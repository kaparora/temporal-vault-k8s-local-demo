from order_demo.workers.order_worker.workflows.order_fulfillment import OrderFulfillmentInput
from order_demo.workers.order_worker.activities.order_activities import (
    FulfillmentRequest,
    NotificationRequest,
    PaymentRequest,
)


def test_order_fulfillment_input_has_order_id() -> None:
    inp = OrderFulfillmentInput(
        order_id="ORD-001",
        customer_name="Avery Stone",
        customer_email="avery.stone@example.com",
        shipping_address="42 Market Street, Berlin",
        payment_token="tok_demo_visa_4242_sensitive",
    )

    assert inp.order_id == "ORD-001"
    assert inp.payment_token == "tok_demo_visa_4242_sensitive"


def test_sensitive_activity_payloads_are_self_describing() -> None:
    payment = PaymentRequest(
        order_id="ORD-001",
        amount=19.99,
        payment_token="tok_demo_visa_4242_sensitive",
    )
    fulfillment = FulfillmentRequest(
        order_id="ORD-001",
        shipping_address="42 Market Street, Berlin",
    )
    notification = NotificationRequest(
        order_id="ORD-001",
        customer_email="avery.stone@example.com",
        notification_type="ORDER_FULFILLED",
    )

    assert payment.payment_token == "tok_demo_visa_4242_sensitive"
    assert fulfillment.shipping_address == "42 Market Street, Berlin"
    assert notification.customer_email == "avery.stone@example.com"
