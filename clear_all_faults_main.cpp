#include <sdbusplus/bus.hpp>

#include <iostream>

constexpr auto mapperService = "xyz.openbmc_project.ObjectMapper";
constexpr auto mapperObject = "/xyz/openbmc_project/object_mapper";
constexpr auto mapperInterface = "xyz.openbmc_project.ObjectMapper";
constexpr auto inventoryPath = "/xyz/openbmc_project/inventory";
constexpr auto inventoryManagerService =
    "xyz.openbmc_project.Inventory.Manager";
constexpr auto operationalStatusIntf =
    "xyz.openbmc_project.State.Decorator.OperationalStatus";
constexpr auto chassisService = "xyz.openbmc_project.State.Chassis";
constexpr auto chassis0Object = "/xyz/openbmc_project/state/chassis0";
constexpr auto chassisInterface = "xyz.openbmc_project.State.Chassis";
constexpr auto chassisPowerOn =
    "xyz.openbmc_project.State.Chassis.PowerState.On";

using GetSubTreePathsResponse = std::vector<std::string>;
using SetPropertyType = std::variant<bool>;
using GetPropertyType = std::variant<std::string>;

GetSubTreePathsResponse
    getObjectSubtreeForInterfaces(const std::string& root, const int32_t depth,
                                  const std::vector<std::string>& interfaces)
{
    auto bus = sdbusplus::bus::new_default();
    auto mapperCall = bus.new_method_call(mapperService, mapperObject,
                                          mapperInterface, "GetSubTreePaths");
    mapperCall.append(root);
    mapperCall.append(depth);
    mapperCall.append(interfaces);

    GetSubTreePathsResponse result = {};

    try
    {
        auto response = bus.call(mapperCall);
        response.read(result);
    }
    catch (const sdbusplus::exception_t& e)
    {
        std::cerr
            << "\n Error in reading Mapper GetSubTreePaths. Exit without clearing the fault leds";
    }

    return result;
}

void setDbusProperty(const std::string& service, const std::string& object,
                     const std::string& interface, const std::string& property,
                     const SetPropertyType& data)
{
    auto bus = sdbusplus::bus::new_default();
    auto properties =
        bus.new_method_call(service.c_str(), object.c_str(),
                            "org.freedesktop.DBus.Properties", "Set");

    properties.append(interface);
    properties.append(property);
    properties.append(data);

    try
    {
        auto result = bus.call(properties);
    }
    catch (const sdbusplus::exception_t& e)
    {
        std::cerr << e.what() << std::endl;
        std::cerr << "\nCall to Set " << property << " property failed for "
                  << object << std::endl;
    }
}

GetPropertyType getDbusProperty(const std::string& service,
                                const std::string& object,
                                const std::string& interface,
                                const std::string& property)
{
    auto bus = sdbusplus::bus::new_default();
    auto properties =
        bus.new_method_call(service.c_str(), object.c_str(),
                            "org.freedesktop.DBus.Properties", "Get");

    properties.append(interface);
    properties.append(property);
    GetPropertyType value;

    try
    {
        auto result = bus.call(properties);
        result.read(value);
    }
    catch (const sdbusplus::exception_t& e)
    {
        std::cerr << e.what() << std::endl;
        std::cerr << "Call to Get " << property << " property failed.";
    }
    return value;
}

int main()
{
    std::cout << "\n Starting to clear all fault leds on the system."
              << std::endl;

    // Check chassis power state
    GetPropertyType getDbusValue = getDbusProperty(
        chassisService, chassis0Object, chassisInterface, "CurrentPowerState");

    // If chassis is powered ON, exit without clearing all faults
    std::string chassisStatus;

    if (auto pVal = std::get_if<std::string>(&getDbusValue))
    {
        chassisStatus.assign(pVal->data(), pVal->size());
    }

    if (chassisStatus == chassisPowerOn)
    {
        std::cout << "\nCurrent chassis power state is " << chassisStatus
                  << ". Exit successfully without doing any fault LED reset."
                  << std::endl;
        return 0;
    }

    std::cout
        << "\nChassis power state is OFF. Continue to clear all fault leds on the system."
        << std::endl;

    std::vector<std::string> interfaces = {operationalStatusIntf};
    GetSubTreePathsResponse inventoryFRUPaths =
        getObjectSubtreeForInterfaces(inventoryPath, 0, interfaces);

    if (inventoryFRUPaths.size() == 0)
    {
        return -1;
    }

    for (auto fruPath : inventoryFRUPaths)
    {
        // Skip CPU Core object paths as it is hosted by PLDM service.
        if (fruPath.find("core") != std::string::npos)
        {
            std::cout << "\nSkipping the object " << fruPath
                      << " hosted by PLDM service." << std::endl;
            continue;
        }

        // Set Functional to true for other inventory paths
        std::cout << "\nSet functional to true for " << fruPath << std::endl;
        setDbusProperty(inventoryManagerService, fruPath, operationalStatusIntf,
                        "Functional", true);
    }

    std::cout << "\nFinished clearing all fault leds on the system."
              << std::endl;
    return 0;
}
