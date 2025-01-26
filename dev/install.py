import argparse
import logging
from pathlib import Path
import re
import tomllib

from packaging import requirements


logger = logging.getLogger(__name__)


def main(path: str | Path, ignore_regex: str, pyproject_path: str = "pkg/pyproject.toml"):
    map_path_to_pyproject = _get_pyprojects(path=path, ignore_regex=ignore_regex, pyproject_path=pyproject_path)
    map_name_to_path = {
        _normalize_distribution_name(pyproject["project"]["name"]): path
        for path, pyproject in map_path_to_pyproject.items()
    }

    script_path = Path(__file__).parent
    # Create requirements.txt file for local editable installs.
    # These are then installed with 'pip install -r requirements.txt --no-deps'
    # (see: https://github.com/pypa/pip/issues/7339, https://github.com/pypa/pip/pull/10837).
    int_reqs_path = script_path / "int_reqs.txt"
    int_reqs = "\n".join([f"-e '{pkg_path}'" for pkg_path in map_path_to_pyproject.keys()])
    int_reqs_path.write_text(int_reqs)
    logger.debug(f"Local requirements.txt file:\n\n{int_reqs}\n")

    glob = []
    for pyproject in map_path_to_pyproject.values():
        dep_specs, dep_names = _extract_dependencies_from_pyproject_data(pyproject)
        if dep_specs:
            logger.debug(f"Dependencies for {pyproject["project"]["name"]}:\n\n{"\n".join(dep_specs)}\n")
        for spec, name in zip(dep_specs, dep_names):
            if name not in map_name_to_path and spec not in glob:
                glob.append(spec)
    ext_reqs_path = script_path / "ext_reqs.txt"
    ext_reqs = "\n".join(glob)
    ext_reqs_path.write_text(ext_reqs)
    logger.debug(f"Third-party requirements.txt file:\n\n{ext_reqs}\n")
    return


def _get_pyprojects(path: str | Path, ignore_regex: str, pyproject_path: str = "pkg/pyproject.toml"):
    dirs: list[Path] = [d for d in Path(path).iterdir() if d.is_dir()]
    pyprojects = {}
    pattern = re.compile(ignore_regex)
    for dir_path in dirs:
        if ignore_regex and pattern.match(dir_path.name):
            logging.info(f"Skipping repository {dir_path.name} as it matches the ignore regex.")
            continue
        pyproject_fullpath = dir_path / pyproject_path
        if not pyproject_fullpath.is_file():
            logging.info(f"Skipping repository {dir_path.name} as does not contain {pyproject_path}.")
            continue
        pyproject_str = pyproject_fullpath.read_text()
        pyproject = tomllib.loads(pyproject_str)
        pyprojects[pyproject_fullpath.parent] = pyproject
    return pyprojects


def _normalize_distribution_name(dist_name: str) -> str:
    """Normalize a distribution name to a canonical form.

    References
    ----------
    - [PyPA: Python Packaging User Guide: Name format](https://packaging.python.org/en/latest/specifications/name-normalization/)
    """
    return re.sub(r"[-_.]+", "-", dist_name).lower()


def _extract_dependencies_from_pyproject_data(pyproject: dict) -> tuple[list[str], list[str]]:
    def add(deps: list[str]) -> None:
        for dep in deps:
            req = requirements.Requirement(dep)
            name_norm = _normalize_distribution_name(req.name)
            # if name_norm.startswith("ruamel"):
            #     print(req, name_norm)
            req.name = name_norm
            specs.append(str(req))
            names.append(name_norm)

    specs = []
    names = []
    project = pyproject.get("project", {})
    add(project.get("dependencies", []))
    for group_name, dependencies in project.get("optional-dependencies", {}).items():
        add(dependencies)
    return specs, names


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Find repositories with 'pyproject.toml' files and install packages in editable mode."
    )

    parser.add_argument(
        "--path",
        type=str,
        required=True,
        help="Path to the directory containing the repositories."
    )

    parser.add_argument(
        "--ignore-regex",
        type=str,
        default="",
        help="Regex pattern to ignore repositories by name."
    )

    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Enable verbose output."
    )

    args = parser.parse_args()
    logging.basicConfig(level=logging.DEBUG if args.verbose else logging.INFO)
    main(
        path=Path(args.path),
        ignore_regex=args.ignore_regex,
    )
