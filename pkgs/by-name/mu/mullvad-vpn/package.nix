{
  lib,
  buildNpmPackage,
  replaceVars,
  grpc-tools,
  makeWrapper,
  electron,
  mullvad,
  nodejs_22,
}:
buildNpmPackage rec {
  pname = "mullvad-vpn";
  inherit (mullvad) src version;
  nodejs = nodejs_22;

  patches = [
    (replaceVars ./distribution.cjs.patch {
      inherit version;
      electron-dist = electron.dist;
    })
    # ./management-interface-build.sh.patch
  ];

  postPatch = ''
    cd desktop/
  '';

  npmDepsHash = "sha256-hPH4xm6wZ7gGUMs6GiOEv1TgURU2Tmfq5bnWwDxcYrs=";

  npmFlags = [ "--ignore-scripts" ];

  nativeBuildInputs = [
    makeWrapper
    grpc-tools
  ];

  makeCacheWritable = true;

  buildInputs = [
    electron
  ];

  env = {
    ELECTRON_SKIP_BINARY_DOWNLOAD = "1";
    ELECTRON_OVERRIDE_DIST_PATH = electron.dist; # TODO: figure out why this is needed
  };

  postConfigure = ''
    ln -s ${lib.getBin mullvad}/bin/* ../dist-assets/
    # ln -s ${lib.getExe' grpc-tools "protoc"} node_modules/grpc-tools/bin/protoc
    # ln -s ${lib.getExe' grpc-tools "grpc_node_plugin"} node_modules/grpc-tools/bin/grpc_node_plugin
  '';

  # FIXME Hack: For some reason the build works fine on the 2nd attempt
  buildPhase = ''
    npm -w windows-utils run build-typescript
    npm -w management-interface run build
    npm -w mullvad-vpn run pack:linux
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/mullvad-vpn/
    cp -r ../dist/*-unpacked/{locales,resources{,.pak}} $out/share/mullvad-vpn/
    cp ../graphics/icon{-square.svg,.svg} $out/share/mullvad-vpn/resources/


    makeWrapper ${lib.getExe electron} $out/bin/mullvad-vpn \
        --add-flags $out/share/mullvad-vpn/resources/app.asar \
        --set MULLVAD_DISABLE_UPDATE_NOTIFICATION 1 \
        --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations}}" \
        --inherit-argv0

    runHook postInstall
  '';

  postInstall = ''
    mkdir -p $out/share/applications

    cat > $out/share/applications/${pname}.desktop <<EOF
    [Desktop Entry]
    Type=Application
    Icon=$out/share/mullvad-vpn/resources/icon.svg
    Exec=$out/bin/mullvad-vpn
    Name=Mullvad VPN
    GenericName=VPN Client
    Categories=Application;Other;
    EOF
  '';

  meta = {
    homepage = "https://github.com/mullvad/mullvadvpn-app";
    description = "Client for Mullvad VPN";
    changelog = "https://github.com/mullvad/mullvadvpn-app/blob/${version}/CHANGELOG.md";
    license = lib.licenses.gpl3Only;
    inherit (electron.meta) platforms;
    maintainers = with lib.maintainers; [
      Br1ght0ne
      ymarkus
      ataraxiasjel
    ];
  };
}
