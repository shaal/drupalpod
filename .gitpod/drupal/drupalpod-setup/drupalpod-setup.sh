#!/usr/bin/env bash
set -eu -o pipefail

# Initialize all variables with null if they do not exist
: "${DEBUG_SCRIPT:=}"
: "${GITPOD_HEADLESS:=}"
: "${DP_INSTALL_PROFILE:=}"
: "${DP_EXTRA_DEVEL:=}"
: "${DP_EXTRA_ADMIN_TOOLBAR:=}"
: "${DP_PROJECT_TYPE:=}"
: "${DEVEL_NAME:=}"
: "${DEVEL_PACKAGE:=}"
: "${ADMIN_TOOLBAR_NAME:=}"
: "${ADMIN_TOOLBAR_PACKAGE:=}"
: "${COMPOSER_DRUPAL_LENIENT:=}"
: "${DP_CORE_VERSION:=}"
: "${DP_ISSUE_BRANCH:=}"
: "${DP_ISSUE_FORK:=}"
: "${DP_MODULE_VERSION:=}"
: "${DP_PATCH_FILE:=}"
: "${DP_INSTALL_LOCALE:=}"

# Assuming .sh files are in the same directory as this script
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

if [ -n "$DEBUG_SCRIPT" ] || [ -n "$GITPOD_HEADLESS" ]; then
    set -x
fi

time ddev start

# Measure the time it takes to go through the script
script_start_time=$(date +%s)

source "$DIR/setup_env.sh"
source "$DIR/install_modules.sh"
source "$DIR/drupal_version_specifics.sh"

# Skip setup if it already ran once and if no special setup is set by DrupalPod extension
if [ ! -f "${GITPOD_REPO_ROOT}"/.drupalpod_initiated ] && [ -n "$DP_PROJECT_TYPE" ]; then

    # Add git.drupal.org to known_hosts
    if [ -z "$GITPOD_HEADLESS" ]; then
        mkdir -p ~/.ssh
        host=git.drupal.org
        SSHKey=$(ssh-keyscan $host 2>/dev/null)
        echo "$SSHKey" >>~/.ssh/known_hosts
    fi

    # Ignore specific directories during Drupal core development
    cp "${GITPOD_REPO_ROOT}"/.gitpod/drupal/templates/git-exclude.template "${GITPOD_REPO_ROOT}"/.git/info/exclude

    # Get the required repo ready
    if [ "$DP_PROJECT_TYPE" == "project_core" ]; then
        # Find if requested core version is dev or stable
        d="$DP_CORE_VERSION"
        case $d in
        *.x)
            # If dev - use git checkout origin/*
            checkout_type=origin
            ;;
        *)
            # stable - use git checkout tags/*
            checkout_type=tags
            ;;
        esac

        # Use origin or tags in git checkout command
        cd "${GITPOD_REPO_ROOT}"/repos/drupal &&
            git fetch origin &&
            git fetch --all --tags &&
            git checkout "$checkout_type"/"$DP_CORE_VERSION"

        # Ignore specific directories during Drupal core development
        cp "${GITPOD_REPO_ROOT}"/.gitpod/drupal/templates/git-exclude.template "${GITPOD_REPO_ROOT}"/repos/drupal/.git/info/exclude
    else
        # If not core - clone selected project into /repos and remove drupal core
        rm -rf "${GITPOD_REPO_ROOT}"/repos/drupal
        if [ ! -d repos/"${DP_PROJECT_NAME}" ]; then
            mkdir -p repos
            cd "${GITPOD_REPO_ROOT}"/repos && time git clone https://git.drupalcode.org/project/"$DP_PROJECT_NAME".git
        fi
    fi

    # Set WORK_DIR
    export WORK_DIR="${GITPOD_REPO_ROOT}"/repos/$DP_PROJECT_NAME

    # Dynamically generate .gitmodules file
    cat <<GITMODULESEND >"${GITPOD_REPO_ROOT}"/.gitmodules
# This file was dynamically generated by a script
[submodule "$DP_PROJECT_NAME"]
    path = repos/$DP_PROJECT_NAME
    url = https://git.drupalcode.org/project/$DP_PROJECT_NAME.git
    ignore = dirty
