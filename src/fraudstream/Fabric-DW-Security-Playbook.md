# Microsoft Fabric Data Warehouse Security Playbook

## L400/L500 Security Implementation for Fabric Data Warehouse

This playbook provides two prescriptive implementation tracks for applying an enterprise (L400) and engineering-deep (L500) security configuration to a Microsoft Fabric Data Warehouse (Warehouse + SQL analytics endpoint) workspace.

The goal is to achieve a defensible, audit-ready posture using **defense-in-depth**:

- **Identity controls** — Microsoft Entra Conditional Access
- **Inbound network protection** — Private Link and/or workspace IP firewall
- **Outbound data exfiltration control** — Outbound Access Protection (OAP)
- **Least-privilege authorization** — in the Warehouse itself

> **Assumptions:** Your Warehouse is hosted in a dedicated "secure DW" workspace on Fabric capacity, and Azure networking teams can provision Private Endpoints and DNS as needed.

---

## Part 1 (L400): Step-by-Step Approach (Best-Practice Prescriptive)

### Step 1 — Prerequisites and Design Decisions

**Objective:** Define the workspace boundary, network model, and operating model so you don't have to re-architect after OAP/Private Link is enabled.

**Required roles:** Fabric tenant admin, workspace admin, Azure networking admin, DW data owner (separation of duties recommended).

**Mandatory actions:**

1. **Confirm scope** — this runbook applies to a single Fabric workspace containing a Warehouse and/or SQL analytics endpoint. Treat the workspace as the security boundary.
2. **Choose inbound model** (pick one per workspace):
   - *Preferred:* workspace-level Private Link + deny public access
   - *Fallback:* workspace IP firewall allow-list (only if Private Link cannot be used for all clients)
3. **Choose outbound model** — enable Outbound Access Protection (OAP) for production DW workspaces.
4. **Design around DW OAP constraints now** — with OAP enabled, Warehouse outbound connections are blocked and exceptions are not currently available; plan to stage ingestion data inside the same workspace (OneLake-based patterns) before loading.
5. **Confirm capacity eligibility** — place the workspace on the required Fabric capacity to support workspace-level inbound rules (per Microsoft guidance).
6. **Define identities and ownership** — list (a) break-glass admin, (b) engineering owners, (c) automation identity, (d) reader groups. Pre-create groups in Entra and avoid individual user grants where possible.
7. **Define evidence storage** — create an "Audit Evidence" location and a change ticket template for every network/security change.

> **Anti-pattern:** Don't build production ingestion that depends on Warehouse pulling from external endpoints if you intend to enable OAP; don't rely on SQL permissions alone as a substitute for inbound network controls.

**Exit criteria (must be true before Step 2):** inbound model selected, outbound model selected, roles assigned, and a written decision on how data will be staged into the DW workspace under OAP.

---

### Step 2 — Establish Identity Guardrails (Microsoft Entra Conditional Access)

**Objective:** Ensure every human access path to the DW workspace meets Zero Trust requirements before network controls are evaluated.

**Required roles:** Entra Conditional Access admin (or Global Security admin) + Fabric tenant admin for verification.

**Minimum required policy set:**

| # | Policy | Details |
|---|--------|---------|
| 1 | **MFA policy** (all users) | Require MFA for all interactive users accessing Fabric, including administrators |
| 2 | **Privileged access policy** | For Fabric/workspace admins: require compliant device + MFA (step-up) and enforce PIM for role activation (time-bound) |
| 3 | **Location/risk policy** | Restrict access to trusted locations (corporate egress/VPN) or enforce risk-based sign-in controls |
| 4 | **App scope** (best practice) | Use one coherent policy set covering Fabric (Power BI) and dependent services |

**Implementation requirements:**

- **Break-glass accounts:** Maintain 1–2 emergency accounts with strong controls and separate monitoring; exclude them from Conditional Access only if your standard requires it and document the reason.
- **Automation identities:** Conditional Access does not protect service principals the same way it protects users; enforce least privilege + strong credential hygiene (certificates), and compensate with network boundary controls and audit logging.
- **Group-based targeting:** Target Entra groups (Admins, Engineers, Readers) instead of individuals.

**Validation:** Perform a sign-in test for each persona (Admin, Engineer, Reader) and confirm expected MFA/device/location prompts are enforced.

