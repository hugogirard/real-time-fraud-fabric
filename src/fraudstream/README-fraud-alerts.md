# Fraud Alert Email Notifications — Fabric Activator + Power Automate

End-to-end solution that sends **customized HTML email alerts** when a
fraudulent credit-card transaction is detected in real time by
**Microsoft Fabric Real-Time Intelligence**.

Alerts are sent **directly to the affected customer** (with the Fraud Ops
team CC'd), include a table of the customer's **last 10 fraudulent
transactions**, and contain a deep link to the **Fraud Investigation App**.

## Architecture

```
┌─────────────────────┐     ┌───────────────────────┐     ┌─────────────────────┐
│  Fabric Eventstream  │────▶│  Eventhouse (KQL DB)  │────▶│  Data Activator     │
│  (live transactions) │     │  Transactions table   │     │  (Reflex trigger)   │
└─────────────────────┘     │  Customers table      │     └────────┬────────────┘
                            └───────────────────────┘              │
                                                          HTTP POST (webhook)
                                                          ┌───────┴──────────┐
                                                          │  Payload includes │
                                                          │  • customer email │
                                                          │  • fraud details  │
                                                          │  • last 10 fraud  │
                                                          │    txns (HTML)    │
                                                          └───────┬──────────┘
                                                                  │
                                                                  ▼
                                                    ┌─────────────────────────┐
                                                    │  Azure Logic App        │
                                                    │  (Power Automate)       │
                                                    │                         │
                                                    │  1. Receive alert JSON  │
                                                    │  2. Compose HTML email  │
                                                    │     + fraud history     │
                                                    │     + app deep link     │
                                                    │  3. Send via Office 365 │
                                                    └─────────────────────────┘
                                                                  │
                                              ┌───────────────────┼───────────────────┐
                                              ▼                                       ▼
                                        📧 To: Customer                       📧 Cc: Fraud Ops
                                    (affected cardholder)                     (security team)
```

## What's Included

| File | Purpose |
|------|---------|
| `infra/main.bicep` | Bicep template — deploys Logic App + Office 365 API connection |
| `infra/main.bicepparam` | Parameter file (edit with your email, region, and app URL) |
| `Deploy-FraudAlerts.ps1` | PowerShell script — deploys everything and outputs webhook URL |
| `fabric/fraud-detection-alert.kql` | KQL query joining Transactions + Customers + fraud history HTML |
| `fabric/activator-setup.md` | Step-by-step guide to configure Fabric Activator (Reflex) |

## Quick Start

### 1. Edit Parameters

Update `infra/main.bicepparam` with your values:

```
param alertRecipientEmail = 'security-team@contoso.com'
param location = 'eastus'
param appUrl = 'https://my-fraud-app.azurewebsites.net'
```

> **Note:** `appUrl` can remain as the default placeholder until your
> investigation app is ready. The email will contain a "Review in Fraud
> Investigation App" button that links to this URL with `user_id` and
> `txn_id` query parameters.

### 2. Deploy to Azure

```powershell
.\Deploy-FraudAlerts.ps1 `
    -SubscriptionId "<your-subscription-id>" `
    -ResourceGroupName "rg-fraud-alerts" `
    -Location "eastus" `
    -AlertRecipientEmail "security-team@contoso.com" `
    -AppUrl "https://my-fraud-app.azurewebsites.net"
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
- **Last 10 fraudulent transactions** for the same cardholder
- **Deep link** to the Fraud Investigation App

## Email Details

### Recipients

| Field | Source | Description |
|-------|--------|-------------|
| **To** | `triggerBody()?['email']` | Customer email from the `Customers` table (joined via `user_id`) |
| **Cc** | `alertRecipientEmail` parameter | Security / Fraud Ops team email |

### Email Sections

1. **Red alert header** — "Immediate Action Required" badge
2. **Transaction details** — amount (highlighted), merchant, location, timestamp, fraud type
3. **Cardholder info** — name, email, home location, credit limit
4. **Risk indicators** — distance from home, z-score, velocity, hour of day
5. **Recent Fraud History** — HTML table of the last 10 fraudulent transactions (built in KQL)
6. **Call-to-action button** — "Review in Fraud Investigation App" linking to `appUrl?user_id=...&txn_id=...`
7. **Footer** — Fabric branding, recipient info, app link

### How the Fraud History Table Works

The KQL query in [`fraud-detection-alert.kql`](fabric/fraud-detection-alert.kql)
pre-builds a complete HTML table (`fraud_history_html`) server-side using
`strcat()` and `make_list()`. This means:

- **No extra Logic App actions** — the HTML is ready to inject
- **No extra API calls** — everything is computed in the Eventhouse
- **Up to 10 most recent** fraud transactions per customer are included

## Prerequisites

- Azure subscription with permissions to create Logic Apps
- Azure CLI installed and authenticated (`az login`)
- Microsoft Fabric workspace with:
  - Eventhouse (KQL database) with `Transactions` and `Customers` tables
  - Eventstream streaming transaction data
- Office 365 account for sending emails
