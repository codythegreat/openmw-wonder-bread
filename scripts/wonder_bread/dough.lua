local self = require('openmw.self')
local core = require('openmw.core')

return {
  engineHandlers = {
    onUpdate = function(actor)
        -- TODO: make this logic that was copied from the global script work
        -- TODO: is there a better handler to use than onUpdate?

        -- for _, item in pairs(world.players[1].cell:getAll(types.Miscellaneous)) do
        --     if item.recordId == objectsWB:get('dough_id') then
        --         -- is the dougn near hot coals?
        --         for _, static in pairs(world.players[1].cell:getAll(types.Static)) do
        --             if static.recordId == 'furn_coals_hot' then
        --                 local dough = item
        --                 local coals = static
        --                 -- Is the dough close to the hot coals?
        --                 if (coals.position - dough.position):length() < 100 then
        --                     -- dough is near hot coals, so grow it
        --                     -- TODO: make this based on game time instead of on each frame
        --                     dough:setScale(dough.scale + 0.01)
        --                     -- check to see if the dough is now at max size (4)
        --                     if dough.scale >= 4 then
        --                         -- remove the dough and create the bread
        --                         local pos = dough.position
        --                         -- remove the dough
        --                         dough:remove(1)
        --                         -- create an instance of bread
        --                         local bread = world.createObject(objectsWB:get('baked_bread_id'), dough.count)
        --                         -- teleport the bread to the dough's position
        --                         bread:teleport(world.players[1].cell, pos)
        --                     end
        --                 end
        --             end
        --         end
        --     end
        -- end
    end
  }
}