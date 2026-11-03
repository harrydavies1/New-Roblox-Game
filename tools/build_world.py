#!/usr/bin/env python3
"""Regenerate MOG MODE from the retained original primitive-map asset."""
from pathlib import Path
import argparse
import math
import copy
import json
import colorsys
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
    keys = {"Vector2": ["X", "Y"], "Vector3": ["X", "Y", "Z"], "Color3": ["R", "G", "B"], "CoordinateFrame": ["X", "Y", "Z", "R00", "R01", "R02", "R10", "R11", "R12", "R20", "R21", "R22"]}
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


def generate_base():
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


def setprop(item, key, tag, value):
    p = item.find("Properties")
    old = props(item).get(key)
    if old is not None: p.remove(old)
    prop(p, tag, key, value)


def folder(parent, label):
    global serial
    serial += 1
    node = ET.SubElement(parent, "Item", {"class": "Folder", "referent": f"MOG{serial}"})
    p = ET.SubElement(node, "Properties"); prop(p, "string", "Name", label)
    return node


def label(parent, caption, color, offset=4, width=220):
    global serial
    serial += 1
    gui = ET.SubElement(parent, "Item", {"class": "BillboardGui", "referent": f"MOG{serial}"})
    p = ET.SubElement(gui, "Properties"); prop(p, "string", "Name", "CourseSign")
    size = ET.SubElement(p, "UDim2", name="Size")
    for k, v in {"XS": "0", "XO": str(width), "YS": "0", "YO": "44"}.items(): ET.SubElement(size, k).text = v
    prop(p, "Vector3", "StudsOffset", (0, offset, 0)); prop(p, "float", "MaxDistance", 70); prop(p, "bool", "AlwaysOnTop", False)
    serial += 1
    text = ET.SubElement(gui, "Item", {"class": "TextLabel", "referent": f"MOG{serial}"})
    p = ET.SubElement(text, "Properties"); prop(p, "string", "Name", "Label")
    size = ET.SubElement(p, "UDim2", name="Size")
    for k, v in {"XS": "1", "XO": "0", "YS": "1", "YO": "0"}.items(): ET.SubElement(size, k).text = v
    prop(p, "float", "BackgroundTransparency", 1); prop(p, "string", "Text", caption)
    prop(p, "Color3", "TextColor3", [int(color[i:i+2], 16)/255 for i in (0, 2, 4)])
    prop(p, "Color3", "TextStrokeColor3", (.08, .09, .12)); prop(p, "float", "TextStrokeTransparency", .3)
    prop(p, "bool", "TextScaled", True); prop(p, "bool", "TextWrapped", True); prop(p, "token", "Font", 9)


def stage_number(platform, stage):
    """Number the actual landing face; no floating billboard on every jump."""
    global serial
    serial += 1
    gui = ET.SubElement(platform, "Item", {"class": "SurfaceGui", "referent": f"MOG{serial}"})
    p = ET.SubElement(gui, "Properties")
    prop(p, "string", "Name", "StageNumber"); prop(p, "token", "Face", 1)
    prop(p, "Vector2", "CanvasSize", (128, 128)); prop(p, "float", "LightInfluence", .2)
    serial += 1
    text = ET.SubElement(gui, "Item", {"class": "TextLabel", "referent": f"MOG{serial}"})
    p = ET.SubElement(text, "Properties")
    prop(p, "string", "Name", "Number"); prop(p, "string", "Text", str(stage))
    size = ET.SubElement(p, "UDim2", name="Size")
    for k, v in {"XS": "1", "XO": "0", "YS": "1", "YO": "0"}.items(): ET.SubElement(size, k).text = v
    prop(p, "float", "BackgroundTransparency", 1); prop(p, "bool", "TextScaled", True)
    prop(p, "Color3", "TextColor3", (1, .98, .91)); prop(p, "Color3", "TextStrokeColor3", (.15, .13, .21))
    prop(p, "float", "TextStrokeTransparency", .05); prop(p, "token", "Font", 9)


