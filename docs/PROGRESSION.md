# Progression and rewards

The balance source is `assets/game.json`; regenerate both config and world after changing it. The values below describe the current revision, not measured human playtime targets.

The loop is **click for Aura → upgrade power → complete courses for XP and pets → unlock a zone → train stronger pets → rebirth/master expert courses**. The goal card directs new players through their first clicks, the starter warm-up, two upgrades, a hard-course pet, then the next zone. Courses remain available without purchases.

## Island gates

| Island | Level | Aura unlock cost | Local click/crystal multiplier |
| --- | ---: | ---: | ---: |
| Mewing Meadow | 1 | Free | 1× |
| Brotein Boulevard | 8 | 25,000 | 2× |
| Rizz Reef | 18 | 350,000 | 4× |
| Sigma Summit | 32 | 3,500,000 | 8× |
| Final Boss Citadel | 50 | 40,000,000 | 16× |

Every unlock requires the previous zone, spends Aura once, and travels to the new island. Owned islands remain unlocked through rebirth. Islands are 6,000 studs apart and the client masks every other island.

## Clicks and XP

- Client cooldown: 0.2 seconds. The server token bucket refills at five per second with one token maximum, so a burst cannot bank extra clicks. An external autoclicker can still submit at the permitted rate; it receives no extra authoritative speed.
- Each accepted click grants one base XP. Crystals grant two base XP and eight times the current click Aura. Each player can collect a given crystal once every 45 seconds.
- XP required for the next level is `floor(60 × level^1.55)`, compared with the previous `floor(20 × level^1.4)`. Level-ups award `40 × newLevel` Aura. Maximum level is 200.
- Next power upgrade costs `floor(75 × 1.48^upgradeLevel)`, capped at the currency maximum. There are 60 upgrades.
- Click Aura is `(1 + upgrades) × petMultiplier × islandMultiplier × (1 + 0.25 × rebirths)`, with optional verified DoubleAura and active Aura boost multipliers. Rebirth starts at 100,000 Aura and scales by `1.85^rebirths`, resetting all Aura and power upgrades.

## Course rewards

Each island has three separately tracked courses. Warm-ups have 12 stages and checkpoints every four. Hard routes have 22 stages, experts 32, with checkpoints every eight. Hard/expert platforms are narrower and experts add hazard strips. Every numbered stage must be touched in order, near the real platform, while alive and in the correct world. Minimum stage/finish timing rejects impossible quick completions; it is not a full movement anticheat.

| Starter course | First Aura / XP | Repeat Aura / XP | Checkpoint Aura | First-clear pet |
| --- | ---: | ---: | ---: | --- |
| Warm-up Circuit | 800 / 90 | 120 / 50 | 40 | None |
| Hop to the Top (hard) | 3,500 / 350 | 350 / 180 | 100 | Leafline Lynx |
| No-Cap Gauntlet (expert) | 10,000 / 800 | 900 / 500 | 100 | Meadow Menace |

For island tier 1–5, course/checkpoint Aura scales by `5^(tier − 1)` and finish XP by `tier^3`. Checkpoints also give five base XP. First-clear rewards are higher than repeats. Each route and each checkpoint has a five-minute saved reward cooldown. Repeating a finished route early is practice: no finish payout and no clear/task increment. First clears, pets, and cooldowns commit together before the finish reward appears.

Checkpoints are for the active run, not permanent resume points. Falling, hazards, or death return to the latest checkpoint; replacing/leaving the course or leaving the server ends that run. A run expires after 15 minutes. A storage failure at the finish lets the player retry by stepping off and back on without redoing a successful save.

## Pets and recurring goals

Fifteen shop pets range from 1,500 Aura to two billion Aura. Each hard/expert course gives its own guaranteed exclusive pet on the first clear, for ten additional pets. Aura cannot buy the first copy of an exclusive pet. Owned pets train up to level ten with `floor(baseCost × 1.8^currentPetLevel)` Aura. Training improves bonuses; there are no random eggs or paid pet rerolls.

Daily tasks ask for 300 accepted clicks, 12 crystals, and two rewarded course completions. They reset at 00:00 UTC. Eleven permanent journal milestones cover clicks, pets, zones, rebirths, earned Aura, and course clears; two give free titles.

The first return reward requires 24 hours after the first durable visit. Claims are then spaced at least 24 hours apart and cycle through 600, 900, 1,300, 1,800, 2,400, 3,200, and 4,500 Aura, each with 40 base XP. Missing a day does not discard previous claims. Login rewards require persistent saving and never grant Flex Gems.

Optional Aura and XP boosts each double their respective gameplay reward for 15 minutes, with offline expiry and duration stacking. Aura boosts and the DoubleAura pass affect clicks/crystals, not fixed course/checkpoint/login payouts. The XP boost affects gameplay XP, including courses. Bought Aura does not count toward earned-Aura milestones. Flex Gems are only delivered through paid receipt processing and only buy styles.

Before public release, use real-device playtests to measure first upgrade, first pet, zone gates, success/fall rates, and return-session behavior. CLI tests establish reward arithmetic and state transitions, not whether the pacing feels right.
