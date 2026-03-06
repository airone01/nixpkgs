{
  lib,
  stdenv,
  fetchFromGitHub,
  pkgsCross,
  pkgsi686Linux,
  bison,
  flex,
  gnumake,
  python3,
  meson,
  ninja,
  cmake,
  pkg-config,
  glslang,
  nasm,
  rustc,
  cargo,
  vulkan-headers,
  vulkan-loader,
  freetype,
  zlib,
  SDL2,
  libx11,
  libxext,
  gst_all_1,
  writeShellScriptBin,
  rsync,
  glib,
  pcre2,
  libffi,
  util-linux,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "proton-ge-src";
  version = "10.0-4";

  src = fetchFromGitHub {
    owner = "ValveSoftware";
    repo = "Proton";
    tag = "proton-${finalAttrs.version}";
    fetchSubmodules = true;
    hash = "sha256-WCPoB1HvbSNUC7o2+M2zghFNDHy/PSMjG5IH1R4UXL0=";
  };

  patches = [
    ./bypass-container.patch
  ];

  nativeBuildInputs = [
    bison
    flex
    gnumake
    python3
    meson
    ninja
    cmake
    pkg-config
    glslang
    nasm
    rustc
    cargo
    rsync
    pkgsCross.mingwW64.stdenv.cc
    pkgsCross.mingw32.stdenv.cc
    pkgsCross.gnu32.stdenv.cc
    pkgsCross.gnu32.pkg-config

    # Bypass building in containers
    (writeShellScriptBin "fake-container-engine" ''
      #!/bin/bash
      while [[ $# -gt 0 ]]; do
        if [[ "$1" == "make" ]]; then
          break
        fi
        shift
      done
      if [[ $# -eq 0 ]]; then
        echo "Fake engine error: 'make' command not found!"
        exit 1
      fi
      export NIX_ORIG_PKG_CONFIG_PATH="$PKG_CONFIG_PATH"
      unset PKG_CONFIG
      # -j1 is used here to make logs clearer by running build steps one by one
      # TODO remove that in the final package
      exec "$@" -j1
    '')

    # Sniper SDK is Debian-based. Valve's Meson script hardcodes search the binaries.
    # These masks fake the binaries.
    (writeShellScriptBin "i686-linux-gnu-gcc" ''exec i686-unknown-linux-gnu-gcc -std=gnu17 "$@"'')
    (writeShellScriptBin "i686-linux-gnu-g++" ''exec i686-unknown-linux-gnu-g++ "$@"'')
    (writeShellScriptBin "i686-linux-gnu-ar" ''exec i686-unknown-linux-gnu-ar "$@"'')
    (writeShellScriptBin "x86_64-linux-gnu-gcc" ''exec gcc -m64 -std=gnu17 "$@"'')
    (writeShellScriptBin "x86_64-linux-gnu-g++" ''exec g++ -m64 "$@"'')
    (writeShellScriptBin "x86_64-linux-gnu-ar" ''exec ar "$@"'')

    # (writeShellScriptBin "i686-linux-gnu-pkg-config" ''
    #   unset PKG_CONFIG_LIBDIR
    #   export PKG_CONFIG_PATH="${pkgsi686Linux.glib.dev}/lib/pkgconfig:${pkgsi686Linux.pcre2.dev}/lib/pkgconfig:${pkgsi686Linux.libffi.dev}/lib/pkgconfig:${pkgsi686Linux.util-linux.dev}/lib/pkgconfig:$PKG_CONFIG_PATH:$NIX_ORIG_PKG_CONFIG_PATH"
    #
    #   exec i686-unknown-linux-gnu-pkg-config "$@"
    # '')
    # (writeShellScriptBin "x86_64-linux-gnu-pkg-config" ''
    #   unset PKG_CONFIG_LIBDIR
    #   export PKG_CONFIG_PATH="${glib.dev}/lib/pkgconfig:${pcre2.dev}/lib/pkgconfig:${libffi.dev}/lib/pkgconfig:${util-linux.dev}/lib/pkgconfig:$PKG_CONFIG_PATH:$NIX_ORIG_PKG_CONFIG_PATH"
    #
    #   exec pkg-config "$@"
    # '')

    (writeShellScriptBin "i686-linux-gnu-pkg-config" ''
      unset PKG_CONFIG_LIBDIR
      export PKG_CONFIG_PATH="$PKG_CONFIG_PATH:$NIX_ORIG_PKG_CONFIG_PATH"
      exec i686-unknown-linux-gnu-pkg-config "$@"
    '')
    (writeShellScriptBin "x86_64-linux-gnu-pkg-config" ''
      unset PKG_CONFIG_LIBDIR
      export PKG_CONFIG_PATH="$PKG_CONFIG_PATH:$NIX_ORIG_PKG_CONFIG_PATH"
      exec pkg-config "$@"
    '')

    # Note: the following masks might not be needed anymore. They're kept as a backup plan.
    # # Having both 32-bit and 64-bit versions of glib in buildInputs causes crossover linking errors.
    # # These pkg-config masks are an attempt to fix that by sorting deps depending on the platform.
    # # This might still be brittle on upstream changes.
    # (writeShellScriptBin "i686-linux-gnu-pkg-config" ''
    #   I686_PATHS=$(echo "$PKG_CONFIG_PATH" | tr ':' '\n' | grep "\-i686\-" | tr '\n' ':' || true)
    #   OTHER_PATHS=$(echo "$PKG_CONFIG_PATH" | tr ':' '\n' | grep -v "\-i686\-" | tr '\n' ':' || true)
    #   export PKG_CONFIG_PATH="''${I686_PATHS}''${OTHER_PATHS}"
    #   exec pkg-config "$@"
    # '')
    # (writeShellScriptBin "x86_64-linux-gnu-pkg-config" ''
    #   I686_PATHS=$(echo "$PKG_CONFIG_PATH" | tr ':' '\n' | grep "\-i686\-" | tr '\n' ':' || true)
    #   OTHER_PATHS=$(echo "$PKG_CONFIG_PATH" | tr ':' '\n' | grep -v "\-i686\-" | tr '\n' ':' || true)
    #   export PKG_CONFIG_PATH="''${OTHER_PATHS}''${I686_PATHS}"
    #   exec pkg-config "$@"
    # '')
  ];

  buildInputs = [
    # 64-bit libs
    vulkan-headers
    vulkan-loader
    freetype
    zlib
    SDL2
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    libx11
    libxext
    glib
    pcre2
    libffi
    util-linux

    # 32-bit libs
    pkgsi686Linux.vulkan-loader
    pkgsi686Linux.freetype
    pkgsi686Linux.zlib
    pkgsi686Linux.SDL2
    pkgsi686Linux.gst_all_1.gstreamer
    pkgsi686Linux.gst_all_1.gst-plugins-base
    pkgsi686Linux.libX11
    pkgsi686Linux.libXext
    pkgsi686Linux.glib
    pkgsi686Linux.pcre2
    pkgsi686Linux.libffi
    pkgsi686Linux.util-linux
  ];

  makeFlags = [
    "SHELL=${stdenv.shell}"
  ];

  # stripping container enforcement check
  postPatch = ''
    substituteInPlace Makefile.in \
      --replace-fail "/bin/bash" "${stdenv.shell}"

    patchShebangs .
  '';

  configurePhase = ''
    runHook preConfigure

    mkdir -p build
    cd build

    ../configure.sh --build-name="proton-ge-src"

    runHook postConfigure
  '';

  preBuild = ''
    export HOME=$TMPDIR/fake-home
    mkdir -p $HOME
    export CARGO_HOME=$HOME/.cargo
  '';

  buildPhase = ''
    runHook preBuild

    make -j$NIX_BUILD_CORES all

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/steam/compatibilitytools.d/Proton-Nix
    cp -r deploy/* $out/share/steam/compatibilitytools.d/Proton-Nix/

    runHook postInstall
  '';

  meta = {
    description = "Compatibility tool for Steam Play based on Wine";
    homepage = "https://github.com/ValveSoftware/Proton";
    license = lib.licenses.bsd3;
    platforms = ["x86_64-linux"];
    maintainers = with lib.maintainers; [airone01];
  };
})
