{
  description = "roc-xlsx";

  nixConfig = {
    extra-substituters = [ "https://niclas-ahden.cachix.org" ];
    extra-trusted-public-keys = [ "niclas-ahden.cachix.org-1:FdGli1vBk0cTuVJV27Tau/JvlbW+Ly3pRwFByyqdke0=" ];
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    # The Roc compiler revision, keep the `?dir=src` at the end
    roc-src.url = "github:roc-lang/roc/5785b23bd4da7b8ad29444e62526033957f6683b?dir=src";
    roc-nix = {
      url = "github:niclas-ahden/roc-nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.roc-src.follows = "roc-src";
    };
  };

  outputs = { nixpkgs, flake-utils, roc-nix, ... }:
    flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ] (system:
      let
        pkgs = import nixpkgs { inherit system; };

        # Builds Roc using `ReleaseFast`. To chase a suspected compiler fault,
        # build a `ReleaseSafe` variant of the same revision:
        #
        #   roc-nix.lib.${system}.mkRoc { optimize = "ReleaseSafe"; }
        #
        # roc-nix's README lists the rest of the build options, patches
        # included.
        roc = roc-nix.packages.${system}.roc;
      in
      {
        formatter = pkgs.nixpkgs-fmt;

        packages = {
          inherit roc;
          default = roc;
        };

        devShells = {
          default = pkgs.mkShell {
            buildInputs = [
              roc
              pkgs.watchexec
              # tests/integration_test.roc hands the spreadsheets we write to
              # unzip and reads them back, so the script never assumes host tools.
              pkgs.unzip
            ];

            shellHook = ''
              export ROC_LANGUAGE_SERVER_PATH=${roc}/bin/roc
            '';
          };
        };
      });
}
