from dataclasses import dataclass

import hvac

from order_demo.workers.order_worker.config import OrderWorkerConfig


@dataclass(frozen=True)
class DbCredentials:
    username: str
    password: str


class VaultDbCredentialsClient:
    def __init__(self, cfg: OrderWorkerConfig):
        self.cfg = cfg

    def _client(self) -> hvac.Client:
        client = hvac.Client(url=self.cfg.vault_addr)
        if self.cfg.vault_auth_method == "kubernetes":
            with open(self.cfg.vault_kubernetes_jwt_path) as token_file:
                jwt = token_file.read()
            client.auth.kubernetes.login(
                role=self.cfg.vault_kubernetes_role,
                jwt=jwt,
            )
            return client

        client.token = self.cfg.vault_token
        return client

    def generate_credentials(self) -> DbCredentials:
        client = self._client()
        response = client.secrets.database.generate_credentials(
            name=self.cfg.vault_db_role,
            mount_point=self.cfg.vault_db_mount,
        )
        data = response["data"]
        return DbCredentials(username=data["username"], password=data["password"])
