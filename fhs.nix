{
  buildFHSEnv,
  claude-desktop,
  qemu_kvm,
  OVMFFull,
  virtiofsd,
}:

let
  ovmf-pkg = OVMFFull.fd;
in
buildFHSEnv {
  pname = "claude-desktop";
  version = claude-desktop.version;

  targetPkgs = pkgs: [
    claude-desktop
    qemu_kvm
    virtiofsd
  ];

  # extraBuildCommands runs inside rootfs generation, so /usr/share/OVMF and /usr/libexec/virtiofsd
  # are created directly in the FHS root filesystem that bwrap mounts!
  extraBuildCommands = ''
    mkdir -p $out/usr/share/OVMF $out/usr/libexec
    ln -sf ${ovmf-pkg}/FV/OVMF_CODE.fd $out/usr/share/OVMF/OVMF_CODE_4M.fd
    ln -sf ${ovmf-pkg}/FV/OVMF_CODE.fd $out/usr/share/OVMF/OVMF_CODE.fd
    ln -sf ${ovmf-pkg}/FV/OVMF_VARS.fd $out/usr/share/OVMF/OVMF_VARS.fd

    ln -sf ${virtiofsd}/bin/virtiofsd $out/usr/libexec/virtiofsd
  '';

  # extraInstallCommands populates the outer derivation output ($out) with desktop files and icons
  extraInstallCommands = ''
    mkdir -p $out/share/applications $out/share/icons
    if [ -d "${claude-desktop}/share/icons" ]; then
      cp -r ${claude-desktop}/share/icons/* $out/share/icons/ 2>/dev/null || true
    fi
    if [ -f "${claude-desktop}/share/applications/com.anthropic.Claude.desktop" ]; then
      install -Dm644 ${claude-desktop}/share/applications/com.anthropic.Claude.desktop $out/share/applications/com.anthropic.Claude.desktop
      substituteInPlace $out/share/applications/com.anthropic.Claude.desktop \
        --replace-fail "${claude-desktop}/bin/claude-desktop" "$out/bin/claude-desktop"
    fi
  '';

  extraBwrapArgs = [
    "--dev-bind-try /dev/kvm /dev/kvm"
    "--dev-bind-try /dev/vhost-vsock /dev/vhost-vsock"
  ];

  runScript = "claude-desktop --ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --password-store=gnome-libsecret";

  meta = claude-desktop.meta // {
    description = "Claude Desktop for Linux with Cowork VM support (FHS)";
    mainProgram = "claude-desktop";
  };
}
