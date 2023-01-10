#!/bin/bash

# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

set -e # exit on error
trap 'catch $? $LINENO' EXIT

catch() {
    if [ "$1" != "0" ]; then
        # we trapped an error - write some reporting output
        error "Exit code $1 was returned from line #$2 !!!"
    fi
}

trace() {
    echo -e "\n>>> $@ ...\n"
}

error() {
    echo "Error: $@" 1>&2
}


mkdir -p "$(dirname "$ACTION_OUTPUT")"  # ensure the log folder exists
touch $ACTION_OUTPUT                    # ensure the log file exists

exec 1>$ACTION_OUTPUT                   # forward stdout to log file
exec 2>&1                               # redirect stderr to stdout


# if this image is used as a base for a custom image, the user can
# add files to the /entrypoint.d directory to be executed at startup
find "/entrypoint.d/" -follow -type f -iname "*.sh" -print | sort -n | while read -r f; do
    # execute each shell script found enabled for execution
    if [ -x "$f" ]; then trace "Running '$f'"; "$f"; fi
done


trace "Connecting to Azure"

while true; do
    # managed identity isn't available immediately
    # we need to do retry after a short nap
    az login --identity --allow-no-subscriptions --only-show-errors --output none && {
        echo "done"
        break
    } || {
        echo "Waiting for Managed Identity to come available..."
        sleep 5
    }
done


if [[ ! -z "$ENVIRONMENT_SUBSCRIPTION_ID" ]]; then
    trace "Selecting Azure Subscription"
    az account set --subscription $ENVIRONMENT_SUBSCRIPTION_ID
    echo "$(az account show -o json | jq --raw-output '"\(.name) (\(.id))"')"
fi

if [[ ! -z "$CATALOG_ITEM" ]]; then
    trace "Selecting Catalog Item directory"
    cd $(echo "$CATALOG_ITEM" | sed 's/^file:\/\///') && echo $PWD
    trace "Making scripts in Catalog Item directory executable"
    find ./ -type f -iname "*.sh" -exec chmod +x {} \;  # make scripts executable
fi


# the script to execute is defined by the following options
# (the first option matching an executable script file wins)
#
# Option 1: a script path is provided as docker CMD command
#
# Option 2: a script file following the pattern [ACTION_NAME].sh exists in the
#           current working directory (catalog item directory)
#
# Option 3: a script file following the pattern [ACTION_NAME].sh exists in the
#           /actions.d directory (actions script directory)

script="$@"                                                                     # the script to execute is the CMD command

if [[ -z "$script" ]]; then                                                     # no script provided as CMD command
    script="$(find $PWD -maxdepth 1 -iname "$ACTION_NAME.sh")"                  # search in current working directory...
    if [[ -z "$script" ]]; then                                                 # no script found in current working directory
        script="$(find /actions.d -maxdepth 1 -iname "$ACTION_NAME.sh")"        # search in actions script directory...
    fi
    if [[ -z "$script" ]]; then                                                 # no script found in actions script directory
        error "Action $ACTION_NAME is not supported." && exit 1                 # exit with error
    fi
fi

if [[ -f "$script" && -x "$script" ]]; then                                     # script file exists and is executable
    # lets execute the task script - isolate execution in sub shell
    trace "Executing script ($script)"; ( exec "$script"; exit $? ) || exit $?  # exit with script exit code
elif [[ -f "$script" ]]; then                                                   # script file exists but is not executable
    error "Script '$script' is not marked as executable" && exit 1              # exit with error
else                                                                            # script file does not exist
    error "Script '$script' does not exist" && exit 1
fi
