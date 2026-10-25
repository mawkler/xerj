{
  description = "XERJ: the unified search engine for AI";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      forAllSystems = nixpkgs.lib.genAttrs [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      name = "xerj";
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          lib = pkgs.lib;
        in
        {
          default = pkgs.rustPlatform.buildRustPackage {
            pname = name;
            version = (lib.importTOML ./engine/Cargo.toml).workspace.package.version;

            # xerj-console-api's build.rs embeds ../../../xerj-ux; without it the console ships empty
            src = lib.fileset.toSource {
              root = ./.;
              fileset = lib.fileset.unions [
                ./engine
                ./xerj-ux
              ];
            };
            cargoRoot = "engine";
            buildAndTestSubdir = "engine";
            cargoLock.lockFile = ./engine/Cargo.lock;
            cargoBuildFlags = [
              "-p"
              "xerj-server"
            ];

            # openssl-src builds with perl
            nativeBuildInputs = [ pkgs.perl ];

            # shortcut: tests read files outside engine/ (landing/…) and CI runs them; widen src + enable to test under nix
            doCheck = false;

            meta = {
              description = "Unified search engine for AI, with an Elasticsearch 8.x-compatible API";
              homepage = "https://xerj.org";
              license = lib.licenses.asl20;
              mainProgram = name;
            };
          };
        }
      );

      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            inputsFrom = [ self.packages.${system}.default ];
            # Debug builds are -O0, where fortify's warning trips jemalloc's -Werror configure probes
            hardeningDisable = [ "fortify" ];
            packages = with pkgs; [
              rustfmt
              clippy
              rust-analyzer
              cargo-audit
              python3
              nodejs
            ];
          };
        }
      );
    };
}
