{
  description = "WSL host config for pc";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    nixos-wsl.url = "github:nix-community/NixOS-WSL/2411.6.0";
    home-manager.url = "github:nix-community/home-manager/release-24.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, nixos-wsl, home-manager, ... }:
    let
      system = "x86_64-linux";
      wsl-nixpkgslib = import nixpkgs { inherit system; };
    in {
      nixosConfigurations.pc = wsl-nixpkgslib.nixosSystem {
        inherit system;
        modules = [
          nixos-wsl.nixosModules.default
          home-manager.nixosModules.home-manager
          # ./wsl.nix
          ./default.nix
        ];
        specialArgs = {
          inherit home-manager;
        };
      };
    };
}
