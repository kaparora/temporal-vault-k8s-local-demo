import os

from temporalio.client import Client


async def connect_temporal_client() -> Client:
    address = os.getenv("TEMPORAL_ADDRESS", "localhost:7233")
    namespace = os.getenv("TEMPORAL_NAMESPACE", "default")
    return await Client.connect(address, namespace=namespace)
