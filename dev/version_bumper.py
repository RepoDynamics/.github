from __future__ import annotations as _annotations

from typing import TYPE_CHECKING as _TYPE_CHECKING
from pathlib import Path as _Path
import copy as _copy
from packaging.requirements import Requirement as _Req
import pyserials as _ps
from versionman.pep440_semver import PEP440SemVer as _PEP440SemVer
import gittidy as _gittidy
import pdep as _pdep
from loggerman import logger as _logger

if _TYPE_CHECKING:
    from typing import Sequence, Literal


def from_directory(
    path: str | _Path = "/Volumes/T7/Projects/GitHub Repos/RepoDynamics",
    exclude: Sequence[str] | None = (
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
    ),
    rel_path_pyproject: str = "pyproject.toml",
    rel_path_src: str = "src",
):
    dirs = [d for d in _Path(path).iterdir() if d.is_dir()]
    dir_names = [d.name for d in dirs]
    for exclude_dir_name in (exclude or []):
        if exclude_dir_name not in dir_names:
            raise ValueError(
                f"Directory name '{exclude_dir_name}' inputted as excluded directory does not exist."
            )
    selected_dirs = sorted([d for d in dirs if d.name not in exclude])
    _logger.info(
        "Selected Directories",
        _logger.pretty([str(d) for d in selected_dirs], indent_size=2)
    )
    return OrgReposManager(
        repo_paths=selected_dirs,
        rel_path_pyproject=rel_path_pyproject,
        rel_path_src=rel_path_src,
    )


