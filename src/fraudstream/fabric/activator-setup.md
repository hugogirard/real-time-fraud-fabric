# Fabric Activator (Reflex) Setup — Fraud Alert to Power Automate

This guide walks through configuring a **Fabric Data Activator** (Reflex) item
that receives enriched fraud events from an **Eventstream** and triggers a
**Power Automate / Azure Logic App** to send customized email alerts **directly
to the affected customer** (with the Fraud Ops team CC'd).

---

## Prerequisites

| Component | Details |
|-----------|---------|
| **Eventhouse** | KQL database with `Transactions` and `Customers` tables populated |
| **Eventstream** | Streaming enriched fraud transactions (filtered to `is_fraud == 1`, joined with `Customers`, includes `fraud_history_html`) |
| **Logic App** | Deployed via the Bicep template in `infra/` (provides the HTTP webhook URL) |

---

## Step 1 — Create the Reflex Item

1. In your **Fabric workspace**, click **+ New item → Activator**.
2. Name it `reflex-fraud-alerts`.
3. Click **Create**.

---

## Step 2 — Connect to the Eventstream

1. In the Activator canvas, click **Get data → Eventstream**.
2. Select your **Eventstream** that carries the enriched fraud events.

   > **Important:** The Eventstream must already be configured to:
   > - Filter transactions to `is_fraud == 1`
   > - Join with the `Customers` table (to include `email`, `display_name`, etc.)
   > - Include the `fraud_history_html` field (built by the KQL query in
   >   [`fraud-detection-alert.kql`](./fraud-detection-alert.kql) and
   >   materialized in the Eventhouse before being routed to the stream)

3. Verify the following columns are present in the Eventstream preview:

   | Column | Example |
   |--------|---------|
   | `transaction_id` | `txn-00042` |
   | `user_id` | `user-007` |
   | `email` | `mark.johnson@contoso.com` |
   | `display_name` | `Mark Johnson` |
   | `amount` | `1245.99` |
   | `merchant_name` | `TechGadgets Inc` |
   | `fraud_type` | `card_not_present` |
   | `fraud_history_html` | `<table>…</table>` |

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
   | `email` | Customer email (**used as the To: recipient**) |
   | `amount` | Transaction amount |
   | `merchant_name` | Merchant name |
   | `merchant_category` | Merchant category |
   | `merchant_city` | Merchant city |
   | `fraud_type` | Type of fraud detected |
   | `distance_from_home_km` | Distance from customer home |
   | `stream_timestamp` | When the transaction occurred |
   | `credit_limit` | Customer's credit limit |
   | `fraud_history_html` | Pre-built HTML table of last 10 fraud txns |

3. Click **Save**.

---

## Step 6 — Activate the Trigger

1. Click **Start** (play button) on the Reflex item to activate monitoring.
2. The Activator will now process events from the Eventstream in real time.
3. When a fraud event arrives, it sends an HTTP POST to your Logic App,
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
| No triggers firing | Verify the Reflex is **Started** and the Eventstream is actively receiving fraud events |
| HTTP 401/403 from Logic App | Check the Logic App callback URL is correct and active |
| Emails not arriving | Verify the Office 365 API connection is authorized in the Logic App |
| Duplicate alerts | Adjust the trigger's **time window** or add deduplication in the KQL query |
