<#
.SYNOPSIS
    Deploys the Fraud Alert Logic App and retrieves the webhook URL
    for Fabric Activator integration.

.DESCRIPTION
    This script:
      1. Creates a resource group (if it doesn't exist)
      2. Deploys the Logic App + Office 365 API connection via Bicep
      3. Retrieves the HTTP trigger callback URL
      4. Outputs the URL to paste into Fabric Activator

.PARAMETER SubscriptionId
    Azure subscription ID to deploy into.

.PARAMETER ResourceGroupName
    Name of the resource group (created if missing).

.PARAMETER Location
    Azure region (e.g. eastus, westeurope).

.PARAMETER AlertRecipientEmail
    Email address that receives fraud alert emails.

.PARAMETER NamePrefix
    Prefix for all resource names. Default: fraud-alert.

.EXAMPLE
    .\Deploy-FraudAlerts.ps1 `
        -SubscriptionId "00000000-0000-0000-0000-000000000000" `
        -ResourceGroupName "rg-fraud-alerts" `
        -Location "eastus" `
        -AlertRecipientEmail "security@contoso.com"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$SubscriptionId,

    [Parameter(Mandatory)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory)]
    [string]$Location,

    [Parameter(Mandatory)]
    [string]$AlertRecipientEmail,

    [string]$NamePrefix = "fraud-alert"
)

$ErrorActionPreference = "Stop"
$InformationPreference = "Continue"

# ── Authenticate & set subscription ───────────────────────
Write-Information "Setting Azure subscription to $SubscriptionId..."
az account set --subscription $SubscriptionId
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to set subscription. Run 'az login' first."
    exit 1
}

# ── Create resource group ─────────────────────────────────
Write-Information "Ensuring resource group '$ResourceGroupName' exists in '$Location'..."
az group create --name $ResourceGroupName --location $Location --output none

# ── Deploy Bicep template ─────────────────────────────────
$bicepFile = Join-Path $PSScriptRoot "infra\main.bicep"

Write-Information "Deploying Logic App via Bicep..."
$deploymentOutput = az deployment group create `
    --resource-group $ResourceGroupName `
    --template-file $bicepFile `
    --parameters location=$Location namePrefix=$NamePrefix alertRecipientEmail=$AlertRecipientEmail `
    --query "properties.outputs" `
    --output json | ConvertFrom-Json

$logicAppName = $deploymentOutput.logicAppName.value
$triggerId = $deploymentOutput.logicAppTriggerId.value
$connectionName = $deploymentOutput.office365ConnectionName.value

Write-Information ""
Write-Information "Deployment complete!"
Write-Information "  Logic App:  $logicAppName"
Write-Information "  Connection: $connectionName"

# ── Retrieve the HTTP trigger callback URL ────────────────
Write-Information ""
Write-Information "Retrieving webhook callback URL..."

$callbackUrl = az rest `
    --method POST `
    --uri "https://management.azure.com$($triggerId)/listCallbackUrl?api-version=2016-06-01" `
    --query "value" `
    --output tsv

Write-Information ""
Write-Information "============================================================"
Write-Information " LOGIC APP WEBHOOK URL (paste into Fabric Activator)"
Write-Information "============================================================"
Write-Information ""
Write-Information $callbackUrl
Write-Information ""
Write-Information "============================================================"

# ── Post-deployment instructions ──────────────────────────
Write-Information ""
Write-Information "NEXT STEPS:"
Write-Information ""
Write-Information "1. AUTHORIZE the Office 365 connection in the Azure Portal:"
Write-Information "   - Go to: Resource Group '$ResourceGroupName' -> '$connectionName'"
Write-Information "   - Click 'Edit API connection' -> 'Authorize' -> Sign in -> Save"
Write-Information ""
Write-Information "2. CONFIGURE Fabric Activator:"
Write-Information "   - Follow the guide in fabric/activator-setup.md"
Write-Information "   - Paste the webhook URL above into the Activator custom action"
Write-Information ""
Write-Information "3. TEST by running Generate_Credit_Card_Transactions.ipynb"
Write-Information "   to stream fraud transactions and verify email delivery."
