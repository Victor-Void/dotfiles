#!/usr/bin/env python3
"""Refresh the model prices shown by the peak-hours popup.

Fetches the public DeepSeek and Anthropic pricing pages, extracts the
per-1M-token rates, validates them (including DeepSeek's off-peak = half of
peak rule), and writes the display rows the shell reads to
    <state>/quickshell/user/peak_hours_prices.json

If anything fails to parse or looks implausible the existing file is left
untouched, so the shell keeps its built-in defaults. Runs at most once per
REFRESH_HOURS (checked against the output file's age), which keeps repeated
config reloads from re-fetching.

Env:
    PEAK_HOURS_FORCE=1   ignore the age check
"""

import html
import json
import os
import re
import ssl
import sys
import time
import urllib.request

DEEPSEEK_URL = "https://api-docs.deepseek.com/quick_start/pricing/"
ANTHROPIC_URL = "https://platform.claude.com/docs/en/about-claude/pricing"
REFRESH_HOURS = 24
UA = (
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/126 Safari/537.36"
)

STATE = os.environ.get("XDG_STATE_HOME", os.path.expanduser("~/.local/state"))
OUT = os.path.join(STATE, "quickshell", "user", "peak_hours_prices.json")


def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=20, context=ssl.create_default_context()) as r:
        return r.read().decode("utf-8", "ignore")


def flat_text(page):
    """Collapse tags to '|' separators so table cells stay distinguishable."""
    text = re.sub(r"<[^>]+>", "|", page)
    text = html.unescape(text)
    return re.sub(r"\|+", "|", text)


def money(token):
    return float(token.lstrip("$"))


def deepseek_rows(page):
    text = flat_text(page)
    start = text.find("PRICING")
    if start < 0:
        raise ValueError("pricing section not found")
    prices = [money(m) for m in re.findall(r"\$[0-9]+(?:\.[0-9]+)?", text[start:start + 1500])]
    if len(prices) < 12:
        raise ValueError(f"expected 12 prices, got {len(prices)}")
    # Order in the table: [off, off, peak, peak] per row (Flash, Pro).
    hit_off, hit_off_pro, hit_peak, hit_peak_pro = prices[0:4]
    miss_off, miss_off_pro, miss_peak, miss_peak_pro = prices[4:8]
    out_off, out_off_pro, out_peak, out_peak_pro = prices[8:12]
    for off, peak in (
        (hit_off, hit_peak), (hit_off_pro, hit_peak_pro),
        (miss_off, miss_peak), (miss_off_pro, miss_peak_pro),
        (out_off, out_peak), (out_off_pro, out_peak_pro),
    ):
        if off <= 0 or abs(peak - 2 * off) > max(0.01, off * 0.05):
            raise ValueError("off-peak is not half of peak")

    def p(v):
        return f"{v:.3f}"

    return [
        {"header": False, "cells": ["", "off-peak", "peak"]},
        {"header": True, "cells": ["V4.1 Flash"]},
        {"header": False, "cells": ["cache hit", p(hit_off), p(hit_peak)]},
        {"header": False, "cells": ["cache miss", p(miss_off), p(miss_peak)]},
        {"header": False, "cells": ["output", p(out_off), p(out_peak)]},
        {"header": True, "cells": ["V4 Pro"]},
        {"header": False, "cells": ["cache hit", p(hit_off_pro), p(hit_peak_pro)]},
        {"header": False, "cells": ["cache miss", p(miss_off_pro), p(miss_peak_pro)]},
        {"header": False, "cells": ["output", p(out_off_pro), p(out_peak_pro)]},
    ]


def anthropic_rows(page):
    text = flat_text(page)

    def row(model):
        m = re.search(
            re.escape(model)
            + r"\|(\$[0-9.]+) / MTok\|(\$[0-9.]+) / MTok\|(\$[0-9.]+) / MTok"
            + r"\|(\$[0-9.]+) / MTok\|(\$[0-9.]+) / MTok",
            text,
        )
        if not m:
            raise ValueError(f"row not found for {model}")
        input_, _write5m, _write1h, cache_read, output = (money(g) for g in m.groups())
        for v in (input_, output, cache_read):
            if not 0 < v < 1000:
                raise ValueError(f"implausible price for {model}")
        return input_, output, cache_read

    models = [("Opus 5", row("Claude Opus 5")),
              ("Sonnet 5", row("Claude Sonnet 5")),
              ("Haiku 4.5", row("Claude Haiku 4.5"))]

    rows = [{"header": False, "cells": ["", "input", "output", "cache read"]}]
    for name, (input_, output, cache_read) in models:
        rows.append({"header": False, "cells": [name, f"{input_:.2f}", f"{output:.2f}", f"{cache_read:.2f}"]})
    return rows


def main():
    if not os.environ.get("PEAK_HOURS_FORCE"):
        try:
            if time.time() - os.path.getmtime(OUT) < REFRESH_HOURS * 3600:
                return 0
        except OSError:
            pass

    try:
        data = {"deepseek": deepseek_rows(fetch(DEEPSEEK_URL)),
                "anthropic": anthropic_rows(fetch(ANTHROPIC_URL))}
    except Exception as exc:  # noqa: BLE001 - report and keep the old file
        print(f"peak-hours price update skipped: {exc}", file=sys.stderr)
        return 1

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    tmp = OUT + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(data, f)
    os.replace(tmp, OUT)
    return 0


if __name__ == "__main__":
    sys.exit(main())
