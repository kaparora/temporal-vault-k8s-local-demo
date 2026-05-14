# Roadmap

This project is a local-first reference demo showing how Temporal workflows can use Vault on Kubernetes for workload identity, dynamic database credentials, and payload protection.

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
make worker-static    -> static Postgres credentials
make worker-vault-db  -> Vault-generated Postgres credentials
```

The Vault-backed worker logs generated database usernames such as:

```text
v-token-order-...
```

Details: [Milestone 2](milestone-2.md)

### Milestone 3: Vault Kubernetes Auth

Status: complete.

Goal: remove the static `VAULT_TOKEN=root` worker authentication path.

Outcome:

- Move the order worker into Kubernetes.
- Give the order worker a dedicated Kubernetes service account.
- Configure Vault Kubernetes auth.
- Bind the worker service account to a Vault role.
- Let the worker obtain a Vault token using Kubernetes auth.
- Keep the dynamic Postgres credential flow working.

Details: [Milestone 3](milestone-3.md)

Why this comes next:

```text
Kubernetes identity -> Vault auth -> database credentials
```

That same identity foundation can later authorize Transit encrypt/decrypt.

### Milestone 4: Vault Transit Payload Encryption

Status: complete.

Goal: protect sensitive workflow data from Temporal server history.

Outcome:

Sensitive workflow payloads now include:

- customer name
- customer email
- shipping address
- payment token

Before/after:

```text
Before Transit:
  Temporal history can show sensitive order payload fields.

After Transit:
  Temporal stores encrypted payloads.
  Authorized decode paths can decrypt through Vault Transit.
```

Implemented:

- Configure Vault Transit.
- Add a payload codec backed by Vault Transit.
- Use a separate Transit task queue so encrypted tasks are handled by a codec-enabled worker.
- Re-run the order workflow and show protected payloads in Temporal UI.

Details: [Milestone 4](milestone-4.md)

### Milestone 5: Least Privilege + Failure Scenarios

Status: complete.

Goal: restore the strongest database security and workflow behavior from the cloud demo.

Outcome:

- Make sensitive fields visible in activity payloads before Transit and hidden after Transit.
- `ORD-002` out-of-stock scenario.
- `ORD-003` payment failure scenario.
- Inventory compensation after payment failure.
- Per-activity Vault database roles.
- Idempotent writes for retried activities.
- Remove the broad compatibility `order-worker` database role.

Details: [Milestone 5](milestone-5.md)

## Planned

### Milestone 6: Polish

Status: in progress.

Goal: make the project easy to demo, reset, and explain.

Expected outcome:

- Tight README walkthrough.
- Numbered narrated demo scripts.
- Reset/teardown commands.
- Diagrams.
- Troubleshooting notes.
- Clear production caveats.

### Milestone 7: Blog + Video

Goal: turn the completed local demo into a public walkthrough.

Expected outcome:

- Publish a blog post with the architecture, demo narrative, commands, and caveats.
- Record a video walkthrough showing the demo in Temporal UI, Vault UI, worker logs, and Postgres.
- Explain why this topic matters and what production hardening remains.
- Link to the GitHub repository.

Working outline: [Blog outline](blog-outline.md)

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
