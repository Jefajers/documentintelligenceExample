# Example of a documentintelligence setup.

### Requires:
1. An Azure subscription
2. RBAC to create resources
3. Az PowerShell
4. A Resource Group

### Usage:
Update bicep parameters in `main.bicepparam` with your values, including the `env` parameter.

- **env = dev**:
  - Allows Document Intelligence Studio to access the Document Intelligence resource and the associated Storage Account by permitting access from the Studio's public IP.
  - Grants Document Intelligence Studio write permissions to the Storage Account for inferencing and testing purposes.
  - Updates the CORS settings on the Storage Account to allow access from Document Intelligence.

- **env = prod**:
  - Restricts access to the Document Intelligence resource and Storage Account.
  - Does not allow public IP access or Studio write permissions by default.
  - Does not update CORS settings for Document Intelligence Studio access.

Deploy by running:
`New-AzResourceGroupDeployment -Name <replaceMe> -ResourceGroupName <replaceMe> -TemplateFile ./main.bicep -TemplateParameterFile ./main.bicepparam`.

### What to expect:
1. Once finished you will have an environment setup with Document Intelligence.