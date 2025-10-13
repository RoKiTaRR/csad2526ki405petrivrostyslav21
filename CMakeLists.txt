cmake_minimum_required(VERSION 3.12)

project(csad2526ki405petrivrostyslav21 VERSION 1.0 LANGUAGES CXX)

# Use a reasonable default for the C++ standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Put compiled binaries in the build directory's bin folder by default
if(NOT CMAKE_RUNTIME_OUTPUT_DIRECTORY)
	set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
endif()

# Sources
set(SRC_FILES
	${CMAKE_SOURCE_DIR}/main.cpp
)

add_executable(${PROJECT_NAME} ${SRC_FILES})

# Compiler warnings (best-effort)
if(MSVC)
	target_compile_options(${PROJECT_NAME} PRIVATE /W4 /permissive-)
else()
	target_compile_options(${PROJECT_NAME} PRIVATE -Wall -Wextra -Wpedantic)
endif()

install(TARGETS ${PROJECT_NAME}
	RUNTIME DESTINATION bin
)

message(STATUS "Project: ${PROJECT_NAME} v${PROJECT_VERSION}")
message(STATUS "C++ standard: ${CMAKE_CXX_STANDARD}")

