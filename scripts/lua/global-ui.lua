

function ui_defaults()
    return {{
        tag="Defaults",
        children={{
            tag="Text",
            attributes={
                color="#ffffff",
                fontSize="16"
            }
        }}
    },{
        tag="Panel",
        attributes={
            id="parent_panel",
            height="95%",
            width="95%"
        },
        children={}
    }}
end

function ui_alignmentHelpers()
    return {{
        tag="Text",
        value="↖",
        attributes={
            alignment="UpperLeft"
        }
    },{
        tag="Text",
        value="↗︎︎",
        attributes={
            alignment="UpperRight"
        }
    },{
        tag="Text",
        value="X",
        attributes={
            alignment="MiddleCenter"
        }
    },{
        tag="Text",
        value="↙",
        attributes={
            alignment="LowerLeft"
        }
    },{
        tag="Text",
        value="↘︎︎",
        attributes={
            alignment="LowerRight"
        }
    }}
end

function ui_greeting(color)
    return {
        tag="Panel",
        attributes={
            id=color .. "_greeting_UI",
            visibility=color,
            rectAlignment="UpperRight",
            offsetXY="0 -80",
            height="100",
            width="400"
        },
        children={{
            tag="Text",
            value="Hello <b>" .. color .. "</b>, the game hasn't started yet",
            attributes={
                alignment="UpperRight",
            }
        },{
            tag="Text",
            value="Check the 'Rules' notebook for more information",
            attributes={
                alignment="UpperRight",
                offsetXY="0 -25"
            }
        }}
    }
end

function ui_pleaseWait(colors_string, color_turn)
    return {
        tag="Panel",
        attributes={
            id=colors_string .. "_UI",
            visibility=colors_string,
            rectAlignment="UpperRight",
            offsetXY="0 -80",
            height="100",
            width="400"
        },
        children={{
            tag="Text",
            value=color_turn .. "'s turn, please wait",
            attributes={
                alignment="UpperRight",
            }
        }}
    }
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

function createGameRuleToggle(rule, text, y_offset)

    local game_rules = getCurrentGameRules()

    return {
        tag="Toggle",
        value=text,
        attributes={
            id=rule,
            onValueChanged="onGameRuleToggle",
            isOn=game_rules[rule],
            rectAlignment="UpperRight",
            offsetXY="0 " .. y_offset,
            textColor="#ffffff",
            width="350",
            height="30"
        }
    }
end

function onGameRuleToggle(player, value, rule)
    setGameRule(rule, value)
    ui_LoadUI()
end

function gameRuleDialog()

    local game_rules = getCurrentGameRules()

    local panel = {
        tag="Panel",
        attributes={
            rectAlignment="UpperRight",
            offsetXY="0 -180",
            width="400",
            height="400"
        },
        children={}
    }

    local y_offset = 0
    table.insert(panel.children, {
        tag="Text",
        value="<i>Dealer becomes first player</i>",
        attributes={
            alignment="UpperRight",
            offsetXY="0 " .. y_offset
        }
    })

    y_offset = y_offset - 30
    local include_rainbow_toggle = createGameRuleToggle(
        "include_rainbow",
        "Include rainbow cards?",
        y_offset
    )
    if not game_rules.include_rainbow then
        include_rainbow_toggle.attributes.width = 255
    end
    table.insert(panel.children, include_rainbow_toggle)
    
    if game_rules.include_rainbow then

        y_offset = y_offset - 30
        table.insert(panel.children, createGameRuleToggle(
            "rainbow_wild",
            "Rainbow cards are wild?",
            y_offset
        ))

        y_offset = y_offset - 30

        if game_rules.rainbow_wild then
            local sub_toggle = createGameRuleToggle(
                "rainbow_one_per_firework",
                "Maximum one wild card per firework?",
                y_offset
            )
            sub_toggle.attributes.width = sub_toggle.attributes.width - 30
            table.insert(panel.children, sub_toggle)
        end

        y_offset = y_offset - 30
        table.insert(panel.children, createGameRuleToggle(
            "rainbow_firework",
            "Create a firework out of rainbow cards?",
            y_offset
        ))

        y_offset = y_offset - 30
        table.insert(panel.children, createGameRuleToggle(
            "rainbow_multicolor",
            "Rainbows cards are every color when giving hints?",
            y_offset
        ))

        y_offset = y_offset - 30
        table.insert(panel.children, createGameRuleToggle(
            "rainbow_talking",
            "Rainbow is a color (Use rainbow as a hint)?",
            y_offset
        ))

    end

    y_offset = y_offset - 30
    local button_width = 255
    if game_rules.include_rainbow then
        button_width = 350
    end
    local deal_button = {
        tag="Button",
        value="Deal and begin a game of Hanabi :)",
        attributes={
            id="ruleSet1",
            onClick="startGame",
            offsetXY="0 " .. y_offset,
            rectAlignment="UpperRight",
            width=button_width,
            height="30"
        }
    }

    table.insert(panel.children, deal_button)

    return panel
end

