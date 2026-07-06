# Deploying the Azure Infrastructure

This guide walks you through provisioning all Azure resources required by the Real-Time Fraud Detection solution using the Azure Developer CLI (`azd`).

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

## Deployment Steps

### 1. Log in to both CLIs

```bash
az login
azd auth login
```

### 2. Initialize a new environment (first time only)

```bash
azd init
```

You will be prompted for an environment name, Azure subscription, and location.

### 3. Provision all resources

```bash
azd up
```

This will deploy all the infrastructure defined under the `infra/` folder (Bicep templates) into your Azure subscription, including:

| Resource | Purpose |
|----------|---------|
| Azure AI Foundry + GPT model | Powers the fraud-analysis AI agent |
| Azure Function App | Backend API — chat/agent service (Python) |
| Azure App Service (Web App) | Frontend — Angular SPA for fraud analysts |
| Storage Account | Function App backing storage |
| Azure Container Registry | Container images for Function & Web App |
| Application Insights + Log Analytics | Monitoring and diagnostics |
| Entra ID App Registrations | OAuth2 authentication for Web App & Function |
| User-Assigned Managed Identity | Keyless auth between Function → Foundry/Storage |
| RBAC Role Assignments | Least-privilege access between services |

### 4. Next step

Once deployment completes, proceed to configure the Microsoft Fabric workspace by following the guide in [`FabricRTI/Readme.md`](../FabricRTI/Readme.md).
