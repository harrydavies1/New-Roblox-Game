#!/usr/bin/env python3
from pathlib import Path
import shutil
import subprocess
import json

ROOT=Path(__file__).resolve().parents[1]


def wrapped(name,path,prefix=''):
    return f'\nlocal {name} = (function()\n{prefix}\n{(ROOT/path).read_text()}\nend)()\n'


def main():
    luau=shutil.which('luau')
    if not luau: raise SystemExit('luau not on PATH')
    base=(ROOT/'tests/roblox-mock.luau').read_text()
    ui=base+wrapped('UI','src/client/UI.luau')+wrapped('PetFactory','src/client/PetFactory.luau')+(ROOT/'tests/ui-scenarios.luau').read_text()
    modules=wrapped('WorldService','src/server/WorldService.luau')+wrapped('Commerce','src/server/Commerce.luau')+wrapped('MogPose','src/client/MogPose.luau','local os={clock=function() return poseClock.Now end}')
    modules+=wrapped('ObbyService','src/server/ObbyService.luau','local os={clock=function() return obbyClock.Now end}; local script={Parent={ObbyRun=true}}; local require=function() return ObbyRun end')
    modules+=wrapped('Storage','src/server/Storage.luau','local script={Parent={SessionStore=true}}; local require=function() return Store end')
    modules+=wrapped('Audio','src/client/Audio.luau','local task=audioTask; local os={clock=function() return audioClock.Now end}')
    modules+=wrapped('WorldVisibility','src/client/WorldVisibility.luau')
    modules+=wrapped('CourseGuide','src/client/CourseGuide.luau')
    modules+=wrapped('Effects','src/client/Effects.luau')
    services=base+(ROOT/'tests/service-scenarios.luau').read_text().replace('-- MODULES --',modules)+(ROOT/'tests/new-service-scenarios.luau').read_text()
    boot_modules=wrapped('BootWorldService','src/server/WorldService.luau')
    boot_modules+=wrapped('BootObbyService','src/server/ObbyService.luau','local os=bootOs; local script={Parent={ObbyRun=true}}; local require=function() return ObbyRun end')
    boot_modules+=wrapped('BootCommerce','src/server/Commerce.luau','local os=bootOs; local task=bootTasks')
    boot_modules+=wrapped('BootStorage','src/server/Storage.luau','local os=bootOs; local script={Parent={SessionStore=true}}; local require=function() return Store end')
    boot_source='\n(function()\nlocal os=bootOs; local task=bootTasks; local require=bootRequire; local script=bootScript\n'+(ROOT/'src/server/init.server.luau').read_text()+'\nend)()\n'
    services+=(ROOT/'tests/bootstrap-scenarios.luau').read_text().replace('-- BOOT MODULES --',boot_modules).replace('-- BOOT SOURCE --',boot_source)
    audio_prefix='local audioClock={Now=0}; local audioQueue={}; local audioTask={spawn=function(f) f() end,delay=function(t,f) table.insert(audioQueue,{At=audioClock.Now+t,Run=f}) end}\n'
    audio_prefix+='services.SoundService=Instance.new("SoundService"); services.ContentProvider={PreloadAsync=function() end}; services.Debris={AddItem=function() end}\n'
    audio_modules=wrapped('Audio','src/client/Audio.luau','local task=audioTask; local os={clock=function() return audioClock.Now end}')
    audio_modules+=wrapped('Music','src/client/Music.luau','local os={clock=function() return audioClock.Now end}')
    audio=base+audio_prefix+audio_modules+(ROOT/'tests/audio-scenarios.luau').read_text()
    (ROOT/'build').mkdir(exist_ok=True)
    for name,content in [('ui',ui),('services',services),('audio',audio)]:
        out=ROOT/'build'/f'{name}-harness.luau'; out.write_text(content)
        result=subprocess.run([luau,str(out)],cwd=ROOT,text=True,capture_output=True)
        for line in result.stdout.splitlines():
            if line.startswith('UI_LAYOUT '):
                layout=json.loads(line[len('UI_LAYOUT '):])
                label=layout.get('Name',str(int(layout['Width'])))
                assert all(c.isalnum() or c=='-' for c in label)
                (ROOT/'build'/f'ui-layout-{label}.json').write_text(json.dumps(layout,indent=2)+'\n')
            else: print(line)
        if result.stderr: print(result.stderr,end='')
        result.check_returncode()


if __name__=='__main__': main()
