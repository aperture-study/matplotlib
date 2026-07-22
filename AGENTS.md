# AGENTS.md

## Environment

This repository is checked out at an older commit (matplotlib `3.8.0.dev`, ~mid-2023)
and is installed as an editable dev build pointing at the local `lib/`. A `.venv/` is
already set up. Run everything through it:

```bash
.venv/bin/python -m pytest lib/matplotlib/tests/...
```

## Dependency pins (required)

matplotlib's test config treats warnings as errors, so newer transitive dependencies
break the suite with deprecation-warning-as-error failures (not real test failures).
The venv is pinned to era-appropriate versions. **`study-constraints.txt` in the repo
root is the authoritative list** — the table below explains the ones that bite:

| Package         | Version  | Reason |
|-----------------|----------|--------|
| `numpy`         | `1.26.4` | The extensions compile against numpy 1.x headers; numpy 2 is an ABI break that only surfaces at `import matplotlib.pyplot` |
| `pyparsing`     | `3.0.9`  | Newer versions warn on the old `enablePackrat`/`parseString` API → collection error |
| `setuptools`    | `65.5.0` | Era-appropriate; this tree predates the Meson port and needs the old `setup.py` chain |
| `setuptools_scm`| `8.3.1`  | 10.x shims over `vcs_versioning`, which warns on the `release-branch-semver` scheme → error when `savefig` writes the version into PNG metadata. Also ensure the stray `vcs-versioning` package is not installed |
| `pytest`        | `7.4.4`  | Era-appropriate; newer majors untested here |
| `pytest-xdist`  | `3.5.0`  | Parallel test runner |
| `pytest-timeout`| `2.3.1`  | Used by the suite |

If you reinstall or upgrade deps, install through the constraints file or tests will
fail on warnings rather than real regressions:

```bash
.venv/bin/python -m pip install -c study-constraints.txt <package>
```

## Running tests

- Run a directory, single file, or a `-k` filter — all work with `-n auto` (parallel).
- Known `pytest-xdist` quirk: passing **multiple explicit file-path arguments** at once
  collects 0 items. Use a directory, a `-k` filter, a single file, or serial (`-p no:xdist`)
  instead.

```bash
# examples that work
.venv/bin/python -m pytest lib/matplotlib/tests/test_text.py -n auto
.venv/bin/python -m pytest lib/matplotlib/tests/ -k antialias -n auto
```
