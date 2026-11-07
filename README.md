# ArkInventory [Rules] RestedXP

A small plugin for [ArkInventory](https://www.curseforge.com/wow/addons/ark-inventory) that lets ArkInventory rules match items used by the **remaining steps of your current [RestedXP](https://www.restedxp.com/) guide and the guide after it**.

ArkInventory evaluates rule formulas in a sandbox where only its own functions are available. It knows nothing about RestedXP. This plugin registers the rule function `rxpitem()` to fill that gap.

Typical use: a **"Guide items"** bar that holds everything the guide will still ask you to collect, use, buy or equip, so you don't sell or bank it by accident.

## Supported game versions

| Version | Interface |
|---|---|
| WoW Forever | 16001 |

Classic Era and other versions are not supported.

## Requirements

- ArkInventory including **ArkInventoryRules** (enabled)
- RestedXP Guides with a guide loaded

## Installation

Install it from [CurseForge](https://www.curseforge.com/wow/addons/arkinventory-rules-restedxp), e.g. with the CurseForge app.

For a manual installation, note that the folder in your AddOns directory **must** be named `ArkInventoryRules_RestedXP`, otherwise WoW will not load the addon:

```bash
cd "C:/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns"
git clone https://github.com/byWulf/wow-arkinventory-rules-restedxp.git ArkInventoryRules_RestedXP
```

Alternatively, download the ZIP from the [releases](https://github.com/byWulf/wow-arkinventory-rules-restedxp/releases) and extract it into `Interface/AddOns`.

Then `/reload` in game.

## Rule function

| Function | Returns |
|---|---|
| `rxpitem()` | `true` if the item appears in the current step or any later step of the loaded guide, or anywhere in the next guide |
| `rxpitem("use", "collect", …)` | Same, but only for the given guide commands |

Steps that count:

- the current step and every step after it,
- earlier steps that are still active (sticky steps),
- except steps you skipped,
- plus every step of the next guide (the one RestedXP loads when the current guide ends).

Items from steps already behind you (finished or skipped) still count for `collect`, `collectmultiple` and `questitemcount` while the quest they belong to is in your quest log. The turn-in step only names the quest, not the items it needs, so without this the items would drop out as soon as you finish collecting them.

Guide commands that count, and the name to pass to `rxpitem(...)` to filter by them:

| Command | Meaning |
|---|---|
| `collect`, `collectmultiple` | Items to collect (quest items, drops) |
| `use` | Items to use (the item button of the step) |
| `buy` | Items to buy from a vendor |
| `equip` | Items to equip |
| `itemcount`, `questitemcount` | Steps that depend on having the item |
| `bankdeposit`, `bankwithdraw`, `retrieveitem` | Items to put into or take out of the bank |

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

- **The next guide counts too.** Guides often say "keep these, you will need them later" only in the step text, while the matching `collect` is in the next guide (e.g. Murloc Fins in the Wetlands guide for a Redridge quest). So all steps of the guide after the loaded one count as well. Guides further ahead don't.
- **Collected items stay in until the turn-in.** Quest items keep counting after you move past the `collect` step, as long as the quest is in your quest log. Items without a quest (e.g. a plain `collect` for a profession) drop out once their step is behind you.
- **Refresh.** ArkInventory caches rule results. The plugin checks every 2 seconds whether the guide or the current step changed, and also reacts to accepting, turning in or abandoning quests. Only when the resulting item list changed it clears the cache and redraws the bags.
- **Rules beat built-in categories.** A matching rule always wins over default categories. A rule's priority only matters against other rules.
- **Manual assignments beat rules.** An item you assigned to a category by hand stays there.
- Without RestedXP loaded, or without a guide, `rxpitem()` never matches. No errors are raised.

## License

MIT, see [LICENSE](LICENSE).
