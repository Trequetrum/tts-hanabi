---------------------------------------------------------------------
---------------- [[ Global Hanabi Script ]] -------------------------
---------------------------------------------------------------------

-- Pictures are stored/hosted by this project's github repo
-- They can be uploaded to steam cloud eventually (Though both are
-- stable/fast hosts).
ASSET_URL = "https://raw.githubusercontent.com/Trequetrum/tts-hanabi/main/assets/"
ASSET_GENED_URL = ASSET_URL .. "generated/"
ASSET_BACK_BLANK_URL = ASSET_URL .. "back_blank.png"

-- Filenames describe cards and have a canonical order for colors as
-- listed here
COLOR_ORDER = {'b', 'g', 'r', 'w', 'y'}

-- Bit mask for the card colors. Used to describe the 'notes' on the
-- back of a card. While players can infer that anything more than one
-- color is a rainbow, 'all five colors' is semantically equivalent to 
-- rainbow (I'm not sure yet if that complicates the implementation of
-- the basic rule-set, but I don't think it will as the masks can be
-- compared directly)
--
-- The keys in this table hard-code how each color is represented as a
-- string on their respective filenames
--
-- a: all/rainbow
-- b: blue
-- g: green
-- r: red
-- w: white
-- y: yellow
COLORS_MASK = {
    a = tonumber('11111', 2), -- 31
    b = tonumber('1', 2), -- 1
    g = tonumber('10', 2), -- 2
    r = tonumber('100', 2), -- 4
    w = tonumber('1000', 2), -- 8
    y = tonumber('10000', 2) -- 16
}

-- Hard-coding how each number is represented as a string on their 
-- respective filenames.
NUMBERS_REP = {'1','2','3','4','5'}

-- Hard-coding how many cards of each number exist for a color.
-- Used when generating the hanabi deck
COLOR_LAYOUT = {
    default=2,
    [1]=3,
    [5]=1
}

LAYOUT_CARD_WIDTH = 2.2
LAYOUT_CARD_HEIGHT = 3.5

-- Store info that is fine to get lost when the game is reset. Mostly
-- used as a cashe of commonly searched for items (like the hanabi 
-- deck). Basically name-spaces global state.
Temp_State={}

-- Get the url for a corresponding number and color_mask. When loaded,
-- this shows automated player 'notes' on the back of their cards
function generated_back_url(num, color_mask)
    if num == 0 and color_mask == 0 then
        return ASSET_URL .. "back_blank.png"
    end

    local colors_str = ""
    local num_str = ""

    for _, color in ipairs(COLOR_ORDER) do
        if bit32.band(COLORS_MASK[color], color_mask) == COLORS_MASK[color] then
            colors_str = colors_str .. 'color'
        end
    end
    if NUMBERS_REP[num] ~= nil then
        num_str = num_str .. NUMBERS_REP[num]
    end

    return ASSET_GENED_URL .. "back_" .. num_str .. colors_str .. ".png"
end

function getHanabiSwatchUrl(name)
    name = "" .. name
    return ASSET_URL .. "back_" .. name .. ".png"
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
                    front_url = ASSET_URL .. color .. num .. ".png",
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

-- Create the full standard deck
function generateStandardDeck()
    spawnDeckFromInfo(generateDeckInfo())()
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

function layoutZByColor(color_mask)
    local top_row_z = LAYOUT_CARD_HEIGHT * 2.5
    local color_index = colorMaskToIndex(color_mask)
    return top_row_z - (LAYOUT_CARD_HEIGHT * color_index)
end

function sameCardFrontInfo(left, right)
    if left == nil then return false end
    if right == nil then return false end

    if  left.front_number == right.front_number and
        left.front_color_mask == right.front_color_mask then
        return true
    end

    return false
end

function getFrontFromInfo(info)
    return info.front_number, info.front_color_mask
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


function discardCard(card)

    local card_info = JSON.decode(card.memo)
    local card_num = card_info.front_number
    local card_color_mask = card_info.front_color_mask

    local move_coords = {
        x=-5,
        y=3,
        z=layoutZByColor(card_color_mask)
    }

    for each_num, _ in ipairs(NUMBERS_REP) do

        local layout_num = COLOR_LAYOUT.default
        if COLOR_LAYOUT[each_num] ~= nil then
            layout_num = COLOR_LAYOUT[each_num]
        end

        if each_num > card_num then
            move_coords.x = move_coords.x - (LAYOUT_CARD_WIDTH * layout_num)
        end
        
    end

    while cardPlaced(
        move_coords.x,
        move_coords.z,
        card_info.front_number, 
        card_info.front_color_mask
    ) do
        move_coords.x = move_coords.x - LAYOUT_CARD_WIDTH
    end

    return kleisliPipeOn(card, {
        smoothMove(move_coords),
        function(card)
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
        end,
        waitUntilResting,
        flipFaceUp
    })
end

