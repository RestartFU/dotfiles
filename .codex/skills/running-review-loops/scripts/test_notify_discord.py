#!/usr/bin/env python3

from argparse import Namespace
from io import BytesIO
from importlib.machinery import SourceFileLoader
from importlib.util import module_from_spec, spec_from_loader
from pathlib import Path
from unittest.mock import patch
import sys
import unittest
from urllib.error import HTTPError, URLError
from urllib.parse import parse_qs, urlsplit


SCRIPT = Path(__file__).with_name("notify-discord")
WEBHOOK = "".join(["https://", "discord.com", "/api/", "webhooks/1/token"])
LOADER = SourceFileLoader("notify_discord", str(SCRIPT))
SPEC = spec_from_loader(LOADER.name, LOADER)
assert SPEC is not None
MODULE = module_from_spec(SPEC)
sys.modules[SPEC.name] = MODULE
LOADER.exec_module(MODULE)


class FakeResponse:
    status = 200

    def __enter__(self):
        return self

    def __exit__(self, *_args):
        return False

    def read(self):
        return b'{"id":"message-123"}'


class NotifyDiscordTests(unittest.TestCase):
    def setUp(self):
        self.original_urlopen = MODULE.urlopen
        self.original_sleep = MODULE.time.sleep
        MODULE.time.sleep = lambda _seconds: None

    def tearDown(self):
        MODULE.urlopen = self.original_urlopen
        MODULE.time.sleep = self.original_sleep

    def test_confirmation_url_preserves_query(self):
        result = MODULE.confirmed_webhook_url(
            WEBHOOK + "?thread_id=42"
        )
        query = parse_qs(urlsplit(result).query)
        self.assertEqual(query, {"thread_id": ["42"], "wait": ["true"]})

    def test_empty_or_relative_xdg_config_home_uses_home_fallback(self):
        expected = Path.home() / ".config"
        for invalid in ("", "relative/path"):
            with self.subTest(invalid=invalid), patch.dict(
                MODULE.os.environ, {"XDG_CONFIG_HOME": invalid}
            ):
                self.assertEqual(MODULE.config_root(), expected)

    def test_absolute_xdg_config_home_is_used(self):
        with patch.dict(MODULE.os.environ, {"XDG_CONFIG_HOME": "/tmp/codex-config"}):
            self.assertEqual(MODULE.config_root(), Path("/tmp/codex-config"))

    def test_payload_preserves_all_fields_and_context_tail(self):
        payload = MODULE.make_payload(
            Namespace(
                status="blocked",
                where="owner/repo#42 @ abc123",
                why="reviewer unavailable",
                context="start " + "x" * 4000 + " NEXT-ACTION",
            )
        )
        self.assertEqual(payload["content"], f"<@{MODULE.USER_ID}>")
        embed = payload["embeds"][0]
        fields = {field["name"]: field["value"] for field in embed["fields"]}
        self.assertEqual(fields["Where"], "owner/repo#42 @ abc123")
        self.assertEqual(fields["Why stopping"], "reviewer unavailable")
        self.assertTrue(fields["Context"].startswith("start "))
        self.assertTrue(fields["Context"].endswith("NEXT-ACTION"))
        self.assertLessEqual(len(fields["Context"]), 1024)
        self.assertNotIn(MODULE.USER_ID, str(embed))

    def test_status_colors(self):
        expected = {
            "approved": 0x57F287,
            "completed": 0x57F287,
            "blocked": 0xFEE75C,
            "failed": 0xED4245,
            "cancelled": 0x95A5A6,
            "test": 0x5865F2,
        }
        for status, color in expected.items():
            with self.subTest(status=status):
                payload = MODULE.make_payload(
                    Namespace(status=status, where="x", why="y", context="z")
                )
                self.assertEqual(payload["embeds"][0]["color"], color)

    def test_network_failure_is_not_retried(self):
        calls = 0

        def fail_once(*_args, **_kwargs):
            nonlocal calls
            calls += 1
            raise URLError("response lost")

        MODULE.urlopen = fail_once
        with self.assertRaisesRegex(RuntimeError, "outcome unknown"):
            MODULE.send(WEBHOOK, {"content": "x"})
        self.assertEqual(calls, 1)

    def test_server_error_is_not_retried(self):
        calls = 0

        def fail_once(*_args, **_kwargs):
            nonlocal calls
            calls += 1
            raise HTTPError("url", 500, "error", {}, BytesIO(b""))

        MODULE.urlopen = fail_once
        with self.assertRaisesRegex(RuntimeError, "outcome unknown"):
            MODULE.send(WEBHOOK, {"content": "x"})
        self.assertEqual(calls, 1)

    def test_explicit_rate_limit_retries_after_full_interval(self):
        calls = 0
        sleeps = []

        def rate_limit_then_pass(*_args, **_kwargs):
            nonlocal calls
            calls += 1
            if calls == 1:
                raise HTTPError(
                    "url",
                    429,
                    "rate limited",
                    {"Retry-After": "0.25"},
                    BytesIO(b'{"retry_after":0.25}'),
                )
            return FakeResponse()

        MODULE.urlopen = rate_limit_then_pass
        MODULE.time.sleep = sleeps.append
        MODULE.send(WEBHOOK, {"content": "x"})
        self.assertEqual(calls, 2)
        self.assertEqual(sleeps, [0.25])

    def test_long_rate_limit_fails_instead_of_retrying_early(self):
        calls = 0

        def long_rate_limit(*_args, **_kwargs):
            nonlocal calls
            calls += 1
            raise HTTPError(
                "url",
                429,
                "rate limited",
                {"Retry-After": "65"},
                BytesIO(b'{"retry_after":65}'),
            )

        MODULE.urlopen = long_rate_limit
        with self.assertRaisesRegex(RuntimeError, "retry after 65.0 seconds"):
            MODULE.send(WEBHOOK, {"content": "x"})
        self.assertEqual(calls, 1)

    def test_zero_rate_limit_uses_short_positive_delay(self):
        calls = 0
        sleeps = []

        def zero_rate_limit_then_pass(*_args, **_kwargs):
            nonlocal calls
            calls += 1
            if calls == 1:
                raise HTTPError(
                    "url",
                    429,
                    "rate limited",
                    {"Retry-After": "0"},
                    BytesIO(b'{"retry_after":0}'),
                )
            return FakeResponse()

        MODULE.urlopen = zero_rate_limit_then_pass
        MODULE.time.sleep = sleeps.append
        MODULE.send(WEBHOOK, {"content": "x"})
        self.assertEqual(calls, 2)
        self.assertEqual(sleeps, [0.25])


if __name__ == "__main__":
    unittest.main()
