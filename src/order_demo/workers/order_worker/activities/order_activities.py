from dataclasses import dataclass
import asyncpg
import structlog
from temporalio import activity

from order_demo.workers.order_worker.config import OrderWorkerConfig
from order_demo.workers.order_worker.vault_client import VaultDbCredentialsClient

logger = structlog.get_logger()


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


class OrderActivities:
    def __init__(self, cfg: OrderWorkerConfig):
        self.cfg = cfg
        self.vault_client = VaultDbCredentialsClient(cfg)

    async def _connect(self) -> asyncpg.Connection:
        username = self.cfg.postgres_user
        password = self.cfg.postgres_password
        if self.cfg.use_vault_db_creds:
            creds = self.vault_client.generate_credentials()
            username = creds.username
            password = creds.password
            logger.info(
                "using_vault_db_credentials",
                vault_db_role=self.cfg.vault_db_role,
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
        conn = await self._connect()
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
        conn = await self._connect()
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
                    raise ValueError(f"Insufficient stock for product {product_id}")

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
    async def process_payment(self, order_id: str, amount: float) -> None:
        activity.logger.info("processing_payment", order_id=order_id, amount=str(amount))
        conn = await self._connect()
        try:
            await conn.execute(
                """
                INSERT INTO payments (order_id, amount, status)
                VALUES ($1, $2, 'SUCCESS')
                ON CONFLICT (order_id) DO NOTHING
                """,
                order_id,
                amount,
            )
        finally:
            await conn.close()

    @activity.defn
    async def mark_order_fulfilled(self, order_id: str) -> None:
        activity.logger.info("marking_order_fulfilled", order_id=order_id)
        conn = await self._connect()
        try:
            async with conn.transaction():
                await conn.execute(
                    """
                    UPDATE orders
                    SET status = 'FULFILLED',
                        updated_at = NOW()
                    WHERE id = $1
                    """,
                    order_id,
                )
                await conn.execute(
                    """
                    INSERT INTO fulfilments (order_id, status)
                    VALUES ($1, 'COMPLETED')
                    ON CONFLICT (order_id) DO NOTHING
                    """,
                    order_id,
                )
        finally:
            await conn.close()

    @activity.defn
    async def send_notification(self, order_id: str, notification_type: str) -> None:
        activity.logger.info(
            "sending_notification",
            order_id=order_id,
            notification_type=notification_type,
        )
        conn = await self._connect()
        try:
            await conn.execute(
                """
                INSERT INTO notifications (order_id, notification_type, status)
                VALUES ($1, $2, 'SENT')
                ON CONFLICT (order_id, notification_type) DO NOTHING
                """,
                order_id,
                notification_type,
            )
        finally:
            await conn.close()
