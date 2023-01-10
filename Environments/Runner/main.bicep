// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

@description('Location for all resources.')
param location string = resourceGroup().location

param name string

@description('Container image to deploy. Should be of the form repoName/imagename:tag for images stored in public Docker Hub, or a fully qualified URI for other registries.')
param container string = 'ghcr.io/colbylwilliams/ade/arm'

@description('The client (app) id for the service principal to use for authentication.')
param clientId string = ''

@secure()
@description('The secret for the service principal to use for authentication.')
param clientSecret string = ''

param actionId string = guid(name)

param actionName string = 'deploy'

param catalog string = 'default'

param catalogItem string = 'Echo'

param catalogRepoUrl string = 'https://github.com/colbylwilliams/ade'

param catalogRepoRevision string = ''

@secure()
param catalogRepoSecret string = ''

param catalogRepoPath string = '/Environments'

// get the tags that ADE added from the Environment Type
// var tags = resourceGroup().tags

var mountStorage = '/mnt/storage'
var mountTemporary = '/mnt/temporary'
var mountRepository = '/mnt/repository'

var authEnvironmentVars = !empty(clientId) && !empty(clientSecret) ? [
  { name: 'AZURE_TENANT_ID', value: tenant().tenantId }
  { name: 'AZURE_CLIENT_ID', value: clientId }
  { name: 'AZURE_CLIENT_SECRET', secureValue: clientSecret }
] : []

var defaultEnvironmentVars = [
  // { name: 'MSI_ENDPOINT', value: '' } // MSI auth endpoint. Only necessary when the MSI endpoint is different than the well-known one. This will have the same value as ARM_MSI_ENDPOINT.
  { name: 'ARM_USE_MSI', value: true } // Always set to true. Tells software like Terraform to authenticate using the container's managed identity.
  // { name: 'ARM_MSI_ENDPOINT', value: '' } // MSI auth endpoint. Only necessary when the MSI endpoint is different than the well-known one. This will have the same value as MSI_ENDPOINT.
  { name: 'ARM_TENANT_ID', value: tenant().tenantId } // Tenant ID.
  { name: 'ARM_SUBSCRIPTION_ID', value: subscription().subscriptionId } // The unique id (guid) for subscription that the Environment's resource group is in. This will have the same value as ENVIRONMENT_SUBSCRIPTION_ID.
  { name: 'ARM_RESOURCE_GROUP_NAME', value: resourceGroup().name } // The name of the Environment's resource group. This will have the same value as ENVIRONMENT_RESOURCE_GROUP_NAME.
  { name: 'ENVIRONMENT_ID', value: '' } // The unique id (guid) of the Environment.
  { name: 'ENVIRONMENT_LOCATION', value: location } // The Azure Region to deploy the Environment's resources.
  { name: 'ENVIRONMENT_SUBSCRIPTION', value: subscription().id } // The resource id for subscription that the Environment's resource group is in. For example: /subscriptions/159f2485-xxxx-xxxx-xxxx-xxxxxxxxxxxx.
  { name: 'ENVIRONMENT_SUBSCRIPTION_ID', value: subscription().subscriptionId } // The unique id (guid) for subscription that the Environment's resource group is in. This will have the same value as ARM_SUBSCRIPTION_ID.
  { name: 'ENVIRONMENT_RESOURCE_GROUP_ID', value: resourceGroup().id } // The id of the Environment's resource group. For example: /subscriptions/159f2485-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/ENVIRONMENT_RESOURCE_GROUP_NAME.
  { name: 'ENVIRONMENT_RESOURCE_GROUP_NAME', value: resourceGroup().name } // The name of the Environment's resource group. This will have the same value as ENVIRONMENT_RESOURCE_GROUP_NAME.
  { name: 'ENVIRONMENT_ARTIFACTS', value: '${mountStorage}/.artifacts' } // Always set to /mnt/storage/.artifacts. The path to a persistent (file share) directory. This directory will be persisted between actions. Files saved to this directory will be available via the Dataplane.
  { name: 'ENVIRONMENT_TYPE_ID', value: resourceGroup().tags.ENVIRONMENT_TYPE_ID }
  { name: 'ENVIRONMENT_TYPE_NAME', value: resourceGroup().tags.ENVIRONMENT_TYPE_NAME }
  { name: 'ENVIRONMENT_TYPE_IDENTITY', value: resourceGroup().tags.ENVIRONMENT_TYPE_IDENTITY }
  { name: 'ENVIRONMENT_TYPE_IDENTITY_TYPE', value: resourceGroup().tags.ENVIRONMENT_TYPE_IDENTITY_TYPE }
  { name: 'PROJECT_ID', value: resourceGroup().tags.PROJECT_ID }
  { name: 'PROJECT_NAME', value: resourceGroup().tags.PROJECT_NAME }
  { name: 'DEVCENTER_ID', value: resourceGroup().tags.DEVCENTER_ID }
  { name: 'DEVCENTER_NAME', value: resourceGroup().tags.DEVCENTER_NAME }
  { name: 'DEVCENTER_CONFIG_ID', value: resourceGroup().tags.DEVCENTER_CONFIG_ID }
  { name: 'DEVCENTER_CONFIG_NAME', value: resourceGroup().tags.DEVCENTER_CONFIG_NAME }
  { name: 'DEVCENTER_STORAGE_ID', value: resourceGroup().tags.DEVCENTER_STORAGE_ID }
  { name: 'DEVCENTER_STORAGE_NAME', value: resourceGroup().tags.DEVCENTER_STORAGE_NAME }
  { name: 'ACTION_ID', value: actionId } // The unique id (guid) of the action.
  { name: 'ACTION_NAME', value: actionName } // The name of the action to execute. For example: deploy.
  // { name: 'ACTION_HOST', value: '' } // TODO...
  // { name: 'ACTION_BASE_URL', value: '' } // TODO...
  { name: 'ACTION_PARAMETERS', value: '' } // A JSON object with the input parameters for the action.
  { name: 'ACTION_STORAGE', value: mountStorage } // Always set to /mnt/storage. The path to a persistent (file share) directory. This directory will be persisted between actions.
  { name: 'ACTION_TEMP', value: '/mnt/temporary' } // Always set to /mnt/temporary. The path to a temporary directory. This directory will not be persisted between actions.
  { name: 'ACTION_OUTPUT', value: '/mnt/storage/.output/${actionId}' } // Always set to /mnt/storage/.output/$ACTION_ID
  { name: 'CATALOG', value: '${mountRepository}${catalogRepoPath}' } // The path to the Catalog within the cloned Catalog git repository. For example: /mnt/catalog/root/Catalog
  { name: 'CATALOG_NAME', value: catalog } // The name of the Catalog
  { name: 'CATALOG_ITEM', value: '${mountRepository}${catalogRepoPath}/${catalogItem}' } // The path to CatalogItem folder within the cloned Catalog git repository. For example: /mnt/catalog/root/Catalog/FunctionApp
  { name: 'CATALOG_ITEM_NAME', value: catalogItem } // The name of the CatalogItem
  { name: 'CATALOG_ITEM_TEMPLATE', value: '' } // The path to CatalogItem template file within the cloned Catalog git repository. For example: /mnt/catalog/root/Catalog/FunctionApp/azuredeploy.json
  { name: 'CATALOG_ITEM_TEMPLATE_URL', value: '' } // TODO...
  { name: 'CATALOG_ITEM_TEMPLATE_URL_TOKEN', value: '' } // TODO...
]

