// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

@minLength(3)
@maxLength(63)
@description('File share name. Valid characters: Lowercase letters, numbers, and hyphens. Cant start or end with hyphen. Cant use consecutive hyphens.')
param shareName string

@minLength(3)
@maxLength(24)
@description('Storage account name. Valid characters: Lowercase letters and numbers. Resource name must be unique across Azure.')
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
