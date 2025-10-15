@echo off
REM Simple CI script for Windows (cmd.exe / batch)
REM Usage: run this from repository root or from CI runner working directory

setlocal enabledelayedexpansion

REM Remove any existing build directory and create a fresh one
if exist build (
    echo Removing existing build directory...
    rmdir /s /q build
    if %ERRORLEVEL% neq 0 (
        echo Failed to remove existing build directory.
        exit /b 1
    )
)

echo Creating build directory...
mkdir build
if %ERRORLEVEL% neq 0 (
    echo Failed to create build directory.
    exit /b 1
)

cd build

echo Configuring project with CMake...
cmake ..
if %ERRORLEVEL% neq 0 (
    echo CMake configuration failed.
    exit /b 1
)

echo Building project...
cmake --build .
if %ERRORLEVEL% neq 0 (
    echo Build failed.
    exit /b 1
)

echo Running tests (ctest)...
ctest --output-on-failure
if %ERRORLEVEL% neq 0 (
    echo Some tests failed.
    exit /b 1
)

echo CI script completed successfully.
exit /b 0
