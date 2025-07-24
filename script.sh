#!/bin/bash

# Script usage information
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --build-only    Skip code processing/log improvements, run build on existing branch"
    echo "  --help, -h      Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                 # Full processing: code suggestions, build, and PR creation"
    echo "  $0 --build-only    # Build-only mode: skip code processing, test build on existing branch, create PR"
    echo ""
    exit 1
}

# Parse command line arguments
BUILD_ONLY_MODE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --build-only)
            BUILD_ONLY_MODE=true
            shift
            ;;
        --help|-h)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

echo "Script mode: $([ "$BUILD_ONLY_MODE" = true ] && echo "Build-only" || echo "Full processing")"

# Source SDKMAN to enable sdk commands
if [ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]; then
    source "$HOME/.sdkman/bin/sdkman-init.sh"
    echo "SDKMAN initialized successfully"
else
    echo "SDKMAN not found at $HOME/.sdkman/bin/sdkman-init.sh"
fi

# Function to ensure Java 11 is active
ensure_java_11() {
    echo "Ensuring Java 11 is active..."
    
    # Try to use SDKMAN first
    if command -v sdk &> /dev/null; then
        echo "Using SDKMAN to set Java 11..."
        sdk use java 11.0.19-tem || sdk install java 11.0.19-tem
        export JAVA_HOME="$HOME/.sdkman/candidates/java/11.0.19-tem"
    else
        echo "SDKMAN not available, setting JAVA_HOME manually..."
        export JAVA_HOME="/Users/charithr/.sdkman/candidates/java/11.0.19-tem"
    fi
    
    # Update PATH to prioritize the correct Java version
    export PATH="$JAVA_HOME/bin:$PATH"
    
    echo "JAVA_HOME: $JAVA_HOME"
    echo "Java version verification:"
    java -version
    mvn -version | head -3
}

# Function to create and push PR
create_pull_request() {
    local repo_owner=$1
    local repo_name=$2
    local branch_name=$3
    local commit_message=$4
    local pr_title=$5
    local pr_body=$6
    local default_branch=$7

    # Stage and commit changes
    git add .
    git commit -m "$commit_message"

    # Push changes to remote
    git push -u origin "$branch_name"

    # Create Pull Request using GitHub API
    curl -X POST \
        -H "Authorization: token ${GITHUB_TOKEN}" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/repos/${repo_owner}/${repo_name}/pulls" \
        -d "{
            \"title\": \"${pr_title}\",
            \"body\": \"${pr_body}\",
            \"head\": \"${branch_name}\",
            \"base\": \"${default_branch}\"
        }"
    echo "Pull request created successfully for $repo_name!"
}

# Check if claude is installed (needed for build fixing in both modes)
if ! command -v claude &> /dev/null; then
    echo "Claude CLI not found. Installing..."
    npm install -g @anthropic-ai/claude-code
    if [ $? -eq 0 ]; then
        echo "Claude CLI installed successfully!"
    else
        echo "Failed to install Claude CLI. Please install manually."
        exit 1
    fi
else
    echo "Claude CLI is already installed."
fi

# Read values from properties.json
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROPERTIES_FILE="$SCRIPT_DIR/properties.json"

# Export environment variables using perl to parse JSON
export ANTHROPIC_API_KEY=$(perl -MJSON -0777 -ne 'print JSON::decode_json($_)->{env}{ANTHROPIC_API_KEY}' "$PROPERTIES_FILE")
export GITHUB_TOKEN=$(perl -MJSON -0777 -ne 'print JSON::decode_json($_)->{env}{GITHUB_TOKEN}' "$PROPERTIES_FILE")

# Read common properties
BRANCH_NAME=$(perl -MJSON -0777 -ne 'print JSON::decode_json($_)->{github}{branch}' "$PROPERTIES_FILE")
PR_TITLE=$(perl -MJSON -0777 -ne 'print JSON::decode_json($_)->{github}{pr_title}' "$PROPERTIES_FILE")
COMMIT_MESSAGE=$(perl -MJSON -0777 -ne 'print JSON::decode_json($_)->{github}{commit_message}' "$PROPERTIES_FILE")
PR_BODY=$(perl -MJSON -0777 -ne 'print JSON::decode_json($_)->{github}{pr_body}' "$PROPERTIES_FILE")
DIRECTORIES=$(perl -MJSON -0777 -ne 'print join("\n", @{JSON::decode_json($_)->{directories}})' "$PROPERTIES_FILE")
echo "Directories to process: $DIRECTORIES"

