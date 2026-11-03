#!/usr/bin/env python3
from pathlib import Path
import shutil
import subprocess

ROOT=Path(__file__).resolve().parents[1]


def wrapped(name,path,prefix=''):
    return f'\nlocal {name} = (function()\n{prefix}\n{(ROOT/path).read_text()}\nend)()\n'


def main():
    luau=shutil.which('luau')
    if not luau: raise SystemExit('luau not on PATH')
    base=(ROOT/'tests/roblox-mock.luau').read_text()
    ui=base+wrapped('UI','src/client/UI.luau')+wrapped('PetFactory','src/client/PetFactory.luau')+(ROOT/'tests/ui-scenarios.luau').read_text()
    modules=wrapped('WorldService','src/server/WorldService.luau')+wrapped('Commerce','src/server/Commerce.luau')+wrapped('MogPose','src/client/MogPose.luau','local os={clock=function() return poseClock.Now end}')
    services=base+(ROOT/'tests/service-scenarios.luau').read_text().replace('-- MODULES --',modules)
    (ROOT/'build').mkdir(exist_ok=True)
    for name,content in [('ui',ui),('services',services)]:
        out=ROOT/'build'/f'{name}-harness.luau'; out.write_text(content)
        subprocess.run([luau,str(out)],cwd=ROOT,check=True)


if __name__=='__main__': main()
