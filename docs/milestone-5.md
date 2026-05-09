# Milestone 5: Least Privilege + Failure Scenarios

Status: in progress.

Milestone 5 starts by making the Transit before/after demo more obvious, then moves into least-privilege database roles and failure scenarios.

## Milestone 5A: Sensitive Activity Payloads

Status: in progress.

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
make port-forward-temporal
make port-forward-ui
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
make port-forward-temporal
make port-forward-vault
make port-forward-ui
make trigger-transit ORDER_ID=ORD-001
```

In Temporal UI, those sensitive values should no longer be visible in encoded payloads.

## Next Milestone 5 Work

- Add `ORD-002` out-of-stock.
- Add `ORD-003` payment failure.
- Add inventory compensation after payment failure.
- Split the broad `order-worker` database role into narrower per-activity roles.
- Keep database writes idempotent under retries.
