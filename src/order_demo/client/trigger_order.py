import asyncio
import os
import sys

import structlog
from temporalio.common import WorkflowIDReusePolicy

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
    workflow_input = OrderFulfillmentInput(
        order_id=order_id,
        customer_name=os.getenv("DEMO_CUSTOMER_NAME", "Avery Stone"),
        customer_email=os.getenv("DEMO_CUSTOMER_EMAIL", "avery.stone@example.com"),
        shipping_address=os.getenv("DEMO_SHIPPING_ADDRESS", "42 Market Street, Berlin"),
        payment_token=os.getenv("DEMO_PAYMENT_TOKEN", "tok_demo_visa_4242_sensitive"),
    )

    result = await temporal_client.execute_workflow(
        OrderFulfillmentWorkflow.run,
        workflow_input,
        id=f"order-fulfillment-{order_id}",
        task_queue=task_queue,
        id_reuse_policy=WorkflowIDReusePolicy.ALLOW_DUPLICATE,
    )
    logger.info("order_completed", result=result)


if __name__ == "__main__":
    asyncio.run(main())
