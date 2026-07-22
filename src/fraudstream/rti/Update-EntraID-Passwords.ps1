<#
.SYNOPSIS
    Resets passwords and disables force-change-password-next-sign-in for Entra ID
    users listed in a CSV file.

.DESCRIPTION
    This script reads a CSV file containing user Email addresses, resets each user's
    password to the specified value, and removes the requirement to change password
    at next sign-in.

    Prerequisites:
      - Azure CLI installed and logged in (az login)
      - Sufficient privileges to reset passwords (User Administrator or Global Administrator)

.PARAMETER CsvPath
    Path to a CSV file containing at least an Email column with UPNs.
    Defaults to "customers.csv" in the same directory as the script.

.PARAMETER NewPassword
    The new password to set for all users.

.EXAMPLE
    .\Update-EntraID-Passwords.ps1 -NewPassword (ConvertTo-SecureString "NewP@ss!456" -AsPlainText -Force)

.EXAMPLE
    .\Update-EntraID-Passwords.ps1 -CsvPath "C:\data\customers.csv" -NewPassword (ConvertTo-SecureString "NewP@ss!456" -AsPlainText -Force)
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$CsvPath,

    [Parameter(Mandatory = $true)]
    [SecureString]$NewPassword
)

# Auto-detect latest customers_*.csv if no path specified
if (-not $CsvPath) {
    $csvFiles = Get-ChildItem -Path $PSScriptRoot -Filter "customers_*.csv" | Sort-Object Name
    if ($csvFiles) {
        $CsvPath = $csvFiles[-1].FullName
    } else {
        $CsvPath = Join-Path $PSScriptRoot "customers.csv"
    }
}

# Convert SecureString to plain text for az CLI
$PlainPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($NewPassword)
)

# ── Load users from CSV ───────────────────────────────────────────────
if (-not (Test-Path $CsvPath)) {
    Write-Error "CSV file not found: $CsvPath"
    exit 1
}
$customers = Import-Csv -Path $CsvPath

Write-Host "============================================" -ForegroundColor Cyan
Write-Host " Entra ID Password Update Script" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "CSV file: $CsvPath"
Write-Host "Users to update: $($customers.Count)"
Write-Host ""

# ── Check for Azure CLI ───────────────────────────────────
$azAvailable = Get-Command az -ErrorAction SilentlyContinue
if (-not $azAvailable) {
    Write-Error "Azure CLI (az) is not installed or not in PATH. Install from https://aka.ms/installazurecli"
    exit 1
}

# Verify login
az account show --output none 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Not logged in. Running 'az login'..." -ForegroundColor Yellow
    az login --output none
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Azure login failed. Please run 'az login' manually."
        exit 1
    }
}

# ── Update passwords ─────────────────────────────────────
$updated = 0
$notFound = 0
$failed = 0

foreach ($customer in $customers) {
    $upn = $customer.email
    $displayName = "$($customer.first_name) $($customer.last_name)"

    Write-Host "Processing: $displayName ($upn)..." -NoNewline

    # Check if user exists
    az ad user show --id $upn --output none 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host " NOT FOUND" -ForegroundColor Yellow
        $notFound++
        continue
    }

    # Reset password and disable force-change-password-next-sign-in
    $errorOutput = az ad user update `
        --id $upn `
        --password $PlainPassword `
        --force-change-password-next-sign-in false `
        --output none 2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-Host " UPDATED" -ForegroundColor Green
        $updated++
    } else {
        Write-Host " FAILED" -ForegroundColor Red
        Write-Host "    Error: $errorOutput" -ForegroundColor DarkRed
        $failed++
    }
}

# ── Summary ───────────────────────────────────────────────
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host " Summary" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Updated:   $updated" -ForegroundColor Green
Write-Host "  Not found: $notFound" -ForegroundColor Yellow
Write-Host "  Failed:    $failed" -ForegroundColor Red
Write-Host ""
Write-Host "Passwords have been reset and force-change-password-next-sign-in is disabled."
