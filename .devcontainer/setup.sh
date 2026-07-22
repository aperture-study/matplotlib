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

# setuptools_scm derives the version from the nearest reachable git tag. Codespace clones do
# not fetch tags, and if the clone is also shallow there is no history for a tag to be
# reachable *through* — fetching tag refs alone would not help. Handle both.
if [ "$(git rev-parse --is-shallow-repository 2>/dev/null)" = "true" ]; then
  echo "shallow clone detected — unshallowing so setuptools_scm can resolve a version"
  git fetch --unshallow --tags origin || warn "could not unshallow the clone"
else
  git fetch --tags origin || warn "could not fetch git tags"
fi

if described=$(git describe --tags --abbrev=8 2>/dev/null); then
  echo "nearest tag: ${described}"
else
  warn "no reachable git tags — setuptools_scm will fall back to 0.1.0.dev1 instead of 3.8.0.dev*"
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
