{
  description = "WSL host config for pc";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
  inputs.nixos-wsl.url = "github:nix-community/NixOS-WSL/2411.6.0";
  outputs = { self, nixpkgs, nixos-wsl, ... }:
    {
      nixosConfigurations.pc = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          nixos-wsl.nixosModules.default
          #./wsl.nix
	  ./minimal.nix
        ];
      };
    };
}
