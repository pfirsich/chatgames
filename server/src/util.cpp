#include "util.hpp"

#include <thread>

// Only use this function for ASCII!
std::string toLower(std::string_view str)
{
    std::string lower { str };
    boost::algorithm::to_lower_copy(lower);
    return lower;
}

std::string hexDump(std::string_view data)
{
    std::stringstream ss;
    for (const auto& c : data) {
        ss << std::hex << std::setw(2) << std::setfill('0') << static_cast<int>(c) << " ";
    }
    return ss.str();
}

std::string threadIdStr()
{
    std::stringstream ss;
    ss << std::this_thread::get_id();
    return ss.str();
}
