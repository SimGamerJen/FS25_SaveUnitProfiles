# FS25_SaveUnitProfiles

**Save Unit Profiles** is a Farming Simulator 25 utility script mod that applies currency and unit preferences per savegame.

It is designed for players who switch between maps from different regions and want each savegame to remember its own regional settings, such as dollars or pounds, miles or kilometres, Fahrenheit or Celsius, and acres or hectares.

## New in 1.1.0.0: Save Units from the Settings Menu

Version `1.1.0.0` adds a **SAVE UNITS** button to the in-game Settings interface.

This means you no longer need to manually edit the XML file for normal setup.

### Recommended setup workflow

1. Load the savegame you want to configure.
2. Open the in-game Settings menu.
3. Set the unit options normally:
   - Money unit
   - Miles / kilometres
   - Fahrenheit / Celsius
   - Acres / hectares
   - 12-hour / 24-hour time
4. Click **SAVE UNITS**.
5. The mod creates or updates a save-specific profile for the currently loaded savegame.

For example, if the current save is `savegame8`, the mod can create a profile such as:

```text
SAVEGAME_8
```

and map that save slot to the saved unit settings automatically.

The XML configuration system is still supported for advanced users and manual editing.

## Features

- Applies unit and currency settings automatically when a configured savegame is loaded.
- Adds a **SAVE UNITS** button to the in-game Settings interface.
- Saves the current unit settings directly to the active savegame profile.
- Supports configurable `US`, `UK`, and `EU` profiles by default.
- Supports custom save-specific profiles such as `SAVEGAME_8`.
- Uses a per-user configuration file in `modSettings/FS25_SaveUnitProfiles/saveUnitProfiles.xml`.
- Shows an in-game notification when a profile is applied or saved.
- Includes console commands for status, manual apply, reload, save-current, and debug logging.

## Settings applied

The mod applies the following FS25 game settings at runtime:

- `moneyUnit` — `1 = Euro`, `2 = Dollar`, `3 = Pounds`
- `useMiles`
- `useFahrenheit`
- `useAcre`
- `use24HourTime`

## Default regional profiles

The included default profiles are:

### US

- Dollars
- Miles
- Fahrenheit
- Acres
- 12-hour time

### UK

- Pounds
- Miles
- Celsius
- Acres
- 24-hour time

### EU

- Euros
- Kilometres
- Celsius
- Hectares
- 24-hour time

## Installation

1. Place `FS25_SaveUnitProfiles.zip` in your Farming Simulator 25 mods folder:

```text
Documents/My Games/FarmingSimulator2025/mods
```

2. Enable the mod for the relevant savegame.
3. Load the savegame.
4. Use the **SAVE UNITS** button in the in-game Settings interface to store the current unit settings for that savegame.

The mod will create its configuration file automatically if it does not already exist:

```text
Documents/My Games/FarmingSimulator2025/modSettings/FS25_SaveUnitProfiles/saveUnitProfiles.xml
```

## Saving units for a savegame

The simplest way to configure a savegame is to use the in-game Settings interface.

1. Load the savegame.
2. Change the unit settings to the values you want.
3. Click **SAVE UNITS**.

The mod will:

- read the currently selected unit settings from the game,
- create or update a save-specific profile,
- map the current save slot to that profile,
- save the changes to `saveUnitProfiles.xml`,
- and show an on-screen confirmation.

If the button is unavailable due to a game update or another UI mod, use the console fallback command:

```text
suSaveCurrent
```

This performs the same save-specific profile update.

## Manual XML configuration

Advanced users can still edit the configuration file directly:

```text
Documents/My Games/FarmingSimulator2025/modSettings/FS25_SaveUnitProfiles/saveUnitProfiles.xml
```

Example configuration:

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
        <savegame slot="12" profile="EU" />
    </savegames>
</saveUnitProfiles>
```

## Console commands

- `suStatus` — shows current slot, profile, and active game settings.
- `suReload` — reloads the XML configuration file.
- `suApply` — applies the mapped profile for the current savegame.
- `suApply UK` — manually applies the `UK` profile.
- `suApply US` — manually applies the `US` profile.
- `suApply EU` — manually applies the `EU` profile.
- `suSaveCurrent` — saves the current game unit settings as a save-specific profile for the loaded savegame.
- `suDebug on` — enables extra logging.
- `suDebug off` — disables extra logging.

## Notes

- The **SAVE UNITS** button is available from the Settings interface and saves the current unit/currency settings for the active savegame.
- Existing manually configured profiles and savegame mappings remain supported.
- This mod changes display/unit preferences only.
- It does not convert money values.
- It does not alter savegame economy values, prices, balances, farm finances, or gameplay difficulty.
- Because this is a Lua script mod, it is intended for PC/Mac use.

## Version

- Mod version: `1.1.0.0`
- Build tag: `20260520.6`
