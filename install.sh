#!/bin/bash
# Copyright (c) Microsoft Corporation. All Rights Reserved.
# Licensed under the MIT license. See LICENSE file on the project webpage for details.

#todo: consider moving some functions
#   into separate *.sh files that can
#   be referenced by the terminal
#   for example, transform yml -> json

set -xe

# --- Parameters Start --- #
    # Most BRANCHes
    export OPENEDX_RELEASE="open-release/ficus.master" # or "open-release/eucalyptus.3" # or named-release/dogwood.rc , etc.
    # No need to specify org, folder, or repository url

    # edx-platform BRANCH override
    export EDX_RELEASE=
    EDX_ORG=edx # or Microsoft
    EDX_FOLDER="edx-platform"
    EDX_REPO=

    # edx/configuration BRANCH override
    export CONFIGURATION_VERSION=
    CONFIGURATION_ORG=edx # or Microsoft
    CONFIGURATION_FOLDER=configuration # or edx-configuration
    CONFIGURATION_REPO=

    # other edx/configuration BRANCH override (only used for ansible-bootstrap.sh and requirements.txt)
    BOOTSTRAP_CONFIGURATION_VERSION=
    BOOTSTRAP_CONFIGURATION_ORG=edx # or Microsoft
    BOOTSTRAP_CONFIGURATION_FOLDER=configuration # or edx-configuration
    BOOTSTRAP_CONFIGURATION_REPO=

    # Misc
    STACK_TYPE=full # or dev
# --- Parameters End --- #

# --- General variables Start --- #
    EDX_APP=/edx/app
    ANSIBLE_ROOT=$EDX_APP/edx_ansible
    TEMP_DIR=/var/tmp
    CURRENT_SCRIPT_NAME=`basename "$0"`
    CURRENT_SCRIPT_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    RUNTIME_YAML="extra-vars.yml"
    VAGRANT=vagrant
# --- General variables End --- #

# --- Process params Start --- #
help()
{
    echo
    echo "This script $CURRENT_SCRIPT_NAME will install open edx"
    echo
    echo "No params are required. Sensible defaults are applied."
    echo
    echo "Options:"
    echo "  -b|--branches           Branch for          most repos. Defaults to open-release/eucalyptus.3"
    echo
    echo "  -p|--platform-branch    Branch for          edx-platform"
    echo "  -q|--platform-org       Organization for    edx-platform. edx or Microsoft"
    echo
    echo "  -c|--config-branch      Branch for          configuration"
    echo "  -d|--config-org         Organization for    configuraiton. edx or Microsoft"
    echo "  -e|--config-folder      Folder for          configuration. configuration or edx-configuration"
    echo
    echo "  -t|--bootstrap-branch   Branch for          bootstrap. Installs ansible and python requirements"
    echo "  -u|--bootstrap-org      Organization for    bootstrap. edx or Microsoft. Installs ansible and python requirements"
    echo "  -v|--bootstrap-folder   Folder for          bootstrap. configuration or edx-configuration. Installs ansible and python requirements"
    echo
    echo "  -s|--stack              full or dev.        Default is full which will install fullstack. dev will install devstack."
    echo
    exit 2
}
parse_args()
{
    while [[ "$#" -gt 0 ]]
        do

        echo "Option $1 set with value $2"

        case "$1" in
            -b|--branches)
                export OPENEDX_RELEASE=$2
                shift
                ;;
            -p|--platform-branch)
                export EDX_RELEASE=$2
                shift
                ;;
            -q|--platform-org)
                EDX_ORG=$2
                shift
                ;;
            -c|--config-branch)
                export CONFIGURATION_VERSION=$2
                shift
                ;;
            -d|--config-org)
                CONFIGURATION_ORG=$2
                shift
                ;;
            -e|--config-folder)
                CONFIGURATION_FOLDER=$2
                shift
                ;;
            -t|--bootstrap-branch)
                BOOTSTRAP_CONFIGURATION_VERSION=$2
                shift
                ;;
            -u|--bootstrap-org)
                BOOTSTRAP_CONFIGURATION_ORG=$2
                shift
                ;;
            -v|--bootstrap-folder)
                BOOTSTRAP_CONFIGURATION_FOLDER=$2
                shift
                ;;
            -s|--stack)
                STACK_TYPE=$2
                shift
                ;;
            -h|--help) # Helpful hints
                help
                ;;
            *) # unknown option
                log "ERROR. Option -${BOLD}$2${NORM} not allowed."
                help
                ;;
        esac

        shift
    done
}
set_variables()
{
    # Branches
    if [ -z $OPENEDX_RELEASE ]; then
        echo " -b|--branches needs to be valid"
        echo "OPENEDX_RELEASE is currently $OPENEDX_RELEASE"
        exit 4
    fi
    if [ -z $EDX_RELEASE ]; then
        export EDX_RELEASE=$OPENEDX_RELEASE
    fi
    if [ -z $CONFIGURATION_VERSION ]; then
        export CONFIGURATION_VERSION=$OPENEDX_RELEASE
    fi
    if [ -z $BOOTSTRAP_CONFIGURATION_VERSION ]; then
        BOOTSTRAP_CONFIGURATION_VERSION=$OPENEDX_RELEASE
    fi

    # Repo URL
    EDX_REPO=`get_repo_url "$EDX_ORG" "$EDX_FOLDER"`
    CONFIGURATION_REPO=`get_repo_url "$CONFIGURATION_ORG" "$CONFIGURATION_FOLDER"`
    BOOTSTRAP_CONFIGURATION_REPO=`get_repo_url "$BOOTSTRAP_CONFIGURATION_ORG" "$BOOTSTRAP_CONFIGURATION_FOLDER"`
}
# --- Process params End --- #

