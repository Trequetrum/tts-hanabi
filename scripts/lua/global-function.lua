function positionHoveringBounds(position, bounds)
    return (
        position.x < bounds.center.x + (bounds.size.x / 2) and
        position.x > bounds.center.x - (bounds.size.x / 2) and
        position.z < bounds.center.z + (bounds.size.z / 2) and
        position.z > bounds.center.z - (bounds.size.z / 2)
    )
end

-- Return an index for each color based on the global color_order
-- all multi-color masks return 0
function colorMaskToIndex(color_mask)

    for i, color in ipairs(COLOR_ORDER) do
        if bit32.bor(COLORS_MASK[color], color_mask) == COLORS_MASK[color] then
            return i
        end
    end

    return 0
end

function getFrontFromInfo(info)
    return info.front_number, info.front_color_mask
end

function getObjectByName(name)
    if  Temp_State[name] ~= nil and 
        not Temp_State[name].isDestroyed()
    then
        return Temp_State[name]
    end

    for _,thingy in ipairs(getObjects()) do
        if thingy.getName() == name then
            Temp_State[name] = thingy
            return thingy
        end
    end

    printToAll("ALERT! Cannot find with name: " .. name)

    return nil
end

function startGame(player)

    startDeal()(function()
        moveTurnTokenTo(player.color)
    end)

end

function getPlayer(color, verbose)
    for _, player in ipairs(Player.getPlayers()) do
        if player.color == color then
            return player
        end
    end

    if verbose then
        printToAll("Alert: No seated player for " .. color)
    end
end

function getHandZone(color)
    for _,oby in ipairs(Hands.getHands()) do
        if oby.getValue() == color then
            return oby
        end
    end

    printToAll("Alert: Failure to find hand zone for " .. color)
end

function getCardsInHandZone(color)
    local cards = {}
    for _,thing in ipairs(getHandZone(color).getObjects()) do
        if isHanabiCard(thing) then
            table.insert(cards, thing)
        end
    end
    return cards
end

function getCurrentDealAmount()
    if #Player.getPlayers() > 3 then
        return 4
    else
        return 5
    end
end

function resetCards()
    for _,tts_object in pairs(getObjects()) do
        if isHanabiCard(tts_object) then
            destroyObject(tts_object)
        end
        if isHanabiCardContainer(tts_object) then
            destroyObject(tts_object)
        end
    end
end

function turnDeal()
    local deck = getHanabiDeck(false)
    if deck == nil then
        local token_mat_obs = getAllTokenMatObjects()
        for _,tts_object in pairs(token_mat_obs) do
            if isHanabiCard(tts_object) then
                deck = tts_object
                break
            end
        end
        if deck == nil then
            printToAll("Info: No more cards, no end of turn deal")
            return
        end
    end

    local dealAmount = getCurrentDealAmount()

    for _,player_color in ipairs(Player.getAvailableColors()) do
        local cards = getCardsInHandZone(player_color)
        local deal_diff = dealAmount - #cards
        if #cards > 0 and deal_diff > 0 then
            deck.deal(deal_diff, player_color)
        end
    end
end

