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
    roc-src.url = "github:roc-lang/roc/b797cda76e77b9e514c2192ca6513d0ba9a39070?dir=src";
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
              # and to xmllint, which parses every part as XML
              pkgs.libxml2
            ]
            # and to LibreOffice, which opens one and reads the cells back. It is
            # 2.6 GiB and nixpkgs builds it for Linux only, which is also where CI
            # runs, so elsewhere the test skips itself.
            ++ pkgs.lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.libreoffice ];

            shellHook = ''
              export ROC_LANGUAGE_SERVER_PATH=${roc}/bin/roc
            '' + pkgs.lib.optionalString pkgs.stdenv.hostPlatform.isLinux ''
              # A missing soffice fails the integration test instead of skipping it
              export ROC_XLSX_REQUIRE_LIBREOFFICE=1
            '';
          };
        };
      });
}
