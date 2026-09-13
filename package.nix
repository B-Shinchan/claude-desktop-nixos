{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  wrapGAppsHook3,
  makeWrapper,
  addDriverRunpath,
  libglvnd,
  xdg-utils,
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  cairo,
  cups,
  dbus,
  expat,
  gdk-pixbuf,
  glib,
  gtk3,
  libdrm,
  libnotify,
  libpulseaudio,
  libsecret,
  libxkbcommon,
  mesa,
  nspr,
  nss,
  pango,
  libcap_ng,
  libseccomp,
  systemd,
  libx11,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxrandr,
  libxcb,
  libxkbfile,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "claude-desktop";
  version = "1.52386.3";

  src = fetchurl {
    url = "https://downloads.claude.ai/claude-desktop/apt/stable/pool/main/c/claude-desktop/claude-desktop_${finalAttrs.version}_amd64.deb";
    hash = "sha256-eXWUzoHBnT9rU3P9uAFpnHVwFvVgBxX6F1HsNOhohFY=";
  };

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    wrapGAppsHook3
    makeWrapper
    addDriverRunpath
  ];

  buildInputs = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    cairo
    cups
    dbus
    expat
    gdk-pixbuf
    glib
    gtk3
    libdrm
    libnotify
    libpulseaudio
    libsecret
    libxkbcommon
    mesa
    nspr
    nss
    pango
    libcap_ng
    libseccomp
    systemd
    libx11
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxrandr
    libxcb
    libxkbfile
  ];

  runtimeDependencies = [
    (lib.getLib systemd)
    libsecret
    libnotify
    libpulseaudio
    libglvnd
  ];

  appendRunpaths = [
    "$out/lib/claude-desktop"
  ];

  dontWrapGApps = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/claude-desktop $out/bin $out/share/applications

    # Copy application files
    cp -r usr/lib/claude-desktop/* $out/lib/claude-desktop/

    # Copy icon assets
    cp -r usr/share/icons $out/share/

    # Install .desktop files
    install -Dm644 usr/share/applications/com.anthropic.Claude.desktop $out/share/applications/com.anthropic.Claude.desktop
    substituteInPlace $out/share/applications/com.anthropic.Claude.desktop \
      --replace-fail "Exec=claude-desktop" "Exec=$out/bin/claude-desktop"

    ln -s com.anthropic.Claude.desktop $out/share/applications/claude-desktop.desktop

    # Create binary symlink
    ln -s $out/lib/claude-desktop/claude-desktop $out/bin/claude-desktop

    runHook postInstall
  '';

  preFixup = ''
    gappsWrapperArgs+=(
      --prefix PATH : ${lib.makeBinPath [ xdg-utils ]}
      --add-flags "\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations} --password-store=gnome-libsecret"
    )
  '';

  postFixup = ''
    addDriverRunpath $out/lib/claude-desktop/claude-desktop
    wrapProgram $out/bin/claude-desktop \
      "''${gappsWrapperArgs[@]}"
  '';

  meta = with lib; {
    description = "Claude Desktop for Linux";
    homepage = "https://claude.ai";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "claude-desktop";
  };
})
