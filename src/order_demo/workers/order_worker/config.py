from dataclasses import dataclass
import os


@dataclass(frozen=True)
class OrderWorkerConfig:
    postgres_host: str
    postgres_port: int
    postgres_db: str
    postgres_user: str
    postgres_password: str

    @classmethod
    def from_env(cls) -> "OrderWorkerConfig":
        return cls(
            postgres_host=os.getenv("POSTGRES_HOST", "localhost"),
            postgres_port=int(os.getenv("POSTGRES_PORT", "5432")),
            postgres_db=os.getenv("POSTGRES_DB", "temporal"),
            postgres_user=os.getenv("POSTGRES_USER", "temporal"),
            postgres_password=os.getenv("POSTGRES_PASSWORD", "temporal"),
        )