**Evidence to capture:** Conditional Access policy export (JSON or screenshots), targeted groups list, and test sign-in results (date/time + tester + outcome).

---

### Step 3 — Lock Down Inbound Access (Private Link or IP Firewall)

**Objective:** Ensure the DW workspace cannot be reached from untrusted networks.

**Required roles:** Fabric tenant admin, workspace admin, Azure networking admin.

#### Option A: Workspace-Level Private Link (Recommended)

1. **Tenant admin:** enable "Configure workspace-level inbound network rules"
2. **Workspace admin:** create/confirm the dedicated DW workspace exists and is on the intended capacity
3. **Workspace admin:** set inbound networking to allow connections only via workspace private link (do this after DNS validation to avoid lockout)
4. **Azure networking:** create the private endpoint to the workspace private link service in the approved VNet/subnet
5. **Workspace admin:** approve the private endpoint connection request in workspace settings
6. **Azure networking:** configure private DNS/split-horizon DNS so workspace FQDN resolves to the private endpoint IP from approved networks
7. **Lockdown step:** once private name resolution and connectivity succeed, deny inbound public access

#### Option B: Workspace IP Firewall (Fallback)

1. **Tenant admin:** enable "Configure workspace-level inbound network rules"
2. **Network team:** provide a minimal allow-list of corporate/VPN egress CIDRs
3. **Workspace admin:** configure workspace IP firewall rules (use CIDR blocks)
4. **Change control:** create a ticket/approval workflow for any firewall updates

**Validation:**

- **Positive test:** from an approved network path, access Fabric UI and connect to Warehouse; run `SELECT 1`
- **Negative test:** from an unapproved network path, confirm access is blocked and record the error
- **DNS test (Private Link):** confirm name resolution returns the private endpoint IP from inside the VNet/VPN path

---

### Step 4 — Enable Outbound Controls (OAP)

**Objective:** Prevent data exfiltration by making outbound connectivity from the DW workspace default-deny.

**Required roles:** Fabric tenant admin, workspace admin, DW owner.

**Enable OAP:**

1. **Tenant admin:** enable "Configure workspace-level outbound network rules"
2. **Workspace admin:** enable OAP on the DW workspace and record the change ticket and approver
3. **Workspace admin:** communicate the operational impact: Warehouse/SQL endpoint outbound is blocked and exceptions are not currently available

**DW-safe loading pattern:**

1. **Land:** ingest files into OneLake in the same DW workspace
2. **Validate:** run schema/quality checks on the staged data before loading
3. **Load:** use Warehouse load commands that reference the workspace-local OneLake location
4. **Promote:** move data from staging schemas to curated schemas via stored procedures

---

### Step 5 — Harden Warehouse Authorization (Least Privilege)

**Objective:** Ensure only approved personas can administer, load, and query the DW.

| Persona | Access Level |
|---------|-------------|
| **Admins** | Very small set; time-bound elevation preferred |
| **Engineers** | Can deploy schema + procedures; no broad data reader grants by default |
| **Automation identity** | Execute-only on ingestion procedures; no admin |
| **Readers** | SELECT on curated views/schemas only |

**Implementation sequence:**

1. Assign workspace roles (Admin/Member/Contributor only to engineering owners; Viewer for consumption)
2. Create SQL roles: `dw_readers`, `dw_loaders`, (optionally `dw_owners`)
3. Grant access via schemas/views (not raw tables)
4. Use views as the default contract
5. Apply RLS/column security where supported
6. Test each persona end-to-end

---

### Step 6 — Monitoring, Auditing, and Recurring Controls

**Objective:** Maintain an audit-ready posture and detect misuse quickly.

| Cadence | Action |
|---------|--------|
| **Daily/Weekly** | Review security-relevant audit events for admin actions and sharing/permission changes |
| **Monthly** | Validate inbound config state; confirm OAP remains enabled |
| **Quarterly** | Formal access reviews (workspace roles + SQL roles); remove stale access; re-test persona access |
| **Per change** | Ticket + approver + implementation timestamp + validation results |

---

## Part 2 (L500): Scripting-Only Implementation (Engineering-Deep)

Use this section for an infrastructure-as-code style rollout. Replace placeholders with your values. Where an API is not available, treat that step as "manual approval required" and keep the rest of the workflow scripted and repeatable.

