using './main.bicep'

param env = 'dev'
param vmSize = 'Standard_D2ds_v5'
param location = 'swedencentral'
param vnetName = 'myVNet'
param documentIntelligenceName = '<replaceMe>'
param customDocumentIntelligenceName = '<replaceMe>'
param storageAccountName = '<replaceMe>'
param bastionName = 'myBastion'
param vmName = 'jumpVm'
param adminUsername = 'azureuser'
param adminPassword = '<replaceMe>'