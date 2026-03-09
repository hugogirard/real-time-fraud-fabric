# Real-Time Fraud Detection with Microsoft Fabric

## Prerequisites

### Azure Developer CLI (azd)

This project uses the [Azure Developer CLI (azd)](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/overview) to provision all Azure infrastructure.

**Install azd:**

- **Windows:** `winget install microsoft.azd`
- **macOS:** `brew tap azure/azd && brew install azd`
- **Linux:** `curl -fsSL https://aka.ms/install-azd.sh | bash`

For other install options, see the [official installation guide](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/install-azd).

### Azure CLI

You also need the [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) installed for authentication.

- **Windows:** `winget install Microsoft.AzureCLI`
- **macOS:** `brew install azure-cli`
- **Linux:** `curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash`

## Deploying the Infrastructure

1. **Log in to both CLIs:**

   ```bash
   az login
   azd auth login
   ```

2. **Initialize a new environment** (first time only):

   ```bash
   azd init
   ```

   You will be prompted for an environment name, Azure subscription, and location.

3. **Provision all resources:**

   ```bash
   azd up
   ```

   This will deploy all the infrastructure defined under the `infra/` folder (Bicep templates) into your Azure subscription.

## Troubleshooting

### "refresh token has expired" error

If you see:

```
ERROR: resolving bicep parameters file: fetching current principal id: ...refresh token has expired
```

Run a full re-authentication for both CLIs:

```bash
azd auth logout
az account clear
az login
azd auth login
```

Then retry `azd up`.

## Project Structure

```
infra/
  main.bicep              # Entry point – subscription-scoped deployment
  main.parameters.json    # Parameters (env name, location, resource group)
  abbreviations.json      # Resource naming abbreviations
  core/
    AI/
      foundry.bicep       # Azure AI Foundry account
```
