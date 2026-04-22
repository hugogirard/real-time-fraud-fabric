# Fabric Activator (Reflex) Setup — Fraud Alert to Power Automate

This guide walks through configuring a **Fabric Data Activator** (Reflex) item
that monitors the Eventhouse for fraudulent transactions and triggers a
**Power Automate / Azure Logic App** to send customized email alerts.

---

## Prerequisites

| Component | Details |
|-----------|---------|
| **Eventhouse** | KQL database with `Transactions` and `Customers` tables populated |
| **Eventstream** | Streaming transactions into the Eventhouse |
| **Logic App** | Deployed via the Bicep template in `infra/` (provides the HTTP webhook URL) |

---

## Step 1 — Create the Reflex Item

1. In your **Fabric workspace**, click **+ New item → Activator**.
2. Name it `reflex-fraud-alerts`.
3. Click **Create**.

---

## Step 2 — Connect to the Eventhouse

1. In the Activator canvas, click **Get data → Eventhouse (KQL Database)**.
2. Select your **Eventhouse** and **KQL database**.
3. Paste the KQL query from [`fraud-detection-alert.kql`](./fraud-detection-alert.kql):

```kql
Transactions
| where is_fraud == 1
| join kind=inner Customers on user_id
| project
    transaction_id,
    user_id,
    display_name,
    email,
    first_name,
    last_name,
    amount,
    merchant_name,
    merchant_category,
    merchant_city,
    merchant_state,
    fraud_type,
    distance_from_home_km,
    hour_of_day,
    day_of_week,
    amount_zscore,
    txn_count_last_1h,
    txn_count_last_24h,
    stream_timestamp,
    home_city,
    home_state,
    credit_limit
| order by stream_timestamp desc
```

4. Click **Connect**.

---

## Step 3 — Define the Trigger Object

1. In the **Design** tab, under **Objects**, select `transaction_id` as the
   **unique key** for the object.
2. Set `user_id` as the **Group by** field (so alerts aggregate per cardholder).

---

## Step 4 — Create the Trigger Condition

1. Click **New Trigger** on the object.
2. Name the trigger: `Fraud Detected`.
3. Set the condition:
   - **Detect when** → `is_fraud` **becomes** `1`
   - Or use: **Detect when** → `amount` **is greater than** `0` (since the query
     already filters to `is_fraud == 1`, any row that appears is a fraud event).
4. Optionally set a **time window** (e.g., evaluate every 1 minute).

---

## Step 5 — Configure the Action (Call Power Automate / Logic App)

1. Under the trigger, click **Act** → **Start a Power Automate flow**.

   > **Option A — Custom Endpoint (recommended for Logic Apps):**  
   > Select **Custom action** and enter the **HTTP POST URL** from your
   > deployed Logic App. This URL is output by the Bicep deployment
   > (`logicAppCallbackUrl`).

   > **Option B — Native Power Automate:**  
   > Select **Start a Power Automate flow** and connect your Power Automate
   > account. Then select the flow created from the Logic App deployment.

2. Map the following fields from the trigger payload to the action:

   | Field | Description |
   |-------|-------------|
   | `transaction_id` | Unique fraud transaction ID |
   | `display_name` | Customer full name |
   | `email` | Customer email (recipient) |
   | `amount` | Transaction amount |
   | `merchant_name` | Merchant name |
   | `merchant_category` | Merchant category |
   | `merchant_city` | Merchant city |
   | `fraud_type` | Type of fraud detected |
   | `distance_from_home_km` | Distance from customer home |
   | `stream_timestamp` | When the transaction occurred |
   | `credit_limit` | Customer's credit limit |

3. Click **Save**.

---

## Step 6 — Activate the Trigger

1. Click **Start** (play button) on the Reflex item to activate monitoring.
2. The Activator will now evaluate the KQL query at the configured interval.
3. When a fraud transaction is detected, it sends an HTTP POST to your Logic App,
   which formats and sends a customized email alert.

---

## Testing

1. Run `Generate_Credit_Card_Transactions.ipynb` to stream transactions
   (including ~4% fraud) into the Eventstream.
2. Watch the **Reflex monitoring** pane for triggered alerts.
3. Check the target inbox for formatted fraud alert emails.

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| No triggers firing | Verify the Reflex is **Started** and the Eventhouse has fraud data |
| HTTP 401/403 from Logic App | Check the Logic App callback URL is correct and active |
| Emails not arriving | Verify the Office 365 API connection is authorized in the Logic App |
| Duplicate alerts | Adjust the trigger's **time window** or add deduplication in the KQL query |
