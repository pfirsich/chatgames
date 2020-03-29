local gui = require("gui")
local net = require("net")
local scenes = require("scenes")
local fonts = require("fonts")

local scene = {}

local createButton = gui.Button("Create Lobby")
local lobbyIdLabel = gui.Label("<Ctrl+V> to Paste Lobby Name")
local joinButton = gui.Button("Join Lobby")
local ui = {
    createButton, lobbyIdLabel, joinButton
}

function scene.enter()
    net.playerName = "joel"
    net.connect()
end

local function createLobby()
    net.createLobby()
    scenes.enter(scenes.waitForJoin)
end

local function joinLobby(lobbyId)
    net.joinLobby(lobbyId)
    scenes.enter(scenes.waitForJoin)
end

function scene.keypressed(key)
    local ctrl = lk.isDown("lctrl") or lk.isDown("rctrl")
    if key == "c" then
        createLobby()
    elseif key == "j" then
        local lobbyId = ülp.trim(love.system.getClipboardText())
        if validLobbyName(lobbyId) then
            joinLobby(lobbyId)
        end
    elseif ctrl and key == "v" then
        lobbyIdLabel.text = ülp.trim(love.system.getClipboardText())
    end
end

local function validLobbyName(str)
    return not str:match("%W")
end

function scene.tick()
    local winW, winH = love.graphics.getDimensions()
    local font = lg.getFont()
    local margin = 50
    createButton.x = winW/2 - createButton.w/2
    createButton.y = winH/2 - createButton.h - margin
    lobbyIdLabel.x = winW/2 - font:getWidth(lobbyIdLabel.text)/2
    lobbyIdLabel.y = winH/2 + margin
    joinButton.x = winW/2 - joinButton.w/2
    joinButton.y = winH/2 + font:getHeight()*2 + margin
    joinButton.disabled = not validLobbyName(lobbyIdLabel.text)
    gui.update(ui)

    if createButton.triggered then
        createLobby()
    end

    if joinButton.triggered then
        joinLobby(lobbyIdLabel.text)
    end
end

function scene.draw()
    lg.setFont(fonts.medium)
    gui.draw(ui)
end

return scene