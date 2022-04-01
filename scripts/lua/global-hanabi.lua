---------------------------------------------------------------------
---------------- [[ Global Hanabi Script ]] -------------------------
---------------------------------------------------------------------

-- Pictures are stored/hosted by this project's github repo
-- They can be uploaded to steam cloud eventually (Though both are
-- stable/fast hosts).
ASSET_URL = "https://raw.githubusercontent.com/Trequetrum/tts-hanabi/main/assets/"
ASSET_VERSION = "v3"
ASSET_GENED_URL = ASSET_URL .. "generated/"
ASSET_BACK_BLANK_URL = ASSET_URL .. "back_blank_" .. ASSET_VERSION .. ".png"

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
Temp_State={
    active_cards={}
}


function colorCharFromMask(color_mask)
    for char, mask in pairs(COLORS_MASK) do
        if mask == color_mask then return char end
    end
    return 'a'
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
        tts_object.setHiddenFrom({tts_zone.getValue(), "Grey"})
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
            continueIf(function(card)
                return Temp_State.active_cards[card.getGUID()] ~= true
            end),
            waitUntilResting,
            continueIf(isObjectInZone(tts_zone)),
            tapFunction(function(card)
                Temp_State.active_cards[card.getGUID()] = true
            end),
            tapFunction(function(card) card.setHiddenFrom({}) end),
            flipFaceUp,
            tapCallback(waitFrames(60)),
            smoothRelativeMove({0, 10, 0}),
            function(card)
                if tts_zone.guid == discardzone_guid then
                    recoverHintToken()()
                    return discardCard(card)
                elseif tts_zone.guid == playzone_guid then
                    return playCard(card)
                end
            end,
            tapFunction(function(card)
                Temp_State.active_cards[card.getGUID()] = false
            end),
            tapFunction(advanceTurnToken)
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
                                tapCallback(waitFrames(200)),
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
        tts_object.setHiddenFrom(table.insert(Player.getAvailableColors(), "Grey"))
    end
end

--[[ The onLoad event is called after the game save finishes loading. --]]
function onLoad()
    log("Hello World!")
    ui_LoadUI()
    hideCardsInHands()
end

--[[ The onUpdate event is called once per frame. --]]
function onUpdate()
    --[[ print('onUpdate loop!') --]]
end