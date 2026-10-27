#!/usr/bin/env python3
"""Names the functions behind addresses in sms.log, from the link map (sms.map) of the same build.

  python3 scripts/symbolize.py path/to/sms.map 0x444d61 sms.exe+0x3a7596 ...

An address is an offset in sms.exe: `sms.exe+0x...` as the log prints it, or just the hex. The map is in the build's
artifact (bin/sms.map); the log's `[port] version: ... (hash)` line says which build the log is from, and the map must
be that build's. Names are the compiler's decorated ones (?name@@...).
"""
import bisect
import re
import sys


def load(path):
    base = None
    entries = []
    for line in open(path, errors="replace"):
        if base is None:
            m = re.search(r"Preferred load address is ([0-9a-fA-F]+)", line)
            if m:
                base = int(m.group(1), 16)
                continue
        m = re.match(r"\s*0001:[0-9a-fA-F]+\s+(\S+)\s+([0-9a-fA-F]+)\s", line)
        if m:
            entries.append((int(m.group(2), 16), m.group(1)))
    if base is None:
        sys.exit("no 'Preferred load address' line: is this a link map?")
    entries.sort()
    return base, [e[0] - base for e in entries], [e[1] for e in entries]


def main(argv):
    if len(argv) < 3:
        sys.exit(__doc__)
    base, rvas, names = load(argv[1])
    for arg in argv[2:]:
        m = re.search(r"(?:\+)?(?:0x)?([0-9a-fA-F]+)$", arg)
        if not m:
            print(f"{arg}: not an address")
            continue
        rva = int(m.group(1), 16)
        i = bisect.bisect_right(rvas, rva) - 1
        if i < 0:
            print(f"0x{rva:x}: before the first symbol")
        else:
            print(f"0x{rva:x}: {names[i]} + 0x{rva - rvas[i]:x}")


main(sys.argv)
