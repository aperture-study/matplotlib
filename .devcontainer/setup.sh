#!/usr/bin/env bash
# Build matplotlib 3.8.0.dev from this tree. Runs as updateContentCommand, so the prebuild
# absorbs the compile (minutes even on 4 cores) and it must be idempotent. It must not depend
# on ANTHROPIC_API_KEY, which is not available during a prebuild.
#
# DELIBERATELY NEVER EXITS NON-ZERO. A failing updateContentCommand does not merely log an
# error — Codespaces tears the container down and replaces it with a bare recovery container,
# so the participant loses the image, the venv, and ~16 minutes, and gets an environment with
# no Aperture in it. A wrong dependency version is a problem worth reporting loudly; it is not
# worth destroying the codespace over. Everything here reports and continues, and
# .devcontainer/verify.sh is the gate the facilitator runs before handing over.
set -uo pipefail
cd "$(dirname "$0")/.."

problems=0
warn() { echo "SETUP PROBLEM: $*" >&2; problems=$((problems + 1)); }

# --- version resolution ------------------------------------------------------
#
# setuptools_scm derives the version from the nearest *reachable* git tag. Codespace clones
# are shallow: all 150 tags are present but no history connects HEAD to any of them, so
# `git describe` fails and setuptools_scm falls back to 0.1.0.dev1 rather than 3.8.0.dev*.
# Fetching tags does not help — the tags were never missing, the history was.
#
# We do not --unshallow: that pulls matplotlib's full history, ~486 MiB, on every single
# codespace create, for a version string. Instead we pin the version setuptools_scm *would*
# have computed at study-base (26224d9606 = v3.7.1 + 1194 commits, under the
# release-branch-semver and node-and-date schemes matplotlib configures in setup.py:342).
#
# This sticks at runtime for free: matplotlib's own _get_version()
# (lib/matplotlib/__init__.py:213) skips setuptools_scm when .git/shallow exists and reads
# the build-time _version.py, so the pinned value is what participants see all session.
#
# Preferred path is still real resolution — the pin is only used when tags are unreachable,
# so a full clone elsewhere behaves normally.
STUDY_BASE_VERSION="3.8.0.dev1194+g26224d96"

git fetch --tags --quiet origin 2>/dev/null || true
if described=$(git describe --tags --abbrev=8 2>/dev/null); then
  echo "tags reachable (${described}) — letting setuptools_scm resolve the version"
else
  echo "shallow clone, no reachable tags — pinning version to ${STUDY_BASE_VERSION}"
  export SETUPTOOLS_SCM_PRETEND_VERSION_FOR_MATPLOTLIB="$STUDY_BASE_VERSION"
fi

PY=python3.11
command -v "$PY" >/dev/null || PY=python3

if [ ! -x .venv/bin/python ]; then
  "$PY" -m venv .venv || warn "venv creation failed"
fi
VENV=.venv/bin/python
[ -x "$VENV" ] || { echo "SETUP ABORTED: no venv to install into" >&2; exit 0; }

"$VENV" -m pip install --quiet --upgrade "pip==24.*" || warn "pip pin failed"

# Build deps first so --no-build-isolation below has them, and pip cannot resolve 2026
# versions of the build chain behind our back.
"$VENV" -m pip install --quiet -c study-constraints.txt \
    setuptools setuptools_scm wheel numpy pybind11 certifi || warn "build-chain install failed"

# Editable install against the local lib/. freetype 2.6.1 and qhull 2020.2 compile from
# source here; the image pre-seeds ~/.cache/matplotlib/<sha256> with both tarballs so this
# never depends on a live fetch. Keep freetype vendored — mpl pins 2.6.1 for pixel-exact
# image comparison and the system freetype breaks the image tests.
"$VENV" -m pip install --no-build-isolation -c study-constraints.txt -e . || warn "matplotlib build failed"

# The test runner is pinned alongside everything else; participants are told to run the suite.
"$VENV" -m pip install --quiet -c study-constraints.txt pytest pytest-xdist pytest-timeout \
  || warn "test runner install failed"

# An install that "worked" proves nothing until pyplot imports — that is where a numpy ABI
# break would surface — and until the version and freetype are the ones we intended.
"$VENV" - <<'PY' || warn "matplotlib import/version/freetype check failed"
import sys
import matplotlib, matplotlib.pyplot  # noqa: F401
from matplotlib import ft2font
print("matplotlib", matplotlib.__version__)
print("freetype  ", ft2font.__freetype_version__)
bad = []
if not matplotlib.__version__.startswith("3.8.0.dev"):
    bad.append(f"version is {matplotlib.__version__}, expected 3.8.0.dev* (git tags missing?)")
if ft2font.__freetype_version__ != "2.6.1":
    bad.append(f"freetype is {ft2font.__freetype_version__}, expected the vendored 2.6.1")
for b in bad:
    print("  !!", b)
sys.exit(1 if bad else 0)
PY

"$VENV" -m pytest lib/matplotlib/tests/test_text.py --collect-only -q >/dev/null 2>&1 \
  || warn "test collection failed — check the dependency pins"

if [ "$problems" -gt 0 ]; then
  echo
  echo "=============================================================="
  echo " setup finished with ${problems} problem(s) — see SETUP PROBLEM above."
  echo " The codespace is still usable. Run .devcontainer/verify.sh for detail."
  echo "=============================================================="
fi

# Always succeed: see the header. verify.sh is the gate, not this script.
exit 0
