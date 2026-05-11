import asyncio
import os

import structlog
from temporalio.worker import Worker

from order_demo.workers.common.temporal_client import connect_temporal_client
from order_demo.workers.order_worker.activities.order_activities import OrderActivities
from order_demo.workers.order_worker.config import OrderWorkerConfig
from order_demo.workers.order_worker.workflows.order_fulfillment import OrderFulfillmentWorkflow

structlog.configure(wrapper_class=structlog.make_filtering_bound_logger(20))
logger = structlog.get_logger()


async def main() -> None:
    cfg = OrderWorkerConfig.from_env()
    temporal_client = await connect_temporal_client()
    task_queue = os.getenv("ORDERS_TASK_QUEUE", "orders-tq")
    activities = OrderActivities(cfg)

    logger.info(
        "starting_order_worker",
        task_queue=task_queue,
        db_credential_source=cfg.db_credential_source,
        vault_db_role=cfg.vault_db_role if cfg.use_vault_db_creds else None,
        vault_auth_method=cfg.vault_auth_method if cfg.use_vault_db_creds else None,
    )
    worker = Worker(
        temporal_client,
        task_queue=task_queue,
        workflows=[OrderFulfillmentWorkflow],
        activities=[
            activities.validate_order,
            activities.reserve_inventory,
            activities.release_inventory,
            activities.process_payment,
            activities.fail_order,
            activities.mark_order_fulfilled,
            activities.send_notification,
        ],
    )
    await worker.run()


if __name__ == "__main__":
    asyncio.run(main())
