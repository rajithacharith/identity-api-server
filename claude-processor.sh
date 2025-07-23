#!/bin/bash

# Function to process a directory with Claude
process_with_claude() {
    local REPO_NAME=$1
    local src_dir=$2

    # Create a normalized path by removing ./ from the beginning
    normalized_dir=${src_dir#./}
    echo "Processing directory: $normalized_dir"
    
    # Change to the specific src/main directory before processing
    cd "$src_dir"
    
    # Process the current directory with Claude
    result=$(claude -p --dangerously-skip-permissions --verbose "Fix all the java files in $REPO_NAME/$normalized_dir directory that need log improvement or log addition according to CLAUDE.md memory" Edit)
    # echo "Fix all the java files in $REPO_NAME/$normalized_dir directory that need log improvement or log addition according to CLAUDE.md memory"
    echo "$result"
    
    # Return to the repository root directory
    cd - > /dev/null
}

# Check if both repository name and directory are provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <repository-name> <src-main-directory>"
    exit 1
fi

# Process the specified directory
process_with_claude "$1" "$2"