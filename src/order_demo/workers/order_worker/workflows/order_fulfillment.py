from dataclasses import dataclass
from datetime import timedelta

from temporalio import workflow
from temporalio.common import RetryPolicy
from temporalio.exceptions import ActivityError

with workflow.unsafe.imports_passed_through():
    from order_demo.workers.order_worker.activities.order_activities import (
        FailOrderRequest,
        FulfillmentRequest,
        NotificationRequest,
        OrderActivities,
        PaymentRequest,
    )


@dataclass
class OrderFulfillmentInput:
    order_id: str
    customer_name: str
    customer_email: str
    shipping_address: str
    payment_token: str


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

        try:
            await workflow.execute_activity_method(
                OrderActivities.reserve_inventory,
                args=[inp.order_id, validated.item.product_id, validated.item.quantity],
                retry_policy=RETRY,
                start_to_close_timeout=timedelta(seconds=30),
            )
        except ActivityError:
            await workflow.execute_activity_method(
                OrderActivities.fail_order,
                FailOrderRequest(
                    order_id=inp.order_id,
                    status="OUT_OF_STOCK",
                    reason=f"Insufficient stock for {validated.item.product_id}",
                ),
                retry_policy=RETRY,
                start_to_close_timeout=timedelta(seconds=30),
            )
            raise

        try:
            await workflow.execute_activity_method(
                OrderActivities.process_payment,
                PaymentRequest(
                    order_id=inp.order_id,
                    amount=amount,
                    payment_token=inp.payment_token,
                ),
                retry_policy=RETRY,
                start_to_close_timeout=timedelta(seconds=30),
            )
        except ActivityError:
            await workflow.execute_activity_method(
                OrderActivities.release_inventory,
                inp.order_id,
                retry_policy=RETRY,
                start_to_close_timeout=timedelta(seconds=30),
            )
            await workflow.execute_activity_method(
                OrderActivities.fail_order,
                FailOrderRequest(
                    order_id=inp.order_id,
                    status="PAYMENT_FAILED",
                    reason="Payment declined",
                ),
                retry_policy=RETRY,
                start_to_close_timeout=timedelta(seconds=30),
            )
            raise

        await workflow.execute_activity_method(
            OrderActivities.mark_order_fulfilled,
            FulfillmentRequest(
                order_id=inp.order_id,
                shipping_address=inp.shipping_address,
            ),
            retry_policy=RETRY,
            start_to_close_timeout=timedelta(seconds=30),
        )
        await workflow.execute_activity_method(
            OrderActivities.send_notification,
            NotificationRequest(
                order_id=inp.order_id,
                customer_email=inp.customer_email,
                notification_type="ORDER_FULFILLED",
            ),
            retry_policy=RETRY,
            start_to_close_timeout=timedelta(seconds=30),
        )

        return f"Order {inp.order_id} fulfilled successfully"
