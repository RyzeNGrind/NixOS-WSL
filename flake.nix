{
  description = "RyzeNGrind's custom NixOS WSL with flake-parts, 24.11, version-tracked and templatized.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    nixos-wsl.url = "github:nix-community/NixOS-WSL/2411.6.0";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs@{ self, nixpkgs, nixpkgs-unstable, nixos-wsl, flake-parts, ... }:
    let
      # *** THE CRITICAL FIX ***
      # For building the WSL system, we MUST use the nixpkgs that nixos-wsl depends on.
      # We'll call it 'wsl-nixpkgs' to avoid confusion with the top-level input.
      wsl-nixpkgs = nixos-wsl.inputs.nixpkgs;
      # Define NixOS configurations here to be referenced later.
#####################################################################################
#####################################################################################
      # WSL Recovery Shell:
      #  wsl -d NixOS --system --user root -- /mnt/wslg/distro/bin/nixos-wsl-recovery
      # WSL Notes: Must use wsl --import instead of wsl --install to prevent systemctl createuser and loginuser errors from wsl user create integration scripts
      #
      nixosConfigurations = {
        pc = wsl-nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs; };
          modules = [
            ({ ... }: {
              system.configurationRevision = self.rev or "dirty";
            })
            nixos-wsl.nixosModules.default
	    ./hosts/pc/wsl.nix
	    #./hosts/pc/minimal.nix
            ({ ... }: {
	       wsl.tarball.configPath = ./hosts/pc;
            })
          ];
        };
      };
    in
    inputs.flake-parts.lib.mkFlake { inherit self inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" ];

      perSystem = { config, pkgs, system, ... }: {
        # Development shell
        devShells.default = import ./shell.nix { inherit system; nixpkgs = inputs.nixpkgs; };
        
        # 🧃 Expose tarballBuilder by referencing the let-binding
        packages.wslTarball = nixosConfigurations.pc.config.system.build.tarballBuilder;
      };

      # Expose the configurations on the final flake output.
      flake = {
        inherit nixosConfigurations;
      };
    };
}
