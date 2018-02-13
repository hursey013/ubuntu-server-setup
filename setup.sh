#!/bin/bash

set -e

function getCurrentDir() {
    local current_dir="${BASH_SOURCE%/*}"
    if [[ ! -d "${current_dir}" ]]; then current_dir="$PWD"; fi
    echo "${current_dir}"
}

function includeDependencies() {
    source "${current_dir}/setupLibrary.sh"
}

current_dir=$(getCurrentDir)
includeDependencies
output_file="output.log"

function main() {
    read -p "Enter username of the new user account (Default is 'hursey013'):" username
    if [ -z "${username}" ]; then
        username="hursey013"
    fi

    promptForPassword

    # Run setup functions
    trap cleanup EXIT SIGHUP SIGINT SIGTERM

    addUserAccount "${username}" "${password}"

    read -rp $'Paste in the public SSH key for the new user:\n' sshKey

    echo 'Running setup script...'
    logTimestamp "${output_file}"

    exec 3>&1 >>"${output_file}" 2>&1
    disableSudoPassword "${username}"
    addSSHKey "${username}" "${sshKey}"
    changeSSHConfig

    setupGit

    # Retrieve new lists of packages
    sudo apt-get update

    echo "Installing Uncomplicated Firewall (UFW)... " >&3
    setupUfw

    echo "Installing Oh My Zsh... " >&3
    setupZsh

    setupTimezone

    echo "Installing Network Time Protocol... " >&3
    configureNTP

    sudo service ssh restart

    cleanup

    echo "Setup Done! Log file is located at ${output_file}" >&3
}

function cleanup() {
    if [[ -f "/etc/sudoers.bak" ]]; then
        revertSudoers
    fi
}

function logTimestamp() {
    local filename=${1}
    {
        echo "==================="
        echo "Log generated on $(date)"
        echo "==================="
    } >>"${filename}" 2>&1
}

function setupGit() {
    echo -ne "Enter email address for Git config (Default is 'hursey013@protonmail.com'):" >&3
    read gitEmail
    if [ -z "${gitEmail}" ]; then
        gitEmail="hursey013@protonmail.com"
    fi

    echo -ne "Enter full name for Git config (Default is 'Brian Hurst'):" >&3
    read gitName
    if [ -z "${gitName}" ]; then
        gitName="Brian Hurst"
    fi

    setGit "${gitEmail}" "${gitName}"
}

function setupTimezone() {
    echo -ne "Enter the timezone for the server (Default is 'America/New_York'):" >&3
    read -r timezone
    if [ -z "${timezone}" ]; then
        timezone="America/New_York"
    fi
    setTimezone "${timezone}"
    echo "Timezone is set to $(cat /etc/timezone)" >&3
}

# Keep prompting for the password and password confirmation
function promptForPassword() {
   PASSWORDS_MATCH=0
   while [ "${PASSWORDS_MATCH}" -eq "0" ]; do
       read -s -rp "Enter new UNIX password:" password
       printf "\n"
       read -s -rp "Retype new UNIX password:" password_confirmation
       printf "\n"

       if [[ "${password}" != "${password_confirmation}" ]]; then
           echo "Passwords do not match! Please try again."
       else
           PASSWORDS_MATCH=1
       fi
   done
}

main
