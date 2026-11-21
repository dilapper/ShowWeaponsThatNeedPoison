# ShowWeaponsThatNeedPoison

A World of Warcraft addon for Rogues who forget to reapply poisons.

It shows nothing until you have learned the Poisons ability (level 20), and nothing while your weapons are poisoned. When a weapon has no poison, its icon appears with a pulsing green glow: main hand and off hand are separate icons. The off-hand icon never appears if you don't have an off-hand weapon.

While the icons are unlocked, dimmed placeholders are always visible so you can position them.

## Tooltip and applying poisons

Hover an icon to see the tooltip of the weapon in that slot. To apply a poison without opening your character sheet, right-click the poison in your bags as usual, then left-click the icon of the weapon you want it on.

## Install

Copy the `ShowWeaponsThatNeedPoison` folder into your `Interface/AddOns` directory.

## Options

Open the options panel from Esc > Options > AddOns > ShowWeaponsThatNeedPoison, or with `/swp options`. You can set the icon scale from 0% to 200% (100% is the default, and 0% makes the icons effectively invisible), lock or unlock their positions, and reset everything. Changing the scale keeps the icons centred where they are.

### Linking the icons

Tick **Link the two icons together** to attach the off-hand icon to the main-hand icon. Then choose which side of the main hand the off hand sits on (top, left, bottom or right) and the gap between them (0-10). While linked, dragging either icon moves the pair. The off-hand icon keeps its spot next to the main hand even when the main-hand icon is hidden.

## Positioning

The icons start unlocked. Drag each one where you want it, then click **Lock position**.

| Command | Effect |
| --- | --- |
| `/swp unlock` | Unlock the icons so they can be dragged |
| `/swp lock` | Lock them in place |
| `/swp options` | Open the options panel |
| `/swp scale <0-200>` | Set icon scale in percent (100 = default) |
| `/swp link [on\|off]` | Link or unlink the two icons (no argument toggles) |
| `/swp side top\|left\|bottom\|right` | Side of the main hand the off hand attaches to |
| `/swp gap <0-10>` | Gap between linked icons |
| `/swp reset` | Reset positions |
| `/swp test` | Force both icons visible and glowing (until reload) |
| `/swp status` | Print what the addon sees (for bug reports) |
| `/swp all` | Toggle between Rogue-only and all classes (for testing) |

`/poison` also works as an alias.
