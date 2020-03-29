local ülp = {}

function ülp.hexDump(str)
    local parts = {}
    for i = 1, str:len() do
        parts[i] = string.format("%02X", str:byte(i))
    end
    return table.concat(parts, " ")
end

return ülp