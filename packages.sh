#!/usr/bin/env bash
# List all packages manually installed through nala

nala list -i -N | grep -P '^[^├└]' | awk '{print }' 

# if needed for input of `sudo nala install -y $(packages.sh)` use the following line
# nala list -i -N | grep -P '^[^├└]' | awk '{print }' | tr '\n' ' '
