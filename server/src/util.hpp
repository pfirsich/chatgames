#include <algorithm>
#include <iomanip>
#include <random>
#include <sstream>
#include <string>
#include <string_view>

#include <boost/algorithm/string.hpp>

template <typename T>
T randInt(T min, T max)
{
    thread_local std::random_device seeder;
    thread_local std::default_random_engine rng { seeder() };
    using DistType = std::uniform_int_distribution<T>;
    using ParamType = typename DistType::param_type;
    thread_local DistType dist;
    return dist(rng, ParamType(min, max));
}

template <typename Container>
auto randomChoice(const Container& container)
{
    const auto idx = randInt<size_t>(0, container.size() - 1);
    auto it = container.begin();
    std::advance(it, idx);
    return *it;
}

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