---

### Scripting Best Practices

Apply these principles to **all** sections below:

1. **Treat as IaC** — store scripts + templates in source control; use PR review; tag releases
2. **Never hardcode secrets** — use Managed Identity where possible; otherwise use certificate-based auth and retrieve secrets from a vault at runtime (no secrets in logs)
3. **Make scripts idempotent** — "create-if-missing / update-if-drift"; re-runs must be safe
4. **Enable strict error handling** — PowerShell: `Set-StrictMode -Version Latest; $ErrorActionPreference = 'Stop'`; Azure CLI: check exit codes, fail fast on non-zero
5. **Add structured logging + transcripts** — write a timestamped log file; capture request IDs where available
6. **Add retries for transient errors** (429/5xx) — exponential backoff; stop after a bounded number of attempts
7. **Validate inputs before changes** — tenant/subscription/workspace IDs, region, RG/VNet/Subnet existence
8. **Separate duties** — keep "approve" steps as explicit checkpoints requiring a human approver; do not silently auto-approve in production
9. **Capture evidence automatically** — export effective config state after each step into an artifacts folder

---

### Step 0 — Define Variables

Set all environment-specific variables upfront. Replace each placeholder with your actual values.

```powershell
$TenantId       = "TENANT_ID"
$Subscription   = "SUBSCRIPTION_ID"
$ResourceGroup  = "RG-Fabric-Networking"
$Location       = "REGION"            # e.g. eastus, westeurope
$VnetName       = "VNET-NAME"
$SubnetName     = "SUBNET-NAME"
$WorkspaceId    = "WORKSPACE_ID"      # Fabric workspace GUID
$WorkspaceName  = "WORKSPACE_NAME"

# Artifacts (evidence) output
$RunId        = (Get-Date).ToString('yyyyMMdd-HHmmss')
$ArtifactsDir = Join-Path (Get-Location) ("artifacts-" + $RunId)
New-Item -ItemType Directory -Path $ArtifactsDir -Force | Out-Null
```

---

### Step 1 — Runtime Safety (PowerShell)

Enable strict mode, start a transcript for audit trail, and define a retry helper for transient failures.

```powershell
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Start-Transcript -Path (Join-Path $ArtifactsDir "run-transcript.txt") -Force

function Invoke-WithRetry {
    param(
        [scriptblock]$Script,
        [int]$MaxAttempts = 6,
        [int]$BaseDelaySeconds = 2
    )
    for ($i = 1; $i -le $MaxAttempts; $i++) {
        try {
            return & $Script
        }
        catch {
            if ($i -eq $MaxAttempts) { throw }
            $delay = [Math]::Min(60, $BaseDelaySeconds * [Math]::Pow(2, $i - 1))
            Start-Sleep -Seconds $delay
        }
    }
}
```

**What this does:**

- `Set-StrictMode -Version Latest` — catches undefined variables and other common scripting mistakes
- `$ErrorActionPreference = 'Stop'` — any non-terminating error becomes a terminating error (fail fast)
- `Start-Transcript` — records all console output to a timestamped log file for audit evidence
- `Invoke-WithRetry` — wraps any script block with exponential backoff retry logic (up to 6 attempts, max 60 seconds delay)

---

### Step 2 — Sign In and Set Context

Authenticate to both Azure PowerShell and Azure CLI, then set the target subscription. Capture login evidence.

```powershell
# PowerShell (Az module)
Invoke-WithRetry { Connect-AzAccount -Tenant $TenantId }
Set-AzContext -Subscription $Subscription

# Azure CLI
az login --tenant $TenantId | Out-File (Join-Path $ArtifactsDir "az-login.json")
az account set --subscription $Subscription
az account show | Out-File (Join-Path $ArtifactsDir "az-account.json")
```

**What this does:**

- Authenticates interactively to both Az PowerShell and Azure CLI using the specified tenant
- Sets the active subscription for all subsequent commands
- Saves the CLI login response and account context as JSON evidence artifacts

---

### Step 3 — Tenant-Level Prerequisites (Manual Checkpoint)

> **⚠ MANUAL STEP — Requires Fabric Tenant Admin**

These settings must be enabled in the **Fabric Admin Portal** before proceeding. If no API is available in your tenant, perform the changes manually and capture evidence.

