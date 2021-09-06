# Generated Cmake Pico project file

cmake_minimum_required(VERSION 3.13)

OPTION(TICVERSION_01 "Support TIC v01 (historique)")
OPTION(TICVERSION_02 "Support TIC v02 (standard)")

if(TICVERSION_01)
add_definitions(-DTICBAUDRATE=1200)
else()
add_definitions(-DTICBAUDRATE=9600)
endif()

set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)

if (NOT EXISTS $ENV{PICO_SDK_PATH})
message(FATAL_ERROR "Missing environment variable PICO_SDK_PATH")
endif ()

# Pull in Raspberry Pi Pico SDK (must be before project)
include($ENV{PICO_SDK_PATH}/pico_sdk_init.cmake)

project(picotic C CXX ASM)

add_subdirectory(tic2json)

# Initialise the Raspberry Pi Pico SDK
pico_sdk_init()

# Add executable. Default name is the project name, version 0.1

add_executable(picotic picotic.c )

pico_set_program_name(picotic "picotic")
pico_set_program_version(picotic "0.1")

# Add the standard library to the build
target_link_libraries(picotic pico_stdlib tic2json)

pico_add_extra_outputs(picotic)
