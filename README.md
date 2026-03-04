# Sorted Pawn Reloaded

[![CurseForge Downloads](https://img.shields.io/curseforge/dt/1477682?logo=curseforge&color=orange)](https://www.curseforge.com/wow/addons/sorted-pawn-reloaded)

A plugin for the **Sorted** inventory addon that adds a **Pawn upgrade
column**.

This addon restores compatibility with modern World of Warcraft versions
and integrates Pawn upgrade information directly into the Sorted
inventory UI.

------------------------------------------------------------------------

## Features

-   Pawn upgrade percentage column inside **Sorted**
-   Fast caching (no repeated Pawn scans)
-   Gear-only evaluation (ignores bags, profession tools, etc.)
-   Sorting by upgrade percentage
-   Debug commands for troubleshooting
-   Lightweight and safe (does not modify Sorted internals)

------------------------------------------------------------------------

## Commands

`/sp`\
Shows available commands.

`/sp info`\
Shows addon status and integration checks.

`/sp dump`\
Dumps the current equippable item cache.

`/sp debug`\
Toggles debug logging.

------------------------------------------------------------------------

## Requirements

This addon requires the following addons:

**Pawn**\
https://www.curseforge.com/wow/addons/pawn

**Sorted**\
https://www.curseforge.com/wow/addons/sorted

------------------------------------------------------------------------

## Installation

### Option 1 --- CurseForge (recommended)

Download the latest release from CurseForge and extract it into your WoW
AddOns folder.

### Option 2 --- Manual install

Download this repository (or clone it) and place the folder inside your
WoW AddOns directory:

    World of Warcraft/_retail_/Interface/AddOns/

The final folder structure should look like this:

    World of Warcraft
    └─ _retail_
       └─ Interface
          └─ AddOns
             └─ SortedPawnReloaded
                ├─ SortedPawnReloaded.toc
                └─ SortedPawnReloaded.lua

Restart WoW or run `/reload` after installing.

------------------------------------------------------------------------

## Usage

After installing the addon:

1.  Open your bags using **Sorted**
2.  Enable the **Pawn** column in the column selector
3.  The column will display Pawn upgrade percentages for equippable gear
4.  Click the column header to sort items by upgrade value

Items with upgrade percentages will appear at the top when sorting.

------------------------------------------------------------------------

## Compatibility

Tested with:

-   World of Warcraft: **Midnight (12.x)**
-   **Pawn**
-   **Sorted**

------------------------------------------------------------------------

## Contributing

Bug reports and suggestions are welcome.

Please open an issue on GitHub:\
https://github.com/Rmkrs/SortedPawnReloaded

------------------------------------------------------------------------

## License

MIT © Hurons\
https://github.com/Rmkrs
