#pragma once

#include <mutex>
#include <random>
#include <shared_mutex>

#include "Server.hpp"
#include "serialization.hpp"

struct Lobby {
    struct Player {
        using Id = uint8_t;
        Id id;
        std::weak_ptr<ConnectionBase> connection;
        std::string name;

        struct IdCompare {
            bool operator()(const Player& a, const Player& b) const
            {
                return a.id < b.id;
            }
        };
    };

    static constexpr auto maxPlayers = std::numeric_limits<Player::Id>::max();

    Lobby(std::string name);

    // Requires at least shared lock
    Player::Id getNextPlayerId() const;

    // Requires unique lock
    Player::Id addPlayer(std::string name, std::weak_ptr<ConnectionBase> connection);

    // Requires at least shared lock
    std::optional<size_t> getPlayerIndexById(Player::Id id);

    // Requires unique lock
    void removePlayer(Player::Id id);

    // Requires at least shared lock
    bool canJoin() const;

    // Requires at least shared lock
    bool isPlayerMaster(Player::Id id) const;

    std::string name;
    std::vector<Player> players;
    bool locked = false;

    mutable std::shared_mutex mutex;
};

class LobbyContext {
public:
    LobbyContext(Config config);

    void run();

    std::shared_ptr<Lobby> createLobby();
    std::shared_ptr<Lobby> getLobby(std::string_view name) const;

private:
    Config config_;
    std::unordered_map<std::string, std::weak_ptr<Lobby>> lobbies_;
    mutable std::shared_mutex mutex_;
};

class LobbySession : public ConnectionBase {
public:
    LobbySession(asio::io_service& ioservice, LobbyContext& context);
    ~LobbySession();

    void processReadBuf(asio::streambuf& readBuf) override;

private:
    enum class MessageType : uint8_t {
        createLobby = 0, // c -> s
        joinLobby = 2, // c -> s
        lobbyJoined = 3, // c <- s
        leaveLobby = 4, // c -> s
        lockLobby = 5, // c -> s
        unlockLobby = 6, // c -> s
        sendMessage = 7, // c -> s
        relayMessage = 8, // c <- s
        requestPlayerList = 9, // c -> s
        returnPlayerList = 10, // c <- s
        heartbeat = 11, // c -> s
        lastMessageType,
    };

    void sendMessage(std::shared_ptr<ConnectionBase> connection, std::string_view data);

    void sendResponse(std::string_view data);

    // Requires at least shared lock on lobby_
    void sendToAll(std::string_view data);

    void encodeLobbyJoined(BufferWriter& wbuf, const std::string& lobbyId, uint8_t playerId);

    // Requires at least shared lock on lobby_
    void encodeReturnPlayerList(BufferWriter& wbuf);

    void processCreateLobby(BufferReader& rbuf);
    void processJoinLobby(BufferReader& rbuf);
    void processLeaveLobby(BufferReader& /*rbuf*/);
    void setLobbyLocked(bool locked);
    void processLockLobby(BufferReader& /*rbuf*/);
    void processUnlockLobby(BufferReader& /*rbuf*/);
    void processSendMessage(BufferReader& rbuf);
    void processRequestPlayerList(BufferReader& /*rbuf*/);

    void processMessage(const std::string& msg);

    std::optional<size_t> playerId;
    std::shared_ptr<Lobby> lobby_;
    LobbyContext& context_;
};