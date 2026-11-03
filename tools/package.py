#!/usr/bin/env python3
"""Copy the verified Studio build and create a complete source ZIP, without .git/caches."""
from pathlib import Path
import argparse
import hashlib
import json
import shutil
import subprocess
import zipfile

ROOT=Path(__file__).resolve().parents[1]


def main():
    parser=argparse.ArgumentParser(); parser.add_argument('--output',type=Path,default=ROOT/'build/MOG-MODE-source.zip'); args=parser.parse_args()
    subprocess.run(['python3','tools/verify_project.py'],cwd=ROOT,check=True)
    out=ROOT/'releases'; out.mkdir(exist_ok=True)
    shutil.copyfile(ROOT/'build/MogMode.rbxl',out/'MogMode.rbxl')
    source_paths=sorted([ROOT/'default.project.json',*(ROOT/'src').rglob('*'),*(ROOT/'assets').rglob('*')])
    source={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in source_paths if p.is_file()}
    manifest={'game':'MOG MODE','rojo':'7.7.1','luau':'0.745','game_sha256':hashlib.sha256((out/'MogMode.rbxl').read_bytes()).hexdigest(),'source_sha256':source,'studio_playtested':False}
    (out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    names=subprocess.check_output(['git','ls-files','--cached','--others','--exclude-standard','-z'],cwd=ROOT).decode().split('\0')
    files=[]
    for name in sorted(set(names)):
        if not name: continue
        p=ROOT/name
        if not p.is_file(): continue
        p.resolve().relative_to(ROOT.resolve())
        assert not any(c in ['.git','.aws','.codex','.agents','.tools','__pycache__'] for c in p.parts)
        files.append(p)
    args.output.parent.mkdir(parents=True,exist_ok=True)
    with zipfile.ZipFile(args.output,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as archive:
        for p in files: archive.write(p,'MOG-MODE/'+str(p.relative_to(ROOT)))
    with zipfile.ZipFile(args.output) as archive:
        assert archive.testzip() is None
        for required in ['default.project.json','README.md','src/client/UI.luau','src/server/init.server.luau','releases/MogMode.rbxl','releases/manifest.json','tests/run.luau']:
            assert 'MOG-MODE/'+required in archive.namelist(),required
    print(f'Packaged {len(files)} files: {args.output} ({args.output.stat().st_size:,} bytes)')


if __name__=='__main__': main()
