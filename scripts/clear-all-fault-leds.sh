#!/bin/sh

# This shell script sets the group D-Bus objects in
# /xyz/openbmc_project/State/Decorator/OperationalStatusManager
# to true or false.
set -e
usage()
{
    echo "clear-all-fault-leds.sh [true/false]"
    echo "Example: clear-all-fault-leds.sh true"
    echo "Example: clear-all-fault-leds.sh false bmc_booted power_on _fault"
    return 0;
}

# We need at least 1 argument
if [ $# -lt 1 ]; then
    echo "At least ONE argument needed";
    usage;
    exit 1;
fi

# User passed in argument [true/false]
action=$1

# If it is not "true" or "false", exit
if [ "$action" != "true" ] && [ "$action" != "false" ]; then
    echo "Bad argument $action passed";
    usage;
    exit 1;
fi

# Skip running this script if the chassis is powered ON.
current_chassis_status=$(busctl get-property xyz.openbmc_project.State.Chassis /xyz/openbmc_project/state/chassis0 xyz.openbmc_project.State.Chassis CurrentPowerState | cut -d" " -f2)

if [ "${current_chassis_status}" = "\"xyz.openbmc_project.State.Chassis.PowerState.On\"" ]; then
    echo "Current chassis power state is , $current_chassis_status . Exit clear-all-fault-leds.sh script successfully without doing any fault LED reset."
    exit 0
fi

# Get the excluded groups, where $@ is all the agruments passed
index=2;
excluded_groups=""

for arg in "$@"
do
    if [ "$arg" = "$action" ]
    then
        # Must be true/false
        continue
        #This allows accepting and using own positional parameters either via
        #argument passing or via envrironment file.
    elif [ $index -eq $# ]
    then
        excluded_groups="${excluded_groups}$arg"
    else
        excluded_groups="${excluded_groups}$arg|"
    fi
    index=$((index+1))
done

# Now, set the OperationalStatus Functional to what has been requested
# We filter out the valid object path using a mapper call
# If we find a unitX/coreX under then, we don't consider those because
# they are not mapped to LED's. Applicable for CPUs and DIMMs
if [ ${#excluded_groups} -eq 0 ]
then
    busctl call xyz.openbmc_project.ObjectMapper /xyz/openbmc_project/object_mapper xyz.openbmc_project.ObjectMapper \
        GetSubTreePaths sias "/xyz/openbmc_project/inventory" 0 1 "xyz.openbmc_project.State.Decorator.OperationalStatus" \
        | sed  's/ /\n/g' | tail -n+3 | awk -F "\"" '{print $2}' | while read -r line
    do
        #skip All empty lines
	 if [ -z "$line" ];then
	     continue;
	 fi

        #object paths for core implemets interface for operational status but is hosted by PLDM service
        # not by inventory manager. Hence we need to skip call to those paths.
        echo "$line" | grep "core\|powersupply\|unit\|connector\|chasis1" >/dev/null
        rc=$?
        if [ $rc -eq 0 ]; then
            continue;
        fi
        busctl set-property xyz.openbmc_project.Inventory.Manager \
	     "$line" xyz.openbmc_project.State.Decorator.OperationalStatus Functional b "$action" || echo "Exception for Dbus path: $line";

	  #skip paths which have no fault LED
        echo "$line" | grep "pcie_card\|usb\|drive\|ethernet\|fan0_\|fan1_\|fan2_\|fan3_\|fan4_\|fan5_\|rdx\|cables\|displayport\|pcieslot12" >/dev/null
        rc=$?
        if [ $rc -eq 0 ]; then
            continue;
        fi

	  # Get the Fault LED associations
	  busctl call xyz.openbmc_project.ObjectMapper "$line/fault_identifying" \
	  org.freedesktop.DBus.Properties Get ss "xyz.openbmc_project.Association" \
	  "endpoints" | sed  's/ /\n/g' | tail -n+3 | awk -F "\"" '{print $2}' | while read -r line2
	  do
	      # Skip All empty lines
	      if [ -z "$line2" ];then
	        continue;
	      fi

	      # Set the Asserted State property
	      busctl set-property xyz.openbmc_project.LED.GroupManager \
		  "$line2" xyz.openbmc_project.Led.Group Asserted b false || echo "Exception thrown for Dbus path: $line2";
   	  done
    done
else
    busctl call xyz.openbmc_project.ObjectMapper /xyz/openbmc_project/object_mapper xyz.openbmc_project.ObjectMapper \
        GetSubTreePaths sias "/xyz/openbmc_project/inventory" 0 1 "xyz.openbmc_project.State.Decorator.OperationalStatus" \
        | sed  's/ /\n/g' | tail -n+3 | grep -Ev "$excluded_groups" | awk -F "\"" '{print $2}' | while read -r line
    do
      # Skip All empty lines
      if [ -z "$line" ];then
        continue;
      fi

        #object paths for core implemets interface for operational status but is hosted by PLDM service
        # not by inventory manager. Hence we need to skip call to those paths.
        echo "$line" | grep "core\|powersupply\|unit\|connector\|chassis1" >/dev/null
        rc=$?
        if [ $rc -eq 0 ]; then
            continue;
        fi
        busctl set-property xyz.openbmc_project.Inventory.Manager \
	"$line" xyz.openbmc_project.State.Decorator.OperationalStatus Functional b "$action" || echo "Exception for Dbus path(else): $line";

	 # Skip paths which have no fault LED
        echo "$line" | grep "pcie_card\|usb\|drive\|ethernet\|fan0_\|fan1_\|fan2_\|fan3_\|fan4_\|fan5_\|rdx\|cables\|displayport\|pcieslot12" >/dev/null
        rc=$?
        if [ $rc -eq 0 ]; then
            continue;
        fi

      # Get the Fault LED associations
      busctl call xyz.openbmc_project.ObjectMapper "$line/fault_identifying" \
      org.freedesktop.DBus.Properties Get ss "xyz.openbmc_project.Association" \
      "endpoints" | sed  's/ /\n/g' | tail -n+3 | awk -F "\"" '{print $2}' | while read -r line2
      do
        # Skip All empty lines
        if [ -z "$line2" ];then
            continue;
        fi

        # Set the Asserted State property
        busctl set-property xyz.openbmc_project.LED.GroupManager \
        "$line2" xyz.openbmc_project.Led.Group Asserted b false || "Exception thrown for Dbus path(else): $line2";
      done
    done
fi

# Return Success
exit 0
