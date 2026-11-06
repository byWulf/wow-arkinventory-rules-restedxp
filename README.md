# ArkInventory [Rules] RestedXP

A small plugin for [ArkInventory](https://www.curseforge.com/wow/addons/ark-inventory) that lets ArkInventory rules match items used by the **remaining steps of your current [RestedXP](https://www.restedxp.com/) guide**.

ArkInventory evaluates rule formulas in a sandbox where only its own functions are available. It knows nothing about RestedXP. This plugin registers the rule function `rxpitem()` to fill that gap.

Typical use: a **"Guide items"** bar that holds everything the guide will still ask you to collect, use, buy or equip, so you don't sell or bank it by accident.

## Supported game versions

| Version | Interface |
|---|---|
| WoW Classic Era | 11509 |
| WoW Classic Forever | 16001 |

Written for Forever. Other versions are untested. If ArkInventory and RestedXP provide the same data there, adding the interface number to the `.toc` is usually enough.

## Requirements

- ArkInventory including **ArkInventoryRules** (enabled)
- RestedXP Guides with a guide loaded

## Installation

The folder in your AddOns directory **must** be named `ArkInventoryRules_RestedXP`, otherwise WoW will not load the addon:

```bash
cd "C:/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns"
git clone https://github.com/byWulf/wow-arkinventory-rules-restedxp.git ArkInventoryRules_RestedXP
```

For Classic Era, use `_classic_era_/Interface/AddOns` instead. Alternatively, download the repository as a ZIP and extract its contents to `Interface/AddOns/ArkInventoryRules_RestedXP/`.

Then `/reload` in game.

## Rule function

| Function | Returns |
|---|---|
| `rxpitem()` | `true` if the item appears in the current step or any later step of the loaded guide |
| `rxpitem("use", "collect", …)` | Same, but only for the given guide commands |

Steps that count:

- the current step and every step after it,
- earlier steps that are still active (sticky steps),
- except steps you skipped.

Guide commands that count, and the name to pass to `rxpitem(...)` to filter by them:

| Command | Meaning |
|---|---|
| `collect`, `collectmultiple` | Items to collect (quest items, drops) |
| `use` | Items to use (the item button of the step) |
| `buy` | Items to buy from a vendor |
| `equip` | Items to equip |
| `itemcount`, `questitemcount` | Steps that depend on having the item |
| `bankdeposit`, `retrieveitem` | Items to put into or take out of the bank |

Left out on purpose: `destroy` (items the guide tells you to throw away) and `usespell` (spells, not items).

## Examples

Everything the rest of the guide needs:

```
rxpitem()
```

Only items you still have to use:

```
rxpitem("use")
```

Guide items, but not quest items that already have their own bar:

```
rxpitem() and not rxpitem("collect")
```

## In-game setup

1. Open `/ai rules` and create a new rule, e.g. "Guide items".
2. Enter a formula, e.g. `rxpitem()`, and enable the rule.
3. In the bag window, right-click a bar → *Categories – Assignable* → *Rule* → assign the new rule to the bar.

## Good to know

- **Only the loaded guide counts.** Items that only the next guide needs show up once that guide is loaded.
- **Collected items stay in.** A `collect` step you already finished still counts until you move past it, because you usually need the items for the turn-in.
- **Refresh.** ArkInventory caches rule results. The plugin checks every 2 seconds whether the guide or the current step changed, and only when the resulting item list changed it clears the cache and redraws the bags.
- **Rules beat built-in categories.** A matching rule always wins over default categories. A rule's priority only matters against other rules.
- **Manual assignments beat rules.** An item you assigned to a category by hand stays there.
- Without RestedXP loaded, or without a guide, `rxpitem()` never matches. No errors are raised.
