# Blog Diagrams

These diagrams support the blog draft in [blog-draft.md](blog-draft.md). They are concept diagrams, not step-by-step run instructions.

## 1. Problem: One Worker, Too Much Trust

```mermaid
flowchart LR
    client["Workflow starter"] --> temporal["Temporal Server\nDurable workflow history"]
    temporal --> worker["Order worker\nOne broad runtime"]

    worker -->|"static DB username/password"| db["Postgres\nOrders, inventory, payments"]
    temporal --> ui["Temporal UI"]

    sensitive["Sensitive payloads\ncustomer email\nshipping address\npayment reference"] --> temporal
    ui -->|"history inspection shows\nworkflow/activity payloads"| sensitive_view["Visible sensitive data"]

    risk1["Long-lived credential"] -.-> worker
    risk2["Broad DB access"] -.-> worker
    risk3["Sensitive history"] -.-> temporal

    classDef risk fill:#fff1f2,stroke:#be123c,color:#7f1d1d;
    classDef neutral fill:#f8fafc,stroke:#475569,color:#0f172a;
    classDef data fill:#eef2ff,stroke:#4f46e5,color:#312e81;

    class risk1,risk2,risk3,sensitive_view risk;
    class client,temporal,worker,db,ui neutral;
    class sensitive data;
```

## 2. Solution: Temporal Orchestrates, Vault Secures

```mermaid
flowchart LR
    starter["Workflow starter\nlocal client or service"] --> temporal["Temporal Server\norchestration + history"]
    temporal -->|"schedule activities"| pod["Kubernetes worker pod\nServiceAccount: order-worker"]

    pod -->|"ServiceAccount JWT"| vault_auth["Vault Kubernetes auth"]
    vault_auth -->|"Vault token\npolicy: order-worker"| pod

    pod -->|"request activity DB role"| vault_db["Vault DB secrets engine"]
    vault_db -->|"short-lived Postgres user"| pod
    vault_db -->|"create/revoke DB users"| postgres["Postgres"]
    pod -->|"SQL with leased credential"| postgres

    pod -->|"encrypt/decrypt payloads"| transit["Vault Transit"]
    starter -->|"encrypt/decrypt payloads\nwith limited token"| transit
    temporal -->|"stores encoded payloads"| history["Encrypted workflow history\nencoding: binary/vault-transit"]

    classDef temporal fill:#ecfeff,stroke:#0891b2,color:#164e63;
    classDef vault fill:#f0fdf4,stroke:#16a34a,color:#14532d;
    classDef worker fill:#f8fafc,stroke:#475569,color:#0f172a;
    classDef data fill:#eef2ff,stroke:#4f46e5,color:#312e81;

    class temporal,history temporal;
    class vault_auth,vault_db,transit vault;
    class starter,pod,postgres worker;
```

## 3. Least Privilege: Activities as Security Boundaries

```mermaid
flowchart TB
    workflow["Order workflow\nbusiness process"] --> validate["Validate order activity"]
    workflow --> reserve["Reserve inventory activity"]
    workflow --> payment["Process payment activity"]
    workflow --> fulfill["Fulfill order activity"]
    workflow --> notify["Notify customer activity"]
    workflow --> release["Release inventory compensation"]

    validate --> role_validate["Vault DB role\norder-validate"]
    reserve --> role_reserve["Vault DB role\norder-reserve-inventory"]
    payment --> role_payment["Vault DB role\norder-process-payment"]
    fulfill --> role_fulfill["Vault DB role\norder-fulfill"]
    notify --> role_notify["Vault DB role\norder-notify"]
    release --> role_release["Vault DB role\norder-release-inventory"]

    role_validate --> access_validate["Read order data"]
    role_reserve --> access_reserve["Reserve inventory only"]
    role_payment --> access_payment["Record payment only"]
    role_fulfill --> access_fulfill["Write fulfillment only"]
    role_notify --> access_notify["Write notification only"]
    role_release --> access_release["Release reservation only"]

    identity["Runtime identity\nKubernetes ServiceAccount"] --> vault["Vault\nmaps identity + policy\nto allowed DB roles"]
    vault --> role_validate
    vault --> role_reserve
    vault --> role_payment
    vault --> role_fulfill
    vault --> role_notify
    vault --> role_release

    classDef workflow fill:#ecfeff,stroke:#0891b2,color:#164e63;
    classDef activity fill:#f8fafc,stroke:#475569,color:#0f172a;
    classDef vault fill:#f0fdf4,stroke:#16a34a,color:#14532d;
    classDef access fill:#fff7ed,stroke:#ea580c,color:#7c2d12;

    class workflow workflow;
    class validate,reserve,payment,fulfill,notify,release,identity activity;
    class vault,role_validate,role_reserve,role_payment,role_fulfill,role_notify,role_release vault;
    class access_validate,access_reserve,access_payment,access_fulfill,access_notify,access_release access;
```
