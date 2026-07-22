#!/usr/bin/env bash
# Build matplotlib 3.8.0.dev from this tree. Runs as updateContentCommand, so the prebuild
# absorbs the compile (minutes even on 4 cores) and it must be idempotent. It must not depend
# on ANTHROPIC_API_KEY, which is not available during a prebuild.
set -euo pipefail
cd "$(dirname "$0")/.."

# setuptools_scm derives the version from git tags, and codespace clones do not fetch tags by
# default. Without them the version resolution goes sideways and never reports 3.8.0.dev*.
git fetch --tags --quiet origin || echo "warning: could not fetch tags; version may be wrong" >&2

PY=python3.11
command -v "$PY" >/dev/null || PY=python3

if [ ! -x .venv/bin/python ]; then
  "$PY" -m venv .venv
fi
VENV=.venv/bin/python

"$VENV" -m pip install --quiet --upgrade "pip==24.*"

# Build deps go in first so that --no-build-isolation below has them, and pip cannot resolve
# 2026 versions of the build chain behind our back.
"$VENV" -m pip install --quiet -c study-constraints.txt \
    setuptools setuptools_scm wheel numpy pybind11 certifi

# Editable install against the local lib/. freetype 2.6.1 and qhull 2020.2 are compiled from
# source here; the image pre-seeds ~/.cache/matplotlib/<sha256> with both tarballs so this
# never depends on a live fetch. Keep freetype vendored — mpl pins 2.6.1 for pixel-exact image
# comparison and the system freetype breaks the image tests.
"$VENV" -m pip install --no-build-isolation -c study-constraints.txt -e .

# The test runner is pinned alongside everything else; participants are told to run the suite.
"$VENV" -m pip install --quiet -c study-constraints.txt pytest pytest-xdist pytest-timeout

# An install that "worked" proves nothing until pyplot imports (that is where a numpy ABI
# break would surface) and until the suite can collect.
"$VENV" - <<'PY'
import matplotlib, matplotlib.pyplot  # noqa: F401
from matplotlib import ft2font
print("matplotlib", matplotlib.__version__)
print("freetype  ", ft2font.__freetype_version__)
assert matplotlib.__version__.startswith("3.8.0.dev"), "unexpected version — are git tags present?"
assert ft2font.__freetype_version__ == "2.6.1", "expected the vendored freetype, not the system one"
PY

"$VENV" -m pytest lib/matplotlib/tests/test_text.py --collect-only -q >/dev/null \
  && echo "test suite collects" \
  || echo "warning: test collection failed — check the dependency pins" >&2
