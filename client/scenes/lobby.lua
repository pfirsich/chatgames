local scenes = require("scenes")
local net = require("net")
local fonts = require("fonts")
local gui = require("gui")

local scene = {}

local copyIdButton = gui.Button("Copy Lobby Name", gui.Button.defaultWidth, 30)
local ui = {
    copyIdButton,
}

function scene.enter(lobbyJoinedData)
end

function scene.keypressed(key)
    local ctrl = lk.isDown("lctrl") or lk.isDown("rctrl")
    if ctrl and key == "c" then
        love.system.setClipboardText(net.lobbyId)
    end
end

function scene.tick()
    local event = net.update()
    while event do
        if event.type == net.events.lobbyUpdate then
            print("Lobby updated:", finspect(event.data))
        elseif event.type == net.events.message then
            print("Message:", event.data.playerId, event.data.message)
        end
        event = net.update()
    end

    local winW, winH = love.graphics.getDimensions()
    copyIdButton.x = winW/2 - copyIdButton.w/2
    copyIdButton.y = math.floor(fonts.big:getHeight() * 1.5)
    gui.update(ui)

    if copyIdButton.triggered then
        love.system.setClipboardText(net.lobbyId)
    end
end

function scene.draw()
    local winW, winH = love.graphics.getDimensions()

    lg.setFont(fonts.big)
    local title = "Lobby: " .. net.lobbyId
    lg.printf(title, 0, 5, winW, "center")

    local font = fonts.medium
    local fontH = font:getHeight()
    lg.setFont(font)
    lg.print("Players:", 5, 50)
    for i, player in ipairs(net.players) do
        lg.print(("  %s (%d)"):format(player.name, player.id), 5, 50 + fontH * i)
    end

    gui.draw(ui)
end

return scene