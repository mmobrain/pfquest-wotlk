### Project Summary: pfQuest-WotLK Performance Overhaul

This update focuses on performance optimizations and stability improvements for the `pfQuest-wotlk` v7.0.1 addon. The primary goal was to address UI lag, stuttering, and FPS drops during common operations like searching the database, updating the quest log, and displaying navigation routes on the map on some devices. The original pfquest is a cross-version compatible add-on, which was stripped of this version including other languages besides **enUS**. It has only been briefly tested on the **WotLK (3.3.5)** client, but only contains a **Vanilla client (1.12) content database**.
This is to ensure compatibility with the Project Epoch server and reduce add-on loading times. **This is probably a one-time modification (for friends and me) that does not envisage further development of this project.**
~~Skulltrail

#### 1. Search & Database Browser (`browser.lua`)

*   **What:** Implemented **Search Throttling (Debouncing)** and **Result Caching**.
    *   **Why:** Previously, the database was searched on every single keystroke, possibly causing significant lag and UI freezes on some devices, especially with large databases. The new system waits for the user to pause typing before initiating a search. Furthermore, search results are now cached, so searching for the same term again is instantaneous.

*   **What:** Optimized the process for updating item information (e.g., quality colors).
    *   **Why:** When displaying a long list of items, the old code would try to fetch information for all of them simultaneously, often causing a noticeable stutter. The updated code now uses an **update queue**, processing only one item per frame. This spreads the workload over time, resulting in a much smoother and more responsive browser experience.
    
    
#### 2. Database & Quest Identification (`database.lua`)

*   **What:** Optimized the `GetQuestIDs` function by pre-filtering quests by exact title *before* performing more complex comparisons.
    *   **Why:** This was a key optimization target. The original function could, in cases of ambiguous quest names, perform very slow string-distance comparisons (Levenshtein) across the entire quest database. The new approach dramatically narrows the search space first, making quest identification in the log nearly instantaneous and eliminating a major source of periodic stuttering.    


#### 3. Quest & Map Updates (`quest.lua`)

*   **What:** Introduced a centralized **Update Scheduler** for quest log and quest giver events.
    *   **Why:** Events like `QUEST_LOG_UPDATE` can fire multiple times in quick succession (e.g., when accepting or turning in quests). The old system would trigger a full, resource-intensive rescan for each event. The new scheduler consolidates these rapid-fire requests into a single, delayed update, preventing redundant calculations and improving overall performance during active questing.


#### 4. Route Drawing & Navigation (`route.lua`)

*   **What:** Completely replaced the route drawing engine. The old "dot-based" system was swapped for an optimized **line-rendering system with texture pooling**.
    *   **Why:** This is the most significant performance enhancement. The previous method of drawing a route by creating hundreds of tiny dot textures was extremely inefficient and a major cause of FPS drops on some devices. The new system draws each segment of the route as a single, long, rotated texture. This reduces the number of UI objects from potentially hundreds to just a handful, drastically improving frame rates and eliminating stuttering when routes are displayed. The use of a texture pool (reusing old line textures instead of creating new ones) further reduces system overhead.

*   **What:** Added a "Progressive Transparency" option for route lines.
    *   **Why:** This is a quality-of-life feature that makes upcoming segments of a long route more transparent, helping the player focus on the immediate path ahead while still seeing the overall direction.


#### 5. Code Structure & Compatibility

*   **What:** General code refactoring, cleaner file loading structure, and improved client compatibility functions.
    *   **Why:** Mainly compatibility with new solutions. Functions (like `GetPlayerFacing` for older clients) were refined for better accuracy, ensuring the addon behaves consistently and reliably. Some modifications to compat/client.lua, map.lua, etc.
    

### Original README.md starts here
**(If you use any of the links below, you will download the original (unmodified) version of pfquest)**
# pfQuest
<img src="https://raw.githubusercontent.com/shagu/ShaguAddons/master/_img/pfQuest/mode.png" float="right" align="right" width="25%">

