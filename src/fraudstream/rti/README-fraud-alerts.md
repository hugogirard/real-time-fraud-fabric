# Real-Time Fraud Alert Emails with Fabric Data Activator

This guide walks you through setting up **real-time fraud alert emails** that are
sent to the affected cardholder the moment a fraudulent credit-card transaction
is detected. The solution uses **Microsoft Fabric Data Activator** (also called
Reflex) as the alerting engine and the **Eventstream** as the data source.

> **For dummies summary:** When a fraudulent credit card transaction happens,
> the system automatically sends an email to the right customer saying
> "Hey, we detected fraud on your card." This guide shows you exactly how to
> set that up, click by click.

---

## How it works — the big picture

Here is how the different pieces fit together. Read this first so the steps
below make sense.

```
┌─────────────────────────────────┐
│  Eventhouse (MyFraud_EH)        │
│  ┌───────────────────────────┐  │
│  │ Customers table           │  │
│  │ (user_id, email,          │  │
│  │  display_name, ...)       │  │
│  └───────────┬───────────────┘  │
│              │ loaded at         │
│              │ notebook start    │
│  ┌───────────┴───────────────┐  │
│  │ CCTransactions table      │  │
│  │ (historical storage)      │  │
│  └───────────────────────────┘  │
└─────────────────────────────────┘
               │
               ▼
┌─────────────────────────────────┐
│  Notebook                       │
│  Generate_Credit_Card_           │
│  Transactions.ipynb             │
│                                 │
│  1. Loads Customers from        │
│     Eventhouse (gets email,     │
│     display_name, home coords)  │
│  2. Generates transactions      │
│  3. Merges customer fields      │
│     INTO each transaction       │
│  4. Streams enriched events     │
│     to the Eventstream          │
└────────────┬────────────────────┘
             │ events include:
             │ user_id, email, display_name,
             │ amount, merchant_name, is_fraud, ...
             ▼
┌─────────────────────────────────┐
│  Eventstream                    │
│  CreditCardTransactions_es      │
│                                 │
│  Routes events to:              │
│  ├─ Eventhouse (for storage)    │
│  └─ Activator (for alerting)    │
└────────────┬────────────────────┘
             │
             ▼
┌─────────────────────────────────┐
│  Data Activator (Reflex)        │
│  rx-fraud-alerts                │
│                                 │
│  Object: "Cardholder"           │
│    grouped by: user_id          │
│                                 │
│  Rule: "Fraud Alert Email"      │
│    When: is_fraud == 1          │
│    Action: Send email           │
│      To: @email (from event)    │
│      Subject: Fraud alert...    │
│      Body: transaction details  │
└────────────┬────────────────────┘
             │
             ▼
        Customer inbox
      (the RIGHT customer)
```

### Why is the customer email in the stream?

This is the key design decision you need to understand:

**Data Activator can only use data columns that are present in its source
Eventstream.** It cannot query the Eventhouse, run KQL, or look up data from
other tables at rule-evaluation time. It only sees the fields on each incoming
event.

So if you want Activator to send an email to the right customer, the `email`
field **must be part of every transaction event** flowing through the
Eventstream.

**How we solve this:** The `Generate_Credit_Card_Transactions` notebook already
loads the `Customers` table from the Eventhouse (to get home coordinates for
distance calculations). We simply include `email` and `display_name` in the
data it merges into each transaction before streaming. This way, every event
arriving in the Eventstream already has the customer's email attached. No join
in the Eventstream, no KQL at runtime — just simple data enrichment at the
source.

---

## Prerequisites

### 1. Workspace items you need

You need these items in your **FraudDemo** workspace. If something is missing,
the deployment script or other notebooks create them.

| Item | Type | How to create it |
|------|------|-----------------|
| `CreditCardTransactions_es` | Eventstream | Created manually or via workspace setup |
| `MyFraud_EH` | Eventhouse (KQL database) | Created manually or via workspace setup |
| `Customers` table | Table in the Eventhouse | Run `Generate_Customers.ipynb` or import `customers.csv` |
| `rx-fraud-alerts` | Reflex (Data Activator) | Created by `Deploy-FraudAlerts.ps1` |

### 2. Customers table must be loaded

The `Customers` table must exist in the Eventhouse **before** you run the
transaction generator notebook. It contains your 10 test users:

