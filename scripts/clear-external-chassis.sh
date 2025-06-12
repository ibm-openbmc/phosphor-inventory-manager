#!/bin/sh

# Remove if external chassis persist path(s) hosted under phosphor-inventory-manager
external_chassis_pim_path="/var/lib/phosphor-inventory-manager/xyz/openbmc_project/inventory/system/chassis"

# Find and delete directories matching pattern
for dir in "${external_chassis_pim_path}"[0-9]*; do
    if [ -d "$dir" ]; then
        echo "Removing external chassis directory: $dir"
        rm -rf "$dir"
    fi
done
