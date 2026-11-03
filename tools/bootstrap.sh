#!/usr/bin/env bash
set -euo pipefail
repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
tool_dir=${MOG_TOOL_DIR:-"$repo_dir/.tools"}
test "$(uname -sm)" = 'Linux x86_64' || { echo 'Use the official desktop Rojo/Luau releases on other platforms.' >&2; exit 1; }
mkdir -p "$tool_dir/bin" "$tool_dir/downloads"
tool_tmp=$(mktemp -d "$tool_dir/.install.XXXXXX")
trap 'rm -rf "$tool_tmp"' EXIT
fetch() {
 local name=$1 digest=$2 url=$3
 if ! printf '%s  %s\n' "$digest" "$tool_dir/downloads/$name" | sha256sum --check --status 2>/dev/null; then
  curl --fail --location --silent --show-error --retry 2 --connect-timeout 15 --max-time 180 "$url" -o "$tool_tmp/$name"
  printf '%s  %s\n' "$digest" "$tool_tmp/$name" | sha256sum --check
  mv "$tool_tmp/$name" "$tool_dir/downloads/$name"
 fi
 printf '%s  %s\n' "$digest" "$tool_dir/downloads/$name" | sha256sum --check
}
fetch rojo-7.7.1-linux-x86_64.zip 00feb4fa0829a1dd72b49df2639da519a352bfe13cadcd83969e2ba2bb5693c4 https://github.com/rojo-rbx/rojo/releases/download/v7.7.1/rojo-7.7.1-linux-x86_64.zip
fetch luau-0.745-ubuntu.zip 186e5ddaa2b048ebc7390c11ed1b00c04e7d3beaffed429250329e3575d2ece2 https://github.com/luau-lang/luau/releases/download/0.745/luau-ubuntu.zip
python3 - "$tool_dir" "$tool_tmp" <<'PY'
from pathlib import Path
import sys, zipfile
root,stage=map(Path,sys.argv[1:])
for filename,tools in {'rojo-7.7.1-linux-x86_64.zip':['rojo'],'luau-0.745-ubuntu.zip':['luau','luau-analyze','luau-compile','luau-ast']}.items():
 with zipfile.ZipFile(root/'downloads'/filename) as archive:
  for tool in tools:
   names=[n for n in archive.namelist() if Path(n).name==tool]
   if len(names)!=1: raise RuntimeError(f'Missing or ambiguous tool: {tool}')
   p=stage/tool; p.write_bytes(archive.read(names[0])); p.chmod(0o755); p.replace(root/'bin'/tool)
PY
"$tool_dir/bin/rojo" --version
