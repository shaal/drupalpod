#!/usr/bin/env bash
if [ -n "$DEBUG_DRUPALPOD" ] || [ -n "$GITPOD_HEADLESS" ]; then
    set -x
fi

# Set the default setup during prebuild process
if [ -n "$GITPOD_HEADLESS" ]; then
    DP_INSTALL_PROFILE='demo_umami'
    DP_EXTRA_DEVEL=1
    DP_EXTRA_ADMIN_TOOLBAR=1
    DP_PROJECT_TYPE='default_drupalpod'
fi

# TODO: once Drupalpod extension supports additional modules - remove these 2 lines
DP_EXTRA_DEVEL=1
DP_EXTRA_ADMIN_TOOLBAR=1

# Check if additional modules should be installed
if [ -n "$DP_EXTRA_DEVEL" ]; then
    DEVEL_NAME="devel"
    DEVEL_PACKAGE="drupal/devel"
    EXTRA_MODULES=1
fi

if [ -n "$DP_EXTRA_ADMIN_TOOLBAR" ]; then
    ADMIN_TOOLBAR_NAME="admin_toolbar_tools"
    ADMIN_TOOLBAR_PACKAGE="drupal/admin_toolbar"
    EXTRA_MODULES=1
fi

# Skip setup if it already ran once and if no special setup is set by DrupalPod extension
if [ ! -f /workspace/drupalpod_initiated.status ] && [ -n "$DP_PROJECT_TYPE" ]; then

    # Add git.drupal.org to known_hosts
    if [ -z "$GITPOD_HEADLESS" ]; then
        mkdir -p ~/.ssh
        host=git.drupal.org
        SSHKey=$(ssh-keyscan $host 2> /dev/null)
        echo "$SSHKey" >> ~/.ssh/known_hosts
    fi

    mkdir -p "${GITPOD_REPO_ROOT}"/repos

    # Clone selected project into /repos
    if [ -n "$DP_PROJECT_NAME" ]; then
        cd "${GITPOD_REPO_ROOT}"/repos && time git clone https://git.drupalcode.org/project/"$DP_PROJECT_NAME"
        WORK_DIR="${GITPOD_REPO_ROOT}"/repos/$DP_PROJECT_NAME
    fi

    # Dynamically generate .gitmodules file
cat <<GITMODULESEND > "${GITPOD_REPO_ROOT}"/.gitmodules
# This file was dynamically generated by a script
[submodule "$DP_PROJECT_NAME"]
    path = repos/$DP_PROJECT_NAME
    url = https://git.drupalcode.org/project/$DP_PROJECT_NAME.git
    ignore = dirty
