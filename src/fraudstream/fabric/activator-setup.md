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
| **Eventstream** | Raw credit-card transactions streaming in (e.g. from Event Hub) |
| **Logic App** | Deployed via the Bicep template in `infra/` (provides the HTTP webhook URL) |

---

## Part A — Configure the Eventstream (filtering, joins, fraud history)

Before the Activator can receive enriched fraud events you need to build a
processing pipeline **inside the Eventstream** that:

1. Filters raw transactions to fraud only (`is_fraud == 1`)
2. Joins with the `Customers` KQL table to get the customer email
3. Looks up the last 10 fraudulent transactions and renders them as an HTML
   table (`fraud_history_html`)
4. Outputs the enriched events to a **derived stream** that the Activator
   consumes

### A.1 — Open the Eventstream

1. In your **Fabric workspace**, open the Eventstream that ingests raw
   credit-card transactions (e.g. `es-credit-card-transactions`).
2. You should see your **source** (Event Hub / Custom App) on the left and
   one or more destinations on the right.

### A.2 — Add a "Filter" transformation (keep fraud only)

1. In the Eventstream canvas, click the **Transform events** dropdown on the
   toolbar and select **Filter**.
2. Connect the input of the Filter node to your source.
3. Configure the filter:

   | Setting | Value |
   |---------|-------|
   | **Column** | `is_fraud` |
   | **Operator** | `Equal to` |
   | **Value** | `1` |

4. Click **Apply**. The preview should show only fraudulent transactions.

### A.3 — Add a "Join" transformation (enrich with customer data)

> **Concept:** The Eventstream **Join** operator lets you join a real-time
> stream against a KQL table stored in your Eventhouse. This is how we
> attach the customer email, name, home location, and credit limit to each
> fraud event.

1. Click **Transform events → Join**.
2. Connect the input of the Join node to the **output** of the Filter node
   from Step A.2.
3. For the **second input** (the reference / dimension side), click
   **Add source → Eventhouse (KQL Database)** and select:
   - Your **Eventhouse**
   - Your **KQL database**
   - Table: **`Customers`**
4. Configure the join:

   | Setting | Value |
   |---------|-------|
   | **Join type** | `Inner` |
   | **Stream key** | `user_id` |
   | **Table key** | `user_id` |

5. In the **Output columns** panel, select (at minimum):

   | From stream (Transactions) | From table (Customers) |
   |----------------------------|------------------------|
   | `transaction_id` | `display_name` |
   | `user_id` | `email` |
   | `amount` | `first_name` |
   | `merchant_name` | `last_name` |
   | `merchant_category` | `home_city` |
   | `merchant_city` | `home_state` |
   | `merchant_state` | `credit_limit` |
   | `fraud_type` | |
   | `distance_from_home_km` | |
   | `hour_of_day` | |
   | `day_of_week` | |
   | `amount_zscore` | |
   | `txn_count_last_1h` | |
   | `txn_count_last_24h` | |
   | `stream_timestamp` | |

6. Click **Apply** and verify the preview shows customer fields alongside
   each fraud transaction.

### A.4 — Add a second "Join" transformation (attach fraud history HTML)

> **Concept:** We need each fraud alert to include an HTML table of the
> customer's last 10 fraud transactions. That table is pre-computed in the
> Eventhouse using the KQL query in
> [`fraud-detection-alert.kql`](./fraud-detection-alert.kql).

#### A.4.1 — Create the materialized KQL view (one-time setup)

In your **Eventhouse → KQL database**, run the following to create a
**KQL function** that the Eventstream can reference:

