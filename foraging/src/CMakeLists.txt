cmake_minimum_required(VERSION 2.6)
project(loop_function)

if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Release)
endif()

set(CMAKE_CXX_FLAGS "-Wall -Wextra")
set(CMAKE_CXX_FLAGS_RELEASE "-O3")

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}")
if(DEFINED ENV{ARGOS_INSTALL_PATH})
  list(APPEND CMAKE_PREFIX_PATH "$ENV{ARGOS_INSTALL_PATH}/argos3-dist")
  list(APPEND CMAKE_MODULE_PATH "$ENV{ARGOS_INSTALL_PATH}/argos3-dist/share/argos3/cmake")
endif()

# Check for Lua and add include path
find_package(Lua53 REQUIRED)
include_directories(${LUA_INCLUDE_DIR})

# Check for ARGoS3
find_package(ARGoS REQUIRED COMPONENTS entities footbot media)

# Add ARGoS paths
include_directories(${ARGOS_INCLUDE_DIRS})
link_directories(${ARGOS_LIBRARY_DIR})

# Create the loop function library
add_library(loop_function SHARED loop_function.h loop_function.cpp)
target_link_libraries(loop_function
  argos3core_simulator
  ${LUA_LIBRARIES}
  ${ARGOS_LDFLAGS}
  argos3plugin_simulator_entities
  argos3plugin_simulator_footbot
  argos3plugin_simulator_media)
