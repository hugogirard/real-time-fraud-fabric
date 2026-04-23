# Real-Time Fraud Alert Emails with **Fabric Data Activator**

End-to-end design that sends a **customized HTML email** to the cardholder
the moment a fraudulent credit-card transaction is detected — powered
entirely by **Microsoft Fabric Data Activator (Reflex)**.

The email contains:

- The triggering fraudulent transaction's details.
- The cardholder's **last 5 fraudulent transactions** (pulled live from the
  Eventhouse at alert time).
- A deep link to your **Fraud Investigation web app** — the link is a
  plain hyperlink inside the Activator email body, so you can edit it any
  time from the Activator rule UI without redeploying anything.

> **Design constraints honored**
>
> - No join inside the Eventstream. The stream carries raw transactions only.
> - The Eventhouse is _not_ used as the Data Activator source.
>   Data Activator consumes the **Eventstream** directly.
> - Customer lookup (`user_id → email, name`) and the "last 5 frauds"
>   table happen **inside Data Activator** as KQL-backed **properties**
>   that query the Eventhouse on demand when a rule fires.

---

## Architecture

```
┌──────────────────────┐
│  Eventstream         │   raw credit-card transactions
│  (live events)       │   (no joins, no enrichment)
└─────────┬────────────┘
          │
          ├──────────────▶  Eventhouse.Transactions   (history + KQL)
          │
          ▼
┌──────────────────────────────────────────────────────────────┐
│  Data Activator (Reflex)                                     │
│  ───────────────────────                                     │
│  • Source        : the Eventstream above                     │
│  • Stream key    : user_id  (one Activator object per card)  │
│  • Filter rule   : is_fraud == 1                             │
│                                                              │
│  Object properties (evaluated at trigger time):              │
│    · email                  ← KQL: Customers lookup by user_id│
│    · customer_name          ← KQL: Customers lookup          │
│    · last_5_frauds_html     ← KQL: top 5 from Transactions   │
│    · investigation_url      ← static/edited in rule UI       │
│                                                              │
│  Action: Send email (built-in)                               │
│    To     = {email}                                          │
│    Subject= "Fraud alert on your card — {txn_id}"            │
│    Body   = HTML template referencing the properties above   │
└──────────────────────────────────────────────────────────────┘
          │
          ▼
     Customer inbox   (+ optional CC to Fraud Ops)
```

Nothing outside Fabric is required — no Logic App, no Power Automate, no
webhook. Data Activator's **built-in email action** does the delivery.

---

## Prerequisites

In the `FraudDemo` workspace the following items are used:

| Role | Item | Notes |
|------|------|-------|
| Source stream | Eventstream `CreditCardTransactions_es` | raw transactions, no joins |
| History / lookup | KQL database `MyFraud_EH` | tables `CCTransactions`, `Customers` |
| Alert engine | Reflex `rx-fraud-alerts` | created during deployment |

The `CCTransactions` table already exists and is populated by the
Eventstream. Relevant columns: `user_id` (e.g. `U0001`…`U0010`),
`transaction_id`, `amount`, `merchant_name`, `merchant_city`,
`merchant_state`, `stream_timestamp`, `is_fraud` (**string**, `"0"` or
`"1"`).

The `Customers` table is loaded from `customers.csv` with the schema:
`user_id`, `first_name`, `last_name`, `email`, `home_city`, `home_state`,
`country_code`. `user_id` values match the stream (`U0001`…`U0010`).

---

## Step 1 — Customers table (already deployed)

The `Customers` table was created and populated during deployment with
10 rows (`U0001`…`U0010`) matching the `user_id` values in
`CCTransactions`. Verify any time with:

```kql
Customers | take 5
```

If you need to re-create it, the schema is:

```kql
.create table Customers (
    user_id: string,
    first_name: string,
    last_name: string,
    email: string,
    home_city: string,
    home_state: string,
    country_code: string
)
```

---

## Step 2 — Connect the Reflex to the Eventstream

The Reflex `rx-fraud-alerts` already exists in `FraudDemo`. Open it and:

1. Click **Get data → Eventstream** and pick
   `CreditCardTransactions_es`. **Important:** choose the Eventstream,
   _not_ the Eventhouse — this satisfies the "no Eventhouse as source"
   constraint.
2. For **Stream key**, choose `user_id`. Data Activator will now
   materialize one **object per cardholder** and update it with every
   new event.

---

## Step 3 — Define KQL-backed properties on the object

Properties are how Data Activator pulls reference + historical data
without requiring a join in the stream. Each property is re-evaluated
when a rule condition is met.

Open the object → **Properties → + New property → KQL query**.

### 3a. `email`

```kql
let uid = toscalar(Stream | project user_id | take 1);
Customers
| where user_id == uid
| project email
| take 1
```

### 3b. `customer_name`

```kql
let uid = toscalar(Stream | project user_id | take 1);
Customers
| where user_id == uid
| project name = strcat(first_name, " ", last_name)
| take 1
```

### 3c. `last_5_frauds_html`