class OrgReposManager:

    def __init__(
        self,
        repo_paths: Sequence[_Path],
        rel_path_pyproject: str = "pyproject.toml",
        rel_path_src: str = "src",
    ):
        self._rel_path_pyproject = rel_path_pyproject
        self._rel_path_src = rel_path_src
        self.projects: dict[str, dict] = {}
        for path in repo_paths:
            pyproject = _ps.read.toml_from_file(path / self._rel_path_pyproject, as_dict=False)
            normalized_dist_name = _pdep.normalize_distribution_name(pyproject["project"]["name"])
            self.projects[normalized_dist_name] = {
                "path": path,
                "pyproject": pyproject,
                "git": None,
            }
        return

    def bump_pinned_dev_versions(
        self,
        dist_names: Sequence[str] | None = None,
        mode: Literal["report", "apply", "commit", "push"] = "report",
        commit_msg: str = "Release version {version}",
    ) -> dict[str, dict]:

        def process_project(dist_name_norm: str, bump: bool) -> None:
            projects[dist_name_norm] = {
                "pyproject": _copy.deepcopy(self.get_pyproject(dist_name_norm)),
                "bump": bump,
                "deps": self.get_dependencies(dist_name_norm),
            }
            return

        def bump_version(version: str) -> str:
            semver = _PEP440SemVer(version)
            dev_num = semver.dev
            return f"0.0.0.dev{dev_num + 1}"

        if mode not in ["report", "apply", "commit", "push"]:
            raise ValueError(
                f"Invalid mode '{mode}'. Must be one of 'report', 'apply', 'commit', or 'push'."
            )

        projects = {}

        dist_names_to_bump_norm = [
            _pdep.normalize_distribution_name(dist_name)
            for dist_name in (dist_names or self.get_changed_projects())
        ]
        for dist_name_to_bump in dist_names_to_bump_norm:
            process_project(dist_name_to_bump, True)
        for dist_name_unchanged in [dist_name for dist_name in self.projects.keys() if dist_name not in dist_names_to_bump_norm]:
            process_project(dist_name_unchanged, False)
        for project_name, project in projects.items():
            # Filter out third-party and excluded dependencies
            project_deps = project["deps"]
            project["deps"] = [dep for dep in project_deps if dep in projects]
        exhausted = False
        counter = 1
        while not exhausted:
            _logger.section(f"Scan {counter}")
            a_dep_needs_bump = False
            for dist_name, project in projects.items():
                for dep in project["deps"]:
                    if projects[dep]["bump"] and not project["bump"]:
                        _logger.info(
                            f"Bump Needed: {self.get_name(dist_name)}",
                            f"Cause: {self.get_name(dep)}",
                        )
                        a_dep_needs_bump = True
                        project["bump"] = True
            if not a_dep_needs_bump:
                exhausted = True
                _logger.info(
                    "Exhausted",
                    "No more dependencies to bump.",
                )
            _logger.section_end()
            counter += 1
        _logger.section("Bump Project Versions")
        for project_name, project in projects.items():
            if project["bump"]:
                curr_ver = project["pyproject"]["project"]["version"]
                new_ver = bump_version(curr_ver)
                project["pyproject"]["project"]["version"] = new_ver
                _logger.info(
                    project_name,
                    f"- Current: {curr_ver}",
                    f"- New: {new_ver}",
                )
        _logger.section_end()
        _logger.section("Bump Dependency Versions")
        for project_name, project in projects.items():
            for dep in project["deps"]:
                if not projects[dep]["bump"]:
                    continue
                for idx, spec in enumerate(project["pyproject"]["project"]["dependencies"]):
                    if _pdep.normalize_distribution_name(_Req(spec).name) == dep:
                        dep_version = projects[dep]["pyproject"]["project"]["version"]
                        spec_new = f"{self.get_name(dep)} == {dep_version}"
                        project["pyproject"]["project"]["dependencies"][idx] = spec_new
                        _logger.info(
                            dep,
                            f"- Package: {project_name}",
                            f"- Current: {spec}",
                            f"- New: {spec_new}",
                        )
                        break
        _logger.section_end()
        assert set(projects.keys()) == set(self.projects.keys())
        for project_name, project in projects.items():
            if not project["bump"]:
                assert project["pyproject"] == self.projects[project_name]["pyproject"]
                continue
            if mode == "report":
                continue
            pyproject_path = self.get_path(project_name) / self._rel_path_pyproject
            pyproject_str = _ps.write.to_toml_string(project["pyproject"])
            pyproject_path.write_text(pyproject_str)
            if mode == "apply":
                continue
            git = self.get_git(project_name)
            git.commit(commit_msg.format(version=project["pyproject"]["project"]["version"]))
            if mode == "commit":
                continue
            git.push()
        return projects

    def get_dependents(self, dist_name: str):
        dependents = []
        target_dist_name_normalized = _pdep.normalize_distribution_name(dist_name)
        for dist_name_normalized in self.projects:
            dist_dependencies = self.get_dependencies(dist_name_normalized)
            if target_dist_name_normalized in dist_dependencies:
                dependents.append(self.get_name(dist_name_normalized))
        return dependents

    def get_project(self, dist_name: str):
        return self.projects[_pdep.normalize_distribution_name(dist_name)]

    def get_git(self, dist_name: str) -> _gittidy.Git:
        project = self.get_project(dist_name)
        if not project["git"]:
            project["git"] = _gittidy.Git(path=self.get_path(dist_name), logger=_logger)
        return project["git"]

    def get_path(self, dist_name: str) -> _Path:
        return self.get_project(dist_name)["path"]

    def get_pyproject(self, dist_name: str):
        return self.get_project(dist_name)["pyproject"]

    def get_version(self, dist_name: str):
        return self.get_pyproject(dist_name)["project"]["version"]

    def get_dependencies(self, dist_name: str, normalize: bool = True):
        transformer = _pdep.normalize_distribution_name if normalize else lambda x: x
        return [
            transformer(_Req(dep).name) for dep in self.get_pyproject(dist_name)["project"].get("dependencies", [])
        ]

    def get_name(self, dist_name: str):
        return self.get_pyproject(dist_name)["project"]["name"]

    def get_changed_projects(self):
        changed_projects = []
        for dist_name, project in self.projects.items():
            git = self.get_git(dist_name)
            if git.has_changes():
                changed_projects.append(self.get_name(dist_name))
        return changed_projects
