#!/bin/sh

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
echo "A) Clone/Pull"
echo "=============\n\n"
SCRIPT_DIR=$(cd "$(dirname "$0")" || { echo "ERROR: Failed to determine script directory."; exit 1; }; pwd)
PULL_SCRIPT="$SCRIPT_DIR/pull.sh"

if [ ! -f "$PULL_SCRIPT" ]; then
  echo "ERROR: The script 'pull.sh' is not found in the directory: $SCRIPT_DIR"
  exit 1
fi

PULL_CMD="sh \"$PULL_SCRIPT\" --owner \"$OWNER\" --path \"$LOCAL_PATH\" --ignore-regex \"$IGNORE_REGEX\" $NO_ARCHIVED $SOURCE"
if [ "$PULL" = false ]; then
  PULL_CMD="$PULL_CMD --no-pull"
fi
if [ "$VERBOSE" = true ]; then
  PULL_CMD="$PULL_CMD --verbose"
fi

# Execute the pull script
sh -c "$PULL_CMD"

# Check if the script succeeded
if [ "$?" -ne 0 ]; then
  echo "ERROR: 'pull.sh' script failed. Exiting."
  exit 1
fi


# Run `install.sh`
echo "\n\nB) Installation"
echo "===============\n\n"
INSTALL_SCRIPT="$SCRIPT_DIR/install.sh"

if [ ! -f "$INSTALL_SCRIPT" ]; then
  echo "ERROR: The script 'install.sh' is not found in the directory: $SCRIPT_DIR"
  exit 1
fi

OWNER_LOWERCASE=$(echo "$OWNER" | tr '[:upper:]' '[:lower:]')

INSTALL_CMD="sh \"$INSTALL_SCRIPT\" --path \"$LOCAL_PATH/$OWNER_LOWERCASE\" --ignore-regex \"$IGNORE_REGEX\""
if [ "$VERBOSE" = true ]; then
  INSTALL_CMD="$INSTALL_CMD --verbose"
fi

# Execute the install script
sh -c "$INSTALL_CMD"

# Check if the script succeeded
if [ "$?" -ne 0 ]; then
  echo "ERROR: 'install.sh' script failed. Exiting."
  exit 1
fi
