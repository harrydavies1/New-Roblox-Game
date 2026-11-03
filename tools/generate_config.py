#!/usr/bin/env python3
"""assets/game.json is the source of truth for the server, UI, and map generator."""
from pathlib import Path
import argparse
import json

ROOT = Path(__file__).resolve().parents[1]


def lua(value, depth=0):
    pad = "\t" * depth
    if isinstance(value, bool): return "true" if value else "false"
    if isinstance(value, str): return json.dumps(value, ensure_ascii=False)
    if isinstance(value, (int, float)): return str(value)
    if isinstance(value, list): return "{\n" + "".join(pad + "\t" + lua(v, depth + 1) + ",\n" for v in value) + pad + "}"
    if isinstance(value, dict): return "{\n" + "".join(pad + "\t[" + json.dumps(k) + "] = " + lua(v, depth + 1) + ",\n" for k, v in value.items()) + pad + "}"
    raise ValueError(value)


def main():
    parser = argparse.ArgumentParser(); parser.add_argument("--check", action="store_true"); args = parser.parse_args()
    data = json.loads((ROOT / "assets/game.json").read_text())
    worlds = {w["Id"]: w for w in data["Worlds"]}
    pets = {p["Id"]: p for p in data["Pets"]}
    routes = {r["Id"]: r for r in data["Obbies"]}
    assert len(worlds) == len(data["Worlds"]) == 5
    assert len(pets) == len(data["Pets"]) == 25
    assert len(routes) == len(data["Obbies"]) == 15
    for index, world in enumerate(data["Worlds"]):
        if index:
            previous = data["Worlds"][index-1]
            assert world["Level"] > previous["Level"] and world["Cost"] > previous["Cost"]
        assert len([r for r in routes.values() if r["World"] == world["Id"]]) == 3
    for route in routes.values():
        assert route["World"] in worlds and route["Count"] >= 12
        assert 0 < route["CheckpointEvery"] < route["Count"]
        assert route["FirstAura"] > route["RepeatAura"] > 0 and route["FirstXP"] > route["RepeatXP"] > 0
        if route["Difficulty"] == "warmup": assert "PetReward" not in route
        else: assert pets[route["PetReward"]]["ObbyOnly"] == route["Id"]
    for pet in pets.values():
        assert pet["World"] in worlds and pet["Cost"] > 0 and pet["Bonus"] > 0
        if pet.get("ObbyOnly"): assert routes[pet["ObbyOnly"]]["PetReward"] == pet["Id"]
    assert data["ClickBurst"] == 1 and data["ClickRate"] * data["ClickCooldown"] == 1
    assert data["LoginInterval"] >= 86400
    output = "--!strict\n-- Generated from assets/game.json; run python3 tools/generate_config.py.\nreturn " + lua(data) + "\n"
    path = ROOT / "src/shared/Config.luau"
    if args.check: assert path.read_text() == output, "Regenerate Config.luau"
    else: path.write_text(output)
    print("Shared config verified: 5 zones, 15 courses, 25 pets")


if __name__ == "__main__": main()
