function getTurnTokenLocation()

    local turn_token_position = getObjectByName("turn_token").getPosition()

    if  positionHoveringBounds(
            turn_token_position,
            getObjectByName("token_mat").getBounds()
        )
    then
        return "token_mat"
    end

    for _,player_color in ipairs(Player.getAvailableColors()) do
        local bounds = {
            center=getHandZone(player_color).getPosition(),
            size={x=14,y=0,z=14},
            offset={x=0,y=0,z=0}
        }
        if positionHoveringBounds(turn_token_position, bounds) then
            return player_color
        end
    end

    return "unknown"
end

function getAllTokenMatObjects()

    local mat_b = getObjectByName("token_mat").getBounds()
    
    local hit_objects = Physics.cast({
        origin={
            mat_b.center.x,
            mat_b.center.y,
            mat_b.center.z - (mat_b.size.z / 2)
        },
        direction={0,0,1},
        type=3,
        size={mat_b.size.x,4,0},
        max_distance=mat_b.size.z
    })

    local acc = {}
    for _,hit in pairs(hit_objects) do
        local tts_object = hit.hit_object
        if tts_object.type ~= "Surface" then
            table.insert(acc, tts_object)
        end
    end

    return acc
end

function advanceTurnToken()

    turnDeal()
    
    local location = getTurnTokenLocation()
    local turn_order = {}

    for _,player_color in ipairs(Player.getAvailableColors()) do
        if #getCardsInHandZone(player_color) > 0 then
            table.insert(turn_order, player_color)
        end
    end

    for i, player_color in ipairs(turn_order) do
        if player_color == location then
            if i < #turn_order then
                moveTurnTokenTo(turn_order[i+1])
                return
            else
                moveTurnTokenTo(turn_order[1])
                return
            end
        end
    end

    printToAll("Alert: Failure to advance the turn token")
end

function moveTurnTokenTo(color)
    local pos = getHandZone(color).getPosition()
    pos.y = 4
    local token = getObjectByName("turn_token")
    smoothMove(pos)(token)()
end

function getHintTokens()
    local tokens = {}
    for n=1,8 do
        local hint_token = getObjectByName("hint_token_" .. n)
        if hint_token ~= nil and not hint_token.isDestroyed() then
            table.insert(tokens, hint_token)
        end
    end
    return tokens
end

function availableHintTokens()
    local tokens = {}
    for _,hint_token in ipairs(getHintTokens()) do
        if not hint_token.is_face_down then
            table.insert(tokens, hint_token)
        end
    end
    return tokens
end

function usedHintTokens()
    local tokens = {}
    for _,hint_token in ipairs(getHintTokens()) do
        if hint_token.is_face_down then
            table.insert(tokens, hint_token)
        end
    end
    return reverseArray(tokens)
end

function useHintToken()
    return kleisliPipeOnLazy(availableHintTokens, {
        function(ts)
            if #ts > 0 then
                return flipObject(ts[1])
            else
                return liftValuesToCallback(nil)
            end
        end
    })
end

function recoverHintToken()
    return kleisliPipeOnLazy(usedHintTokens, {
        function(ts)
            if #ts > 0 then
                return flipObject(ts[1])
            else
                return liftValuesToCallback(1)
            end
        end
    })
end

function resetHintTokens()
    parallelCallback(mapArray(usedHintTokens(), flipObject))()
end

function getFuseTokens()
    local tokens = {}
    for n=1,3 do
        local fuse_token = getObjectByName("fuse_token_" .. n)
        if fuse_token ~= nil and not fuse_token.isDestroyed() then
            table.insert(tokens, fuse_token)
        end
    end
    return tokens
end

function resetFuseTokens()
    local fuse_tokens = getFuseTokens()

    local token_mat_bounds = getObjectByName("token_mat").getBounds()
    
    for i,fuse in ipairs(fuse_tokens) do
        local pos = {
            x=token_mat_bounds.center.x + (token_mat_bounds.size.x/2) - 2,
            y=token_mat_bounds.center.y + 0.5,
            z=token_mat_bounds.center.y - (token_mat_bounds.size.z/2) + (2 * (i-1))
        }
        smoothMove(pos)(fuse)()
    end
end

function useFuseToken()
    return kleisliPipeOnLazy(
        function()
            local fuse_tokens = getFuseTokens()
            for _,fuse in ipairs(fuse_tokens) do
                if fuse.resting and 
                    positionHoveringBounds(
                        fuse.getPosition(), 
                        getObjectByName('token_mat').getBounds()
                    )
                then return fuse end
            end
        end, {
            continueIf(function(fuse) return fuse ~= nil end),
            tapFunction(function(fuse)
                local num = tonumber(fuse.getName():sub(-1))
                if num == 1 then
                    broadcastToAll("A missfired rocket, the crowd is restless")
                elseif num == 2 then
                    broadcastToAll("A second missfire, be careful")
                elseif num == 3 then
                    broadcastToAll("Final score is " .. getCurrentScore())
                    broadcastToAll("The third missfire, the show cannot go on")
                end
            end),
            smoothMove({0,4,0}),
            smoothMove({0,40,0}),
            function(fuse)

                local mat_bounds = getObjectByName("discard_mat").getBounds()
                local pos = {
                    x=mat_bounds.center.x,
                    y=1,
                    z=mat_bounds.center.z + (mat_bounds.size.z/2) + 0.6
                }

                local taken = true
                while taken do
                    local hits = Physics.cast({
                        origin={pos.x,5,pos.z},
                        direction={0,-1,0},
                        max_distance=10,
                    })
                    taken = false
                    for _,hit in ipairs(hits) do
                        if hit.hit_object.getName():sub(1, -2) == "fuse_token_" then
                            taken = true
                            pos.x = pos.x + 2
                        end
                    end
                end
                return move(pos)(fuse)
            end
        }
    )
end