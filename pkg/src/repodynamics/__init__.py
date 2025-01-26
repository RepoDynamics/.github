from __future__ import annotations as _annotations

from typing import TYPE_CHECKING as _TYPE_CHECKING
from pathlib import Path as _Path

from loggerman import logger as _logger
import pyserials as _ps

from repodynamics.manager import OrganizationManager

if _TYPE_CHECKING:
    from typing import Sequence


def from_directory(
    path: str | _Path = "/Volumes/T7/Projects/GitHub Repos/RepoDynamics",
    pyproject_path: str = "pkg/pyproject.toml",
    exclude: Sequence[str] | None = (
        '_OrganizationRepo(.github)',
        '.archived',
        'BinderDocker',
        'DocsMan',
        'FixMan',
        'MetaTemplates',
        'PyPackIT',
        'PyPackIT-Template',
        'PyPackIT-Template(ORIG DATA)',
        'SphinxDocs',
    ),
) -> OrganizationManager:
    exclude = [name.casefold() for name in exclude]
    loaded = []
    excluded = []
    no_pyproject = []
    pyprojects = {}
    for sub_path in _Path(path).iterdir():
        if not sub_path.is_dir():
            continue
        if sub_path.name.casefold() in exclude:
            excluded.append(sub_path)
            continue
        path_pyproject = sub_path / pyproject_path
        if not path_pyproject.is_file():
            no_pyproject.append(sub_path)
            continue
        pyproject = _ps.read.toml_from_file(path_pyproject, as_dict=False)
        pyprojects[path_pyproject] = pyproject
        loaded.append(sub_path)
    logs = ["Loaded directories:", "\n".join(f"- {d}" for d in sorted(loaded))]
    if no_pyproject:
        logs.extend(["Directories without pyproject file:", "\n".join(f"- {d}" for d in sorted(no_pyproject))])
    if excluded:
        logs.extend(["Excluded directories:", "\n".join(f"- {d}" for d in sorted(excluded))])
    _logger.info("Directory Load", *logs)
    return OrganizationManager(pyprojects)