# Temporal Vault K8s Local Demo

## Purpose

Build a local-first reference demo showing how Temporal workflows can use Vault on Kubernetes for workload identity, dynamic database credentials, and payload protection.

This project is a fresh start inspired by the existing cloud demo in `../vault-temporal`, but it should be designed for local development from day one rather than directly ported.

The demo narrative:

1. Temporal orchestrates an order workflow.
2. Vault protects the worker's database access with short-lived credentials.
3. Vault Kubernetes auth removes static Vault tokens.
4. Vault Transit protects sensitive workflow payloads.
5. Least-privilege roles tighten each activity's database access.

## Collaboration Goal

Use this project to learn how to work with Codex and compare that workflow with the earlier Claude Code collaboration.

We should build in small, reviewable milestones. Each milestone should leave the repo runnable or at least clearly explain what is still missing.

## Target Architecture

Eventually, the local stack should include:

- `kind` or another local Kubernetes cluster
- Temporal server and Temporal UI
- Vault running in Kubernetes
- Postgres running in Kubernetes
- Python Temporal workers
- A Python client to trigger demo workflows
- Vault Kubernetes auth for worker identity
- Vault database secrets engine for short-lived Postgres credentials
- Vault Transit for workflow payload encryption
- Future: Vault PKI for Temporal mTLS certificates

## Demo Story

The order workflow should keep the same useful shape from the cloud demo:

1. Validate order
2. Reserve inventory
3. Process payment
4. Mark order fulfilled
5. Send notification

Initial test orders:

- `ORD-001`: happy path
- `ORD-002`: out of stock
- `ORD-003`: payment failure with inventory compensation

## What To Carry Over From The Cloud Demo

- The core order workflow narrative
- The three demo scenarios
- The idea of per-activity least-privilege database access
- Clear README instructions and diagrams
- Explicit teardown/reset commands
- Honest notes about what is and is not production-ready

## What To Redesign

- Use Kubernetes auth instead of AWS IAM auth.
- Make the local developer experience the primary interface.
- Add idempotent activity writes from the beginning.
- Use consistent environment variable names.
- Avoid relying on cloud Terraform state.
- Keep setup and teardown repeatable with `make` or scripts.
- Add tests and linting earlier.

## Proposed Milestones

### Milestone 1: Local Temporal + Postgres

Goal: prove the local workflow loop before adding Vault.

Expected outcome:

- Create a local Kubernetes cluster.
- Run Temporal and Temporal UI.
- Run Postgres.
- Start a Python order worker.
- Trigger `ORD-001` from a Python client.
- Document the commands.

Vault is intentionally out of scope for Milestone 1.

### Milestone 2: Add Vault

Goal: introduce Vault while keeping the first version simple.

Expected outcome:

- Run Vault locally in Kubernetes.
- Configure the database secrets engine.
- Fetch dynamic Postgres credentials from the worker.
- Keep the order flow working.

### Milestone 3: Kubernetes Auth

Goal: remove static Vault worker credentials.

Expected outcome:

- Configure Vault Kubernetes auth.
- Bind the order worker service account to a Vault role.
- Let the worker authenticate to Vault using its pod identity.

### Milestone 4: Vault Transit Payload Encryption

Goal: protect sensitive workflow data from being stored in plaintext in Temporal history.

Expected outcome:

- Enrich the order payload with realistic sensitive fields.
- Configure Vault Transit.
- Encrypt/decrypt workflow payloads through a Vault-backed payload codec.
- Show the before/after in Temporal UI or workflow history.

### Milestone 5: Least Privilege + Failure Scenarios

Goal: restore the strongest security story from the cloud demo.

Expected outcome:

- Per-activity Vault database roles.
- `ORD-002` out-of-stock failure.
- `ORD-003` payment failure with compensation.
- Idempotent database writes for retried activities.

### Milestone 6: Polish

Goal: make the project easy to demo and reset.

Expected outcome:

- `make up`
- `make deploy`
- `make worker`
- `make trigger ORDER_ID=ORD-001`
- `make down`
- README diagrams
- Troubleshooting notes

### Milestone 7: Blog + Video

Goal: turn the completed local demo into a public walkthrough.

Expected outcome:

- Publish a blog post explaining the architecture and demo arc.
- Record a video walkthrough showing the before/after Vault story.
- Include diagrams, commands, and clear caveats.
- Link to the GitHub repository.

### Future Scope: Vault PKI + Temporal mTLS

Goal: use Vault-issued certificates for Temporal worker/client authentication.

Expected outcome:

- Configure Vault PKI.
- Configure Temporal frontend TLS/mTLS.
- Issue worker/client certificates through Vault.
- Explore certificate renewal or rotation.

This is deliberately after the database credential, Kubernetes auth, Transit, and least-privilege stories.

## Working Style

Codex should:

- Inspect before changing.
- Make small, understandable commits or patches.
- Explain tradeoffs briefly as implementation choices come up.
- Prefer local repeatability over cleverness.
- Verify each milestone with real commands.
- Keep the old cloud demo as a reference, not a template to copy blindly.
