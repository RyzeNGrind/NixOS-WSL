{
  description = "A robust, working NixOS-WSL configuration";

  inputs = {
    # We only need the nixos-wsl input. It brings its own nixpkgs.
    nixos-wsl.url = "github:nix-community/NixOS-WSL";
  };

  # Change the signature to accept the whole `inputs` set
  outputs = { self, nixos-wsl, ... }@inputs:
    let
      # Define our system architecture
      system = "x86_64-linux";
      
      # *** THIS IS THE CRITICAL CHANGE ***
      # We get nixpkgs from nixos-wsl's inputs, ensuring they are compatible.
      nixpkgs = nixos-wsl.inputs.nixpkgs;

    in {
      # This makes it so you can just run `nix build` to get the tarball
      packages.${system}.default = self.nixosConfigurations.wsl.config.system.build.tarballBuilder;

      nixosConfigurations.wsl = nixpkgs.lib.nixosSystem {
        inherit system;
        
        # Pass the inputs down so modules can access them if needed.
        specialArgs = { inherit inputs; }; 
        
        modules = [
          nixos-wsl.nixosModules.default
          (
            { config, pkgs, ... }: {
              # 1. Enable WSL integration and set the default user
              wsl.enable = true;
              wsl.defaultUser = "ryzengrind";

              # This is still good practice to have.
              wsl.extraBin = with pkgs; [
                { src = "${gnugrep}/bin/grep"; }
                { src = "${systemd}/bin/systemctl"; }
                { src = "${systemd}/bin/loginctl"; }
              ];

              # 2. This is required for systemd to function correctly in WSL
              boot.isContainer = true;

              # 3. Define your users.
              users.users = {
                ryzengrind = {
                  isNormalUser = true;
                  linger = true;
                  hashedPassword = "$6$VOP1Yx5OUXwpOFaG$tVWf3Ai0.kzXpblhnatoeHHZb1xGKUuSEEQO79y1efrSyXR0sGmvFjo7oHbZBuQgZ3NFZi0MahU5hbyzsIwqq.";
                };
                root = {
                  hashedPassword = "$6$VOP1Yx5OUXwpOFaG$tVWf3Ai0.kzXpblhnatoeHHZb1xGKUuSEEQO79y1efrSyXR0sGmvFjo7oHbZBuQgZ3NFZi0MahU5hbyzsIwqq.";
                };
              };

              # 4. A minimal set of packages for a stable first boot.
              environment.systemPackages = with pkgs; [
                git
                nix
                systemd # provides systemctl
                gnugrep
                wget
                curl
                fish
                neofetch
                home-manager
              ];

              # 5. Enable Flakes
              nix.settings.experimental-features = [ "nix-command" "flakes" ];

              # 6. Set the state version
              system.stateVersion = "24.11"; # Or "24.05", etc., matching nixpkgs branch if you override

              # 7. This fix is still necessary for interop once boot succeeds.
              environment.extraInit = ''
                mkdir -p /usr/bin
                ln -sf ${pkgs.systemd}/bin/systemctl /usr/bin/systemctl
              '';
            }
          )
        ];
      };
    };
}
