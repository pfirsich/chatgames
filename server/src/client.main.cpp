#include <boost/asio.hpp>
#include <cstdlib>
#include <cstring>
#include <iostream>

#include <arpa/inet.h>

using boost::asio::ip::tcp;

// https://www.boost.org/doc/libs/1_66_0/doc/html/boost_asio/example/cpp11/echo/blocking_tcp_echo_client.cpp
int main(int argc, char** argv)
{
    if (argc != 3) {
        std::cerr << "Usage: client <host> <port>\n";
        return 1;
    }

    boost::asio::io_context iocontext;

    tcp::socket socket(iocontext);
    tcp::resolver resolver(iocontext);
    boost::asio::connect(socket, resolver.resolve(argv[1], argv[2]));
    std::cout << "Connected." << std::endl;

    constexpr size_t bufSize = 1024;
    char inputBuf[bufSize];
    while (std::cin.getline(inputBuf, bufSize - 4)) {
        const uint32_t len = std::strlen(inputBuf);
        char msgBuf[bufSize];
        const uint32_t nLen = ntohl(len);
        std::memcpy(msgBuf, &nLen, sizeof(uint32_t));
        std::memcpy(msgBuf + sizeof(uint32_t), inputBuf, len);
        boost::asio::write(socket, boost::asio::buffer(msgBuf, len + 4));
    }

    return 0;
}
