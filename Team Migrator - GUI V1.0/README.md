Azure DevOps Team Migrator:
This tool is part of Azure DevOps Management Studio which I'm working on. It simply clones the users from one team to another. You need to have a source and target organization.

Requirements:
- Azure CLI should be installed. Download it from Microsoft's documentation.
- Your personal access token for Target org should have full access to "User Entitlement" management.
- Your systems execution policy should be set to either remote-signed or unrestricted in order to run the scripts. 
