# Script Usage Guide

## Overview
This script automates the process of processing GitHub repositories with AI-powered code suggestions and Maven builds. It now supports two modes of operation.

## Prerequisites
1. **Properties File**: Configure `properties.json` with your API keys, repositories, and directories
2. **Java 11**: SDKMAN will be used to manage Java versions
3. **Maven**: Required for building Java projects
4. **Git**: For repository operations
5. **Node.js**: For Claude CLI installation (only in full mode)

## Usage

### Full Processing Mode (Default)
```bash
./script.sh
```
**What it does:**
- Processes all specified directories with AI code suggestions
- Runs Maven build with retry logic
- Applies AI fixes for build failures
- Creates pull requests automatically
- Cleans up repositories after completion

### Build-Only Mode
```bash
./script.sh --build-only
```
**What it does:**
- Skips AI code processing/log improvements phase
- **Runs on existing branch** (no branch switching/creation)
- Runs Maven build with retry logic
- Applies AI fixes for build failures only
- Creates pull requests from current branch
- Cleans up repositories after completion

### Help
```bash
./script.sh --help
# or
./script.sh -h
```

## Configuration

### Properties File Setup
1. Copy the sample properties file:
   ```bash
   cp properties.sample.json properties.json
   ```

2. Edit `properties.json` with your values:
   ```json
   {
     "env": {
       "ANTHROPIC_API_KEY": "your-anthropic-api-key",
       "GITHUB_TOKEN": "your-github-token"
     },
     "github": {
       "repositories": ["username/repo-name"],
       "branch": "feature-branch-name",
       "commit_message": "Your commit message",
       "pr_title": "Your PR title",
       "pr_body": "Your PR description"
     },
     "directories": ["./components/target-component"]
   }
   ```

## When to Use Each Mode

### Full Processing Mode
Use when you want to:
- Apply AI-powered code improvements
- Fix both code quality and build issues
- Automatically create pull requests
- Perform comprehensive repository processing

### Build-Only Mode
Use when you want to:
- Test build compatibility on existing branches
- Only fix compilation errors and build issues
- Skip code quality/logging improvements
- Avoid creating new branches or switching branches
- Still create pull requests with build fixes from current branch
- Quickly validate and fix repositories that can build successfully

## Examples

### Process a specific component with full AI suggestions
```bash
# Configure properties.json to target specific directories
# Then run full mode
./script.sh
```

### Only fix build issues without code suggestions
```bash
./script.sh --build-only
```

### Test build compatibility for multiple repositories
```bash
# Set multiple repositories in properties.json
./script.sh --build-only
```

## Output

### Full Mode Output
- AI code suggestion results
- Maven build attempts and results
- PR creation confirmation
- Repository cleanup status

### Build-Only Mode Output
- Maven build attempts and results
- Build fix attempts (if needed)
- Build success/failure status
- Repository cleanup status

## Error Handling

The script includes robust error handling:
- **Build Failures**: Up to 10 retry attempts with AI-powered fixes
- **Java Version**: Automatic Java 11 setup via SDKMAN
- **Missing Dependencies**: Maven dependency resolution
- **Git Operations**: Proper branch management and remote setup

## Tips

1. **Large Repositories**: Build-only mode is faster for large codebases
2. **Testing**: Use build-only mode to test changes before full processing
3. **CI/CD Integration**: Build-only mode is ideal for automated testing pipelines
4. **Development**: Full mode for development branches, build-only for testing branches
