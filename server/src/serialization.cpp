#include "serialization.hpp"

std::string readString(asio::streambuf& sbuf, size_t n)
{
    assert(sbuf.size() >= n);
    const auto begin = asio::buffers_begin(sbuf.data());
    return std::string { begin, begin + n };
}

std::optional<std::string> readMessage(asio::streambuf& readBuf)
{
    if (readBuf.size() >= 4) {
        const auto msgSize = ntohl(peekInteger<uint32_t>(readBuf));
        if (readBuf.size() >= msgSize + 4) {
            readBuf.consume(4);
            const auto msg = readString(readBuf, msgSize);
            readBuf.consume(msgSize);
            return msg;
        }
    }
    return std::nullopt;
}