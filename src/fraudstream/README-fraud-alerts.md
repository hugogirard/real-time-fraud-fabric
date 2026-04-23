# Real-Time Fraud Alert Emails with Fabric Data Activator

This guide walks you through setting up **real-time fraud alert emails** that are
sent to the affected cardholder the moment a fraudulent credit-card transaction
is detected. The solution uses **Microsoft Fabric Data Activator** (also called
Reflex) as the alerting engine and the **Eventstream** as the data source.

## How it works (architecture)

```
                                                ┌──────────────────────────┐
                                                │ Eventhouse (MyFraud_EH)  │
┌────────────────────────────────────┐          │  ├─ CCTransactions table │
│ Eventstream                        │──────────│  └─ Customers table      │
│ CreditCardTransactions_es          │          └──────────────────────────┘
│                                    │
│  Transaction events include:       │          ┌──────────────────────────┐
│  user_id, email, display_name,     │          │ Data Activator (Reflex)  │
│  amount, merchant_name, is_fraud,  │──────────│  rx-fraud-alerts         │
│  fraud_type, ...                   │          │                          │
└────────────────────────────────────┘          │  Object key = user_id    │
                                                │  Rule: is_fraud == 1     │
                                                │  Action: Send email      │
                                                │    To = @email           │
                                                └──────────┬───────────────┘
                                                           │
                                                           ▼
                                                    Customer inbox
                                                 (+ CC to Fraud Ops)
```

**Key design decisions:**

| Decision | Rationale |
|----------|-----------|
| Eventstream is the Activator source (not the Eventhouse) | Data Activator monitors live events as they flow through the Eventstream |
| Customer fields (`email`, `display_name`) are included in the transaction events | Activator can only use fields present in its source stream — it cannot query the Eventhouse at runtime |
| No join inside the Eventstream itself | The enrichment happens in the `Generate_Credit_Card_Transactions` notebook before events are sent to the Eventstream |

