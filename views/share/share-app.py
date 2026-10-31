#!/usr/bin/env python3
"""Prints the name of the app receiving the screen share: the PipeWire node
the portal's video stream is linked to (pw-dump), or nothing."""
import json
import subprocess

try:
    objects = json.loads(subprocess.run(["pw-dump"], capture_output=True, text=True, timeout=5).stdout or "[]")
except (OSError, ValueError, subprocess.SubprocessError):
    objects = []
nodes = {o["id"]: (o.get("info") or {}).get("props") or {} for o in objects if o.get("type") == "PipeWire:Interface:Node"}
sources = [i for i, p in nodes.items()
           if p.get("media.class") == "Video/Source" and ("xdpw" in str(p.get("node.name", "")) or "portal" in str(p.get("application.name", "")).lower())]
names = []
for o in objects:
    if o.get("type") != "PipeWire:Interface:Link":
        continue
    info = o.get("info") or {}
    if info.get("output-node-id") in sources:
        p = nodes.get(info.get("input-node-id"), {})
        name = p.get("application.name") or p.get("application.process.binary") or p.get("node.name")
        if name and name not in names:
            names.append(name)
print(", ".join(names))
