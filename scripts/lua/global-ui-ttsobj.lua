
function ui_scoreUI()
end

function ui_cardUI(card, hidden_from)
    -- front_number
    -- front_color_mask
    -- back_number
    -- back_color_mask
    local info = JSON.decode(card.memo)
    local card_num = tonumber(info.back_number)
    local card_color_mask = tonumber(info.back_color_mask)
    local images = {}

    local visibility = table.concat(
        filterArray(Player.getAvailableColors(), function(c)
            return c ~= hidden_from
        end),
        "|"
    )

    if card_num ~= 0 then
        table.insert(images, {
            tag="Image",
            attributes={
                image="icon_" ..  card_num,
                rectAlignment="MiddleRight",
                preserveAspect=true,
                visibility=visibility
            }
        })
    end

    if card_color_mask ~= 0 then
        table.insert(images, {
            tag="Image",
            attributes={
                image="icon_" ..  colorCharFromMask(card_color_mask),
                rectAlignment="MiddleLeft",
                preserveAspect=true,
                visibility=visibility
            }
        })
    end

    return {{
        tag="Defaults",
        children={{
            tag="Text",
            attributes={
                color="#ffffff",
                fontSize="20",
                outline="#000000"
            }
        }}
    }, {
        tag="Panel",
        attributes={
            height="80",
            width="180",
            position="0 -210 0"
        },
        children=images
    }}
end