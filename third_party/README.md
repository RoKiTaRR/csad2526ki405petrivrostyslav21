Vendoring GoogleTest for offline builds

To build the unit tests without network access, place a copy of GoogleTest's
source under `third_party/googletest` so CMake can find it with `add_subdirectory`.

Two easy ways to populate this folder:

1) Clone the repository (recommended):
   git clone https://github.com/google/googletest.git third_party/googletest

2) Download the release ZIP and extract:
   - Download: https://github.com/google/googletest/releases
   - Extract the contents so that `third_party/googletest/CMakeLists.txt` exists

After that, run CMake as usual (no network required):

mkdir build
cd build
cmake -G "Visual Studio 17 2022" ..
cmake --build . --config Debug
ctest -C Debug -V

If you prefer automation, I can add a script to fetch the release ZIP into `third_party`.
