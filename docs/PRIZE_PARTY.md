# Prize and presentation revision

This revision fixes the reported "nothing happens" finish behavior and gives MOG MODE a consistent cartoon arcade identity. It builds on the five-island version; it does not reset existing profiles or change sold product mappings.

## The obby defect and fix

Previously, walking from an island onto a course did not create a tracked run. The player had to start through the menu. The visible prize was decorative, and the server only listened for numbered platform contacts. A finish after an untracked run did nothing. An interrupted contact could also stall ordered progress, and a failed finish save required stepping off and touching the final platform again.

Now:

- Entrance bridges lead to an explicit walk-on START pad. Physical entry starts a run even during autosave; menu starts still work. Duplicate contacts do not reset the run.
- Every landing is numbered. A personal arrow and outline point to the next required stage. The server also checks the next physical landing every tenth of a second to recover missed contact events. It never skips a stage based on prize proximity.
- The wide finish deck has a chest, pennants, a reward-pet display with the correct silhouette, and a working prize prompt. Landing on the final stage normally grants automatically; the prompt can recover a final missed contact or request a save retry.
- The finish remains verified while saving retries every five seconds. Manual retries are limited to once every two seconds. Travel and course changes wait for delivery so they cannot discard an earned prize. There is no finish payout or exclusive pet in memory before the durable commit succeeds.
- A prize card shows awarded Aura, actual boosted XP, the unlocked pet model/name, and a button to open its squad collection. Preview mode explicitly labels rewards temporary. Previously collected pets are not awarded again, and early repeat runs remain practice.

A pending prize is held in the current server session, not a separate offline delivery queue. If Roblox storage never accepts the write before the session ends, the game has not acknowledged or saved that clear; the player can complete it again. Completed durable clears, pets, and cooldowns survive rejoining.

## Presentation and small details

The HUD retains its compact footprint. Charcoal panels are replaced by warm sticker-like surfaces, chunky ink borders, Fredoka One lettering, currency-colored counters, a gold MOG button, lime actions, springy press feedback, and a small sunglasses mascot. The menu fits and scrolls in landscape. Zone buttons explain missing levels, previous zones, or Aura. Pet/course tabs follow the island after travel or rejoining.

The pet collection now has larger model portraits, an owned/equipped count, earned-pet accents, medals on earned pets, distinct rat/capybara shapes, and a visible level-ten goose crown. Equip best uses the strongest owned trained bonuses and the verified free/pass slot limit without spending currency.

Each island gains a themed aura-inspection mascot scene. Course entrances have bridges; platform faces carry numbers; rims, chest locks/lids, wider finish decks, and victory pennants give routes a finished look. Prize models distinguish foxes, gargoyles, axolotls, moths, and honkers instead of reusing one generic cat silhouette. Most surfaces remain matte: 15 of 2,807 map parts are Neon, with the previous low bloom and separated floor heights preserved.

Sixteen original cue arrangements use Roblox's bundled tap, water, jump, landing, and ping assets. Small percussive clicks, checkpoint intervals, upgrade arpeggios, route-start cues, a chest fanfare, and a longer pet reveal have different patterns. Short attack/release envelopes soften cuts, high frequencies are reduced, major rewards suppress overlapping level jingles and quiet clicks, and no more than 12 voices play at once. Muting stops current sounds and invalidates delayed notes, even if sound is quickly re-enabled. No copyrighted meme voice uploads or external asset IDs are required.

The [desktop](hud-desktop.png), [phone](hud-phone.png), [menu](hud-menu-desktop.png), and [prize card](hud-prize-phone.png) previews export real GUI geometry. They are 2D layout illustrations; they do not show Roblox rendering, pet viewports, input, or physics.

## Verification

`tools/check.sh` analyzes pure modules, compiles all 21 game scripts, checks source/config/map consistency, builds both place formats, verifies the embedded scripts, and inspects all five island gates, 15 routes, 330 reachable jump stages, 60 crystals, floor heights, entrance bridges, touch-enabled starts/finishes, numbered faces, and clear prize landings.

The executable boundary tests cover natural entry and missed contacts on every route; ordered-stage and distance rejection; duplicate prize requests; starts during a save; failed finish writes with backoff and automatic retry; preservation of pending prizes; actual server reward packets; actual effect-to-reveal dispatch; pet models; sound cue lifecycle/muting; next-jump guidance; retained streamed islands; UI safe-area bounds; and equip-best slot/bonus rules. They use explicit fakes and do not emulate the Roblox engine.

Complete the [Studio test pass](STUDIO_TESTING.md) to hear the real sounds, inspect the final art/layout, play every jump on physical devices, assess enjoyment, and exercise live DataStore/Marketplace services. Linux CLI validation cannot establish those results.
