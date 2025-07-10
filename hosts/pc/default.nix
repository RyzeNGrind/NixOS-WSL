{ inputs, ... }:

{
  imports = [
    ./system.nix
    inputs.home-manager.nixosModules.home-manager
    {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.users.ryzengrind = import ./home.nix;
    }
  ];
}
