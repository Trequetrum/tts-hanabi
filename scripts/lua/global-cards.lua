-- Get the url for a corresponding number and color_mask. When loaded,
-- this shows automated player 'notes' on the back of their cards
function generated_back_url(num, color_mask)
    if num == 0 and color_mask == 0 then
        return ASSET_BACK_BLANK_URL
    end

    local colors_str = ""
    local num_str = ""

    for _, color in ipairs(COLOR_ORDER) do
        if bit32.band(COLORS_MASK[color], color_mask) == COLORS_MASK[color] then
            colors_str = colors_str .. color
        end
    end
    if NUMBERS_REP[num] ~= nil then
        num_str = num_str .. NUMBERS_REP[num]
    end

    return ASSET_GENED_URL .. "back_" .. num_str .. colors_str .. "_" .. ASSET_VERSION .. ".png"
end

function generated_front_url_char(num, color_char)
    return ASSET_URL .. color_char .. num .. "_" .. ASSET_VERSION .. ".png"
end

function generated_front_url(num, color_mask)
    for color, mask in pairs(COLORS_MASK) do
        if mask == color_mask then
            return generated_front_url_char(num, color)
        end     
    end
    return generated_front_url_char(num, "a")
end

-- Return a table of starting card URLs and states
function generateDeckInfo()

    local deck_info = {}

    for num, _ in ipairs(NUMBERS_REP) do
        local layout_num = COLOR_LAYOUT.default
        if COLOR_LAYOUT[num] ~= nil then
            layout_num = COLOR_LAYOUT[num]
        end
        for i = 1, layout_num do
            for color, mask in pairs(COLORS_MASK) do
                table.insert(deck_info, {
                    front_url = generated_front_url_char(num, color),
                    back_url = generated_back_url(0,0),
                    state = {
                        front_number = num,
                        front_color_mask = mask,
                        back_number = 0,
                        back_color_mask = 0
                    }
                })
            end
        end
    end

    return deck_info

end

function isHanabiCard(tts_object)
    if tts_object == nil then return false end

    local info = JSON.decode(tts_object.memo or "")
    if  info ~= nil and 
        info.front_number ~= nil and 
        info.front_color_mask ~= nil then
            return true
    end
    return false
end

function isHanabiCardContainer(tts_object)
    if tts_object.getQuantity() > 0 then
        local cards = tts_object.getObjects()
        for _,card in ipairs(cards) do
            if isHanabiCard(card) then
                return true
            end
        end
    end
    return false
end


function discardCard(card)
    return kleisliPipeOnLazy(
        function()
            local card_info = JSON.decode(card.memo)
            local card_num = card_info.front_number
            local card_color_mask = card_info.front_color_mask

            local move_coords = layoutDiscardCard(card_num, card_color_mask)
            move_coords.y = 3
            
            while cardPlaced(
                move_coords.x,
                move_coords.z,
                card_info.front_number,
                card_info.front_color_mask
            ) do
                move_coords.x = move_coords.x + LAYOUT_CARD_WIDTH
            end

            return move_coords
        end, {
            remember(curryFlip(smoothMove)(card)),
            remember(smoothRotation({0,180,0})),
            function(card, _, move_coords)
                local card_info = JSON.decode(card.memo)
                move_coords.y = 1
                while cardPlaced(
                    move_coords.x,
                    move_coords.z,
                    card_info.front_number,
                    card_info.front_color_mask
                ) do
                    move_coords.x = move_coords.x - LAYOUT_CARD_WIDTH
                end
                return smoothMove(move_coords)(card)
            end
        }
    )
end

