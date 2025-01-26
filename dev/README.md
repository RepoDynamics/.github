# Development Guide

To start working on RepoDynamics projects:

1. Install the [GitHub CLI](https://github.com/cli/cli#installation) (`gh`).
2. Clone the `repodynamics/.github` repository, for example using `gh`:
   ```bash
   gh repo clone repodynamics/.github ./repodynamics/.github
   ```
3. Create and activate a virtual environment with `python` and `pip` preinstalled,
   for example using `conda`:
   ```bash
   conda create -n repodynamics python
   conda activate repodynamics
   ```
4. Run the initialization script (for more information on optional inputs, run with `--help`):
   ```bash
   repodynamics/.github/dev/init.sh
   ```
   This script clones all RepoDynamics repositories locally
   and installs all Python packages in editable mode
   along with their third-party dependencies in the current environment.


The initialization script is a convenience script running the `pull.sh` and `install.sh`
scripts, respectively. You can also invoke these two scripts separately, when needed
(for more information, run with `--help`):

- `pull.sh`: Clones or pulls specified repositories to establish a synchronized local copy.
- `install.sh`: Installs all third-party dependencies of all repositories containing Python projects.
  This is followed by installing all Python projects in editable mode.
