#!/bin/bash

#
# Copyright (c) 2023 Matthew Penner & sil.dev
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#

# Give everything time to initialize for preventing SteamCMD deadlock
sleep 1

# Default the TZ environment variable to UTC.
TZ=${TZ:-UTC}
export TZ

# Set environment variable that holds the Internal Docker IP
INTERNAL_IP=$(ip route get 1 | awk '{print $(NF-2);exit}')
export INTERNAL_IP

# Switch to the container's working directory
cd /home/container || exit 1

# Convert all of the "{{VARIABLE}}" parts of the command into the expected shell
# variable format of "${VARIABLE}" before evaluating the string and automatically
# replacing the values.
PARSED=$(echo "${STARTUP}" | sed -e 's/{{/${/g' -e 's/}}/}/g' | eval echo "$(cat -)")

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

## if auto_update is not set or to 1 update
if [ -z ${AUTO_UPDATE} ] || [ "${AUTO_UPDATE}" == "1" ]; then
    # Update Source Server
    if [ ! -z ${SRCDS_APPID} ]; then
        ./steamcmd/steamcmd.sh +force_install_dir /home/container +login ${STEAM_USER} ${STEAM_PASS} ${STEAM_AUTH} +app_update ${SRCDS_APPID} $( [[ -z ${SRCDS_BETAID} ]] || printf %s "-beta ${SRCDS_BETAID}" ) $( [[ -z ${SRCDS_BETAPASS} ]] || printf %s "-betapassword ${SRCDS_BETAPASS}" ) $( [[ -z ${HLDS_GAME} ]] || printf %s "+app_set_config 90 mod ${HLDS_GAME}" ) $( [[ -z ${VALIDATE} ]] || printf %s "validate" ) +quit
    else
        echo -e "No appid set."
    fi

else
    echo -e "Not updating game server as auto update was set to 0."
fi

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
            echo "Cloning repository from $repo_url to $target_folder"
            git clone --branch "$BRANCH" "$repo_url" "$target_folder"
        fi
    fi
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