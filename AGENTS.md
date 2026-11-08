# AGENTS.md

## Language

All documentation in this repository (README, AGENTS.md, code comments, commit messages) is written in **English**.

## Project

WoW addon `ArkInventoryRules_RestedXP`: registers the ArkInventory rule function `rxpitem()`, which matches items used by the remaining steps of the current RestedXP guide.

- `ArkInventoryRules_RestedXP.toc`: addon manifest, interface `16001` (WoW Forever only, Classic Era is not supported)
- `ArkInventoryRules_RestedXP.lua`: reads the parsed guide from RestedXP's global `RXP` (`RXP.currentGuide.steps[i].elements`, each element has a `tag` such as `collect` or `use`), the current step from `RXPCData.currentStep` and skipped steps from `RXPCData.stepSkip`. Elements of earlier steps still count when their quest (`element.questId`, or `element.quests` for `questitemcount`) is in the quest log (`C_QuestLog.IsOnQuest`). Items of finished, not skipped `collect`/`collectmultiple` steps with a quest are also stored in the per-character SavedVariable `ArkInventoryRules_RestedXPCharDB.pendingQuests` (`[questID] = { [itemID] = tag }`) and count until the quest is turned in (`C_QuestLog.IsQuestFlaggedCompleted`), so they survive guide changes. All steps of the next guide count as well (`NEXT_GUIDES`): `#next` of the current guide is resolved like RestedXP does (`;`-separated list, optional `<group>\` prefix, first guide that passes `RXP.IsGuideActive`), then parsed with `RXP:FetchGuide` and filtered with `RXP.ProcessGuideTable` and cached. `RXP.functions.next` is not used because it can load the guide instead of returning it. A 2 second ticker plus the quest events `QUEST_ACCEPTED`, `QUEST_TURNED_IN` and `QUEST_REMOVED` trigger a recalculation; ArkInventory's rule cache is only cleared when the item list changed.
- `README.md`: user documentation, keep it in sync with the rule function and the list of guide commands

## Installed copies

The addon is installed as a plain copy (not a clone) in:

- `C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\ArkInventoryRules_RestedXP`

After changing the `.toc` or `.lua`, copy them there. The folder name must stay `ArkInventoryRules_RestedXP`.

## Testing

There is no automated test setup. Changes are verified in game with `/reload`; ArkInventory reports rule errors in chat and in the rule editor (`/ai rules`).

## Releasing

Published on CurseForge as project `1787600` (https://www.curseforge.com/wow/addons/arkinventory-rules-restedxp) and as GitHub releases. Releases are built by `.github/workflows/release.yml` with the BigWigs packager (`.pkgmeta` sets the folder name and leaves out `AGENTS.md`/`CLAUDE.md`):

1. Commit and push the changes to `main`.
2. Tag and push: `git tag -a vX.Y.Z -m "X.Y.Z"` and `git push origin vX.Y.Z` (semantic versioning).
3. The workflow packages the addon, replaces `@project-version@` in the TOC with the tag, uploads the zip to CurseForge (game version from the TOC interface, WoW Forever) and creates the GitHub release. The changelog is generated from the commit messages since the previous tag.

The CurseForge upload needs the repository secret `CF_API_TOKEN` (a CurseForge author API token). "Run workflow" on the Actions tab builds the package as an artifact without uploading. Never edit `## Version` in the TOC by hand; installed dev copies show `@project-version@`.
