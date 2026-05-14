# FS25_SaveUnitProfiles

Save Unit Profiles is a Farming Simulator 25 utility script mod that applies currency and unit preferences automatically based on the loaded savegame slot.

This is the `1.0.0.0` release candidate prepared for current FS25 builds using `modDesc descVersion="108"`.

## Features

- Applies unit/currency settings per savegame slot.
- Supports configurable `US`, `UK`, and `EU` profiles by default.
- Uses a per-user config file in `modSettings/FS25_SaveUnitProfiles/saveUnitProfiles.xml`.
- Shows an in-game notification when a profile is applied.
- Includes console commands for status, manual apply, reload, and debug logging.

## Settings applied

The mod applies the following FS25 game settings at runtime:

- `moneyUnit` — `1 = Euro`, `2 = Dollar`, `3 = Pounds`
- `useMiles`
- `useFahrenheit`
- `useAcre`
- `use24HourTime`

## Install

1. Place `FS25_SaveUnitProfiles.zip` in your Farming Simulator 25 mods folder.
2. Enable the mod for the relevant savegame.
3. Load the save once.
4. The mod will create this config file if it does not already exist:

```text
Documents/My Games/FarmingSimulator2025/modSettings/FS25_SaveUnitProfiles/saveUnitProfiles.xml
```

5. Edit the savegame slot mappings in that file.

## Example config

```xml
<saveUnitProfiles>
    <profiles>
        <profile name="US">
            <money>2</money>
            <miles>true</miles>
            <fahrenheit>true</fahrenheit>
            <acre>true</acre>
            <use24HourTime>false</use24HourTime>
        </profile>
        <profile name="UK">
            <money>3</money>
            <miles>true</miles>
            <fahrenheit>false</fahrenheit>
            <acre>true</acre>
            <use24HourTime>true</use24HourTime>
        </profile>
        <profile name="EU">
            <money>1</money>
            <miles>false</miles>
            <fahrenheit>false</fahrenheit>
            <acre>false</acre>
            <use24HourTime>true</use24HourTime>
        </profile>
    </profiles>
    <savegames>
        <savegame slot="1" profile="UK" />
        <savegame slot="9" profile="US" />
        <savegame slot="12" profile="UK" />
    </savegames>
</saveUnitProfiles>
```

## Console commands

- `suStatus` — shows current slot, profile, and active game settings.
- `suReload` — reloads the XML config.
- `suApply` — applies the mapped profile for the current save.
- `suApply UK` — manually applies a named profile.
- `suApply US` — manually applies a named profile.
- `suDebug on` — enables extra logging.
- `suDebug off` — disables extra logging.

## Notes

- Savegame-to-profile mappings are intentionally edited in XML for this release.
- This mod changes display/unit preferences only. It does not convert money values or alter savegame economy values.
- Because this is a Lua script mod, it is intended for PC/Mac use.

## Version

- Mod version: `1.0.0.0`
- Build tag: `20260514.1`
