#!/bin/bash

# Prepare development environment by cloning all repositories
# and installing packages and dependencies.

# Requirements:
# GitHub CLI (gh): https://github.com/cli/cli


# Default input arguments
OWNER="RepoDynamics"
LOCAL_PATH="$(pwd)"
NO_ARCHIVED=""
SOURCE=""
IGNORE_REGEX=""
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
    -i|--ignore-regex)
      IGNORE_REGEX="$2"
      shift
      shift
      ;;
    -a|--no-archived)
      NO_ARCHIVED="--no-archived"
      shift
      ;;
    -s|--source)
      SOURCE="--source"
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
      echo "-------------------------------"
      echo "Set up development environment."
      echo "-------------------------------"
      echo "This script sets up a development environment
by cloning/pulling repositories from a GitHub accounts, \
and installing all Python packages in editable mode along with their third-party dependencies. \
This script simply runs 'pull.sh' followed by 'install.sh'; \
for more information, see those scripts."
      echo "-------------------"
      echo "Usage: $0 [options]"
      echo "Options:"
      echo "  -o, --owner         GitHub organization or user account (default: RepoDynamics)"
      echo "  -i, --ignore-regex  Regex pattern to ignore repositories by name"
      echo "  -a, --no-archived   Exclude archived repositories (default: false)"
      echo "  -s, --source        Exclude forked repositories (default: false)"
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


# Run `pull.sh`
SCRIPT_DIR="$(dirname "$0")"
PULL_SCRIPT="$SCRIPT_DIR/pull.sh"

if [[ ! -f "$PULL_SCRIPT" ]]; then
  echo "ERROR: The script 'pull.sh' is not found in the directory: $SCRIPT_DIR"
  exit 1
fi

bash "$PULL_SCRIPT" --owner "$OWNER" --path "$LOCAL_PATH" --ignore-regex "$IGNORE_REGEX" $NO_ARCHIVED $SOURCE $( [[ $PULL == false ]] && echo "--no-pull" ) $( [[ $VERBOSE == true ]] && echo "--verbose" )

# Check if the script succeeded
if [[ $? -ne 0 ]]; then
  echo "ERROR: 'pull.sh' script failed. Exiting."
  exit 1
fi


# Run `install.sh`
INSTALL_SCRIPT="$SCRIPT_DIR/install.sh"

if [[ ! -f "$INSTALL_SCRIPT" ]]; then
  echo "ERROR: The script 'install.sh' is not found in the directory: $SCRIPT_DIR"
  exit 1
fi

OWNER_LOWERCASE="${OWNER,,}"

bash "$INSTALL_SCRIPT" --path "$LOCAL_PATH/$OWNER_LOWERCASE" --ignore-regex "$IGNORE_REGEX" $( [[ $VERBOSE == true ]] && echo "--verbose" )

# Check if the script succeeded
if [[ $? -ne 0 ]]; then
  echo "ERROR: 'pull.sh' script failed. Exiting."
  exit 1
fi
