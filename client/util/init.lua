local ülp = {}

function ülp.hexDump(str)
    local parts = {}
    for i = 1, str:len() do
        parts[i] = string.format("%02X", str:byte(i))
    end
    return table.concat(parts, " ")
end

function ülp.pointInRect(x, y, rx, ry, rw, rh)
    return x > rx and x < rx + rw and y > ry and y < ry + rh
end

function ülp.trim(str)
    return str:match("^%s*(.-)%s*$")
end

function ülp.clamp(v, lo, hi)
    return math.min(math.max(v, lo or 0), hi or 1)
end

function ülp.findKey(tbl, val)
    for k, v in pairs(tbl) do
        if val == v then
            return k
        end
    end
    return nil
end

function ülp.call(func, ...)
    if func then
        func(...)
    end
end

function ülp.nop()
    -- pass
end

function ülp.loveDoFile(path)
    local chunk, err = love.filesystem.load(path)
    if chunk then
        return chunk()
    else
        error(err)
    end
end

function ülp.autoFullscreen()
    local supported = love.window.getFullscreenModes()
    table.sort(supported, function(a, b) return a.width*a.height < b.width*b.height end)

    local filtered = {}
    local scrWidth, scrHeight = love.window.getDesktopDimensions()
    for _, mode in ipairs(supported) do
        if mode.width*scrHeight == scrWidth*mode.height then
            table.insert(filtered, mode)
        end
    end
    supported = filtered

    local max = supported[#supported]
    local flags = {fullscreen = true}
    if not love.window.setMode(max.width, max.height, flags) then
        error(string.format("Resolution %dx%d could not be set successfully.", max.width, max.height))
    end
    if love.resize then love.resize(max.width, max.height) end
end

function ülp.fallback(tbl, fallback)
    local meta = getmetatable(tbl) or {}
    meta.__index = fallback
    return setmetatable(tbl, meta)
end

local enumMt = {
    __index = function(tbl, key)
        error(("'%s' is not a value of the enum!"):format(key), 2)
    end,
    __newindex = function(tbl, key)
        error("Enums are not writable", 2)
    end,
}

function ülp.enum(values, numberValues)
    local obj = setmetatable({}, enumMt)
    local numberCounter = 1
    for k, v in pairs(values) do
        local kType = type(k)
        if kType == "string" then
            rawset(obj, k, v)
        elseif kType == "number" then
            rawset(obj, v, v)
            if numberValues then
                rawset(obj, v, numberCounter)
                numberCounter = numberCounter + 1
            end
        else
            error(("Invalid key type for enum '%s'"):format(kType), 2)
        end
    end
    return obj
end

-- rrggbb, #rrggbb, rrggbbaa or #rrggbbaa
function ülp.parseHexColor(str)
    local len = str:len()
    assert(len >= 6 and len <= 9)
    local i = str:sub(1, 1) == "#" and 2 or 1
    local a = 1.0
    if len >= 8 then
        a = tonumber(str:sub(i + 7, i + 8), 16) / 255.0
    end
    return {
        tonumber(str:sub(i + 1, i + 2), 16) / 255.0,
        tonumber(str:sub(i + 3, i + 4), 16) / 255.0,
        tonumber(str:sub(i + 5, i + 6), 16) / 255.0,
        a
    }
end

function ülp.shuffle(list)
    for i = 1, #list - 1 do
        local j = love.math.random(i, #list)
        list[i], list[j] = list[j], list[i]
    end
end

function ülp.range(start, stop, step)
    step = step or 1
    local list = {}
    for i = start, stop, step do
        table.insert(list, i)
    end
    return list
end

function ülp.findItemByKey(list, key, value)
    for _, item in ipairs(list) do
        if item[key] == value then
            return item, i
        end
    end
    return nil, nil
end

function ülp.reduce(list, func)
    local acc
    for k, v in ipairs(list) do
        if k == 1 then
            acc = v
        else
            acc = func(acc, v)
        end
    end
    return acc
end

function ülp.sum(list)
    return ülp.reduce(list, function(a, b) return a + b end)
end

function ülp.filter(list, func)
    local ret = {}
    for _, v in ipairs(list) do
        if func(v) then
            table.insert(ret, v)
        end
    end
    return ret
end

function ülp.count(list, func)
    local n = 0
    for _, v in ipairs(list) do
        if func(v) then
            n = n + 1
        end
    end
    return n
end

function ülp.find(list, func)
    for i, v in ipairs(list) do
        if func(v) then
            return v
        end
    end
    return nil
end

local constMt = {
    __index = function(tbl, key)
        assert(tbl.data)
        local mt = getmetatable(tbl)
        if tbl.data[key] ~= nil then
            return tbl.data[key]
        elseif mt[key] ~= nil then
            return mt[key]
        else
            error("Unknown key in const table: " .. tostring(key))
        end
    end,
    __newindex = function(tbl, key)
        error("Table is read only")
    end,
    getName = function(tbl, value)
        return ülp.findKey(tbl.data, value)
    end,
}

function ülp.constTable(tbl)
    return setmetatable({data = tbl}, constMt)
end

return ülp