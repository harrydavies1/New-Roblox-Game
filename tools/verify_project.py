#!/usr/bin/env python3
"""Validate the built Roblox place, all five zones, course jumps, floor separation, and source."""
from pathlib import Path
import json
import math
import struct
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]


def props(item):
    return {p.get("name"): p for p in item.find("Properties")}


def property_node(item, key):
    return next((v for k, v in props(item).items() if k.lower() == key.lower()), None)


def name(item):
    return props(item)["Name"].text


def child(item, key):
    found = [i for i in item.findall("Item") if name(i) == key]
    assert len(found) == 1, (key, len(found))
    return found[0]


def vector(item, key):
    node = property_node(item, key)
    return tuple(float(node.findtext(axis)) for axis in ("X", "Y", "Z"))


def top(item):
    point = vector(item, "CFrame")
    size = vector(item, "Size")
    cf = property_node(item, "CFrame")
    half = sum(abs(float(cf.findtext("R1" + str(i)))) * size[i] / 2 for i in range(3))
    return point[1] + half


def main():
    design = json.loads((ROOT / "assets/game.json").read_text())
    binary = (ROOT / "build/MogMode.rbxl").read_bytes()
    assert binary.startswith(b"<roblox!\x89\xff\r\n\x1a\n")
    classes, instances = struct.unpack_from("<II", binary, 16)
    assert classes >= 10 and instances >= 2400
    root = ET.parse(ROOT / "build/MogMode.rbxlx").getroot()
    workspace = child(root, "Workspace")
    world = child(workspace, "MogWorld")
    assert property_node(workspace, "StreamingEnabled").text == "true"
    assert len(world.findall("Item")) == len(design["Worlds"]) == 5
    part_count = neon_count = crystal_count = stage_count = 0
    bounds = []
    for index, spec in enumerate(design["Worlds"]):
        island = child(world, spec["Id"])
        markers = child(island, "Markers")
        spawn = vector(child(markers, "Spawn"), "CFrame")
        assert spawn == (spec["Origin"][0], 5.5, spec["Origin"][1] + 29)
        for marker in ("PetShop", "Quests", "Shop"):
            child(markers, marker)
        if index == 0: child(markers, "Rebirth")
        crystals = child(island, "Shards").findall("Item")
        assert len(crystals) == 12
        assert all(name(n).startswith("Shard_") for n in crystals)
        for crystal in crystals:
            assert property_node(crystal, "CanCollide").text == "false"
        crystal_count += len(crystals)
        next_world = design["Worlds"][index + 1]["Id"] if index < 4 else None
        expected = ({next_world} if next_world else set()) | ({"meadow"} if index else set())
        assert {name(n) for n in child(island, "Portals").findall("Item")} == expected
        details = child(island, "Details")
        for landmark in ("MogTotemHead", "MogTotemJaw", "AuraPendant"):
            child(details, landmark)
        child(details, "CertifiedMogger")
        nose = vector(child(details, "MogTotemNose"), "CFrame")
        ox, oz = spec["Origin"]
        assert (nose[0]-ox)*(spawn[0]-ox)+(nose[2]-oz)*(spawn[2]-oz) > 0, "The mog monument should face arriving players"
        land = child(island, "Landscape")
        assert not any(name(n) == "SkyStep" for n in land.findall("Item"))
        cliff = child(land, "FloatingIsland")
        grass = child(land, "SoftGrass")
        assert top(cliff) < top(grass) - 0.5, "Coplanar cliff/grass surfaces cause floor flicker"
        tops = [top(child(land, key)) for key in ("SoftGrass", "Plaza", "PlazaInset", "CenterRing")]
        assert all(abs(a - b) > 0.05 for i, a in enumerate(tops) for b in tops[i+1:])
        courses = child(island, "Obbies")
        routes = [r for r in design["Obbies"] if r["World"] == spec["Id"]]
        assert len(courses.findall("Item")) == len(routes) == 3
        for route in routes:
            course = child(courses, route["Id"])
            steps = child(course, "Steps").findall("Item")
            assert len(steps) == route["Count"]
            assert len(steps) >= (12 if route["Difficulty"] == "warmup" else 22)
            previous = vector(child(course, "Start"), "CFrame")
            assert property_node(child(course, "Start"), "CanTouch").text == "true"
            bridge = child(course, "EntranceBridge")
            assert property_node(bridge, "CanCollide").text == "true"
            assert math.dist(vector(bridge, "CFrame"), previous) < 15
            for stage, platform in enumerate(steps, 1):
                assert name(platform) == f"{stage:02d}"
                assert property_node(platform, "CanTouch").text == "true"
                assert property_node(child(child(platform, "StageNumber"), "Number"), "Text").text == str(stage)
                point = vector(platform, "CFrame")
                rise = point[1] - previous[1]
                discriminant = 50**2 - 2*150*rise
                assert discriminant > 0
                airtime = (50 + math.sqrt(discriminant)) / 150
                horizontal = math.hypot(point[0] - previous[0], point[2] - previous[2])
                assert horizontal < 18 * airtime - 0.4, (route["Id"], stage, "unreachable jump")
                assert rise < 3 and vector(platform, "Size")[0] >= route["Width"]
                previous = point
                stage_count += 1
            assert property_node(child(course, "Finish"), "CanTouch").text == "true"
            for key in ("PrizeChest", "ChestLid", "ChestLock"):
                assert property_node(child(course, key), "CanCollide").text == "false", "Prize decoration must not block the landing"
            assert vector(steps[-1], "Size")[0] >= 12
            hazards = child(course, "Hazards").findall("Item")
            assert bool(hazards) == (route["Difficulty"] == "expert")
            for hazard in hazards:
                assert property_node(hazard, "CanTouch").text == "true"
                stage = int(name(hazard).split("_")[-1])
                platform = child(child(course, "Steps"), f"{stage:02d}")
                safe_width = vector(hazard, "CFrame")[0] - vector(hazard, "Size")[0]/2 - (vector(platform, "CFrame")[0] - vector(platform, "Size")[0]/2)
                assert safe_width > 3.2, "Hazard leaves no fair landing area"
            if route.get("PetReward"):
                assert route["Difficulty"] in ("sky", "expert")
                child(course, "RewardPet")
                pet = next(p for p in design["Pets"] if p["Id"] == route["PetReward"])
                assert pet["ObbyOnly"] == route["Id"]
            else:
                assert route["Difficulty"] == "warmup"
        xs, zs = [], []
        for item in island.iter("Item"):
            if item.get("class") != "Part": continue
            assert property_node(item, "Anchored").text == "true"
            point, size = vector(item, "CFrame"), vector(item, "Size")
            cf = property_node(item, "CFrame")
            half_x = sum(abs(float(cf.findtext("R0"+str(i))))*size[i]/2 for i in range(3))
            half_z = sum(abs(float(cf.findtext("R2"+str(i))))*size[i]/2 for i in range(3))
            xs.extend([point[0]-half_x, point[0]+half_x]); zs.extend([point[2]-half_z, point[2]+half_z])
            part_count += 1
            if property_node(item, "Material").text == "288": neon_count += 1
        bounds.append((min(xs), max(xs), min(zs), max(zs)))
    assert stage_count == sum(r["Count"] for r in design["Obbies"]) == 330
    assert crystal_count == 60 and part_count >= 2200
    assert neon_count/part_count < 0.025, "Too much emissive scenery"
    for i, a in enumerate(bounds):
        for b in bounds[i+1:]:
            gap = max(b[0]-a[1], a[0]-b[1], b[2]-a[3], a[2]-b[3])
            assert gap > 1500, "Another island is too close to the horizon"
    lighting = child(root, "Lighting")
    assert float(property_node(child(lighting, "Bloom"), "Intensity").text) <= 0.05
    scripts = [i for i in root.iter("Item") if i.get("class") in ("Script", "LocalScript", "ModuleScript")]
    paths = sorted((ROOT/"src").rglob("*.luau"))
    assert len(scripts) == len(paths)
    embedded = {props(n)["Source"].text: n.get("class") for n in scripts}
    for path in paths:
        kind = "Script" if path.name.endswith(".server.luau") else "LocalScript" if path.name.endswith(".client.luau") else "ModuleScript"
        assert embedded.get(path.read_text()) == kind, path
    server = child(child(root, "ServerScriptService"), "MogServer")
    for key in ("Commerce", "WorldService", "SessionStore", "RateLimiter", "ServerSettings", "Storage", "ObbyService", "ObbyRun"):
        child(server, key)
    client = child(child(child(root, "StarterPlayer"), "StarterPlayerScripts"), "MogClient")
    for key in ("UI", "PetFactory", "MogPose", "Effects", "Audio", "WorldVisibility", "CourseGuide"):
        child(client, key)
    mapped = set()
    def walk(node):
        for path in node.get("filePaths", []): mapped.add((ROOT/path).resolve())
        for nested in node.get("children", []): walk(nested)
    walk(json.loads((ROOT/"build/sourcemap.json").read_text()))
    assert all(path.resolve() in mapped for path in paths)
    assert not any("tests" in path.parts for path in mapped)
    print(f"PASS: {len(scripts)} scripts, 5 isolated zones, 15 reachable courses / 330 stages, 60 crystals, separated floors, {neon_count}/{part_count} emissive parts")


if __name__ == "__main__":
    main()
