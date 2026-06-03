cmake_minimum_required(VERSION 3.10.2)

project(security_core VERSION 1.0.0 LANGUAGES CXX)

add_library(security_core SHARED
    ../src/native_security.cpp
)

# Link standard Android logging library
target_link_libraries(security_core
    log
)
