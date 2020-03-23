#include <string_view>

#include <spdlog/spdlog.h>

#include "Config.hpp"
#include "Server.hpp"

int main(int argc, char** argv)
{
    const std::vector<std::string_view> args(argv + 1, argv + argc);
    if (args.size() < 1) {
        spdlog::critical("Usage: server <configfile>");
        return 1;
    }

    const auto configPath = args[0];
    const auto optConfig = Config::loadFromFile(configPath);
    if (!optConfig) {
        spdlog::critical("Could not load initial configuration.");
        return 1;
    }
    const Config& config = *optConfig;
    spdlog::info("Loaded config file '{}'", configPath);

    Server server { config };
    server.run();

    return 1; // This program should run forever, so return 1 here
}
