# Milestone 4: Vault Transit Payload Encryption

Status: complete.

Milestone 4 protects sensitive workflow payloads from being stored in plaintext in Temporal history.

## What Changes

Milestone 3 proved workload identity and dynamic database credentials:

```text
worker pod -> Kubernetes ServiceAccount JWT -> Vault Kubernetes auth -> dynamic Postgres credentials
```

Milestone 4 adds payload protection:

```text
trigger client + worker -> Vault Transit payload codec -> encrypted Temporal payloads
```

## Sensitive Demo Payload

Earlier milestones only sent an order ID into the workflow:

```text
ORD-001
```

That was not sensitive enough to make payload encryption meaningful. The workflow input now includes demo-sensitive fields:

- customer name
- customer email
- shipping address
- payment token

The worker still uses the order ID for the current business logic. The other fields exist to make the security behavior visible in Temporal history.

## Transit Codec

When `USE_VAULT_PAYLOAD_CODEC=true`, both the trigger client and worker use a Temporal `PayloadCodec` backed by Vault Transit.

The Transit demo uses a separate task queue, `orders-tq-transit`, so encrypted tasks are not accidentally picked up by a plaintext worker.

The codec:

- serializes the original Temporal payload
- asks Vault Transit to encrypt it
- stores the encrypted ciphertext as a Temporal payload with encoding `binary/vault-transit`
- asks Vault Transit to decrypt when an authorized client or worker needs to read the payload

## Commands

Deploy the Kubernetes worker with Transit enabled:

```bash
make worker-k8s-transit
```

Keep Temporal and Vault reachable from the laptop:

```bash
make port-forward-temporal
make port-forward-vault
make port-forward-ui
```

Trigger an encrypted-payload workflow:

```bash
make trigger-transit ORDER_ID=ORD-001
```

Inspect worker logs:

```bash
make logs-worker
```

Expected log signal:

```text
starting_order_worker db_credential_source=vault vault_auth_method=kubernetes
using_vault_db_credentials db_username=v-kubernet-order-...
```

In Temporal UI, payloads should appear encoded as `binary/vault-transit` instead of plaintext JSON containing the payment token.

## Verification

Milestone 4 was verified with:

```bash
make worker-k8s-transit
make port-forward-temporal
make port-forward-vault
make port-forward-ui
make trigger-transit ORDER_ID=ORD-001
make logs-worker
```

The workflow completed successfully with the Transit-enabled worker and Vault-generated database credentials.

## Why This Matters

Temporal history is durable by design. That is exactly what makes Temporal useful, but it also means workflow inputs, activity inputs, results, and failures need deliberate handling when they contain sensitive data.

Vault Transit lets the demo keep Temporal as the orchestrator while moving encryption authority into Vault.

## Caveats

- The local trigger client still uses `VAULT_TOKEN=root` to reach Vault Transit.
- The Kubernetes worker uses Vault Kubernetes auth and the `order-worker` Vault policy.
- Vault still runs in dev mode.
- A production system should use a proper codec server for controlled UI decode access.
