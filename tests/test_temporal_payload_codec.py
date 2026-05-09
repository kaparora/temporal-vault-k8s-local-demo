import base64

import pytest
from temporalio.api.common.v1 import Payload

from order_demo.temporal_payload_codec import (
    VAULT_TRANSIT_ENCODING,
    VaultTransitConfig,
    VaultTransitPayloadCodec,
)
from order_demo.vault_auth import VaultAuthConfig


class FakeTransit:
    def encrypt_data(self, name, plaintext, mount_point):
        return {"data": {"ciphertext": f"vault:v1:{plaintext}"}}

    def decrypt_data(self, name, ciphertext, mount_point):
        plaintext = ciphertext.removeprefix("vault:v1:")
        return {"data": {"plaintext": plaintext}}


class FakeSecrets:
    transit = FakeTransit()


class FakeVaultClient:
    secrets = FakeSecrets()


@pytest.mark.asyncio
async def test_vault_transit_payload_codec_round_trips_payload(monkeypatch) -> None:
    monkeypatch.setattr(
        "order_demo.temporal_payload_codec.authenticated_vault_client",
        lambda cfg: FakeVaultClient(),
    )
    codec = VaultTransitPayloadCodec(
        VaultTransitConfig(
            vault_auth=VaultAuthConfig(
                vault_addr="http://vault:8200",
                vault_auth_method="token",
                vault_token="root",
                vault_kubernetes_role="order-worker",
                vault_kubernetes_jwt_path="/var/run/token",
            ),
            transit_mount="transit",
            transit_key="temporal-payloads",
        )
    )
    original = Payload(
        metadata={"encoding": b"json/plain"},
        data=base64.b64encode(b'{"payment_token":"tok_demo_visa_4242_sensitive"}'),
    )

    encoded = await codec.encode([original])
    decoded = await codec.decode(encoded)

    assert encoded[0].metadata["encoding"] == VAULT_TRANSIT_ENCODING
    assert b"tok_demo_visa_4242_sensitive" not in encoded[0].data
    assert decoded[0] == original