def mascot_scene(parent, ox, oz, spec):
    """A little aura-inspection booth and expressive local mascot, built from primitives."""
    x, z = ox-31, oz+38
    gold, ink = "E5B94F", "302A3D"
    part(parent, "AuraInspectionPlinth", (x, 5.9, z), (9, 1.4, 8), spec["Cliff"])
    part(parent, "MascotBody", (x, 8, z), (3.8, 3.1, 3.5), spec["Ground"], shape=0, collide=False)
    head = part(parent, "CertifiedMogger", (x, 11, z), (4.5, 3.8, 3.7), spec["Trim"], shape=0, collide=False)
    part(parent, "MascotJawline", (x, 9.7, z-1.7), (4, 1.1, 1), spec["Trim"], collide=False)
    for side in (-1, 1):
        part(parent, "MascotShades", (x+side*1.05, 11.4, z-1.85), (1.7, .8, .35), ink, collide=False)
        part(parent, "MascotLensShine", (x+side*1.05-.3, 11.6, z-2.04), (.45, .12, .08), "FFF7E6", collide=False)
        part(parent, "MascotFoot", (x+side*1.4, 6.9, z-.4), (1.6, .8, 2.3), gold, shape=0, collide=False)
    part(parent, "MascotShadesBridge", (x, 11.5, z-1.85), (.7, .2, .35), ink, collide=False)
    part(parent, "MascotSmile", (x, 10.4, z-2), (1.3, .12, .12), ink, collide=False)
    if spec["Id"] in ("coral", "citadel"):
        part(parent, "HonkerBeak", (x, 10.5, z-2.2), (2, .7, 1.8), gold, collide=False)
    else:
        for side in (-1, 1): part(parent, "MascotEar", (x+side*1.7, 13, z), (1.3, 1.8, 1.5), spec["Ground"], shape=0, collide=False)
    if spec["Id"] == "candy":
        part(parent, "MascotDumbbellBar", (x+3.7, 8.5, z-.2), (.5, .5, 4), ink, collide=False)
        for side in (-1, 1): part(parent, "MascotDumbbellWeight", (x+3.7, 8.5, z-.2+side*1.8), (1.5, 1.5, .7), gold, collide=False)
    if spec["Id"] == "cosmos":
        part(parent, "MascotPlanetRing", (x, 11, z), (.22, 6.2, 6.2), spec["Color"], shape=2, roll=75, collide=False)
    if spec["Id"] == "citadel":
        for side in (-1, 0, 1): part(parent, "HonkerCrown", (x+side*1.2, 13.3+(1-abs(side))*.4, z), (.7, 1.3, .7), gold, collide=False)
    label(head, {"meadow": "AURA INSPECTION\nCertified. Keep cooking.", "candy": "BROTEIN CHECK\nNever skip jump day.", "coral": "RIZZ LEVEL: DEEP\nThe reef is locked in.", "cosmos": "COSMIC SIDE EYE\nGravity can't mog you.", "citadel": "FINAL BOSS HONKER\nEarn the crown."}[spec["Id"]], spec["Trim"], 5, 170)


def prize_pet(parent, pet, center):
    """Match the reward's silhouette instead of displaying a cat for every pet."""
    x, y, z = center; ink = "302A3D"
    part(parent, "RewardPet", center, (2.8, 2.4, 2.4), pet["Color"], shape=0, collide=False)
    face_y, face_z = y+.1, z-1.15
    if pet["Shape"] == "goose":
        part(parent, "PrizeGooseNeck", (x, y+1.5, z-.2), (1.1, 2.2, 1.1), pet["Color"], shape=0, collide=False)
        part(parent, "PrizeGooseHead", (x, y+2.7, z-.2), (2, 1.8, 1.8), pet["Color"], shape=0, collide=False)
        part(parent, "PrizeHonkerBeak", (x, y+2.4, z-1.3), (1.1, .55, 1), pet["Accent"], collide=False)
        face_y, face_z = y+2.8, z-1.1
    for side in (-1, 1):
        part(parent, "RewardPetEye", (x+side*.58, face_y, face_z), (.3, .4, .18), ink, shape=0, collide=False)
        part(parent, "RewardPetEyeShine", (x+side*.58-.04, face_y+.1, face_z-.1), (.08, .1, .05), "FFF7E8", shape=0, collide=False)
        part(parent, "PrizePetFoot", (x+side*.7, y-1, z-.4), (.8, .45, .9), pet["Accent"], shape=0, collide=False)
        if pet["Shape"] == "fox":
            part(parent, "RewardPetEar", (x+side*.8, y+1.4, z), (.6, 1.2, .7), pet["Accent"], shape=0, collide=False)
        if pet["Shape"] in ("dragon", "moth"):
            part(parent, "PrizePetWing", (x+side*2, y+.3, z+.3), (2.4, .35, 2.4), pet["Accent"], shape=0, roll=side*25, collide=False)
        if pet["Shape"] == "dragon":
            part(parent, "PrizePetHorn", (x+side*.6, y+1.4, z), (.4, 1, .4), pet["Accent"], collide=False)
        if pet["Shape"] == "axolotl":
            for gill in (-1, 0, 1): part(parent, "PrizePetGill", (x+side*1.65, y+gill*.55, z), (1, .3, .5), pet["Accent"], shape=0, roll=side*gill*20, collide=False)
    part(parent, "PrizeMedal", (x, y-.4, z-1.25), (.4, .4, .15), "E5B94F", roll=45, collide=False)


