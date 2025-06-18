#include <filesystem>
#include <iostream>
#include <regex>

int main()
{
    try
    {
        std::string pimPath =
            "/var/lib/phosphor-inventory-manager/xyz/openbmc_project/inventory/system";
        std::regex chassisFolderName(R"(chassis[0-9]+)");

        for (const auto& entry : std::filesystem::directory_iterator(pimPath))
        {
            if (entry.is_directory())
            {
                std::string folderName = entry.path().filename().string();

                if (std::regex_match(folderName, chassisFolderName))
                {
                    std::filesystem::path folderPath = entry.path();
                    std::cout << "clear-external-chassis, Removing Directory: "
                              << folderPath << std::endl;
                    std::error_code ec;
                    std::filesystem::remove_all(folderPath, ec);

                    if (ec)
                    {
                        std::cerr << "Error removing " << folderPath << ": "
                                  << ec.message() << std::endl;
                    }
                }
            }
        }
    }
    catch (std::exception& ex)
    {
        std::cerr
            << "Exception occured while checking & cleaning any exetrnal chassis: "
            << ex.what() << std::endl;
    }

    return 0;
}
