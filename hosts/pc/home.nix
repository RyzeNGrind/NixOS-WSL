{ config, pkgs, lib, ... }:

{
  # User-scoped (home-manager) configuration for ryzengrind.
  # All user environment, shell, and editor settings should be managed here.
  # System-scoped config (users, groups, systemPackages, etc) should go in system.nix.

  home.username = "ryzengrind";
  home.homeDirectory = "/home/ryzengrind";

  programs.home-manager.enable = true;

  # Shell and environment
  programs.fish.enable = true;
  programs.tmux.enable = true;
  programs.neovim.enable = true;

  # Direnv for reproducible dev environments
  programs.direnv = {
    enable = true;
    enableBashIntegration = true;
    nix-direnv.enable = true;
  };

  # Git configuration (user-specific)
  programs.git = {
    enable = true;
    userName = "RyzeNGrind";
    userEmail = "git@ryzengrind.xyz";
    # Add more user-specific git config here if needed
  };

  # User-scoped packages (edit as needed)
  home.packages = with pkgs; [
    _1password-gui-beta
    nixVersions.stable
    dconf2nix
    neofetch
    nvtopPackages.full
    # Add more user packages here
  ];

  # Place user dotfiles, custom scripts, or home.file here as needed

  # Home-manager state version (keep in sync with system.stateVersion)
  home.stateVersion = "24.11";
}