| user_id | display_name | email | home_city |
|---------|-------------|-------|-----------|
| U0001 | Mark Johnson | mark.johnson@...onmicrosoft.com | Porto Alegre |
| U0002 | Daniel Doyle | daniel.doyle@...onmicrosoft.com | Indianapolis |
| U0003 | Stephanie Miller | stephanie.miller@...onmicrosoft.com | Belo Horizonte |
| ... | ... | ... | ... |

### 3. Notebook includes email in the stream (already done)

The `Generate_Credit_Card_Transactions` notebook has been updated to include
`email` and `display_name` in every transaction event it sends to the
Eventstream. Specifically:

- The merge step now pulls `email` and `display_name` from the Customers
  table (in addition to `home_lat` and `home_lon`).
- The `send_cols` list now includes `email` and `display_name`.

You do **not** need to change the notebook — this is already done. But if you
ever reset the notebook, make sure these two fields are still present in
`send_cols`.

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

After the script finishes, follow Steps 1–4 below to configure the Activator.

---

## Step 1 — Connect the Eventstream to the Activator

**Goal:** Tell the Eventstream to send a copy of every transaction event to
your Data Activator so it can monitor them in real time.

**Where you do this:** In the **Eventstream** item (not the Activator).

> **Official docs with screenshots:**
> [Add a Fabric Activator destination to an eventstream](https://learn.microsoft.com/en-us/fabric/real-time-intelligence/event-streams/add-destination-activator)

### Click-by-click instructions

1. Go to [https://app.fabric.microsoft.com](https://app.fabric.microsoft.com)
   and open your **FraudDemo** workspace.

2. In the list of workspace items, find and click on
   **`CreditCardTransactions_es`** (look for the Eventstream icon — it looks
   like a lightning bolt or stream). This opens the **Eventstream canvas** — a
   visual diagram showing where your data comes from and where it goes.

3. Look at the top-left corner of the canvas. If it says **"Live view"**, you
   need to switch to edit mode first:
   - Click the **Edit** button in the toolbar at the top.
   - The view switches to **"Edit mode"**. You can now make changes.

4. In the toolbar at the top, click **Add destination**. A dropdown menu
   appears. Select **Activator**.

   > **Can't find "Add destination"?** Make sure you're in **Edit mode** (see
   > step 3). The button only appears in edit mode. You can also right-click on
   > the canvas and look for "Add destination" in the context menu.

5. A configuration pane opens on the right side. Fill in these fields:

   | Field | What to enter |
   |-------|--------------|
   | **Destination name** | `FraudAlertActivator` (or any name you like) |
   | **Workspace** | Select **FraudDemo** from the dropdown |
   | **Activator** | Select **`rx-fraud-alerts`** from the dropdown. If you don't see it, click **Create new** and name it `rx-fraud-alerts` |

6. Click **Save**.

7. **Important — Publish your changes:** Back on the canvas, click the
   **Publish** button in the toolbar. This applies your changes and starts
   routing events to the Activator. Wait for the green "Published
   successfully" confirmation message.

   > If you skip this step, events will NOT flow to the Activator.

8. You should now see a new node on the canvas labeled with your Activator
   destination, connected to your event source by a line. This means events
   are flowing.

**What you just did:** You told the Eventstream: "Every time a transaction
event comes in, also send a copy to the Data Activator called
`rx-fraud-alerts`." The Activator is now receiving live data.

---

## Step 2 — Create a "Cardholder" object in the Activator

**Goal:** Tell the Activator how to organize incoming events. We want it to
group events by `user_id` so it tracks each cardholder separately. This way,
when a fraud rule fires, it knows which specific cardholder is affected.

**Where you do this:** In the **Activator** item (Reflex).

> **Official docs with screenshots:**
> - [Assign data to objects in Activator](https://learn.microsoft.com/en-us/fabric/real-time-intelligence/data-activator/activator-assign-data-objects)
> - [Tutorial — "Create an object" section](https://learn.microsoft.com/en-us/fabric/real-time-intelligence/data-activator/activator-tutorial#create-an-object)

### Click-by-click instructions

1. Go back to the **FraudDemo** workspace in the Fabric portal.

2. Find and click on **`rx-fraud-alerts`** in the workspace item list (look for
   the Activator/Reflex icon). The Activator opens.

3. Look at the **Explorer pane** on the left side. You should see a stream
   listed there — this is the data coming from your Eventstream (it may be
   called `FraudAlertActivator` or similar, matching the destination name you
   set in Step 1).

   > **Don't see any stream?** Go back to Step 1 and make sure you published
   > the Eventstream changes. Also make sure the notebook is running and
   > sending events.

4. **Click on the stream** in the Explorer pane to select it. The center pane
   shows a live table of incoming events. You should see columns like
   `user_id`, `email`, `display_name`, `amount`, `is_fraud`, etc.

   > **Don't see `email` or `display_name` columns?** The notebook is not
   > including these fields. Make sure you're using the updated notebook that
   > has `email` and `display_name` in the `send_cols` list.

5. With the stream selected, click **New object** in the ribbon (toolbar at the
   top of the screen).

6. The **Build object** pane opens on the right side. Fill in:

   | Field | What to enter | Why |
   |-------|--------------|-----|
   | **Object name** | `Cardholder` | This is what we're monitoring — cardholders |
   | **Unique ID column** | Select `user_id` from the dropdown | This tells Activator: "Each unique `user_id` value (U0001, U0002, ...) is a separate cardholder. Group their events together." |

7. **(Important)** Under **Assign Properties**, you'll see a list of all
   columns from the stream. Check the boxes next to these columns to make them
   available as properties you can use in rules and email notifications:

   - [x] `email` — **you need this to send emails to the right person**
   - [x] `display_name` — to address the customer by name in the email
   - [x] `amount` — to show the transaction amount
   - [x] `merchant_name` — to show where the purchase was made
   - [x] `merchant_city` — transaction location
   - [x] `merchant_state` — transaction location
   - [x] `is_fraud` — the fraud flag (needed for the rule condition)
   - [x] `fraud_type` — type of fraud detected
   - [x] `transaction_id` — unique transaction identifier
   - [x] `stream_timestamp` — when the transaction happened

   > **Tip:** You can always add more properties later. But `email` is
   > critical — without it, you can't send emails to the customer.

8. Click **Create**.

9. In the Explorer pane on the left, you should now see:
   ```
   ▼ Cardholder
     ├─ [stream name]
     ├─ email
     ├─ display_name
     ├─ amount
     ├─ merchant_name
     └─ ... (other properties)
   ```

   Click on the **Cardholder** object itself. The center pane shows events
   organized by `user_id`. You should see values like `U0001`, `U0002`, etc.,
   each with their own events.

**What you just did:** You told Activator: "I'm monitoring cardholders. Each
cardholder is identified by `user_id`. Here are the data fields I care about
for each cardholder." Now the `email` field from the Customers table (which
was merged into the stream by the notebook) is available as a property on each
cardholder object.

---

## Step 3 — Create the fraud detection rule

**Goal:** Create a rule that says: "When a transaction arrives with
`is_fraud == 1`, send an email to the affected customer using the `email`
property from that event."

**Where you do this:** In the **Activator** item, on the **Cardholder** object
you just created.

> **Official docs with screenshots:**
> - [Create a rule in Fabric Activator](https://learn.microsoft.com/en-us/fabric/real-time-intelligence/data-activator/activator-create-activators)
> - [Tutorial — "Explore a rule" and "Create a new rule" sections](https://learn.microsoft.com/en-us/fabric/real-time-intelligence/data-activator/activator-tutorial#explore-a-rule)

### Click-by-click instructions

#### 3a. Start creating the rule

1. In the **Explorer pane** (left side), expand the **Cardholder** object by
   clicking the arrow next to it.

2. Click on the **stream** underneath the Cardholder object (this is the
   eventstream data). The center pane shows a chart of event values.

3. In the ribbon (toolbar at the top), click **New rule**. The **Definition
   pane** opens on the right side with three sections you need to fill in:
   **Monitor**, **Condition**, and **Action**.

#### 3b. Fill in the Monitor section

The Monitor section tells the rule *what data to watch*.

1. The **Monitor** dropdown should already show the stream from your
   Eventstream. If it doesn't, select it from the dropdown.

2. **Do not add any summarization** (no Average, no Count, nothing). We want
   the rule to look at every single event as it arrives — not an aggregate
   over time.

#### 3c. Fill in the Condition section

The Condition section tells the rule *when to fire*.

1. Select the condition type: **On each event when a value is met**.

2. Configure the condition:
   - **Column**: select `is_fraud` from the dropdown
   - **Operator**: select `Equals`
   - **Value**: type `1`

   > **If the rule never fires later:** The `is_fraud` column might be a
   > string in your data (values `"0"` and `"1"` as text, not numbers). Try
   > changing the value to `"1"` (with quotes) if the integer `1` doesn't
   > work.

3. Look at the chart in the center pane — it should update to highlight only
   the events where `is_fraud == 1`. If you see highlighted data points, the
   condition is working.

#### 3d. Fill in the Action section — this is where the email is configured

The Action section tells the rule *what to do when the condition is met*.
This is where you configure the email to go to the right customer.

1. For **Select action**, choose **Send email** from the dropdown.

2. **For "To" (the recipient) — THIS IS THE KEY STEP:**
   - Click on the **To** field.
   - You'll see a dropdown. **Do not type an email address manually.**
   - Instead, look for **`email`** in the dropdown list and select it.
   - This tells Activator: "Send the email to whatever address is in the
     `email` column of the event that triggered the rule."

   > **Example of what happens at runtime:** A transaction comes in for
   > user `U0003` (Stephanie Miller) with `is_fraud == 1`. The event also
   > contains `email = stephanie.miller@...onmicrosoft.com` (because the
   > notebook included it). Activator sees the rule fire and sends the
   > alert email to `stephanie.miller@...onmicrosoft.com`. The RIGHT
   > customer gets the RIGHT email.

3. For **Subject**, enter:
   ```
   Fraud Alert — Suspicious transaction of $@amount at @merchant_name
   ```
   > **How to insert @property references:** When you type `@` in the text
   > field, a dropdown appears showing all available properties (`amount`,
   > `merchant_name`, `display_name`, etc.). Click on the one you want to
   > insert. At runtime, `@amount` is replaced with the actual value (e.g.
   > `$523.47`) and `@merchant_name` is replaced with the merchant name.

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

   > Type `@` each time you want to insert a property value. For example,
   > type `@` then select `display_name` from the dropdown. It shows as
   > `@display_name` in the text box but will be replaced with the actual
   > customer name (like "Stephanie Miller") when the email is sent.

6. For **Context**, select additional properties to include as a summary table
   at the bottom of the email. Check these boxes:
   - [x] `transaction_id`
   - [x] `amount`
   - [x] `merchant_name`
   - [x] `fraud_type`
   - [x] `stream_timestamp`

7. Click **Create** to save the rule.

#### 3e. Rename the rule

1. The new rule appears in the **Explorer pane** under the Cardholder object.
   Click on it to select it.

2. In the center pane, click the **pencil icon** (edit icon) next to the rule
   name at the top.

3. Rename it to **`Fraud Alert Email`** and press Enter.

#### 3f. Test the rule before going live

1. With the **Fraud Alert Email** rule selected, click **Send me a test
   action** (in the Definition pane on the right, or in the ribbon toolbar).

   > **What this does:** It finds a past event where `is_fraud == 1` and
   > sends you a sample email so you can see what it looks like.
   >
   > **Important:** The test email always goes to **your own email** (the
   > person signed into Fabric), NOT to the customer. This is by design — it
   > lets you verify the format before going live.

2. Check your inbox (also check spam/junk). You should receive an email with
   the fraud transaction details filled in.

3. **If the "Send me a test action" button is grayed out:** This means there
   are no past events where `is_fraud == 1`. Make sure the notebook is running
   and streaming events. Wait a few minutes for some fraud events to come in,
   then try again.

---

## Step 4 — Start the rule and run a live test

1. With the **Fraud Alert Email** rule selected, click **Save and start** in
   the Definition pane, or click **Start** in the ribbon toolbar.

2. The rule status changes to **Running** (you'll see a green "Running"
   indicator next to the rule name).

3. Open and run the **`Generate_Credit_Card_Transactions`** notebook to start
   streaming transactions. The notebook replays 6 months of transactions
   compressed into ~30 minutes of real-time streaming.

4. As events flow in, every transaction where `is_fraud == 1` triggers the
   rule. The affected cardholder receives an email at their address (the
   `email` field from the Customers table, included in the stream by the
   notebook).

5. To **verify** it's working:
   - In the Activator, click on the **Fraud Alert Email** rule.
   - Select the **Analytics** tab in the center pane. You should see charts
     showing how many times the rule fired and for which `user_id` values.
   - Check the inbox of one of the test users (e.g. `mark.johnson@...`) for
     the fraud alert email.

6. To **stop** the rule later, click **Stop** in the ribbon toolbar.

---

## (Optional) Use the Logic App for advanced HTML emails

The built-in Activator email is a simple structured message. If you want a
**rich HTML email** with branded styling, a fraud history table, and a
deep-link button, deploy the Logic App:

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

## How the email reaches the right customer — end-to-end flow

Here is exactly what happens when a fraudulent transaction occurs:

1. The **notebook** generates a transaction for user `U0003` (Stephanie Miller)
   with `is_fraud = 1`.

2. Before sending the event, the notebook looks up `U0003` in the `Customers`
   table and attaches `email = stephanie.miller@...onmicrosoft.com` and
   `display_name = Stephanie Miller` to the event.

3. The enriched event is sent to the **Eventstream**.

4. The Eventstream routes the event to both the **Eventhouse** (for storage)
   and the **Activator** (for alerting).

5. The **Activator** receives the event, sees `is_fraud == 1`, and the
   **Fraud Alert Email** rule fires.

6. The rule's action says "Send email to `@email`". Activator reads the
   `email` field from the event → `stephanie.miller@...onmicrosoft.com`.

7. Stephanie Miller receives the fraud alert email in her inbox.

---

## Summary of what each component does

| Component | Role |
|-----------|------|
| **Eventhouse** (`MyFraud_EH`) | Stores `Customers` reference table and `CCTransactions` history |
| **Notebook** (`Generate_Credit_Card_Transactions`) | Generates transactions, enriches each one with `email` and `display_name` from the Customers table, and streams them to the Eventstream |
| **Eventstream** (`CreditCardTransactions_es`) | Routes enriched transaction events to the Eventhouse (storage) and Activator (alerting) |
| **Activator** (`rx-fraud-alerts`) | Monitors events, groups by `user_id`, fires rule when `is_fraud == 1`, sends email to the `email` address in the event |

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| **No `email` column in the stream** | The notebook is not including customer fields. Make sure the notebook's merge step includes `email` and `display_name`, and that `send_cols` lists both fields. Re-run the notebook after fixing. |
| **Rule never fires** | Verify the Eventstream has `is_fraud == 1` events. Run this KQL query in the Eventhouse: `CCTransactions \| where is_fraud == "1" \| count`. Also check the condition value matches the data type (string `"1"` vs integer `1`). |
| **Email goes to the wrong person** | Inspect a sample event in the Eventstream Live view. Confirm the `email` field matches the expected customer for that `user_id`. If `email` is empty or wrong, check the `Customers` table in the Eventhouse. |
| **No email received** | Check spam/junk. Verify that the Fabric admin has enabled email actions: **Admin portal → Tenant settings → Data Activator**. |
| **"Send me a test action" button is grayed out** | No past event has `is_fraud == 1` yet. Run the notebook, wait a few minutes for fraud events to flow, then try again. |
| **Activator shows "No data"** | Confirm the Eventstream destination was published (Step 1, sub-step 7). Go to the Eventstream, switch to **Live view**, and check events are flowing to the Activator node. |
| **"email" not available in the To dropdown** | You didn't assign `email` as a property in Step 2. Go back to the Cardholder object, select the stream, and use **New Property** from the ribbon to add the `email` column. |

---

## Official documentation

- [What is Fabric Activator?](https://learn.microsoft.com/en-us/fabric/real-time-intelligence/data-activator/activator-introduction)
- [Tutorial: Create and activate a Fabric Activator rule](https://learn.microsoft.com/en-us/fabric/real-time-intelligence/data-activator/activator-tutorial) — includes screenshots of every UI step
- [Add a Fabric Activator destination to an eventstream](https://learn.microsoft.com/en-us/fabric/real-time-intelligence/event-streams/add-destination-activator)
- [Assign data to objects in Activator](https://learn.microsoft.com/en-us/fabric/real-time-intelligence/data-activator/activator-assign-data-objects)
- [Create a rule in Fabric Activator](https://learn.microsoft.com/en-us/fabric/real-time-intelligence/data-activator/activator-create-activators)
- [Activator rules overview](https://learn.microsoft.com/en-us/fabric/real-time-intelligence/data-activator/activator-rules-overview)
