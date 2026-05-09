import os

from temporalio.client import Client

from order_demo.temporal_payload_codec import build_data_converter_from_env


async def connect_temporal_client() -> Client:
    address = os.getenv("TEMPORAL_ADDRESS", "localhost:7233")
    namespace = os.getenv("TEMPORAL_NAMESPACE", "default")
    return await Client.connect(
        address,
        namespace=namespace,
        data_converter=build_data_converter_from_env(),
    )
