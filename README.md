# FS25_SaveUnitProfiles

**Save Unit Profiles** is a Farming Simulator 25 script mod that allows different savegames to use different currency and unit settings.

Farming Simulator normally stores currency and measurement unit preferences globally. That means if you play a US map using dollars, miles, Fahrenheit and acres, then switch to a UK or European map, those settings can follow you into the next savegame.

Save Unit Profiles fixes that by applying a unit profile for the active savegame.

---

## Current Version

```text
Version: 1.2.0.0
```

---

## What It Does

Save Unit Profiles adds a native **Unit Profile** selector directly into the FS25 settings menu:

```text
General Settings > Units
```

From there, you can choose a regional unit profile such as:

```text
US
UK
EU
CA
BR
JP
CH
PL
```

Selecting a profile immediately applies the profile to the current savegame and stores that mapping in the mod configuration.

The right-hand settings help pane shows what the selected profile means, including the country or region name and the unit choices used by that profile.

Example:

```text
Profile: CA - Canada
Currency: $
Speed / distance: kilometres / km/h
Temperature: Celsius
Field area: acres
Time format: 24-hour
```

---

## Main Features

- Native FS25 settings integration under **General Settings > Units**.
- Per-savegame unit profile assignment.
- Profile selection applies immediately when changed.
- Built-in regional profiles using two-character profile codes.
- Save-specific custom profile support using deterministic `SAVEGAME_##` profile names.
- Right-hand tooltip/help text showing the selected profile’s country/region and unit setup.
- Runtime refresh of the active game settings and visible Settings UI.
- XML configuration stored in the player’s `modSettings` folder.
- Console commands retained for troubleshooting and manual setup.
- No dependency on Additional Currencies or any other currency mod.

---

## Built-in Profiles

Save Unit Profiles includes predefined regional profiles for common map regions and modded map locations.

The selector displays the operational two-character profile code. The right-hand tooltip displays the full country or region name.

Typical examples include:

| Code | Profile |
|---|---|
| US | United States |
| UK | United Kingdom |
| EU | European Union / Central Europe |
| CA | Canada |
| BR | Brazil |
| CN | China |
| CZ | Czech Republic |
| HU | Hungary |
| JP | Japan |
| NO | Norway |
| PL | Poland |
| RO | Romania |
| RU | Russia |
| KR | South Korea |
| CH | Switzerland |
| TR | Turkey |
| UA | Ukraine |

The exact unit settings are shown in-game when each profile is selected.

---

## Custom Savegame Profiles

Custom profiles are savegame-specific.

Clicking **Save Current Units** creates or updates a profile for the current savegame slot using the format:

```text
SAVEGAME_##
```

For example:

```text
SAVEGAME_17
```

This allows you to manually adjust the normal FS25 unit settings, then save that exact setup as the custom profile for the current savegame.

Custom profiles from other savegame slots are not shown in the selector for the active savegame.

---

## How to Use

1. Enable the mod for the savegame.
2. Load the savegame.
3. Open:

```text
General Settings > Units
```

4. Use the **Unit Profile** selector.
5. Select the desired regional profile.

The selected profile is applied immediately and saved for the current savegame.

To save a custom setup:

1. Adjust the normal FS25 unit settings.
2. Click **Save Current Units**.
3. The mod saves those settings as the current savegame’s `SAVEGAME_##` custom profile.
4. The Unit Profile selector updates to that save-specific profile.

---

## Configuration File

The mod stores its configuration here:

```text
Documents/My Games/FarmingSimulator2025/modSettings/FS25_SaveUnitProfiles/saveUnitProfiles.xml
```

The XML file contains:

- profile definitions
- savegame slot mappings
- custom savegame profiles

Manual editing is still supported, but normal use should no longer require editing the XML file directly.

Example savegame mapping:

```xml
<savegame slot="17" profile="CA" />
```

Example custom savegame profile:

```xml
<profile name="SAVEGAME_17">
    <money>3</money>
    <miles>true</miles>
    <fahrenheit>false</fahrenheit>
    <acre>true</acre>
    <use24HourTime>true</use24HourTime>
</profile>
```

---

## Base Currency Notes

Farming Simulator 25’s base game includes the standard money units:

```text
1 = Euro
2 = Dollar
3 = Pound
```

Save Unit Profiles includes integrated regional currency/profile definitions directly in the mod. It does not require Additional Currencies.

Currency changes affect the displayed currency/unit preference. The mod does not change your actual farm balance, prices, economy balancing, loan values, or savegame finances.

---

## Console Commands

Console commands remain available for testing and troubleshooting.

```text
suStatus
suReload
suApply
suApply UK
suApply US
suApply EU
suProfile UK
suProfile CA
suSaveCurrent
suDebug on
suDebug off
```

Common examples:

```text
suStatus
```

Shows the current Save Unit Profiles status.

```text
suReload
```

Reloads the XML configuration.

```text
suProfile CA
```

Assigns and applies the Canada profile to the current savegame.

```text
suSaveCurrent
```

Saves the current in-game unit settings as the current savegame’s custom `SAVEGAME_##` profile.

---

## Changelog

### 1.2.0.0

#### Added

- Added a native **Unit Profile** selector to **General Settings > Units**.
- Added immediate apply-on-selection behaviour for unit profiles.
- Added integrated regional profile/currency support directly in Save Unit Profiles.
- Added predefined profiles for multiple countries and map regions.
- Added right-hand tooltip/help text showing profile country/region and unit details.
- Added save-specific custom profile support using `SAVEGAME_##`.

#### Changed

- Replaced the previous separate UNIT PROFILE button/dialog workflow with a native settings-row selector.
- Profile selection now applies immediately and stores the mapping for the active savegame.
- **Save Current Units** now updates the active savegame’s deterministic custom profile.
- Custom profiles are scoped to the current savegame slot.
- The selector shows two-character profile codes for predefined profiles and `SAVEGAME_##` for current-save custom profiles.
- Removed dependency assumptions around Additional Currencies.

#### Retained

- Existing XML mappings remain supported.
- Manual XML configuration remains possible.
- Console commands remain available for troubleshooting and manual setup.
- Runtime refresh support remains in place so active game settings and the visible Settings UI update immediately.

### 1.1.0.0

- Added a Settings interface action to save the current unit setup.
- Added `suSaveCurrent` console fallback.
- Added automatic save-specific profile creation.

### 1.0.0.0

- Initial public release.
- Added per-savegame unit profile mapping using XML configuration.
- Added default US, UK and EU profile support.
- Added console commands for status, reload, apply and debug functions.

---

## Compatibility

Save Unit Profiles is a PC/Mac script mod.

It is designed to work with normal FS25 savegames and regional/custom maps.

The mod does not require:

```text
Additional Currencies
Additional Game Settings
Realistic Livestock
```

Those mods may be useful references or may coexist in a mod folder, but they are not required for Save Unit Profiles to function.

---

## GitHub

```text
https://github.com/SimGamerJen/FS25_SaveUnitProfiles
```

---

## Author

**SimGamerJen**

Fun first, skills later.
