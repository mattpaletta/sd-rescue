{
  description = "sd-rescue: recover deleted photos from an SD card on macOS using photorec";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = { self, nixpkgs }:
    let
      # The script relies on macOS tools (diskutil, /dev/rdiskN), so Darwin only.
      systems = [ "aarch64-darwin" "x86_64-darwin" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      packages = forAllSystems (pkgs: rec {
        sd-rescue = pkgs.stdenvNoCC.mkDerivation {
          pname = "sd-rescue";
          version = "0.1.0";
          src = ./.;

          nativeBuildInputs = [ pkgs.makeWrapper ];
          dontBuild = true;

          installPhase = ''
            runHook preInstall
            install -Dm755 recover-sd.sh $out/bin/sd-rescue
            # Prefix only: diskutil, dd and sudo still come from the system PATH.
            wrapProgram $out/bin/sd-rescue \
              --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.testdisk ]}
            runHook postInstall
          '';

          meta = {
            description = "Guided photorec wrapper to recover deleted photos from an SD card";
            homepage = "https://github.com/ochias/sd-rescue";
            license = pkgs.lib.licenses.mit;
            platforms = pkgs.lib.platforms.darwin;
            mainProgram = "sd-rescue";
          };
        };
        default = sd-rescue;
      });

      apps = forAllSystems (pkgs: rec {
        sd-rescue = {
          type = "app";
          program = "${self.packages.${pkgs.stdenv.hostPlatform.system}.sd-rescue}/bin/sd-rescue";
        };
        default = sd-rescue;
      });

      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = [ pkgs.testdisk pkgs.shellcheck ];
        };
      });
    };
}
