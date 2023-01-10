#!/bin/bash

# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

trace() {
    echo -e "\n>>> $@ ...\n"
}

readonly EnvironmentState="$ADE_ACTION_STORAGE/environment.tfstate"
readonly EnvironmentPlan="$ADE_ACTION_TEMP/environment.tfplan"
readonly EnvironmentVars="$ADE_ACTION_TEMP/environment.tfvars.json"

echo "$ADE_ACTION_PARAMETERS" > $EnvironmentVars

trace "Terraform Info"
terraform -version

trace "Initializing Terraform"
terraform init -no-color

trace "Creating Terraform Plan"
terraform plan -no-color -compact-warnings -destroy -refresh=true -lock=true -state=$EnvironmentState -out=$EnvironmentPlan -var-file="$EnvironmentVars" -var "resource_group_name=$ADE_ENVIRONMENT_RESOURCE_GROUP_NAME"

trace "Applying Terraform Plan"
terraform apply -no-color -compact-warnings -auto-approve -lock=true -state=$EnvironmentState $EnvironmentPlan

# tail -f /dev/null
