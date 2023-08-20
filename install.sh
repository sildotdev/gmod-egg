#!/bin/bash
# steamcmd Base Installation Script
#
# Server Files: /mnt/server

## just in case someone removed the defaults.
if [ "${STEAM_USER}" == "" ]; then
    echo -e "steam user is not set.\n"
    echo -e "Using anonymous user.\n"
    STEAM_USER=anonymous
    STEAM_PASS=""
    STEAM_AUTH=""
else
    echo -e "user set to ${STEAM_USER}"
fi

## download and install steamcmd
cd /tmp
mkdir -p /mnt/server/steamcmd
curl -sSL -o steamcmd.tar.gz https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz
tar -xzvf steamcmd.tar.gz -C /mnt/server/steamcmd
mkdir -p /mnt/server/steamapps # Fix steamcmd disk write error when this folder is missing
cd /mnt/server/steamcmd

# SteamCMD fails otherwise for some reason, even running as root.
# This is changed at the end of the install process anyways.
chown -R root:root /mnt
export HOME=/mnt/server

## install game using steamcmd
./steamcmd.sh +force_install_dir /mnt/server +login ${STEAM_USER} ${STEAM_PASS} ${STEAM_AUTH} $( [[ "${WINDOWS_INSTALL}" == "1" ]] && printf %s '+@sSteamCmdForcePlatformType windows' ) +app_update ${SRCDS_APPID} ${EXTRA_FLAGS} validate +quit ## other flags may be needed depending on install. looking at you cs 1.6

## set up 32 bit libraries
mkdir -p /mnt/server/.steam/sdk32
cp -v linux32/steamclient.so ../.steam/sdk32/steamclient.so

## set up 64 bit libraries
mkdir -p /mnt/server/.steam/sdk64
cp -v linux64/steamclient.so ../.steam/sdk64/steamclient.so

echo -e "Running Palomino install scripts..."
echo -e "Removing target folders..."

# Since this is a first install, remove the repo folders
rm -rf "$HOME/garrysmod/gamemodes/${FOLDER_GAMEMODE}"
rm -rf "$HOME/garrysmod/gamemodes/${FOLDER_BASE}"
rm -rf "$HOME/garrysmod/addons"
rm -rf "$HOME/garrysmod/lua/bin"
# rm -rf "$HOME/garrysmod/cfg"


# Checking and pulling/cloning/updating repositories
BRANCH=${BRANCH:-master} # Default branch if BRANCH variable is not defined

# Function to clone or update a repository
clone_or_update_repo() {
    local repo_url="$1"
    local target_folder="$HOME/$2"
    local target_notempty="$3"

    if [ -z "$repo_url" ]; then
        echo "Repo URL for $target_folder is not defined. Skipping."
        return
    fi

    # Using the GITHUB_TOKEN for authentication
    if [ -n "$GITHUB_TOKEN" ]; then
        repo_url="https://x-access-token:${GITHUB_TOKEN}@${repo_url#https://}"
    fi

    if [ "$target_notempty" == "true" ]; then
        if [ -d "$target_folder" ]; then
            # Temporarily move existing files
            mkdir -p "${target_folder}_backup"
            mv "$target_folder"/* "${target_folder}_backup/"
            git clone --branch "$BRANCH" "$repo_url" "$target_folder"
            # Copy files from backup to target only if they don't exist in target
            cp -n -r "${target_folder}_backup/"* "$target_folder/"
            rm -r "${target_folder}_backup"
        else
            git clone --branch "$BRANCH" "$repo_url" "$target_folder"
        fi
    else
        if [ -d "$target_folder/.git" ]; then
            echo "Updating repository in $target_folder"
            git -C "$target_folder" pull origin "$BRANCH"
        else
            echo "Cloning repository from $1 to $target_folder"
            git clone --branch "$BRANCH" "$repo_url" "$target_folder"
        fi
    fi

    # Remove the origin URL entirely
    # git -C "$target_folder" remote remove origin
}

# Delete addons folder if it's empty
if [ -d "$HOME/garrysmod/addons" ] && [ -z "$(ls -A $HOME/garrysmod/addons)" ]; then
    rm -r "$HOME/garrysmod/addons"
fi

# Clone or update repositories
clone_or_update_repo "$REPO_GAMEMODE" "garrysmod/gamemodes/${FOLDER_GAMEMODE}"
clone_or_update_repo "$REPO_BASE" "garrysmod/gamemodes/${FOLDER_BASE}"
clone_or_update_repo "$REPO_ADDONS" "garrysmod/addons"
clone_or_update_repo "$REPO_BIN" "garrysmod/lua/bin"
clone_or_update_repo "$REPO_CFG" "garrysmod/cfg" "true"