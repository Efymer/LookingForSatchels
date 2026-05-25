# Changelog

## [v1.1]

- Removed Raid Finder support (Raid Finder doesn't exist in MoP Classic)
- The L+ button now only appears on the Dungeon Finder
- Old Raid Finder watch-list entries are stripped on first load

## [v1.0.1]

- Hook CurseForge auto-upload (Project ID 1553678)

## [v1.0]

- Rewritten for Mists of Pandaria Classic (Patch 5.5.3, Interface 50503)
- Split into Settings / Core / UI modules
- Replaced per-frame `OnUpdate` scan loop with `C_Timer.NewTicker`
- Debounced `LFG_UPDATE_RANDOM_INFO` burst so the scan body runs once per poll instead of six times
- L+ / L- buttons moved to the left side of the dropdown name
- Removed the floating L status indicator and the in-game Settings panel; the addon is now controlled entirely through the LFG UI buttons and the queue popup
- Removed the role-icon tooltips next to the L+ buttons and inside the queue popup
- Migrated SavedVariables from positional / 0/1 shapes to booleans and named tables
