#pragma once

#include <deque>
#include <memory>
#include <thread>
#include <vector>

#include <boost/asio.hpp>
#include <boost/asio/ip/tcp.hpp>

#include <spdlog/spdlog.h>

#include "Config.hpp"

namespace asio = boost::asio;
using asio::ip::tcp;
using boost::system::error_code;

class Connection : public std::enable_shared_from_this<Connection> {
public:
    Connection(asio::io_service& ioservice);

    tcp::socket& getSocket();

    void read();
    void send(std::string msg);

private:
    void readBuf(const error_code& error, size_t size);

    void queueMessage(std::string msg);
    void sendFromQueue();
    void sendDone(const error_code& error);

    asio::io_service& ioservice_;
    tcp::socket socket_;
    asio::io_service::strand writeStrand_;
    asio::streambuf readBuf_;
    std::deque<std::string> sendQueue_;
};

class Server {
public:
    Server(Config config);

    void run();

private:
    void accept();
    void handleConnection(std::shared_ptr<Connection> connection, const error_code& error);

    Config config_;
    std::vector<std::thread> threads_;
    asio::io_service ioservice_;
    tcp::acceptor acceptor_;
};