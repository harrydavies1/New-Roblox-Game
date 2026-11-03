# Recovery provenance

This note describes the recovered release at commit `60b8ed3f9561ee0998fb698e62c1af0fa4c963da`. The current revision expands it to five islands, 15 courses, 60 crystals, and 2,218 anchored parts; see [the README](../README.md) and [progression notes](PROGRESSION.md) for current behavior.

The earlier workspace's local `d3ef64d` commit was not present after the environment was restored, and it had not been pushed to GitHub. The retained `PrismClickers-map-check.rbxlx` contained the original four-zone primitive map plus Config, Economy, Format, RateLimiter, ServerSettings, and SessionStore. Those six modules and base geometry were extracted without executing external code.

The MOG MODE catalogue, safeguards, server/client runtime, interface, procedural pets and poses, themed map changes, and executable tests were reconstructed from the source recorded in this conversation. This is a recovered implementation; it is not claimed to be byte-identical to the unavailable commit. The map generator uses the retained `assets/base-world.rbxmx` as its editable baseline. Four purely decorative caption markers from the prior version are absent; the recovered map has 1,690 anchored parts. Gameplay routes, 52 crystal positions, shops, and portals remain present.

The recovered project is recompiled, tested, built, and packaged from the source in this repository. `releases/manifest.json` binds the downloadable Studio file to source checksums. `tools/package.py` creates the complete source ZIP, including the ready-to-open Studio file. It excludes Git metadata, runtime credentials, generated test harnesses, and tool caches.
