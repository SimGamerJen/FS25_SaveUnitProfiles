# FS25_SaveUnitProfiles

Save Unit Profiles is a Farming Simulator 25 utility script mod that applies currency and unit preferences automatically based on the loaded savegame slot.

This is the `1.1.0.0` experimental usability build prepared for current FS25 builds using `modDesc descVersion="108"`.

## Features

- Applies unit/currency settings per savegame slot.
- Supports configurable `US`, `UK`, and `EU` profiles by default.
- Uses a per-user config file in `modSettings/FS25_SaveUnitProfiles/saveUnitProfiles.xml`.
- Shows an in-game notification when a profile is applied.
- Can save the current game unit settings for the loaded savegame with `suSaveCurrent`.
- Includes console commands for status, manual apply, reload, UI probing, and debug logging.

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
- `suSaveCurrent` — saves the current game unit settings as a save-specific profile for the loaded savegame.
- `suUiProbe` — logs UI/buttonbar diagnostic information while testing the General Settings button hook.
- `suUiProbe inject` — attempts live button injection into detected buttonbar candidates for diagnostic testing.
- `suDebug on` — enables extra logging.
- `suDebug off` — disables extra logging.

## Notes

- Savegame-to-profile mappings are intentionally edited in XML for this release.
- This mod changes display/unit preferences only. It does not convert money values or alter savegame economy values.
- Because this is a Lua script mod, it is intended for PC/Mac use.

## Version

- Mod version: `1.0.0.0`
- Build tag: `20260514.1`


## Saving the Current Savegame Units

From version 1.1.0.0, the mod can save the currently selected unit settings for the loaded savegame.

Open the in-game General Settings screen, set the unit options as required, then use the **SAVE UNITS** button where available. The mod will create or update a save-specific profile such as `SAVEGAME_12` and map the current save slot to that profile.

If the UI button is not available due to a game update or another UI mod, use the console command:

```text
suSaveCurrent
```

This performs the same save-specific profile update.


## 1.1.0.0 UI Save Units Build

Adds a SAVE UNITS button to the in-game Settings button bar. The button saves the currently selected global unit/currency settings as a save-specific profile for the active savegame. The console fallback command is `suSaveCurrent`.
