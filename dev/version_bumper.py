from pathlib import Path as _Path

from packaging.requirements import Requirement as _Req
import pyserials as _ps
from versionman.pep440_semver import PEP440SemVer as _PEP440SemVer

import pdep as _pdep


def bump_pinned_dev_versions(
    path_org_dir: str | _Path,
    to_bump_names: list[str],
    exclude_names: list[str] | None = None,
):
    path = _Path(path_org_dir)
    dirs = [d for d in path.iterdir() if d.is_dir()]
    dir_names = [d.name for d in dirs]
    check_names_integrity(to_bump_names, dir_names, "to-bump")
    check_names_integrity(exclude_names or [], dir_names, "exclude")
    selected_dirs = prune_dirs(dirs, exclude_names)
    to_bump_dirs, other_dirs = categorize_dirs(selected_dirs, to_bump_names)
    return bump_pinned_deps(to_bump_dirs, other_dirs)


def bump_pinned_deps(
    to_bump: list[str | _Path],
    dependents: list[str | _Path],
):
    def process_path(path: _Path, bump: bool) -> None:
        pyproject = _ps.read.toml_from_file(path / "pyproject.toml", as_dict=False)
        project_name = pyproject["project"]["name"]
        project_name_normalized = _pdep.normalize_distribution_name(project_name)
        name_path[project_name_normalized] = path
        name_version[project_name_normalized] = pyproject["project"]["version"]
        original_name[project_name_normalized] = project_name
        pyprojects[project_name_normalized] = pyproject
        bump_map[project_name_normalized] = bump
        dep_map[project_name_normalized] = [
            _pdep.normalize_distribution_name(_Req(dep).name)
            for dep in pyproject["project"].get("dependencies", [])
        ]
        return

    def bump_version(version: str) -> str:
        semver = _PEP440SemVer(version)
        dev_num = semver.dev
        return f"0.0.0.dev{dev_num + 1}"

    name_version: dict[str, str] = {}
    name_path: dict[str, str | _Path] = {}
    original_name: dict[str, str] = {}
    pyprojects: dict[str, dict] = {}
    bump_map: dict[str, bool] = {}
    dep_map: dict[str, list[str]] = {}

    for path in to_bump:
        process_path(path, True)
    for path in dependents:
        process_path(path, False)
    for project_name, deps in dep_map.items():
        dep_map[project_name] = [dep for dep in deps if dep in pyprojects]
    exhausted = False
    while not exhausted:
        a_dep_needs_bump = False
        for dist_name, deps in dep_map.items():
            for dep in deps:
                if bump_map.get(dep):
                    if not bump_map.get(dist_name, False):
                        a_dep_needs_bump = True
                    bump_map[dist_name] = True
        if not a_dep_needs_bump:
            exhausted = True
    for project_name, pyproject in pyprojects.items():
        if bump_map.get(project_name):
            pyproject["project"]["version"] = bump_version(pyproject["project"]["version"])
        for dep in dep_map[project_name]:
            if not bump_map.get(dep):
                continue
            for idx, spec in enumerate(pyproject["project"]["dependencies"]):
                if _pdep.normalize_distribution_name(_Req(spec).name) == dep:
                    dep_version = name_version[dep]
                    spec = f"{original_name[dep]} == {bump_version(dep_version)}"
                    pyproject["project"]["dependencies"][idx] = spec
                    break
    return name_version, name_path, original_name, pyprojects, bump_map, dep_map


def casefold(names: list[str]) -> list[str]:
    return [name.casefold() for name in names]


def check_names_integrity(
    names: list[str],
    allowed_names: list[str],
    description: str,
):
    names_casefold = casefold(names)
    allowed_names_casefold = casefold(allowed_names)
    for name in names_casefold:
        if name not in allowed_names_casefold:
            raise ValueError(f"Invalid {description} name '{name}'.")


def prune_dirs(
    dirs: list[_Path],
    exclude_names: list[str] | None,
):
    if not exclude_names:
        return dirs
    exclude_names_casefold = casefold(exclude_names)
    return [d for d in dirs if d.name.casefold() not in exclude_names_casefold]


def categorize_dirs(
    dirs: list[_Path],
    to_bump_names: list[str],
):
    to_bump_names_casefold = casefold(to_bump_names)
    to_bump_dirs = []
    other_dirs = []
    for d in dirs:
        if d.name.casefold() in to_bump_names_casefold:
            to_bump_dirs.append(d)
        else:
            other_dirs.append(d)
    return to_bump_dirs, other_dirs


if __name__ == "__main__":
    bump_pinned_dev_versions(
        path_org_dir="/Volumes/T7/Projects/GitHub Repos/RepoDynamics",
        to_bump_names=["JSONSchemata", "MDit"],
        exclude_names=[
            '.archived',
            'DocsMan',
            'FixMan',
            'MetaTemplates',
            'PyPackIT',
            'PyPackIT-Template',
            'PyPackIT-Template(ORIG DATA)',
            'PyTests',
            'SphinxDocs',
            '_OrganizationRepo(.github)'
        ],
    )