GITMODULESEND

    # Checkout specific branch only if there's issue_branch
    if [ -n "$DP_ISSUE_BRANCH" ]; then
        # If branch already exist only run checkout,
        if cd "${WORK_DIR}" && git show-ref -q --heads "$DP_ISSUE_BRANCH"; then
            cd "${WORK_DIR}" && git checkout "$DP_ISSUE_BRANCH"
        else
            cd "${WORK_DIR}" && git remote add "$DP_ISSUE_FORK" https://git.drupalcode.org/issue/"$DP_ISSUE_FORK".git
            cd "${WORK_DIR}" && git fetch "$DP_ISSUE_FORK"
            cd "${WORK_DIR}" && git checkout -b "$DP_ISSUE_BRANCH" --track "$DP_ISSUE_FORK"/"$DP_ISSUE_BRANCH"
        fi
    elif [ -n "$DP_MODULE_VERSION" ] && [ "$DP_PROJECT_TYPE" != "project_core" ]; then
        cd "${WORK_DIR}" && git checkout "$DP_MODULE_VERSION"
    fi

    # Remove site that was installed before (for debugging)
    rm -rf "${GITPOD_REPO_ROOT}"/web
    rm -rf "${GITPOD_REPO_ROOT}"/vendor
    rm -f "${GITPOD_REPO_ROOT}"/composer.json
    rm -f "${GITPOD_REPO_ROOT}"/composer.lock

    source "$DIR/composer_setup.sh"

    if [ -n "$DP_PATCH_FILE" ]; then
        echo Applying selected patch "$DP_PATCH_FILE"
        cd "${WORK_DIR}" && curl "$DP_PATCH_FILE" | patch -p1
    fi

    # Prepare special setup to work with Drupal core
    if [ "$DP_PROJECT_TYPE" == "project_core" ]; then
        source "$DIR/drupal_setup_core.sh"
    # Prepare special setup to work with Drupal contrib
    elif [ -n "$DP_PROJECT_NAME" ]; then
        source "$DIR/drupal_setup_contrib.sh"
    fi

    time "${GITPOD_REPO_ROOT}"/.gitpod/drupal/install-essential-packages.sh
    # Configure phpcs for drupal.
    cd "$GITPOD_REPO_ROOT" &&
        vendor/bin/phpcs --config-set installed_paths vendor/drupal/coder/coder_sniffer

    # ddev config auto updates settings.php and generates settings.ddev.php
    ddev config --auto
    # New site install
    time ddev drush si -y --account-pass=admin --site-name="DrupalPod" "$DP_INSTALL_PROFILE" --locale="${DP_INSTALL_LOCALE:-en}"
    # Install devel and admin_toolbar modules
    if [ "$DP_EXTRA_DEVEL" != '1' ]; then
        DEVEL_NAME=
    fi
    if [ "$DP_EXTRA_ADMIN_TOOLBAR" != '1' ]; then
        ADMIN_TOOLBAR_NAME=
    fi

    # Enable extra modules
    cd "${GITPOD_REPO_ROOT}" &&
        ddev drush en -y \
            "$ADMIN_TOOLBAR_NAME" \
            "$DEVEL_NAME"

    # Enable the requested module
    if [ "$DP_PROJECT_TYPE" == "project_module" ]; then
        cd "${GITPOD_REPO_ROOT}" && ddev drush en -y "$DP_PROJECT_NAME"
    fi

    # Enable the requested theme
    if [ "$DP_PROJECT_TYPE" == "project_theme" ]; then
        cd "${GITPOD_REPO_ROOT}" && ddev drush then -y "$DP_PROJECT_NAME"
        cd "${GITPOD_REPO_ROOT}" && ddev drush config-set -y system.theme default "$DP_PROJECT_NAME"
    fi

    # Take a snapshot
    cd "${GITPOD_REPO_ROOT}" && ddev snapshot
    echo "Your database state was locally saved, you can revert to it by typing:"
    echo "ddev snapshot restore --latest"

    # Save a file to mark workspace already initiated
    touch "${GITPOD_REPO_ROOT}"/.drupalpod_initiated

    # Finish measuring script time
    script_end_time=$(date +%s)
    runtime=$((script_end_time - script_start_time))
    echo "drupalpod-setup.sh script ran for" $runtime "seconds"
else
    cd "${GITPOD_REPO_ROOT}" && ddev start
fi

# Open internal preview browser with current website
preview
