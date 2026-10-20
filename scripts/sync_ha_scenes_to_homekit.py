#!/usr/bin/env python3
"""Sync Home Assistant scenes.yaml to native Apple Home scenes.

Runs on the Mac Mini. Reads HA scenes over `ssh ha-pi`, then upserts matching
HomeKit action sets through the local HomeKit MCP Helper.

Home Assistant allows two scenes to share a display name. Apple Home does not.
The first scene keeps the Home Assistant name. A later scene with the same name
gets a room prefix taken from its id (Guest Room Chill, Kitchen Dinner Time).
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import shlex
import subprocess
import sys
import urllib.request
from pathlib import Path
from typing import Any

HELPER_URL = os.environ.get("HOMEKIT_MCP_URL", "http://127.0.0.1:8765")
HOME_NAME = os.environ.get("HOMEKIT_HOME_NAME", "Köpenick Home")
STATE_FILE = Path(os.environ.get("HA_HK_SCENE_SYNC_STATE", str(Path.home() / ".local/state/homekit-mcp/ha-scenes.sha256")))

SUPPORTED_DOMAINS = {"light", "cover", "switch"}


def run(cmd: list[str], timeout: int = 60) -> str:
    p = subprocess.run(cmd, text=True, capture_output=True, timeout=timeout)
    if p.returncode != 0:
        raise RuntimeError(f"{' '.join(cmd)} failed ({p.returncode}): {p.stderr or p.stdout}")
    return p.stdout


def load_ha_scenes() -> list[dict[str, Any]]:
    domains = ", ".join(repr(domain) for domain in sorted(SUPPORTED_DOMAINS))
    code = f'''
import yaml, json
scenes = yaml.safe_load(open('/config/scenes.yaml')) or []
out = []
supported = {{{domains}}}
for scene in scenes:
    entities = scene.get('entities') or {{}}
    actions = []
    unsupported = []
    for entity_id, attrs in entities.items():
        domain = entity_id.split('.', 1)[0]
        if domain not in supported:
            unsupported.append(entity_id)
            continue
        attrs = attrs or {{}}
        action = {{
            'entity_id': entity_id,
            'state': str(attrs.get('state', 'on')).lower(),
        }}
        if 'brightness' in attrs and attrs.get('brightness') is not None:
            action['brightness'] = int(attrs['brightness'])
        if 'xy_color' in attrs and attrs.get('xy_color') is not None:
            action['xy_color'] = [float(attrs['xy_color'][0]), float(attrs['xy_color'][1])]
        if 'color_temp' in attrs and attrs.get('color_temp') is not None:
            action['color_temperature'] = int(attrs['color_temp'])
        if domain == 'cover':
            if action['state'] == 'open':
                action['target_position'] = 100
            elif action['state'] == 'closed':
                action['target_position'] = 0
            elif attrs.get('current_position') is not None:
                action['target_position'] = int(attrs['current_position'])
        actions.append(action)
    out.append({{
        'id': str(scene.get('id') or scene.get('name')),
        'name': scene.get('name'),
        'actions': actions,
        'unsupported': unsupported,
    }})
print(json.dumps(out, sort_keys=True))
'''
    return json.loads(run(["ssh", "ha-pi", f"python3 -c {shlex.quote(code)}"], timeout=90))


def assign_apple_names(scenes: list[dict[str, Any]]) -> None:
    """Give each scene a unique Apple Home name. First copy keeps the HA name."""
    used: set[str] = set()
    for scene in scenes:
        name = scene.get("name")
        if not isinstance(name, str) or not name:
            scene["apple_name"] = None
            continue
        apple = name
        if apple in used:
            sid = str(scene.get("id") or "")
            if sid.startswith("guest_room_"):
                apple = f"Guest Room {name}"
            elif sid.startswith("kitchen_"):
                apple = f"Kitchen {name}"
            else:
                apple = f"{name} ({sid})"
            base = apple
            n = 2
            while apple in used:
                apple = f"{base} {n}"
                n += 1
        used.add(apple)
        scene["apple_name"] = apple


def canonical_hash(scenes: list[dict[str, Any]]) -> str:
    payload = json.dumps(scenes, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(payload.encode()).hexdigest()


def helper_post(payload: dict[str, Any]) -> dict[str, Any]:
    req = urllib.request.Request(
        f"{HELPER_URL}/mcp",
        data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=45) as r:
        return json.loads(r.read().decode())


def helper_inventory() -> dict[str, Any]:
    with urllib.request.urlopen(f"{HELPER_URL}/inventory", timeout=30) as r:
        return json.loads(r.read().decode())


def sync(scenes: list[dict[str, Any]], dry_run: bool = False) -> list[str]:
    messages: list[str] = []
    inv = helper_inventory()
    homes = [h for h in inv.get("homes", []) if h.get("name") == HOME_NAME]
    if not homes:
        raise RuntimeError(f"Apple Home not found: {HOME_NAME}")

    for scene in scenes:
        apple_name = scene.get("apple_name") or scene.get("name")
        if not apple_name or not scene.get("actions"):
            continue
        payload = {
            "tool": "homekit_create_scene",
            "home": HOME_NAME,
            "name": apple_name,
            "mode": "dry_run" if dry_run else "apply",
            "confirm_apply": not dry_run,
            "actions": scene["actions"],
        }
        result = helper_post(payload)
        if result.get("status") == "error":
            raise RuntimeError(f"{apple_name}: {result}")
        count = result.get("action_count", len(scene["actions"]))
        label = apple_name if apple_name == scene.get("name") else f"{apple_name} (HA name {scene.get('name')})"
        line = f"{label}: {'planned' if dry_run else 'synced'} ({count} HomeKit actions)"
        missing = [
            item.get("entity_id", "")
            for item in result.get("actions") or []
            if item.get("found") == "false"
        ]
        if missing:
            line += f"; not on the bridge: {', '.join(missing)}"
        if scene.get("unsupported"):
            line += f"; skipped unsupported: {', '.join(scene['unsupported'])}"
        messages.append(line)
    return messages


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--force", action="store_true", help="sync even if scenes.yaml hash is unchanged")
    ap.add_argument("--dry-run", action="store_true", help="plan only; do not mutate Apple Home")
    args = ap.parse_args()

    scenes = load_ha_scenes()
    assign_apple_names(scenes)
    digest = canonical_hash(scenes)
    old = STATE_FILE.read_text().strip() if STATE_FILE.exists() else ""
    if not args.force and old == digest:
        return 0  # silent no-op for cron

    messages = sync(scenes, dry_run=args.dry_run)
    if not args.dry_run:
        STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
        STATE_FILE.write_text(digest + "\n")
    print("HA → Apple Home scene sync complete:")
    print("\n".join(f"- {m}" for m in messages))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as e:
        print(f"HA → Apple Home scene sync FAILED: {e}", file=sys.stderr)
        raise SystemExit(1)
