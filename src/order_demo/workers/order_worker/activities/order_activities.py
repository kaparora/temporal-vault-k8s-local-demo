from dataclasses import dataclass
import asyncpg
import structlog
from temporalio import activity
from temporalio.exceptions import ApplicationError

from order_demo.workers.order_worker.config import OrderWorkerConfig
from order_demo.workers.order_worker.vault_client import VaultDbCredentialsClient

logger = structlog.get_logger()

VALIDATE_ORDER_DB_ROLE = "order-validate"
RESERVE_INVENTORY_DB_ROLE = "order-reserve-inventory"
RELEASE_INVENTORY_DB_ROLE = "order-release-inventory"
PROCESS_PAYMENT_DB_ROLE = "order-process-payment"
FULFILL_ORDER_DB_ROLE = "order-fulfill"
FAIL_ORDER_DB_ROLE = "order-fail"
SEND_NOTIFICATION_DB_ROLE = "order-send-notification"


@dataclass
class OrderItem:
    product_id: str
    quantity: int
    unit_price: float


@dataclass
class ValidateOrderResult:
    order_id: str
    customer_id: str
    item: OrderItem


@dataclass
class PaymentRequest:
    order_id: str
    amount: float
    payment_token: str


@dataclass
class FulfillmentRequest:
    order_id: str
    shipping_address: str


@dataclass
class NotificationRequest:
    order_id: str
    customer_email: str
    notification_type: str


@dataclass
class FailOrderRequest:
    order_id: str
    status: str
    reason: str


