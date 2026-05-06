import asyncio
import os
import sys

import structlog

from order_demo.workers.common.temporal_client import connect_temporal_client
from order_demo.workers.order_worker.workflows.order_fulfillment import (
    OrderFulfillmentInput,
    OrderFulfillmentWorkflow,
)

structlog.configure(wrapper_class=structlog.make_filtering_bound_logger(20))
logger = structlog.get_logger()


async def main() -> None:
    if len(sys.argv) < 2:
        logger.error("usage", command="python -m order_demo.client.trigger_order ORD-001")
        sys.exit(1)

    order_id = sys.argv[1]
    temporal_client = await connect_temporal_client()
    task_queue = os.getenv("ORDERS_TASK_QUEUE", "orders-tq")

    logger.info("triggering_order", order_id=order_id, task_queue=task_queue)
    result = await temporal_client.execute_workflow(
        OrderFulfillmentWorkflow.run,
        OrderFulfillmentInput(order_id=order_id),
        id=f"order-fulfillment-{order_id}",
        task_queue=task_queue,
    )
    logger.info("order_completed", result=result)


if __name__ == "__main__":
    asyncio.run(main())