function ui_hintOptions(color)

    local talk_to = Temp_State.talking_to or ""

    local panel = {
        tag="Panel",
        attributes={
            rectAlignment="UpperRight",
            visibility=color,
            offsetXY="0 -80",
            width="400",
            height="400"
        },
        children=ui_alignmentHelpers()
    }

    local toggle_group = {
        tag="ToggleGroup",
        attributes={
            allowSwitchOff=true
        },
        children={}
    }

    table.insert(panel.children, toggle_group)

    local y_offset = 0
    for _,player_color in ipairs(Player.getAvailableColors()) do
        if player_color ~= color and #getCardsInHandZone(player_color) > 0 then
            local is_on = false
            if talk_to == player_color then
                is_on = true
            end

            table.insert(toggle_group.children, {
                tag="Toggle",
                value="Talk to the " .. player_color .. " player",
                attributes={
                    id="talk_to_" .. player_color,
                    onValueChanged="onTalkToToggle",
                    isOn=is_on,
                    rectAlignment="UpperRight",
                    offsetXY="0 " .. y_offset,
                    textColor="#ffffff",
                    width="200",
                    height="30"
                }
            })
            y_offset = y_offset - 30
        end
    end

    if talk_to ~= "" then
        local cards = getCardsInHandZone(talk_to)
        for _,mask in pairs(COLORS_MASK) do
            for _,card in pairs(cards) do
                local color_mask = JSON.decode(card.memo).front_color_mask
                if color_mask == mask then
                    
                end
            end
        end
    end

    return panel
    
--     <ToggleGroup>
--     <VerticalLayout>
--         <Toggle>Toggle A</Toggle>
--         <Toggle>Toggle B</Toggle>
--         <Toggle>Toggle C</Toggle>
--     </VerticalLayout>
-- </ToggleGroup>

end

function onTalkToToggle(player, toggle_is_on, id)
    if toggle_is_on == "False" or not toggle_is_on then
        Temp_State.talking_to = nil
    else 
        -- id = talk_to_<color>
        local color = id:sub(9)
        Temp_State.talking_to = color
    end
    ui_LoadUI()
end

function positionHoveringBounds(position, bounds)
    return (
        position.x < bounds.center.x + (bounds.size.x / 2) and
        position.x > bounds.center.x - (bounds.size.x / 2) and
        position.z < bounds.center.z + (bounds.size.z / 2) and
        position.z > bounds.center.z - (bounds.size.z / 2)
    )
end

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

function ui_LoadUI()

    local globalLoayout = ui_defaults()
    local parent_table = globalLoayout[2].children

    local all_colors = Player.getAvailableColors()
    local turn_token_location = getTurnTokenLocation()

    if turn_token_location == "token_mat" then
        for _,player_color in ipairs(all_colors) do
            table.insert(parent_table, ui_greeting(player_color))
        end

        table.insert(parent_table, gameRuleDialog())
    else
        local wait_colors = ""
        for _,player_color in ipairs(all_colors) do
            if player_color ~= turn_token_location then
                wait_colors = wait_colors .. player_color .. "|"
            end
        end
        wait_colors = wait_colors:sub(1, -2)
        table.insert(parent_table, ui_pleaseWait(wait_colors, turn_token_location))

        if turn_token_location ~= "unknown" then
            table.insert(parent_table, ui_hintOptions(turn_token_location))
        end

    end

    UI.setXmlTable(globalLoayout)

    -- local oby = getAllTokenMatObjects()
    -- for _,ob in ipairs(oby) do
    --     log(ob.getName() .. " : " .. logString(ob.getPosition()))
    -- end

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

    printToAll("ALERT! Cannot find " .. name)

    return nil
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

function getDeck()
    if  Temp_State.deck ~= nil and 
        not Temp_State.deck.isDestroyed()
    then
        return Temp_State.deck
    end

    function getDeckInList(list)
        for _,thingy in ipairs(list) do
            if thingy.getQuantity() > 0 then
                local cards = thingy.getObjects()
                for _,card in ipairs(cards) do
                    if isHanabiCard(card) then
                        Temp_State.deck = thingy
                        return thingy
                    end
                end
            end
        end
        return nil
    end

    local deck = getDeckInList(getAllTokenMatObjects())
    if deck ~= nil then
        Temp_State.deck = deck
        return deck 
    end

    deck = getDeckInList(getObjects())
    Temp_State.deck = deck
    return deck

end

function startGame(player)

    -- log(Player.getAvailableColors())
    -- smoothMove({0,4,20})(getTurnToken())()

    deal()
    moveTurnTokenTo(player.color)

end

function moveTurnTokenTo(color)
    local pos = getHandZone(color).getPosition()
    pos.y = 4
    local token = getObjectByName("turn_token")
    smoothMove(pos)(token)()
end

function getPlayer(color)
    for _, player in ipairs(Player.getPlayers()) do
        if player.color == color then
            return player
        end
    end
end

function getHandZone(color)
    for _,oby in ipairs(Hands.getHands()) do
        if oby.getValue() == color then
            return oby
        end
    end
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

function deal()
    local deck = getDeck()
    if deck == nil then
        broadcastToAll("No Hanabi Deck Discovered. Aborting")
        return
    end

    local players = Player.getPlayers()
    local dealAmount = nil

    if #players > 3 then
        dealAmount = 4
    else
        dealAmount = 5
    end

    for _, player in ipairs(players) do
        if #player.getHandObjects() == 0 then
            deck.deal(dealAmount, player.color)
        end
    end

    --[[
    This is just for testing purposes. Deal some cards to another
    player. I've picked red.
    ]]
    if #players == 1 then
        if numCardsInHandZone("Red") == 0 then
            deck.deal(5, "Red")
        end
    end
end