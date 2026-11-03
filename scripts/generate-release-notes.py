#!/usr/bin/env python3
"""Generate structured GitHub Release notes for Claude Desktop on NixOS."""

import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PACKAGE_FILE = ROOT / "package.nix"


def main():
    tag = sys.argv[1] if len(sys.argv) > 1 else ""
    if not PACKAGE_FILE.exists():
        sys.exit(f"Error: {PACKAGE_FILE} not found")

    content = PACKAGE_FILE.read_text()

    # Extract version
    version_match = re.search(r'version = "([^"]+)";', content)
    version = version_match.group(1) if version_match else "unknown"

    # Extract hash
    hash_match = re.search(r'hash = "(sha256-[^"]+)";', content)
    sri_hash = hash_match.group(1) if hash_match else "unknown"

    # Vendor deb URL
    url = f"https://downloads.claude.ai/claude-desktop/apt/stable/pool/main/c/claude-desktop/claude-desktop_{version}_amd64.deb"

    if not tag:
        tag = f"v{version}"

    # Determine title
    rev_match = re.search(r"-([0-9]+)$", tag)
    if rev_match:
        title = f"Claude Desktop v{version} (Packaging Revision {rev_match.group(1)})"
    else:
        title = f"Claude Desktop v{version} (NixOS Release)"

    body = f"""### Anthropic Claude Desktop `{version}`

Official Anthropic Claude Desktop Linux application packaged natively for NixOS.

#### Upstream Artifact Details

| Property | Value |
| :--- | :--- |
| **Application** | Claude Desktop |
| **Upstream Version** | `{version}` |
| **Upstream Source** | [Official Anthropic Debian Repository]({url}) |
| **Architecture** | `amd64` (`x86_64-linux`) |
| **Source SRI Hash** | `{sri_hash}` |

#### Automated CI Verification

- **Flake Evaluation**: Verified Flake outputs and Nix formatting (`nix flake check`)
- **Package Build**: Compiled native derivation using autoPatchelfHook and wrapped Electron runtime (`nix build`)
- **Desktop Integration**: Validated XDG desktop entry (`claude-desktop.desktop`) and icon specification
- **Wayland Window Matching**: Verified Wayland app ID, window identity, and Weston compositor compatibility

#### Installation & Pinning

##### Immediate Run
```bash
nix run github:B-Shinchan/claude-desktop-nixos/{tag}
```

##### Flake Input (`flake.nix`)
Pin this specific release in your system flake:
```nix
inputs.claude-desktop.url = "github:B-Shinchan/claude-desktop-nixos/{tag}";
```

##### NixOS Module (`configuration.nix`)
```nix
imports = [ inputs.claude-desktop.nixosModules.default ];
programs.claude-desktop.enable = true;
```

##### Home Manager (`home.nix`)
```nix
home.packages = [
  inputs.claude-desktop.packages.${{pkgs.stdenv.hostPlatform.system}}.default
];
```

---
> [!NOTE]
> **Independent Community Packaging**: This project provides independent Nix expressions packaging Anthropic's official vendor binaries. It is not affiliated with, sponsored by, or endorsed by Anthropic.
"""

    if output := os.environ.get("GITHUB_OUTPUT"):
        with open(output, "a") as f:
            f.write(f"title={title}\n")

    print(body.strip())


if __name__ == "__main__":
    main()
