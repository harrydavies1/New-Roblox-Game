# Studio test pass

The CLI tests exercise real economy/session modules and execute actual UI, world, commerce, and pose source against explicit boundary fakes. They do not run Roblox's renderer, physics, live Marketplace, or live DataStores. Complete these checks in Studio and a private published test experience before public release.

1. Open `releases/MogMode.rbxl` in Roblox Studio and press Play. Confirm the Studio sandbox banner, temporary progress, disabled real purchases, and no Output errors. Click/tap MOG!, press F, and try controller X.
2. Check Aura/XP, level rewards, Mog Power upgrades, all nine ranks, and the 25-click mog burst. Test R6 and R15; all joint transforms should restore after a pose, setting change, death, and respawn.
3. Follow each island's 12-crystal loop and eight-jump sky route. Check the ordinary 30× and bonus 100× click-value reward, player-specific 45-second cooldown, dead/distant prompt rejection, and streaming after revisiting.
4. Unlock all four zones. Validate previous-island, level, and Aura requirements; permanent unlocks, safe travel, collision, readability of monuments/shop labels, and recovery after falling.
5. Adopt and train pets, inspect viewport previews and followers, and rest/re-equip them. Three slots apply normally; five require the verified pass. Check level-five stars and level-ten crowns. Repeat with other nearby players and after travel/respawn.
6. Claim daily quests and journal milestones once; verify no repeated rewards. Midnight UTC resets daily counters but preserves currencies, journal stamps, and earned titles. Rebirth resets Aura and upgrades while retaining pets, islands, XP/level, styles, stamps, and Flex Gems.
7. Test portrait/landscape phones (including 320×568 and 390×844), tablets, desktops, and gamepad UI selection. Check safe-area insets, long text, scrolling, confirmations, and default movement/jump controls near the click button. Headless size tests do not establish pixel layout or physical input behavior.
8. Listen to every effect, including menus, crystals, clicks, errors, levels, and purchases. Toggle SFX and animations independently. Check for missing bundled sound errors and reasonable volume.
9. Start a multi-player Studio server. Players' currencies, inventory, cooldowns, and claims must remain independent; pet parties, ranks/styles, and mog poses should be visible to others. Check memory/frame time across repeated visits and joins/leaves; start with a 12-player limit and tune from observed performance.
10. Use a separate private published experience and datastore namespace to test real saves. Studio defaults to memory. Enable Studio API access and `StudioUseLiveDataStores` only deliberately for test data. Check autosave, leaving, shutdown, rejoining, overlapping sessions, lock expiry, and service outages.
11. Create actual Developer Products and Game Passes in Creator Dashboard and set their IDs in `src/server/ServerSettings.luau`. Check correct quantities, listed/native final price, cancellation, successful receipt delivery, retries, prior ownership, and purchase-time pass refresh. Never prune receipt IDs or remove sold product mappings while receipts remain outstanding.

Record actual devices, client versions, player counts, test results, and fixes. Human playtests are still needed for pacing and enjoyment.