class OrderActivities:
    def __init__(self, cfg: OrderWorkerConfig):
        self.cfg = cfg
        self.vault_client = VaultDbCredentialsClient(cfg)

    async def _connect(self, vault_db_role: str | None = None) -> asyncpg.Connection:
        username = self.cfg.postgres_user
        password = self.cfg.postgres_password
        if self.cfg.use_vault_db_creds:
            role = vault_db_role or self.cfg.vault_db_role
            creds = self.vault_client.generate_credentials(role)
            username = creds.username
            password = creds.password
            logger.info(
                "using_vault_db_credentials",
                vault_db_role=role,
                db_username=username,
            )

        return await asyncpg.connect(
            host=self.cfg.postgres_host,
            port=self.cfg.postgres_port,
            user=username,
            password=password,
            database=self.cfg.postgres_db,
        )

    @activity.defn
    async def validate_order(self, order_id: str) -> ValidateOrderResult:
        activity.logger.info("validating_order", order_id=order_id)
        conn = await self._connect(VALIDATE_ORDER_DB_ROLE)
        try:
            order = await conn.fetchrow(
                "SELECT id, customer_id, status FROM orders WHERE id = $1",
                order_id,
            )
            if order is None:
                raise ValueError(f"Order {order_id} not found")
            if order["status"] not in {"PENDING", "FULFILLED"}:
                raise ValueError(f"Order {order_id} is not fulfillable: {order['status']}")

            item = await conn.fetchrow(
                """
                SELECT product_id, quantity, unit_price
                FROM order_items
                WHERE order_id = $1
                """,
                order_id,
            )
            if item is None:
                raise ValueError(f"Order {order_id} has no items")

            return ValidateOrderResult(
                order_id=order["id"],
                customer_id=order["customer_id"],
                item=OrderItem(
                    product_id=item["product_id"],
                    quantity=item["quantity"],
                    unit_price=float(item["unit_price"]),
                ),
            )
        finally:
            await conn.close()

    @activity.defn
    async def reserve_inventory(self, order_id: str, product_id: str, quantity: int) -> None:
        activity.logger.info(
            "reserving_inventory",
            order_id=order_id,
            product_id=product_id,
            quantity=quantity,
        )
        conn = await self._connect(RESERVE_INVENTORY_DB_ROLE)
        try:
            async with conn.transaction():
                existing = await conn.fetchrow(
                    "SELECT order_id FROM inventory_reservations WHERE order_id = $1",
                    order_id,
                )
                if existing is not None:
                    return

                result = await conn.execute(
                    """
                    UPDATE inventory
                    SET quantity = quantity - $1,
                        updated_at = NOW()
                    WHERE product_id = $2
                      AND quantity >= $1
                    """,
                    quantity,
                    product_id,
                )
                if int(result.split()[-1]) == 0:
                    raise ApplicationError(
                        f"Insufficient stock for product {product_id}",
                        type="OutOfStock",
                        non_retryable=True,
                    )

                await conn.execute(
                    """
                    INSERT INTO inventory_reservations (order_id, product_id, quantity)
                    VALUES ($1, $2, $3)
                    """,
                    order_id,
                    product_id,
                    quantity,
                )
        finally:
            await conn.close()

    @activity.defn
    async def release_inventory(self, order_id: str) -> None:
        activity.logger.info("releasing_inventory", order_id=order_id)
        conn = await self._connect(RELEASE_INVENTORY_DB_ROLE)
        try:
            async with conn.transaction():
                reservation = await conn.fetchrow(
                    """
                    SELECT product_id, quantity
                    FROM inventory_reservations
                    WHERE order_id = $1
                    """,
                    order_id,
                )
                if reservation is None:
                    return

                await conn.execute(
                    """
                    UPDATE inventory
                    SET quantity = quantity + $1,
                        updated_at = NOW()
                    WHERE product_id = $2
                    """,
                    reservation["quantity"],
                    reservation["product_id"],
                )
                await conn.execute(
                    "DELETE FROM inventory_reservations WHERE order_id = $1",
                    order_id,
                )
        finally:
            await conn.close()

    @activity.defn
    async def process_payment(self, req: PaymentRequest) -> None:
        activity.logger.info(
            "processing_payment",
            order_id=req.order_id,
            amount=str(req.amount),
            payment_token_suffix=req.payment_token[-4:],
        )
        conn = await self._connect(PROCESS_PAYMENT_DB_ROLE)
        try:
            if "declined" in req.payment_token:
                await conn.execute(
                    """
                    INSERT INTO payments (order_id, amount, status)
                    VALUES ($1, $2, 'FAILED')
                    ON CONFLICT (order_id) DO UPDATE
                    SET amount = EXCLUDED.amount,
                        status = EXCLUDED.status
                    """,
                    req.order_id,
                    req.amount,
                )
                raise ApplicationError(
                    f"Payment declined for order {req.order_id}",
                    type="PaymentDeclined",
                    non_retryable=True,
                )

            await conn.execute(
                """
                INSERT INTO payments (order_id, amount, status)
                VALUES ($1, $2, 'SUCCESS')
                ON CONFLICT (order_id) DO NOTHING
                """,
                req.order_id,
                req.amount,
            )
        finally:
            await conn.close()

    @activity.defn
    async def fail_order(self, req: FailOrderRequest) -> None:
        activity.logger.info(
            "failing_order",
            order_id=req.order_id,
            status=req.status,
            reason=req.reason,
        )
        conn = await self._connect(FAIL_ORDER_DB_ROLE)
        try:
            await conn.execute(
                """
                UPDATE orders
                SET status = $2,
                    updated_at = NOW()
                WHERE id = $1
                """,
                req.order_id,
                req.status,
            )
        finally:
            await conn.close()

    @activity.defn
    async def mark_order_fulfilled(self, req: FulfillmentRequest) -> None:
        activity.logger.info(
            "marking_order_fulfilled",
            order_id=req.order_id,
            shipping_address=req.shipping_address,
        )
        conn = await self._connect(FULFILL_ORDER_DB_ROLE)
        try:
            async with conn.transaction():
                await conn.execute(
                    """
                    UPDATE orders
                    SET status = 'FULFILLED',
                        updated_at = NOW()
                    WHERE id = $1
                    """,
                    req.order_id,
                )
                await conn.execute(
                    """
                    INSERT INTO fulfilments (order_id, status)
                    VALUES ($1, 'COMPLETED')
                    ON CONFLICT (order_id) DO NOTHING
                    """,
                    req.order_id,
                )
        finally:
            await conn.close()

    @activity.defn
    async def send_notification(self, req: NotificationRequest) -> None:
        activity.logger.info(
            "sending_notification",
            order_id=req.order_id,
            customer_email=req.customer_email,
            notification_type=req.notification_type,
        )
        conn = await self._connect(SEND_NOTIFICATION_DB_ROLE)
        try:
            await conn.execute(
                """
                INSERT INTO notifications (order_id, notification_type, status)
                VALUES ($1, $2, 'SENT')
                ON CONFLICT (order_id, notification_type) DO NOTHING
                """,
                req.order_id,
                req.notification_type,
            )
        finally:
            await conn.close()
