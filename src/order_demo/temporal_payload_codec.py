import base64
import os
from dataclasses import dataclass
from collections.abc import Sequence

from temporalio.api.common.v1 import Payload
from temporalio.converter import DataConverter, PayloadCodec

from order_demo.vault_auth import VaultAuthConfig, authenticated_vault_client

VAULT_TRANSIT_ENCODING = b"binary/vault-transit"


@dataclass(frozen=True)
class VaultTransitConfig:
    vault_auth: VaultAuthConfig
    transit_mount: str
    transit_key: str

    @classmethod
    def from_env(cls) -> "VaultTransitConfig":
        return cls(
            vault_auth=VaultAuthConfig.from_env(),
            transit_mount=os.getenv("VAULT_TRANSIT_MOUNT", "transit"),
            transit_key=os.getenv("VAULT_TRANSIT_KEY", "temporal-payloads"),
        )


class VaultTransitPayloadCodec(PayloadCodec):
    def __init__(self, cfg: VaultTransitConfig):
        self.cfg = cfg

    async def encode(self, payloads: Sequence[Payload]) -> list[Payload]:
        return [self._encrypt_payload(payload) for payload in payloads]

    async def decode(self, payloads: Sequence[Payload]) -> list[Payload]:
        return [self._decrypt_payload(payload) for payload in payloads]

    def _encrypt_payload(self, payload: Payload) -> Payload:
        if payload.metadata.get("encoding") == VAULT_TRANSIT_ENCODING:
            return payload

        plaintext = base64.b64encode(payload.SerializeToString()).decode("ascii")
        client = authenticated_vault_client(self.cfg.vault_auth)
        response = client.secrets.transit.encrypt_data(
            name=self.cfg.transit_key,
            plaintext=plaintext,
            mount_point=self.cfg.transit_mount,
        )

        return Payload(
            metadata={
                "encoding": VAULT_TRANSIT_ENCODING,
                "encryption-key-id": self.cfg.transit_key.encode("utf-8"),
            },
            data=response["data"]["ciphertext"].encode("utf-8"),
        )

    def _decrypt_payload(self, payload: Payload) -> Payload:
        if payload.metadata.get("encoding") != VAULT_TRANSIT_ENCODING:
            return payload

        client = authenticated_vault_client(self.cfg.vault_auth)
        response = client.secrets.transit.decrypt_data(
            name=self.cfg.transit_key,
            ciphertext=payload.data.decode("utf-8"),
            mount_point=self.cfg.transit_mount,
        )
        plaintext = base64.b64decode(response["data"]["plaintext"])
        decoded = Payload()
        decoded.ParseFromString(plaintext)
        return decoded


def build_data_converter_from_env() -> DataConverter:
    if os.getenv("USE_VAULT_PAYLOAD_CODEC", "false").lower() not in {"1", "true", "yes"}:
        return DataConverter()

    return DataConverter(
        payload_codec=VaultTransitPayloadCodec(VaultTransitConfig.from_env()),
    )
