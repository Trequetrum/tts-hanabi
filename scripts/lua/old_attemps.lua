

-- Lets us save aribrary data onto cards via getTable('state')
-- We don't accept a nil state (The script will always initialize an
-- empty table). AFAIK, that's the only way to check if the script
-- has been loaded and run.
generated_card_script = [[
    function onSave()
        --log(">>>>> ..... Saving: " .. type(state) .. logString(state))
        if state ~= nil then 
            --log(self.getGUID() .. " >>>>> Save non-Empty state: " .. JSON.encode(state))
            return JSON.encode(state)
        else
            --log(">>>>> Saving Empty State")
            return JSON.encode({})
        end
    end
    function onLoad(json_state)
        --log(">>>>> state: " .. json_state)
        local st = JSON.decode(json_state)
        if st ~= nil then
            --log(">>>>> Load state")
            state = st
        else
            --log(self.getGUID() .. " >>>>> Load empty state")
            state = {}
        end
    end
]]


function overwriteObjStateTable(obj, state, callback)
    local function attempter()
        local local_state = obj.getTable('state')
        if(local_state == nil) then
            Wait.frames(attempter, 1)
        else
            obj.setTable('state', state)
            --log(obj.getGUID() .. " setTable " .. logString(state))
            callback(obj)
        end
    end
    attempter()
end