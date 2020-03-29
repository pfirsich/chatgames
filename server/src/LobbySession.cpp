#include "LobbySession.hpp"

#include "util.hpp"
#include "words.hpp"

std::string getRandomLobbyName()
{
    return randomChoice(adjectives) + randomChoice(nouns);
}

Lobby::Lobby(std::string name)
    : name(std::move(name))
{
}

Lobby::Player::Id Lobby::getNextPlayerId() const
{
    assert(players.size() < maxPlayers
        && std::is_sorted(players.begin(), players.end(), Player::IdCompare()));
    for (size_t i = 0; i < players.size(); ++i) {
        // players is sorted, so this id is free
        if (players[i].id != i) {
            return static_cast<Player::Id>(i);
        }
    }
    // No gaps found, return new one
    return static_cast<Player::Id>(players.size());
}

Lobby::Player::Id Lobby::addPlayer(std::string name, std::weak_ptr<ConnectionBase> connection)
{
    const auto id = getNextPlayerId();
    players.emplace_back(Player { id, connection, name });
    std::sort(players.begin(), players.end(), Player::IdCompare());
    return id;
}

std::optional<size_t> Lobby::getPlayerIndexById(Player::Id id)
{
    for (size_t i = 0; i < players.size(); ++i) {
        if (players[i].id == id)
            return i;
    }
    return std::nullopt;
}

void Lobby::removePlayer(Player::Id id)
{
    const auto playerIdx = getPlayerIndexById(id);
    assert(playerIdx);
    players.erase(players.begin() + *playerIdx);
}

bool Lobby::canJoin() const
{
    return !locked && players.size() < maxPlayers;
}

bool Lobby::isPlayerMaster(Player::Id id) const
{
    // For now the lowest player id (first element) is master
    return players.size() > 0 && players.front().id == id;
}

LobbyContext::LobbyContext(Config config)
    : config_(std::move(config))
{
}

void LobbyContext::run()
{
}

std::shared_ptr<Lobby> LobbyContext::createLobby()
{
    std::unique_lock lock(mutex_);
    std::string name = getRandomLobbyName();
    while (lobbies_.find(toLower(name)) != lobbies_.end()) {
        name = getRandomLobbyName();
        spdlog::debug(name);
        spdlog::debug(toLower(name));
    }
    const auto lobby = std::make_shared<Lobby>(name);
    lobbies_.emplace(toLower(name), lobby);
    return lobby;
}

std::shared_ptr<Lobby> LobbyContext::getLobby(std::string_view name) const
{
    std::shared_lock lock(mutex_);
    const auto it = lobbies_.find(toLower(name));
    if (it != lobbies_.end())
        return it->second.lock();
    else
        return nullptr;
}

LobbySession::LobbySession(asio::io_service& ioservice, LobbyContext& context)
    : ConnectionBase(ioservice)
    , context_(context)
{
}

LobbySession::~LobbySession()
{
}

void LobbySession::processReadBuf(asio::streambuf& readBuf)
{
    const auto msg = readMessage(readBuf);
    if (msg) {
        processMessage(*msg);
    }
}

void LobbySession::sendMessage(std::shared_ptr<ConnectionBase> connection, std::string_view data)
{
    BufferWriter wbuf;
    wbuf.string<uint32_t>(data);
    const auto msg = wbuf.toString();
    spdlog::debug("Send: {}", hexDump(msg));
    connection->send(msg);
}

void LobbySession::sendResponse(std::string_view data)
{
    sendMessage(getSharedPtr(), data);
}

// Requires at least shared lock on lobby_
void LobbySession::sendToAll(std::string_view data)
{
    for (const auto& player : lobby_->players) {
        if (auto conn = player.connection.lock())
            sendMessage(conn, data);
    }
}

void LobbySession::encodeLobbyJoined(
    BufferWriter& wbuf, const std::string& lobbyId, uint8_t playerId)
{
    wbuf.integer<uint8_t>(static_cast<uint8_t>(MessageType::lobbyJoined));
    wbuf.string(lobbyId);
    wbuf.integer<uint8_t>(playerId);
}

// Requires at least shared lock on lobby_
void LobbySession::encodeReturnPlayerList(BufferWriter& wbuf)
{
    wbuf.integer<uint8_t>(static_cast<uint8_t>(MessageType::returnPlayerList));
    wbuf.integer<uint8_t>(lobby_->players.size());
    for (const auto& player : lobby_->players) {
        wbuf.integer<uint8_t>(player.id);
        wbuf.string(player.name);
    }
}

