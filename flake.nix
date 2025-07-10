{
  description = "RyzeNGrind's custom NixOS WSL with flake-parts, 24.11, version-tracked and templatized.";
  nixConfig = {
    extra-substituters = [
      "https://nix-community.cachix.org"
      "https://cuda-maintainers.cachix.org"
      "https://cache.nixos.org"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
    ];
    experimental-features = ["nix-command" "flakes"];
    trusted-public-keys = [
      "nixpkgs-ci.cachix.org-1:D/DUreGnMgKVRcw6d/5WxgBDev0PqYElnVB+hZJ+JWw="  
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
      "colmena.cachix.org-1:7BzpDnjjH8ki2CT3f6GdOk7QAzPOl+1t3LvTLXqYcSg="
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ];
    trusted-substituters = [
      "https://nixpkgs-ci.cachix.org"      
      "https://nix-community.cachix.org"
      "https://cuda-maintainers.cachix.org"
      "https://colmena.cachix.org"
      "https://cache.nixos.org"
    ];
    substituters = [
      "https://nixpkgs-ci.cachix.org"      
      "https://nix-community.cachix.org"
      "https://cuda-maintainers.cachix.org"
      "https://colmena.cachix.org"
      "https://cache.nixos.org"
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL/2411.6.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-parts.url = "github:hercules-ci/flake-parts";
    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    alejandra.url = "github:kamadorueda/alejandra";
    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nh = {
      url = "github:viperML/nh";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, nixpkgs-unstable, nixos-wsl, flake-parts, home-manager, ... }:
    let
      # Use the nixpkgs that nixos-wsl depends on for WSL system builds.
      wsl-nixpkgs = nixos-wsl.inputs.nixpkgs;

      # Helper to get username@hostname for homeConfigurations, injects Ghostty support for all major shells
      mkHomeConfig = { username, hostname, system ? "x86_64-linux" }: home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs { inherit system; config.allowUnfree = true; };
        modules = [
          ({ pkgs, ... }: {
            # Ensure Ghostty and terminfo are available in user environment
            home.packages = [
              pkgs.ghostty
              pkgs.ghostty.terminfo
            ];

            # Bash integration for Ghostty
            programs.bash = {
              enable = true;
              initExtra = ''
                if [[ "$TERM" == "xterm-ghostty" ]]; then
                  builtin source ${pkgs.ghostty.shell_integration}/bash/ghostty.bash
                fi
              '';
            };

            # Zsh integration for Ghostty
            programs.zsh = {
              enable = true;
              initExtra = ''
                if [[ "$TERM" == "xterm-ghostty" ]]; then
                  source ${pkgs.ghostty.shell_integration}/zsh/ghostty-integration
                fi
              '';
            };

            # Fish integration for Ghostty
            programs.fish = {
              enable = true;
              interactiveShellInit = ''
                if test "$TERM" = "xterm-ghostty"
                  source ${pkgs.ghostty.shell_integration}/fish/vendor_conf.d/ghostty-shell-integration.fish
                end
              '';
            };
          })
          ./hosts/${hostname}/home.nix
        ];
      };
    in
    inputs.flake-parts.lib.mkFlake { inherit self inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" ];

      perSystem = { config, pkgs, system, ... }: {
        # Development shell with Ghostty support for all shells
        devShells.default = pkgs.mkShell {
          packages = [
            pkgs.ghostty
            pkgs.ghostty.terminfo
          ];
          shellHook = ''
            # Bash
            if [ -n "$BASH_VERSION" ] && [ "$TERM" = "xterm-ghostty" ]; then
              builtin source ${pkgs.ghostty.shell_integration}/bash/ghostty.bash
            fi
            # Zsh
            if [ -n "$ZSH_VERSION" ] && [ "$TERM" = "xterm-ghostty" ]; then
              source ${pkgs.ghostty.shell_integration}/zsh/ghostty-integration
            fi
            # Fish
            if [ -n "$FISH_VERSION" ] && [ "$TERM" = "xterm-ghostty" ]; then
              source ${pkgs.ghostty.shell_integration}/fish/vendor_conf.d/ghostty-shell-integration.fish
            fi
          '';
        };

        # Expose tarballBuilder for WSL image export
        packages.wslTarball = let
          pcConfig = wsl-nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            specialArgs = { inherit inputs; };
            modules = [
              ({ pkgs, ... }: {
                system.configurationRevision = self.rev or "dirty";
                wsl.tarball.configPath = ./hosts/pc;
                # System-wide Ghostty support for all shells
                environment.systemPackages = [
                  pkgs.ghostty
                  pkgs.ghostty.terminfo
                ];
                programs.bash.interactiveShellInit = ''
                  if [[ "$TERM" == "xterm-ghostty" ]]; then
                    builtin source ${pkgs.ghostty.shell_integration}/bash/ghostty.bash
                  fi
                '';
                programs.zsh.interactiveShellInit = ''
                  if [[ "$TERM" == "xterm-ghostty" ]]; then
                    source ${pkgs.ghostty.shell_integration}/zsh/ghostty-integration
                  fi
                '';
                programs.fish.interactiveShellInit = ''
                  if test "$TERM" = "xterm-ghostty"
                    source ${pkgs.ghostty.shell_integration}/fish/vendor_conf.d/ghostty-shell-integration.fish
                  end
                '';
              })
              nixos-wsl.nixosModules.default
              ./hosts/pc/default.nix
            ];
          };
        in pcConfig.config.system.build.tarballBuilder;
      };

      # Expose the NixOS and Home Manager configurations
      flake = {
        nixosConfigurations = {
          pc = wsl-nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            specialArgs = { inherit inputs; };
            modules = [
              ({ pkgs, ... }: {
                system.configurationRevision = self.rev or "dirty";
                wsl.tarball.configPath = ./hosts/pc;
                # System-wide Ghostty support for all shells
                environment.systemPackages = [
                  pkgs.ghostty
                  pkgs.ghostty.terminfo
                ];
                programs.bash.interactiveShellInit = ''
                  if [[ "$TERM" == "xterm-ghostty" ]]; then
                    builtin source ${pkgs.ghostty.shell_integration}/bash/ghostty.bash
                  fi
                '';
                programs.zsh.interactiveShellInit = ''
                  if [[ "$TERM" == "xterm-ghostty" ]]; then
                    source ${pkgs.ghostty.shell_integration}/zsh/ghostty-integration
                  fi
                '';
                programs.fish.interactiveShellInit = ''
                  if test "$TERM" = "xterm-ghostty"
                    source ${pkgs.ghostty.shell_integration}/fish/vendor_conf.d/ghostty-shell-integration.fish
                  end
                '';
              })
              nixos-wsl.nixosModules.default
              ./hosts/pc/default.nix
            ];
          };
          # Uncomment if ws config is present
          # ws = wsl-nixpkgs.lib.nixosSystem {
          #   system = "x86_64-linux";
          #   specialArgs = { inherit inputs; };
          #   modules = [
          #     ({ pkgs, ... }: {
          #       system.configurationRevision = self.rev or "dirty";
          #       wsl.tarball.configPath = ./hosts/ws;
          #       # System-wide Ghostty support for all shells
          #       environment.systemPackages = [
          #         pkgs.ghostty
          #         pkgs.ghostty.terminfo
          #       ];
          #       programs.bash.interactiveShellInit = ''
          #         if [[ "$TERM" == "xterm-ghostty" ]]; then
          #           builtin source ${pkgs.ghostty.shell_integration}/bash/ghostty.bash
          #         fi
          #       '';
          #       programs.zsh.interactiveShellInit = ''
          #         if [[ "$TERM" == "xterm-ghostty" ]]; then
          #           source ${pkgs.ghostty.shell_integration}/zsh/ghostty-integration
          #         fi
          #       '';
          #       programs.fish.interactiveShellInit = ''
          #         if test "$TERM" = "xterm-ghostty"
          #           source ${pkgs.ghostty.shell_integration}/fish/vendor_conf.d/ghostty-shell-integration.fish
          #         end
          #       '';
          #     })
          #     nixos-wsl.nixosModules.default
          #     ./hosts/ws/default.nix
          #   ];
          # };
        };

        # Home Manager configuration keyed by username@hostname, not hardcoded
        homeConfigurations = let
          users = [
            { username = "ryzengrind"; hostname = "pc"; }
            # { username = "alice"; hostname = "laptop"; }
          ];
          mkKey = u: "${u.username}@${u.hostname}";
          mkVal = u: mkHomeConfig { inherit (u) username hostname; };
        in
          builtins.listToAttrs (map (u: { name = mkKey u; value = mkVal u; }) users);
      };
    };
}