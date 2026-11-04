# Illustrated player menu

The menu is now a small player hub built for MOG MODE's cartoon world. The gold Courses feature gives the main play loop priority. Power, Squad, Worlds, and Daily Ws have their own illustrated tiles and live progress summaries; Shop and Settings sit in a smaller utility row. A sunglasses mascot, ink borders, raised faces, and a restrained cream/gold palette tie the hub to the island monuments.

The icons are original GUI drawings: steps and a flag, a dumbbell, the mogging pet, a ringed planet, a checked calendar, a gem bag, and a gear. No new uploaded images, permissions, or asset IDs are needed. The same drawings identify panel headers. Category colors appear on the illustrations and small marks, rather than filling every navigation row with a different color.

The hub opens from the gold menu button, keyboard **M**, or controller **Y**. The close button, clicking outside, M/Y again, or controller B closes it. Chat-processed keyboard input is ignored. The persistent HUD keeps its previous compact footprint; the larger hub is visible only when opened.

The hub fits the safe area, with a fixed header/footer and a scroll viewport on smaller screens. A footer hint appears when there is more to scroll. Tiles remain at least 44 pixels high. Gamepad links traverse the grid explicitly and scroll focused controls into view. Closing a panel returns controller focus to the menu button. Pressed faces and old highlights reset on dismissal/reopening, and resizing cancels the opening tween so rotation cannot restore an old offscreen position. The extra-animation preference disables decorative motion while retaining focus indicators.

First-clear progress, pet collection, power/level, and owned islands come from the replicated server profile. The Daily Ws badge counts actually claimable tasks, journal milestones, and eligible login rewards. It disappears as rewards become unavailable or claimed. Opening the hub dismisses an old toast so it cannot cover the heading.

Implementation:

- `src/client/Menu.luau`: hub layout, navigation, progress, and interaction.
- `src/client/MenuIcons.luau`: original shape illustrations.
- `src/client/UI.luau`: compact menu button, panel headings, shortcuts, and hub integration.

Layout illustrations: [desktop](hud-menu-desktop.png), [small phone](hud-menu-phone.png), [landscape](hud-menu-landscape.png), and [claimable rewards](hud-menu-rewards-phone.png). These export GUI geometry and use an approximate local typeface; they are not Roblox engine screenshots. The preview renderer includes clipping, rounded corners, rotation, and strokes, but cannot establish engine rendering or physical input behavior.

The CLI suite exercises all seven destination tiles across five viewports and three profile states, verifies target sizes/overlap, dismissal layers, loading guards, reward badges, processed input, controller focus, scroll behavior, and the existing music/purchase/reward flows. Complete the Studio test pass to inspect final pixels and interaction on actual devices.
