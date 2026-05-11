from order_demo.workers.order_worker.config import OrderWorkerConfig
from order_demo.workers.order_worker.activities.order_activities import (
    FAIL_ORDER_DB_ROLE,
    FULFILL_ORDER_DB_ROLE,
    PROCESS_PAYMENT_DB_ROLE,
    RELEASE_INVENTORY_DB_ROLE,
    RESERVE_INVENTORY_DB_ROLE,
    SEND_NOTIFICATION_DB_ROLE,
    VALIDATE_ORDER_DB_ROLE,
)


def test_static_db_credentials_are_default(monkeypatch) -> None:
    monkeypatch.delenv("USE_VAULT_DB_CREDS", raising=False)

    cfg = OrderWorkerConfig.from_env()

    assert cfg.use_vault_db_creds is False
    assert cfg.db_credential_source == "static"


def test_vault_db_credentials_can_be_enabled(monkeypatch) -> None:
    monkeypatch.setenv("USE_VAULT_DB_CREDS", "true")
    monkeypatch.setenv("VAULT_DB_ROLE", "order-validate")

    cfg = OrderWorkerConfig.from_env()

    assert cfg.use_vault_db_creds is True
    assert cfg.db_credential_source == "vault"
    assert cfg.vault_db_role == "order-validate"


def test_kubernetes_auth_can_be_enabled(monkeypatch) -> None:
    monkeypatch.setenv("VAULT_AUTH_METHOD", "kubernetes")
    monkeypatch.setenv("VAULT_KUBERNETES_ROLE", "order-worker")
    monkeypatch.setenv("VAULT_KUBERNETES_JWT_PATH", "/var/run/token")

    cfg = OrderWorkerConfig.from_env()

    assert cfg.vault_auth_method == "kubernetes"
    assert cfg.vault_kubernetes_role == "order-worker"
    assert cfg.vault_kubernetes_jwt_path == "/var/run/token"


def test_activity_database_roles_are_narrowly_named() -> None:
    assert VALIDATE_ORDER_DB_ROLE == "order-validate"
    assert RESERVE_INVENTORY_DB_ROLE == "order-reserve-inventory"
    assert RELEASE_INVENTORY_DB_ROLE == "order-release-inventory"
    assert PROCESS_PAYMENT_DB_ROLE == "order-process-payment"
    assert FULFILL_ORDER_DB_ROLE == "order-fulfill"
    assert FAIL_ORDER_DB_ROLE == "order-fail"
    assert SEND_NOTIFICATION_DB_ROLE == "order-send-notification"
