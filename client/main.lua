require("globals")

local net = require("net")

net.playerName = "joel"
net.connect()

function love.update()
    local event = net.update()
    while event do
        if event.type == net.events.connected then
            print("Connected.")
        elseif event.type == net.events.lobbyJoined then
            print("Created lobby:", event.data.lobbyId, event.data.playerId)
        elseif event.type == net.events.playerListUpdated then
            print("Lobby updated:", inspect(event.data))
        elseif event.type == net.events.message then
            print("Message:", event.data.playerId, event.data.message)
        end
        event = net.update()
    end
end

function love.keypressed(key)
    if key == "h" then
        print("Create lobby")
        net.createLobby()
    elseif key == "j" then
        print("Join Lobby")
        net.joinLobby(love.system.getClipboardText())
    elseif key == "s" then
        print("Send message")
        net.sendMessage("testpipikaka")
    end
end
