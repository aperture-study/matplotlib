#!/usr/bin/env bash
# Install the Aperture VS Code extension. Runs on every attach; both paths are idempotent.
#
# `code` is not reliably on PATH inside lifecycle hooks, so this tries the CLI first and falls
# back to unpacking the VSIX straight into the server's extension directory. Either way the
# extension only activates after a **window reload** — no lifecycle hook can trigger that, so
# it is a step in the participant runbook.
set -uo pipefail

VSIX=/opt/aperture/aperture.vsix
EXT_DIR="$HOME/.vscode-remote/extensions/sst-dev.aperture-0.0.1"

if [ ! -f "$VSIX" ]; then
  echo "Aperture VSIX missing at $VSIX — wrong image tag?" >&2
  exit 0
fi

if command -v code >/dev/null 2>&1; then
  if code --install-extension "$VSIX" --force; then
    echo "Aperture extension installed. Reload the window to activate it."
    exit 0
  fi
  echo "code --install-extension failed; falling back to unpacking the VSIX" >&2
fi

# A VSIX is a zip whose `extension/` directory is the extension itself. python3 rather than
# unzip, since python3 is guaranteed present by the Dockerfile.
mkdir -p "$EXT_DIR"
python3 - "$VSIX" "$EXT_DIR" <<'PY'
import sys, zipfile, pathlib
vsix, dest = sys.argv[1], pathlib.Path(sys.argv[2])
with zipfile.ZipFile(vsix) as z:
    for info in z.infolist():
        if info.is_dir() or not info.filename.startswith("extension/"):
            continue
        target = dest / info.filename[len("extension/"):]
        target.parent.mkdir(parents=True, exist_ok=True)
        with z.open(info) as src, open(target, "wb") as out:
            out.write(src.read())
print(f"unpacked {vsix} -> {dest}")
PY

echo "Aperture extension staged. Reload the window to activate it."
