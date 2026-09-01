{
  pkgs ? import <nixpkgs> {},
  system ? builtins.currentSystem,
  fnoxVersion ? null,
}: let
  inherit (pkgs) lib;
  sources = builtins.fromJSON (lib.strings.fileContents ./sources.json);

  # Define target version with the following precedence:
  # 1. Explicitly provided fnoxVersion parameter
  # 2. FNOX_VERSION environment variable
  # 3. Default to "latest"
  envVersion = builtins.getEnv "FNOX_VERSION";
  selectedVersion =
    if fnoxVersion != null
    then fnoxVersion
    else if envVersion != ""
    then envVersion
    else "latest";

  # Access relevant data from sources.json
  versionData =
    if builtins.hasAttr selectedVersion sources
    then sources.${selectedVersion}
    else throw "fnox version '${selectedVersion}' not found in sources.json";

  # Create the fnox package derivation
  mkFnoxPackage = {version}: let
    platformData = versionData.platforms.${system}
      or (throw "Unsupported system: ${system}");

    fnox-archive = pkgs.fetchurl {
      url = platformData.url;
      sha256 = platformData.sha256;
    };
  in
    pkgs.stdenv.mkDerivation {
      pname = "fnox";
      inherit version;

      src = fnox-archive;

      nativeBuildInputs = [pkgs.gnutar pkgs.gzip];

      dontBuild = true;
      dontConfigure = true;
      # Generic fixups would strip or re-sign the release executable; keep
      # the exact published bytes so the checksum in sources.json is the
      # whole provenance story.
      dontFixup = true;

      unpackPhase = ''
        runHook preUnpack
        mkdir -p source
        tar -xzf $src -C source
        runHook postUnpack
      '';

      installPhase = ''
        runHook preInstall

        mkdir -p $out/bin
        cp source/fnox $out/bin/fnox
        chmod +x $out/bin/fnox

        runHook postInstall
      '';

      meta = {
        description = "Secrets manager with provider backends and a caching daemon";
        homepage = "https://fnox.jdx.dev";
        license = lib.licenses.mit;
        platforms = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
        mainProgram = "fnox";
      };
    };

  fnox = mkFnoxPackage {
    version = versionData.version;
  };
in {
  inherit fnox;
  default = fnox;
}
