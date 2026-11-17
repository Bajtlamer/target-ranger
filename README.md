# Target Ranger 0.1.7

Range indicator for ranged attackers (first target: Hunter) on WoW Forever, interface 16001.

## What it shows

A small badge on the target frame and/or the target nameplate:

- Positive number (green): the target is inside the range of your main attack (Auto Shot, else Arcane Shot, else Serpent Sting). The number is the upper distance bound in yards.
- Negative number (red): too far. The number is the distance you are known to be beyond.
- Negative number (orange): too close, for example in the Hunter dead zone between melee and Auto Shot.
- Under the number: the estimated distance window, for example `10-35 yd`.
- Floating text IN RANGE / TOO CLOSE / OUT OF RANGE when the state changes.

Distance is estimated by combining spell range checks (Concussive Shot, Hunter's Mark and other ranged spells you know) with the interact distances (about 10, 11 and 28 yards). It is a bracket, not an exact distance, so the number moves in steps (about 10, 11, 28, 35, 100) as you move away.

## Install

Copy the inner `TargetRanger` folder to `/Applications/World of Warcraft/_forever_/Interface/AddOns/` and restart the client.

## Commands (`/tr` or `/ranger`)

- `/tr test` plays a demo sequence without a target
- `/tr debug` prints every probe result for the current target (send this output if the numbers look wrong)
- `/tr anchor target|nameplate|both|screen`
- `/tr text on|off`
- `/tr npc on|off` track NPC targets (default off: NPCs ignored)
- `/tr sameside on|off` track players of your own faction or race (default off: ignored)
- `/tr bg on|off` addon active inside battlegrounds (default on)
- `/tr scale N`
- `/tr unlock` then drag the screen badge, `/tr lock`
- `/tr log on|off|clear` diagnostics log (default on), stored in the SavedVariables file `WTF/Account/<account>/SavedVariables/TargetRanger.lua` after `/reload` or logout
- `/tr log on|off|clear` diagnostics log (default on), stored in the SavedVariables file `WTF/Account/<account>/SavedVariables/TargetRanger.lua` after `/reload` or logout
- `/tr mark` writes a marker line into the log at the moment you see a wrong text
- `/tr on|off`, `/tr reset`

## Known limits

- Spell IDs and range values are not yet verified on the live client; use `/tr debug` to confirm which probes are found.
- Nameplates must be enabled in the game options for the nameplate badge.
- Only tested for syntax outside the game.

## Original artwork

The AddOns list uses the original addon emblem in Artwork/AddonIcon.tga. Logos and avatars for CurseForge are in artwork/v1. A full client restart is needed to discover the texture; live rendering remains to be confirmed.

## Development folders and artwork

Development folder: target-ranger. Runtime addon folders are separate from artwork/. The versioned artwork/v1/ directory contains the original master PNG, logo-1024.png, avatar-400.png for CurseForge, icon-64.png and Icon.tga for each addon. artwork/index.json lists the available versions. Add future designs as a new version directory; keep previous artwork. Marketing PNGs and source masters are excluded from runtime ZIPs.

## CurseForge project text

Ready-to-copy summaries, descriptions and local artwork references are listed in [curseforge/ref-index.md](curseforge/ref-index.md).
