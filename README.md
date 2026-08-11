# Real-Time Fraud Detection with Microsoft Fabric

An end-to-end real-time fraud detection solution built on **Microsoft Fabric Real-Time Intelligence** and **Azure AI Foundry**. The system generates synthetic credit card transactions, streams them through Fabric Eventstream into a KQL database (Eventhouse), and uses Data Activator (Reflex) to detect fraudulent transactions and send automated email alerts to affected cardholders — all in real time.

In addition to the streaming fraud-detection pipeline, the solution includes an **AI-powered analyst chat interface** where fraud investigators can query transaction history, ask about suspicious patterns, and get natural-language insights powered by an Azure AI Foundry agent (GPT model). The chat is served through an Angular web app authenticated via Entra ID, backed by a Python Azure Function that orchestrates the AI agent using an on-behalf-of token flow.

## Solution Concept

```mermaid
flowchart LR
    subgraph Data Generation
        NB1[Generate Customers<br/>Notebook]
        NB2[Generate Transactions<br/>Notebook]
    end

    subgraph Microsoft Fabric RTI
        ES[Eventstream]
        EH[(Eventhouse<br/>KQL Database)]
        RX[Data Activator<br/>Reflex]
    end

    subgraph Fraud Alerts
        EMAIL[Email Alert<br/>to Cardholder]
    end

    subgraph AI Investigation
        FUNC[Azure Function<br/>Agent Service]
        AGENT[AI Foundry Agent<br/>GPT Model]
        WEB[Angular Web App<br/>Analyst Dashboard]
    end

    NB1 -->|Ingest customers| EH
    NB2 -->|Stream transactions| ES
    ES -->|Real-time ingestion| EH
    ES -->|Trigger on is_fraud=1| RX
    RX -->|Send alert| EMAIL

    WEB -->|Chat query| FUNC
    FUNC -->|On-behalf-of| AGENT
    AGENT -->|KQL queries| EH
    AGENT -->|Streaming response| FUNC
    FUNC -->|SSE| WEB
```

## Azure & Fabric Deployment Architecture

```mermaid
flowchart TB
    subgraph Azure Resource Group
        direction TB
        AI[Azure AI Foundry<br/>+ GPT Model Deployment]
        FUNC[Azure Function App<br/>Python · Chat Service]
        WEB[App Service<br/>Angular SPA]
        ACR[Container Registry]
        STOR[Storage Account]
        INSIGHTS[Application Insights<br/>+ Log Analytics]
        MI[Managed Identity]
        ENTRA[Entra ID<br/>App Registrations]
    end

    subgraph Fabric Workspace
        direction TB
        EH[(Eventhouse<br/>MyFraud_EH)]
        ESTREAM[Eventstream<br/>CreditCardTransactions]
        NBK[Notebooks<br/>Customer & Transaction Gen]
        REFLEX[Reflex<br/>Fraud Alert Rules]
    end

    %% Azure internal connections
    MI -->|Azure AI User| AI
    MI -->|Blob Data Owner| STOR
    FUNC -->|Hosted in| ACR
    WEB -->|Hosted in| ACR
    FUNC -->|Uses| MI
    FUNC -->|Calls agent| AI
    WEB -->|OAuth2 token| ENTRA
    FUNC -->|Validates token| ENTRA
    FUNC -->|Telemetry| INSIGHTS
    WEB -->|Telemetry| INSIGHTS

    %% Cross-boundary connections
    ESTREAM -->|Event Hub endpoint<br/>connection string in Key Vault| NBK
    NBK -->|Stream events| ESTREAM
    ESTREAM -->|Ingest| EH
    ESTREAM -->|Trigger| REFLEX
    AI -->|Queries KQL| EH
```

## Getting Started

| Step | Description | Guide |
|------|-------------|-------|
| 1 | **Deploy Azure infrastructure** — provision all Azure resources with `azd up` | [docs/deployment.md](./docs/deployment.md) |
| 2 | **Configure Microsoft Fabric workspace** — set up Eventhouse, Eventstream, notebooks, and Reflex | [FabricRTI/Readme.md](./FabricRTI/Readme.md) |

## Project Structure

```
infra/                    # Bicep IaC templates (deployed by azd)
  main.bicep              #   Entry point – subscription-scoped deployment
  core/                   #   Modular resource definitions
    AI/                   #     Foundry + model deployment
    apim/                 #     API Management (optional)
    container/            #     Container Registry
    data/                 #     Microsoft Fabric capacity
    entraID/              #     App registrations
    function/             #     Function App
    identity/             #     Managed Identity
    log/                  #     App Insights + Log Analytics
    rbac/                 #     Role assignments
    storage/              #     Storage Account
    web/                  #     App Service (Web App)
FabricRTI/                # Fabric workspace items (Git-synced)
  Databases/              #   Eventhouse + KQL schema
  Events/                 #   Eventstream + Notebooks
  rx-fraud-alerts.Reflex/ #   Data Activator fraud rules
src/
  functions/              # Python Azure Function (AI agent backend)
  web/                    # Angular frontend (analyst chat UI)
  fraudstream/            # Fabric RTI deployment scripts & notebooks
docs/
  deployment.md           # Azure infrastructure deployment guide
```
