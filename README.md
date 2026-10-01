# Claude Desktop on NixOS

[![Nix Flake](https://img.shields.io/badge/Nix_Flake-blue?logo=nixos&logoColor=white)](https://nixos.org)
[![Platform](https://img.shields.io/badge/Platform-x86__64--linux-lightgrey?logo=linux&logoColor=white)](https://nixos.org)
[![Wayland Ready](https://img.shields.io/badge/Wayland-Ready-green?logo=wayland&logoColor=white)](https://wayland.freedesktop.org/)
[![Packaging License: MIT](https://img.shields.io/badge/Packaging_License-MIT-yellow.svg)](./LICENSE)

Repackaging of Anthropic's official Claude Desktop Linux (`.deb`) application for NixOS, featuring out-of-the-box native Wayland rendering, GNOME Keyring Secret Service persistence across Wayland compositors (Niri, Hyprland, Sway), and complete Cowork virtualization support via `buildFHSEnv`.

---

## Architecture: Problems & Solutions

The official Claude Desktop Linux package is distributed as an `x86_64` Debian archive tailored for standard FHS distributions (Ubuntu/Debian). On NixOS, several structural barriers prevent the application from running:

1. **Missing Dynamic Linkage & Bundled Helpers**:
   - The Electron wrapper and its bundled helpers (`cowork-linux-helper`, `virtiofsd`) link against dynamic libraries residing in standard paths like `/lib64/ld-linux-x86-64.so.2` and expect `libseccomp` and `libcap-ng`.
   - **Solution**: Patched with `autoPatchelfHook`, resolving ELF interpreters and runtime dependencies while appending Nix store runpaths to the binary wrapper.

2. **Hardcoded Virtualization Firmware Paths**:
   - Claude's Cowork VM feature inspects the filesystem directly for hardcoded UEFI firmware at `/usr/share/OVMF/OVMF_CODE_4M.fd` or `/usr/share/OVMF/OVMF_CODE.fd`, along with `/usr/libexec/virtiofsd`. Without an FHS rootfs layout, Claude reports:
     ```
     Cowork requires QEMU. Install it with 'sudo apt install qemu-system-x86 ovmf virtiofsd', then restart Claude.
     (unsupportedCode: "virtualization_tools_missing")
     ```
   - **Solution**: Implemented an FHS runtime wrapper via `buildFHSEnv` that stages NixOS's `OVMFFull` firmware at `/usr/share/OVMF/`, bundles `virtiofsd` at `/usr/libexec/virtiofsd`, provisions `qemu-system-x86_64`, and binds `/dev/kvm` and `/dev/vhost-vsock` into the bubblewrap sandbox.

3. **Keyring Failures on Non-GNOME Wayland Compositors**:
   - In environments without GNOME Shell (such as Niri, Hyprland, Sway), Electron fails to determine the secret storage backend, causing authentication session loss on restart.
   - **Solution**: Pre-configured flags `--password-store=gnome-libsecret` ensure sessions persist reliably using standard FreeDesktop Secret Service implementations (`gnome-keyring` or KeePassXC).

4. **OAuth Browser Deep-Linking**:
   - Signing in redirects through the browser to a `claude://` scheme. Without standard XDG MIME registrations and `xdg-utils` in the runtime `PATH`, browser handshakes fail.
   - **Solution**: Packages desktop integration files registering `x-scheme-handler/claude` and injects `xdg-utils` into runtime `PATH`.

---

## Feature Matrix

| Feature | Status | Implementation Details |
| :--- | :---: | :--- |
| **Core Chat & Projects** | **Supported** | Full Electron runtime parity with official `.deb` release. |
| **Artifacts & Previews** | **Supported** | Complete rendering support with hardware acceleration. |
| **Native Wayland & DMA-BUF** | **Supported** | Pre-configured with `--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations`. |
| **OAuth `claude://` Callbacks** | **Supported** | Desktop protocol handler mapped to `x-scheme-handler/claude` via `xdg-utils`. |
| **Secret Storage Persistence** | **Supported** | Backed by `libsecret` and FreeDesktop Secret Service (`--password-store=gnome-libsecret`). |
| **Claude Cowork VM** | **Supported** | FHS wrapper supplies `qemu_kvm`, `virtiofsd`, and UEFI `OVMF` binaries. |
| **Voice Dictation** | **Supported** | PulseAudio/PipeWire ALSA backend wired via runtime library paths. |

---

## Quickstart / Ad-hoc Usage

Execute directly without modifying your system configuration:

### Default (Cowork VM-enabled FHS)
```bash
nix run github:B-Shinchan/claude-desktop-nixos
```

### Pure Derivation (Lightweight, No QEMU / OVMF overhead)
```bash
nix run github:B-Shinchan/claude-desktop-nixos#pure
```

---

## Declarative NixOS Integration

### 1. Flake Inputs
Add `claude-desktop-nixos` to your system `flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    claude-desktop.url = "github:B-Shinchan/claude-desktop-nixos";
    # Ensure inputs.claude-desktop.inputs.nixpkgs follows your system nixpkgs if desired:
    # claude-desktop.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, claude-desktop, ... }: {
    # System configuration...
  };
}
```

### 2. NixOS Configuration (`configuration.nix`)

Because Claude Desktop contains proprietary binaries from Anthropic, ensure unfree packages are allowed:

```nix
{ pkgs, inputs, ... }:

{
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = [
    inputs.claude-desktop.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

  # Required for Cowork VM features:
  boot.kernelModules = [ "vhost_vsock" ];
  users.users.<username>.extraGroups = [ "kvm" ];

  # Required for secret persistence on standalone Wayland compositors:
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.login.enableGnomeKeyring = true;
}
```

> **Note on Desktop Integration & MIME Callbacks:**  
> When installed via `environment.systemPackages`, NixOS automatically links the `.desktop` file and registers the `x-scheme-handler/claude` MIME association system-wide.

### 3. Home Manager (`home.nix`)

```nix
{ pkgs, inputs, ... }:

{
  home.packages = [
    inputs.claude-desktop.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];
}
```

---

## Troubleshooting & Gotchas

### 1. OAuth Callback Not Handled by Browser
If clicking "Open in Claude" in your browser fails to focus the application:
1. Verify the MIME registration:
   ```bash
   xdg-mime query default x-scheme-handler/claude
   ```
   *Expected output*: `com.anthropic.Claude.desktop`
2. If unset, manually register the scheme handler:
   ```bash
   xdg-mime default com.anthropic.Claude.desktop x-scheme-handler/claude
   ```

### 2. Cowork VM Initialization Issues
If Cowork features indicate missing virtualization:
- Verify `/dev/kvm` exists and your user belongs to the `kvm` group:
  ```bash
  ls -l /dev/kvm
  ```
- Verify the VSOCK kernel module is loaded:
  ```bash
  lsmod | grep vhost_vsock
  ```
  If missing on a live session, run:
  ```bash
  sudo modprobe vhost_vsock
  ```

### 3. Keyring Prompt / Session Lost on Restart
If you are logged out every time Claude Desktop is closed:
- Ensure a Secret Service daemon (`gnome-keyring` or KeePassXC with Freedesktop Secret Service enabled) is running in your session.
- Under compositors like Niri, Hyprland, or Sway, launch the keyring daemon in your compositor startup configuration:
  ```bash
  dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP
  gnome-keyring-daemon --start --components=secrets
  ```

---

## Legal & Disclaimers

- **Packaging Code**: Licensed under the [MIT License](./LICENSE).
- **Trademarks & Binaries**: **Claude**, **Claude Desktop**, and the Anthropic logo are trademarks of **Anthropic PBC**.
- This repository is an independent community packaging effort and is neither affiliated with nor endorsed by Anthropic.
