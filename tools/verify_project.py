#!/usr/bin/env python3
from pathlib import Path
import json
import struct
import xml.etree.ElementTree as ET

ROOT=Path(__file__).resolve().parents[1]


def props(item): return {p.get('name'):p for p in item.find('Properties')}
def name(item): return props(item)['Name'].text
def child(item,key):
    nodes=[i for i in item.findall('Item') if name(i)==key]
    assert len(nodes)==1,(key,len(nodes))
    return nodes[0]


def main():
    binary=(ROOT/'build/MogMode.rbxl').read_bytes()
    assert binary.startswith(b'<roblox!\x89\xff\r\n\x1a\n')
    classes,instances=struct.unpack_from('<II',binary,16)
    assert classes>=10 and instances>=1700
    root=ET.parse(ROOT/'build/MogMode.rbxlx').getroot()
    world=child(child(root,'Workspace'),'MogWorld')
    part_count=0
    for index,key in enumerate(['meadow','candy','coral','cosmos']):
        island=child(world,key); markers=child(island,'Markers')
        cf=props(child(markers,'Spawn'))['CFrame']
        assert float(cf.findtext('X'))==(620 if index%2 else 0)
        assert float(cf.findtext('Z'))==(620 if index>=2 else 0)+29
        child(markers,'PetShop'); child(markers,'Quests')
        if key=='meadow': child(markers,'Rebirth')
        shards=child(island,'Shards').findall('Item'); assert len(shards)==13
        for c in shards: assert props(c)['CanCollide'].text=='false'
        gates={name(i) for i in child(island,'Portals').findall('Item')}
        assert gates==({'candy','coral','cosmos'} if key=='meadow' else {'meadow'})
        for n in ['MogTotemHead','MogTotemJaw','AuraPendant']: child(child(island,'Details'),n)
        if key=='candy': assert any(name(i)=='BroteinBarbell' for i in child(island,'Details').findall('Item'))
        steps=[i for i in child(island,'Landscape').findall('Item') if name(i)=='SkyStep']; assert len(steps)==8
        last=None
        for step in steps:
            cf=props(step)['CFrame']; p=tuple(float(cf.findtext(a)) for a in ['X','Y','Z'])
            if last: assert 0<p[1]-last[1]<3 and ((p[0]-last[0])**2+(p[2]-last[2])**2)**.5<10
            last=p
        for i in island.iter('Item'):
            if i.get('class')=='Part': assert props(i)['Anchored'].text=='true'; part_count+=1
    assert part_count==1690,part_count
    scripts=[i for i in root.iter('Item') if i.get('class') in ['Script','LocalScript','ModuleScript']]
    paths=sorted((ROOT/'src').rglob('*.luau')); assert len(scripts)==len(paths)==14
    embedded={props(i)['Source'].text:i.get('class') for i in scripts}
    for path in paths:
        cls='Script' if path.name.endswith('.server.luau') else 'LocalScript' if path.name.endswith('.client.luau') else 'ModuleScript'
        assert embedded.get(path.read_text())==cls,f'Missing/wrong embedded script: {path}'
    server=child(child(root,'ServerScriptService'),'MogServer')
    for key in ['Commerce','WorldService','SessionStore','RateLimiter','ServerSettings']: child(server,key)
    client=child(child(child(root,'StarterPlayer'),'StarterPlayerScripts'),'MogClient')
    for key in ['UI','PetFactory','MogPose','Effects']: child(client,key)
    source_map=json.loads((ROOT/'build/sourcemap.json').read_text()); mapped=set()
    def walk(node):
        for p in node.get('filePaths',[]): mapped.add((ROOT/p).resolve())
        for c in node.get('children',[]): walk(c)
    walk(source_map)
    assert all(p.resolve() in mapped for p in paths)
    assert not any('tests' in p.parts for p in mapped)
    print(f'PASS: complete place with {len(scripts)} scripts, {part_count} anchored map parts, 52 crystals, all portals/spawns and source mappings')


if __name__=='__main__': main()
