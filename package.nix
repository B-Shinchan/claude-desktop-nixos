{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  desktop-file-utils,
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
  libgbm,
  nspr,
  nss,
  pango,
  pipewire,
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
  version = "4.29.0";

  src = fetchurl {
    url = "https://downloads.claude.ai/claude-desktop/apt/stable/pool/main/c/claude-desktop/claude-desktop_${finalAttrs.version}_amd64.deb";
    hash = "sha256-SqD3Y9bAWseVAjkt1Q9df1xFWy8KQF1b3xVUrNg0Kok=";
  };

  nativeBuildInputs = [
    dpkg
    desktop-file-utils
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
    libgbm
    nspr
    nss
    pango
    pipewire
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
    pipewire
  ];

  appendRunpaths = [
    "${addDriverRunpath.driverLink}/lib"
  ];

  dontWrapGApps = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/claude-desktop $out/bin $out/share/applications

    # Copy application files
    cp -r usr/lib/claude-desktop/. $out/lib/claude-desktop/

    # Copy icon assets
    cp -r usr/share/icons $out/share/

    # Install .desktop files
    install -Dm644 usr/share/applications/com.anthropic.Claude.desktop $out/share/applications/com.anthropic.Claude.desktop
    substituteInPlace $out/share/applications/com.anthropic.Claude.desktop \
      --replace-fail "Exec=claude-desktop" "Exec=$out/bin/claude-desktop"

    # Use one main category so menus do not duplicate the application.
    desktop-file-edit --set-key=Categories --set-value="Utility;" $out/share/applications/com.anthropic.Claude.desktop
    # X11 reports Claude-desktop; Wayland separately uses com.anthropic.Claude.
    sed -i '/^# Matches the Wayland app_id/d; /^# package.json desktopName/d' $out/share/applications/com.anthropic.Claude.desktop
    desktop-file-edit --set-key=StartupWMClass --set-value="Claude-desktop" $out/share/applications/com.anthropic.Claude.desktop

    # Create binary symlink
    ln -s $out/lib/claude-desktop/claude-desktop $out/bin/claude-desktop

    runHook postInstall
  '';

  preFixup = ''
    gappsWrapperArgs+=(
      --prefix PATH : ${lib.makeBinPath [ xdg-utils ]}
      --add-flags "--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations,WebRTCPipeWireCapturer --password-store=gnome-libsecret"
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
    sourceProvenance = [ sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "claude-desktop";
  };
})
