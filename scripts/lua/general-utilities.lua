

function concatTables(first, second)
    for _,entry in ipairs(second) do
        table.insert(first, entry)
    end
    return first
end