local types = require("openmw.types")
local world = require("openmw.world")
local core = require("openmw.core")
-- local util = require("openmw.util")
-- local async = require("openmw.async")
-- local vfs = require("openmw.vfs")
local storage = require("openmw.storage")
-- local anim = require("openmw.animation")
-- local I = require("openmw.interfaces")

local objectsWB = storage.globalSection('Objects_wonderbread')

-- this is called when the mod is loaded
-- creates all of the records that we'd need to easily make dough, filled bottls, bread, etc.
local function initializeRecords()
    local recordDraft, record

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
    local fullBottleIds = {}
    for _, bottle in pairs(bottles) do
        recordDraft = types.Miscellaneous.createRecordDraft({
            template = types.Miscellaneous.records[bottle],
            name = 'bottle (full)'
        })
        record = world.createRecord(recordDraft)
        fullBottleIds[bottle] = record.id
    end
    objectsWB:set('full_bottle_ids', fullBottleIds)

    local dough = {
        icon = 'icons/n/tx_pearl.dds', -- changed '\' to '/'
        model = 'meshes/n/ingred_pearl_01.nif',
        name = 'dough',
        -- scale = 2, -- TODO: some way to permanently set the scale of the dough
        template = types.Miscellaneous.records['misc_soulgem_petty'],
        value = 1,
        weight = 0.2
    }
    recordDraft = types.Miscellaneous.createRecordDraft(dough)
    record = world.createRecord(recordDraft)
    objectsWB:set('dough_id', record.id)

    local bakedBread = {
        icon = 'icons/m/tx_bread_01.dds', -- changed '\' to '/'
        model = 'meshes/n/ingred_bread_01.nif',
        name = 'baked bread',
        template = types.Potion.records['p_restore_fatigue_s'],
        weight = 0.2
    }
    recordDraft = types.Potion.createRecordDraft(bakedBread)
    record = world.createRecord(recordDraft)
    objectsWB:set('baked_bread_id', record.id)
end

-- creates a new record and returns it
local function createNewRecord(data)
    -- TODO: come up with a way to create the object without createRecordDraft
    if types[data.type].createRecordDraft == nil then
        print("Error: createRecordDraft is not defined for type " .. data.type)
        return nil
    end
    -- create draft record for the object
    local recordDraft = types[data.type].createRecordDraft({
        icon = data.icon,
        model = data.model,
        name = data.name,
        template = types[data.type].records[data.template],
        value = data.value,
        weight = data.weight
    })

    return world.createRecord(recordDraft)
end

-- create and move an item to the actor's inventory
-- can be based on a completely new record or an existing record
local function createAndMoveToInventory(data)
    local record = nil
    local requestObject = data.object
    -- if we have a template, then create a new record
    -- otherwise, lookup and use the existing record
    if requestObject.template then
        record = createNewRecord(requestObject)
    else
        record = types[requestObject.type].record(requestObject.id)
    end

    if not record then
        print("Error: record not found for type " .. requestObject.type .. " and recordId " .. (requestObject.recordId or "nil"))
        return
    end

    local count = requestObject.count or 1
    local object = world.createObject(record.id, count)

    local scale = requestObject.scale or 1
    object:setScale(scale)

    local player = data.player
    object:moveInto(types.Actor.inventory(player))

    player:sendEvent(data.callback or 'receiveBackData', {
        eventName = 'createAndMoveToInventory',
        eventData = data,
        returnData = {
            object = object
        }
    })
end

-- create and move an item to a given position
-- can be based on a completely new record or an existing record
local function createAndMoveToPosition(data)
    local record = nil
    local requestObject = data.object
    -- if we have a template, then create a new record
    -- otherwise, lookup and use the existing record
    if requestObject.template then
        record = createNewRecord(requestObject)
    else
        record = types[requestObject.type].record(requestObject.id)
    end

    if not record then
        print("Error: record not found for type " .. requestObject.type .. " and recordId " .. (requestObject.recordId or "nil"))
        return
    end

    local count = requestObject.count or 1
    local object = world.createObject(record.id, count)

    local scale = requestObject.scale or 1
    object:setScale(scale)

    local player = data.player
    local position = requestObject.position or player.position
    object:teleport(player.cell, position)

    player:sendEvent(data.callback or 'receiveBackData', {
        eventName = 'createAndMoveToPosition',
        eventData = data,
        returnData = {
            object = object
        }
    })
end

-- either completely removes the object or removes a certain count of the object
local function removeObject(data)
    local o = data.object
    local count = data.count or o.count

    -- check to see if we are looking at the object
    o:remove(count)

    local player = data.player
    
    player:sendEvent(data.callback or 'receiveBackData', {
        eventName = 'removeObject',
        eventData = data,
        returnData = {
            count = o.count -- 0 if fully removed
        }
    })
end

local function onInit()
    -- initialize our records if they aren't already
    if #objectsWB:asTable() == 0 then
        initializeRecords()
    end
end

local function processDoughForPlayer(data)
    local player = data.player
    local dt = data.deltaTime
    -- check to see if there are any dough that could be growing
    for _, item in pairs(player.cell:getAll(types.Miscellaneous)) do
        if item.recordId == objectsWB:get('dough_id') then
            -- is the dougn near hot coals?
            for _, static in pairs(player.cell:getAll(types.Static)) do
                if static.recordId == 'furn_coals_hot' then
                    local dough = item
                    local coals = static
                    -- Is the dough close to the hot coals?
                    if (coals.position - dough.position):length() < 100 then
                        -- dough is near hot coals, so grow it
                        local scaleIncreasePerSecond = .25
                        dough:setScale(dough.scale + (dt * scaleIncreasePerSecond))
                        -- check to see if the dough is now at max size (4)
                        if dough.scale >= 4 then
                            -- remove the dough and create the bread
                            -- create an instance of bread
                            local bread = world.createObject(objectsWB:get('baked_bread_id'), dough.count)
                            -- teleport the bread to the dough's position
                            bread:teleport(player.cell, dough.position)
                            -- remove the dough
                            dough:remove(dough.count)
                        end
                    end
                end
            end
        end
    end
end

return {
    engineHandlers = {
        onInit = onInit
    },
    eventHandlers = {
        createAndMoveToInventory = createAndMoveToInventory,
        createAndMoveToPosition = createAndMoveToPosition,
        removeObject = removeObject,
         processDoughForPlayer = processDoughForPlayer
    }
}