"""Generate an independent PE Qt5/MFC scaffold without copying SDK sources."""
import argparse
from pathlib import Path
import re
import secrets
import shutil
import tempfile

def generate(name: str, output: Path) -> Path:
    if not re.fullmatch(r"[A-Za-z][A-Za-z0-9_]{0,63}", name):
        raise ValueError("name must be an ASCII identifier, starting with a letter (max 64)")
    output = output.absolute()
    if output.exists():
        raise FileExistsError(f"output already exists: {output}")
    assets = Path(__file__).resolve().parents[1] / "assets"
    templates = sorted(assets.glob("*.in"))
    if not templates:
        raise FileNotFoundError(f"no templates in {assets}")
    output.parent.mkdir(parents=True, exist_ok=True)
    staging = Path(tempfile.mkdtemp(prefix=".pe-scaffold-", dir=output.parent))
    replacements = {"@NAME@": name, "@CLASS_A@": hex(secrets.randbits(32)),
                    "@CLASS_B@": hex(secrets.randbits(32))}
    try:
        for template in templates:
            text = template.read_text(encoding="utf-8")
            for marker, value in replacements.items():
                text = text.replace(marker, value)
            if re.search(r"@[A-Z_]+@", text):
                raise ValueError(f"unresolved marker in {template.name}")
            target = staging / template.name.removesuffix(".in")
            target.write_text(text, encoding="utf-8-sig" if target.suffix in {".cpp", ".h"} else "utf-8",
                              newline="\n")
        # Windows rename refuses an existing destination, including concurrent creation.
        staging.rename(output)
    finally:
        if staging.exists():
            shutil.rmtree(staging)
    return output

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--name", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    try:
        print(generate(args.name, args.output))
    except (OSError, ValueError) as error:
        parser.exit(1, f"error: {error}\n")

if __name__ == "__main__":
    main()
