<#
.SYNOPSIS
    Deploys the Real-Time Fraud Alert solution to Microsoft Fabric and (optionally) Azure.

.DESCRIPTION
    This script sets up the fraud alert system that sends customized email notifications
    when fraudulent credit-card transactions are detected in real time.

    Components deployed:
    - Fabric: Reflex (Data Activator) item for real-time alerting
    - Azure (optional): Logic App for advanced HTML email templating

    The solution uses Fabric Data Activator as the core alerting engine. The Activator
    source is the Eventstream (NOT the Eventhouse), and customer lookups + fraud history
    are done via KQL-backed properties evaluated at trigger time.

    Prerequisites (must already exist):
    - Eventhouse with CCTransactions and Customers tables
    - Eventstream streaming transaction data

.PARAMETER FabricWorkspaceName
    Name of the Fabric workspace (e.g., "FraudDemo").

.PARAMETER KqlDatabaseName
    Name of the KQL database inside the Eventhouse (e.g., "MyFraud_EH").

.PARAMETER TransactionsTableName
    Name of the transactions table (default: "CCTransactions").

.PARAMETER EventstreamName
    Name of the Eventstream to connect the Reflex to (e.g., "CreditCardTransactions_es").

.PARAMETER ReflexName
    Name of the Reflex item to create (default: "rx-fraud-alerts").

.PARAMETER InvestigationAppUrl
    URL of the fraud investigation web app (used in email links).

.PARAMETER DeployLogicApp
    If specified, also deploys the Azure Logic App for advanced HTML emails.

.PARAMETER SubscriptionId
    Azure subscription ID (required if -DeployLogicApp is specified).

.PARAMETER ResourceGroupName
    Azure resource group name (required if -DeployLogicApp is specified).

.PARAMETER Location
    Azure region (default: "canadaeast").

.PARAMETER AlertRecipientEmail
    Fraud Ops team email for CC (required if -DeployLogicApp is specified).

.EXAMPLE
    # Fabric-only deployment (Data Activator built-in email)
    .\Deploy-FraudAlerts.ps1 `
        -FabricWorkspaceName "FraudDemo" `
        -KqlDatabaseName "MyFraud_EH" `
        -EventstreamName "CreditCardTransactions_es"

.EXAMPLE
    # Full deployment including Azure Logic App
    .\Deploy-FraudAlerts.ps1 `
        -FabricWorkspaceName "FraudDemo" `
        -KqlDatabaseName "MyFraud_EH" `
        -EventstreamName "CreditCardTransactions_es" `
        -DeployLogicApp `
        -SubscriptionId "00000000-0000-0000-0000-000000000000" `
        -ResourceGroupName "rg-fraud-alerts" `
        -AlertRecipientEmail "security@contoso.com"

.NOTES
    Prerequisites:
    - Azure CLI installed and authenticated (az login)
    - Fabric workspace with Eventhouse and Eventstream already configured
    - Transaction data flowing through the Eventstream
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$FabricWorkspaceName,

    [Parameter(Mandatory = $true)]
    [string]$KqlDatabaseName,

    [Parameter()]
    [string]$TransactionsTableName = "CCTransactions",

    [Parameter(Mandatory = $true)]
    [string]$EventstreamName,

    [Parameter()]
    [string]$ReflexName = "rx-fraud-alerts",

    [Parameter()]
    [string]$InvestigationAppUrl = "https://fraud-app.contoso.com/review",

    [switch]$DeployLogicApp,

    [Parameter()]
    [string]$SubscriptionId,

    [Parameter()]
    [string]$ResourceGroupName,

    [Parameter()]
    [string]$Location = "canadaeast",

    [Parameter()]
    [string]$AlertRecipientEmail
)

$ErrorActionPreference = "Stop"
$ScriptRoot = $PSScriptRoot

# ─────────────────────────────────────────────────────────────────────────────
# Helper functions
# ─────────────────────────────────────────────────────────────────────────────

function Write-Step {
    param([string]$Message)
    Write-Host "`n▶ $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "  ✓ $Message" -ForegroundColor Green
}

function Write-Info {
    param([string]$Message)
    Write-Host "  ℹ $Message" -ForegroundColor Gray
}

function Write-Warning {
    param([string]$Message)
    Write-Host "  ⚠ $Message" -ForegroundColor Yellow
}

function Get-FabricAccessToken {
    $token = az account get-access-token --resource "https://api.fabric.microsoft.com" --query accessToken -o tsv
    if (-not $token) {
        throw "Failed to get Fabric access token. Run 'az login' first."
    }
    return $token
}

function Get-KustoAccessToken {
    $token = az account get-access-token --resource "https://kusto.kusto.windows.net" --query accessToken -o tsv
    if (-not $token) {
        throw "Failed to get Kusto access token. Run 'az login' first."
    }
    return $token
}

