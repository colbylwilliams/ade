#!/bin/bash

# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

DIR=$(dirname "$0")
. $DIR/_common.sh

trace() {
    echo -e "\n>>> $@ ...\n"
}

deploymentName=$(date +"%Y-%m-%d-%H%M%S%z")
deploymentOutput=""

if [ ! -z "$(find . -name '*.bicep' -print -quit)" ] ; then
    trace "Transpiling BICEP template"
    find . -name "*.bicep" -exec echo "- {}" \; -exec az bicep build --files {} \;
fi

# format the action parameters as arm parameters
deploymentParameters=$(echo "$ACTION_PARAMETERS" | jq --compact-output '{ "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#", "contentVersion": "1.0.0.0", "parameters": (to_entries | if length == 0 then {} else (map( { (.key): { "value": .value } } ) | add) end) }' )


# This is a bit of a hack, but we can resolve linked templates with
# relativePaths before executing submitting the deployment to ARM by:
#
#   1. Use `bicep decompile` to transpile the the ARM template into
#      bicep modules. During this process bicep will resolve the linked
#      templates locally and convert them each into bicep modules.
#
#   2. Then run `bicep build` to transpile those bicep modules back
#      into ARM. This will output a new, single ARM template with the
#      linked templates embedded as nested templates

hasRelativePath=$( cat $CATALOG_ITEM_TEMPLATE | jq '.. | objects | select(has("templateLink") and (.templateLink | has("relativePath"))) | any' )

if [ "$relativePath" = true ] ; then

    trace "Resolving linked  ARM templates"

    bicepTemplate="${CATALOG_ITEM_TEMPLATE/.json/.bicep}"
    generatedTemplate="${CATALOG_ITEM_TEMPLATE/.json/.generated.json}"

    az bicep decompile --file $CATALOG_ITEM_TEMPLATE
    az bicep build --file $bicepTemplate --outfile $generatedTemplate

    deploymentTemplate=$generatedTemplate

else

    deploymentTemplate=$CATALOG_ITEM_TEMPLATE

fi


trace "Deploying ARM template"

if [ -z "$ENVIRONMENT_RESOURCE_GROUP_NAME" ]; then

    deploymentOutput=$(az deployment sub create --subscription $ENVIRONMENT_SUBSCRIPTION_ID \
                                                --location "$ENVIRONMENT_LOCATION" \
                                                --name "$deploymentName" \
                                                --no-prompt true --no-wait \
                                                --template-file "$deploymentTemplate" \
                                                --parameters "$deploymentParameters" \
                                                "${deploymentParameters_adds[@]}" 2>&1)

    if [ $? -eq 0 ]; then # deployment successfully created
        while true; do

            sleep 1

            ProvisioningState=$(az deployment sub show --name "$deploymentName" --query "properties.provisioningState" -o tsv)
            ProvisioningDetails=$(az deployment operation sub list --name "$deploymentName")

            trackDeployment "$ProvisioningDetails"

            if [[ "CANCELED|FAILED|SUCCEEDED" == *"${ProvisioningState^^}"* ]]; then

                echo -e "\nDeployment $deploymentName: $ProvisioningState"

                if [[ "CANCELED|FAILED" == *"${ProvisioningState^^}"* ]]; then
                    exit 1
                else
                    break
                fi
            fi

        done
    fi

else

    deploymentOutput=$(az deployment group create --subscription $ENVIRONMENT_SUBSCRIPTION_ID \
                                                    --resource-group "$ENVIRONMENT_RESOURCE_GROUP_NAME" \
                                                    --name "$deploymentName" \
                                                    --no-prompt true --no-wait --mode Complete \
                                                    --template-file "$deploymentTemplate" \
                                                    --parameters "$deploymentParameters" \
                                                    "${deploymentParameters_adds[@]}" 2>&1)

    if [ $? -eq 0 ]; then # deployment successfully created
        while true; do

            sleep 1

            ProvisioningState=$(az deployment group show --resource-group "$ENVIRONMENT_RESOURCE_GROUP_NAME" --name "$deploymentName" --query "properties.provisioningState" -o tsv)
            ProvisioningDetails=$(az deployment operation group list --resource-group "$ENVIRONMENT_RESOURCE_GROUP_NAME" --name "$deploymentName")

            trackDeployment "$ProvisioningDetails"

            if [[ "CANCELED|FAILED|SUCCEEDED" == *"${ProvisioningState^^}"* ]]; then

                echo -e "\nDeployment $deploymentName: $ProvisioningState"

                if [[ "CANCELED|FAILED" == *"${ProvisioningState^^}"* ]]; then
                    exit 1
                else
                    break
                fi
            fi

        done
    fi

fi

# trim spaces from output to avoid issues in the following (generic) error section
deploymentOutput=$(echo "$deploymentOutput" | sed -e 's/^[[:space:]]*//')

if [ ! -z "$deploymentOutput" ]; then

    if [ $(echo "$deploymentOutput" | jq empty > /dev/null 2>&1; echo $?) -eq 0 ]; then
        # the component deployment output was identified as JSON - lets extract some error information to return a more meaningful output
        deploymentOutput="$( echo $deploymentOutput | jq --raw-output '.. | .message? | select(. != null) | "Error: \(.)\n"' | sed 's/\\n/\n/g'  )"
    fi

    # our script failed to enqueue a new deployment -
    # we return a none zero exit code to inidicate this
    echo "$deploymentOutput" && exit 1

fi
