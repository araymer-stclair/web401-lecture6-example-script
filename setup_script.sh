#!/bin/bash

# Written by: Andrew Raymer
# Last Modified By: Andrew Raymer
VERSION="1.0.1"
# Date Created: Nov 28th, 2019
# Date Last Modified: June 14th, 2021

set -e # Exit script on first error (safety)
set -u # Exit script if unbound variable is called (safety)

readonly DOMAIN=".web401.lab"
readonly SCRIPT_NAME=$(basename "$0")
readonly LOG_PATH="/tmp/base_install.log"

# This checks the user id of who is running this script and exits if ran by root or using SUDO
if [ "$EUID" -eq 0 ]; then
  echo "Please do not run as root"
  exit 1
fi

# Logging function with a standardized output
function log {
    # this makes the path if it doesn't exist
    mkdir -p $LOG_PATH
    # $1 Log action
    local MSG="$1"
    # Gets the current user
    local CURRENT_USER=$(whoami)
    # Outputs to terminal
    echo -e "~*~*~*~*~*~*~* \t \t $1 \t \t *~*~*~*~*~*~*~"
    # Gets the timestamp right now
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    # Complicated way to print to afile
    printf '{"hostname":"%s","timestamp":"%s","user":"%s","message":"%s"}\n' "$(hostname)" "$timestamp" "$CURRENT_USER" "$MSG" >> "$LOG_PATH/$PROJECT_NAME-$SCRIPT_NAME.log"
}


function install_and_configure_zsh {
    log "Now setting up ZSH"
    sudo apt-get update
    sudo apt-get upgrade -y
    sudo apt-get dist-upgrade -y
    # installs ZSH
    sudo apt-get install -y zsh
    # This changes default shell to zsh
    chsh -s $(which zsh)
    # This fetches ohmyzsh
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    # This edits the theme from robbyrussell to mortalscumbag in the .zshrc file
    sed -i 's/robbyrussell/mortalscumbag/g' ~/.zshrc

    # These are adding extra settings I typically set in ZSH like multiple histories being commited at once
    echo "# History Stuff" >> ~/.zshrc
    echo "HISTFILE=~/.zhistory" >> ~/.zshrc
    echo "HISTSIZE=SAVEHIST=1000" >> ~/.zshrc
    echo "setopt incappendhistory" >> ~/.zshrc
    echo "setopt sharehistory" >> ~/.zshrc
    echo "setopt extendedhistory" >> ~/.zshrc
}

function docker_install {
    log "Installing docker by removing whatever was preinstalled"
    sudo apt-get update
    sudo apt-get remove -y docker
    # Install dependencies
    sudo apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg-agent \
        software-properties-common
    # Fetches the proper gpg key from docker
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo apt-key fingerprint 0EBFCD88
    # This adds the correct repository to our sources.list
    sudo add-apt-repository \
        "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) \
        stable"
    sudo apt-get update
    # Installs bas docker
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose
    # This adds the current user to the docker group so we don't need to use SUDO to interact with docker
    sudo usermod -aG docker $(whoami)
    # This fixes a socket permission issue
    sudo chmod 666 /var/run/docker.sock
    # This starts docker on system boot
    sudo systemctl start docker
    sudo systemctl enable docker
    # This is just giving us docker info and if for some reason the service isn't installed it will error out the script
    docker info
    docker ps
}

function portainer_setup {
    # This installs portainer which is super duper helpful with docker
    # Kinda like PHPMyAdmin but 100x less scary
    log "Now installing portainer"
    ### Images ###
    docker volume create portainer_data
    docker run -d -p 9000:9000 --name portainer --restart always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer
}

function set_hostname {
    log "Now setting hostname"
    # This is gives us a super fancy input box to put our name in
    NAME=$(whiptail --inputbox "what is the hostname for the server?" 8 78 --title "Server Hostname" 3>&1 1>&2 2>&3)
    # now we capture the previous exit code
    local exitstatus=$?
    if [ $exitstatus = 0 ]; then # If we didn't select cancel, we contiue
        echo "127.1.1.1 ${NAME}${DOMAIN}" | sudo tee -a /etc/hosts
        echo "${NAME}${DOMAIN}" | sudo tee /etc/hostname
        sudo hostname ${NAME}${DOMAIN}
        log "Hostname set to ${NAME}${DOMAIN}"
    else
        exit 4
    fi

}

function main {
    log "Starting script"
    sudo dpkg --configure -a
    sudo apt-get update
    # These install the basic tools I use
    sudo apt-get install -y htop vim nmon iptraf screen mdadm hdparm nload tmux
    sudo apt-get install -y curl git ncdu screen molly-guard vim smartmontools iotop iptraf
    sudo apt-get upgrade -y
    sudo apt-get dist-upgrade -y
    log "Finished installing base packages"
    # These next commands are just calling functions above to do their individual part
    set_hostname
    install_and_configure_zsh
    docker_install
    portainer_setup
    # This gives us a nice little message
    whiptail --title "Reboot" --msgbox "Hostname: $(hostname) \n The server will now reboot" 8 78
    local exitstatus=$?
    if [ $exitstatus = 0 ]; then # If we didn't select cancel, we contiue
        sudo reboot
    else
        exit 4
    fi
}

# we call main like any program should
main