function getCurrentScore()

    local score = 0

    for _,color_mask in pairs(COLORS_MASK) do

        local check_z = layoutCardZByColor(color_mask)

        local found_objects = Physics.cast({
            type = 3, -- Box
            direction = {1, 0, 0},
            max_distance = (#NUMBERS_REP - 1) * LAYOUT_CARD_WIDTH,
            origin = { 5.6, 1, check_z },
            size= { 0, 5, 0 }
        })

        local color_score = 0
        for _,found in pairs(found_objects) do
            local tts_object = found.hit_object
            if isHanabiCard(tts_object) then
                local num = JSON.decode(tts_object.memo).front_number
                if num > color_score then
                    color_score = num
                end
            end
        end

        score = score + color_score
    end

    return score

end

function giveHintNumber(player_color, number)
    local cards = getCardsInHandZone(player_color)
    for _,card in pairs(cards) do
        -- front_number
        -- front_color_mask
        -- back_number
        -- back_color_mask
        local info = JSON.decode(card.memo)
        if  info.back_number ~= number and
            info.front_number == number
        then
            info.back_number = number
            card.memo = JSON.encode(info)
            swapCardBack(card, number, info.back_color_mask)(
                function(new_card)
                    new_card.setHiddenFrom({player_color})
                end
            )
        end
    end
end

function giveHintColors(player_color, color_mask)
    local cards = getCardsInHandZone(player_color)
    for _,card in pairs(cards) do
        local info = JSON.decode(card.memo)
        if  info.back_color_mask ~= color_mask and
            bit32.bor(info.front_color_mask, color_mask) == info.front_color_mask
        then
            local updated_mask = bit32.bor(info.back_color_mask, color_mask)
            info.back_color_mask = updated_mask
            card.memo = JSON.encode(info)
            swapCardBack(card, info.back_number, updated_mask)(
                function(new_card)
                    new_card.setHiddenFrom({player_color})
                end
            )
        end
    end
end

function spawnDeckFromInfo(card_info, position)

    if position == nil then
        position = {0,0,0}
    end
    
    local callTable = {}
    for index, info in ipairs(card_info) do
        local i = index - 1
        callTable[index] = spawnCard(
            info.front_url,
            info.back_url,
            info.state,
            {
                (((i * 2) % 30) - 15), 
                0, 
                15 - (math.floor(i/15) * 5)
            }
        )
    end

    return mapCallback(
        function(cards)
            local deck = group(cards)[1]
            deck.setPosition(position)
            return deck
        end,
        parallelCallback(callTable)
    )
end

function startDeal()

    return kleisliPipeOnLazy(function()
            resetHintTokens()
            resetFuseTokens()
            resetCards()
            return getCurrentGameRules().include_rainbow
        end,{
            spawnHanabiDeck,
            function(deck)
                local token_mat_pos = getObjectByName("token_mat").getPosition()
                local deckPos = {
                    x=token_mat_pos.x + 2,
                    y=2,
                    z=token_mat_pos.z + 2
                }
                return parallelCallback({
                    smoothMove(deckPos)(deck),
                    smoothRotation({0,180,180})(deck),
                })
            end,
            mapLiftCallback(pluck(1)),
            waitUntilResting,
            tapFunction(function(deck) deck.shuffle() end),
            tapCallback(waitFrames(30)),
            tapFunction(function(deck)

                local players = Player.getPlayers()
                local dealAmount = getCurrentDealAmount()

                for _, player in ipairs(players) do
                    if  player.getHandCount() > 0 and
                        #player.getHandObjects() == 0
                    then
                        deck.deal(dealAmount, player.color)
                    end
                end

                --[[
                This is just for testing purposes. Deal some cards to another
                player. I've picked red.
                ]]
                if #players == 1 then
                    if #getCardsInHandZone("Red") == 0 then
                        deck.deal(5, "Red")
                    end
                end
            end)
        }
    )
end

function getCurrentGameRules()
    local game_rules = JSON.decode(getObjectByName("token_mat").memo or "")
    if game_rules == nil then
        game_rules = {
            include_rainbow = false,
            rainbow_wild = true,
            rainbow_one_per_firework = true,
            rainbow_firework = true,
            rainbow_multicolor = true,
            rainbow_talking = false
        }

        getObjectByName("token_mat").memo = JSON.encode(game_rules)
    end

    return game_rules
end

function setGameRule(rule, value)
    local is_on = false
    if value == "True" or value == true then
        is_on = true
    end

    local game_rules = getCurrentGameRules()
    game_rules[rule] = is_on
    getObjectByName("token_mat").memo = JSON.encode(game_rules)
    return game_rules
end