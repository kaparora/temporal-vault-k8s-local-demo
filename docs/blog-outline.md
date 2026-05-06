# Blog Outline: Securing Temporal Workflows with Vault on Kubernetes

Status: living outline. Do not treat this as a final draft until the Kubernetes auth, Transit, least-privilege, and polish milestones are complete.

## Working Titles

- Securing Temporal Workflows with HashiCorp Vault on Kubernetes
- Temporal + Vault on Kubernetes: Dynamic DB Credentials and Encrypted Workflow Payloads
- Protecting Temporal Workers and Workflow Data with Vault

## Thesis

Temporal orchestrates long-running business workflows. Vault can provide the security control plane around those workflows: workload identity, dynamic database credentials, and payload protection.

## Target Audience

- Platform engineers running Kubernetes.
- Security engineers evaluating Vault integration patterns.
- Temporal users who need stronger secrets and payload protection.
- HashiCorp practitioners looking for a concrete workflow orchestration demo.

## Demo Arc

1. Run a local order workflow with Temporal.
2. Show the static credential problem.
3. Replace static Postgres credentials with Vault dynamic credentials.
4. Replace the static Vault token with Vault Kubernetes auth.
5. Add sensitive order payload fields.
6. Protect workflow payloads with Vault Transit.
7. Add per-activity least-privilege DB roles.
8. Show failure scenarios and compensation.

## Core Message

Temporal should orchestrate durable business processes. Vault should own the security controls around the worker:

- how the worker proves its identity
- how it gets database access
- how long that access lasts
- how sensitive workflow data is protected
- how activity-level access can follow least privilege

## Proposed Structure

### 1. Why This Demo Exists

Most examples show Temporal and Vault separately. This demo ties them together in a local, runnable Kubernetes environment.

### 2. The Order Workflow

Describe the workflow:

```text
validate order -> reserve inventory -> process payment -> fulfill -> notify
```

Initial scenarios:

- `ORD-001`: happy path
- `ORD-002`: out of stock
- `ORD-003`: payment failure with compensation

### 3. Milestone 1: Temporal + Postgres

Show the baseline:

- Temporal server
- Temporal UI
- Postgres
- Python worker
- Python trigger client

Key point:

```text
Temporal works, but database credentials are still static.
```

### 4. Milestone 2: Vault Dynamic Database Credentials

Show before:

```text
make worker        -> db_credential_source=static
```

Show after:

```text
make worker-vault  -> db_credential_source=vault
```

Evidence:

```text
using_vault_db_credentials db_username=v-token-order-...
```

Explain:

- Vault database secrets engine
- short-lived Postgres users
- leases and revocation
- why this improves over static passwords

### 5. Milestone 3: Vault Kubernetes Auth

Explain the Secret Zero problem:

```text
How does the worker safely get its first Vault token?
```

Show the target:

```text
Kubernetes ServiceAccount -> Vault Kubernetes auth -> Vault token
```

### 6. Milestone 4: Vault Transit Payload Encryption

Explain why the existing payload needs enrichment:

```text
ORD-001 alone is not sensitive enough to demonstrate payload protection.
```

Add sensitive demo fields:

- customer name
- customer email
- shipping address
- payment token or payment reference

Show before:

```text
Temporal history can show sensitive fields.
```

Show after:

```text
Temporal stores encrypted payloads.
Authorized decode path uses Vault Transit.
```

### 7. Milestone 5: Least Privilege + Failure Scenarios

Show per-activity DB roles:

- read orders
- write inventory
- write payments
- write fulfilments
- write notifications

Show failure scenarios:

- out of stock
- payment failure
- inventory compensation

### 8. Production Caveats

Be explicit:

- Vault dev mode is not production.
- Local `kind` is not production Kubernetes.
- Temporal is currently local/self-hosted and not hardened.
- TLS/mTLS is future scope.
- Audit logging, policy hardening, and operational runbooks are still needed.

### 9. What Readers Can Try

Point to the repository and basic commands:

```bash
make install
make up
make deploy
make wait
make db-init
make vault-init
make worker-vault
make trigger ORDER_ID=ORD-001
```

## Video Outline

1. Show the architecture diagram.
2. Run the baseline order workflow.
3. Show static worker mode.
4. Run Vault-backed worker mode.
5. Show generated `v-token-order-*` usernames.
6. Show Vault UI or leases.
7. Later: show Kubernetes auth.
8. Later: show encrypted payloads in Temporal history.

## Open Questions

- Should the final blog use the local demo only, or also compare it to the original cloud demo?
- Should the video be one long walkthrough or split into shorter episodes?
- Should Transit be implemented with a Python payload codec, a codec server, or both?
- How much production hardening should be covered in the main post versus a follow-up?
