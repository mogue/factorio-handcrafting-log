# factorio-handcrafting-log
Factorio game mod that allows you to log and view the items you handcraft in-game.

![Handcrafting Queue](thumbnail.png?raw=true)

The purpose of this mod is to evaluate speedrun related builds, design and optimize the handcrafting queue. Note that speedrun.com does not permit mods so make sure to disable before doing an official run. However the mod does not include any gameplay changing content but use only for practice.

This mod will only start logging once it is added to the gameplay so if you apply it retroactivly to saves it will start logging from the point it's added.

The mod has 3 modes: Queue, Raw and Totals. 

* **Queue** will be a processed list showing you the crafting queue with counts and calculated crafting time and idle time. 
* **Raw** is the unprocessed entries logged from completed handcrafts added to the player inventory. 
* **Totals** shows a summary of the log with items grouped together sorted by what most time was spent on.

Note that all counts will be in recipes completed and not item counts, so 2x Copper Cable will infact have produced 4 Copper Cables but the log will only count 2. So keep that in mind especially when looking at the totals.

.CSV file export is available for the logged data, you will find the exported file in your factorio script-output folder. CSV is an easy to process text data format and is supported by spreadsheet editors such as google spreadsheets.

This mod should work fine with other mods but may give incorrect information if recipes or handcrafting is extensively modified.

Avoid using the mod for longer playthroughs as it will slowly store everything handcrafted in memory. Processing that data will also become more intense as the list grows. For longer playthroughs it should be ok to add and remove the mod if you want to measure the handcrafting queue at certain points. But the mod is designed for short playthroughs and testing purpose.

Supposedly the mod supports multiplayer but hasn't been tested yet.
