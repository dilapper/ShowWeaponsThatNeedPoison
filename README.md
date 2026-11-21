# ShowWeaponsThatNeedPoison

A World of Warcraft addon for Rogues who forget to reapply poisons.

It shows nothing while your weapons are poisoned. When a weapon has no poison, its icon appears with a pulsing green glow: main hand and off hand are separate icons. The off-hand icon never appears if you don't have an off-hand weapon.

While the icons are unlocked, dimmed placeholders are always visible so you can position them.

## Install

Copy the `ShowWeaponsThatNeedPoison` folder into your `Interface/AddOns` directory.

## Positioning

The icons start unlocked. Drag each one where you want it, then click **Lock position**.

| Command | Effect |
| --- | --- |
| `/swp unlock` | Unlock the icons so they can be dragged |
| `/swp lock` | Lock them in place |
| `/swp size <16-200>` | Set icon size |
| `/swp reset` | Reset positions |
| `/swp all` | Toggle between Rogue-only and all classes (for testing) |

`/poison` also works as an alias.
