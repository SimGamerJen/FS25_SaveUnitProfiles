# FS25_SaveUnitProfiles

First-pass Farming Simulator 25 script mod to apply currency and unit preferences per savegame slot.

## What it changes

It uses `g_gameSettings:setValue(settingName, value, true)` for:

- `moneyUnit` — 1 Euro, 2 Dollar, 3 Pounds
- `useMiles`
- `useFahrenheit`
- `useAcre`
- `use24HourTime`

The settings are global FS25 profile settings, so the mod applies the selected profile shortly after a save loads.

## Install

1. Put `FS25_SaveUnitProfiles.zip` in your FS25 mods folder.
2. Enable it for the relevant save.
3. Load the save once.
4. The mod will create:

```text
Documents/My Games/FarmingSimulator2025/modSettings/FS25_SaveUnitProfiles/saveUnitProfiles.xml
```

5. Edit the `<savegames>` mappings to match your save slots.

## Example config

```xml
<savegame slot="9" profile="US" />
<savegame slot="12" profile="UK" />
```

## Console commands

Open the developer console and use:

```text
suStatus
suReload
suApply
suApply UK
suApply US
suDebug on
suDebug off
```

## Test plan

1. Load a US save mapped to `US`.
2. Run `suStatus`.
3. Confirm `moneyUnit` is 2 and Fahrenheit is true.
4. Save and quit.
5. Load a UK save mapped to `UK`.
6. Run `suStatus`.
7. Confirm `moneyUnit` is 3 and Fahrenheit is false.

If the values change in `suStatus` but parts of the UI do not refresh immediately, close and reopen the affected menu screen. If FS25 caches a setting until game restart, this mod proves the mapping but an external launcher would be needed for that setting.
