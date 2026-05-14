# Demo Scripts

These scripts are a narrated path through the local Temporal + Vault + Kubernetes demo.

They intentionally stay thin over `make` targets. `make` remains the operational source of truth; these scripts provide the demo talk track and expected observations.

The filename tells you which terminal to use:

- `T1`: setup and port-forwards
- `T2`: long-running local workers
- `T3`: trigger commands, Kubernetes worker deployment, verification

Run the scripts from the repository root.

## Start

Terminal 1:

```bash
./scripts/demo/00_T1_check.sh
./scripts/demo/01_T1_setup.sh
./scripts/demo/02_T1_ports.sh
```

`02_T1_ports.sh` keeps running.

## Before Vault

Terminal 2:

```bash
./scripts/demo/03_T2_worker_static_db.sh
```

Terminal 3:

```bash
./scripts/demo/04_T3_show_security_problems.sh
```

## After Vault

Stop the static worker in Terminal 2 with `Ctrl-C`, then run:

```bash
./scripts/demo/05_T2_worker_vault_db.sh
```

Terminal 3:

```bash
./scripts/demo/06_T3_show_dynamic_creds.sh
```

## Kubernetes Identity

Stop the Vault worker in Terminal 2 with `Ctrl-C` before continuing. From this point on, the Kubernetes worker should be the only worker polling the demo task queues.

Terminal 2:

```bash
./scripts/demo/07_T2_worker_k8s_auth.sh
```

Terminal 3:

```bash
./scripts/demo/08_T3_show_k8s_identity.sh
./scripts/demo/09_T3_show_plaintext_payloads.sh
```

## Transit

Terminal 2:

```bash
./scripts/demo/10_T2_worker_transit.sh
```

Terminal 3:

```bash
./scripts/demo/11_T3_show_transit_encryption.sh
```

## Least Privilege And Failures

Switch Terminal 2 back to the normal Kubernetes worker before this step:

```bash
./scripts/demo/07_T2_worker_k8s_auth.sh
```

Terminal 3:

```bash
./scripts/demo/12_T3_show_least_privilege_and_failures.sh
```

Use this whenever you want to reset demo data without deleting the cluster:

```bash
./scripts/demo/13_T3_reset.sh
```

Use this at the end of the demo to delete the local kind cluster:

```bash
./scripts/demo/14_T1_cleanup.sh
```

## Long-Running Scripts

- `02_T1_ports.sh` runs until stopped.
- `03_T2_worker_static_db.sh` runs until stopped.
- `05_T2_worker_vault_db.sh` runs until stopped.
- Kubernetes worker scripts deploy a pod and then return.