> **Important — Why `email` must be in the stream:**
> Fabric Data Activator works with the data columns present in its source
> Eventstream. It does **not** have the ability to query the Eventhouse or
> run KQL at rule-evaluation time. To send the alert email to the right
> customer, the `email` field must be part of each transaction event.
>
> The `Generate_Credit_Card_Transactions` notebook already loads the
> `Customers` table from the Eventhouse to generate transactions. Adding
> `email` and `display_name` to the streamed fields is a one-line change
> (see [Prerequisites](#prerequisites) below).

---

## Prerequisites

### Workspace items

You need the following items in your **FraudDemo** workspace before starting:

| Item | Type | Purpose |
|------|------|---------|
| `CreditCardTransactions_es` | Eventstream | Streams real-time transaction events |
| `MyFraud_EH` | Eventhouse (KQL database) | Stores `CCTransactions` and `Customers` tables |
| `rx-fraud-alerts` | Reflex (Data Activator) | Created by `Deploy-FraudAlerts.ps1` |

### Customers table

The `Customers` table must be loaded in the Eventhouse from `customers.csv`.
It contains 10 users (`U0001`–`U0010`) with these columns:

| Column | Example |
|--------|---------|
| `user_id` | `U0001` |
| `first_name` | `Mark` |
| `last_name` | `Johnson` |
| `display_name` | `Mark Johnson` |
| `email` | `mark.johnson@contoso.com` |
| `home_city` | `Porto Alegre` |
| `home_state` | `RS` |
| `credit_limit` | `15000.00` |

### Transaction stream must include customer fields

The `Generate_Credit_Card_Transactions` notebook must include `email` and
`display_name` in the events it sends to the Eventstream. Open the notebook
and add these two fields to the `send_cols` list:

```python
send_cols = [
    "transaction_id", "user_id",
    "email", "display_name",          # <-- ADD THESE TWO FIELDS
    "stream_timestamp", "amount",
    "merchant_name", "merchant_category",
    "merchant_city", "merchant_state",
    "merchant_lat", "merchant_lon",
    "is_fraud", "fraud_type",
    "distance_from_home_km", "hour_of_day", "day_of_week",
    "time_since_last_txn_sec", "rolling_avg_amount",
    "amount_zscore", "txn_count_last_1h", "txn_count_last_24h",
]
```

The notebook already loads the `Customers` table from the Eventhouse and merges
it with transactions (for `home_lat`, `home_lon`, etc.). Adding `email` and
`display_name` to `send_cols` is all that's needed — no new join is required.

---

## Quick Start

Run the deployment script to create the Reflex item and discover existing
resources:

```powershell
# Fabric-only deployment (Data Activator built-in email)
.\Deploy-FraudAlerts.ps1 `
    -FabricWorkspaceName "FraudDemo" `
    -KqlDatabaseName "MyFraud_EH" `
    -EventstreamName "CreditCardTransactions_es"
```

Or with the optional Azure Logic App for advanced HTML emails:

```powershell
.\Deploy-FraudAlerts.ps1 `
    -FabricWorkspaceName "FraudDemo" `
    -KqlDatabaseName "MyFraud_EH" `
    -EventstreamName "CreditCardTransactions_es" `
    -DeployLogicApp `
    -SubscriptionId "<your-subscription-id>" `
    -ResourceGroupName "rg-fraud-alerts" `
    -AlertRecipientEmail "security@contoso.com"
```

The script will:
1. Authenticate via Azure CLI
2. Find the workspace, KQL database, and Eventstream
3. Create the Reflex item (if it doesn't exist)
4. (Optional) Deploy the Azure Logic App
5. Output portal links and the remaining manual configuration steps below

---

## Step 1 — Add the Activator as a destination in the Eventstream

This step connects your live transaction stream to the Data Activator so it can
monitor every event in real time.

> **Official docs with screenshots:**
> [Add a Fabric Activator destination to an eventstream](https://learn.microsoft.com/en-us/fabric/real-time-intelligence/event-streams/add-destination-activator)

### Where to do this

You do this from the **Eventstream** item, not from the Activator.

### Step-by-step

1. Open the [Fabric portal](https://app.fabric.microsoft.com/) and navigate to
   your **FraudDemo** workspace.

2. In the workspace item list, click on **`CreditCardTransactions_es`**
   (the Eventstream). This opens the Eventstream canvas.

3. You should see a visual canvas with your event source on the left. If the
   canvas says **Live view** in the top-left corner, click **Edit** in the
   toolbar to switch to **Edit mode**. You must be in Edit mode to add
   destinations.

4. In the ribbon (toolbar at the top), click **Add destination** and select
   **Activator** from the dropdown list.

5. In the **Activator** pane that opens on the right:
   - **Destination name**: enter a name like `FraudAlertActivator`
   - **Workspace**: select **FraudDemo**
   - **Activator**: select the existing **`rx-fraud-alerts`** Reflex
     (created by the deployment script). If you don't see it, click
     **Create new** and name it `rx-fraud-alerts`.

6. Click **Save**.

7. Back on the canvas, click **Publish** in the toolbar to apply the changes.
   Wait for the publish to complete (you'll see a green confirmation).

8. The Eventstream canvas now shows an **Activator** destination node connected
   to your event source. Transaction events are now flowing into the Activator.

> **Why the Eventstream and not the Eventhouse?**
> Data Activator is designed to monitor **live event streams**. It needs the
> Eventstream as its source so it can evaluate rules on each arriving event in
> real time. The Eventhouse stores historical data and is not a real-time source
> for Activator.

---

## Step 2 — Create an object in the Activator

An **object** in Data Activator represents the business entity you are
monitoring. In this case, each object is a **cardholder** identified by
`user_id`. The Activator groups all incoming events by this key so that
rules are evaluated per cardholder.

> **Official docs with screenshots:**
> - [Assign data to objects in Activator](https://learn.microsoft.com/en-us/fabric/real-time-intelligence/data-activator/activator-assign-data-objects)
> - [Tutorial: Create and activate a rule](https://learn.microsoft.com/en-us/fabric/real-time-intelligence/data-activator/activator-tutorial) — see the "Create an object" section

### Where to do this

You do this from inside the **Activator** item (Reflex).

### Step-by-step

1. In the **FraudDemo** workspace, click on **`rx-fraud-alerts`** to open the
   Activator.

2. In the **Explorer** pane (left side), you should see the eventstream you
   connected in Step 1 (it may appear as `FraudAlertActivator` or
   `CreditCardTransactions_es`). Click on it to select it. The center pane
   shows a live table of incoming events.

3. In the ribbon (toolbar at the top), click **New object**.

4. In the **Build object** pane that opens on the right, fill in:

   | Field | Value | Why |
   |-------|-------|-----|
   | **Object name** | `Cardholder` | This is the business entity we're monitoring — each cardholder |
   | **Unique ID column** | `user_id` | This column uniquely identifies each cardholder (e.g. `U0001`, `U0002`, …). All events with the same `user_id` are grouped into one object instance |

5. **(Optional but recommended)** Under **Assign Properties**, select the
   columns you want available as properties on the object. Select at least:
   - `email`
   - `display_name`
   - `amount`
   - `merchant_name`
   - `merchant_city`
   - `merchant_state`
   - `is_fraud`
   - `fraud_type`
   - `transaction_id`
   - `stream_timestamp`

   These will become properties you can reference in your rule conditions
   and email notifications.

6. Click **Create**.

7. The Explorer pane now shows a **Cardholder** object with the properties you
   selected. Click on the **Cardholder** object to see its events organized by
   `user_id`. You should see different `user_id` values (like `U0001`,
   `U0002`, etc.) each with their own event history.

> **What just happened?**
> You told Activator: "Group all incoming transaction events by `user_id`.
> Each unique `user_id` is a *Cardholder* object. Track the selected columns
> as properties on each cardholder." Now you can create rules that fire per
> cardholder when specific conditions are met.

---

## Step 3 — Create the fraud detection rule

A **rule** defines what condition to watch for and what action to take when the
condition is met. Our rule is simple: when a transaction arrives with
`is_fraud == 1`, send an email to the cardholder.

> **Official docs with screenshots:**
> - [Create a rule in Fabric Activator](https://learn.microsoft.com/en-us/fabric/real-time-intelligence/data-activator/activator-create-activators) — see "Define a rule condition and action"
> - [Tutorial: Create and activate a rule](https://learn.microsoft.com/en-us/fabric/real-time-intelligence/data-activator/activator-tutorial) — see "Explore a rule" and "Create a new rule" sections

### Where to do this

You do this from inside the **Activator** item, on the **Cardholder** object
you created in Step 2.

### Step-by-step

1. In the **Explorer** pane (left side), expand the **Cardholder** object and
   click on the stream underneath it (this is the eventstream data assigned to
   the object). You'll see a chart of event values in the center pane.

2. In the ribbon (toolbar at the top), click **New rule**.

3. The **Definition** pane opens on the right side with three sections:
   **Monitor**, **Condition**, and **Action**. Fill in each section as
   described below.

---

### 3a. Monitor section

The Monitor section defines *what data* the rule watches.

1. The **Monitor** dropdown should already show the stream from your
   Eventstream. If not, select it.

2. You do **not** need to add any summarization (no Average, no Count).
   We want to react to every single event, not an aggregate.

---

### 3b. Condition section

The Condition section defines *when* the rule fires.

1. For the condition type, select **On each event when a value is met**.

2. Set the condition to:
   - **Column**: `is_fraud`
   - **Operator**: `Equals`
   - **Value**: `1`

   > **Note:** In some workspaces `is_fraud` is a string column (`"0"` or
   > `"1"`). If the `Equals 1` condition never fires, try `"1"` (with quotes)
   > instead.

3. The chart in the center pane updates to show **only** the events where
   `is_fraud == 1`. Verify that you see highlighted data points — these are the
   events that would trigger the rule.

---

### 3c. Action section — send an email to the right customer

The Action section defines *what happens* when the condition is met.

1. For **Select action**, choose **Send email**.

2. For **To** (the recipient):
   - Click the **To** field.
   - From the dropdown, select the **`email`** property.
   - This means the email will be sent to whichever customer's `email` address
     is on the event that triggered the rule. For example, if `U0003` made a
     fraudulent transaction, the email goes to
     `stephanie.miller@contoso.com`.

   > **This is how the right user gets the alert.** The `email` column in
   > each transaction event comes from the `Customers` table in the
   > Eventhouse (it was included in the stream by the notebook). The
   > Activator reads this field from the incoming event and uses it as the
   > email recipient.

3. For **Subject**, enter:
   ```
   Fraud Alert — Suspicious transaction of $@amount at @merchant_name
   ```
   > **Tip:** Type `@` to insert property references. When you type `@`,
   > a dropdown appears with all available properties. Select `amount`,
   > `merchant_name`, etc. The `@property_name` tokens are replaced with
   > actual values when the email is sent.

4. For **Headline**, enter:
   ```
   Fraudulent transaction detected on your card
   ```

5. For **Notes** (the email body text), enter:
   ```
   Hi @display_name,

   A potentially fraudulent transaction was detected on your card:

   Amount: $@amount
   Merchant: @merchant_name
   Location: @merchant_city, @merchant_state
   Type: @fraud_type
   Time: @stream_timestamp
   Transaction ID: @transaction_id

   If you did not authorize this transaction, please contact your bank immediately.
   ```

6. For **Context**, select additional properties to include as a summary table
   in the email. Check at least:
   - `transaction_id`
   - `amount`
   - `merchant_name`
   - `fraud_type`
   - `stream_timestamp`

7. Click **Create** to save the rule.

---

### 3d. Rename the rule

1. After creating the rule, it appears in the **Explorer** pane under the
   **Cardholder** object. Select it.

2. In the center pane, click the **pencil icon** next to the rule name at the
   top, and rename it to **`Fraud Alert Email`**.

---

### 3e. Test the rule before starting

1. With the rule selected, click **Send me a test action** in the Definition
   pane (or in the ribbon). This sends a sample alert to **your** email using
   a past event where the condition was true.

   > **Note:** The test alert always goes to YOU (the signed-in user),
   > regardless of the `email` property value. This is by design so you can
   > verify the email format before going live.

2. Check your inbox. You should receive an email with the fraud transaction
   details filled in. Verify the subject, body, and context values look correct.

3. If you don't receive it, check your spam/junk folder, or see the
   [Troubleshooting](#troubleshooting) section below.

---

## Step 4 — Start the rule and run a live test

1. With the **Fraud Alert Email** rule selected, click **Save and start** in
   the Definition pane, or click **Start** in the ribbon toolbar.

2. The rule status changes to **Running** (you'll see a green "Running"
   indicator next to the rule name in the Explorer pane).

3. Open and run the **`Generate_Credit_Card_Transactions`** notebook to start
   streaming transactions. The notebook replays 6 months of transaction data
   compressed into ~30 minutes of real-time streaming.

4. As events flow in, every transaction where `is_fraud == 1` triggers the
   rule. The affected cardholder receives an email at the address stored in the
   `email` field of that event.

5. To **verify** it's working:
   - In the Activator, click on the **Fraud Alert Email** rule.
   - Select the **Analytics** tab in the center pane. You should see charts
     showing how many times the rule fired and for which `user_id` values.
   - Check the inbox of one of the test users (e.g. `mark.johnson@...`) for
     the fraud alert email.

6. To **stop** the rule, click **Stop** in the ribbon toolbar.

---

## (Optional) Use the Logic App for advanced HTML emails

The built-in Activator email is plain-text with a structured context table.
If you want a **rich HTML email** with branded styling, a fraud history table,
and a deep-link button, deploy the Logic App:

1. Run the deployment script with `-DeployLogicApp` (see Quick Start above).

2. After deployment, go to the **Azure Portal** and authorize the Office 365
   API connection:
   - Navigate to your resource group → open the **API Connection** resource
     (`fraud-alert-office365`).
   - Click **Edit API connection** → **Authorize** → Sign in → **Save**.

3. Copy the **Logic App callback URL** from the deployment output.

4. In the Activator, edit your rule's **Action** section:
   - Change the action type to **Create custom action**.
   - Follow the prompts to connect it to a Power Automate flow that calls
     the Logic App webhook URL.

> See [Trigger custom actions (Power Automate flows)](https://learn.microsoft.com/en-us/fabric/real-time-intelligence/data-activator/activator-trigger-power-automate-flows)
> for detailed instructions.

---

## Summary of what each component does

| Component | Role |
|-----------|------|
| **Eventstream** (`CreditCardTransactions_es`) | Streams raw transaction events including customer fields (`email`, `display_name`) from the notebook |
| **Eventhouse** (`MyFraud_EH`) | Stores `CCTransactions` history and `Customers` reference table. The notebook reads `Customers` to enrich transactions before streaming |
| **Notebook** (`Generate_Credit_Card_Transactions`) | Generates transactions, enriches them with customer data from the Eventhouse, and sends them to the Eventstream |
| **Activator** (`rx-fraud-alerts`) | Monitors the Eventstream, groups events by `user_id`, and sends email alerts when `is_fraud == 1` |

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| **Rule never fires** | Verify the Eventstream has `is_fraud == 1` events. Run this KQL query in the Eventhouse: `CCTransactions \| where is_fraud == "1" \| count`. Also check that the condition value matches the data type (string `"1"` vs integer `1`). |
| **Email goes to the wrong person** | Check that `email` is included in the transaction events. In the Eventstream Live view, inspect a sample event and confirm it contains an `email` field. If missing, update the notebook's `send_cols` list (see [Prerequisites](#transaction-stream-must-include-customer-fields)). |
| **No email received** | Check your spam/junk folder. Also verify that the Fabric admin has enabled email actions for Activator in the tenant admin portal: **Admin portal → Tenant settings → Data Activator**. |
| **"Send me a test action" button is grayed out** | The button is only enabled if there is at least one past event where the rule condition is true. Make sure the Eventstream has been running and has produced `is_fraud == 1` events. |
| **Activator shows "No data"** | Confirm the Eventstream destination was published (Step 1, sub-step 7). Go back to the Eventstream, switch to **Live view**, and check that events are flowing to the Activator destination node. |

---

## Official documentation

- [What is Fabric Activator?](https://learn.microsoft.com/en-us/fabric/real-time-intelligence/data-activator/activator-introduction)
- [Tutorial: Create and activate a Fabric Activator rule](https://learn.microsoft.com/en-us/fabric/real-time-intelligence/data-activator/activator-tutorial) — includes screenshots of every UI step
- [Add a Fabric Activator destination to an eventstream](https://learn.microsoft.com/en-us/fabric/real-time-intelligence/event-streams/add-destination-activator)
- [Assign data to objects in Activator](https://learn.microsoft.com/en-us/fabric/real-time-intelligence/data-activator/activator-assign-data-objects)
- [Create a rule in Fabric Activator](https://learn.microsoft.com/en-us/fabric/real-time-intelligence/data-activator/activator-create-activators)
- [Activator rules overview](https://learn.microsoft.com/en-us/fabric/real-time-intelligence/data-activator/activator-rules-overview)