# --- Reusable utility functions Start --- #
verify_file_exists()
{
    FILE_PATH=$1
    if [ ! -f $FILE_PATH ]; then
        echo "No file exists at path: $FILE_PATH"
        echo "Exiting script"
        exit 3
    fi
}
get_repo_url()
{
    echo "https://github.com/$1/$2.git"
}
# --- Reusable utility functions End --- #

# --- Preconditions Start --- #
verify_org_type() {
    # Restrict to supported values.
    if [ $1 != "edx" ] && [ $1 != "Microsoft" ]; then
        echo "Please specify edx or Microsoft (with $2 argument)"
        echo "Exiting script"
        exit 1
    fi
}
verify_conf_folder() {
    # Restrict to supported values.
    if [ $1 != "configuration" ] && [ $1 != "edx-configuration" ]; then
        echo "Please specify configuration or edx-configuration (with $2 argument)"
        echo "Exiting script"
        exit 1
    fi
}
verify_stack_type() {
    # Restrict to supported values.
    if [ $STACK_TYPE != "dev" ] && [ $STACK_TYPE != "full" ]; then
        echo "Please specify fullstack or devstack (with -s|--stack argument full or dev)"
        echo "Exiting script"
        exit 1
    fi
}
verify_bootstrap_enlistment()
{
    pushd $TEMP_DIR

    if [ ! -d $BOOTSTRAP_CONFIGURATION_FOLDER ]; then
        git clone $BOOTSTRAP_CONFIGURATION_REPO
    fi

    pushd $BOOTSTRAP_CONFIGURATION_FOLDER
    # todo: we should eventually merge all upstream branches into our fork.
    git checkout $BOOTSTRAP_CONFIGURATION_VERSION
    popd

    popd
}
update_packages()
{
    for (( b=1; b<=3; b++ ))
    do
        echo
        echo "$1 packages..."
        echo
        sudo apt-get $1 -y -qq --fix-missing
        if [ $? -eq 0 ]; then
            break
        else
            echo "$1 failed"

            if [ $b -eq 3 ]; then
                echo "Exiting script"
                exit 6
            fi
        fi
    done
}
verify_git()
{
    if ! type git >/dev/null 2>&1 ; then
        echo "Installing git..."
        update_packages "install git --force-yes"
    fi
    #todo: ensure version 2+. note: ubuntu < 16 will require
    #   apt-add-repository ppa:git-core/ppa and an apt update
}
verify_ssh()
{
    if [ ! -f "/etc/ssh/sshd_config" ]; then
        echo "installing ssh..."
        update_packages "install ssh --force-yes"
    fi
}
verify_curl()
{
    if ! type curl >/dev/null 2>&1 ; then
        echo "Installing curl..."
        update_packages "install curl --force-yes"
    fi
}
verify_browsers()
{
    # Dev stack installs chrome and firefox and can fail if the browsers already exist.
    if [ $STACK_TYPE == "dev" ]; then
        if type firefox >/dev/null 2>&1 ; then
            echo "Un-installing firefox...The proper version will be installed later"
            update_packages "purge firefox"
        fi

        if type google-chrome-stable >/dev/null 2>&1 ; then
            echo "Un-installing chrome...The proper version will be installed later"
            update_packages "purge google-chrome-stable"
        fi

        # Package that comes with firefox.
        update_packages "remove hunspell-en-us"
    fi
}
verify_vagrant_user()
{
    # Dev stack expects vagrant user
    if [ $STACK_TYPE == "dev" ]; then
        vHome="/home/$VAGRANT"
        if [ ! -d $vHome ]; then
            useradd -d $vHome -m $VAGRANT
            echo -e "$VAGRANT\n$VAGRANT\n" | passwd $VAGRANT
        fi
    fi
}
# --- Preconditions End --- #

