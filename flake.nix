{
  description = "fnox - secrets manager with a caching daemon (prebuilt release binaries)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    ...
  }: let
    systems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
    outputs = flake-utils.lib.eachSystem systems (system: let
      pkgs = nixpkgs.legacyPackages.${system};

      # Import packages from default.nix
      # Prioritize fnoxVersion from the FNOX_VERSION environment variable if set
      envVersion = builtins.getEnv "FNOX_VERSION";
      selectedVersion =
        if envVersion != ""
        then envVersion
        else null;
      fnoxPkgs = import ./default.nix {
        inherit pkgs system;
        fnoxVersion = selectedVersion;
      };
    in {
      packages = fnoxPkgs;

      apps = {
        fnox = flake-utils.lib.mkApp {
          drv = fnoxPkgs.fnox;
          name = "fnox";
        };
        default = flake-utils.lib.mkApp {
          drv = fnoxPkgs.fnox;
          name = "fnox";
        };
      };

      formatter = pkgs.alejandra;

      devShells.default = pkgs.mkShell {
        nativeBuildInputs = [fnoxPkgs.fnox];
      };
    });
  in
    outputs
    // {
      overlays.default = final: prev: {
        fnoxPackages = outputs.packages.${prev.stdenv.hostPlatform.system};
        fnox = outputs.packages.${prev.stdenv.hostPlatform.system}.fnox;
      };
    };
}