# Get all repositories as an array
REPOS=$(perl -MJSON -0777 -ne 'print join("\n", @{JSON::decode_json($_)->{github}{repositories}})' "$PROPERTIES_FILE")

# Process each repository
echo "$REPOS" | while read -r REPO_FULL; do
    echo "Processing repository: $REPO_FULL"
    
    # Extract owner and repo name
    IFS='/' read -r REPO_OWNER REPO_NAME <<< "$REPO_FULL"
    
    # Check if repository directory exists
    if [ -d "$REPO_NAME" ]; then
        echo "Repository $REPO_NAME already exists. Updating..."
        cd "$REPO_NAME"
        
        # Get default branch name
        DEFAULT_BRANCH=$(git remote show origin | grep 'HEAD branch' | cut -d' ' -f5)
        echo "Default branch is: $DEFAULT_BRANCH"
        
        if [ "$BUILD_ONLY_MODE" = false ]; then
            # Full processing mode: update and create new branch
            # Add upstream remote if it doesn't exist
            if ! git remote | grep -q "upstream"; then
                echo "Adding upstream remote..."
                git remote add upstream "https://github.com/${REPO_OWNER}/${REPO_NAME}.git"
            fi
            
            # Fetch from both origin and upstream
            echo "Fetching from origin and upstream..."
            git fetch origin
            git fetch upstream
            
            # Switch to default branch and pull latest from upstream
            echo "Switching to $DEFAULT_BRANCH and updating from upstream..."
            git checkout $DEFAULT_BRANCH
            git pull upstream $DEFAULT_BRANCH
            
            # Push updated default branch to origin (your fork)
            git push origin $DEFAULT_BRANCH
            
            # Create and switch to new branch based on updated default branch
            echo "Creating new branch $BRANCH_NAME based on upstream/$DEFAULT_BRANCH..."
            git checkout -b $BRANCH_NAME upstream/$DEFAULT_BRANCH
            echo "Repository updated successfully!"
        else
            # Build-only mode: stay on current branch
            CURRENT_BRANCH=$(git branch --show-current)
            echo "Build-only mode: Staying on current branch '$CURRENT_BRANCH'"
            echo "Repository ready for build testing!"
        fi
    else
        echo "Cloning repository $REPO_NAME..."
        # Clone the repository using the PAT
        git clone https://oauth2:${GITHUB_TOKEN}@github.com/${REPO_OWNER}/${REPO_NAME}.git
        cd "$REPO_NAME"
        
        # Get default branch name
        DEFAULT_BRANCH=$(git remote show origin | grep 'HEAD branch' | cut -d' ' -f5)
        echo "Default branch is: $DEFAULT_BRANCH"
        
        if [ "$BUILD_ONLY_MODE" = false ]; then
            # Full processing mode: set up upstream and create new branch
            # Add upstream remote if this is a fork
            echo "Adding upstream remote..."
            git remote add upstream "https://github.com/${REPO_OWNER}/${REPO_NAME}.git"
            
            # Fetch from upstream
            echo "Fetching from upstream..."
            git fetch upstream
            
            # Create and switch to new branch based on upstream default branch
            echo "Creating new branch $BRANCH_NAME based on upstream/$DEFAULT_BRANCH..."
            git checkout -b $BRANCH_NAME upstream/$DEFAULT_BRANCH
            echo "Repository cloned successfully!"
        else
            # Build-only mode: stay on default branch
            echo "Build-only mode: Staying on default branch '$DEFAULT_BRANCH'"
            echo "Repository cloned successfully!"
        fi
    fi

    # Skip code processing/log improvements in build-only mode
    if [ "$BUILD_ONLY_MODE" = false ]; then
        # Collect all allowed src/main directories first
        allowed_dirs=()
        while IFS= read -r src_dir; do
            # Check if this src_dir is a subdirectory of any root folder in DIRECTORIES
            is_allowed=false
            while IFS= read -r root_dir; do
                # Remove leading ./ from paths for comparison
                normalized_src_dir=${src_dir#./}
                normalized_root_dir=${root_dir#./}
                
                # Check if src_dir starts with root_dir (is a subdirectory)
                if [[ "$normalized_src_dir" == "$normalized_root_dir"* ]]; then
                    is_allowed=true
                    echo "Directory $src_dir matches root folder $root_dir"
                    break
                fi
            done <<< "$DIRECTORIES"
            
            if [ "$is_allowed" = true ]; then
                allowed_dirs+=("$src_dir")
            else
                echo "Skipping directory $src_dir as it is not a subdirectory of any root folder in the directories list."
            fi
        done < <(find . -type d -path "*/src/main")
        
        # Process all allowed directories and collect their PIDs
        processor_pids=()
        for src_dir in "${allowed_dirs[@]}"; do
            echo "Processing src/main directory: $src_dir"
            
            # Run claude-processor in background
            "$SCRIPT_DIR/claude-processor.sh" "$REPO_NAME" "$src_dir" > "processor_output_${src_dir//\//_}.$$.tmp" &
            processor_pids+=($!)
            
            # Wait a moment before starting the next processor
            echo "Waiting for 5 seconds before processing the next directory..."
            sleep 5
        done
        
        # Wait for all processors to complete and collect outputs
        echo "Waiting for all processors to complete..."
        for i in "${!processor_pids[@]}"; do
            processor_pid=${processor_pids[i]}
            src_dir=${allowed_dirs[i]}
            
            wait $processor_pid
            processor_output=$(<"processor_output_${src_dir//\//_}.$$.tmp")
            rm "processor_output_${src_dir//\//_}.$$.tmp"
            
            # Print the output
            echo "Output from processing $src_dir:"
            echo "$processor_output"
            echo "----------------------------------------"
        done
        
        echo "All file reviews completed. Proceeding with build and PR creation..."
    else
        echo "Build-only mode: Skipping code processing/log improvements phase. Proceeding directly to build..."
    fi

    # Function to attempt Maven build with retry logic
    attempt_maven_build() {
        local max_attempts=10
        local attempt=1
        local build_successful=false
        
        # Ensure Java 11 is active before any build attempts
        ensure_java_11
        
        echo "========================================"
        echo "Building at root directory only"
        echo "========================================"
        
        while [ $attempt -le $max_attempts ] && [ "$build_successful" = false ]; do
            echo "=== Root Build Attempt $attempt of $max_attempts ==="
            
            # Re-verify Java version before each attempt
            echo "Current Java version:"
            java -version
            echo "Current JAVA_HOME: $JAVA_HOME"
            
            if [ $attempt -eq 1 ]; then
                echo "Running initial Maven clean install at root..."
                maven_cmd="mvn clean install -Dmaven.test.skip=true -DskipTests --fail-never"
            else
                echo "Running Maven build after applying fixes (attempt $attempt)..."
                # For subsequent attempts, use resume functionality if available
                # Check if we can identify failed modules from previous build
                if [ -n "$previous_failed_modules" ]; then
                    echo "Resuming build from previously failed modules: $previous_failed_modules"
                    maven_cmd="mvn install -Dmaven.test.skip=true -DskipTests -rf $previous_failed_modules --fail-never -q"
                else
                    echo "Re-running full build..."
                    maven_cmd="mvn clean install -Dmaven.test.skip=true -DskipTests --fail-never"
                fi
                # Ensure Java 11 is still active after Claude changes
                ensure_java_11
            fi
            
            echo "Executing: $maven_cmd"
            BUILD_OUTPUT=$($maven_cmd 2>&1)
            echo "$BUILD_OUTPUT"
            
            # Check for successful build message
            if echo "$BUILD_OUTPUT" | grep -q "\[INFO\] BUILD SUCCESS"; then
                echo "Maven build successful at root on attempt $attempt!"
                build_successful=true
                
                # Create PR (in both modes)
                echo "Proceeding with PR creation..."
                
                # Determine the branch name for PR creation
                if [ "$BUILD_ONLY_MODE" = false ]; then
                    PR_BRANCH="$BRANCH_NAME"
                else
                    PR_BRANCH=$(git branch --show-current)
                fi
                
                create_pull_request "$REPO_OWNER" "$REPO_NAME" "$PR_BRANCH" "$COMMIT_MESSAGE" "$PR_TITLE" "$PR_BODY" "$DEFAULT_BRANCH"
                
                # Clean up: Move back to parent directory and remove repo
                cd ..
                echo "Repository $REPO_NAME cleaned up successfully!"
                break
            else
                echo "Build failed on attempt $attempt."
                
                # Extract failed module information for resume functionality
                previous_failed_modules=""
                if echo "$BUILD_OUTPUT" | grep -q "FAILURE"; then
                    # Try to extract the module that failed
                    failed_module=$(echo "$BUILD_OUTPUT" | grep -B5 -A5 "FAILURE" | grep "Building" | tail -1 | sed 's/.*Building \([^ ]*\).*/\1/' | sed 's/.*://')
                    if [ -n "$failed_module" ]; then
                        previous_failed_modules=":$failed_module"
                        echo "Identified failed module for resume: $failed_module"
                    fi
                fi
                # If not the last attempt, try to fix the issues
                if [ $attempt -lt $max_attempts ]; then
                    echo "Attempting to fix build failures with Claude AI..."

                    # Write build output to a file
                    BUILD_OUTPUT_FILE="build_output_${REPO_NAME}_attempt${attempt}.$$.log"
                    echo "$BUILD_OUTPUT" > "$BUILD_OUTPUT_FILE"

                    # Use the file in the Claude prompt
                    claude_prompt="Fix all build failures in repository $REPO_NAME. The Maven build at root level is failing. Please analyze the build output in the file $BUILD_OUTPUT_FILE and fix ALL issues that are preventing the build from succeeding.

                    Focus on fixing these types of issues if present:
                    1. CHECKSTYLE VIOLATIONS: Code formatting, indentation, naming conventions, import organization, line length, Javadoc comments, brace placement
                    2. COMPILATION ERRORS: Missing imports, syntax errors, missing dependencies in pom.xml, type resolution issues, method signature mismatches
                    3. DEPENDENCY ISSUES: Missing dependencies, version conflicts, repository configuration, module dependencies
                    4. TEST FAILURES: Test compilation errors, missing test dependencies, test configuration issues
                    5. GENERAL BUILD ERRORS: Any other Maven build issues, plugin configuration problems, resource processing errors

                    COMPLETE BUILD OUTPUT FILE: $BUILD_OUTPUT_FILE

                    Please fix ALL the issues mentioned in the build output above to make the Maven build succeed."

                    result=$(claude -p --dangerously-skip-permissions --verbose "$claude_prompt" Edit)
                    echo "Claude AI fixes applied:"
                    echo "$result"
                    echo "----------------------------------------"
                    
                    # Single comprehensive prompt for all types of build failures
                    claude_prompt="Fix all build failures in repository $REPO_NAME. The Maven build at root level is failing. Please analyze the build output and fix ALL issues that are preventing the build from succeeding.

Focus on fixing these types of issues if present:
1. CHECKSTYLE VIOLATIONS: Code formatting, indentation, naming conventions, import organization, line length, Javadoc comments, brace placement
2. COMPILATION ERRORS: Missing imports, syntax errors, missing dependencies in pom.xml, type resolution issues, method signature mismatches
3. DEPENDENCY ISSUES: Missing dependencies, version conflicts, repository configuration, module dependencies
4. TEST FAILURES: Test compilation errors, missing test dependencies, test configuration issues
5. GENERAL BUILD ERRORS: Any other Maven build issues, plugin configuration problems, resource processing errors

COMPLETE BUILD OUTPUT:
$BUILD_OUTPUT

Please fix ALL the issues mentioned in the build output above to make the Maven build succeed."
                    
                    result=$(claude -p --dangerously-skip-permissions --verbose "$claude_prompt" Edit)
                    echo "Claude AI fixes applied:"
                    echo "$result"
                    echo "----------------------------------------"
                    
                    # Wait a moment before next attempt
                    echo "Waiting 10 seconds before next build attempt..."
                    sleep 10
                else
                    echo "Maximum build attempts ($max_attempts) reached."
                    echo "Final build output:"
                    echo "$BUILD_OUTPUT"
                    echo "Skipping PR creation for $REPO_NAME."
                fi
            fi
            
            attempt=$((attempt + 1))
        done
        
        return $([ "$build_successful" = true ] && echo 0 || echo 1)
    }
    
    # Run Maven build with retry logic
    echo "Starting Maven build process with retry logic..."
    attempt_maven_build
done

echo "All repositories processed successfully!"

