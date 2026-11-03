# New-Roblox-Game

## MOG MODE

Click to flex, build Aura, upgrade Mog Power, adopt a ridiculous hype squad, and explore four bright floating zones.

**Downloads:** [Source ZIP](https://github.com/harrydavies1/New-Roblox-Game/archive/refs/heads/main.zip) · [Studio game file](https://github.com/harrydavies1/New-Roblox-Game/raw/refs/heads/main/releases/MogMode.rbxl)

Open `releases/MogMode.rbxl` in Roblox Studio on Windows or macOS and press **Play**. No uploaded art, animation IDs, or credentials are needed for the default sandbox. Studio progress is temporary and real purchases are disabled. This repository was recovered after a workspace restoration; see [recovery provenance](docs/RECOVERY.md).

### Included

- Mewing Meadow, Brotein Boulevard, Rizz Reef, and Sigma Summit; cat monuments, oversized gym props, coral gardens, cosmic spires, boutiques, portals, 52 renewable crystals, and four eight-jump routes.
- Twelve guaranteed Aura pets, ten training levels, three equipped slots (five with a pass), animated followers, level stars/crowns, and menu previews.
- Sixty Mog Power upgrades, 200 XP levels, nine rank titles, twenty rebirths, daily goals, nine permanent journal stamps, and two free earned titles.
- A procedural R6/R15 flex every 25 accepted clicks, local sound, click/reward animation, confetti, trails, orbit effects, and separate sound/animation settings.
- Optional packs of earned Aura, Robux-only Flex Gems for guaranteed cosmetics, and three permanent passes. No random paid eggs. Every island and pet is available through play.
- Server-owned rewards, validated requests and proximity, rate limiting, leased save sessions, autosave, shutdown release, and atomic paid-receipt deduplication.

### Currency and live configuration

Aura comes from gameplay and optional Robux packs; it buys pets, training, upgrades, islands, and rebirths. Flex Gems come **only** from Robux Developer Products and buy cosmetics. Gameplay never awards Flex Gems.

All live IDs start at zero in `src/server/ServerSettings.luau`. Create your own Developer Products and Game Passes in Creator Dashboard, set their IDs, and choose prices there. The game fetches listed prices; Roblox's native prompt shows the final charge. Product keys and guaranteed rewards:

| Key | Reward |
| --- | --- |
| `aura_small` | 5,000 Aura |
| `aura_medium` | 60,000 Aura |
| `aura_large` | 750,000 Aura |
| `flex_gems_small` | 100 Flex Gems |
| `flex_gems_medium` | 350 Flex Gems |
| `flex_gems_large` | 900 Flex Gems |

Passes: `DoubleAura` doubles click/crystal Aura; `ExtraPets` adds two equip slots; `VIP` adds the Prismatic Ribbon and Mog Patron nameplate. Pass benefits require Roblox ownership verification. Developer Product rewards are granted only by ProcessReceipt after balance and receipt ID are durably saved together. Failed/offline delivery remains pending for retry. Never prune receipt IDs or reuse sold product mappings. A full currency balance defers receipts until their entire reward fits.

Published servers use `MogMode_Profiles_v1`; Studio uses memory by default. Use a separate published test experience and namespace for live save/commerce testing.

### Development and verification

On Linux x86_64 with Python 3, curl, and Git:

```bash
bash tools/check.sh
```

The installer verifies official release SHA-256 checksums for Rojo 7.7.1 and Luau 0.745. Checks include strict analysis of the pure modules/tests, compilation of every game script, economy/session tests, actual UI/service code exercised against explicit boundary fakes, deterministic map generation, both place formats, source maps, and inspection of embedded scripts, spawns, portals, and collectibles.

Build outputs are ignored under `build/`. In the prepared cloud environment, reuse cached tools with:

```bash
MOG_TOOL_DIR=/workspace/.roblox-tools bash tools/check.sh
```

To generate a fresh downloadable place and complete ZIP after checks:

```bash
python3 tools/package.py
```

The ZIP includes source, editable map baseline, generated map, tests, documentation, tooling, and `releases/MogMode.rbxl`. It excludes Git internals and caches. Commit the updated `releases/` files when releasing a changed game. `releases/manifest.json` contains the Studio file and game-source checksums.

For source syncing with a matching desktop Rojo plugin:

```bash
export PATH="$PWD/.tools/bin:$PATH"
rojo serve default.project.json --address 127.0.0.1 --port 34872
```

Cloud loopback is not automatically reachable by desktop Studio; opening the built place is the direct workflow. No cloud web preview or Roblox upload is performed.

Edit `src/shared/Config.luau` for balance, catalogues, ranks, and goals. Runtime is in `src/server/` and `src/client/`. To change map geometry, edit `assets/base-world.rbxmx` or `tools/build_world.py`, run the generator, and commit `src/world/MogWorld.rbxmx` together.

**Validation limit:** CLI and boundary checks do not execute Roblox rendering, audio, input, physics, or live services. Complete the [Studio test pass](docs/STUDIO_TESTING.md) before public release. Sound uses Roblox's bundled `electronicpingshort.wav`; all map/pet art uses original primitives.
