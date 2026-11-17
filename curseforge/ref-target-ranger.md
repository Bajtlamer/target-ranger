# Target Ranger

## Summary

A Hunter-focused range indicator for WoW Forever, showing estimated distance brackets and in-range, too-close or too-far alerts on targets and nameplates.

## Description

A compact, Hunter-focused range indicator for WoW Forever. Target Ranger combines available spell-range checks and interaction-distance checks to show an estimated distance bracket and whether your ranged attack is in range, too close or too far away.

### Features

- A range badge on the target frame, target nameplate or movable screen position.
- Green in-range feedback, red too-far feedback and orange too-close feedback.
- An estimated distance window beneath the main number.
- Optional floating messages when the range state changes.
- Configurable display scale, target filters and battleground behavior.

### Requirements and installation

Requires WoW Forever 1.60.1. Install `TargetRanger` in `Interface/AddOns/` and restart the client. Enable target nameplates in the game options if you want a nameplate badge. No Titan Panel dependency is required.

### Getting started

- `/tr test`: preview a demonstration sequence.
- `/tr anchor target|nameplate|both|screen`: choose the display location.
- `/tr unlock` and `/tr lock`: position and lock the screen badge.
- `/tr scale N`: adjust the display scale.
- `/tr text on|off`: control floating messages.
- `/tr npc on|off`: control NPC target tracking.
- `/tr on|off`: enable or disable the addon.

The `/ranger` alias is also available. NPC targets are ignored by default, so enable NPC tracking if you want to use the indicator on them.

### Notes and limitations

The displayed range is a bracket, not an exact continuous distance. It changes in steps as different checks become available. Readable checks depend on your learned spells and the live client. Hunter spell IDs, range values and real-client behavior still need live confirmation.

### Reporting issues

Include the addon version, client build, class, learned ranged abilities, target type and selected anchor. Use `/tr debug` to inspect the available checks and include a screenshot of the unexpected range state. Review diagnostic saved files before sharing them.

## Upload reference (local notes)

Use **Summary** for the short project summary and **Description**, including its subsections, for the main project description. The notes below are preparation references and do not need to be pasted into the public description.

- Current local version: `0.1.7`.
- Intended client: WoW Forever 1.60.1, interface `16001`.
- Runtime folder: `TargetRanger`.
- Dependencies and integrations: No required companion addon. Target nameplates must be enabled to use nameplate badges.
- [400px PNG avatar](../artwork/v1/TargetRanger/avatar-400.png)
- [1024px PNG logo](../artwork/v1/TargetRanger/logo-1024.png)
- [64px PNG icon preview](../artwork/v1/TargetRanger/icon-64.png)
- [Original generated PNG](../artwork/v1/TargetRanger/master.png)
- [All artwork versions](../artwork/)

Suggested screenshots to capture in game: Target in range; target too far; Hunter minimum-range/dead-zone feedback; nameplate or movable screen badge.
