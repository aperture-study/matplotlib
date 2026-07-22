#!/usr/bin/env bash
# Acceptance checks for a study codespace. Run from the repo root:
#
#   bash .devcontainer/verify.sh
#
# Covers everything checkable from a terminal. Two things it cannot check, because no script
# can: that the extension activated (needs a window reload) and that the map paints. Those are
# steps 2 and 4 of the participant runbook.
set -uo pipefail
cd "$(dirname "$0")/.."

pass=0; fail=0
ok()   { echo "  PASS  $1"; pass=$((pass+1)); }
bad()  { echo "  FAIL  $1"; fail=$((fail+1)); }
check(){ if eval "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1"; fi; }

echo "== secret =="
# Must arrive from the org Codespaces secret. If this fails, Aperture starts and then cannot
# reach a model, which looks like a broken image rather than a missing secret.
check "ANTHROPIC_API_KEY is set" '[ -n "${ANTHROPIC_API_KEY:-}" ]'
if grep -rq 'localEnv' .devcontainer/ 2>/dev/null; then
  bad "\${localEnv:...} found in .devcontainer — it resolves empty here and shadows the secret"
else
  ok "no \${localEnv:...} anywhere in .devcontainer"
fi

echo "== image =="
check "bun is 1.3.14"                  '[ "$(bun --version)" = "1.3.14" ]'
check "aperture wrapper is on PATH"    'command -v aperture'
check "VSIX at its fixed path"         '[ -f /opt/aperture/aperture.vsix ]'
check "Aperture source at /opt/aperture" '[ -d /opt/aperture/packages/opencode ]'

echo "== matplotlib tarball cache (seeded in the image) =="
for sha in 0a3c7dfbda6da1e8fce29232e8e96d987ababbbf71ebc8c75659e4132c367014 \
           b5c2d7eb833278881b952c8a52d20179eab87766b00b865000469a45c1838b7e; do
  f="$HOME/.cache/matplotlib/$sha"
  if [ -f "$f" ] && [ "$(sha256sum "$f" | cut -d' ' -f1)" = "$sha" ]; then
    ok "cache ${sha:0:12}… present and intact"
  else
    bad "cache ${sha:0:12}… missing or corrupt"
  fi
done

echo "== workspace =="
check "venv exists" '[ -x .venv/bin/python ]'
if [ -f setupext.py ]; then
  # matplotlib
  .venv/bin/python - <<'PY' && ok "matplotlib imports, version and freetype correct" || bad "matplotlib import/version/freetype check"
import matplotlib, matplotlib.pyplot
from matplotlib import ft2font
assert matplotlib.__version__.startswith("3.8.0.dev"), matplotlib.__version__
assert ft2font.__freetype_version__ == "2.6.1", ft2font.__freetype_version__
print(matplotlib.__version__, ft2font.__freetype_version__)
PY
  check "test suite collects" '.venv/bin/python -m pytest lib/matplotlib/tests/test_text.py --collect-only -q'
else
  # retro-game-store
  check "flask is 3.1.3" '[ "$(.venv/bin/python -c "import importlib.metadata as m;print(m.version(\"flask\"))")" = "3.1.3" ]'
  check "store.db seeded" '[ -s store.db ]'
fi

echo "== extension install path (record which one fired) =="
if command -v code >/dev/null 2>&1; then
  echo "  NOTE  'code' IS on PATH here — attach.sh used the CLI"
else
  echo "  NOTE  'code' is NOT on PATH — attach.sh used the VSIX-unpack fallback"
fi
check "extension present in the server's extension dir" \
      'ls -d "$HOME"/.vscode-remote/extensions/sst-dev.aperture-* || code --list-extensions | grep -qi aperture'

echo
echo "$pass passed, $fail failed"
echo
echo "Still to check by hand (no script can):"
echo "  1. Reload the window, then confirm 'Aperture: Repaint active editor' is in the palette."
echo "  2. Run 'aperture' — it should listen on 4096."
echo "  3. Open a source file — colored strips should appear in the left gutter."
[ "$fail" -eq 0 ]
