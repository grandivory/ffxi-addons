_addon.name     = 'voidwatch'
_addon.author   = 'Mojo, with updates by Baeron'
_addon.version  = '1.20200224'
_addon.commands = {'vw'}

require('logger')
require('coroutine')
config = require('config')
packets = require('packets')
res = require('resources')
texts = require('texts')

defaults = {}
defaults.pos = {}
defaults.pos.x = 0
defaults.pos.y = 0
defaults.text = {}
defaults.text.size = 12
defaults.padding = 1
defaults.convert_pulse = true
defaults.pop_nm = false
defaults.displacers = 5
defaults.keep_items = true
defaults.take_chest = false
defaults.cheer = false
defaults.pulse_emote = '/hurray'
defaults.hmp_emote = '/cheer'

settings = config.load(defaults)
display = texts.new('Current Heavy Metal Pouches: ${hmp}\nPulse weapons: ${pulse_setting}\n${running_state}', settings)

local handlers = {}
local choice = {}
local conditions = {
    receive = false,
    box = false,
    rift = false,
    running = false,
    escape = false,
    trade = false,
    cheer = false
}

local bags = {
    'inventory',
    'safe',
    'safe2',
    'storage',
    'locker',
    'satchel',
    'sack',
    'case',
    'wardrobe',
    'wardrobe2',
    'wardrobe3',
    'wardrobe4',
}

local pulse_items = {
    [18457] = 'Murasamemaru',
    [18542] = 'Aytanri',
    [18904] = 'Ephemeron',
    [19144] = 'Coruscanti',
    [19145] = 'Asteria',
    [19174] = 'Borealis',
    [19794] = 'Delphinius',
}

local important_items = {
    [5910] = 'Heavy Metal Pouch',
    [3509] = 'Heavy Metal',
    -- [3508] = 'Crystal Petrifact',
}

-- Items that are worth NPCing or selling on the AH
local npcable_items = {
    -- Smithing
    [654] = 'Darksteel Ingot',
    [756] = 'Durium Ore',
    [2275] = 'Scintillant Ingot',
    [652] = 'Steel Ingot',

    -- Goldsmithing
    [745] = 'Gold Ingot',
    [737] = 'Gold Ore',
    [653] = 'Mythril Ingot',
    [747] = 'Ocl. Ingot',
    [740] = 'Phrygian Ore',
    [746] = 'Platinum Ingot',
    [738] = 'Platinum Ore',
    [791] = 'Aquamarine',
    [801] = 'Chrysoberyl',
    [810] = 'Fluorite',
    [784] = 'Jadeite',
    [802] = 'Moonstone',
    [797] = 'Painite',
    [803] = 'Sunstone',
    [805] = 'Zircon',

    -- Woodworking
    [692] = 'Beech Log',
    [702] = 'Ebony Log',
    [2534] = 'Jacaranda Log',
    [700] = 'Mahogany Log',
    [703] = 'Petrified Log',
    [2532] = 'Teak Log',

    -- Clothcraft
    [823] = 'Gold Thread',
    [830] = 'Rainbow Cloth',
    [1132] = 'Raxa',

    -- Alchemy
    [2189] = 'Fiendish Skin',
    [942] = 'Phil. Stone',
    [844] = 'Phoenix Feather',

    -- Other
    [2496] = 'Anc. Beast Horn',
    [883] = 'Behemoth Horn',
    [5565] = 'Cerberus Meat',
    [887] = 'Coral Fragment',
    [4486] = 'Dragon Heart',
    [4272] = 'Dragon Meat',
    [2408] = 'Flocon-de-mer',
    [2158] = 'Hydra Fang',
    [2172] = 'Hydra Scale',
    [1465] = 'Granite',
    [4386] = 'King Truffle',
    [2198] = 'W. Spider\'s Web',
    [866] = 'Wyvern Scales',
    [1122] = 'Wyvern Skin',
    [2188] = 'Wyvern Tailskin',
}

local cells = {
    ['Cobalt Cell'] = 3434,
    ['Rubicund Cell'] = 3435,
    ['Phase Displacer'] = 3853,
}

function count_hmp()
    local items = windower.ffxi.get_items()
    hmp_count = 0
    for _, bag in pairs(bags) do
        for index = 1, items['max_' .. bag] do
            if items[bag][index].id == 5910 then
                hmp_count = hmp_count + items[bag][index].count
            end
        end
    end
    return hmp_count
end

