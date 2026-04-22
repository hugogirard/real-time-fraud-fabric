# Fraud Alert Email Notifications — Fabric Activator + Power Automate

End-to-end solution that sends **customized HTML email alerts** when a
fraudulent credit-card transaction is detected in real time by
**Microsoft Fabric Real-Time Intelligence**.

## Architecture

```
┌─────────────────────┐     ┌───────────────────────┐     ┌─────────────────────┐
│  Fabric Eventstream  │────▶│  Eventhouse (KQL DB)  │────▶│  Data Activator     │
│  (live transactions) │     │  Transactions table   │     │  (Reflex trigger)   │
└─────────────────────┘     │  Customers table      │     └────────┬────────────┘
                            └───────────────────────┘              │
                                                          HTTP POST (webhook)
                                                                   │
                                                                   ▼
                                                     ┌─────────────────────────┐
                                                     │  Azure Logic App        │
                                                     │  (Power Automate)       │
                                                     │                         │
                                                     │  1. Receive alert JSON  │
                                                     │  2. Compose HTML email  │
                                                     │  3. Send via Office 365 │
                                                     └─────────────────────────┘
                                                                   │
                                                                   ▼
                                                              📧 Email
                                                        (Fraud Ops team)
```

## What's Included

| File | Purpose |
|------|---------|
| `infra/main.bicep` | Bicep template — deploys Logic App + Office 365 API connection |
| `infra/main.bicepparam` | Parameter file (edit with your email and region) |
| `Deploy-FraudAlerts.ps1` | PowerShell script — deploys everything and outputs webhook URL |
| `fabric/fraud-detection-alert.kql` | KQL query joining Transactions + Customers for fraud events |
| `fabric/activator-setup.md` | Step-by-step guide to configure Fabric Activator (Reflex) |

## Quick Start

### 1. Edit Parameters

Update `infra/main.bicepparam` with your values:

```
param alertRecipientEmail = 'security-team@contoso.com'
param location = 'eastus'
```

### 2. Deploy to Azure

```powershell
.\Deploy-FraudAlerts.ps1 `
    -SubscriptionId "<your-subscription-id>" `
    -ResourceGroupName "rg-fraud-alerts" `
    -Location "eastus" `
    -AlertRecipientEmail "security-team@contoso.com"
```

The script outputs the **Logic App webhook URL** — you'll need this for
the Fabric Activator configuration.

### 3. Authorize the Office 365 Connection

After deployment, authorize the email connector:

1. Go to the Azure Portal → your resource group → the API connection resource
2. Click **Edit API connection** → **Authorize** → sign in with your Office 365 account → **Save**

### 4. Configure Fabric Activator

Follow the detailed guide in [`fabric/activator-setup.md`](fabric/activator-setup.md):

1. Create a **Reflex** item in your Fabric workspace
2. Connect it to your **Eventhouse** with the KQL query from `fabric/fraud-detection-alert.kql`
3. Set the trigger condition for fraud detection
4. Add a **Custom Action** with the Logic App webhook URL
5. **Start** the Activator

### 5. Test

Run `Generate_Credit_Card_Transactions.ipynb` to stream transactions.
Fraudulent transactions (~4%) will trigger the Activator, which calls the
Logic App, which sends a rich HTML email with:

- Transaction details (amount, merchant, location, timestamp)
- Cardholder information (name, email, home location, credit limit)
- Risk indicators (distance from home, amount z-score, velocity metrics)
- Fraud type classification

## Email Preview

The customized email includes:

- **Red alert header** with "Immediate Action Required" badge
- **Transaction details** table with highlighted fraud amount
- **Cardholder info** with home location and credit limit
- **Risk indicators** panel explaining why the transaction was flagged
- **Footer** with Fabric Real-Time Intelligence branding

## Prerequisites

- Azure subscription with permissions to create Logic Apps
- Azure CLI installed and authenticated (`az login`)
- Microsoft Fabric workspace with:
  - Eventhouse (KQL database) with `Transactions` and `Customers` tables
  - Eventstream streaming transaction data
- Office 365 account for sending emails