This is an addon for World of Warcraft Vanilla (1.12) and The Burning Crusade (2.4.3). It helps players to find several ingame objects and quests. The addon reads questobjectives, parses them and uses its internal database to plot the found matches on the world- and minimap. It ships with a GUI to browse through all known objects. If one of the items is not yet available on your realm, you'll see a [?] in front of the name.

The addon is not designed to be a quest- or tourguide, instead the goals are to provide an accurate in-game version of [AoWoW](http://db.vanillagaming.org/) or [Wowhead](http://www.wowhead.com/). The vanilla version is powered by the database of [VMaNGOS](https://github.com/vmangos). The Burning Crusade version is using data from the [CMaNGOS](https://github.com/cmangos) project with translations taken from [MaNGOS Extras](https://github.com/MangosExtras).

pfQuest is the successor of [ShaguQuest](https://shagu.org/ShaguQuest/) and has been entirely written from scratch. In comparison to [ShaguQuest](https://shagu.org/ShaguQuest/), this addon does not depend on any specific map- or questlog addon. It's designed to support the default interface aswell as every other addon. In case you experience any addon conflicts, please add an issue to the bugtracker.

# Downloads
You can check the [[Latest Changes]](https://github.com/shagu/pfQuest/commits/master) page to see what has changed recently.

## World of Warcraft: **Vanilla**
1. **[[Download pfQuest]](https://github.com/shagu/pfQuest/releases/latest/download/pfQuest-full.zip)** (\*)
2. Unpack the Zip-file
3. Move the `pfQuest` folder into `Wow-Directory\Interface\AddOns`
4. Restart Wow
5. Set "Script Memory" to "0" ([HowTo](https://i.imgur.com/rZXwaK0.jpg))

\*) *You can optionally pick one of the slim version downloads instead. Those version are limited to only one specific language: [English](https://github.com/shagu/pfQuest/releases/latest/download/pfQuest-enUS.zip),
[Korean](https://github.com/shagu/pfQuest/releases/latest/download/pfQuest-koKR.zip),
[French](https://github.com/shagu/pfQuest/releases/latest/download/pfQuest-frFR.zip),
[German](https://github.com/shagu/pfQuest/releases/latest/download/pfQuest-deDE.zip),
[Chinese](https://github.com/shagu/pfQuest/releases/latest/download/pfQuest-zhCN.zip),
[Spanish](https://github.com/shagu/pfQuest/releases/latest/download/pfQuest-esES.zip),
[Russian](https://github.com/shagu/pfQuest/releases/latest/download/pfQuest-ruRU.zip)*

## World of Warcraft: **The Burning Crusade**
1. **[[Download pfQuest]](https://github.com/shagu/pfQuest/releases/latest/download/pfQuest-full-tbc.zip)** (\*)
2. Unpack the Zip-file
3. Move the `pfQuest-tbc` folder into `Wow-Directory\Interface\AddOns`
4. Restart Wow

\*) *You can optionally pick one of the slim version downloads instead. Those version are limited to only one specific language: [English](https://github.com/shagu/pfQuest/releases/latest/download/pfQuest-enUS-tbc.zip),
[Korean](https://github.com/shagu/pfQuest/releases/latest/download/pfQuest-koKR-tbc.zip),
[French](https://github.com/shagu/pfQuest/releases/latest/download/pfQuest-frFR-tbc.zip),
[German](https://github.com/shagu/pfQuest/releases/latest/download/pfQuest-deDE-tbc.zip),
[Chinese](https://github.com/shagu/pfQuest/releases/latest/download/pfQuest-zhCN-tbc.zip),
[Spanish](https://github.com/shagu/pfQuest/releases/latest/download/pfQuest-esES-tbc.zip),
[Russian](https://github.com/shagu/pfQuest/releases/latest/download/pfQuest-ruRU-tbc.zip)*

## World of Warcraft: **Wrath of the Lich King**

> [!IMPORTANT]
>
> **This is a BETA version of pfQuest**
>
> It is able to run on a WotLK (3.3.5a) client, but does not yet ship a WotLK database.
> Every available content is limited to Vanilla & TBC as of now.

1. **[[Download pfQuest]](https://github.com/shagu/pfQuest/releases/latest/download/pfQuest-full-wotlk.zip)** (\*)
2. Unpack the Zip-file
3. Move the `pfQuest-wotlk` folder into `Wow-Directory\Interface\AddOns`
4. Restart Wow

\*) *You can optionally pick one of the slim version downloads instead. Those version are limited to only one specific language: [English](https://github.com/shagu/pfQuest/releases/latest/download/pfQuest-enUS-wotlk.zip),
[Korean](https://github.com/shagu/pfQuest/releases/latest/download/pfQuest-koKR-wotlk.zip),
[French](https://github.com/shagu/pfQuest/releases/latest/download/pfQuest-frFR-wotlk.zip),
[German](https://github.com/shagu/pfQuest/releases/latest/download/pfQuest-deDE-wotlk.zip),
[Chinese](https://github.com/shagu/pfQuest/releases/latest/download/pfQuest-zhCN-wotlk.zip),
[Spanish](https://github.com/shagu/pfQuest/releases/latest/download/pfQuest-esES-wotlk.zip),
[Russian](https://github.com/shagu/pfQuest/releases/latest/download/pfQuest-ruRU-wotlk.zip)*

## Development Version
The development version includes databases of all languages and client expansions. Based on the folder name, this will launch in both vanilla and tbc mode. Due to the amount of included data, this snapshot will lead to a higher RAM/Disk-Usage and slightly increased loading times.

- Download via Git: [`https://github.com/shagu/pfQuest.git`](https://github.com/shagu/pfQuest.git)
- Download via Browser: **[Zip File](https://github.com/shagu/pfQuest/archive/master.zip)**

## Controls
- To change node colors on the World Map, **click** the node.
- To remove previously done quests from the map, **\<shift\>-click** the quest giver on the world-map
- To temporarily hide clusters on the world-map, hold the **\<ctrl\>-key**
- To temporarily hide nodes on the mini-map, hover it and hold the **\<ctrl\>-key**
- To move the minimap-button, **\<shift\>-drag** the icon
- To move the arrow, **\<shift\>-drag** the frame

## Addon Memory Usage
The addon ships an entire database of all spawns, objects, items and quests and therefore includes a huge database (~80 MB incl. all locales) that gets loaded into memory on game launch. However, the memory usage of pfQuest is persistent and does not increase any further over time, so there's nothing bad on performance at all. Depending on the download you pick (especially the full packages), you might see a message that warns you about an addon consuming too much memory. To get rid of that warning, you can set the addon memory limit to `0` which reads as `no limit`. This option can be found in the [character selection screen](https://i.imgur.com/rZXwaK0.jpg).

# Map & Minimap Nodes
<img src="https://raw.githubusercontent.com/shagu/ShaguAddons/master/_img/pfQuest/arrow.jpg" width="35.8%" align="left">
<img src="https://raw.githubusercontent.com/shagu/ShaguAddons/master/_img/pfQuest/minimap-nodes.png" width="59.25%">
<img src="https://raw.githubusercontent.com/shagu/ShaguAddons/master/_img/pfQuest/map-quests.png" width="55.35%" align="left">
<img src="https://raw.githubusercontent.com/shagu/ShaguAddons/master/_img/pfQuest/map-spawnpoints.png" width="39.65%">

# Auto-Tracking
<img src="https://raw.githubusercontent.com/shagu/ShaguAddons/master/_img/pfQuest/map-autotrack.png" float="right" align="right" width="30%">
The addon features 4 different modes that define how the new or updated questobjectives should be handled. Those modes can be selected on the dropdown menu in the top-right area the map.

### Option: All Quests
Every quest will be automatically shown and updated on the map.

### Option: Tracked Quests
Only tracked quests (Shift-Click) will be automatically shown and updated on the map.

### Option: Manual Selection
Only quest objectives that have been manually displayed ("Show"-Button in the Questlog) will be displayed.
Completed quest objectives will be still automatically removed from the map.

### Option: Hide Quests
Same as "Manual Selection" and in addition to that, Quest-Givers won't be shown automatically.
Also completed quest objectives will remain on the map. This mode won't touch any of the map nodes created.

# Database Browser
<img src="https://raw.githubusercontent.com/shagu/ShaguAddons/master/_img/pfQuest/browser-spawn.png" align="left" width="30%">
<img src="https://raw.githubusercontent.com/shagu/ShaguAddons/master/_img/pfQuest/browser-quests.png" align="left" width="30%">
<img src="https://raw.githubusercontent.com/shagu/ShaguAddons/master/_img/pfQuest/browser-items.png" align="center" width="33%">

The database GUI allows you to bookmark and browse through all entries within the pfQuest database. It can be opened by a click on the pfQuest minimap icon or via `/db show`. The browser will show a maximum of 100 entries at once for each tab. Use your scrollwheel or press the up/down arrows to go up and down the list.

# Questlog Integration
### Questlinks
<img src="https://raw.githubusercontent.com/shagu/ShaguAddons/master/_img/pfQuest/questlink.png" float="right" align="right" width="30%">

On servers that support questlinks, a shift-click on a selected quest will add a questlink into chat. Those links are similar to the known questlinks from TBC+ and are compatible to ones produced by [ShaguQuest](https://shagu.org/ShaguQuest/), [Questie](https://github.com/AeroScripts/QuestieDev) and [QuestLink](http://addons.us.to/addon/questlink-0). Please be aware that some servers (e.g Kronos) are blocking questlinks and you'll have to disable this feature in the pfQuest settings, in order to print the quest name into the chat instead of adding a questlink. Questlinks sent from pfQuest to pfQuest are locale independent and rely on the Quest ID.

The tooltip will display quest information such as your current state on the quest (new, in progress, already done) as well as the quest objective text and the full quest description. In addition to that, the suggested level and the minimum level are shown.

### Questlog Buttons
<img src="https://raw.githubusercontent.com/shagu/ShaguAddons/master/_img/pfQuest/questlog-integration.png" align="left" width="300">

The questlog will show 4 additional buttons on each quest in order to provide easy manual quest tracking. Those buttons can be used to show or hide individual quests on the map. Those buttons won't affect the entries that you've placed by using the database browser.

**Show**  
The "Show" button will add the questobjectives of the current quest to the map.

**Hide**  
The "Hide" button will remove the current selected quest from the map.

**Clean**  
The "Clean" button will remove all nodes that have been placed by pfQuest from the map.

**Reset**  
The "Reset" button will restore the default visibility of icons to match the set values on the map dropdown menu (e.g "All Quests" by default).

# Chat/Macro CLI
<img src="https://raw.githubusercontent.com/shagu/ShaguAddons/master/_img/pfQuest/chat-cli.png">

The addon features a CLI interface which allows you to easilly create macros to show your favourite herb or mining-veins. Let's say you want to display all **Iron Deposit** deposits, then type in chat or create a macro with the text: `/db object Iron Deposit`. You can also display all mines on the map by typing: `/db mines`. This can be extended by giving the minimum and maximum required skill as paramter, like: `/db mines 150 225` to display all ores between skill 150 and 225. The `mines` parameter can also be replaced by `herbs`, `rares`, `chests` or `taxi` in order to show those instead. If `/db` doesn't work for you, there are also some other aliases available like `/shagu`, `pfquest` and `/pfdb`.
