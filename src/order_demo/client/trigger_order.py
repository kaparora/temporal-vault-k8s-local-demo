import asyncio
import os
import sys

import structlog
from temporalio.client import WorkflowFailureError
from temporalio.common import WorkflowIDConflictPolicy, WorkflowIDReusePolicy

from order_demo.workers.common.temporal_client import connect_temporal_client
from order_demo.workers.order_worker.workflows.order_fulfillment import (
    OrderFulfillmentInput,
    OrderFulfillmentWorkflow,
)

structlog.configure(wrapper_class=structlog.make_filtering_bound_logger(20))
logger = structlog.get_logger()


def demo_input_for_order(order_id: str) -> OrderFulfillmentInput:
    payment_token = os.getenv("DEMO_PAYMENT_TOKEN", "tok_demo_visa_4242_sensitive")
    if order_id == "ORD-003" and "DEMO_PAYMENT_TOKEN" not in os.environ:
        payment_token = "tok_demo_card_declined_sensitive"

    return OrderFulfillmentInput(
        order_id=order_id,
        customer_name=os.getenv("DEMO_CUSTOMER_NAME", "Avery Stone"),
        customer_email=os.getenv("DEMO_CUSTOMER_EMAIL", "avery.stone@example.com"),
        shipping_address=os.getenv("DEMO_SHIPPING_ADDRESS", "42 Market Street, Berlin"),
        payment_token=payment_token,
    )


async def main() -> None:
    if len(sys.argv) < 2:
        logger.error("usage", command="python -m order_demo.client.trigger_order ORD-001")
        sys.exit(1)

    order_id = sys.argv[1]
    temporal_client = await connect_temporal_client()
    task_queue = os.getenv("ORDERS_TASK_QUEUE", "orders-tq")

    logger.info("triggering_order", order_id=order_id, task_queue=task_queue)
    workflow_input = demo_input_for_order(order_id)

    try:
        result = await temporal_client.execute_workflow(
            OrderFulfillmentWorkflow.run,
            workflow_input,
            id=f"order-fulfillment-{order_id}",
            task_queue=task_queue,
            id_reuse_policy=WorkflowIDReusePolicy.ALLOW_DUPLICATE,
            id_conflict_policy=WorkflowIDConflictPolicy.TERMINATE_EXISTING,
        )
    except WorkflowFailureError as err:
        logger.error("order_failed", order_id=order_id, cause=str(err.__cause__ or err))
        sys.exit(2)

    logger.info("order_completed", result=result)


if __name__ == "__main__":
    asyncio.run(main())