function layoutPlayCard(card_num, color_mask)
    local color_index = colorMaskToIndex(color_mask)
    local left_column = -40.16 + LAYOUT_CARD_WIDTH * (#NUMBERS_REP*2+1)
    local top_row_z = 13.54

    return Vector({
        x=left_column + color_index * LAYOUT_CARD_WIDTH,
        y=1,
        z=top_row_z - (LAYOUT_CARD_HEIGHT * (#NUMBERS_REP-card_num))
    })
end

function layoutDiscardCard(card_num, color_mask)
    local color_index = colorMaskToIndex(color_mask)
    local left_column = -40.16
    local top_row_z = 13.54

    local x_offset = left_column
    for each_num, _ in ipairs(NUMBERS_REP) do

        local layout_num = COLOR_LAYOUT.default
        if COLOR_LAYOUT[each_num] ~= nil then
            layout_num = COLOR_LAYOUT[each_num]
        end

        if card_num > each_num then
            x_offset = x_offset + LAYOUT_CARD_WIDTH * layout_num
        end
    end

    return Vector({
        x=x_offset,
        y=1,
        z=top_row_z - (LAYOUT_CARD_HEIGHT * color_index)
    })
end

-- include_rainbow
-- rainbow_wild
-- rainbow_one_per_firework
-- rainbow_firework
-- rainbow_multicolor
-- rainbow_talking
function playCard(card)
    return kleisliPipeOn(card, {
        tapFunction(function(t) t.setLock(true) end),
        function(card)
            local info = JSON.decode(card.memo)
            local num = info.front_number
            local color_mask = info.front_color_mask

            local move_coords = layoutPlayCard(num, color_mask)
            move_coords.y = 3

            if  color_mask ~= COLORS_MASK.a or
                (not getCurrentGameRules().rainbow_wild and
                getCurrentGameRules().rainbow_firework)
            then
                return liftValuesToCallback(move_coords, card)
            else
                return askAfterRainbowPlayLocation(card)
            end
        end,
        remember(function(coords, card)
            if coords.y < 0 then
                return liftValuesToCallback(card, true)
            else
                return smoothMove(coords)(card)
            end
        end),
        tapFunction(function(t) t.setLock(false) end),
        function(card, _, move_coords)

            local num = JSON.decode(card.memo).front_number

            if  move_coords.y < 0 or
                cardPlaced(move_coords.x,move_coords.z) or
                ( num ~= 1 and 
                not cardPlaced(
                    move_coords.x,
                    move_coords.z - LAYOUT_CARD_HEIGHT
                ))
            then
                return kleisliPipeOn(card, {
                    discardCard,
                    tapCallback(useFuseToken())
                })
            end
            return kleisliPipeOn(card, {
                smoothRotation({0,180,0}),
                waitUntilResting
            })
        end
    })
end

function askAfterRainbowPlayLocation(card)
    local info = JSON.decode(card.memo)
    local card_num = info.front_number
    local card_color_mask = info.front_color_mask

    if card_color_mask ~= COLORS_MASK.a then
        printToAll("Alert: askAfterRainbowPlayLocation run without rainbow card")
        return liftValuesToCallback(Vector(-1,-1,-1), card)
    end

    local viable_masks = {}

    local played_cards = cardFireworkStatus()

    for _,color_mask in pairs(COLORS_MASK) do
        if  -- We can only play rainbow if it is it's own firework and
            (   color_mask ~= COLORS_MASK.a or
                getCurrentGameRules().rainbow_firework
            ) and
            -- We can only play a number if there's a sport for it and
            played_cards[color_mask].count + 1 == card_num and
            -- Either the firework has no rainbow yet or it's the
            -- rainbow firework (So it can have as many as it likes)
            -- or we can have more than one wild card per firework
            (   (not played_cards[color_mask].rainbow) or
                color_mask == COLORS_MASK.a or
                (not getCurrentGameRules().rainbow_one_per_firework)
            )
        then
        -- logs(">>>>>\n\n>>>>> color_mask", color_mask, "\n",
        -- ">>>>> getCurrentGameRules().rainbow_firework", getCurrentGameRules().rainbow_firework, "\n",
        -- ">>>>> played_cards[color_mask].count + 1", played_cards[color_mask].count + 1, "\n",
        -- ">>>>> card_num", card_num, "\n",
        -- ">>>>> played_cards[color_mask].rainbow", played_cards[color_mask].rainbow, "\n")

            table.insert(viable_masks, color_mask)
        end
    end

    if #viable_masks < 1 then
        return liftValuesToCallback(Vector(-1,-1,-1), card)
    elseif #viable_masks == 1 then
        local pos = layoutPlayCard(card_num, viable_masks[1])
        pos.y = 3
        return liftValuesToCallback(pos, card)
    else
        return function(callback)
            Temp_State.askAfterRainbowPlayLocation = {
                callback=function(card_num, card_color_mask)
                    Temp_State.askAfterRainbowPlayLocation = nil
                    ui_LoadUI()

                    local pos = layoutPlayCard(card_num, card_color_mask)
                    pos.y = 3
                    callback(pos, card)
                end,
                card_num=card_num,
                color_masks=viable_masks
            }
            ui_LoadUI()
        end
    end

end

function cardFireworkStatus()

    local retTbl = {}

    for _,color_mask in pairs(COLORS_MASK) do

        retTbl[color_mask] = {
            count = 0,
            rainbow = false
        }
        local check_pos = layoutPlayCard(1, color_mask)
        check_pos.y = 2

        local found_objects = Physics.cast({
            type = 3, -- Box
            direction = {0, 0, 1},
            max_distance = (#NUMBERS_REP - 1) * LAYOUT_CARD_HEIGHT,
            origin = check_pos,
            size= { 0, 4, 0 },
            debug=true
        })

        for _,found in pairs(found_objects) do
            local tts_object = found.hit_object
            if isHanabiCard(tts_object) then
                local mask = JSON.decode(tts_object.memo).front_color_mask
                retTbl[color_mask] = {
                    count = retTbl[color_mask].count + 1,
                    rainbow = 
                        retTbl[color_mask].rainbow or
                        (mask == COLORS_MASK.a)
                }
            end
        end

    end

    return retTbl

end

-- Check for a hanabi card at the given global x,z coords. Optionally
-- supply a num and/or color to also check if the card matches.
function cardPlaced(x, z, num, color)
    local hits = Physics.cast({
        origin = {x, 2, z},
        direction = {0, -1, 0},
        type = 1, -- ray
        max_distance = 5
    })

    local match = false

    for _,hit in ipairs(hits) do
        local tts_object = hit.hit_object
        if isHanabiCard(tts_object) then
            local card_info = JSON.decode(tts_object.memo)
            local hit_num = card_info.front_number
            local hit_color = card_info.front_color_mask

            match = true
            if num ~= nil and hit_num ~= num then
                match = false
            end
            if color ~= nil and hit_color ~= color then
                match = false
            end
            if match == true then
                return match
            end
        end
    end

    return match
end

function getHanabiDeck(verbose)
    if  Temp_State.deck ~= nil and 
        not Temp_State.deck.isDestroyed()
    then
        return Temp_State.deck
    end

    function getDeckInList(list)
        for _,thingy in ipairs(list) do
            if isHanabiCardContainer(thingy) then
                Temp_State.deck = thingy
                return thingy
            end
        end
        return nil
    end

    local deck = getDeckInList(getTokenMatObjects())
    if deck ~= nil then
        Temp_State.deck = deck
        return deck 
    end

    deck = getDeckInList(getObjects())
    Temp_State.deck = deck

    if deck == nil and verbose then
        printToAll("Alert: Failure to find hanabi deck")
    end

    return deck
end

-- Create the hanabi deck, decide whether to include rainbows
function spawnHanabiDeck(include_rainbow)
    local deck_info = generateDeckInfo()
    if not include_rainbow then
        deck_info = filterArray(
            deck_info,
            function(info)
                return info.state.front_color_mask ~= COLORS_MASK.a
            end
        )
    end
    return spawnDeckFromInfo(deck_info)
end

-- onLoad, we'll want to make sure all cards in player hands are hidden
-- again properly
function hideCardsInHands()
    for _,player_color in ipairs(Player.getAvailableColors()) do
        local cards = getCardsInHandZone(player_color)
        for _,card in ipairs(cards) do
            card.setHiddenFrom({player_color, "Grey"})
        end
    end
end