#!/usr/bin/env python3
"""Find state="new" translation entries in changed XLF files.

Outputs JSON with file paths, language codes, and new translation entries
including IDs, source/target text, line numbers, and placeholders.
"""

import json
import re
import subprocess
import sys
import xml.etree.ElementTree as ET

XLF_NS = "urn:oasis:names:tc:xliff:document:1.2"
NS = {"xlf": XLF_NS}
XLF_FILE_PATTERN = re.compile(r"messages\.([a-z]{2})\.xlf$")


def find_changed_xlf_files():
    """Find changed messages.{lang}.xlf files using git diff."""
    files = set()
    for cmd in (
        ["git", "diff", "--name-only"],
        ["git", "diff", "--cached", "--name-only"],
    ):
        try:
            result = subprocess.run(cmd, capture_output=True, text=True, check=True)
            for line in result.stdout.strip().splitlines():
                if XLF_FILE_PATTERN.search(line):
                    files.add(line)
        except subprocess.CalledProcessError:
            pass
    return sorted(files)


def detect_language(filepath):
    """Extract language code from messages.{lang}.xlf filename."""
    match = XLF_FILE_PATTERN.search(filepath)
    return match.group(1) if match else None


def build_line_index(filepath):
    """Build a mapping from trans-unit id to line number by scanning raw text."""
    line_map = {}
    try:
        with open(filepath, "r", encoding="utf-8") as f:
            for line_num, line in enumerate(f, start=1):
                # Match trans-unit id attribute
                m = re.search(r'<trans-unit[^>]*\bid="([^"]*)"', line)
                if m:
                    line_map[m.group(1)] = line_num
    except OSError:
        pass
    return line_map


def serialize_element(elem):
    """Serialize an element's content (text + children) to string."""
    parts = []
    if elem.text:
        parts.append(elem.text)
    for child in elem:
        parts.append(ET.tostring(child, encoding="unicode"))
        if child.tail:
            parts.append(child.tail)
    return "".join(parts)


def extract_placeholders(elem):
    """Extract placeholder elements (<x .../>) from an element."""
    placeholders = []
    for child in elem:
        local_tag = child.tag.replace(f"{{{XLF_NS}}}", "")
        if local_tag == "x":
            placeholders.append(ET.tostring(child, encoding="unicode"))
    return placeholders


def extract_new_entries(filepath):
    """Parse an XLF file and extract trans-units with state='new' targets."""
    try:
        tree = ET.parse(filepath)
    except (ET.ParseError, OSError) as e:
        print(f"Warning: Could not parse {filepath}: {e}", file=sys.stderr)
        return []

    root = tree.getroot()
    line_map = build_line_index(filepath)
    entries = []

    for tu in root.iter(f"{{{XLF_NS}}}trans-unit"):
        tu_id = tu.get("id", "")
        target = tu.find(f"xlf:target", NS)

        if target is None or target.get("state") != "new":
            continue

        source = tu.find(f"xlf:source", NS)
        source_text = serialize_element(source) if source is not None else ""
        target_text = serialize_element(target) if target is not None else ""
        placeholders = extract_placeholders(source) if source is not None else []

        entries.append({
            "id": tu_id,
            "source": source_text,
            "target": target_text,
            "line_number": line_map.get(tu_id, 0),
            "placeholders": placeholders,
        })

    return entries


def main():
    files = find_changed_xlf_files()
    result = {"files": []}

    for filepath in files:
        language = detect_language(filepath)
        entries = extract_new_entries(filepath)

        if entries:
            result["files"].append({
                "path": filepath,
                "language": language,
                "new_entries": entries,
            })

    json.dump(result, sys.stdout, indent=2, ensure_ascii=False)
    print()


if __name__ == "__main__":
    main()
