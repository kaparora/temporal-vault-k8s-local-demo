from dataclasses import dataclass
import os


@dataclass(frozen=True)
class OrderWorkerConfig:
    postgres_host: str
    postgres_port: int
    postgres_db: str
    postgres_user: str
    postgres_password: str
    use_vault_db_creds: bool
    vault_addr: str
    vault_auth_method: str
    vault_token: str
    vault_kubernetes_role: str
    vault_kubernetes_jwt_path: str
    vault_db_mount: str
    vault_db_role: str

    @property
    def db_credential_source(self) -> str:
        if self.use_vault_db_creds:
            return "vault"
        return "static"

    @classmethod
    def from_env(cls) -> "OrderWorkerConfig":
        return cls(
            postgres_host=os.getenv("POSTGRES_HOST", "localhost"),
            postgres_port=int(os.getenv("POSTGRES_PORT", "5432")),
            postgres_db=os.getenv("POSTGRES_DB", "temporal"),
            postgres_user=os.getenv("POSTGRES_USER", "temporal"),
            postgres_password=os.getenv("POSTGRES_PASSWORD", "temporal"),
            use_vault_db_creds=os.getenv("USE_VAULT_DB_CREDS", "false").lower()
            in {"1", "true", "yes"},
            vault_addr=os.getenv("VAULT_ADDR", "http://localhost:8200"),
            vault_auth_method=os.getenv("VAULT_AUTH_METHOD", "token"),
            vault_token=os.getenv("VAULT_TOKEN", "root"),
            vault_kubernetes_role=os.getenv("VAULT_KUBERNETES_ROLE", "order-worker"),
            vault_kubernetes_jwt_path=os.getenv(
                "VAULT_KUBERNETES_JWT_PATH",
                "/var/run/secrets/kubernetes.io/serviceaccount/token",
            ),
            vault_db_mount=os.getenv("VAULT_DB_MOUNT", "database"),
            vault_db_role=os.getenv("VAULT_DB_ROLE", "order-worker"),
        )
