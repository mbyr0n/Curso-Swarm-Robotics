#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARGOS_SRC="$ROOT/argos3/src"
ARGOS_BUILD="$ROOT/argos3/build"
ARGOS_DIST="$ROOT/argos3-dist"

# Ubuntu 24.04: qt5-default no longer exists. Install qtbase5-dev instead:
# sudo apt install build-essential cmake libfreeimage-dev libfreeimageplus-dev qtbase5-dev qtbase5-dev-tools freeglut3-dev libxi-dev libxmu-dev liblua5.3-dev lua5.3 doxygen graphviz libgraphviz-dev asciidoc libgl1-mesa-dev libglu1-mesa-dev

mkdir -p "$ARGOS_BUILD"

cmake \
  -S "$ARGOS_SRC" \
  -B "$ARGOS_BUILD" \
  -DCMAKE_INSTALL_PREFIX="$ARGOS_DIST" \
  -DCMAKE_BUILD_TYPE=Release \
  -DARGOS_INSTALL_LDSOCONF=OFF \
  -DARGOS_DOCUMENTATION=OFF

cmake --build "$ARGOS_BUILD" --parallel "$(nproc)"
cmake --install "$ARGOS_BUILD"

ENV_BLOCK="# ARGoS3 local installation
export ARGOS_INSTALL_PATH=$ROOT
export CMAKE_PREFIX_PATH=$ARGOS_DIST\${CMAKE_PREFIX_PATH:+:\$CMAKE_PREFIX_PATH}
export ARGOS_PLUGIN_PATH=$ARGOS_DIST/lib/argos3\${ARGOS_PLUGIN_PATH:+:\$ARGOS_PLUGIN_PATH}
export LD_LIBRARY_PATH=$ARGOS_DIST/lib:$ARGOS_DIST/lib/argos3\${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}
export PATH=$ARGOS_DIST/bin\${PATH:+:\$PATH}
"

if ! grep -q "# ARGoS3 local installation" "$HOME/.bashrc"; then
  printf "\n%s\n" "$ENV_BLOCK" >> "$HOME/.bashrc"
fi

export ARGOS_INSTALL_PATH="$ROOT"
export CMAKE_PREFIX_PATH="$ARGOS_DIST${CMAKE_PREFIX_PATH:+:$CMAKE_PREFIX_PATH}"
export ARGOS_PLUGIN_PATH="$ARGOS_DIST/lib/argos3${ARGOS_PLUGIN_PATH:+:$ARGOS_PLUGIN_PATH}"
export LD_LIBRARY_PATH="$ARGOS_DIST/lib:$ARGOS_DIST/lib/argos3${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export PATH="$ARGOS_DIST/bin${PATH:+:$PATH}"
