local scenes = require("scenes")
local net = require("net")

local scene = {}

function scene.enter()
end

function scene.tick()
    local event = net.update()
    if event then
        if event.type == net.events.connected then
            -- we should already be connected, ignore
        elseif event.type == net.events.lobbyJoined then
            print("Joined lobby:", event.data.lobbyId, event.data.playerId)
            scenes.enter(scenes.lobby, event.data)
        else
            error("Unexpected event: " .. net.events:getName(event.type))
        end
    end
end

function scene.draw()
    local winW, winH = love.graphics.getDimensions()
    lg.printf("Connecting to lobby..", 0, winH/2, winW, "center")
end

return scene