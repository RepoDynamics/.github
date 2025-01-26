#!/bin/sh

# Install all Python packages in editable mode.


# Default input arguments
LOCAL_PATH="$(pwd)"
IGNORE_REGEX=""
VERBOSE=false


# Parse input parameters
while [ "$#" -gt 0 ]; do
  case "$1" in
    -p|--path)
      LOCAL_PATH="$2"
      shift 2
      ;;
    -i|--ignore-regex)
      IGNORE_REGEX="$2"
      shift 2
      ;;
    -v|--verbose)
      VERBOSE=true
      shift
      ;;
    -h|--help)
      echo "-----------------------------------------"
      echo "Install Python packages in editable mode."
      echo "-----------------------------------------"
      echo "This script finds all repositories in a local directory that include a 'pkg/pyproject.toml' file. \
It then analyzes these pyproject.toml files to categorize all dependencies into local and third-party dependencies. \
That is, any requirement specifier whose name is equal to the project name of an existing pyproject.toml file \
is considered a local dependency. The script will then install all packages and their dependencies, \
ensuring that all local dependencies are installed from the local copy in editable mode."
      echo "-------------------"
      echo "Usage: $0 [options]"
      echo "Options:"
      echo "  -p, --path          Local directory path containing repositories (default: current working directory)"
      echo "  -i, --ignore-regex  Regex pattern to ignore repositories by name"
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


# Ensure pip is installed
if ! command -v pip >/dev/null 2>&1; then
  echo "ERROR: pip is not installed. Please install it and try again."
  exit 1
fi


# Install script dependencies
if [ "$VERBOSE" = true ]; then
  pip install packaging
else
  pip install packaging >/dev/null 2>&1
fi


# Locate the Python script `install.py` and ensure it exists
SCRIPT_DIR=$(cd "$(dirname "$0")" 2>/dev/null || { echo "ERROR: Failed to determine the script's directory."; exit 1; }; pwd)
PYTHON_SCRIPT="$SCRIPT_DIR/install.py"

if [ ! -f "$PYTHON_SCRIPT" ]; then
  echo "ERROR: The Python script 'install.py' is not found in the directory: $SCRIPT_DIR"
  exit 1
fi

# Construct the Python script command
COMMAND="python \"$PYTHON_SCRIPT\" --path \"$LOCAL_PATH\""
if [ -n "$IGNORE_REGEX" ]; then
  COMMAND="$COMMAND --ignore-regex \"$IGNORE_REGEX\""
fi
if [ "$VERBOSE" = true ]; then
  COMMAND="$COMMAND --verbose"
fi

# Execute the Python script
sh -c "$COMMAND"


# Install third-party package dependencies
echo "Install third-party dependencies:"
echo "================================="
EXT_REQS_PATH="$SCRIPT_DIR/ext_reqs.txt"
pip install -r "$EXT_REQS_PATH"
rm -f "$EXT_REQS_PATH"


# Install local packages in editable mode
echo "Install local packages:"
echo "======================="
INT_REQS_PATH="$SCRIPT_DIR/int_reqs.txt"
pip install -r "$INT_REQS_PATH" --no-deps
rm -f "$INT_REQS_PATH"
