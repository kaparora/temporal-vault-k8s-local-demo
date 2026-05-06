from order_demo.workers.order_worker.config import OrderWorkerConfig


def test_static_db_credentials_are_default(monkeypatch) -> None:
    monkeypatch.delenv("USE_VAULT_DB_CREDS", raising=False)

    cfg = OrderWorkerConfig.from_env()

    assert cfg.use_vault_db_creds is False
    assert cfg.db_credential_source == "static"


def test_vault_db_credentials_can_be_enabled(monkeypatch) -> None:
    monkeypatch.setenv("USE_VAULT_DB_CREDS", "true")
    monkeypatch.setenv("VAULT_DB_ROLE", "order-worker")

    cfg = OrderWorkerConfig.from_env()

    assert cfg.use_vault_db_creds is True
    assert cfg.db_credential_source == "vault"
    assert cfg.vault_db_role == "order-worker"


def test_kubernetes_auth_can_be_enabled(monkeypatch) -> None:
    monkeypatch.setenv("VAULT_AUTH_METHOD", "kubernetes")
    monkeypatch.setenv("VAULT_KUBERNETES_ROLE", "order-worker")
    monkeypatch.setenv("VAULT_KUBERNETES_JWT_PATH", "/var/run/token")

    cfg = OrderWorkerConfig.from_env()

    assert cfg.vault_auth_method == "kubernetes"
    assert cfg.vault_kubernetes_role == "order-worker"
    assert cfg.vault_kubernetes_jwt_path == "/var/run/token"
