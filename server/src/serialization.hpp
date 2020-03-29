#pragma once

#include <optional>
#include <string>

#include <boost/asio.hpp>

#include <arpa/inet.h>

namespace asio = boost::asio;

template <typename T>
T ntoh(T val)
{
    static_assert(
        std::is_same_v<T, uint8_t> || std::is_same_v<T, uint16_t> || std::is_same_v<T, uint32_t>,
        "Unknown type for ntoh");
    if constexpr (std::is_same_v<T, uint8_t>) {
        return val;
    } else if constexpr (std::is_same_v<T, uint16_t>) {
        return ntohs(val);
    } else if constexpr (std::is_same_v<T, uint32_t>) {
        return ntohl(val);
    }
    // This should never happen
    return val;
}

template <typename T>
T hton(T val)
{
    static_assert(
        std::is_same_v<T, uint8_t> || std::is_same_v<T, uint16_t> || std::is_same_v<T, uint32_t>,
        "Unknown type for ntoh");
    if constexpr (std::is_same_v<T, uint8_t>) {
        return val;
    } else if constexpr (std::is_same_v<T, uint16_t>) {
        return htons(val);
    } else if constexpr (std::is_same_v<T, uint32_t>) {
        return htonl(val);
    }
    // This should never happen
    return val;
}

template <typename T>
T peekInteger(const asio::streambuf& sbuf)
{
    assert(sbuf.size() >= sizeof(T));
    const auto buffer = asio::buffer_cast<const char*>(sbuf.data());
    T val { 0 };
    std::memcpy(&val, buffer, sizeof(T));
    return val;
}

std::string readString(asio::streambuf& sbuf, size_t n);

std::optional<std::string> readMessage(asio::streambuf& readBuf);

class BufferReader {
public:
    BufferReader(asio::const_buffer buffer)
        : buffer_(buffer)
    {
    }

    size_t size() const
    {
        return buffer_.size();
    }

    size_t remaining() const
    {
        return size() - tell();
    }

    void seek(size_t pos)
    {
        cursor_ = pos;
    }

    void seekRel(int delta)
    {
        cursor_ += delta;
    }

    size_t tell() const
    {
        return cursor_;
    }

    template <typename T = void>
    const T* tellPtr() const
    {
        return reinterpret_cast<const T*>(
            reinterpret_cast<const uint8_t*>(buffer_.data()) + cursor_);
    }

    template <typename T>
    T integer()
    {
        static_assert(std::is_integral_v<T>);
        T val { 0 };
        std::memcpy(&val, tellPtr(), sizeof(T));
        seekRel(sizeof(T));
        return ntoh(val);
    }

    std::string string(size_t size)
    {
        std::string str(tellPtr<char>(), size);
        seekRel(size);
        return str;
    }

    template <typename SizeType = uint8_t>
    std::string string()
    {
        const auto size = integer<SizeType>();
        return string(size);
    }

private:
    asio::const_buffer buffer_;
    size_t cursor_ = 0;
};

class BufferWriter {
public:
    BufferWriter(size_t size = 0)
        : buffer_(size)
    {
    }

    template <typename T>
    BufferWriter& integer(T val)
    {
        std::vector<uint8_t> temp(sizeof(T));
        const T valOrdered = hton(val);
        std::memcpy(temp.data(), &valOrdered, sizeof(T));
        buffer_.insert(buffer_.end(), temp.begin(), temp.end());
        return *this;
    }

    template <typename SizeType = uint8_t>
    BufferWriter& string(std::string_view str, size_t len)
    {
        integer<SizeType>(len);
        buffer_.insert(buffer_.end(), str.begin(), str.end());
        return *this;
    }

    template <typename SizeType = uint8_t>
    BufferWriter& string(std::string_view str)
    {
        return string<SizeType>(str, str.size());
    }

    std::string toString() const
    {
        return std::string(buffer_.begin(), buffer_.end());
    }

    void clear()
    {
        buffer_.clear();
    }

private:
    std::vector<uint8_t> buffer_;
};