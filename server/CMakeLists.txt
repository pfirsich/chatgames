cmake_minimum_required(VERSION 3.7)

project(chatgames-server)

set(CMAKE_CXX_STANDARD 17)
# Seriously CMake, Boost, whoever is responsible for this, go fuck yourself.
# I am done noodling around and I refuse to solve this the proper way, whatever it may be, in case it actually exists.
# I just shit that flag in here and that is it.
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -pthread")

find_package(spdlog REQUIRED)
find_package(Boost REQUIRED COMPONENTS system coroutine)
# I guess I should use target_include_directories, but that just doesn't work, so fuck you again CMake
include_directories(server PUBLIC deps/tomlplusplus/include)

set(SERVER_SRC
  Config.cpp
  Server.cpp
  LobbySession.cpp
  serialization.cpp
  words.cpp
  server.main.cpp
)
list(TRANSFORM SERVER_SRC PREPEND src/)

add_executable(server ${SERVER_SRC})

# no -pedantic because of fmt!
target_compile_options(server PRIVATE -Wall -Wextra)

target_link_libraries(server spdlog::spdlog)
target_link_libraries(server Boost::system Boost::boost)

add_executable(testclient src/client.main.cpp)
target_compile_options(testclient PRIVATE -Wall -Wextra)
target_link_libraries(testclient Boost::system Boost::boost)