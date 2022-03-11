---------------------------------------------------------------------
---------------- [[ Global Hanabi Script ]] -------------------------
---------------------------------------------------------------------


-- Pictures are stored/hosted by this project's github repo
-- They can be uploaded to steam cloud eventually (Though both are
-- stable/fast hosts).
asset_url = "https://raw.githubusercontent.com/Trequetrum/tts-hanabi/main/assets/"
asset_gened_url = asset_url .. "generated/"
asset_back_blank_url = asset_url .. "back_blank.png"

-- Filenames describe cards and have a canonical order for colors as
-- listed here
color_order = {'b', 'g', 'r', 'w', 'y'}

-- Bit mask for the card colors. Used to describe the 'notes' on the
-- back of a card. While players can infer that anything more than one
-- color is a rainbow, 'all five colors' is semantically equivalent to 
-- rainbow (I'm not sure yet if that complicates the implementation of
-- the basic rule-set, but I don't think it will as the masks can be
-- treated as values to check equality directly).
-- Use `band` to mask and `bor` to combine.
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
colors_mask = {
    ['a'] = tonumber('11111', 2),
    ['b'] = tonumber('1', 2),
    ['g'] = tonumber('10', 2),
    ['r'] = tonumber('100', 2),
    ['w'] = tonumber('1000', 2),
    ['y'] = tonumber('10000', 2)
}

-- Hard-coding how each number is represented as a string on their 
-- respective filenames.
numbers = {'1','2','3','4','5'}

-- Hard-coding how many cards of each number exist for a color.
-- Used when generating the hanabi deck
color_layout = {
    default=2,
    ['1']=3,
    ['5']=1
}

-- Get the url for a corresponding number and color_mask. When loaded,
-- this shows automated player 'notes' on the back of their cards
function generated_back_url(num, color_mask)
    if num == 0 and color_mask == 0 then
        return asset_url .. "back_blank.png"
    end

    local colors_str = ""
    local num_str = ""

    for _, color in ipairs(color_order) do
        if band(colors_mask[color], color_mask) == colors_mask[color] then
            colors_str = colors_str .. 'color'
        end
    end
    if numbers[num] ~= nil then
        num_str = num_str .. numbers[num]
    end

    return asset_gened_url .. "back_" .. num_str .. colors_str .. "png"
end

-- This recursively spawns each new card as a continuation of 
-- spawning the previous card. TTS gets weird when a user's machine
-- can't spawn everything in the same frame, meaning that if we spawn
-- too much at once, players will be out of sync with each other.
--
-- What's too many? That depends (apparently) on a whole host of 
-- factors. So to avoid the problem, we spawn one thing at a time.
-- 
-- It gets worse though, we need to spawn cards far enough apart that
-- TTS won't auto-group them for us since auto-group is unreliable too
-- (go figure). 
--
-- Also, `reload` on cards with new front and back takes time but 
-- unlike `spawnObject,` there's no callback for when that completes. 
-- Since the cards onLoad function will only be called once it's 
-- loaded, we just check every frame (The "for now" solution).
function generateDeck_rec(card_info, index, max, accumulated, callback)
    if index > max then

        local grouped = group(accumulated)
        if callback ~= nil and grouped[1] ~= nil then
            callback(grouped[1])
        end
            
    else 

        spawnCard(
            card_info[index].front_url,
            card_info[index].back_url,
            card_info[index].state,
            {
                ((((index - 1) * 2) % 30) - 25), 
                0, 
                15 - (math.floor(index/15) * 5)
            },
            function(new_card)

                table.insert(accumulated, new_card)
                
                generateDeck_rec(
                    card_info, 
                    index + 1, 
                    max, 
                    accumulated, 
                    callback
                )

            end
        )

    end
end


-- API warpper for generateDeck_rec
function generateDeckFromInfo(info, callback)
    local max = #info
    generateDeck_rec(info, 1, max, {}, callback)
end

-- Wrapper around spawnObject that sets the custom images and state
-- for a card. State is not longer in a card's lua, but can be found
-- JSON encoded on its `.memo` attribute. 
function spawnCard(front_url, back_url, state, pos, callback)
    spawnObject({
        type = "CardCustom",
        position = pos,
        callback_function = function(custom_card)
            custom_card.setCustomObject({
                face = front_url,
                back = back_url
            })
            
            local new_card = custom_card.reload()
            new_card.memo = JSON.encode(state)
            --Wait.frames(function() 
                callback(new_card) 
            --end, 1)
            
        end
    })
end

-- Return a table of starting card URLs and states
function generateDeckInfo()

    local deck_info = {}

    for _, num in ipairs(numbers) do
        local layout_num = color_layout.default
        if color_layout[num] ~= nil then
            layout_num = color_layout[num]
        end
        for i = 1, layout_num do
            for color, mask in pairs(colors_mask) do
                table.insert(deck_info, {
                    front_url = asset_url .. color .. num .. ".png",
                    back_url = generated_back_url(0,0),
                    state = {
                        font_number = num,
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

--[[ The onLoad event is called after the game save finishes loading. --]]
function onLoad()
    log("Hello World!")

    generateDeckFromInfo(generateDeckInfo())
end

--[[ The onUpdate event is called once per frame. --]]
function onUpdate()
    --[[ print('onUpdate loop!') --]]
end