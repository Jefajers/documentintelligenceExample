# Example of a documentintelligence setup.

### Requires:
1. An Azure subscription
2. RBAC to create resources
3. Az PowerShell
4. A Resource Group

### Usage:
Update bicep parameters in `main.bicepparam` with your values.
Deploy by running: `New-AzResourceGroupDeployment -Name <replaceMe> -ResourceGroupName <replaceMe> -TemplateFile ./main.bicep -TemplateParameterFile ./main.bicepparam`.

### What to expect:
1. Once finished you will have a environment setup with documentintelligence.