# Milestone 1: Local Temporal + Postgres

## Goal

Prove the local workflow loop before adding Vault.

Milestone 1 answers one question:

```text
can a local Python worker run an order workflow against Temporal and Postgres in Kubernetes?
```

The answer is yes.

## What We Built

- A local `kind` cluster.
- A `temporal-vault-demo` Kubernetes namespace.
- Postgres running in Kubernetes.
- Temporal server running in Kubernetes.
- Temporal UI running in Kubernetes.
- A local Python Temporal worker.
- A local Python client to trigger an order workflow.
- Seed database schema and data for `ORD-001`.
- Makefile commands for setup, deployment, port-forwarding, worker startup, trigger, status, logs, shell, tests, and teardown.

## Workflow

`ORD-001` runs the happy path:

1. Validate order.
2. Reserve inventory.
3. Process payment.
4. Mark order fulfilled.
5. Send notification.

The activity writes are idempotent for the Milestone 1 tables:

- inventory reservation uses `order_id` as the idempotency key
- payment uses `order_id` as the idempotency key
- fulfilment uses `order_id` as the idempotency key
- notification uses `(order_id, notification_type)` as the idempotency key

## Commands That Worked

Setup:

```bash
make install
make up
make deploy
make wait
make db-init
```

Long-running terminals:

```bash
make port-forward-temporal
make port-forward-postgres
make port-forward-ui
```

Worker and trigger:

```bash
make worker
make trigger ORDER_ID=ORD-001
```

Temporal UI:

```text
http://localhost:8080
```

## Verification

After the successful run, Postgres showed:

```text
orders:                  ORD-001 -> FULFILLED
inventory_reservations:  ORD-001 -> WIDGET-001 qty 1
payments:                ORD-001 -> 19.99 SUCCESS
notifications:           ORD-001 -> ORDER_FULFILLED SENT
```

Code validation also passed:

```bash
uv run ruff check .
uv run pytest
```

## Fixes And Lessons

Kubernetes injects service environment variables by default. That collided with container-level environment variables such as `POSTGRES_PORT` and `TEMPORAL_PORT`, so the manifests set:

```yaml
enableServiceLinks: false
```

The Temporal image did not contain the dynamic config path we initially pointed at, so that optional setting was removed.

`kubectl port-forward` connects to loopback inside the pod network namespace. Temporal needed to listen on all interfaces while still advertising the pod IP for membership:

```text
BIND_ON_IP=0.0.0.0
TEMPORAL_BROADCAST_ADDRESS=$(POD_IP)
TEMPORAL_ADDRESS=127.0.0.1:7233
```

Postgres `NUMERIC` values arrive in Python as `Decimal`. Temporal's default JSON payload converter does not serialize `Decimal`, so activity results convert `unit_price` to `float` in Milestone 1.

## Non-Scope

Milestone 1 intentionally does not include:

- Vault
- dynamic database credentials
- Vault Kubernetes auth
- per-activity database roles
- `ORD-002` out-of-stock flow
- `ORD-003` payment failure and compensation
- production Temporal, Postgres, or Kubernetes hardening

## Next

Milestone 2 adds Vault in Kubernetes and replaces static worker database credentials with short-lived credentials from Vault's database secrets engine.
