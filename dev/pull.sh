#!/bin/bash

# Clone or pull repositories from a GitHub account.

# Requirements:
# GitHub CLI (gh): https://github.com/cli/cli

# References:
# - https://stackoverflow.com/a/68770988/14923024


# Default input arguments
OWNER="RepoDynamics"
LOCAL_PATH="$(pwd)"
NO_ARCHIVED=""
SOURCE=""
PULL=true
VERBOSE=false


# Parse input parameters
while [[ $# -gt 0 ]]; do
  case $1 in
    -o|--owner)
      OWNER="$2"
      shift # Remove argument name
      shift # Remove argument value
      ;;
    -p|--path)
      LOCAL_PATH="$2"
      shift
      shift
      ;;
    --no-archived)
      NO_ARCHIVED="--no-archived"
      shift
      ;;
    --source)
      SOURCE="--source"
      shift
      ;;
    --no-pull)
      PULL=false
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    -h|--help)
      echo "Get repositories from a GitHub account."
      echo "---------------------------------------"
      echo "This script finds all repositories in a GitHub account, \
      and syncs them with a local clone. For a given local directory path, \
      the script looks for repositories under 'owner-name/repo-name', \
      where 'owner-name' is the GitHub account and 'repo-name' is the name \
      of a repository in that account. If such directory doesn't exist, \
      then the GitHub repository is cloned into that path. Otherwise, \
      the remote repository is pulled and rebased into the existing local clone."
      echo "-------------------"
      echo "Usage: $0 [options]"
      echo "Options:"
      echo "  -o, --owner       GitHub account name (default: RepoDynamics)"
      echo "  -p, --path        Local directory path for cloning (default: current working directory)"
      echo "  --no-archived     Exclude archived repositories (default: false)"
      echo "  --source          Exclude forked repositories (default: false)"
      echo "  --no-pull         Disable pulling updates for existing repositories (default: false)"
      echo "  --verbose         Enable verbose output (default: false)"
      exit 0
      ;;
    *)
      echo "Unknown parameter: $1"
      echo "Use -h or --help for usage information."
      exit 1
      ;;
  esac
done


# Ensure GitHub CLI is installed
if ! command -v gh &> /dev/null; then
  echo "Error: GitHub CLI (gh) is not installed. Please install it and try again."
  exit 1
fi


# Create the local directory if it does not exist
mkdir -p "$LOCAL_PATH"
cd "$LOCAL_PATH" || {
  echo "Error: Failed to navigate to directory $LOCAL_PATH."
  exit 1
}


# Set quiet or verbose flag for Git commands
if $VERBOSE; then
  QUIET=""
else
  QUIET="-q"
fi


# List all repositories from the organization and process them.
# Max `--limit` is 4000.
# Reference: https://cli.github.com/manual/gh_repo_list
gh repo list "$OWNER" --limit 4000 $NO_ARCHIVED $SOURCE | while read -r repo _; do

  if [[ -d "$repo" ]]; then
    echo "Updating existing repository: $repo"
    (
      cd "$repo" || {
        echo "WARNING: Failed to navigate to existing repository directory $repo. Skipping fetch and pull."
        exit
      }
      # Fetch all branches and tags
      git fetch --all --tags $QUIET

      # Perform pull only if enabled
      if $PULL; then
        # Rebase all branches that track a remote branch
        git stash $QUIET --include-untracked || true
        for branch in $(git branch -r | grep -v '\->' | awk '{print $1}' | sed 's/origin\///'); do  # iterate over remote branch names
          git checkout $QUIET "$branch" 2>/dev/null || {
            echo "WARNING: Failed to checkout branch $branch in $repo. Skipping branch pull."
            continue
          }
          GIT_TERMINAL_PROMPT=0 git pull --rebase $QUIET origin "$branch" || {
            echo "WARNING: Rebase failed for branch $branch in $repo. Skipping branch pull."
            continue
          }
        done
        git stash pop $QUIET || true
      else
        echo "Skipping pull for repository $repo as --no-pull is set."
      fi
    )
  else
    echo "Cloning repository: $repo"
    GIT_TERMINAL_PROMPT=0 gh repo clone "$repo" "$repo" -- $QUIET || echo "WARNING: Failed to clone $repo. Skipping repository clone."
  fi

done
