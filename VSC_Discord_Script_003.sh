#!/bin/bash

# KDS 08052024
# Written with assistance from ChatGPT

# Function to check if the script is running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "This script needs to be run as root. Please use 'sudo' to execute it."
        exit 1
    fi
}

# Check if running as root
check_root

echo "Checking if Discord is installed..."

if which discord &> /dev/null; then
    echo "Discord is installed, checking version..."
    installed_version=$(dpkg -s discord 2>/dev/null | grep '^Version:' | awk '{print $2}')

    # Download latest Discord package
    echo "Downloading the latest Discord package..."
    if ! curl -Lo "/tmp/latest_discord.deb" 'https://discord.com/api/download?platform=linux'; then
        echo "Failed to download the latest Discord package"
        exit 1
    fi

    # Fetch version from downloaded package
    echo "Fetching version from the downloaded package..."
    fetched_version=$(dpkg-deb -I /tmp/latest_discord.deb 2>/dev/null | grep 'Version:' | awk '{print $2}')

    echo "Installed version: $installed_version"
    echo "Fetched version: $fetched_version"

    # Version comparison function
    compare_versions() {
        local ver1=(${1//./ })
        local ver2=(${2//./ })
        local length1=${#ver1[@]}
        local length2=${#ver2[@]}

        # Pad the shorter version with zeros
        [ "$length1" -lt "$length2" ] && ver1+=($(for i in $(seq $length1 $length2); do echo 0; done))
        [ "$length2" -lt "$length1" ] && ver2+=($(for i in $(seq $length2 $length1); do echo 0; done))

        for i in "${!ver1[@]}"; do
            if [[ ${ver2[i]} -gt ${ver1[i]} ]]; then
                return 0 # ver2 is greater
            elif [[ ${ver2[i]} -lt ${ver1[i]} ]]; then
                return 1 # ver1 is greater
            fi
        done

        return 2 # versions are equal
    }

    # Compare versions
    compare_versions "$installed_version" "$fetched_version"
    result=$?

    if [ $result -eq 0 ]; then
        echo "Fetched version $fetched_version is greater than installed version $installed_version, checking if Discord is running..."
        if pgrep -x "discord" > /dev/null; then
            echo "Discord is running, killing..."
            pkill -x "discord"
        else
            echo "Discord is not running, updating..."
        fi

        echo "Updating Discord..."
        if ! dpkg -i "/tmp/latest_discord.deb"; then
            echo "Failed to install Discord"
            rm -rf "/tmp/latest_discord.deb"
            exit 1
        fi
        echo "Discord has been updated."
        rm -rf "/tmp/latest_discord.deb"
        exit 0
    elif [ $result -eq 1 ]; then
        echo "Installed version $installed_version is greater than fetched version $fetched_version, maybe check your sources? Cleaning up and exiting..."
        rm -rf "/tmp/latest_discord.deb"
        exit 1
    elif [ $result -eq 2 ]; then
        echo "Fetched version $fetched_version is equal to installed version $installed_version, cleaning up and exiting..."
        rm -rf "/tmp/latest_discord.deb"
        exit 0
    fi
else
    echo "Discord is not installed."

    # Prompt the user for installation
    read -p "Do you want to install Discord? (Y/N): " response
    response=$(echo "$response" | tr '[:lower:]' '[:upper:]')

    if [ "$response" = "Y" ]; then
        echo "Installing latest Discord..."
        if ! curl -Lo "/tmp/latest_discord.deb" 'https://discord.com/api/download?platform=linux'; then
            echo "Failed to download the latest Discord package"
            exit 1
        fi
        if ! dpkg -i "/tmp/latest_discord.deb"; then
            echo "Failed to install Discord"
            rm -rf "/tmp/latest_discord.deb"
            exit 1
        fi
        rm -rf "/tmp/latest_discord.deb"
        exit 0
    elif [ "$response" = "N" ]; then
        echo "Exiting..."
        exit 0
    else
        echo "Invalid response. Please enter Y or N."
        exit 1
    fi
fi
