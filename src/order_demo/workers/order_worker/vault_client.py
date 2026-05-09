from dataclasses import dataclass

import hvac

from order_demo.vault_auth import VaultAuthConfig, authenticated_vault_client
from order_demo.workers.order_worker.config import OrderWorkerConfig


@dataclass(frozen=True)
class DbCredentials:
    username: str
    password: str


class VaultDbCredentialsClient:
    def __init__(self, cfg: OrderWorkerConfig):
        self.cfg = cfg

    def _client(self) -> hvac.Client:
        return authenticated_vault_client(
            VaultAuthConfig(
                vault_addr=self.cfg.vault_addr,
                vault_auth_method=self.cfg.vault_auth_method,
                vault_token=self.cfg.vault_token,
                vault_kubernetes_role=self.cfg.vault_kubernetes_role,
                vault_kubernetes_jwt_path=self.cfg.vault_kubernetes_jwt_path,
            )
        )

    def generate_credentials(self) -> DbCredentials:
        client = self._client()
        response = client.secrets.database.generate_credentials(
            name=self.cfg.vault_db_role,
            mount_point=self.cfg.vault_db_mount,
        )
        data = response["data"]
        return DbCredentials(username=data["username"], password=data["password"])
