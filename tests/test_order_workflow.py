from order_demo.workers.order_worker.workflows.order_fulfillment import OrderFulfillmentInput


def test_order_fulfillment_input_has_order_id() -> None:
    assert OrderFulfillmentInput(order_id="ORD-001").order_id == "ORD-001"
