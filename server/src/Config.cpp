#include "Config.hpp"

#include <fstream> // Needed so parse_file works?
#include <thread>

#include <spdlog/spdlog.h>
#include <toml++/toml.h>

std::optional<Config> Config::loadFromFile(std::string_view path)
{
    try {
        const auto table = toml::parse_file(path);
        Config config;

        const auto port = table["port"].value<int64_t>();
        if (!port || *port < 0 || *port > 65535) {
            spdlog::error("Integer 'port' is mandatory in config.");
            return std::nullopt;
        }
        config.port = static_cast<uint16_t>(*port);

        const auto defaultThreads = std::thread::hardware_concurrency();
        config.numThreads = table["numThreads"].value_or<int64_t>(defaultThreads);

        return config;
    } catch (const toml::parse_error& err) {
        const auto src = err.source();
        spdlog::critical("Error parsing config file\n{}:{}:{}: {}", *src.path, src.begin.line,
            src.begin.column, err.description());
        return std::nullopt;
    }
}