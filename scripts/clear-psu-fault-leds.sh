#!/bin/sh

# This shell script clears enclosure fault LED and PSU fault LED.

# Skip running the script if chassis is powered ON.
current_chassis_status=$(busctl get-property xyz.openbmc_project.State.Chassis /xyz/openbmc_project/state/chassis0 xyz.openbmc_project.State.Chassis CurrentPowerState | cut -d" " -f2)

if [ "${current_chassis_status}" = "\"xyz.openbmc_project.State.Chassis.PowerState.On\"" ]; then
    echo "Current chassis power state is , $current_chassis_status . Exit clear-psu-fault-leds.sh script successfully without resetting PSU and enclosure fault LEDs."
    exit 0
fi

# Explicitly set Asserted to false for enclosure_fault, SAI, enclosure identify LED group object as these are not to be persisted.
busctl set-property xyz.openbmc_project.LED.GroupManager "/xyz/openbmc_project/led/groups/enclosure_fault" xyz.openbmc_project.Led.Group Asserted b false;
busctl set-property xyz.openbmc_project.LED.GroupManager "/xyz/openbmc_project/led/groups/platform_system_attention_indicator" xyz.openbmc_project.Led.Group Asserted b false;
busctl set-property xyz.openbmc_project.LED.GroupManager "/xyz/openbmc_project/led/groups/partition_system_attention_indicator" xyz.openbmc_project.Led.Group Asserted b false;
busctl set-property xyz.openbmc_project.LED.GroupManager "/xyz/openbmc_project/led/groups/enclosure_identify" xyz.openbmc_project.Led.Group Asserted b false;

# Get powersupply objects
busctl call xyz.openbmc_project.ObjectMapper /xyz/openbmc_project/object_mapper xyz.openbmc_project.ObjectMapper GetSubTreePaths sias "/xyz/openbmc_project/inventory" 0 1 "xyz.openbmc_project.Inventory.Item.PowerSupply" | sed  's/ /\n/g' | tail -n+3 | awk -F "\"" '{print $2}' | while read -r line
do
    # Clear fault LEDs for all power supply objects by setting its Functional to true.
    busctl set-property xyz.openbmc_project.Inventory.Manager "$line" xyz.openbmc_project.State.Decorator.OperationalStatus Functional b true;
done

exit 0
