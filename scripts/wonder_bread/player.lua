local types = require("openmw.types")
local self = require("openmw.self")
local core = require("openmw.core")
local util = require("openmw.util")
local camera = require("openmw.camera")
local nearby = require("openmw.nearby")
-- local async = require("openmw.async")
-- local vfs = require("openmw.vfs")
local storage = require("openmw.storage")
-- local anim = require("openmw.animation")
-- local I = require("openmw.interfaces")
local ui = require("openmw.ui")

local settingsWB = storage.playerSection('Settings_wonderbread')
local objectsWB = storage.globalSection('Objects_wonderbread')

-- used mostly for core.sendGlobalEvent
-- since types can't be serialized
local typeMap = {
    [types.Activator] = 'Activator',
    [types.Actor] = 'Actor',
    [types.Apparatus] = 'Apparatus',
    [types.Armor] = 'Armor',
    [types.Book] = 'Book',
    [types.Clothing] = 'Clothing',
    [types.Container] = 'Container',
    [types.Creature] = 'Creature',
    [types.Door] = 'Door',
    [types.ESM4Activator] = 'ESM4Activator',
    [types.ESM4Ammunition] = 'ESM4Ammunition',
    [types.ESM4Armor] = 'ESM4Armor',
    [types.ESM4Book] = 'ESM4Book',
    [types.ESM4Clothing] = 'ESM4Clothing',
    [types.ESM4Door] = 'ESM4Door',
    [types.ESM4Flora] = 'ESM4Flora',
    [types.ESM4Ingredient] = 'ESM4Ingredient',
    [types.ESM4ItemMod] = 'ESM4ItemMod',
    [types.ESM4Light] = 'ESM4Light',
    [types.ESM4Miscellaneous] = 'ESM4Miscellaneous',
    [types.ESM4MovableStatic] = 'ESM4MovableStatic',
    [types.ESM4Potion] = 'ESM4Potion',
    [types.ESM4Static] = 'ESM4Static',
    [types.ESM4StaticCollection] = 'ESM4StaticCollection',
    [types.ESM4Terminal] = 'ESM4Terminal',
    [types.ESM4Weapon] = 'ESM4Weapon',
    [types.Ingredient] = 'Ingredient',
    [types.Item] = 'Item',
    [types.LevelledCreature] = 'LevelledCreature',
    [types.Light] = 'Light',
    [types.Lockable] = 'Lockable',
    [types.Lockpick] = 'Lockpick',
    [types.Miscellaneous] = 'Miscellaneous',
    [types.NPC] = 'NPC',
    [types.Player] = 'Player',
    [types.Potion] = 'Potion',
    [types.Probe] = 'Probe',
    [types.Repair] = 'Repair',
    [types.Static] = 'Static',
    [types.Weapon] = 'Weapon'
}

local bottles = {
    'misc_com_bottle_01',
    'misc_com_bottle_02',
    'misc_com_bottle_03',
    'misc_com_bottle_04',
    'misc_com_bottle_05',
    'misc_com_bottle_06',
    'misc_com_bottle_07',
    'misc_com_bottle_08',
    'misc_com_bottle_09',
    'misc_com_bottle_10',
    'misc_com_bottle_11',
    'misc_com_bottle_12',
    'misc_com_bottle_13',
    'misc_com_bottle_14',
    'misc_com_bottle_15'
}

-- all mortar and pestle objects
local mortarAndPestle = {
    'apparatus_a_mortar_01',
    'apparatus_j_mortar_01',
    'apparatus_m_mortar_01',
    'apparatus_g_mortar_01',
    'apparatus_sm_mortar_01'
}

-- all ingredients that can be converted to dough
local ingredientsToDough = {
    'ingred_wickwheat_01'
}

-- receives back data from the global event
local function receiveBackData(data)
    local debugEnabled = settingsWB:get('debugLoggingEnabled')
    if debugEnabled then
        print('Debug (receiveBackData): eventName - ' .. data.eventName)
    end
end

-- returns true if ANY passed items are in the player's inventory
local function anyInInventory(i)
    -- check if i is a single item or a list of items
    local itemList = i
    if type(i) == 'string' then
        itemList = {i}
    end

    local inventory = types.Actor.inventory(self)

    for _, item in pairs(itemList) do
        if inventory:find(item) then
            return true
        end
    end
    return false
end

