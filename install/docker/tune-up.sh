#!/bin/bash

#---------------------------------------------------------------------------------
# Tunning up docker
#---------------------------------------------------------------------------------

# Swappiness
echo "vm.swappiness=10" | sudo tee /etc/sysctl.d/99-swappiness.conf
sudo sysctl --system

# Cache pressure
echo "vm.vfs_cache_pressure=50" | sudo tee /etc/sysctl.d/99-cache-pressure.conf
sudo sysctl --system

# Ajustes de I/O
echo "vm.dirty_ratio=15" | sudo tee /etc/sysctl.d/99-dirty-ratio.conf
echo "vm.dirty_background_ratio=5" | sudo tee -a /etc/sysctl.d/99-dirty-ratio.conf
sudo sysctl --system


exit 0
