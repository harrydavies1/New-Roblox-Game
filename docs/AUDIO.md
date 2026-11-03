# Music and selected sound effects

The owner's chosen asset IDs and volumes are configured in [`src/shared/AudioConfig.luau`](../src/shared/AudioConfig.luau). The ready-to-open place includes this configuration and the playlist controller.

## Playlist

| Order | Song | Creator Store asset |
| --- | --- | --- |
| 1 | Tender Static — warm Rhodes and upright bass | [139132289200391](https://create.roblox.com/store/asset/139132289200391) |
| 2 | Elevator Jazz — Easy Listening Groove | [117496769617516](https://create.roblox.com/store/asset/117496769617516) |
| 3 | Gymnopedie No. 1 | [9045766377](https://create.roblox.com/store/asset/9045766377) |

The client plays one full song at a time, then advances 1 → 2 → 3 → 1 indefinitely. Songs are not individually looped or shuffled. Tracks fade in, and travel/character respawns do not create additional players or restart the current song.

Menu → Settings contains a separate Music toggle, a now-playing label, and volume controls in 25% steps. Music defaults to on at 50%, corresponding to Sound.Volume 0.12; 100% corresponds to the configured maximum 0.24. Muting pauses the song, and re-enabling resumes its position within that client session. Music does not follow the SFX toggle. The server validates and saves music preferences with the existing profile; older profiles gain sensible defaults without resetting progress. Playback waits for the saved preferences before starting.

An unavailable or stalled song is skipped. If all three fail, the player retries after 30 seconds instead of continuously attempting requests. Ended events drive normal transitions; load/playback guards recover from unavailable assets and missing events. Only the current song remains allocated.

## Effects

| Use | Creator Store asset |
| --- | --- |
| Every verified obby clear, including pet finishes and practice clears | [12222253 — victory.wav](https://create.roblox.com/store/asset/12222253) |
| World Aura crystal pickups and rewarded Aura checkpoints | [72264591133889 — UI pop](https://create.roblox.com/store/asset/72264591133889) |
| Menu buttons, tabs, and panel taps | [132948338000932 — bubble pop](https://create.roblox.com/store/asset/132948338000932) |

These clips play at normal speed without the old short-note duration cutoff or bundled-note equalizer. Ended releases each voice; loading/length guards also release failed or stalled sounds. The existing voice cap, click rate limits, reward priority, mute cleanup, and short bundled cues for other actions remain. A failed reward save still cannot play a completion sound or reveal a prize before a durable completion is acknowledged. Practice clears play victory audio but clearly award no cooldown-protected prize.

## Editing and checking in Studio

In Explorer, open `ReplicatedStorage → MogShared → AudioConfig` to edit selected IDs/volumes. Playlist behavior is in `StarterPlayer → StarterPlayerScripts → MogClient → Music`; effect handling is in its `Audio` module. Stop Play mode before editing, and also update the corresponding source files before rebuilding with Rojo.

Test all three songs through an entire loop in a private Studio/published test. Check independent SFX/music mute, resume position, volume, rejoining preferences, travel, respawn, ordinary and pet obby finishes, Aura pickups, checkpoints, and menu taps. If Roblox reports an asset access error in Output, check that the audio is available and that the experience has permission to use it in Creator Dashboard. Code cannot grant asset access on the owner's behalf.

The CLI suite executes the actual playlist/effect modules against explicit boundary fakes to verify IDs, order, wrapping, one-song allocation, mute/resume, volume, failed-load backoff, stale callbacks, full-clip cleanup, settings migration, and server/UI preference handling. Fake durations are test data, not measured durations of these assets. Linux tests do not hear audio, contact Roblox's audio delivery service, or verify the experience's asset permissions.
