# fnox-overlay

A small Nix flake and overlay for the prebuilt
[fnox](https://github.com/jdx/fnox) release binaries, including the
[alleneubank/fnox](https://github.com/alleneubank/fnox) fork prereleases.

Consumers download neither the fnox source tree nor a Rust toolchain. Nix
fetches the platform archive published by the release, verifies its pinned
SHA-256 hash, and installs the executable without post-install fixups.

## Direct flake package

Add the input and make it follow the consumer's nixpkgs:

~~~nix
inputs.fnox-overlay = {
  url = "github:alleneubank/fnox-overlay";
  inputs.nixpkgs.follows = "nixpkgs";
  inputs.flake-utils.follows = "flake-utils";
};
~~~

Reference the package directly:

~~~nix
fnox = fnox-overlay.packages.${system}.fnox;
~~~

Run it without installing it:

~~~console
nix run github:alleneubank/fnox-overlay -- --version
~~~

## Overlay

`overlays.default` adds `fnox` (and `fnoxPackages`) to nixpkgs at the
`latest` upstream version recorded in `sources.json`:

~~~nix
pkgs = import nixpkgs {
  inherit system;
  overlays = [fnox-overlay.overlays.default];
};
~~~

## Pinning a version (fork releases)

`sources.json` keys every recorded release by version. Select one explicitly
so pure flake evaluation never falls back to `latest`, the same shape
sendapp uses for the tilt fork:

~~~nix
fnoxForkVersion = "1.34.1-fork.20260901.gabcdef123";
fnoxForkOverlay = _: prev: {
  fnox =
    (import "${fnox-overlay}/default.nix" {
      inherit (prev.stdenv.hostPlatform) system;
      pkgs = prev;
      fnoxVersion = fnoxForkVersion;
    }).fnox;
};
~~~

Outside flakes, `FNOX_VERSION=<version>` selects the entry for impure
evaluation.

## Updating sources.json

~~~console
./update                                   # upstream latest (jdx/fnox)
./update 1.34.1                            # a specific upstream version
FNOX_REPO=alleneubank/fnox \
FNOX_PLATFORMS="aarch64-darwin x86_64-linux" \
  ./update 1.34.1-fork.20260901.gabcdef123  # a fork prerelease
~~~

Fork releases ship `checksums.txt`; the script verifies each download against
it before recording the Nix hash. A scheduled workflow refreshes `latest`
from upstream twice a day.