function launchRocket()
    return function(callback)

        local rockets = {"3e2281", "37cf9b", "d69263"}

        for _,rocket_guid in ipairs(rockets) do
            local rocket = getObjectFromGUID(rocket_guid)
            if rocket ~= nil and rocket.resting then
                kleisliPipeOn(rocket, {
                    smoothMove({0,4,0}),
                    smoothMove({0,40,0}),
                    tapFunction(destroyObject),
                    mapLiftCallback(function() return 1 end)
                })(callback)
                return
            end
        end

        liftValuesToCallback(0)(callback)

    end
end

function playCard(card)
    local info = JSON.decode(card.memo)
    local num = info.front_number
    local color_mask = info.front_color_mask

    local move_coords = {x=0,y=3,z=0}

    move_coords.z = layoutZByColor(color_mask)
    move_coords.x = 5.6 + (num - 1) * LAYOUT_CARD_WIDTH

    return kleisliPipeOn(card, {
        smoothMove(move_coords),
        function(card)
            if  cardPlaced(move_coords.x,move_coords.z) or
                ( num ~= 1 and 
                not cardPlaced(
                    move_coords.x - LAYOUT_CARD_WIDTH,
                    move_coords.z
                ))
            then
                return seriesCallback({
                    discardCard(card),
                    launchRocket()
                })
            end
            return kleisliPipeOn(card, {
                waitUntilResting,
                flipFaceUp
            })
        end
    })
end

function getCurrentScore()

    local score = 0

    for _,color_mask in pairs(COLORS_MASK) do

        local check_z = layoutZByColor(color_mask)

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

function isObjectInZone(tts_zone)
    return function(tts_object)
        for _,check in pairs(tts_zone.getObjects()) do
            if check.getGUID() == tts_object.getGUID() then
                return true
            end
        end
        return false
    end
end

function onObjectEnterZone(tts_zone, tts_object)
    local playzone_guid = "4739d6"
    local discardzone_guid = "438d80"
    local snap_playzone_guid = "df2727"
    local snap_discardzone_guid = "394402"

    -- Hanabi cards that enter a player's hand are revealed to all
    -- other players
    if tts_zone.type == "Hand" and isHanabiCard(tts_object) then
        tts_object.setHiddenFrom({tts_zone.getValue()})
        flipFaceUp(tts_object)()
    end

    -- If the turn token enters a players hand zone, reload the UI
    -- so it updates for that player
    if tts_zone.type == "Scripting" and tts_object.getName() == "turn_token" then
        local location = getTurnTokenLocation()
        if location ~= "unknown" then
            if location ~= "token_mat" then
                broadcastToAll("Starting " .. location .. "'s turn")
            end
            ui_LoadUI()
        end
    end

    -- Hanabi cards that are layed on the table once played or 
    -- discarded are revealed to all players
    if  (tts_zone.guid == snap_discardzone_guid or
        tts_zone.guid == snap_playzone_guid) and
        isHanabiCard(tts_object)
    then
        tts_object.setHiddenFrom({})
    end

    if  tts_zone.guid == discardzone_guid or
        tts_zone.guid == playzone_guid
    then
        kleisliPipeOn(tts_object, {
            continueIf(isHanabiCard),
            waitUntilResting,
            continueIf(isObjectInZone(tts_zone)),
            smoothRelativeMove({0, 10, 0}),
            function(card)
                if tts_zone.guid == discardzone_guid then
                    return discardCard(card)
                elseif tts_zone.guid == playzone_guid then
                    return playCard(card)
                end
            end
        })()

        kleisliPipeOn(tts_object, {
            continueIf(function(oby) return oby.getQuantity() > 0 end),
            waitUntilResting,
            continueIf(isObjectInZone(tts_zone)),
            function(deck)
                local sequence = {}

                for _,maybe_card in pairs(deck.getObjects()) do
                    if isHanabiCard(maybe_card) then
                        table.insert(
                            sequence, 
                            kleisliPipeOn(deck, {
                                -- This is a short leak, I don't expect this code
                                -- to run very often or for very long, so who cares?
                                continueIf(isObjectInZone(tts_zone)),
                                spawnFromContainer(maybe_card.guid),
                                tapCallback(waitFrames(20)),
                            })
                        )
                    end
                end

                return seriesCallback(sequence)
            end
        })()

    end

end

function onObjectSpawn(tts_object)
    if isHanabiCard(tts_object) then
        tts_object.setHiddenFrom(Player.getAvailableColors())
    end
end

--[[ The onLoad event is called after the game save finishes loading. --]]
function onLoad()
    log("Hello World!")
    ui_LoadUI()

    -- generateStandardDeck()
    -- discardDeck()

    -- seriesCallback({
    --     launchRocket(),
    --     launchRocket(),
    --     launchRocket(),
    --     launchRocket()
    -- })()

end

--[[ The onUpdate event is called once per frame. --]]
function onUpdate()
    --[[ print('onUpdate loop!') --]]
end