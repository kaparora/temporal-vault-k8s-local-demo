from dataclasses import dataclass
from datetime import timedelta

from temporalio import workflow
from temporalio.common import RetryPolicy

with workflow.unsafe.imports_passed_through():
    from order_demo.workers.order_worker.activities.order_activities import OrderActivities


@dataclass
class OrderFulfillmentInput:
    order_id: str


RETRY = RetryPolicy(
    maximum_attempts=3,
    initial_interval=timedelta(seconds=1),
    backoff_coefficient=2.0,
    maximum_interval=timedelta(seconds=10),
)


@workflow.defn
class OrderFulfillmentWorkflow:
    @workflow.run
    async def run(self, inp: OrderFulfillmentInput) -> str:
        validated = await workflow.execute_activity_method(
            OrderActivities.validate_order,
            inp.order_id,
            retry_policy=RETRY,
            start_to_close_timeout=timedelta(seconds=30),
        )
        amount = validated.item.quantity * validated.item.unit_price

        await workflow.execute_activity_method(
            OrderActivities.reserve_inventory,
            args=[inp.order_id, validated.item.product_id, validated.item.quantity],
            retry_policy=RETRY,
            start_to_close_timeout=timedelta(seconds=30),
        )
        await workflow.execute_activity_method(
            OrderActivities.process_payment,
            args=[inp.order_id, amount],
            retry_policy=RETRY,
            start_to_close_timeout=timedelta(seconds=30),
        )
        await workflow.execute_activity_method(
            OrderActivities.mark_order_fulfilled,
            inp.order_id,
            retry_policy=RETRY,
            start_to_close_timeout=timedelta(seconds=30),
        )
        await workflow.execute_activity_method(
            OrderActivities.send_notification,
            args=[inp.order_id, "ORDER_FULFILLED"],
            retry_policy=RETRY,
            start_to_close_timeout=timedelta(seconds=30),
        )

        return f"Order {inp.order_id} fulfilled successfully"
