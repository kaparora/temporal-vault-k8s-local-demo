from dataclasses import dataclass
import os

import hvac


@dataclass(frozen=True)
class VaultAuthConfig:
    vault_addr: str
    vault_auth_method: str
    vault_token: str
    vault_kubernetes_role: str
    vault_kubernetes_jwt_path: str

    @classmethod
    def from_env(cls) -> "VaultAuthConfig":
        return cls(
            vault_addr=os.getenv("VAULT_ADDR", "http://localhost:8200"),
            vault_auth_method=os.getenv("VAULT_AUTH_METHOD", "token"),
            vault_token=os.getenv("VAULT_TOKEN", "root"),
            vault_kubernetes_role=os.getenv("VAULT_KUBERNETES_ROLE", "order-worker"),
            vault_kubernetes_jwt_path=os.getenv(
                "VAULT_KUBERNETES_JWT_PATH",
                "/var/run/secrets/kubernetes.io/serviceaccount/token",
            ),
        )


def authenticated_vault_client(cfg: VaultAuthConfig) -> hvac.Client:
    client = hvac.Client(url=cfg.vault_addr)
    if cfg.vault_auth_method == "kubernetes":
        with open(cfg.vault_kubernetes_jwt_path) as token_file:
            jwt = token_file.read()
        client.auth.kubernetes.login(
            role=cfg.vault_kubernetes_role,
            jwt=jwt,
        )
        return client

    client.token = cfg.vault_token
    return client