var environmentVars = empty(authEnvironmentVars) ? defaultEnvironmentVars : concat(defaultEnvironmentVars, authEnvironmentVars)

var identityId = resourceGroup().tags.ENVIRONMENT_TYPE_IDENTITY

var storageAccountId = resourceGroup().tags.DEVCENTER_STORAGE_ID
var storageAccountName = empty(storageAccountId) ? '' : last(split(storageAccountId, '/'))
var storageAccountGroup = empty(storageAccountId) ? '' : first(split(last(split(replace(storageAccountId, 'resourceGroups', 'resourcegroups'), '/resourcegroups/')), '/'))
var storageAccountSub = empty(storageAccountId) ? '' : first(split(last(split(storageAccountId, '/subscriptions/')), '/'))

var repositoryUser = contains(toLower(catalogRepoUrl), 'github.com') ? 'gituser' : contains(toLower(catalogRepoUrl), 'dev.azure.com') ? 'azurereposuser' : 'user'
var repository = empty(catalogRepoSecret) ? catalogRepoUrl : replace(catalogRepoUrl, 'https://', 'https://${repositoryUser}:${catalogRepoSecret}@')

var nameClean = replace(replace(replace(toLower(trim(name)), ' ', '-'), '_', '-'), '.', '-')
// Character limit: 3-63
// Valid characters: Lowercase letters, numbers, and hyphens. Cant start or end with hyphen. Cant use consecutive hyphens.
var shareName = length(nameClean) <= 62 ? nameClean : take(nameClean, 62)

resource storage 'Microsoft.Storage/storageAccounts@2021-09-01' existing = if (!empty(storageAccountId)) {
  name: storageAccountName
  scope: resourceGroup(storageAccountSub, storageAccountGroup)
}

module storageFileShare 'fileshare.bicep' = {
  name: 'storageFileShare'
  params: {
    accountName: storage.name
    shareName: shareName
  }
  scope: resourceGroup(storageAccountSub, storageAccountGroup)
}

resource group 'Microsoft.ContainerInstance/containerGroups@2022-09-01' = {
  name: 'aderunner'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identityId}': {}
    }
  }
  // tags: {
  //   version: version
  //   timestamp: timestamp
  // }
  properties: {
    // subnetIds: (!empty(subnetId) ? [
    //   {
    //     id: subnetId
    //   }
    // ] : null)
    containers: [
      {
        name: 'aderunner'
        properties: {
          image: container
          // ports: (empty(subnetId) ? [
          //   {
          //     port: 80
          //     protocol: 'TCP'
          //   }
          // ] : null)
          resources: {
            requests: {
              cpu: 1
              memoryInGB: 2
            }
          }
          volumeMounts: [
            {
              name: 'repository'
              mountPath: mountRepository
              readOnly: false
            }
            {
              name: 'storage'
              mountPath: mountStorage
              readOnly: false
            }
            {
              name: 'temporary'
              mountPath: mountTemporary
              readOnly: false
            }
          ]
          environmentVariables: environmentVars
          // environmentVariables:[
          //   {
          //     name: 'foo'
          //     value: 'bar'
          //     secureValue: 'bar'
          //   }
          // ]
        }
      }
    ]
    osType: 'Linux'
    restartPolicy: 'Never'
    // ipAddress: (empty(subnetId) ? {
    //   type: 'Public'
    //   ports: [
    //     {
    //       port: 80
    //       protocol: 'TCP'
    //     }
    //   ]
    // } : null)
    volumes: [
      {
        name: 'repository'
        gitRepo: {
          repository: repository
          directory: '.'
          revision: (!empty(catalogRepoRevision) ? catalogRepoRevision : null)
        }
      }
      {
        name: 'storage'
        azureFile: {
          shareName: storageFileShare.outputs.shareName
          storageAccountName: storage.name
          storageAccountKey: storage.listKeys().keys[0].value
          readOnly: false
        }
      }
      {
        name: 'temporary'
        emptyDir: {}
      }
    ]
  }
}
