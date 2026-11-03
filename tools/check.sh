#!/usr/bin/env bash
set -euo pipefail
repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_dir"
export MOG_TOOL_DIR=${MOG_TOOL_DIR:-"$repo_dir/.tools"}
bash tools/bootstrap.sh
export PATH="$MOG_TOOL_DIR/bin:$PATH"
mkdir -p build
luau-analyze src/shared/Config.luau src/shared/Economy.luau src/shared/Format.luau \
 src/server/SessionStore.luau src/server/RateLimiter.luau src/server/ServerSettings.luau tests/run.luau
python3 - <<'PY'
from pathlib import Path
import subprocess
paths=sorted(str(p) for p in Path('src').rglob('*.luau'))
subprocess.run(['luau-compile','--null',*paths],check=True)
print(f'Compiled all {len(paths)} source scripts.')
PY
luau tests/run.luau
python3 tools/test_contracts.py
python3 tools/build_world.py --check
rojo build default.project.json --output build/MogMode.rbxl
rojo build default.project.json --output build/MogMode.rbxlx
rojo sourcemap default.project.json --output build/sourcemap.json
python3 tools/verify_project.py
echo 'All CLI checks passed. Roblox Studio playtesting remains; see docs/STUDIO_TESTING.md.'