GITMODULESEND

    # Ignore specific directories during Drupal core development
    cp "${GITPOD_REPO_ROOT}"/.gitpod/drupal/git-exclude.template "${GITPOD_REPO_ROOT}"/.git/info/exclude
    cp "${GITPOD_REPO_ROOT}"/.gitpod/drupal/git-exclude.template "${GITPOD_REPO_ROOT}"/repos/drupal/.git/info/exclude

    # Checkout specific branch only if there's issue_fork
    if [ -n "$DP_ISSUE_FORK" ]; then
        # If branch already exist only run checkout,
        if cd "${WORK_DIR}" && git show-ref -q --heads "$DP_ISSUE_BRANCH"; then
            cd "${WORK_DIR}" && git checkout "$DP_ISSUE_BRANCH"
        else
            cd "${WORK_DIR}" && git remote add "$DP_ISSUE_FORK" https://git.drupalcode.org/issue/"$DP_ISSUE_FORK".git
            cd "${WORK_DIR}" && git fetch "$DP_ISSUE_FORK"
            cd "${WORK_DIR}" && git checkout -b "$DP_ISSUE_BRANCH" --track "$DP_ISSUE_FORK"/"$DP_ISSUE_BRANCH"
        fi
    elif [ -n "$DP_MODULE_VERSION" ]; then
        cd "${WORK_DIR}" && git checkout "$DP_MODULE_VERSION"
    fi

    # Restoring requested environment + profile installation
    if [ -n "$DP_CORE_VERSION" ]; then
        # Remove default site that was installed during prebuild
        rm -rf "${GITPOD_REPO_ROOT}"/web
        rm -rf "${GITPOD_REPO_ROOT}"/vendor
        rm -f "${GITPOD_REPO_ROOT}"/composer.json
        rm -f "${GITPOD_REPO_ROOT}"/composer.lock

         # Copying environment of requested Drupal version
        cd "$GITPOD_REPO_ROOT" && cp -rT ../ready-made-envs/"$DP_CORE_VERSION"-dev/. .
    fi

    # Check if snapshot can be used (when no full reinstall needed)
    # Run it before any other ddev command (to avoid ddev restart)
    if [ -z "$DP_REINSTALL" ]; then
        # Retrieve pre-made snapshot
        cd "$GITPOD_REPO_ROOT" && time ddev snapshot restore "$DP_INSTALL_PROFILE"
    fi

    if [ -n "$DP_PATCH_FILE" ]; then
        echo Applying selected patch "$DP_PATCH_FILE"
        cd "${WORK_DIR}" && curl "$DP_PATCH_FILE" | patch -p1
    fi

    # Add project source code as symlink (to repos/name_of_project)
    # double quotes explained - https://stackoverflow.com/a/1250279/5754049
    if [ -n "$DP_PROJECT_NAME" ]; then
        cd "${GITPOD_REPO_ROOT}" && \
        ddev composer config \
        repositories.drupal-core1 \
        ' '"'"' {"type": "path", "url": "'"repos/$DP_PROJECT_NAME"'", "options": {"symlink": true}} '"'"' '
    fi

    if [ "$DP_PROJECT_TYPE" == "project_core" ]; then
        # Add a special path when working on core contributions
        # (Without it, /web/modules/contrib is not found by website)
        cd "${GITPOD_REPO_ROOT}" && \
        ddev composer config \
        repositories.drupal-core2 \
        ' '"'"' {"type": "path", "url": "'"repos/drupal/core"'"} '"'"' '

        # Removing the conflict part of composer
        echo "$(cat composer.json | jq 'del(.conflict)' --indent 4)" > composer.json
    fi

    # Prepare special setup to work with Drupal core
    if [ "$DP_PROJECT_TYPE" == "project_core" ]; then

        # repos/drupal/vendor -> ../../vendor
        if [ ! -L "$GITPOD_REPO_ROOT"/repos/drupal/vendor ]; then
            cd "$GITPOD_REPO_ROOT"/repos/drupal && \
            ln -s ../../vendor .
        fi

        # Create folders for running tests
        mkdir -p "$GITPOD_REPO_ROOT"/web/sites/simpletest
        mkdir -p "$GITPOD_REPO_ROOT"/web/sites/simpletest/browser_output

        # Symlink the simpletest folder into the Drupal core git repo.
        # repos/drupal/sites/simpletest -> ../../../web/sites/simpletest
        if [ ! -L "$GITPOD_REPO_ROOT"/repos/drupal/sites/simpletest ]; then
            cd "$GITPOD_REPO_ROOT"/repos/drupal/sites && \
            ln -s ../../../web/sites/simpletest .
        fi
    fi

    if [ -n "$DP_PROJECT_NAME" ]; then
        # Add the project to composer (it will get the version according to the branch under `/repo/name_of_project`)
        cd "${GITPOD_REPO_ROOT}" && time ddev composer require drupal/"$DP_PROJECT_NAME"
    fi

    # Patch index.php for Drupal core development (must run after composer require above)
    if [ "$DP_PROJECT_TYPE" == "project_core" ]; then

        # Update composer.lock to allow composer's symlink of repos/drupal/core
        cd "${GITPOD_REPO_ROOT}" && time ddev composer require drupal/core

        # Set special setup for composer for working on Drupal core
        cd "$GITPOD_REPO_ROOT"/web && \
        patch -p1 < "$GITPOD_REPO_ROOT"/src/composer-drupal-core-setup/scaffold-patch-index-and-update-php.patch
    fi

    # Configure phpcs for drupal.
    cd "$GITPOD_REPO_ROOT" && \
    vendor/bin/phpcs --config-set installed_paths vendor/drupal/coder/coder_sniffer

    if [ -n "$DP_INSTALL_PROFILE" ]; then

        # Check if a full site install is required
        if [ -n "$DP_REINSTALL" ]; then
            # New site install
            ddev drush si -y --account-pass=admin --site-name="DrupalPod" "$DP_INSTALL_PROFILE"

            # Enabale extra modules
            if [ -n "$EXTRA_MODULES" ]; then
                cd "${GITPOD_REPO_ROOT}" && \
                ddev drush en -y \
                "$DEVEL_NAME" \
                "$ADMIN_TOOLBAR_NAME"
            fi

            # Enable Claro as default admin theme
            cd "${GITPOD_REPO_ROOT}" && ddev drush then claro
            cd "${GITPOD_REPO_ROOT}" && ddev drush config-set -y system.theme admin claro

            # Enable Olivero as default theme
            if [ -n "$DP_OLIVERO" ]; then
                cd "${GITPOD_REPO_ROOT}" && \
                ddev drush then olivero && \
                ddev drush config-set -y system.theme default olivero
            fi
        fi

        # Enable the module or theme
        if [ "$DP_PROJECT_TYPE" == "project_module" ]; then
            cd "${GITPOD_REPO_ROOT}" && ddev drush en -y "$DP_PROJECT_NAME"
        elif [ "$DP_PROJECT_TYPE" == "project_theme" ]; then
            cd "${GITPOD_REPO_ROOT}" && ddev drush then -y "$DP_PROJECT_NAME"
            cd "${GITPOD_REPO_ROOT}" && ddev drush config-set -y system.theme default "$DP_PROJECT_NAME"
        fi

        # When working on core, we should the database of profile installed, to
        # catch up with latest version since Drupalpod's Prebuild ran
        if [ "$DP_PROJECT_TYPE" == "project_core" ]; then
            cd "${GITPOD_REPO_ROOT}" && time ddev drush updb -y
        fi
    else
        # Wipe database from prebuild's Umami site install
        cd "${GITPOD_REPO_ROOT}" && ddev drush sql-drop -y
    fi

    # Take a snapshot
    cd "${GITPOD_REPO_ROOT}" && ddev snapshot

    # Save a file to mark workspace already initiated
    touch /workspace/drupalpod_initiated.status
else
    cd "${GITPOD_REPO_ROOT}" && ddev start
fi

preview
