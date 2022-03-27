function tableSize(table)
    local count = 0
    for _,_ in pairs(table) do
        count = count + 1
    end
    return count
end

function concatTables(first, second)
    for _,entry in ipairs(second) do
        table.insert(first, entry)
    end
    return first
end

function map(table, fn)
    local t = {}
    for k,v in pairs(table) do
        t[k] = fn(v)
    end
    return t
end

function filter(table, pred)
    local t = {}
    for k,v in pairs(table) do
        if pred(v) then
            t[k] = v
        end
    end
    return t
end

function bitwiseOr(ints)
    local res = 0
    for _,a in pairs(ints) do
        res = bit32.bor(res, a)
    end
    return res
end

function bitwiseAnd(ints)
    local res = nil
    for i,a in pairs(ints) do
        if i == 1 then
            res = a
        else
            res = bit32.band(res, a)
        end
        res = bit32.bor(res, a)
    end
    return res
end

function pluck(key)
    return function(table)
        return table[key]
    end
end

function noDuplicatesArray(array)
    local hash = {}
    local res = {}
    for _,v in ipairs(array) do
        if not hash[v] then
            table.insert(res, v)
            hash[v] = true
        end
    end
    return res
end