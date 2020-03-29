#pragma once

#include <deque>
#include <memory>
#include <thread>
#include <vector>

#include <boost/asio.hpp>
#include <boost/asio/ip/tcp.hpp>
#include <boost/lexical_cast.hpp>

#include <spdlog/spdlog.h>

#include "Config.hpp"

namespace asio = boost::asio;
using asio::ip::tcp;
using boost::system::error_code;

class ConnectionBase : public std::enable_shared_from_this<ConnectionBase> {
public:
    ConnectionBase(asio::io_service& ioservice);

    virtual ~ConnectionBase() = default;

    tcp::socket& getSocket();

    std::shared_ptr<ConnectionBase> getSharedPtr();
    std::weak_ptr<ConnectionBase> getWeakPtr();

    void read();
    void send(std::string msg);

private:
    void readBuf(const error_code& error, size_t size);

    void queueMessage(std::string msg);
    void sendFromQueue();
    void sendDone(const error_code& error);

protected:
    virtual void processReadBuf(asio::streambuf&) = 0;

    asio::io_service& ioservice_;
    tcp::socket socket_;
    asio::io_service::strand writeStrand_;
    asio::streambuf readBuf_;
    std::deque<std::string> sendQueue_;
};

template <typename Connection, typename Context>
class Server {
public:
    Server(Config config)
        : config_(std::move(config))
        , threads_(config.numThreads)
        , acceptor_(ioservice_)
        , context_(config_)
    {
    }

    void run()
    {
        spdlog::info("Listening on port {}", config_.port);
        const auto ep = tcp::endpoint { tcp::v4(), config_.port };
        acceptor_.open(ep.protocol());
        acceptor_.set_option(tcp::acceptor::reuse_address(true));
        acceptor_.bind(ep);
        acceptor_.listen();

        accept();

        for (auto& thread : threads_)
            thread = std::thread { [&]() { ioservice_.run(); } };
        spdlog::info("Started {} IO worker threads", threads_.size());

        spdlog::info("Running context");
        context_.run();

        for (auto& thread : threads_)
            thread.join();
        spdlog::warn("IO worker threads joined");
    }

private:
    void accept()
    {
        const auto connection = std::make_shared<Connection>(ioservice_, context_);

        acceptor_.async_accept(connection->getSocket(),
            [=](const error_code& error) { handleConnection(connection, error); });
    }

    void handleConnection(std::shared_ptr<Connection> connection, const error_code& error)
    {
        if (!error) {
            spdlog::info("Connection from: {}",
                boost::lexical_cast<std::string>(connection->getSocket().remote_endpoint()));
            connection->read();
        }

        accept();
    }

    Config config_;
    std::vector<std::thread> threads_;
    asio::io_service ioservice_;
    tcp::acceptor acceptor_;
    Context context_;
};