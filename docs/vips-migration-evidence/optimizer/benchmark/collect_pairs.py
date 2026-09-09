import json
import re
import sys
from pathlib import Path

pairs = []
for argument in sys.argv[2:]:
    operation, directory = argument.split("=", 1)
    directory = Path(directory).resolve()
    if not directory.is_dir():
        raise ValueError(f"Missing output directory: {directory}")
    groups = {}
    for path in sorted(directory.iterdir()):
        match = re.fullmatch(r"(.+)-(imagemagick|libvips)(\.[^.]+)", path.name)
        if match:
            label, backend, extension = match.groups()
            group = groups.setdefault((label, extension), {"operation": operation, "name": label})
            group[backend] = str(path)
    if not groups:
        raise ValueError(f"No paired benchmark filenames in {directory}; supply a custom manifest for other naming conventions")
    for (label, extension), group in groups.items():
        for backend in ("imagemagick", "libvips"):
            group.setdefault(backend, str(directory / f"{label}-{backend}{extension}"))
        pairs.append(group)
Path(sys.argv[1]).write_text(json.dumps(pairs, indent=2) + "\n")
print(f"Recorded {len(pairs)} cases; missing counterpart paths remain explicit")
