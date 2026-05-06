# Roadmap

This project is a local-first demo of Temporal, Vault, Postgres, and Kubernetes.

The demo story should build in layers:

1. Prove the workflow locally.
2. Show Vault issuing dynamic database credentials to the Temporal worker.
3. Replace static Vault tokens with Kubernetes workload identity.
4. Protect sensitive workflow payloads with Vault Transit.
5. Add least-privilege database roles and failure scenarios.

## Completed

### Milestone 1: Local Temporal + Postgres

Status: complete.

Proved the local workflow loop:

- `kind`
- Postgres in Kubernetes
- Temporal and Temporal UI in Kubernetes
- local Python worker
- local Python trigger client
- `ORD-001` happy path

Details: [Milestone 1](milestone-1.md)

### Milestone 2: Add Vault Database Secrets

Status: complete.

Added the before/after credential demo:

```text
make worker        -> static Postgres credentials
make worker-vault  -> Vault-generated Postgres credentials
```

The Vault-backed worker logs generated database usernames such as:

```text
v-token-order-...
```

Details: [Milestone 2](milestone-2.md)

## Planned

### Milestone 3: Vault Kubernetes Auth

Goal: remove the static `VAULT_TOKEN=root` worker authentication path.

Expected outcome:

- Run the order worker in Kubernetes or otherwise give it a Kubernetes service account identity.
- Configure Vault Kubernetes auth.
- Bind the worker service account to a Vault role.
- Let the worker obtain a Vault token using Kubernetes auth.
- Keep the dynamic Postgres credential flow working.

Why this comes next:

```text
Kubernetes identity -> Vault auth -> database credentials
```

That same identity foundation can later authorize Transit encrypt/decrypt.

### Milestone 4: Vault Transit Payload Encryption

Goal: protect sensitive workflow data from Temporal server history.

The current workflow payload is not rich enough for this demo because it only carries an order ID. Before adding encryption, enrich the payload with sensitive demo fields:

- customer name
- customer email
- shipping address
- payment token or payment reference

Expected before/after:

```text
Before Transit:
  Temporal history can show sensitive order payload fields.

After Transit:
  Temporal stores encrypted payloads.
  Authorized decode paths can decrypt through Vault Transit.
```

Implementation direction:

- Configure Vault Transit.
- Add a payload codec or converter backed by Vault Transit.
- Optionally add a codec server for Temporal UI decode support.
- Re-run the order workflow and show protected payloads.

### Milestone 5: Least Privilege + Failure Scenarios

Goal: restore the strongest database security and workflow behavior from the cloud demo.

Expected outcome:

- Per-activity Vault database roles.
- `ORD-002` out-of-stock scenario.
- `ORD-003` payment failure scenario.
- Inventory compensation after payment failure.
- Idempotent writes for retried activities.

### Milestone 6: Polish

Goal: make the project easy to demo, reset, and explain.

Expected outcome:

- Tight README walkthrough.
- Reset/teardown commands.
- Diagrams.
- Troubleshooting notes.
- Clear production caveats.

## Future Scope

### Vault PKI + Temporal mTLS

Goal: use Vault-issued certificates for Temporal worker/client authentication.

This is deliberately future scope because the current Temporal server is unauthenticated plaintext gRPC. A proper mTLS demo would require:

- Vault PKI engine.
- Temporal frontend TLS/mTLS configuration.
- Worker/client certificate issuance.
- Trust distribution.
- Certificate renewal or rotation.

This is valuable, but it should come after the Kubernetes auth, Transit, and least-privilege stories are solid.
