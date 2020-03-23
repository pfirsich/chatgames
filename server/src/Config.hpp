#pragma once

#include <optional>
#include <string_view>

struct Config {
    uint16_t port;
    size_t numThreads;

    static std::optional<Config> loadFromFile(std::string_view path);
};
