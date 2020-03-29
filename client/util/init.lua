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

return ülp