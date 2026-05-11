# Demo Scripts

These scripts are a narrated path through the local Temporal + Vault + Kubernetes demo.

They intentionally stay thin over `make` targets. `make` remains the operational source of truth; these scripts provide the demo talk track and expected observations.

Run scripts from the repository root:

```bash
./scripts/demo/00-check-prereqs.sh
./scripts/demo/01-start-local-stack.sh
./scripts/demo/02-before-vault.sh
./scripts/demo/03-after-vault.sh
./scripts/demo/04-kubernetes-auth.sh
./scripts/demo/05-before-transit.sh
./scripts/demo/06-after-transit.sh
./scripts/demo/07-least-privilege-and-failures.sh
```

Use this whenever you want to reset demo data without deleting the cluster:

```bash
./scripts/demo/08-reset-demo-data.sh
```

Long-running commands:

- `make port-forward` keeps running until you stop it.
- `make worker` and `make worker-vault` keep running until you stop them.
- The Kubernetes worker scripts deploy a pod and then return.

For a live demo, keep one terminal for port-forwards, one for local workers, and one for the numbered scripts.