# --- Core functionality Start --- #
install_ansible()
{
    # Only try if we haven't already fully succeeded already.
    # We can use the next functions result as test for now.
    if [ ! -f $CURRENT_SCRIPT_PATH/$RUNTIME_YAML ]; then
        pushd $TEMP_DIR/$BOOTSTRAP_CONFIGURATION_FOLDER/util/install

        INSTALL_SCRIPT="ansible-bootstrap.sh"

        verify_file_exists $INSTALL_SCRIPT

        # Note: The following two hotfixes have already been applied to recent versions
        #   of ansible-bootstrap.sh. Also, these fixes will no-opt (do nothing) if the
        #   fixes already exist the bootstrap config branch.

        # 1. Fix intermittent networking bug by pre-pending protocol
        sed -i -e 's/="pgp.mit/="hkp:\/\/pgp.mit/g' $INSTALL_SCRIPT

        # 2. Fix possible network settings issue by appending port
        sed -i -e 's/mit.edu"/mit.edu:80"/g' $INSTALL_SCRIPT

        bash $INSTALL_SCRIPT

        popd
    fi
}
write_settings_to_file()
{
    pushd $CURRENT_SCRIPT_PATH

    bash -c "cat <<EOF >$RUNTIME_YAML
---
edx_platform_repo: \"$EDX_REPO\"
edx_platform_version: \"$EDX_RELEASE\"
certs_version: \"$OPENEDX_RELEASE\"
forum_version: \"$OPENEDX_RELEASE\"
xqueue_version: \"$OPENEDX_RELEASE\"
configuration_version: \"$OPENEDX_RELEASE\"
PROGRAMS_VERSION: \"$OPENEDX_RELEASE\"
demo_version: \"$OPENEDX_RELEASE\"
ECOMMERCE_VERSION: \"$OPENEDX_RELEASE\"
ECOMMERCE_WORKER_VERSION: \"$OPENEDX_RELEASE\"
edx_ansible_source_repo: \"$CONFIGURATION_REPO\"
COMMON_SSH_PASSWORD_AUTH: \"yes\"
EDXAPP_SITE_NAME: \"$HOSTNAME\"
EOF"
    cp *.yml $ANSIBLE_ROOT
    chown edx-ansible:edx-ansible $ANSIBLE_ROOT/*.yml

    popd
}
install_python_libraries_and_run_edx_playbook()
{
    #todo: switch this to non-bootstrap config that ansible-bootstrap brings along
    pushd $TEMP_DIR/$BOOTSTRAP_CONFIGURATION_FOLDER
    verify_file_exists "./requirements.txt"
    pip install -r requirements.txt

    pushd playbooks

    playBook="$VAGRANT-${STACK_TYPE}stack"
    verify_file_exists ${playBook}.yml
    verify_file_exists "$ANSIBLE_ROOT/server-vars.yml"
    verify_file_exists "$ANSIBLE_ROOT/$RUNTIME_YAML"

    # Disable "immediate exit" on errors to allow for retry
    set +e

    for (( a=1; a<=13; a++ ))
    do
        echo
        echo "STARTING - ${STACK_TYPE}stack - attempt number: $a"
        echo

        params="${playBook}.yml -e@$ANSIBLE_ROOT/server-vars.yml -e@$ANSIBLE_ROOT/$RUNTIME_YAML "
        ansible-playbook -i localhost, -c local $params

        if [ $? -eq 0 ]; then
            echo "SUCCEEDED - ${STACK_TYPE}stack - attempt number: $a !"
            break
        else
            echo "FAILED - ${STACK_TYPE}stack - attempt number: $a"

            # Try removing the often problematic mysql ppa before updating.
            rm /etc/apt/sources.list.d/repo_mysql*

            update_packages "update"
            update_packages "install -f"
            update_packages "upgrade -f"

            if [ $a -eq 13 ]; then
                echo "Installation Failed. Exiting script"
                exit 5
            fi
        fi
    done

    # Enable "immediate exit" on error
    set -e

    popd
    popd
}

# --- Core functionality End --- #

# --- Execution Start --- #

parse_args $@

set_variables

verify_org_type "$EDX_ORG" "-q|--platform-org"
verify_org_type "$CONFIGURATION_ORG" "-d|--config-org"
verify_org_type "$BOOTSTRAP_CONFIGURATION_ORG" "-u|--bootstrap-org"

verify_conf_folder "$CONFIGURATION_FOLDER" "-e|--config-folder"
verify_conf_folder "$BOOTSTRAP_CONFIGURATION_FOLDER" "-v|--bootstrap-folder"

verify_stack_type

# Disable "immediate exit" on errors to allow for retry
set +e
# Try removing the often problematic mysql ppa before updating.
rm /etc/apt/sources.list.d/repo_mysql*

update_packages "update"
update_packages "install -f"
update_packages "upgrade -f"
# Enable "immediate exit" on error
set -e

verify_git

verify_ssh

verify_curl

verify_browsers

verify_vagrant_user

verify_bootstrap_enlistment

# NOTE: keep "set -xe" and these functions
#   adjacent. install_ansible uses the
#   existence of extra-vars to determine if
#   install_ansible has succeeded already.
install_ansible
write_settings_to_file

install_python_libraries_and_run_edx_playbook

echo
echo "Complete success!"
echo
# --- Execution End --- #

/edx/bin/supervisorctl status
