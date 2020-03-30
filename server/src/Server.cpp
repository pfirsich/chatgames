#include "Server.hpp"

#include "util.hpp"

ConnectionBase::ConnectionBase(asio::io_context& ioContext)
    : ioContext_(ioContext)
    , writeStrand_(ioContext.get_executor())
    , socket_(ioContext_)
{
}

tcp::socket& ConnectionBase::getSocket()
{
    return socket_;
}

std::shared_ptr<ConnectionBase> ConnectionBase::getSharedPtr()
{
    return shared_from_this();
}

std::weak_ptr<ConnectionBase> ConnectionBase::getWeakPtr()
{
    return weak_from_this();
}

void ConnectionBase::read()
{
    // We pass in a shared_ptr to ourselves, so as long as the connection lives
    // and read will call itself, this object stays alive.
    const auto buffers = readBuf_.prepare(512);
    socket_.async_read_some(asio::buffer(buffers),
        [me = this->shared_from_this()](
            const error_code& error, size_t size) { me->readBuf(error, size); });
}

void ConnectionBase::send(std::string msg)
{
    spdlog::debug("ConnectionBase::send ({}): {}", threadIdStr(), hexDump(msg));
    // We cannot send from multiple threads, so we need a strand
    asio::post(writeStrand_, [me = this->shared_from_this(), msg = std::move(msg)]() {
        spdlog::debug("in lambda ({}): {}", threadIdStr(), hexDump(msg));
        me->queueMessage(std::move(msg));
    });
}

void ConnectionBase::readBuf(const error_code& error, size_t size)
{
    if (error)
        return;

    readBuf_.commit(size);

    processReadBuf(readBuf_);

    read();
}

void ConnectionBase::queueMessage(std::string msg)
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

void ConnectionBase::sendFromQueue()
{
    asio::async_write(socket_, asio::buffer(sendQueue_.front()),
        asio::bind_executor(
            writeStrand_, [me = this->shared_from_this()](const error_code& error, size_t) {
                me->sendDone(error);
            }));
}

void ConnectionBase::sendDone(const error_code& error)
{
    if (!error) {
        sendQueue_.pop_front();
        if (!sendQueue_.empty())
            sendFromQueue();
    }
}
