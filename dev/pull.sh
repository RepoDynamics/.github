#!/bin/sh

# Clone or pull repositories from a GitHub account.

# Requirements:
# GitHub CLI (gh): https://github.com/cli/cli

# References:
# - https://stackoverflow.com/a/68770988/14923024


# Default input arguments
OWNER="RepoDynamics"
LOCAL_PATH="$(pwd)"
NO_ARCHIVED="--no-archived"
SOURCE="--source"
IGNORE_REGEX=""
PULL=true
VERBOSE=false

echo ""

# Parse input parameters
while [ "$#" -gt 0 ]; do
  case "$1" in
    -o|--owner)
      OWNER="$2"
      shift 2
      ;;
    -p|--path)
      LOCAL_PATH="$2"
      shift 2
      ;;
    -i|--ignore-regex)
      IGNORE_REGEX="$2"
      shift 2
      ;;
    -a|--archived)
      NO_ARCHIVED=""
      shift
      ;;
    -f|--fork)
      SOURCE=""
      shift
      ;;
    -n|--no-pull)
      PULL=false
      shift
      ;;
    -v|--verbose)
      VERBOSE=true
      shift
      ;;
    -h|--help)
      echo "---------------------------------------"
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
      echo "  -o, --owner         GitHub organization or user account (default: RepoDynamics)"
      echo "  -i, --ignore-regex  Regex pattern to ignore repositories by name"
      echo "  -a, --archived      Include archived repositories (default: false)"
      echo "  -f, --fork          Include forked repositories (default: false)"
      echo "  -p, --path          Local directory path for cloning (default: current working directory)"
      echo "  -n, --no-pull       Disable pulling updates for existing repositories (default: false)"
      echo "  -v, --verbose       Enable verbose output (default: false)"
      echo "  -h, --help          Show this dialog and exit."
      exit 0
      ;;
    *)
      echo "ERROR: Unknown parameter: $1"
      echo "Use -h or --help for usage information."
      exit 1
      ;;
  esac
done


# Ensure GitHub CLI is installed
if ! command -v gh >/dev/null 2>&1; then
  echo "ERROR: GitHub CLI (gh) is not installed. Please install it and try again."
  exit 1
fi


# Create the local directory if it does not exist
mkdir -p "$LOCAL_PATH" || {
  echo "ERROR: Failed to create directory $LOCAL_PATH."
  exit 1
}
cd "$LOCAL_PATH" || {
  echo "ERROR: Failed to navigate to directory $LOCAL_PATH."
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
counter=0
gh repo list "$OWNER" --limit 1000 $NO_ARCHIVED $SOURCE | while IFS= read -r repo_line; do

  repo=$(echo "$repo_line" | awk '{print $1}')
  # Extract repository name from the full repo identifier (org/repo_name)
  repo_name=$(basename "$repo")
  # Convert to lowercase
  repo_lowercase=$(echo "$repo" | tr '[:upper:]' '[:lower:]')

  counter=$((counter + 1))
  echo ""
  echo "$counter. $repo_name"
  echo "---------------------------------------"

  # Skip repositories that match the ignore regex (case-insensitive)
  if [ -n "$IGNORE_REGEX" ] && echo "$repo_name" | grep -qiE "$IGNORE_REGEX"; then
    echo "SKIP: Repository $repo matches the ignore regex."
    continue
  fi

  if [ -d "$repo_lowercase" ]; then
    echo "UPDATE: Updating existing repository: $repo"
    (
      cd "$repo_lowercase" || {
        echo "WARNING: Failed to navigate to existing repository directory $repo. Skipping fetch and pull."
        exit
      }
      # Fetch all branches and tags
      git fetch --all --tags $QUIET

      # Perform pull only if enabled
      if $PULL; then
        # Rebase all branches that track a remote branch
        git stash $QUIET --include-untracked || true
        for branch in $(git branch -r | grep -v '\->' | awk '{print $1}' | sed 's|origin/||'); do  # iterate over remote branch names
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
        echo "SKIP: Skipping pull for repository $repo as --no-pull is set."
      fi
    )
  else
    echo "CLONE: $repo"
    GIT_TERMINAL_PROMPT=0 gh repo clone "$repo" "$repo_lowercase" -- $QUIET || echo "WARNING: Failed to clone $repo."
  fi

done
