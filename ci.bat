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

REM --- Diagnostics ---
echo ================= Diagnostics ================
echo OS: %OS%
echo Current directory: %CD%
echo CMAKE_GENERATOR: %CMAKE_GENERATOR%
echo CMAKE_CONFIG: %CMAKE_CONFIG%
echo PATH (first 200 chars): %PATH:~0,200%
echo -- cmake --version --
cmake --version 2>nul || echo cmake: not found
echo -- tool presence checks --
where cl >nul 2>&1
if %ERRORLEVEL%==0 (echo cl: found) else (echo cl: not found)
where msbuild >nul 2>&1
if %ERRORLEVEL%==0 (echo msbuild: found) else (echo msbuild: not found)
where nmake >nul 2>&1
if %ERRORLEVEL%==0 (echo nmake: found) else (echo nmake: not found)
where ninja >nul 2>&1
if %ERRORLEVEL%==0 (echo ninja: found) else (echo ninja: not found)
echo =================================================

echo Configuring project with CMake...
REM Use a label-based flow to avoid nested-paren parsing issues.
if defined CMAKE_GENERATOR goto :use_generator
if "%OS%"=="Windows_NT" goto :check_windows_tools
goto :cmake_default

:check_windows_tools
echo No CMAKE_GENERATOR specified. Detecting installed Windows build tools in PATH...
where cl >nul 2>&1 && goto :cmake_default
where msbuild >nul 2>&1 && goto :cmake_default
where nmake >nul 2>&1 && goto :cmake_default
where ninja >nul 2>&1 && goto :cmake_default

echo No tool found in PATH. Attempting to locate Visual Studio via vswhere...
where vswhere >nul 2>&1
if %ERRORLEVEL% neq 0 goto :no_toolchain
for /f "usebackq delims=" %%I in (`vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do set "VS_INSTALL=%%I"
if defined VS_INSTALL (
    echo Found Visual Studio at %VS_INSTALL% - calling vcvars64.bat to set environment
    if exist "%VS_INSTALL%\VC\Auxiliary\Build\vcvars64.bat" (
        call "%VS_INSTALL%\VC\Auxiliary\Build\vcvars64.bat"
        goto :cmake_default
    ) else (
        echo vcvars64.bat not found under %VS_INSTALL%
        goto :no_toolchain
    )
) else (
    goto :no_toolchain
)

:no_toolchain
echo ERROR: No MSVC or other build toolchain detected. Open the "x64 Native Tools Command Prompt for VS" or install Visual Studio Build Tools, or set CMAKE_GENERATOR to a valid generator and re-run.
exit /b 1

:use_generator
echo Using CMake generator: %CMAKE_GENERATOR%
cmake -G "%CMAKE_GENERATOR%" ..
if %ERRORLEVEL% neq 0 (
    echo CMake configuration failed with generator %CMAKE_GENERATOR%.
    exit /b 1
)
goto :build_step

:cmake_default
echo Running CMake configure (default)...
cmake ..
if %ERRORLEVEL% neq 0 (
    echo CMake configuration failed.
    exit /b 1
)

echo Building project...
REM Allow specifying configuration (Debug/Release) via CMAKE_CONFIG env var for multi-config generators
if defined CMAKE_CONFIG (
    cmake --build . --config %CMAKE_CONFIG%
else (
    cmake --build .
)
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
