# Milestone 5: Least Privilege + Failure Scenarios

Status: complete.

Milestone 5 makes the Transit before/after demo more obvious, adds realistic failure paths, and tightens database access with per-activity Vault database roles.

## Milestone 5A: Sensitive Activity Payloads

Status: complete.

Goal: make sensitive data visible in Temporal UI before Transit and hidden after Transit.

Milestone 4 added sensitive fields to the workflow input:

- customer name
- customer email
- shipping address
- payment token

Milestone 5A also passes sensitive fields into activity inputs:

- `process_payment` receives `payment_token`
- `mark_order_fulfilled` receives `shipping_address`
- `send_notification` receives `customer_email`

This gives the demo a clearer before/after:

```text
Before Transit:
  Temporal UI can show sensitive workflow and activity payload fields.

After Transit:
  Temporal UI shows encrypted payloads such as binary/vault-transit.
```

## Demo Commands

Before Transit:

```bash
make worker-k8s
```

Keep Temporal reachable in another terminal:

```bash
make port-forward-temporal
make port-forward-ui
```

Then trigger the workflow:

```bash
make trigger ORDER_ID=ORD-001
```

In Temporal UI, inspect the workflow input and activity inputs. You should be able to see values like:

```text
avery.stone@example.com
42 Market Street, Berlin
tok_demo_visa_4242_sensitive
```

After Transit:

```bash
make worker-k8s-transit
```

Keep Temporal and Vault reachable in another terminal:

```bash
make port-forward-temporal
make port-forward-vault
make port-forward-ui
```

Then trigger the Transit workflow:

```bash
make trigger-transit ORDER_ID=ORD-001
```

In Temporal UI, those sensitive values should no longer be visible in encoded payloads.

The before-Transit path uses task queue `orders-tq`; the after-Transit path uses `orders-tq-transit`. Keeping those queues separate prevents encrypted payloads from being delivered to a worker that is intentionally running without the Transit codec.

## Milestone 5B: Failure Scenarios

Status: complete.

Goal: show Temporal's durable workflow behavior when business failures happen.

Demo orders:

- `ORD-001`: happy path
- `ORD-002`: out of stock
- `ORD-003`: payment failure after inventory reservation

Expected behavior:

```text
ORD-001:
  order status: FULFILLED
  inventory reservation: present
  payment: SUCCESS
  notification: SENT

ORD-002:
  order status: OUT_OF_STOCK
  inventory reservation: absent
  payment: absent
  notification: absent

ORD-003:
  order status: PAYMENT_FAILED
  inventory reservation: absent after compensation
  payment: FAILED
  notification: absent
```

The payment failure uses a deterministic demo token:

```text
tok_demo_card_declined_sensitive
```

The workflow compensates by releasing inventory after payment failure, then marks the order as `PAYMENT_FAILED`.

Demo commands:

```bash
make db-init
make worker-k8s
```

Keep Temporal reachable in another terminal:

```bash
make port-forward-temporal
```

Then run each order:

```bash
make trigger ORDER_ID=ORD-001
make trigger ORDER_ID=ORD-002
make trigger ORDER_ID=ORD-003
```

`ORD-002` and `ORD-003` intentionally fail at the workflow level, so `make trigger` exits non-zero for those two orders after the workflow records the expected terminal status.

Verified database state:

```text
orders:
  ORD-001 -> FULFILLED
  ORD-002 -> OUT_OF_STOCK
  ORD-003 -> PAYMENT_FAILED

inventory_reservations:
  ORD-001 -> WIDGET-001 qty 1
  ORD-002 -> absent
  ORD-003 -> absent

payments:
  ORD-001 -> SUCCESS
  ORD-003 -> FAILED
```

## Milestone 5C: Per-Activity Database Roles

Status: complete.

Goal: make Vault-issued Postgres credentials match the activity being executed.

The worker now requests these Vault database roles:

```text
validate_order         -> order-validate
reserve_inventory     -> order-reserve-inventory
release_inventory     -> order-release-inventory
process_payment       -> order-process-payment
mark_order_fulfilled  -> order-fulfill
fail_order            -> order-fail
send_notification     -> order-send-notification
```

This changes the security story from:

```text
worker gets one broad database credential
```

to:

```text
each activity gets short-lived credentials for only the tables it needs
```

The older broad `order-worker` database role has been removed. Helper commands now default to the narrow read-only `order-validate` role, and the worker activities request only their activity-specific roles during normal execution.

Role verification:

```bash
make vault-init
make vault-test-db-creds
make logs-worker
```

`make vault-init` prints the configured Vault database roles. The list should not include `order-worker`.

Verified with all three demo orders:

```text
ORD-001 -> FULFILLED
ORD-002 -> OUT_OF_STOCK
ORD-003 -> PAYMENT_FAILED
```

Worker logs show Vault-generated usernames for activity-specific roles such as:

```text
order-validate
order-reserve-inventory
order-release-inventory
order-process-payment
order-fulfill
order-fail
order-send-notification
```

## Idempotency Under Retries

The activity writes are safe to retry:

- `reserve_inventory` returns if a reservation already exists.
- `release_inventory` returns if there is no reservation to release.
- `process_payment` uses conflict handling for both success and failed payment rows.
- `mark_order_fulfilled` can repeat the order status update and uses conflict handling for the fulfilment row.
- `send_notification` uses conflict handling for the notification row.
- `fail_order` repeats the same terminal status update.

This keeps Temporal retries from duplicating reservations, payments, fulfilments, or notifications.

## Final Verification

Verified after removing the broad `order-worker` database role:

```text
make test  -> 9 passed
make lint  -> all checks passed
```

Vault database roles:

```text
order-fail
order-fulfill
order-process-payment
order-release-inventory
order-reserve-inventory
order-send-notification
order-validate
```

The `order-worker` name still exists as the Kubernetes ServiceAccount, Vault auth role, and Vault policy name. It is no longer a Vault database role.
