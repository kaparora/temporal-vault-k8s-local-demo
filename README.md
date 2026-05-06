# Temporal Vault K8s Local Demo

Local-first reference demo showing how Temporal workflows can use Vault on Kubernetes for workload identity, dynamic database credentials, and payload protection.

Current status: Milestone 2 is complete.

The demo now shows a before/after Vault story:

- before Vault: the worker uses static Postgres credentials
- after Vault: the worker gets short-lived Postgres credentials from Vault's database secrets engine

The full demo arc is:

1. Temporal orchestrates an order workflow.
2. Vault protects the worker's database access.
3. Vault Kubernetes auth removes static Vault tokens.
4. Vault Transit protects sensitive workflow payloads.
5. Least-privilege roles tighten each activity's database access.

## Milestones

- [Roadmap](docs/roadmap.md)
- [Milestone 1: Local Temporal + Postgres](docs/milestone-1.md)
- [Milestone 2: Add Vault](docs/milestone-2.md)
- [Blog outline](docs/blog-outline.md)

## Prerequisites

- Docker
- `kind`
- `kubectl`
- Python 3.12
- `uv`

## Quick Start

```bash
make install
make up
make deploy
make wait
make db-init
make vault-init
```

Keep these long-running port-forwards open while using the local worker:

```bash
make port-forward-temporal
make port-forward-postgres
make port-forward-vault
make port-forward-ui
```

Alternatively, run all four in one terminal:

```bash
make port-forward
```

In another terminal, start the before-Vault worker with static database credentials:

```bash
make worker
```

Or start the after-Vault worker with dynamic database credentials:

```bash
make worker-vault
```

In a third terminal, trigger the happy-path order:

```bash
make trigger ORDER_ID=ORD-001
```

Temporal UI is available at:

```text
http://localhost:8080
```

## Useful Commands

```bash
make status
make vault-init
make vault-read-db-creds
make vault-test-db-creds
make port-forward-temporal
make port-forward-postgres
make port-forward-vault
make port-forward-ui
make logs-temporal
make logs-postgres
make logs-vault
make worker
make worker-vault
make db-shell
make down
```

## Current Demo

The current workflow supports the `ORD-001` happy path:

- `ORD-001`: validates, reserves inventory, processes payment, marks fulfilled, sends notification

Successful runs leave this database state:

```text
orders:                  ORD-001 -> FULFILLED
inventory_reservations:  ORD-001 -> WIDGET-001 qty 1
payments:                ORD-001 -> 19.99 SUCCESS
notifications:           ORD-001 -> ORDER_FULFILLED SENT
```

The before/after demo is:

```text
make worker        -> db_credential_source=static
make worker-vault  -> db_credential_source=vault
```

In Vault mode, the worker logs generated Postgres usernames such as `v-token-order-...`.

Before Vault:

```bash
make worker
make trigger ORDER_ID=ORD-001
```

After Vault:

```bash
make vault-init
make worker-vault
make trigger ORDER_ID=ORD-001
```

Completed milestone details are captured in [docs/milestone-1.md](docs/milestone-1.md) and [docs/milestone-2.md](docs/milestone-2.md).

Later milestones add:

- Vault Kubernetes auth
- Vault Transit payload encryption
- per-activity least-privilege database roles
- `ORD-002` out-of-stock failure
- `ORD-003` payment failure with compensation
- future Vault PKI + Temporal mTLS

## Target Architecture

```mermaid
flowchart LR
    client["Trigger Client"] -->|"starts order workflow"| temporal

    subgraph k8s["kind Kubernetes cluster"]
        temporal["Temporal Server\norchestration + history"]
        ui["Temporal UI"]
        worker["Order Worker Pod\nKubernetes ServiceAccount"]
        vault["Vault\nKubernetes Auth + DB Secrets + Transit"]
        postgres["Postgres\norders database"]
    end

    worker -->|"polls task queue"| temporal
    ui -->|"views workflow history"| temporal

    worker -->|"authenticates with\nServiceAccount JWT"| vault
    vault -->|"issues Vault token"| worker
    worker -->|"reads database/creds/<role>"| vault
    vault -->|"creates short-lived\nPostgres user"| postgres
    worker -->|"connects with dynamic creds"| postgres
    worker -->|"encrypts/decrypts payloads\nwith Transit"| vault
```

Current status: Milestone 2 runs Temporal, Temporal UI, Postgres, and Vault in `kind`, but the trigger client and worker still run locally through port-forwarding. Milestone 3 moves the worker into Kubernetes and replaces `VAULT_TOKEN=root` with Vault Kubernetes auth.

## Notes

This is a local development demo, not a production deployment. Milestone 2 still uses Vault dev mode and a static root token for worker-to-Vault authentication. Milestone 3 replaces that with Vault Kubernetes auth.
