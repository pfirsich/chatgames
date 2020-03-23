#include "Server.hpp"

#include <arpa/inet.h>

#include <boost/lexical_cast.hpp>

template <typename T>
T peekInteger(const asio::streambuf& sbuf)
{
    assert(sbuf.size() >= sizeof(T));
    const auto buffer = asio::buffer_cast<const char*>(sbuf.data());
    T val { 0 };
    std::memcpy(&val, buffer, sizeof(T));
    return val;
}

std::string readString(asio::streambuf& sbuf, size_t n)
{
    assert(sbuf.size() >= n);
    const auto begin = asio::buffers_begin(sbuf.data());
    return std::string { begin, begin + n };
}

Connection::Connection(asio::io_service& ioservice)
    : ioservice_(ioservice)
    , socket_(ioservice)
    , writeStrand_(ioservice)
{
}

tcp::socket& Connection::getSocket()
{
    return socket_;
}

void Connection::read()
{
    // We pass in a shared_ptr to ourselves, so as long as the connection lives
    // and read will call itself, this object stays alive.
    const auto buffers = readBuf_.prepare(512);
    socket_.async_read_some(
        asio::buffer(buffers), [me = shared_from_this()](const error_code& error, size_t size) {
            me->readBuf(error, size);
        });
}

void Connection::readBuf(const error_code& error, size_t size)
{
    if (error)
        return;

    readBuf_.commit(size);

    if (readBuf_.size() >= 4) {
        const auto msgSize = ntohl(peekInteger<uint32_t>(readBuf_));
        if (readBuf_.size() >= msgSize + 4) {
            readBuf_.consume(4);
            const auto msg = readString(readBuf_, msgSize);
            readBuf_.consume(msgSize);
            // TODO: Hand it to a message handler
            spdlog::info("Message: {}", msg);
        }
    }

    read();
}

void Connection::send(std::string msg)
{
    // We cannot send from multiple threads, so we need a strand
    ioservice_.post(writeStrand_.wrap(
        [me = shared_from_this(), msg = std::move(msg)]() { me->queueMessage(std::move(msg)); }));
}

void Connection::queueMessage(std::string msg)
{
    const bool writeInProgress = !sendQueue_.empty();
    // We don't have to protect sendQueue_ here, because this function (and all others that
    // access sendQueue_) is called from the writeStrand_
    sendQueue_.emplace_back(std::move(msg));

    // sendFromQueue will end up calling itself if there is still something to send,
    // but if there is not, we have to kick it off again
    if (!writeInProgress) {
        sendFromQueue();
    }
}

void Connection::sendFromQueue()
{
    asio::async_write(socket_, asio::buffer(sendQueue_.front()),
        writeStrand_.wrap(
            [me = shared_from_this()](const error_code& error, size_t) { me->sendDone(error); }));
}

void Connection::sendDone(const error_code& error)
{
    if (!error) {
        sendQueue_.pop_front();
        if (!sendQueue_.empty())
            sendFromQueue();
    }
}

Server::Server(Config config)
    : config_(std::move(config))
    , threads_(config.numThreads)
    , acceptor_(ioservice_)
{
}

void Server::accept()
{
    const auto connection = std::make_shared<Connection>(ioservice_);

    acceptor_.async_accept(connection->getSocket(),
        [=](const error_code& error) { handleConnection(connection, error); });
}

void Server::handleConnection(std::shared_ptr<Connection> connection, const error_code& error)
{
    if (!error) {
        spdlog::info("Connection from: {}",
            boost::lexical_cast<std::string>(connection->getSocket().remote_endpoint()));
        connection->read();
    }

    accept();
}

void Server::run()
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
    spdlog::warn("Started {} worker threads", threads_.size());

    for (auto& thread : threads_)
        thread.join();
    spdlog::warn("Worker threads joined");
}