```kql
.create-or-alter function FraudHistoryHtml() {
    Transactions
    | where is_fraud == 1
    | sort by stream_timestamp desc
    | extend row_html = strcat(
        '<tr>',
        '<td style="padding:6px 8px;border-bottom:1px solid #ecf0f1;">',
            format_datetime(stream_timestamp, 'yyyy-MM-dd HH:mm'), '</td>',
        '<td style="padding:6px 8px;border-bottom:1px solid #ecf0f1;color:#c0392b;font-weight:600;">$',
            tostring(round(amount, 2)), '</td>',
        '<td style="padding:6px 8px;border-bottom:1px solid #ecf0f1;">',
            merchant_name, '</td>',
        '<td style="padding:6px 8px;border-bottom:1px solid #ecf0f1;">',
            merchant_city, ', ', merchant_state, '</td>',
        '<td style="padding:6px 8px;border-bottom:1px solid #ecf0f1;">',
            '<span style="display:inline-block;background:#fdf2f2;color:#c0392b;',
            'font-weight:600;font-size:12px;padding:2px 10px;border-radius:4px;',
            'border:1px solid #f5c6cb;">', fraud_type, '</span></td>',
        '</tr>')
    | summarize fraud_rows = make_list(row_html, 10) by user_id
    | project user_id, fraud_history_html = strcat(
        '<table style="width:100%;border-collapse:collapse;font-size:13px;">',
        '<thead><tr style="background:#f8f9fa;">',
        '<th style="text-align:left;padding:8px;border-bottom:2px solid #dee2e6;">Date</th>',
        '<th style="text-align:left;padding:8px;border-bottom:2px solid #dee2e6;">Amount</th>',
        '<th style="text-align:left;padding:8px;border-bottom:2px solid #dee2e6;">Merchant</th>',
        '<th style="text-align:left;padding:8px;border-bottom:2px solid #dee2e6;">Location</th>',
        '<th style="text-align:left;padding:8px;border-bottom:2px solid #dee2e6;">Type</th>',
        '</tr></thead><tbody>',
        strcat_array(fraud_rows, ''),
        '</tbody></table>')
}
```

#### A.4.2 — Add the join in the Eventstream

1. Click **Transform events → Join**.
2. Connect the input to the **output** of the Customer Join (Step A.3).
3. For the **second input**, click **Add source → Eventhouse (KQL Database)**
   and select:
   - Your **Eventhouse**
   - Your **KQL database**
   - Function/Table: **`FraudHistoryHtml`** (the function you just created)
4. Configure the join:

   | Setting | Value |
   |---------|-------|
   | **Join type** | `Left outer` |
   | **Stream key** | `user_id` |
   | **Table key** | `user_id` |

   > Use **Left outer** so events still flow even if no prior fraud history
   > exists for a new customer.

5. In the **Output columns**, keep all columns from the previous step and
   add `fraud_history_html` from the KQL function.
6. Click **Apply**.

### A.5 — Add the Activator destination (derived stream)

1. On the toolbar, click **Add destination → Activator**.
2. Select the Activator item you will create in Part B (or create it now —
   see Step 1 below).
3. Click **Connect** and then **Publish** the Eventstream.

### A.6 — Verify the pipeline

Your Eventstream canvas should now look like this:

```
[Source: Event Hub]
        │
        ▼
  ┌───────────┐
  │  Filter   │  is_fraud == 1
  └─────┬─────┘
        │
        ▼
  ┌───────────────────────────────┐
  │  Join (Inner)                 │◄── [Eventhouse: Customers table]
  │  on user_id                   │
  │  → adds email, display_name,  │
  │    home_city, credit_limit…   │
  └─────────────┬─────────────────┘
                │
                ▼
  ┌───────────────────────────────┐
  │  Join (Left outer)            │◄── [Eventhouse: FraudHistoryHtml()]
  │  on user_id                   │
  │  → adds fraud_history_html    │
  └─────────────┬─────────────────┘
                │
                ▼
  ┌─────────────────────┐
  │  Destination:       │
  │  Activator (Reflex) │
  └─────────────────────┘
```

Click **Data preview** on the final node and confirm all expected columns
are present (see the table in Step 2 of Part B below).

---

## Part B — Configure the Activator (Reflex)

### Step 1 — Create the Reflex Item

1. In your **Fabric workspace**, click **+ New item → Activator**.
2. Name it `reflex-fraud-alerts`.
3. Click **Create**.

---

### Step 2 — Connect to the Eventstream

1. In the Activator canvas, click **Get data → Eventstream**.
2. Select the Eventstream you configured in **Part A** (the enriched fraud
   stream with filter + customer join + fraud history).
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

### Step 3 — Define the Trigger Object

1. In the **Design** tab, under **Objects**, select `transaction_id` as the
   **unique key** for the object.
2. Set `user_id` as the **Group by** field (so alerts aggregate per cardholder).

---

### Step 4 — Create the Trigger Condition

1. Click **New Trigger** on the object.
2. Name the trigger: `Fraud Detected`.
3. Set the condition:
   - **Detect when** → `is_fraud` **becomes** `1`
   - Or use: **Detect when** → `amount` **is greater than** `0` (since the query
     already filters to `is_fraud == 1`, any row that appears is a fraud event).
4. Optionally set a **time window** (e.g., evaluate every 1 minute).

---

### Step 5 — Configure the Action (Call Power Automate / Logic App)

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

### Step 6 — Activate the Trigger

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
