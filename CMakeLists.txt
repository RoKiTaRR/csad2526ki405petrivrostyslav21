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

# Library for math operations
add_library(math_operations STATIC ${CMAKE_SOURCE_DIR}/math_operations.cpp)
target_include_directories(math_operations PUBLIC ${CMAKE_SOURCE_DIR})

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

# --- GoogleTest and unit tests ---
# Prefer a vendored copy under third_party/googletest for offline builds.

# When building with MSVC, ensure GoogleTest uses the same C runtime as
# the rest of the project to avoid "RuntimeLibrary" (/MT vs /MD) linker errors.
if(MSVC)
	# Force googletest to use the shared CRT (/MD or /MDd depending on config)
	set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)
endif()

if(EXISTS ${CMAKE_SOURCE_DIR}/third_party/googletest/CMakeLists.txt)
	message(STATUS "Using vendored GoogleTest from third_party/googletest")
	add_subdirectory(${CMAKE_SOURCE_DIR}/third_party/googletest ${CMAKE_BINARY_DIR}/third_party/googletest)
else()
	include(FetchContent)
	FetchContent_Declare(
		googletest
		URL https://github.com/google/googletest/archive/refs/heads/main.zip
	)
	FetchContent_MakeAvailable(googletest)
endif()

enable_testing()

add_executable(unit_tests ${CMAKE_SOURCE_DIR}/tests/unit_tests.cpp)
target_link_libraries(unit_tests PRIVATE math_operations gtest_main)
target_include_directories(unit_tests PRIVATE ${CMAKE_SOURCE_DIR})

include(GoogleTest)
gtest_discover_tests(unit_tests)

# Sanity checks and helper target for CI logs
if(NOT EXISTS "${CMAKE_SOURCE_DIR}/tests/unit_tests.cpp")
	message(FATAL_ERROR "Unit test source file tests/unit_tests.cpp not found")
endif()

message(STATUS "unit_tests target defined: ${unit_tests}")

add_custom_target(print_test_info ALL
	COMMAND ${CMAKE_COMMAND} -E echo "Expected unit_tests binary (generator expression): $<TARGET_FILE:unit_tests>"
	COMMENT "Printing expected unit_tests path for CI logs"
)


