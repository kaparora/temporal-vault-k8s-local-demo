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

    def generate_credentials(self) -> DbCredentials:
        client = hvac.Client(url=self.cfg.vault_addr, token=self.cfg.vault_token)
        response = client.secrets.database.generate_credentials(
            name=self.cfg.vault_db_role,
            mount_point=self.cfg.vault_db_mount,
        )
        data = response["data"]
        return DbCredentials(username=data["username"], password=data["password"])