local function getAllInInventory(i)
    -- check if i is a single item or a list of items
    local itemList = i
    if type(i) == 'string' then
        itemList = {i}
    end

    local inventory = types.Actor.inventory(self)
    local items = {}
    for _, item in pairs(itemList) do

        local found = inventory:findAll(item)
        
        if found then
            for _, v in ipairs(found) do
                items[#items + 1] = v
            end
        end
    end
    return items
end

-- fires a ray from the camera in the direction the camera is facing, and returns the first object it hits
local function getTarget()
    local origin = camera.getPosition()
    local direction = camera.viewportToWorldVector(util.vector2(0.5, 0.5)) or util.vector3(0, 0, 0)
    local result = nearby.castRenderingRay(
        origin,
        origin + direction * camera.getViewDistance()
    )
    if (result) then return result end
end

-- returns true if the ray hit water, false otherwise
local function hasHitWater(rayResult)
    local waterline = self.cell.waterLevel
    local hit = rayResult.hitPos
    local hitWater = false
	if waterline then
		if hit.z < waterline - 5 then hitWater = true end
    end
    return hitWater
end

-- returns true if the player is close to water, false otherwise
local function isPlayerCloseToWater(rayResult)
    if not self.cell.hasWater then
        return false
    end
    local waterline = self.cell.waterLevel
    local hit = rayResult.hitPos
    local waterHit = util.vector3(hit.x, hit.y, waterline)
    local maxDistance = 300
    return (waterHit - self.position):length() < maxDistance
end

local function contains(list, item)
    for _, v in ipairs(list) do
        if v == item then
            return true
        end
    end
    return false
end

local function onKeyPress(key)
    local hotkey = settingsWB:get('actionHotkey')
    if key.code == hotkey then
        local target = getTarget()
        if hasHitWater(target) then
            if isPlayerCloseToWater(target) then
                -- fill the empty bottles in the player's inventory with water
                local emptyBottles = getAllInInventory(bottles)
                if emptyBottles then
                    for _, bottle in ipairs(emptyBottles) do
                        -- add a full bottle to the player's inventory
                        core.sendGlobalEvent("createAndMoveToInventory", {
                            object = {
                                id = objectsWB:get('full_bottle_ids')[bottle.recordId],
                                type = typeMap[types.Miscellaneous],
                                count = bottle.count,
                            },
                            player = self.object
                        })

                        -- remove the empty bottle from the player's inventory
                        core.sendGlobalEvent("removeObject", {
                            object = bottle,
                            player = self.object
                        })
                    end
                end
            end
        end
        if (target.hit and target.hitObject) then
            if contains(ingredientsToDough, target.hitObject.recordId) then
                -- does the player have a mortar and pestle in their inventory?
                -- TODO: if the player has alchemy mod installed, check for these nearby
                if anyInInventory(mortarAndPestle) then
                    local fullBottleRecordIds = {}
                    for _, v in pairs(objectsWB:get('full_bottle_ids')) do
                        table.insert(fullBottleRecordIds, v)
                    end
                    local fullBottles = getAllInInventory(fullBottleRecordIds)
                    if #fullBottles > 0 then
                        -- total up all the full bottles
                        local totalBottles = 0
                        for _, bottle in ipairs(fullBottles) do
                            totalBottles = bottle.count
                        end

                        -- how many wickwheat are in the hit stack?
                        local totalWick = target.hitObject.count or 1

                        -- only convert as many wickwheat as there are full bottles
                        local toConvert = math.min(totalBottles, totalWick)

                        local position = target.hitPos
                        local count = toConvert

                        -- convert the wickwheat to dough
                        core.sendGlobalEvent('createAndMoveToPosition', {
                            object = {
                                id = objectsWB:get('dough_id'),
                                type = typeMap[types.Miscellaneous],
                                position = position,
                                count = count,
                                -- TODO: could we somehow have a default scale for dough?
                                scale = 2.0
                            },
                            player = self.object,
                            callback = 'attachScript'
                        })

                        core.sendGlobalEvent('removeObject', {
                            object = target.hitObject,
                            count = toConvert,
                            player = self.object
                        })

                        for _, bottle in ipairs(fullBottles) do
                            local toReplace = math.min(toConvert, bottle.count)
                            -- remove the full bottle from the player's inventory
                            core.sendGlobalEvent('removeObject', {
                                object = bottle,
                                count = toReplace,
                                player = self.object
                            })
                            -- add empty bottle(s) to the player's inventory
                            core.sendGlobalEvent('createAndMoveToInventory', {
                                object = {
                                    -- HACK: get the ID from the record's model
                                    -- TODO: this is a hack, should be replaced with a proper ID mapping
                                    id = bottle.type.record(bottle.recordId).model:sub(10, 27),
                                    type = typeMap[types.Miscellaneous],
                                    count = toReplace
                                },
                                player = self.object
                            })
                            toConvert = toConvert - toReplace
                            if toConvert <= 0 then
                                break
                            end
                        end

                        ui.showMessage(string.format(
                            "Converted %d wickwheat%s to dough",
                            toConvert,
                            toConvert > 1 and " items" or ""
                        ))
                    else
                        ui.showMessage("No full bottles found in your inventory.")
                    end
                else
                    ui.showMessage('No mortar and pestle found')
                end
            end
        end
    end
end

return {
    engineHandlers = {
        onKeyPress = onKeyPress
    },
    eventHandlers = {
        receiveBackData = receiveBackData,
    },
}