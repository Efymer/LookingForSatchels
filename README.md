# LookingForSatchels

**Never miss an LFG satchel again.**

`LookingForSatchels` is a lightweight World of Warcraft Mists of Pandaria Classic (5.5.x) addon that watches Blizzard's **Call to Arms** role-bonus system and pings you the instant a satchel becomes available for a dungeon or Raid Finder wing you're tracking — for the roles you're willing to play. When a match appears it flashes the WoW window, plays a sound, prints a chat alert, and pops a draggable **Queue?** dialog letting you join with a single click.

It's designed to run quietly in the background while you're out questing, AFK in a city, or running other content — so you can take advantage of a 30-minute Tank-shortage bonus the moment it drops, without parking yourself in front of the Dungeon Finder window.

## Features

- **Watch list buttons** — an `L+` / `L-` toggle next to the dungeon name on the **Dungeon Finder** and **Raid Finder** frames adds or removes the currently selected dungeon
- **Per-dungeon role overrides** — three role checkboxes appear next to each `L-` button so you can scan for Tank / Heal / Damage shortages on a specific dungeon (or leave them all empty to use your default role set)
- **Raid Finder bulk add** — Shift-click on the Raid Finder `L+` adds all available wings to the watch list; Ctrl-click clears them
- **Background polling** — a 10-second `C_Timer` scan polls the LFG service for role-bonus rewards and fires a raid-warning banner, taskbar flash and sound when a satchel matches
- **One-click queue popup** — a secure **Queue?** dialog joins the dungeon, scenario or Raid Finder wing without navigating Blizzard's UI; safely hides itself during combat or while you're in a group, and re-shows afterwards
- **Shift-click to consume** — Shift-clicking on the popup buttons also removes that dungeon from your watch list, handy for "one Raid Finder wing per week" workflows
- **Per-character state** — watch list and preferences are saved per character

## Installation

1. Close World of Warcraft.
2. Place the `LookingForSatchels` folder into:
   `World of Warcraft\_classic_\Interface\AddOns\`
3. Start the game and enable `LookingForSatchels` in the AddOns list.

The final installed path should be:

```
World of Warcraft\_classic_\Interface\AddOns\LookingForSatchels\LookingForSatchels.toc
```

## Usage

Open the **Dungeon Finder** (`I`) or **Raid Finder** and click the `L+` button next to the dungeon name to start watching that dungeon for Call to Arms satchel bonuses. The button flips to `L-` and three role checkboxes appear — leave them unchecked to scan for every role, or tick specific ones to narrow the scan for this dungeon only.

When a satchel appears for a role you've selected, the addon prints a chat alert, flashes the WoW window icon, plays a sound and shows a draggable **Queue?** popup with one-click Yes/No buttons. Shift-click on the popup's Yes/No also removes that dungeon from your watch list, which is handy if you only want one wing per week.

## Credits

This is a Mists of Pandaria Classic rewrite of the original retail `LookingForSatchels` addon by **lqnrd**. The original concept, queue-popup design and per-dungeon role override are theirs; this version modernises it for MoP Classic 5.5.3 (Interface 50503) with a `C_Timer.NewTicker` scan loop, modular file layout, and the floating status indicator removed.