function Invoke-FabricApi {
    param(
        [string]$Method,
        [string]$Path,
        [object]$Body,
        [string]$Token
    )
    
    $uri = "https://api.fabric.microsoft.com/v1$Path"
    $headers = @{
        "Authorization" = "Bearer $Token"
        "Content-Type"  = "application/json"
    }
    
    $params = @{
        Uri     = $uri
        Method  = $Method
        Headers = $headers
    }
    
    if ($Body) {
        $params.Body = ($Body | ConvertTo-Json -Depth 10)
    }
    
    try {
        $response = Invoke-RestMethod @params
        return $response
    }
    catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        if ($statusCode -eq 409) {
            return @{ AlreadyExists = $true }
        }
        throw
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# Main deployment
# ─────────────────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Magenta
Write-Host "  Fraud Alert Deployment — Fabric Data Activator" -ForegroundColor Magenta
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Magenta

# ── Step 1: Authenticate ─────────────────────────────────────────────────────
Write-Step "Authenticating with Azure / Fabric"

$fabricToken = Get-FabricAccessToken
Write-Success "Fabric token acquired"

# ── Step 2: Find Fabric Workspace ────────────────────────────────────────────
Write-Step "Finding Fabric workspace: $FabricWorkspaceName"

$workspaces = Invoke-FabricApi -Method GET -Path "/workspaces" -Token $fabricToken
$workspace = $workspaces.value | Where-Object { $_.displayName -eq $FabricWorkspaceName }

if (-not $workspace) {
    throw "Workspace '$FabricWorkspaceName' not found."
}

$workspaceId = $workspace.id
Write-Success "Found workspace: $workspaceId"

# ── Step 3: Find Eventhouse / KQL Database ───────────────────────────────────
Write-Step "Finding KQL database: $KqlDatabaseName"

$items = Invoke-FabricApi -Method GET -Path "/workspaces/$workspaceId/items" -Token $fabricToken
$kqlDb = $items.value | Where-Object { $_.displayName -eq $KqlDatabaseName -and $_.type -eq "KQLDatabase" }

if (-not $kqlDb) {
    # Try to find by Eventhouse name
    $eventhouse = $items.value | Where-Object { $_.displayName -eq $KqlDatabaseName -and $_.type -eq "Eventhouse" }
    if ($eventhouse) {
        Write-Info "Found Eventhouse, looking for associated KQL database..."
        $kqlDb = $items.value | Where-Object { $_.type -eq "KQLDatabase" } | Select-Object -First 1
    }
}

if (-not $kqlDb) {
    throw "KQL Database '$KqlDatabaseName' not found in workspace."
}

$kqlDbId = $kqlDb.id
Write-Success "Found KQL database: $kqlDbId"

# ── Step 4: Find Eventstream ─────────────────────────────────────────────────
Write-Step "Finding Eventstream: $EventstreamName"

$eventstream = $items.value | Where-Object { $_.displayName -eq $EventstreamName -and $_.type -eq "Eventstream" }

if (-not $eventstream) {
    throw "Eventstream '$EventstreamName' not found in workspace."
}

$eventstreamId = $eventstream.id
Write-Success "Found Eventstream: $eventstreamId"

# ── Step 5: Create Reflex (Data Activator) ───────────────────────────────────
Write-Step "Creating Reflex: $ReflexName"

$existingReflex = $items.value | Where-Object { $_.displayName -eq $ReflexName -and $_.type -eq "Reflex" }

if ($existingReflex) {
    Write-Warning "Reflex '$ReflexName' already exists (ID: $($existingReflex.id))"
    $reflexId = $existingReflex.id
}
else {
    $reflexBody = @{
        displayName = $ReflexName
        type        = "Reflex"
    }
    
    $result = Invoke-FabricApi -Method POST -Path "/workspaces/$workspaceId/items" -Body $reflexBody -Token $fabricToken
    
    if ($result.AlreadyExists) {
        Write-Warning "Reflex '$ReflexName' already exists"
        $reflexId = ($items.value | Where-Object { $_.displayName -eq $ReflexName }).id
    }
    else {
        $reflexId = $result.id
        Write-Success "Created Reflex: $reflexId"
    }
}

# ── Step 6: Deploy Azure Logic App (optional) ────────────────────────────────
$logicAppWebhookUrl = $null

if ($DeployLogicApp) {
    Write-Step "Deploying Azure Logic App for advanced email templating"
    
    if (-not $SubscriptionId) { throw "-SubscriptionId is required when -DeployLogicApp is specified" }
    if (-not $ResourceGroupName) { throw "-ResourceGroupName is required when -DeployLogicApp is specified" }
    if (-not $AlertRecipientEmail) { throw "-AlertRecipientEmail is required when -DeployLogicApp is specified" }
    
    # Set subscription
    az account set --subscription $SubscriptionId
    Write-Success "Using subscription: $SubscriptionId"
    
    # Create resource group if needed
    $rgExists = az group exists --name $ResourceGroupName | ConvertFrom-Json
    if (-not $rgExists) {
        Write-Info "Creating resource group: $ResourceGroupName"
        az group create --name $ResourceGroupName --location $Location | Out-Null
    }
    
    # Deploy Bicep
    $bicepFile = Join-Path (Join-Path $ScriptRoot "infra") "main.bicep"
    if (-not (Test-Path $bicepFile)) {
        throw "Bicep template not found: $bicepFile"
    }
    
    Write-Info "Deploying Logic App via Bicep..."
    
    $deploymentResult = az deployment group create `
        --resource-group $ResourceGroupName `
        --template-file $bicepFile `
        --parameters location=$Location `
        --parameters alertRecipientEmail=$AlertRecipientEmail `
        --parameters appUrl=$InvestigationAppUrl `
        --query "properties.outputs" `
        -o json | ConvertFrom-Json
    
    if ($deploymentResult.logicAppCallbackUrl) {
        $logicAppWebhookUrl = $deploymentResult.logicAppCallbackUrl.value
        Write-Success "Logic App deployed"
        Write-Info "Webhook URL: $logicAppWebhookUrl"
    }
    else {
        Write-Warning "Logic App deployed but callback URL not returned. Get it from the Azure Portal."
    }
    
    Write-Warning "IMPORTANT: Authorize the Office 365 API connection in the Azure Portal:"
    Write-Host "   1. Go to: https://portal.azure.com/#resource/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName" -ForegroundColor Yellow
    Write-Host "   2. Open the API Connection resource (fraud-alert-office365)" -ForegroundColor Yellow
    Write-Host "   3. Click 'Edit API connection' → 'Authorize' → Sign in → Save" -ForegroundColor Yellow
}

# ─────────────────────────────────────────────────────────────────────────────
# Summary and next steps
# ─────────────────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "  Deployment Complete" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Green

Write-Host ""
Write-Host "Summary:" -ForegroundColor White
Write-Host "  • Workspace:    $FabricWorkspaceName ($workspaceId)" -ForegroundColor Gray
Write-Host "  • KQL Database: $KqlDatabaseName ($kqlDbId)" -ForegroundColor Gray
Write-Host "  • Eventstream:  $EventstreamName ($eventstreamId)" -ForegroundColor Gray
Write-Host "  • Reflex:       $ReflexName ($reflexId)" -ForegroundColor Gray
if ($logicAppWebhookUrl) {
    Write-Host "  • Logic App:    $logicAppWebhookUrl" -ForegroundColor Gray
}

Write-Host ""
Write-Host "Portal Links:" -ForegroundColor White
Write-Host "  • Workspace:   https://app.fabric.microsoft.com/groups/$workspaceId" -ForegroundColor Cyan
Write-Host "  • Reflex:      https://app.fabric.microsoft.com/groups/$workspaceId/reflexes/$reflexId" -ForegroundColor Cyan
Write-Host "  • Eventstream: https://app.fabric.microsoft.com/groups/$workspaceId/eventstreams/$eventstreamId" -ForegroundColor Cyan

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Yellow
Write-Host "  MANUAL STEPS REQUIRED" -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Yellow

Write-Host ""
Write-Host "1. CONFIGURE REFLEX — Open the Reflex in the Fabric Portal:" -ForegroundColor White
Write-Host "   https://app.fabric.microsoft.com/groups/$workspaceId/reflexes/$reflexId" -ForegroundColor Cyan
Write-Host ""
Write-Host "   a) Get data → Eventstream → select '$EventstreamName'" -ForegroundColor Gray
Write-Host "   b) Set Stream key = 'user_id'" -ForegroundColor Gray
Write-Host ""
Write-Host "   c) Add KQL-backed properties (see README-fraud-alerts.md):" -ForegroundColor Gray
Write-Host "      • email          — lookup from Customers by user_id" -ForegroundColor Gray
Write-Host "      • customer_name  — Customers first_name + last_name" -ForegroundColor Gray
Write-Host "      • last_5_frauds_html — HTML table from $TransactionsTableName" -ForegroundColor Gray
Write-Host "      • investigation_url — static: $InvestigationAppUrl" -ForegroundColor Gray
Write-Host ""
Write-Host "   d) Create rule: When each event happens" -ForegroundColor Gray
Write-Host "      Condition: is_fraud == `"1`"" -ForegroundColor Gray
Write-Host "      Action: Send email to {email}" -ForegroundColor Gray
Write-Host ""
Write-Host "   e) Click 'Start' to activate the rule" -ForegroundColor Gray

if ($logicAppWebhookUrl) {
    Write-Host ""
    Write-Host "2. (OPTIONAL) USE LOGIC APP FOR ADVANCED EMAILS:" -ForegroundColor White
    Write-Host "   Instead of the built-in email action, use 'Custom action' and" -ForegroundColor Gray
    Write-Host "   paste the Logic App webhook URL:" -ForegroundColor Gray
    Write-Host "   $logicAppWebhookUrl" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "2. TEST — Run Generate_Credit_Card_Transactions.ipynb to stream" -ForegroundColor White
Write-Host "   transactions. Fraudulent events (is_fraud=1) should trigger" -ForegroundColor Gray
Write-Host "   email alerts to the affected cardholder." -ForegroundColor Gray

Write-Host ""
Write-Host "Documentation: $ScriptRoot\README-fraud-alerts.md" -ForegroundColor Gray
Write-Host ""
