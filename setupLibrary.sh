#!/bin/bash

# Add the new user account
# Arguments:
#   Account Username
#   Account Password
function addUserAccount() {
    local username=${1}
    local password=${2}

    sudo adduser --disabled-password "${username}"
    echo "${username}:${password}" | sudo chpasswd
    sudo usermod -aG sudo "${username}"
}

# Add the local machine public SSH Key for the new user account
# Arguments:
#   Account Username
#   Public SSH Key
function addSSHKey() {
    local username=${1}
    local sshKey=${2}

    execAsUser "${username}" "mkdir -p ~/.ssh; chmod 700 ~/.ssh; touch ~/.ssh/authorized_keys"
    execAsUser "${username}" "echo \"${sshKey}\" | sudo tee -a ~/.ssh/authorized_keys"
    execAsUser "${username}" "chmod 600 ~/.ssh/authorized_keys"
}

# Execute a command as a certain user
# Arguments:
#   Account Username
#   Command to be executed
function execAsUser() {
    local username=${1}
    local exec_command=${2}

    sudo -u "${username}" -H bash -c "${exec_command}"
}

# Modify the sshd_config file
function changeSSHConfig() {
    sudo sed -re 's/^(\#?)(PasswordAuthentication)([[:space:]]+)yes/\2\3no/' -i."$(echo 'old')" /etc/ssh/sshd_config
    sudo sed -re 's/^(\#?)(PermitRootLogin)([[:space:]]+)(.*)/PermitRootLogin no/' -i /etc/ssh/sshd_config
}

# Setup Git
# Arguments:
#   Email Address
#   Full Name
function setGit() {
    local gitEmail=${1}
    local gitName=${2}

    cd /home/"${username}"
    execAsUser "${username}" "git config --global user.email \"${gitEmail}\""
    execAsUser "${username}" "git config --global user.name \"${gitName}\""
    cd "${current_dir}"
}

# Setup the Uncomplicated Firewall
function setupUfw() {
    sudo apt-get --assume-yes install ufw
    sudo ufw allow OpenSSH
    yes y | sudo ufw enable
}

function setupZsh() {
    sudo apt-get --assume-yes install zsh git-core curl
    execAsUser "${username}" "sh -c \"$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)\""
    execAsUser "${username}" "chsh -s $(which zsh)"
}

# Set the machine's timezone
# Arguments:
#   tz data timezone
function setTimezone() {
    local timezone=${1}
    echo "${1}" | sudo tee /etc/timezone
    sudo ln -fs "/usr/share/zoneinfo/${timezone}" /etc/localtime # https://bugs.launchpad.net/ubuntu/+source/tzdata/+bug/1554806
    sudo dpkg-reconfigure -f noninteractive tzdata
}

# Configure Network Time Protocol
function configureNTP() {
    sudo apt-get --assume-yes install ntp
}

# Disables the sudo password prompt for a user account by editing /etc/sudoers
# Arguments:
#   Account username
function disableSudoPassword() {
    local username="${1}"

    sudo cp /etc/sudoers /etc/sudoers.bak
    sudo bash -c "echo '${1} ALL=(ALL) NOPASSWD: ALL' | (EDITOR='tee -a' visudo)"
}

# Reverts the original /etc/sudoers file before this script is ran
function revertSudoers() {
    sudo cp /etc/sudoers.bak /etc/sudoers
    sudo rm -rf /etc/sudoers.bak
}