**Required actions:**

1. Enable **"Configure workspace-level inbound network rules"** in the Fabric admin portal
2. Enable **"Configure workspace-level outbound network rules"** in the Fabric admin portal

**Evidence to capture:**

- Screenshot or export of the tenant setting state **before** and **after** the change
- Change ticket number and approver name
- Store all evidence in `$ArtifactsDir`

---

### Step 4 — Workspace-Level Private Link (Preferred Inbound)

Deploy the private endpoint infrastructure in a repeatable, idempotent manner.

#### Step 4.0 — Pre-Flight Checks

Validate that the target resource group, VNet, and subnet all exist before making any changes.

```powershell
# Validate RG exists
az group show -n $ResourceGroup `
    | Out-File (Join-Path $ArtifactsDir "rg.json")

# Validate VNet exists
az network vnet show -g $ResourceGroup -n $VnetName `
    | Out-File (Join-Path $ArtifactsDir "vnet.json")

# Validate Subnet exists
az network vnet subnet show `
    -g $ResourceGroup `
    --vnet-name $VnetName `
    -n $SubnetName `
    | Out-File (Join-Path $ArtifactsDir "subnet.json")
```

> If any of these commands fail, fix the networking prerequisites before continuing.

#### Step 4.1 — Deploy the Fabric Private Link Service (PLS)

Use a Bicep/ARM template stored in source control. The deployment is declarative and idempotent.

```powershell
az deployment group create `
    --resource-group $ResourceGroup `
    --template-file .\fabric-workspace-private-link-service.bicep `
    --parameters workspaceId=$WorkspaceId location=$Location name=$WorkspaceName `
    --mode Incremental `
    --output json | Out-File (Join-Path $ArtifactsDir "pls-deployment.json")
```

**Best practices:**

- Keep templates in source control; parameterize per environment
- Use `--mode Incremental` so existing resources are not deleted
- Save deployment output as evidence

#### Step 4.2 — Set the PLS Resource ID

After the PLS is deployed, capture its resource ID for use in subsequent steps.

```powershell
# REQUIRED: set this to the actual PLS resource ID created in Step 4.1
$plsResourceId = "<PLS_RESOURCE_ID>"
```

#### Step 4.3 — Create Private Endpoint (Idempotent)

Create the private endpoint only if it doesn't already exist.

```powershell
$peName  = "pe-fabric-$WorkspaceName"
$peExists = az network private-endpoint show `
    -g $ResourceGroup -n $peName `
    --query "name" -o tsv 2>$null

