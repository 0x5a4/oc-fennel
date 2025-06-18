{
  inputs = {
    utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      utils,
    }:
    utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        lib = nixpkgs.lib;
      in
      {
        packages.default = pkgs.stdenv.mkDerivation (finalAttrs: {
          pname = "oc-fennel";
          version = "1.5.3"; # also update in programs.cfg

          src = pkgs.fetchFromSourcehut {
            owner = "~technomancy";
            repo = "fennel";
            rev = finalAttrs.version;
            hash = "sha256-7Tq6Vx032jxnfPmtsKiTBQ/yH8vHO8+wMoQHZSIevWY=";
          };

          buildInputs = [ pkgs.lua ];

          patches = [
            ./patches/search-path.patch
            ./patches/arg-emulation.patch
            ./patches/no-readline.patch
          ];

          buildPhase = ''
            mkdir -p $out/lib/fennel $out/bin $out/boot

            make bootstrap/macros.lua bootstrap/match.lua bootstrap/view.lua

            # build fennel lib
            while read -r fnl 
            do
              outfile=''${fnl%".fnl"} 

              lua bootstrap/aot.lua src/fennel/$fnl > $out/lib/fennel/''${outfile}.lua
            done < <(find src/fennel \
              -iname "*.fnl" \
              -type f \
              -not -name macros.fnl \
              -not -name match.fnl \
              -printf "%f\n")

            lua bootstrap/aot.lua src/fennel.fnl > $out/lib/fennel.lua

            # fennel bin
            lua bootstrap/aot.lua src/launcher.fnl >> $out/bin/fennel.lua

            # fennel searcher init script
            cp ${./99_fennel.lua} $out/boot/99_fennel.lua
          '';

          dontInstall = true;

          meta = {
            license = lib.licenses.mit;
          };
        });
      }
    );
}
