local scenes = require("scenes")
local net = require("net")
local fonts = require("fonts")
local gui = require("gui")
local playerColors = require("playercolors")

local messages = ülp.constTable {
    vote = 1,
    updatePlayerData = 2,
}

local scene = {}

local gameListMargin = 20
local gameListX = 250

local minGameButtonW = 150
local maxGameButtonW = 400

local copyIdButton = gui.Button("Copy Lobby Name", gui.Button.defaultWidth, 30)
local voteButton = gui.Button("Vote for Game")
local startButton = gui.Button("Start Game")
local watchButton = gui.Button("Watch")
local gameButtons = {}
local ui = {
    copyIdButton, voteButton, startButton, watchButton
}

watchDescription = "Don't play, just watch"

local selectedGame = nil

local playerData = {}

local games = {}

local playerColorIndices = ülp.range(1, #playerColors)
ülp.shuffle(playerColorIndices)

function scene.load()
    games = {}

    local items = lf.getDirectoryItems("games")
    for i, item in ipairs(items) do
        local game = require("games." .. item)
        table.insert(games, game)
    end
    table.sort(games, function(a, b) return a.name < b.name end)

    for i, game in ipairs(games) do
        local button = gui.Button(game.name)
        table.insert(gameButtons, button)
        table.insert(ui, button)
    end
end

function scene.enter(lobbyJoinedData)
    selectedGame = nil
end

function scene.keypressed(key)
    local ctrl = lk.isDown("lctrl") or lk.isDown("rctrl")
    if ctrl and key == "c" then
        love.system.setClipboardText(net.lobbyId)
    end
end

local function getGameListRect()
    local winW, winH = love.graphics.getDimensions()
    local y = copyIdButton.y + copyIdButton.h + gameListMargin
    local w = winW - gameListX - gameListMargin
    local h = winH - y - gameListMargin
    return gameListX, y, w, h
end

local function getPlayersByVote(gameIndex)
    local players = {}
    for id, player in pairs(playerData) do
        if player.vote == gameIndex then
            table.insert(players, id)
        end
    end
    return players
end

local function voteFinished()
    local votes = {}
    for i = 0, #games do
        votes[i] = getPlayersByVote(i)
    end

    local totalVotes = ülp.reduce(votes, function(players) return #players end)
    -- votes[0] is "just watch"
    if totalVotes + #votes[0] < #net.players then
        -- not everyone voted
        return false
    end

    local gamesVotedFor = ülp.filter(votes, function(players) return #players > 0 end)
    if #gamesVotedFor > 1 then
        -- not everyone that wants to play is not voting for the same game
        return false
    end

    local votesForGame = gamesVotedFor[1]
    local gameIndex = ülp.findKey(votes, votesForGame)
    if #votesForGame < games[gameIndex].minPlayers
            or #votesForGame > games[gameIndex].maxPlayers then
        return false
    end

    return true
end

local function sendPlayerData()
    local data = {}
    for id, player in pairs(playerData) do
        table.insert(data, {id, player.color, player.vote})
    end
    net.sendMessage{type = messages.updatePlayerData, data = data}
end

local function sendVote(vote)
    net.sendMessage{type = messages.vote, vote = vote}
end

local function processMessage(playerId, msg)
    print("msg:", finspect(msg))
    playerData[playerId] = playerData[playerId] or {}
    if msg.type == messages.vote then
        playerData[playerId].vote = msg.vote
        if net.isMaster() then
            sendPlayerData()
        end
    elseif msg.type == messages.updatePlayerData then
        if not net.isMaster() then
            playerData = {}
            for _, player in ipairs(msg.data) do
                local id = player[1]
                playerData[id] = {
                    color = player[2],
                    vote = player[3],
                }
            end
        end
    else
        print("Unknown message:", finspect(msg))
    end
end

function scene.tick()
    local event = net.update()
    while event do
        if event.type == net.events.lobbyUpdated then
            print("Lobby updated:", finspect(event.data))
        elseif event.type == net.events.message then
            print("Message:", event.data.playerId, event.data.message)
            processMessage(event.data.playerId, event.data.message)
        end
        event = net.update()
    end

    if net.isMaster() then
        local addedPlayerData = false
        for _, player in ipairs(net.players) do
            if playerData[player.id] == nil then
                if #playerColorIndices == 0 then
                    error("Ran out of player colors")
                end
                playerData[player.id] = {
                    color = table.remove(playerColorIndices),
                    vote = nil,
                }
                addedPlayerData = true
            end
        end

        if addedPlayerData then
            sendPlayerData()
        end
    end

    local winW, winH = love.graphics.getDimensions()
    copyIdButton.x = winW/2 - copyIdButton.w/2
    copyIdButton.y = math.floor(fonts.big:getHeight() * 1.5)

    local gameListX, gameListY, gameListW, gameListH = getGameListRect()
    local gameButtonW = ülp.clamp(gameListW / (#gameButtons + 1), minGameButtonW, maxGameButtonW)
    for i, gameButton in ipairs(gameButtons) do
        gameButton.w = gameButtonW
        gameButton.x = gameListX + (i - 1) * gameButton.w
        gameButton.y = gameListY
    end
    watchButton.w = gameButtonW
    watchButton.x = gameButtons[#gameButtons].x + gameButtons[#gameButtons].w
    watchButton.y = gameListY

    voteButton.x = gameListX + gameListW / 2 - voteButton.w / 2
    voteButton.y = gameListY + gameListH - voteButton.h - 5

    local showStart = net.isMaster() and voteFinished()
    startButton:setHidden(not showStart)

    startButton.x = gameListX + gameListW - startButton.w - 5
    startButton.y = voteButton.y

    gui.update(ui)

    if copyIdButton.triggered then
        love.system.setClipboardText(net.lobbyId)
    end

    for i, gameButton in ipairs(gameButtons) do
        if gameButton.triggered then
            selectedGame = games[i]
        end
    end

    if voteButton.triggered then
        local vote = selectedGame and ülp.findKey(games, selectedGame) or 0
        playerData[net.playerId].vote = vote
        if net.isMaster() then
            sendPlayerData()
        else
            sendVote(vote)
        end
    end

    if watchButton.triggered then
        selectedGame = nil
    end
end

local function markButtonVotes(button, gameIndex)
    local voteIndicatorSize = 15
    local spacing = 2

    local votes = getPlayersByVote(gameIndex)
    for i, playerId in ipairs(votes) do
        if true or playerId ~= net.playerId then
            local color = playerColors[playerData[playerId].color]
            lg.setColor(color)
            local x = button.x + spacing + (i - 1) * (voteIndicatorSize + spacing)
            lg.rectangle("fill", x, button.y + spacing, voteIndicatorSize, voteIndicatorSize)
        end
    end
end

function scene.draw()
    local winW, winH = love.graphics.getDimensions()

    lg.setFont(fonts.big)
    lg.setColor(1, 1, 1)
    local title = "Lobby: " .. net.lobbyId
    lg.printf(title, 0, 5, winW, "center")

    local font = fonts.medium
    local fontH = font:getHeight()
    lg.setFont(font)
    lg.print("Players:", 5, 50)
    for i, player in ipairs(net.players) do
        local y = math.floor(50 + fontH * (i + 0.5))
        local color = {1, 1, 1}
        if playerData[player.id] then
            color = playerColors[playerData[player.id].color]
        end
        lg.setColor(color)
        lg.print(("%s (%d)"):format(player.name, player.id), 5, y)
    end

    local gameListX, gameListY, gameListW, gameListH = getGameListRect()
    lg.setColor(0.1, 0.1, 0.1)
    lg.rectangle("line", gameListX, gameListY, gameListW, gameListH)
    lg.setColor(1, 1, 1)
    local description = selectedGame and selectedGame.description or watchDescription
    lg.printf(description,
        gameListX + 10,
        gameListY + gameButtons[1].h + 10,
        gameListW - 20)

    gui.draw(ui)

    for gameIdx, gameButton in ipairs(gameButtons) do
        markButtonVotes(gameButton, gameIdx)
    end
    markButtonVotes(watchButton, 0)

    local vote = playerData[net.playerId] and playerData[net.playerId].vote
    if false and vote then
        local button = vote and gameButtons[vote] or watchButton
        local color = playerColors[playerData[net.playerId].color]
        lg.setColor(color)
        lg.setLineWidth(3)
        lg.rectangle("line", button.x + 1, button.y + 1, button.w - 2, button.h - 2)
        lg.setLineWidth(1)
    end
end

return scene