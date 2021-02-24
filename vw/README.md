# Voidwatch

This addon will automate much of the process of popping and looting voidwatch NMs. It also provides a simple
display with information on your current heavy metal pouches, pulse weapon convert behavior, and whether the
addon is currently running.

This addon tries to be smart about how it handles its settings:
* It will start to relinquish items when you have 3 inventory spots left so that there is still room for a pulse weapon and heavy metal
* If you have it set not to convert pulse weapons, but already have one in your inventory, it will still convert it
* It will take all items from the chest at once if all of them are worth taking, even if you have `vw chest` set to `false`
## Loading the addon
`lua load vw`

## Running the addon
1. Load the addon with `lua load vw`
1. Set the configuration the way you want it with the commands below
1. Once you're at the planar rift, start running the addon with `vw start`

## Commands
|Command|Effect|
|--|--|
|help|Shows all of the commands that can be used|
|status|Shows the current configuration|
|pop|Sets whether to pop the voidwatch NM (default: false)|
|displacers|Sets how many displacers to use when popping (default: 5)|
|convert|Sets whether to convert pulse weapons to cells (default: true)|
|items|Sets whether to take NPC-able items from teh chest (default: true)|
|chest|Sets whether to take the entire chest at once (default: false)|
|cheer|Sets whether to emote when getting a good item (default: false)|
|pulse|Sets the emote to use when getting a pulse weapon or cell (default: /hurray)|
|hmp|Sets the emote to use when getting a heavy metal pouch (default: /cheer)|
|start|Run the addon|
|stop|Stop running the addon|
