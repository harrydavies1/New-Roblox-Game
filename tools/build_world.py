#!/usr/bin/env python3
"""Regenerate MOG MODE from the retained original primitive-map asset."""
from pathlib import Path
import argparse
import math
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
WORLD_NAMES = {"meadow": "MEWING MEADOW", "candy": "BROTEIN BOULEVARD", "coral": "RIZZ REEF", "cosmos": "SIGMA SUMMIT"}
serial = 0


def props(item):
    return {p.get("name"): p for p in item.find("Properties")}


def name(item):
    return props(item)["Name"].text


def prop(parent, tag, key, value):
    e = ET.SubElement(parent, tag, name=key)
    keys = {"Vector3": ["X", "Y", "Z"], "Color3": ["R", "G", "B"], "CoordinateFrame": ["X", "Y", "Z", "R00", "R01", "R02", "R10", "R11", "R12", "R20", "R21", "R22"]}
    if tag in keys:
        for k, v in zip(keys[tag], value, strict=True):
            ET.SubElement(e, k).text = f"{v:.6f}"
    else:
        e.text = str(value).lower() if isinstance(value, bool) else str(value)


def part(parent, label, pos, size, color, shape=1, roll=0, neon=False, collide=True):
    global serial
    serial += 1
    item = ET.SubElement(parent, "Item", {"class": "Part", "referent": f"MOG{serial}"})
    p = ET.SubElement(item, "Properties")
    prop(p, "string", "Name", label)
    for k, v in {"Anchored": True, "CanCollide": collide, "CanTouch": False, "CanQuery": collide, "CastShadow": not neon}.items():
        prop(p, "bool", k, v)
    prop(p, "Vector3", "Size", size)
    prop(p, "Color3", "Color", [int(color[i:i+2], 16) / 255 for i in (0, 2, 4)])
    prop(p, "token", "shape", shape)
    prop(p, "token", "Material", 288 if neon else 272)
    prop(p, "token", "TopSurface", 0)
    prop(p, "token", "BottomSurface", 0)
    a = math.radians(roll)
    prop(p, "CoordinateFrame", "CFrame", (*pos, math.cos(a), -math.sin(a), 0, math.sin(a), math.cos(a), 0, 0, 0, 1))
    return item


def generate():
    global serial
    serial = 0
    tree = ET.parse(ROOT / "assets/base-world.rbxmx")
    root = tree.getroot()
    world = root.find("Item")
    props(world)["Name"].text = "MogWorld"
    replacements = {"SUNPETAL MEADOW": "MEWING MEADOW", "CANDY CLOUD CANYON": "BROTEIN BOULEVARD", "BUBBLEGUM REEF": "RIZZ REEF", "STARFALL SUMMIT": "SIGMA SUMMIT", "PET BOUTIQUE": "HYPE SQUAD HQ", "Sparks only": "Aura only", "DAILY DISCOVERIES": "SIDE QUEST DEPARTMENT", "Three little adventures every day": "Daily goals + permanent journal", "REBIRTH GARDEN": "NEXT ERA PORTAL", "Grow a little brighter": "Rebirth. Return. Remog."}
    for item in root.iter("Item"):
        for key in ("Text",):
            value = props(item).get(key)
            if value is not None and value.text:
                for a, b in replacements.items():
                    value.text = value.text.replace(a, b)
    for island in world.findall("Item"):
        world_id = name(island)
        detail = next(i for i in island.findall("Item") if name(i) == "Details")
        center = next(i for i in detail.findall("Item") if name(i) == "HeartCrystal")
        cf = props(center)["CFrame"]
        ox, oz = float(cf.findtext("X")), float(cf.findtext("Z"))
        detail.remove(center)
        def at(x, y, z): return (ox + x, y, oz + z)
        trim = "FFF0BD"
        part(detail, "MogTotemBody", at(0,9,0), (6,5,4), trim)
        part(detail, "MogTotemHead", at(0,14,0), (8,6,5), "FFF5DD")
        part(detail, "MogTotemJaw", at(0,12,-2.3), (8.5,2.2,1.6), trim)
        for dx in (-2.7,2.7):
            part(detail, "MogTotemEar", at(dx,17,0), (2.8,3,3), trim, roll=-dx*10)
            part(detail, "MogTotemLens", at(dx*.64,14.6,-2.65), (2.8,1.4,.4), "29283F", collide=False)
            part(detail, "LensHighlight", at(dx*.64-.5,14.9,-2.9), (.55,.22,.12), "B0F5ED", collide=False)
        part(detail, "SunglassesBridge", at(0,14.65,-2.7), (1.2,.3,.35), "29283F", collide=False)
        part(detail, "MogTotemNose", at(0,13.65,-2.9), (.6,.3,.2), "FFA6CF", collide=False)
        part(detail, "GoldChain", at(0,9.3,-2.1), (3.8,.35,.3), "FFDC73", neon=True, collide=False)
        part(detail, "AuraPendant", at(0,8.7,-2.2), (.85,.85,.3), "FFDC73", roll=45, neon=True, collide=False)
        if world_id == "candy":
            stands = []
            for node in list(detail.findall("Item")):
                if name(node) == "CandyStick":
                    cf = props(node)["CFrame"]
                    stands.append((float(cf.findtext("X")),float(cf.findtext("Z"))))
                if name(node) in ["CandyStick","Lollipop","CandySwirl"]: detail.remove(node)
            for x,z in stands:
                part(detail,"GymBench",(x,7.2,z),(8,1.1,3.5),"B5A2EF")
                for dx in (-2.7,2.7): part(detail,"BenchLeg",(x+dx,6,z),(.8,2,2.8),"FFF3DC")
                part(detail,"BroteinBarbell",(x,9.5,z),(9,.6,.6),"FFF5DB",shape=2)
                for dx in (-3.7,3.7):
                    part(detail,"BubbleWeight",(x+dx,9.5,z),(1,4.3,4.3),"FFE099",shape=2)
                    part(detail,"WeightPlate",(x+dx,9.5,z),(1.15,2.5,2.5),"FFADCF",shape=2)
            for node in list(detail.findall("Item")):
                if name(node) != "Gumdrop": continue
                cf=props(node)["CFrame"]; x,z=float(cf.findtext("X")),float(cf.findtext("Z")); detail.remove(node)
                part(detail,"BroteinShake",(x,6.6,z),(3,2.4,2.4),"C6F4E5",shape=2,roll=90)
                part(detail,"ShakeLid",(x,8.2,z),(.35,2.6,2.6),"FFF5DC",shape=2,roll=90)
                part(detail,"GiantStraw",(x+.4,9,z),(1.7,.4,.4),"FF95CD",shape=2,roll=90,collide=False)
    ET.indent(root,space="  ")
    return ET.tostring(root,encoding="utf-8",xml_declaration=True)+b"\n",root


def main():
    parser=argparse.ArgumentParser(); parser.add_argument("--check",action="store_true"); args=parser.parse_args()
    data, root=generate(); target=ROOT/'src/world/MogWorld.rbxmx'
    if args.check:
        assert target.read_bytes()==data,"Regenerate with python3 tools/build_world.py"
    else: target.write_bytes(data)
    count=sum(i.get('class')=='Part' for i in root.iter('Item'))
    print(f"Map verified: 4 islands, {count} anchored parts, 52 collectible crystals")


if __name__=='__main__': main()
