#!/bin/bash

echo "export ARGOS_INSTALL_PATH=$HOME/swarm_robotics" >> ~/.bashrc
echo "export PKG_CONFIG_PATH=$HOME/swarm_robotics/argos3-dist/lib/pkgconfig" >> ~/.bashrc
echo "export ARGOS_PLUGIN_PATH=$HOME/swarm_robotics/argos3-dist/lib/argos3" >> ~/.bashrc
echo "export LD_LIBRARY_PATH=$HOME/swarm_robotics/argos3-dist/lib/argos3:$LD_LIBRARY_PATH" >> ~/.bashrc
echo "export PATH=$HOME/swarm_robotics/argos3-dist/bin/:$PATH" >> ~/.bashrc

export ARGOS_INSTALL_PATH=$HOME/swarm_robotics >> ~/.bashrc
export PKG_CONFIG_PATH=$HOME/swarm_robotics/argos3-dist/lib/pkgconfig >> ~/.bashrc
export ARGOS_PLUGIN_PATH=$HOME/swarm_robotics/argos3-dist/lib/argos3 >> ~/.bashrc
export LD_LIBRARY_PATH=$HOME/swarm_robotics/argos3-dist/lib/argos3:$LD_LIBRARY_PATH >> ~/.bashrc
export PATH=$HOME/swarm_robotics/argos3-dist/bin/:$PATH >> ~/.bashrc

cd $HOME/swarm_robotics/argos3/build

cmake -DCMAKE_INSTALL_PREFIX=$HOME/swarm_robotics/argos3-dist -DCMAKE_BUILD_TYPE=Release -DARGOS_INSTALL_LDSOCONF=OFF -DARGOS_DOCUMENTATION=OFF ../src

make -j4
make install