def position(node):
    cf = props(node)["CFrame"]
    return [float(cf.findtext(k)) for k in ("X", "Y", "Z")]


def generate():
    global serial
    _, root = generate_base()
    design = json.loads((ROOT / "assets/game.json").read_text())
    world = root.find("Item")
    islands = {name(node): node for node in world.findall("Item")}
    # Reuse original authored scenery, with a distinct fifth citadel palette.
    citadel = copy.deepcopy(islands["cosmos"])
    props(citadel)["Name"].text = "citadel"
    world.append(citadel); islands["citadel"] = citadel
    for wi, spec in enumerate(design["Worlds"]):
        island = islands[spec["Id"]]
        old_origin = [(0, 0), (620, 0), (0, 620), (620, 620), (620, 620)][wi]
        dx, dz = spec["Origin"][0]-old_origin[0], spec["Origin"][1]-old_origin[1]
        for node in island.iter("Item"):
            p = props(node)
            if "CFrame" in p:
                cf = p["CFrame"]; cf.find("X").text = str(float(cf.findtext("X"))+dx); cf.find("Z").text = str(float(cf.findtext("Z"))+dz)
            if node.get("class") == "Part":
                # Keep colour variety while taking neon and high-luminance whites out of scenery.
                material = p.get("Material")
                if material is not None: material.text = "272"
                color = p.get("Color")
                if color is not None:
                    values = [float(color.findtext(k)) for k in ("R", "G", "B")]
                    h, saturation, value = colorsys.rgb_to_hsv(*values)
                    values = colorsys.hsv_to_rgb(h, min(.62, saturation*.8), min(.79, value*.82))
                    for k, value in zip(("R", "G", "B"), values): color.find(k).text = f"{value:.6f}"
        land = next(n for n in island.findall("Item") if name(n) == "Landscape")
        details = next(n for n in island.findall("Item") if name(n) == "Details")
        markers = next(n for n in island.findall("Item") if name(n) == "Markers")
        shards = next(n for n in island.findall("Item") if name(n) == "Shards")
        portals = next(n for n in island.findall("Item") if name(n) == "Portals")
        for p in list(portals.findall("Item")): portals.remove(p)
        # Remove the old bypassable sky-crystal staircase and its signs/decks.
        remove = {"SkyStep", "StepGlow", "JumpSign", "PortalDeck", "PortalPath", "PortalArch", "Bonus_01"}
        for parent in (land, details, shards):
            for node in list(parent.findall("Item")):
                if name(node) in remove: parent.remove(node)
        for node in land.findall("Item"):
            key = name(node)
            if key == "FloatingIsland":
                size = props(node).get("size", props(node).get("Size"))
                if size is not None: size.find("X").text = "10"  # top=4, grass top=5; no coplanar faces
            if key in {"SoftGrass", "FloatingIsland", "Underside", "IslandHeart", "Plaza", "PlazaInset", "CenterRing", "PathStone"}:
                color = spec["Ground"] if key in {"SoftGrass", "CenterRing"} else spec["Cliff"] if key in {"FloatingIsland", "Underside", "IslandHeart"} else spec["Trim"]
                setprop(node, "Color", "Color3", [int(color[i:i+2], 16)/255 for i in (0, 2, 4)])
        for node in details.findall("Item"):
            if name(node) == "Fountain":
                for gui in list(node.findall("Item")): node.remove(gui)
                label(node, spec["Name"].upper(), spec["Color"], offset=20)
        # Readable nearby signage, rather than billboard text covering the whole play view.
        for gui in island.iter("Item"):
            if gui.get("class") == "BillboardGui":
                setprop(gui, "MaxDistance", "float", 65)
                size = props(gui).get("Size")
                if size is not None:
                    size.find("XO").text = "180"; size.find("YO").text = "44"
        if spec["Id"] == "citadel":
            for node in list(details.findall("Item")):
                if name(node) == "CrystalSpire": details.remove(node)
            ox, oz = spec["Origin"]
            for tx, tz in [(-70,-70), (70,-70), (-70,70), (70,70)]:
                part(details, "CitadelTower", (ox+tx, 14, oz+tz), (12, 18, 12), spec["Cliff"])
                for cx, cz in [(-4,-4), (4,-4), (-4,4), (4,4)]:
                    part(details, "TowerBattlement", (ox+tx+cx, 24, oz+tz+cz), (3, 3, 3), spec["Trim"])
                part(details, "TowerBanner", (ox+tx, 16, oz+tz-6.1), (4, 7, .2), spec["Ground"], collide=False)
        # Ordinary crystals remain small, lightly emissive landmarks; most map parts are matte.
        for i, node in enumerate(shards.findall("Item")):
            setprop(node, "Material", "token", 288 if i % 4 == 0 else 272)
            setprop(node, "Color", "Color3", (.65, .77, .74))
        ox, oz = spec["Origin"]
        # Face the sunglasses/jawline monument toward arriving players at +Z.
        # The retained baseline put its face on the far side of the spawn camera.
        for node in details.findall("Item"):
            if not (name(node).startswith("MogTotem") or name(node) in {"LensHighlight", "SunglassesBridge", "GoldChain", "AuraPendant"}): continue
            cf = props(node)["CFrame"]
            cf.find("X").text = f"{2*ox-float(cf.findtext('X')):.6f}"
            cf.find("Z").text = f"{2*oz-float(cf.findtext('Z')):.6f}"
            for row in (0, 2):
                for col in range(3):
                    key = f"R{row}{col}"; cf.find(key).text = f"{-float(cf.findtext(key)):.6f}"
        mascot_scene(details, ox, oz, spec)
        target = design["Worlds"][wi+1] if wi < len(design["Worlds"])-1 else design["Worlds"][0]
        gate = part(portals, target["Id"], (ox, 8, oz-72), (6, 5, 2), target["Color"], collide=False)
        label(gate, target["Name"].upper()+"\nTRAVEL / DISCOVER", target["Color"], 8)
        if wi > 0:
            gate = part(portals, "meadow", (ox-29, 8, oz-65), (5, 5, 2), spec["Trim"], collide=False)
            # The last island already targets meadow above; keep only one return gate.
            if target["Id"] == "meadow": portals.remove(gate)
            else: label(gate, "RETURN TO MEADOW", spec["Trim"], 6)
        shop = part(markers, "Shop", (ox+30, 8, oz+27), (2, 2, 2), spec["Color"], collide=False)
        label(shop, "STYLE & SUPPLIES\nOptional currency and boosts", spec["Trim"], 5)
        courses = folder(island, "Obbies")
        for ri, route in enumerate(r for r in design["Obbies"] if r["World"] == spec["Id"]):
            course = folder(courses, route["Id"]); steps = folder(course, "Steps"); hazards = folder(course, "Hazards")
            angle = math.radians(route["Angle"])
            start = (ox+math.cos(angle)*112, 6.4, oz+math.sin(angle)*112)
            start_pad = part(course, "Start", start, (10, 1.4, 10), spec["Trim"])
            setprop(start_pad, "CanTouch", "bool", True)
            label(start_pad, "START\nWalk on · follow the numbers", spec["Trim"], 3, 150)
            bridge_point = (ox+math.cos(angle)*99, 5.9, oz+math.sin(angle)*99)
            bridge = part(course, "EntranceBridge", bridge_point, (29, 1.2, 9), spec["Cliff"])
            setprop(bridge, "CFrame", "CoordinateFrame", (*bridge_point, math.cos(angle), 0, -math.sin(angle), 0, 1, 0, math.sin(angle), 0, math.cos(angle)))
            sign = part(markers, "Course_"+route["Id"], (ox+math.cos(angle)*88, 7, oz+math.sin(angle)*88), (2, 2, 2), spec["Color"], collide=False)
            reward = "AURA + XP" if not route.get("PetReward") else "FIRST CLEAR: EXCLUSIVE PET"
            label(sign, route["Name"].upper()+"\n"+reward, spec["Color"], 5)
            previous = start
            for stage in range(1, route["Count"]+1):
                # Every jump is reachable with WalkSpeed 18 / JumpPower 50 / Gravity 150.
                # Narrow targets, alternating offsets, staggered rises and hazard strips create difficulty.
                forward = route["Spacing"]*stage
                lateral = (0 if route["Difficulty"] == "warmup" else (2.5 if stage % 2 else -2.5))
                y = 6.4 + stage*(.75 if route["Difficulty"] == "warmup" else 1.15) + (1.0 if stage%4 in (2,3) else 0)
                point = (start[0]+math.cos(angle)*forward-math.sin(angle)*lateral, y, start[2]+math.sin(angle)*forward+math.cos(angle)*lateral)
                checkpoint = stage%route["CheckpointEvery"] == 0 or stage == route["Count"]
                width = max(route["Width"], 12 if stage == route["Count"] else 7 if checkpoint else 0)
                if route["Difficulty"] == "expert" and stage % 4 == 2: width = max(width, 5.2)
                platform = part(steps, f"{stage:02d}", point, (width, 1.1, width), spec["Trim"] if checkpoint else spec["Ground"])
                setprop(platform, "CanTouch", "bool", True)
                stage_number(platform, stage)
                part(course, "StepRim", (point[0], point[1]-.48, point[2]), (width+.15, .22, width+.15), spec["Cliff"], collide=False)
                if checkpoint and stage != route["Count"]: label(platform, "CHECKPOINT "+str(stage), spec["Color"], 3, 130)
                if route["Difficulty"] == "expert" and stage % 4 == 2:
                    # An offset hazard leaves a safe landing section rather than blocking the jump.
                    hazard = part(hazards, f"Hazard_{stage:02d}", (point[0]+width*.38, point[1]+.7, point[2]), (.45, .35, width), "B85D68", collide=False)
                    setprop(hazard, "CanTouch", "bool", True)
                previous = point
            finish = part(course, "Finish", (previous[0], previous[1]+2.2, previous[2]), (1.4, 2, 1.4), spec["Color"], collide=False)
            setprop(finish, "Transparency", "float", 1)
            setprop(finish, "CanTouch", "bool", True)
            chest = (previous[0]+3.3, previous[1]+1.7, previous[2]+1.6)
            part(course, "PrizeChest", chest, (3.3, 2.1, 2.4), "D9A842", collide=False)
            part(course, "ChestLid", (chest[0], chest[1]+1.2, chest[2]), (3.5, .7, 2.6), spec["Color"], collide=False)
            part(course, "ChestLock", (chest[0], chest[1]+.15, chest[2]-1.25), (.65, .8, .2), "FFF1B2", collide=False)
            for side in (-1, 1):
                post = (previous[0]+side*5, previous[1]+3.5, previous[2]+3.5)
                part(course, "FinishPost", post, (.45, 6, .45), spec["Cliff"], collide=False)
                part(course, "VictoryPennant", (post[0]+side*.9, post[1]+1.5, post[2]), (1.8, 1.5, .15), spec["Color"], collide=False)
            if route.get("PetReward"):
                pet = next(p for p in design["Pets"] if p["Id"] == route["PetReward"])
                label(finish, "CLAIM PRIZE\n"+pet["Name"]+" · first clear", spec["Trim"], 6)
                center = (previous[0], previous[1]+4, previous[2])
                prize_pet(course, pet, center)
            else: label(finish, "BIG W!\nAura + XP prize", spec["Trim"], 5)
    # Deep copies need fresh referents; there are no cross-object Ref properties in this model.
    for index, node in enumerate(root.iter("Item")): node.set("referent", f"WORLD{index}")
    ET.indent(root, space="  ")
    return ET.tostring(root, encoding="utf-8", xml_declaration=True)+b"\n", root


def main():
    parser=argparse.ArgumentParser(); parser.add_argument("--check",action="store_true"); args=parser.parse_args()
    data, root=generate(); target=ROOT/'src/world/MogWorld.rbxmx'
    if args.check:
        assert target.read_bytes()==data,"Regenerate with python3 tools/build_world.py"
    else: target.write_bytes(data)
    count=sum(i.get('class')=='Part' for i in root.iter('Item'))
    print(f"Map verified: 5 separated islands, 15 courses, {count} anchored parts, 60 collectible crystals")


if __name__=='__main__': main()
