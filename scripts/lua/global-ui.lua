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

function playerNameColored(player_color)
    local player_name = player_color
    if getPlayer(player_color, false) ~= nil then
        player_name = getPlayer(player_color).steam_name
        if string.len(player_name) < 2 then
            player_name = player_color
        end
    end

    return string.format(
        '<textcolor color="#%s"><b>%s</b></textcolor>',
        Color[player_color]:toHex(),
        player_name
    )
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
            value="Hello " .. playerNameColored(color) .. ", the game hasn't started yet",
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
            value=playerNameColored(color_turn) .. "'s turn, please wait",
            attributes={
                alignment="UpperRight",
                fontSize=20
            }
        }}
    }
end

function ui_createGameRuleToggle(rule, text, y_offset)

    local game_rules = getCurrentGameRules()

    return {
        tag="Toggle",
        value=text,
        attributes={
            id=rule,
            onValueChanged="ui_onGameRuleToggle",
            isOn=game_rules[rule],
            rectAlignment="UpperRight",
            offsetXY="0 " .. y_offset,
            textColor="#ffffff",
            width="350",
            height="30"
        }
    }
end

function ui_onGameRuleToggle(player, value, rule)
    setGameRule(rule, value)
    ui_LoadUI()
end

function ui_gameRuleDialog()

    local game_rules = getCurrentGameRules()

    local panel = {
        tag="Panel",
        attributes={
            rectAlignment="UpperRight",
            offsetXY="0 -180",
            width="400",
            height="400",
            visibility=table.concat(Player.getAvailableColors(), "|")
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
    local include_rainbow_toggle = ui_createGameRuleToggle(
        "include_rainbow",
        "Include rainbow cards",
        y_offset
    )
    if not game_rules.include_rainbow then
        include_rainbow_toggle.attributes.width = 255
    end
    table.insert(panel.children, include_rainbow_toggle)
    
    if game_rules.include_rainbow then

        y_offset = y_offset - 30
        table.insert(panel.children, ui_createGameRuleToggle(
            "rainbow_wild",
            "Rainbow cards are wild",
            y_offset
        ))

        y_offset = y_offset - 30

        if game_rules.rainbow_wild then
            local sub_toggle = ui_createGameRuleToggle(
                "rainbow_one_per_firework",
                "Maximum one wild card per firework",
                y_offset
            )
            sub_toggle.attributes.width = sub_toggle.attributes.width - 30
            table.insert(panel.children, sub_toggle)
        end

        y_offset = y_offset - 30
        table.insert(panel.children, ui_createGameRuleToggle(
            "rainbow_firework",
            "Create a firework out of rainbow cards",
            y_offset
        ))

        y_offset = y_offset - 30
        table.insert(panel.children, ui_createGameRuleToggle(
            "rainbow_multicolor",
            "Rainbows cards are every color when giving hints",
            y_offset
        ))

        y_offset = y_offset - 30
        table.insert(panel.children, ui_createGameRuleToggle(
            "rainbow_talking",
            "Rainbow is a color (Use rainbow as a hint)",
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

function ui_activeTurnUi(color)
    local panel = {
        tag="Panel",
        attributes={
            rectAlignment="UpperRight",
            visibility=color,
            offsetXY="0 -80",
            width="400",
            height="400"
        },
        children={}
    }

    local message = {
        tag="Text",
        value=playerNameColored(color) .. ", it's your turn.",
        attributes={
            fontSize="20",
            alignment="UpperRight"
        }
    }
    table.insert(panel.children, message)

    local num_hints = #availableHintTokens()
    local txt = "You can play, discard,"
    if num_hints < 1 then
        txt = "You can only play or discard"
    end

    local options = {
        tag="Text",
        value=txt,
        attributes={
            fontSize="20",
            alignment="UpperRight",
            offsetXY="0 -30"
        }
    }

    table.insert(panel.children, options)
    if num_hints > 0 then
        table.insert(panel.children, ui_hintOptions(color))
    end


    return panel
end

function ui_hintOptions(color)

    local talk_to = Temp_State.talking_to or ""

    local panel = {
        tag="Panel",
        attributes={
            rectAlignment="UpperRight",
            visibility=color,
            offsetXY="0 -60",
            width="400",
            height="400"
        },
        children={}--ui_alignmentHelpers()
    }
    local y_offset = 0
    local x_offset = 0

    local toggle_text = {
        tag="Text",
        value="or talk to a player",
        attributes={
            fontSize="20",
            alignment="UpperRight"
        }
    }
    y_offset = y_offset - 30
    table.insert(panel.children, toggle_text)

    local toggle_group = {
        tag="ToggleGroup",
        attributes={
            allowSwitchOff=true
        },
        children={}
    }
    table.insert(panel.children, toggle_group)
    
    local players_by_color = {}
    for _,player_color in ipairs(Player.getAvailableColors()) do
        if player_color ~= color and #getCardsInHandZone(player_color) > 0 then
            table.insert(players_by_color, player_color)
        end
    end

    function getXOffset(num, total)
        local players_left = total - num
        local to_the_right = (3 - (num % 3)) % 3
        if players_left >= to_the_right then
            return 0 - (120 * to_the_right)
        else
            return 0 - (120 * players_left)
        end
    end

    for i,player_color in ipairs(players_by_color) do
        
        local is_on = false
        if talk_to == player_color then
            is_on = true
        end

        local toggle_string = playerNameColored(player_color)

        table.insert(toggle_group.children, {
            tag="Toggle",
            attributes={
                id="talk_to_" .. player_color,
                onValueChanged="ui_onTalkToToggle",
                isOn=is_on,
                rectAlignment="UpperRight",
                offsetXY=getXOffset(i, #players_by_color).." "..y_offset,
                textColor="#ffffff",
                width="120",
                height="30"
            },
            children={{
                tag="Text",
                value=toggle_string
            }}
        })
        if i % 3 == 0 then
            y_offset = y_offset - 30
        end
            
    end

    y_offset = y_offset - 45

    if talk_to ~= "" then
        local game_rules = getCurrentGameRules()
 
        local cards = mapArray(
            getCardsInHandZone(talk_to),
            function(card)
                local info = JSON.decode(card.memo)
                return {
                    number = info.front_number,
                    color_mask = info.front_color_mask
                }
            end
        )

        local has_rainbow = false
        for _,card in pairs(cards) do
            if card.color_mask == COLORS_MASK.a then
                has_rainbow = true
                break
            end
        end

        local hint_color_mask = 0
        if game_rules.rainbow_multicolor then
            hint_color_mask = bitwiseOr(mapArray(cards, pluck("color_mask")))
        else
            hint_color_mask = bitwiseOr(filter(
                mapArray(cards, pluck("color_mask")),
                function(mask)
                    return mask ~= COLORS_MASK.a
                end
            ))
        end

        local button_width = 50
        local button_height = 50
        x_offset = 0
        for c,mask in pairs(COLORS_MASK) do
            if  bit32.band(mask,hint_color_mask) == mask and
                (c ~= "a" or (has_rainbow and game_rules.rainbow_talking))
            then
                table.insert(panel.children, {
                    tag="Panel",
                    attributes={
                        id="talk_to_" .. talk_to .. ":" .. c,
                        onClick="ui_onTalkToPlayer(" .. talk_to .. ")",
                        offsetXY=x_offset .. " " .. y_offset,
                        rectAlignment="UpperRight",
                        width=button_width,
                        height=button_height
                    },
                    children={{
                        tag="Image",
                        attributes={
                            image="swatch_" .. c,
                            preserveAspect=true
                        }
                    }}
                })
                x_offset = x_offset - button_width - 10
            end
        end
        y_offset = y_offset - button_height - 10
        x_offset = 0

        for i = #NUMBERS_REP, 1, -1 do
            num_rep = NUMBERS_REP[i]
            for _,num in
                ipairs(noDuplicatesArray(mapArray(cards, pluck("number"))))
            do
                if num == i then
                    table.insert(panel.children, {
                        tag="Panel",
                        attributes={
                            id="talk_to_" .. talk_to .. ":" .. num_rep,
                            onClick="ui_onTalkToPlayer(" .. talk_to .. ")",
                            offsetXY=x_offset .. " " .. y_offset,
                            rectAlignment="UpperRight",
                            width=button_width,
                            height=button_height
                        },
                        children={{
                            tag="Image",
                            attributes={
                                image="swatch_" .. num_rep,
                                preserveAspect=true
                            }
                        }}
                    })
                    x_offset = x_offset - button_width - 10
                end
            end
        end
    end

    return panel
end

function ui_onTalkToPlayer(player, talking_to, id)
    local talk_char = id:sub(-1)
    Temp_State.talking_to = nil
    local is_number = tonumber(talk_char)

    if is_number ~= nil then
        giveHintNumber(talking_to, is_number)
    else
        giveHintColors(talking_to, COLORS_MASK[talk_char])
    end

    useHintToken()(advanceTurnToken)
end

function ui_onTalkToToggle(player, toggle_is_on, id)
    if toggle_is_on == "False" or not toggle_is_on then
        Temp_State.talking_to = nil
    else 
        -- id = talk_to_<color>
        local color = id:sub(9)
        Temp_State.talking_to = color
    end
    ui_LoadUI()
end

function ui_askAfterRainbowPlayLocation(info)

    local vis = getTurnTokenLocation()
    if vis == "unknown" or vis == "token_mat" then
        vis = table.concat(Player.getAvailableColors(), "|")
    end

    local panel = {
        tag="Panel",
        attributes={
            id="ui_askAfterRainbowPlayLocation",
            visibility=vis,
            rectAlignment="MiddleCenter",
            height=400,
            width=125 * #info.color_masks
        },
        children={}
    }

    local x_offset = 0
    for _,color_mask in ipairs(info.color_masks) do

        table.insert(panel.children, {
            tag="Panel",
            attributes={
                id="select_card_".. color_mask .. ":" .. info.card_num,
                onClick="ui_onSelectCardPlayLocation(" .. info.card_num .. " " .. color_mask .. ")",
                offsetXY=x_offset .. " 0",
                rectAlignment="UpperLeft",
                width=120,
                height=400
            },
            children={{
                tag="Image",
                attributes={
                    image="card_front_" .. info.card_num .. colorCharFromMask(color_mask),
                    preserveAspect=true
                }
            }}
        })
        x_offset = x_offset + 125
    end

    return panel
end

function ui_onSelectCardPlayLocation(player, call_str)

    local tokens = {}
    for token in string.gmatch(call_str, "[^%s]+") do
        table.insert(tokens, token)
    end
    
    local num = tokens[1]
    local color_mask = tokens[2]

    local info = Temp_State.askAfterRainbowPlayLocation
    if info == nil then
        printToAll("Alert: ui_onSelectCardPlayLocation run without Temp_State set")
        return
    end

    info.callback(num, color_mask)
end

function ui_LoadUI()

    if not Temp_State.isLoadedUiAssetBundle then
        Temp_State.isLoadedUiAssetBundle = true
        local assets = {}
        for color,_ in pairs(COLORS_MASK) do
            table.insert(assets, {
                name="swatch_" .. color,
                url=getHanabiSwatchUrl(color)
            })
        end
        for _,num in ipairs(NUMBERS_REP) do
            table.insert(assets, {
                name="swatch_" .. num,
                url=getHanabiSwatchUrl(num)
            })
        end

        for color_char,_ in pairs(COLORS_MASK) do
            for _,num in ipairs(NUMBERS_REP) do
                table.insert(assets, {
                    name="card_front_" .. num .. color_char,
                    url=generated_front_url_char(num, color_char)
                })
            end
        end

        UI.setCustomAssets(assets)
    end

    local globalLoayout = ui_defaults()
    local parent_table = globalLoayout[2].children

    local all_colors = Player.getAvailableColors()
    local turn_token_location = getTurnTokenLocation()

    if turn_token_location == "token_mat" then
        for _,player_color in ipairs(all_colors) do
            table.insert(parent_table, ui_greeting(player_color))
        end

        table.insert(parent_table, ui_gameRuleDialog())
    else
        local wait_colors = {}
        for _,player_color in ipairs(all_colors) do
            if player_color ~= turn_token_location then
                wait_colors = table.insert(wait_colors, player_color)
            end
        end
        wait_colors_str = table.concat(wait_colors, "|")
        table.insert(parent_table, ui_pleaseWait(wait_colors_str, turn_token_location))

        if turn_token_location ~= "unknown" then
            table.insert(parent_table, ui_activeTurnUi(turn_token_location))
        end

    end

    if Temp_State.askAfterRainbowPlayLocation ~= nil then
        table.insert(
            parent_table,
            ui_askAfterRainbowPlayLocation(
                Temp_State.askAfterRainbowPlayLocation
            )
        )
    end

    UI.setXmlTable(globalLoayout)

end

function getHanabiSwatchUrl(name)
    name = "" .. name
    return ASSET_URL .. "back_" .. name .. "_" .. ASSET_VERSION .. ".png"
end