function pulse_setting_display()
    if settings.convert_pulse then
        return '\\cs(255,0,0)Convert\\cr'
    else
        return '\\cs(0,255,0)Keep\\cr'
    end
end

function running_display()
    if conditions.running then
        return '\\cs(0,255,0)Running\\cr'
    else
        return '\\cs(255,0,0)Stopped\\cr'
    end
end

display.hmp = count_hmp()
display.pulse_setting = pulse_setting_display()
display.running_state = running_display()
texts.show(display)

local function escape()
    conditions['escape'] = true
    while conditions['escape'] do
        log('escaping')
        windower.send_command('setkey escape down')
        coroutine.sleep(.2)
        windower.send_command('setkey escape up')
        coroutine.sleep(1)
    end
end

local function pulse_cheer()
    windower.send_command('input ' .. settings.pulse_emote)
end

local function hmp_cheer()
    windower.send_command('input ' .. settings.hmp_emote)
end

local function calculate_time_offset()
    local self = windower.ffxi.get_player().name
    local members = {}
    for k, v in pairs(windower.ffxi.get_party()) do
        if type(v) == 'table' then
            members[#members + 1] = v.name
        end
    end
    table.sort(members)
    for k, v in pairs(members) do
        if v == self then
            return (k - 1) * .4
        end
    end
end

local function get_mob_by_name(name)
    local mobs = windower.ffxi.get_mob_array()
    for i, mob in pairs(mobs) do
        if (mob.name == name) and (math.sqrt(mob.distance) < 6) then
            return mob
        end
    end
end

local function poke_thing(thing)
    local npc = get_mob_by_name(thing)
    if npc then
        local p = packets.new('outgoing', 0x1a, {
            ['Target'] = npc.id,
            ['Target Index'] = npc.index,
        })
        packets.inject(p)
    end
end

local function poke_rift()
    conditions['rift'] = true
    while conditions['rift'] do
        log('poke rift')
        poke_thing('Planar Rift')
        coroutine.sleep(4)
    end
end

local function poke_box()
    conditions['box'] = true
    while conditions['box'] do
        log('poke box')
        poke_thing('Riftworn Pyxis')
        coroutine.sleep(4)
    end
end

local function trade_cells()
    log('trade cells')
    local npc = get_mob_by_name('Planar Rift')
    if npc then
        local trade = packets.new('outgoing', 0x36, {
            ['Target'] = npc.id,
            ['Target Index'] = npc.index,
        })
        local remaining = {
            cobalt = 1,
            rubicund = 1,
            phase = 5,
        }
        local idx = 1
        local n = 0
        local inventory = windower.ffxi.get_items(0)
        for index = 1, inventory.max do
            if (remaining.cobalt > 0) and (inventory[index].id == cells['Cobalt Cell']) then
                trade['Item Index %d':format(idx)] = index
                trade['Item Count %d':format(idx)] = 1
                idx = idx + 1
                remaining.cobalt = 0
                n = n + 1
            elseif (remaining.rubicund > 0) and (inventory[index].id == cells['Rubicund Cell']) then
                trade['Item Index %d':format(idx)] = index
                trade['Item Count %d':format(idx)] = 1
                idx = idx + 1
                remaining.rubicund = 0
                n = n + 1
            elseif (remaining.phase > 0) and (inventory[index].id == cells['Phase Displacer']) then
                local count = 0
                if (inventory[index].count >= remaining.phase) then
                    count = remaining.phase
                else
                    count = inventory[index].count
                end
                trade['Item Index %d':format(idx)] = index
                trade['Item Count %d':format(idx)] = count
                idx = idx + 1
                remaining.phase = remaining.phase - count
                n = n + count
            end
        end
        trade['Number of Items'] = n
        conditions['trade'] = false
        packets.inject(trade)
        if settings.pop_nm then
            coroutine.schedule(poke_rift, 2)
        end
    end
end

local function observe_box_spawn(id, data)
    if (id == 0x38) and conditions['running'] then
        local p = packets.parse('incoming', data)
        local mob = windower.ffxi.get_mob_by_id(p['Mob'])
        if not mob then elseif (mob.name == 'Riftworn Pyxis') then
            if p['Type'] == 'deru' then
                log('box spawn')
                log('time offset %f':format(calculate_time_offset()))
                coroutine.schedule(poke_box, calculate_time_offset())
            elseif p['Type'] == 'kesu' then
                log('box despawn')
                conditions['trade'] = true
                conditions['box'] = false
                display.hmp = count_hmp()
            end
        end
    end
end

local function observe_rift_spawn(id, data)
    if (id == 0xe) and conditions['running'] and conditions['trade'] then
        local p = packets.parse('incoming', data)
        local npc = windower.ffxi.get_mob_by_id(p['NPC'])
        if not npc then elseif (npc.name == 'Planar Rift') then
            log('rift spawn')
            coroutine.schedule(trade_cells, 1)
        end
    end
end

local function start_fight(id, data)
    if (id == 0x5b) and conditions['rift'] then
        log('start fight')
        local p = packets.parse('outgoing', data)
        p['Option Index'] = (settings.displacers * 0x10) + 1
        p['_unknown1'] = 0
        conditions['rift'] = false
        conditions['escape'] = false
        return packets.build(p)
    end
end

local function has_rare_item(id)
    local items = windower.ffxi.get_items()
    log("Searching for rare item %s":format(res.items[id].en))
    for k, v in pairs(bags) do
        for index = 1, items["max_%s":format(v)] do
            if items[v][index].id == id then
                return true
            end
        end
    end
    return false
end

local function obtain_item(id, data)
    if (id == 0x5b) and conditions['box'] then
        log('obtain item')

        local p = packets.parse('outgoing', data)

        p['Option Index'] = choice.option
        p['_unknown1'] = 0

        -- If we have a pulse weapon, then we want to convert it to a pulse cell if we're configured to do so
        -- or we already have the weapon in our inventory (so can't take another)
        if pulse_items[choice.item] and (settings.convert_pulse or has_rare_item(choice.item)) then
            p['_unknown1'] = 1
		end

        conditions['escape'] = false
        if choice.last then
            conditions['box'] = false
            if conditions.cheer ~= false then
                coroutine.schedule(conditions.cheer, 1)
                conditions.cheer = false
            end
        end
        return packets.build(p)
    end
end

local function examine_rift(id, data)
    if (id == 0x34) and conditions['rift'] then
        coroutine.schedule(escape, 0)
    end
end

local function is_item_rare(id)
    if res.items[id].flags['Rare'] then
        return true
    end
    return false
end

local function examine_box(id, data)
    if (id == 0x34) and conditions['box'] then
        local p = packets.parse('incoming', data)
        local rare = 0
        local count = 0
        local take_items = 0
        choice = {
            last = false,
        }
        local inventory = windower.ffxi.get_bag_info(0)
        -- Leave 3 open spots for pulse + HMP + one empty slot
        local available_inventory = inventory.max - inventory.count - 3

        log('Available Inventory slots: ' .. available_inventory)

        -- Find the items we want to take
        -- Loop through the chest backwards so that we always take the top item first
        for i = 8, 1, -1 do
            local item = p['Menu Parameters']:unpack('I', 1 + (i - 1)*4)
            if not (item == 0) then
                if settings.cheer then
                    if pulse_items[item] then
                        conditions.cheer = pulse_cheer
                    elseif important_items[item] then
                        conditions.cheer = hmp_cheer
                    end
                end

                if pulse_items[item] or important_items[item] then
                    choice.option = i
                    choice.item = item
                    take_items = take_items + 1
                end

                if npcable_items[item] and settings.keep_items and available_inventory > 0 then
                    choice.option = i
                    choice.item = item
                    take_items = take_items + 1
                end
                if is_item_rare(item) and has_rare_item(item) then
                    rare = rare + 1
                end
                count = count + 1
            end
        end

        if (count == take_items or settings.take_chest) and available_inventory >= count and rare ~= count then
            -- Take the entire chest if:
            -- 1. We want to keep every item in the chest AND we have space for them all
            -- 2. settings.take_chest is true AND we have space for all items
            choice.option = 10 -- Take all
            choice.last = (rare == 0)
        elseif not choice.option or rare == count then
            -- Relinquish all items if:
            -- 1. choice.option is NOT set (this also covers the case where we'd normally take the chest but don't have space)
            -- 1. rare is equal to count (all items left in the chest are rare items that we already have)
            choice.option = 9 -- Relinquish
            choice.last = true
        end

        -- In all other cases, choice.option is already set to the item we want to take
        coroutine.schedule(escape, 0)
    end
end

local function start()
    conditions['running'] = true
    display.running_state = running_display()
    trade_cells()
end

local function stop()
    conditions['running'] = false
    display.running_state = running_display()
end

local function toggle_pop()
    settings.pop_nm = not settings.pop_nm
    config.save(settings)
    log('Pop Voidwatch NM: ' .. tostring(settings.pop_nm))
end

local function toggle_convert()
    settings.convert_pulse = not settings.convert_pulse
    config.save(settings)
    log('Convert pulse weapons to cells: ' .. tostring(settings.convert_pulse))
    display.pulse_setting = pulse_setting_display()
end

local function toggle_items()
    settings.keep_items = not settings.keep_items
    config.save(settings)
    log('Keep NPCable items: ' .. tostring(settings.keep_items))
end

local function toggle_chest()
    settings.take_chest = not settings.take_chest
    config.save(settings)
    log('Take the whole chest: ' .. tostring(settings.take_chest))
end

local function toggle_cheer()
    settings.cheer = not settings.cheer
    config.save(settings)
    log('Cheer for good items: ' .. tostring(settings.cheer))
end

local function set_displacers(num_displacers)
    if num_displacers then
        settings.displacers = tonumber(num_displacers)
        config.save(settings)
    end
    log('Number of displacers per pop set to ' .. settings.displacers)
end

local function args_to_string(first, ...)
    local result = first
    for _, next in pairs(arg) do
        if type(next) == 'string' then
            result = result .. ' ' .. next
        end
    end

    return result
end

local function set_pulse_emote(...)
    local emote = args_to_string(unpack(arg))
    if emote ~= nil then
        settings.pulse_emote = emote
        config.save(settings)
    end
    log('Emote for pulse weapons set to ' .. settings.pulse_emote)
end

local function set_hmp_emote(...)
    local emote = args_to_string(unpack(arg))
    if emote ~= nil then
        settings.hmp_emote = emote
        config.save(settings)
    end
    log('Emote for heavy metal set to ' .. settings.hmp_emote)
end

local function show_help()
    print('%s':format(_addon.name))
    print('    \\cs(255,255,255)pop\\cr - Toggles whether to pop the voidwatch NM')
    print('    \\cs(255,255,255)convert\\cr - Toggles whether to convert pulse weapons to pulse cells')
    print('    \\cs(255,255,255)items\\cr - Toggles whether to keep NPCable items')
    print('    \\cs(255,255,255)chest\\cr - Toggles whether to take the entire chest of items')
    print('    \\cs(255,255,255)cheer\\cr - Toggles whether to cheer when getting a good item')
    print('    \\cs(255,255,255)displacers <number>\\cr - Sets the number of displacers to use when popping')
    print('    \\cs(255,255,255)help\\cr - Show this help text')
    print('    \\cs(255,255,255)start\\cr - Start running the script!')
    print('    \\cs(255,255,255)stop\\cr - Stop the script')
    print('    \\cs(255,255,255)status\\cr - Show the current configuration for the addon')
end

local function show_status()
    log('Voidwatch configuration:')
    log('Pop the NM: ' .. tostring(settings.pop_nm))
    log('Number of displacers to use: ' .. settings.displacers)
    log('Convert pulse weapons to cells: ' .. tostring(settings.convert_pulse))
    log('Keep NPC-able items: ' .. tostring(settings.keep_items))
    log('Take the entire chest: ' .. tostring(settings.take_chest))
    log('Cheer for good item drops: ' .. tostring(settings.cheer))
    log('Emote to use for heavy metal: ' .. settings.hmp_emote)
    log('Emote to use for pulse weapons: ' .. settings.pulse_emote)
end

handlers['start'] = start
handlers['stop'] = stop
handlers['pop'] = toggle_pop
handlers['convert'] = toggle_convert
handlers['items'] = toggle_items
handlers['cheer'] = toggle_cheer
handlers['pulse'] = set_pulse_emote
handlers['hmp'] = set_hmp_emote
handlers['displacers'] = set_displacers
handlers['help'] = show_help
handlers['chest'] = toggle_chest
handlers['status'] = show_status

local function handle_command(...)
    local cmd  = (...) and (...):lower()
    local args = {select(2, ...)}
    if handlers[cmd] then
        local msg = handlers[cmd](unpack(args))
        if msg then
            error(msg)
        end
    else
        error("unknown command %s":format(cmd))
    end
end

windower.register_event('addon command', handle_command)
windower.register_event('outgoing chunk', obtain_item)
windower.register_event('incoming chunk', examine_box)
windower.register_event('outgoing chunk', start_fight)
windower.register_event('incoming chunk', examine_rift)
windower.register_event('incoming chunk', observe_box_spawn)
windower.register_event('incoming chunk', observe_rift_spawn)
windower.register_event('load', show_status)