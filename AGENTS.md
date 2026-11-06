# AGENTS.md

## Language

All documentation in this repository (README, AGENTS.md, code comments, commit messages) is written in **English**.

## Project

WoW addon `ArkInventoryRules_RestedXP`: registers the ArkInventory rule function `rxpitem()`, which matches items used by the remaining steps of the current RestedXP guide.

- `ArkInventoryRules_RestedXP.toc`: addon manifest, interface `11509` (Classic Era) and `16001` (Classic Forever)
- `ArkInventoryRules_RestedXP.lua`: reads the parsed guide from RestedXP's global `RXP` (`RXP.currentGuide.steps[i].elements`, each element has a `tag` such as `collect` or `use`), the current step from `RXPCData.currentStep` and skipped steps from `RXPCData.stepSkip`. A 2 second ticker notices guide or step changes and clears ArkInventory's rule cache when the item list changed.
- `README.md`: user documentation, keep it in sync with the rule function and the list of guide commands

## Installed copies

The addon is installed as a plain copy (not a clone) in:

- `C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\ArkInventoryRules_RestedXP`

After changing the `.toc` or `.lua`, copy them there. The folder name must stay `ArkInventoryRules_RestedXP`.

## Testing

There is no automated test setup. Changes are verified in game with `/reload`; ArkInventory reports rule errors in chat and in the rule editor (`/ai rules`).
