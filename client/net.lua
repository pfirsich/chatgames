local socket = require("socket")
local BlobWriter = require("libs.BlobWriter")
local BlobReader = require("libs.BlobReader")
local Queue = require("queue")
local msgpack = require("libs.msgpack")
msgpack.set_string("string")
msgpack.set_number("float")

local msgTypes = ülp.constTable {
    createLobby = 0, -- send
    joinLobby = 2, -- send
    lobbyJoined = 3, -- recv
    leaveLobby = 4, -- send
    lockLobby = 5, -- send
    unlockLobby = 6, -- send
    sendMessage = 7, -- send
    relayMessage = 8, -- recv
    requestLobbyUpdate = 9, -- send
    updateLobby = 10, -- recv
    heartbeat = 11, -- send
}

local net = {}

net.events = ülp.constTable {
    connected = 1,
    lobbyJoined = 2,
    lobbyUpdated = 3,
    message = 4,
}

local reader = BlobReader("", ">")
local writer = BlobWriter(">")

local tcp = nil
local recvQueue = Queue()
local sendQueue = Queue()

local events = Queue()

net.playerName = nil
net.playerId = nil
net.lobbyId = nil
net.players = {}

function net.connect()
    tcp = socket.tcp()
    local success, err = tcp:connect("127.0.0.1", 6969)
    if success == nil then
        error(err)
    end
    tcp:settimeout(0)
end

local encodeMessage = {}

encodeMessage[msgTypes.createLobby] = function(playerName)
    writer:u8(playerName:len()):raw(playerName)
end

encodeMessage[msgTypes.joinLobby] = function(playerName, lobbyId)
    writer:u8(playerName:len()):raw(playerName)
    writer:u8(lobbyId:len()):raw(lobbyId)
end

encodeMessage[msgTypes.sendMessage] = function(msg)
    writer:u16(msg:len()):raw(msg)
end

local function sendMessage(msgType, ...)
    writer:clear():u8(msgType)
    encodeMessage[msgType](...)
    local data = writer:tostring()
    writer:clear()
    writer:u32(data:len())
    writer:raw(data)
    sendQueue:push(writer:tostring())
end

function net.createLobby()
    assert(net.playerName)
    sendMessage(msgTypes.createLobby, net.playerName)
end

function net.joinLobby(lobbyId)
    assert(net.playerName)
    sendMessage(msgTypes.joinLobby, net.playerName, lobbyId)
end

function net.sendMessage(msg)
    sendMessage(msgTypes.sendMessage, msgpack.pack(msg))
end

local messageHandlers = {}

messageHandlers[msgTypes.lobbyJoined] = function(msg)
    reader:reset(msg)
    assert(reader:u8() == msgTypes.lobbyJoined)
    local lobbyIdLen = reader:u8()
    local lobbyId = tostring(reader:raw(lobbyIdLen))
    local playerId = reader:u8()
    events:push({type = net.events.lobbyJoined, data = {
        lobbyId = lobbyId,
        playerId = playerId,
    }})
    net.playerId = playerId
    net.lobbyId = lobbyId
end

messageHandlers[msgTypes.relayMessage] = function(msg)
    reader:reset(msg)
    assert(reader:u8() == msgTypes.relayMessage)
    local _playerId = reader:u8()
    local msgLen = reader:u16()
    local msg = tostring(reader:raw(msgLen))
    events:push({type = net.events.message, data = {
        playerId = _playerId,
        message = msgpack.unpack(msg),
    }})
end

messageHandlers[msgTypes.updateLobby] = function(msg)
    reader:reset(msg)
    assert(reader:u8() == msgTypes.updateLobby)
    local numPlayers = reader:u8()
    net.players = {}
    for i = 1, numPlayers do
        local id = reader:u8()
        local nameLen = reader:u8()
        local name = tostring(reader:raw(nameLen))
        table.insert(net.players, {
            id = id,
            name = name,
        })
        table.sort(net.players, function(a, b) return a.id < b.id end)
    end
    events:push({type = net.events.lobbyUpdated, data = net.players})
end

local function readSocket()
    local msg, err, part = tcp:receive("*all")
    if msg == nil and err == "timeout" then
        return part
    end
    if msg == nil then
        error(err)
    end
    return msg
end

local function concatUntil(recvQueue, sizeToReach)
    local front = recvQueue:peek()
    local frontLen = front:len()

    if frontLen >= sizeToReach then
        return true
    end

    local totalSize = frontLen
    for offset = 1, recvQueue:size() - 1 do
        totalSize = totalSize + recvQueue:peek(offset)
        if totalSize >= sizeToReach then
            -- concat
            local parts = {}
            for i = 0, offset do
                table.insert(parts, recvQueue:pop())
            end
            recvQueue:pushFront(table.concat(parts, ""))
            return true
        end
    end

    -- we went through the whole queue and it wasn't enough
    return false
end

local function receive()
    local data = readSocket()
    local dataLen = data:len()
    if data and dataLen > 0 then
        print("Received:", ülp.hexDump(data), data)
        recvQueue:push(data)
    end

    while true do
        if recvQueue:empty() then
            -- there is nothing to do
            return
        end

        local enoughForSize = concatUntil(recvQueue, 4)
        if not enoughForSize then
            print("no size")
            return
        end

        reader:reset(recvQueue:peek())
        local msgSize = reader:u32()
        print(recvQueue:peek():len(), msgSize + 4)
        local enoughForMsg = concatUntil(recvQueue, msgSize + 4)
        if not enoughForMsg then
            print("no msg")
            return
        end

        local front = recvQueue:pop()
        print("pop off recvQueue")
        local msg = front:sub(5, msgSize + 4)
        if front:len() > msgSize + 4 then
            -- push the rest back
            recvQueue:pushFront(front:sub(msgSize + 4 + 1))
        end

        local msgType = msg:byte()
        local msgHandler = messageHandlers[msgType]
        if msgHandler then
            print("receive", msgTypes:getName(msgType))
            msgHandler(msg)
        else
            print("Unexpected/unknown message type:", msgType)
        end
    end
end

local function send()
    while not sendQueue:empty() do
        local data = sendQueue:pop()
        local dataLen = data:len()
        local bytesSent, err = tcp:send(data)
        if bytesSent == nil then
            if err == "timeout" then
                sendQueue:pushFront(data)
            else
                error(err)
            end
        else
            if bytesSent < dataLen then
                sendQueue:pushFront(data:sub(bytesSent + 1))
                break
            end
        end
    end
end

function net.update()
    receive()

    if events:empty() then
        send()
        return nil
    else
        return events:pop()
    end
end

function net.isMaster(playerId)
    playerId = playerId or net.playerId
    return net.players[1].id == playerId
end

return net