This property builds a complete HTML `<table>` of the customer's 5 most
recent fraudulent transactions. Because it's computed only when the
rule fires (not on every stream event), it's cheap.

```kql
let uid = toscalar(Stream | project user_id | take 1);
let rows =
    CCTransactions
    | where user_id == uid and is_fraud == "1"
    | top 5 by stream_timestamp desc
    | project
        row = strcat(
            "<tr>",
              "<td>", tostring(stream_timestamp), "</td>",
              "<td>", tostring(transaction_id), "</td>",
              "<td>$", tostring(round(amount, 2)), "</td>",
              "<td>", merchant_name, "</td>",
              "<td>", merchant_city, ", ", merchant_state, "</td>",
            "</tr>")
    | summarize body = strcat_array(make_list(row), "");
strcat(
    "<table border='1' cellpadding='6' cellspacing='0' ",
    "style='border-collapse:collapse;font-family:Segoe UI,Arial;font-size:13px'>",
    "<thead style='background:#f3f3f3'><tr>",
      "<th>When</th><th>Txn ID</th><th>Amount</th>",
      "<th>Merchant</th><th>Location</th>",
    "</tr></thead><tbody>",
    toscalar(rows),
    "</tbody></table>"
)
```

### 3d. `investigation_url`

Make this a **static / text property** (not KQL). Value:

```
https://fraud-app.contoso.com/review
```

You'll append `?user_id=…&txn_id=…` in the email body. Since it's a
property, you can edit it later in the Activator UI without touching
any code.

---

## Step 4 — Create the trigger rule

1. On the object, click **+ New rule → When each event happens**.
2. **Condition:** `is_fraud == "1"` (the column is a string in this
   workspace).
3. **Action:** **Send me an email** → switch recipient to **Use a
   property** → pick `email`.
4. Optionally add a **Cc** to your Fraud Ops mailbox.
5. **Subject:**

   ```
   Fraud alert on your card — transaction {transaction_id}
   ```

6. **Body (rich text, HTML allowed):** paste the template below and drop
   in the property tokens using the **Insert property** button.

```html
<p>Hello {customer_name},</p>

<p>
  We detected a <strong>potentially fraudulent transaction</strong> on
  your card a moment ago:
</p>

<ul>
  <li><strong>Amount:</strong> ${amount}</li>
  <li><strong>Merchant:</strong> {merchant_name}</li>
  <li><strong>Location:</strong> {merchant_city}, {merchant_state}</li>
  <li><strong>Time:</strong> {stream_timestamp}</li>
  <li><strong>Transaction ID:</strong> {transaction_id}</li>
</ul>

<h3>Your last 5 flagged transactions</h3>
{last_5_frauds_html}

<p style="margin-top:20px">
  <a
    href="{investigation_url}?user_id={user_id}&txn_id={transaction_id}"
    style="background:#0078d4;color:#fff;padding:10px 18px;
           text-decoration:none;border-radius:4px;font-family:Segoe UI,Arial"
  >
    Review in the Fraud Investigation App
  </a>
</p>

<p style="color:#888;font-size:12px">
  Sent automatically by Microsoft Fabric Data Activator.
</p>
```

> **Editing the link later:** open the rule, change the
> `investigation_url` property or the hyperlink in the body, and
> **Save & start**. No redeploy, no code changes.

---

## Step 5 — Start the rule and test

1. Click **Start** on the rule.
2. Run `Generate_Credit_Card_Transactions.ipynb` to stream transactions.
3. Watch the Activator **Events** tab — every `is_fraud == "1"` event
   should show a fired rule and an **Email sent** action.
4. Confirm the cardholder inbox receives the HTML alert with a populated
   "last 5 frauds" table and a working deep link.

---

## Why this satisfies the constraints

| Requirement                                 | How it's met                                                                                   |
| ------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| No join inside the Eventstream              | The Eventstream only routes raw events. All customer lookup happens in Activator properties.   |
| Eventhouse is **not** the Activator source  | Activator source = the Eventstream. The Eventhouse is queried _only_ from KQL properties.      |
| Right customer receives the email           | The `email` property is resolved per `user_id` via a `Customers` KQL lookup at trigger time.   |
| Last 5 fraudulent transactions in the body  | `last_5_frauds_html` property builds the HTML table server-side in KQL.                        |
| Editable web app link                       | `investigation_url` is a property + plain hyperlink — edit in the Activator UI anytime.        |
| Data Activator highlighted                  | Activator owns the filter, the enrichment, the history lookup, and the email delivery.        |

---

## Troubleshooting

- **Property returns empty** — make sure `user_id` in `Customers` matches
  the `user_id` in the stream (same type and case).
- **Email action disabled** — an admin must enable the Reflex email
  action for your tenant (Fabric admin portal → Copilot & AI → Reflex).
- **Rule never fires** — verify the Eventstream actually emits
  `is_fraud == "1"` events
  (`CCTransactions | where is_fraud == "1" | count`).
- **HTML rendering issues** — some mail clients strip inline styles.
  Keep the template simple (tables + inline CSS only, as above).
