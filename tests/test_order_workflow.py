from order_demo.workers.order_worker.workflows.order_fulfillment import OrderFulfillmentInput


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
