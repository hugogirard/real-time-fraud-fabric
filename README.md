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

## Configure the Microsoft Fabric Workspace

Once `azd up` has provisioned the Azure resources, the next step is to set up the **Real-Time Intelligence** workspace in Microsoft Fabric. This is where the Eventhouse, Eventstream, notebooks, and Reflex (Activator) that power the fraud-detection demo live.

Follow the step-by-step guide in [`FabricRTI/Readme.md`](./FabricRTI/Readme.md), which walks you through:

1. **Connecting the Fabric workspace to this Git repo** (Git folder set to `/FabricRTI`) so the Eventhouse, KQL database, Eventstream, notebooks, and Reflex item are provisioned automatically on sync.
2. **Verifying the KQL database schema** (`Customers` and `CCTransactions` tables) created by `DatabaseSchema.kql` on sync.
3. **Generating synthetic customers** with the `Generate_Customers` notebook.
4. **Wiring the Eventstream connection string** into the Azure Key Vault deployed by `azd` (secret name `EventHubConnectionString`).
5. **Granting the Fabric workspace identity** the `Key Vault Secrets User` role so the notebooks can fetch the secret at runtime.
6. **Streaming transactions** with the `Generate_Credit_Card_Transactions` notebook.
7. **Configuring the Reflex (Activator) rule** that sends fraud-alert emails — see [`src/fraudstream/rti/README-fraud-alerts.md`](./src/fraudstream/rti/README-fraud-alerts.md) for the click-by-click walk-through.

> **Prerequisites for the Fabric setup:** a Fabric-enabled workspace assigned to a Fabric capacity, the Azure Key Vault deployed by `azd up`, and an Entra ID tenant where you can create test users.

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
