// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

param shareName string

param accountName string

resource storage 'Microsoft.Storage/storageAccounts@2021-09-01' existing = {
  name: accountName
  resource fileServices 'fileServices' = {
    name: 'default'
    resource fileShare 'shares' = {
      name: shareName
    }
  }
}

output shareName string = storage::fileServices::fileShare.name