if (-not $peExists) {
    az network private-endpoint create `
        --name $peName `
        --resource-group $ResourceGroup `
        --vnet-name $VnetName `
        --subnet $SubnetName `
        --private-connection-resource-id $plsResourceId `
        --group-id "fabric" `
        --connection-name "pec-fabric-$WorkspaceName" `
        --location $Location `
        --output json | Out-File (Join-Path $ArtifactsDir "private-endpoint-create.json")
}
else {
    az network private-endpoint show `
        -g $ResourceGroup -n $peName `
        --output json | Out-File (Join-Path $ArtifactsDir "private-endpoint-existing.json")
}
```

**What this does:**

- Checks if a private endpoint with the expected name already exists
- If **not found** → creates a new private endpoint in the specified VNet/subnet linked to the Fabric PLS
- If **found** → exports the existing endpoint config as evidence (safe re-run)

#### Step 4.4 — Approval Checkpoint (Separation of Duties)

> **⚠ MANUAL STEP — Requires PLS Owner Approval**

Do **NOT** auto-approve in production unless your governance explicitly allows it. Have the PLS owner approve the pending private endpoint connection.

```powershell
# List pending connections
az network private-endpoint-connection list `
    --id $plsResourceId `
    --output json | Out-File (Join-Path $ArtifactsDir "pec-list.json")

# After manual approval, record it:
# az network private-endpoint-connection approve `
#     --id <CONNECTION_ID> `
#     --description "Approved for DW workspace" `
#     --output json | Out-File (Join-Path $ArtifactsDir "pec-approve.json")
```

#### Step 4.5 — Private DNS Validation (Critical)

You **must** verify that the workspace FQDN resolves to the private endpoint IP from approved networks **before** denying public access.

```powershell
# Run from an in-VNet host or over VPN:
nslookup <WORKSPACE_FQDN>
# or
Resolve-DnsName <WORKSPACE_FQDN>

# Record the output as evidence in $ArtifactsDir
```

> **Warning:** If DNS does not resolve correctly, denying public access will lock you out.

#### Step 4.6 — Export Effective Azure State

Always capture the final state of the private endpoint as evidence.

```powershell
az network private-endpoint show `
    -g $ResourceGroup -n $peName `
    --output json | Out-File (Join-Path $ArtifactsDir "private-endpoint-final.json")
```

---

### Step 5 — Deny Inbound Public Access (Workspace Setting)

#### Step 5.0 — Pre-Lockdown Checks (Required)

Complete **all four** checks before proceeding:

| Check | Description | How to Verify |
|-------|-------------|---------------|
| A | Private endpoint is **Approved** in Azure | Check `pec-list.json` from Step 4.4 |
| B | DNS from approved network returns **private IP** | `nslookup` / `Resolve-DnsName` from Step 4.5 |
| C | At least one admin can access workspace via private path | Open Fabric UI from VNet/VPN |
| D | Evidence of A/B/C captured in `$ArtifactsDir` | Verify files exist |

#### Step 5.1 — Apply the Workspace Inbound Setting

> If your tenant has an API, automate it here. Otherwise, apply in **Workspace Settings → Networking**.

**Evidence to store:**

- `before-inbound.json` / screenshot
- `after-inbound.json` / screenshot

#### Step 5.2 — Post-Lockdown Verification (Required)

| Test | Action | Expected Result |
|------|--------|----------------|
| **Positive** | From approved network: access Fabric UI + connect to Warehouse | Access succeeds |
| **Negative** | From unapproved network: attempt to access workspace | Access denied |

---

### Step 6 — Enable Outbound Access Protection (OAP)

#### Step 6.0 — Pre-Flight (Mandatory)

Before enabling OAP, verify:

- [ ] Tenant setting "workspace-level outbound network rules" is enabled
- [ ] Ingestion design is DW-safe under OAP (workspace-local OneLake staging)
- [ ] Rollback plan is documented (note: rollback = disabling OAP; not recommended for prod)
- [ ] Approval record captured and stored in `$ArtifactsDir`

#### Step 6.1 — Enable OAP (API or Manual)

```powershell
# Acquire a Fabric API token
$token = (Get-AzAccessToken -ResourceUrl "https://analysis.windows.net/powerbi/api").Token

# Enable OAP on the workspace (pseudo-REST pattern)
Invoke-WithRetry {
    Invoke-RestMethod -Method Patch `
        -Headers @{ Authorization = "Bearer $token" } `
        -Uri "https://api.powerbi.com/v1.0/myorg/groups/$WorkspaceId/" `
        -Body '{"outboundAccessProtection":"Enabled"}'
}
```

> **Note:** If no REST API is available in your tenant, enable OAP via **Workspace Settings** and capture screenshots as evidence.

#### Step 6.2 — Post-Change Verification (Required)

| Test | Action | Expected Result | Evidence File |
|------|--------|-----------------|---------------|
| **Config** | Confirm OAP is Enabled in workspace settings | Enabled | `oap-after.json` |
| **Negative** | Attempt a known-disallowed outbound operation from Warehouse | Blocked | `oap-negative-test.txt` |
| **Positive** | Run an approved load from workspace-local OneLake staging | Success | `oap-positive-test.txt` |

---

### Step 7 — Optional Fallback: Workspace IP Firewall Allow-List

> Use **only** if Private Link is not feasible for all clients.

#### Step 7.0 — Define Allow-List Input

Store the allow-list as a JSON file in your repository (change-controlled).

```json
[
    { "name": "CorpVPN", "cidr": "203.0.113.0/24" },
    { "name": "HQ",      "cidr": "198.51.100.10/32" }
]
```

#### Step 7.1 — Validate and Load the Allow-List

```powershell
$FirewallAllowlistPath = ".\firewall-allowlist.json"

if (-not (Test-Path $FirewallAllowlistPath)) {
    throw "Missing allow-list file: $FirewallAllowlistPath"
}

Copy-Item $FirewallAllowlistPath `
    (Join-Path $ArtifactsDir "firewall-allowlist-input.json") -Force

# Validate content
$allowlist = Get-Content $FirewallAllowlistPath -Raw | ConvertFrom-Json

if ($allowlist.Count -lt 1) {
    throw "Allow-list must contain at least one CIDR"
}

foreach ($rule in $allowlist) {
    if (-not $rule.name -or -not $rule.cidr) {
        throw "Each rule must include 'name' and 'cidr'"
    }
}
```

**What this does:**

- Verifies the allow-list file exists
- Copies it to the artifacts directory for evidence
- Validates that each entry has both a `name` and `cidr` field
- Fails fast with a clear error message if validation fails

#### Step 7.2 — Apply Firewall Rules

> If an API is available, apply the allow-list programmatically. Otherwise, configure in **Workspace Settings** and attach the allow-list file to the change ticket.

**Always capture before/after state:**

- `firewall-before.json` / screenshot
- `firewall-after.json` / screenshot

#### Step 7.3 — Post-Change Tests (Required)

| Test | Action | Expected Result | Evidence File |
|------|--------|-----------------|---------------|
| **Positive** | From an allowed CIDR: access Fabric UI + connect to Warehouse | Access succeeds | `firewall-positive-test.txt` |
| **Negative** | From a non-allowed IP: attempt to access workspace | Access denied | `firewall-negative-test.txt` |

---

### Step 8 — Warehouse SQL Security Baseline (T-SQL)

Run this T-SQL against the Warehouse to establish the least-privilege role structure.

```sql
-- Create roles
CREATE ROLE dw_readers;
CREATE ROLE dw_loaders;

-- Grant curated schema access to readers
GRANT SELECT ON SCHEMA::curated TO dw_readers;

-- Grant ingestion procedure execution to loaders
GRANT EXECUTE ON SCHEMA::ingest TO dw_loaders;

-- Add identities (replace with your identity model)
-- CREATE USER [user@contoso.com] FROM EXTERNAL PROVIDER;
-- ALTER ROLE dw_readers ADD MEMBER [user@contoso.com];
```

**Principles:**

- Grant via **roles**, never to individual users directly
- Prefer **views** over direct table access
- Avoid broad table-level `SELECT` grants

---

### Step 9 — Validation (Minimum Acceptance Tests)

Run these tests before declaring the implementation complete.

#### Inbound Tests

| # | Test | Command / Action | Expected Result |
|---|------|------------------|-----------------|
| 1 | Connect from approved network | Connect to Warehouse, run `SELECT 1;` | Query returns `1` |
| 2 | Connect from unapproved network | Attempt connection | Connection refused / blocked |
| 3 | DNS resolution (Private Link only) | `nslookup <WORKSPACE_FQDN>` from inside VNet | Returns private endpoint IP |

#### Outbound Tests (OAP)

| # | Test | Command / Action | Expected Result |
|---|------|------------------|-----------------|
| 1 | Disallowed outbound | Attempt external connection from Warehouse | Blocked |
| 2 | Approved local load | Load from workspace-local OneLake staging | Succeeds |

#### Authorization Tests

| # | Persona | Test | Expected Result |
|---|---------|------|-----------------|
| 1 | **Reader** | Query curated views | Succeeds |
| 2 | **Reader** | Query raw/staging tables | Denied |
| 3 | **Automation** | Execute ingestion procedures | Succeeds |
| 4 | **Automation** | Attempt admin actions | Denied |
| 5 | **Admin** | Perform admin action via elevation path | Succeeds |

---

### Step 10 — Evidence Capture (Do Not Skip)

Capture and store with date/time + change ticket:

| Evidence Item | Source Step | Format |
|---------------|-----------|--------|
| Conditional Access policy export | Step 2 (L400) | JSON or screenshots |
| Workspace inbound settings state | Steps 4–5 | JSON / screenshots |
| Private endpoint approvals + DNS proof | Steps 4.4–4.5 | JSON + nslookup output |
| OAP enabled proof + blocked outbound test | Step 6 | JSON + test output |
| SQL role/grant scripts | Step 8 | `.sql` files |
| Persona test outcomes | Step 9 | Test result logs |

```powershell
# Stop the transcript to finalize the evidence log
Stop-Transcript

# List all captured artifacts
Get-ChildItem $ArtifactsDir | Format-Table Name, Length, LastWriteTime
```
