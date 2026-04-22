// ============================================================
// Logic App — Fraud Alert Email Sender
// ============================================================
// Deploys a Consumption Logic App with:
//   1. HTTP trigger (webhook endpoint for Fabric Activator)
//   2. Compose action (builds a rich HTML email body)
//   3. Send email via Office 365 Outlook connector
//
// After deployment, authorize the Office 365 API connection
// in the Azure Portal, then copy the Logic App callback URL
// into the Fabric Activator custom action.
// ============================================================

@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('Name prefix for resources.')
param namePrefix string = 'fraud-alert'

@description('Email address to receive fraud alert notifications.')
param alertRecipientEmail string

// ── Variables ─────────────────────────────────────────────
var logicAppName = '${namePrefix}-logic-app'
var office365ConnectionName = '${namePrefix}-office365'

// ── Office 365 API Connection ─────────────────────────────
resource office365Connection 'Microsoft.Web/connections@2016-06-01' = {
  name: office365ConnectionName
  location: location
  properties: {
    displayName: 'Office 365 Outlook — Fraud Alerts'
    api: {
      id: subscriptionResourceId(
        'Microsoft.Web/locations/managedApis',
        location,
        'office365'
      )
    }
  }
}

// ── Logic App (Consumption) ───────────────────────────────
resource logicApp 'Microsoft.Logic/workflows@2019-05-01' = {
  name: logicAppName
  location: location
  properties: {
    state: 'Enabled'
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      contentVersion: '1.0.0.0'
      parameters: {
        '$connections': {
          defaultValue: {}
          type: 'Object'
        }
        alertRecipientEmail: {
          defaultValue: alertRecipientEmail
          type: 'String'
        }
      }
      triggers: {
        When_Fabric_Activator_detects_fraud: {
          type: 'Request'
          kind: 'Http'
          inputs: {
            schema: {
              type: 'object'
              properties: {
                transaction_id: { type: 'string' }
                user_id: { type: 'string' }
                display_name: { type: 'string' }
                email: { type: 'string' }
                first_name: { type: 'string' }
                last_name: { type: 'string' }
                amount: { type: 'number' }
                merchant_name: { type: 'string' }
                merchant_category: { type: 'string' }
                merchant_city: { type: 'string' }
                merchant_state: { type: 'string' }
                fraud_type: { type: 'string' }
                distance_from_home_km: { type: 'number' }
                hour_of_day: { type: 'integer' }
                day_of_week: { type: 'integer' }
                amount_zscore: { type: 'number' }
                txn_count_last_1h: { type: 'integer' }
                txn_count_last_24h: { type: 'integer' }
                stream_timestamp: { type: 'string' }
                home_city: { type: 'string' }
                home_state: { type: 'string' }
                credit_limit: { type: 'number' }
              }
            }
          }
        }
      }
      actions: {
        Compose_Email_Body: {
          type: 'Compose'
          runAfter: {}
          inputs: '''<!DOCTYPE html>
<html>
<head>
<style>
  body { font-family: "Segoe UI", Arial, sans-serif; margin: 0; padding: 0; background-color: #f4f4f4; }
  .container { max-width: 640px; margin: 20px auto; background: #ffffff; border-radius: 8px; overflow: hidden; box-shadow: 0 2px 8px rgba(0,0,0,0.1); }
  .header { background: linear-gradient(135deg, #c0392b, #e74c3c); color: #ffffff; padding: 24px 32px; }
  .header h1 { margin: 0; font-size: 22px; font-weight: 600; }
  .header p { margin: 6px 0 0; font-size: 14px; opacity: 0.9; }
  .alert-badge { display: inline-block; background: #ffffff; color: #c0392b; font-weight: 700; font-size: 12px; padding: 4px 12px; border-radius: 12px; margin-top: 10px; text-transform: uppercase; letter-spacing: 0.5px; }
  .body-content { padding: 24px 32px; }
  .section-title { font-size: 14px; font-weight: 600; color: #7f8c8d; text-transform: uppercase; letter-spacing: 0.5px; margin: 20px 0 10px; border-bottom: 2px solid #ecf0f1; padding-bottom: 6px; }
  .section-title:first-child { margin-top: 0; }
  .detail-table { width: 100%; border-collapse: collapse; }
  .detail-table td { padding: 8px 0; font-size: 14px; vertical-align: top; }
  .detail-table td:first-child { color: #7f8c8d; width: 180px; font-weight: 500; }
  .detail-table td:last-child { color: #2c3e50; font-weight: 400; }
  .amount-highlight { font-size: 28px; font-weight: 700; color: #c0392b; }
  .fraud-type-badge { display: inline-block; background: #fdf2f2; color: #c0392b; font-weight: 600; font-size: 13px; padding: 4px 14px; border-radius: 6px; border: 1px solid #f5c6cb; }
  .risk-indicators { background: #fff9f0; border: 1px solid #fdebd0; border-radius: 6px; padding: 14px 18px; margin: 16px 0; }
  .risk-indicators h4 { margin: 0 0 8px; color: #e67e22; font-size: 13px; text-transform: uppercase; letter-spacing: 0.5px; }
  .risk-indicators ul { margin: 0; padding-left: 18px; font-size: 13px; color: #7f6c3e; }
  .risk-indicators li { margin-bottom: 4px; }
  .footer { background: #f8f9fa; padding: 18px 32px; text-align: center; font-size: 12px; color: #95a5a6; border-top: 1px solid #ecf0f1; }
  .footer a { color: #3498db; text-decoration: none; }
</style>
</head>
<body>
<div class="container">
  <!-- Header -->
  <div class="header">
    <h1>Fraud Alert — Suspicious Transaction Detected</h1>
    <p>Real-Time Intelligence &bull; Microsoft Fabric</p>
    <span class="alert-badge">Immediate Action Required</span>
  </div>

  <div class="body-content">
    <!-- Transaction Details -->
    <div class="section-title">Transaction Details</div>
    <table class="detail-table">
      <tr><td>Transaction ID</td><td><code>@{triggerBody()?['transaction_id']}</code></td></tr>
      <tr><td>Amount</td><td><span class="amount-highlight">$@{triggerBody()?['amount']}</span></td></tr>
      <tr><td>Merchant</td><td>@{triggerBody()?['merchant_name']}</td></tr>
      <tr><td>Category</td><td>@{triggerBody()?['merchant_category']}</td></tr>
      <tr><td>Location</td><td>@{triggerBody()?['merchant_city']}, @{triggerBody()?['merchant_state']}</td></tr>
      <tr><td>Timestamp</td><td>@{triggerBody()?['stream_timestamp']}</td></tr>
      <tr><td>Fraud Type</td><td><span class="fraud-type-badge">@{triggerBody()?['fraud_type']}</span></td></tr>
    </table>

    <!-- Cardholder Information -->
    <div class="section-title">Cardholder Information</div>
    <table class="detail-table">
      <tr><td>Name</td><td>@{triggerBody()?['display_name']}</td></tr>
      <tr><td>Email</td><td>@{triggerBody()?['email']}</td></tr>
      <tr><td>User ID</td><td><code>@{triggerBody()?['user_id']}</code></td></tr>
      <tr><td>Home Location</td><td>@{triggerBody()?['home_city']}, @{triggerBody()?['home_state']}</td></tr>
      <tr><td>Credit Limit</td><td>$@{triggerBody()?['credit_limit']}</td></tr>
    </table>

    <!-- Risk Indicators -->
    <div class="section-title">Risk Indicators</div>
    <div class="risk-indicators">
      <h4>Why this was flagged</h4>
      <ul>
        <li><strong>Distance from home:</strong> @{triggerBody()?['distance_from_home_km']} km</li>
        <li><strong>Amount z-score:</strong> @{triggerBody()?['amount_zscore']} (standard deviations from mean)</li>
        <li><strong>Transactions in last hour:</strong> @{triggerBody()?['txn_count_last_1h']}</li>
        <li><strong>Transactions in last 24h:</strong> @{triggerBody()?['txn_count_last_24h']}</li>
        <li><strong>Hour of day:</strong> @{triggerBody()?['hour_of_day']}:00</li>
      </ul>
    </div>
  </div>

  <!-- Footer -->
  <div class="footer">
    This alert was generated automatically by <strong>Fabric Real-Time Intelligence</strong>
    via Data Activator.<br/>
    Investigate this transaction in the Fabric workspace or contact the Fraud Operations team.
  </div>
</div>
</body>
</html>'''
        }
        Send_Fraud_Alert_Email: {
          type: 'ApiConnection'
          runAfter: {
            Compose_Email_Body: [
              'Succeeded'
            ]
          }
          inputs: {
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'office365\'][\'connectionId\']'
              }
            }
            method: 'post'
            path: '/v2/Mail'
            body: {
              To: '@{parameters(\'alertRecipientEmail\')}'
              Subject: 'FRAUD ALERT — $@{triggerBody()?[\'amount\']} at @{triggerBody()?[\'merchant_name\']} (@{triggerBody()?[\'display_name\']})'
              Body: '@{outputs(\'Compose_Email_Body\')}'
              IsHtml: true
              Importance: 'High'
            }
          }
        }
        Response_200: {
          type: 'Response'
          runAfter: {
            Send_Fraud_Alert_Email: [
              'Succeeded'
            ]
          }
          inputs: {
            statusCode: 200
            body: {
              status: 'Alert email sent'
              transaction_id: '@triggerBody()?[\'transaction_id\']'
            }
          }
        }
      }
      outputs: {}
    }
    parameters: {
      '$connections': {
        value: {
          office365: {
            connectionId: office365Connection.id
            connectionName: office365Connection.name
            id: subscriptionResourceId(
              'Microsoft.Web/locations/managedApis',
              location,
              'office365'
            )
          }
        }
      }
    }
  }
}

// ── Outputs ───────────────────────────────────────────────
output logicAppName string = logicApp.name
output logicAppResourceId string = logicApp.id
output office365ConnectionName string = office365Connection.name

// The callback URL is generated after deployment.
// Retrieve it via: az resource show --ids <logicAppId>/triggers/When_Fabric_Activator_detects_fraud --query properties.callbackUrl -o tsv
// Or use the listCallbackUrl output below.
output logicAppTriggerId string = '${logicApp.id}/triggers/When_Fabric_Activator_detects_fraud'
