#!/usr/bin/env python3
"""Mechanical consistency checks between role code and role documentation.

For every role:
  1. every variable in defaults/main.yml is declared in meta/argument_specs.yml (main)
     (internal helpers prefixed with `_` are exempt);
  2. every literal `default:` in the spec equals the value in defaults/main.yml
     (Jinja-valued defaults are not compared);
  3. no spec file contains Jinja delimiters ({{ {% {#) — Ansible templates specs at runtime;
  4. every spec option exists in defaults/main.yml OR explains its default in the
     description ("Default: …" / "No default") — catches stale or undocumented entries;
  5. every description is a string (an unquoted "text: more" silently becomes a mapping).

What a script cannot judge (prose accuracy, examples, docs/) is covered by the
doc-impact checklist in AGENTS.md.

Usage: scripts/check-consistency.py        exit 1 on any finding
"""
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent


def is_jinja(v) -> bool:
    return isinstance(v, str) and ("{{" in v or "{%" in v)


def non_string_descriptions(options, prefix=""):
    for name, opt in (options or {}).items():
        opt = opt or {}
        desc = opt.get("description")
        for item in desc if isinstance(desc, list) else [desc]:
            if item is not None and not isinstance(item, str):
                yield prefix + name
                break
        yield from non_string_descriptions(opt.get("options"), prefix + name + ".")


def main() -> int:
    findings = []
    for role_dir in sorted((ROOT / "roles").iterdir()):
        spec_file = role_dir / "meta" / "argument_specs.yml"
        defaults_file = role_dir / "defaults" / "main.yml"
        role = role_dir.name
        if not spec_file.exists():
            findings.append(f"{role}: missing meta/argument_specs.yml")
            continue
        raw = spec_file.read_text()
        for delim in ("{{", "{%", "{#"):
            if delim in raw:
                findings.append(f"{role}: argument_specs.yml contains '{delim}' (breaks at runtime)")
        all_eps = yaml.safe_load(raw)["argument_specs"]
        for ep_name, ep in all_eps.items():
            for bad in non_string_descriptions(ep.get("options")):
                findings.append(f"{role}: [{ep_name}] `{bad}` description is not a string (quote it)")
        spec = all_eps["main"].get("options") or {}
        defaults = {}
        if defaults_file.exists():
            defaults = yaml.safe_load(defaults_file.read_text()) or {}

        for var, value in defaults.items():
            if var.startswith("_"):
                continue
            if var not in spec:
                findings.append(f"{role}: defaults var `{var}` not declared in argument_specs")
                continue
            opt = spec[var] or {}
            if "default" in opt and not is_jinja(value) and opt["default"] != value:
                findings.append(
                    f"{role}: `{var}` spec default {opt['default']!r} != defaults/main.yml {value!r}")

        for var, opt in spec.items():
            if var in defaults:
                continue
            desc = opt.get("description") or ""
            desc = " ".join(desc) if isinstance(desc, list) else str(desc)
            if opt.get("required") or "default" in desc.lower() or "no default" in desc.lower():
                continue
            findings.append(
                f"{role}: spec option `{var}` has no default in defaults/main.yml and its "
                f"description doesn't explain its default (stale or undocumented?)")

    if findings:
        print("\n".join(findings))
        print(f"\n{len(findings)} consistency finding(s)", file=sys.stderr)
        return 1
    print("roles: code and specs consistent")
    return 0


if __name__ == "__main__":
    sys.exit(main())