void LobbySession::processCreateLobby(BufferReader& rbuf)
{
    const auto playerName = rbuf.string();
    BufferWriter wbuf;
    lobby_ = context_.createLobby();
    {
        std::unique_lock lock(lobby_->mutex);
        playerId = lobby_->addPlayer(playerName, getWeakPtr());
        encodeLobbyJoined(wbuf, lobby_->name, *playerId);
    }
    sendResponse(wbuf.toString());

    spdlog::debug("Create lobby {} with player {} (id: {})", lobby_->name, playerName, *playerId);
}

void LobbySession::processJoinLobby(BufferReader& rbuf)
{
    const auto playerName = rbuf.string();
    const auto lobbyId = rbuf.string();
    lobby_ = context_.getLobby(lobbyId);
    if (lobby_) {
        BufferWriter lobbyJoinedBuf, playerListBuf;
        std::unique_lock lock(lobby_->mutex);
        if (lobby_->canJoin()) {
            playerId = lobby_->addPlayer(playerName, getWeakPtr());
            encodeLobbyJoined(lobbyJoinedBuf, lobby_->name, *playerId);
            encodeReturnPlayerList(playerListBuf);
            sendResponse(lobbyJoinedBuf.toString());
            sendToAll(playerListBuf.toString());
            spdlog::debug(
                "Joined lobby {} with player {} (id: {})", lobby_->name, playerName, *playerId);
        } else {
            spdlog::debug("Cannot join lobby {}", lobby_->name);
        }
    } else {
        spdlog::info("Attempt to join non-existent lobby {}", lobbyId);
    }
}

void LobbySession::processLeaveLobby(BufferReader& /*rbuf*/)
{
    if (lobby_) {
        {
            std::unique_lock lock(lobby_->mutex);
            lobby_->removePlayer(*playerId);
            playerId = std::nullopt;

            BufferWriter wbuf;
            encodeReturnPlayerList(wbuf);
            sendToAll(wbuf.toString());
        }
        lobby_.reset();
    }
}

void LobbySession::setLobbyLocked(bool locked)
{
    if (lobby_) {
        assert(playerId);
        std::unique_lock lock(lobby_->mutex);
        if (lobby_->isPlayerMaster(*playerId))
            lobby_->locked = locked;
    }
}

void LobbySession::processLockLobby(BufferReader& /*rbuf*/)
{
    setLobbyLocked(true);
}

void LobbySession::processUnlockLobby(BufferReader& /*rbuf*/)
{
    setLobbyLocked(false);
}

void LobbySession::processSendMessage(BufferReader& rbuf)
{
    const auto msg = rbuf.string<uint16_t>();
    if (lobby_) {
        assert(playerId);

        BufferWriter wbuf;
        wbuf.integer<uint8_t>(static_cast<uint8_t>(MessageType::relayMessage));
        wbuf.integer<uint8_t>(*playerId);
        wbuf.string<uint16_t>(msg);
        const auto sendMsg = wbuf.toString();
        {
            std::shared_lock lock(lobby_->mutex);
            for (const auto& player : lobby_->players) {
                if (player.id != *playerId) {
                    if (auto conn = player.connection.lock())
                        sendMessage(conn, sendMsg);
                }
            }
        }
    }
}

void LobbySession::processRequestPlayerList(BufferReader& /*rbuf*/)
{
    if (lobby_) {
        BufferWriter wbuf;
        {
            std::shared_lock lock(lobby_->mutex);
            encodeReturnPlayerList(wbuf);
        }
        sendResponse(wbuf.toString());
    }
}

void LobbySession::processMessage(const std::string& msg)
{
    BufferReader rbuf(asio::buffer(msg));
    const auto typeVal = rbuf.integer<uint8_t>();
    if (typeVal >= static_cast<uint8_t>(MessageType::lastMessageType)) {
        spdlog::info("Received message with invalid type {}", typeVal);
        return;
    }
    const auto type = static_cast<MessageType>(typeVal);
    switch (type) {
    case MessageType::createLobby:
        processCreateLobby(rbuf);
        break;
    case MessageType::joinLobby:
        processJoinLobby(rbuf);
        break;
    case MessageType::leaveLobby:
        processLeaveLobby(rbuf);
        break;
    case MessageType::lockLobby:
        processLockLobby(rbuf);
        break;
    case MessageType::unlockLobby:
        processUnlockLobby(rbuf);
        break;
    case MessageType::sendMessage:
        processSendMessage(rbuf);
        break;
    case MessageType::requestPlayerList:
        processRequestPlayerList(rbuf);
        break;
    case MessageType::heartbeat:
        // this message is supposed to be ignored
        break;
    default:
        spdlog::info("Received message of unexpected type: {}", typeVal);
        break;
    }
}