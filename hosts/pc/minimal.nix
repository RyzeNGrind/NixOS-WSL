# ~/Workspaces/NixOS-WSL/hosts/minimal.nix
{ pkgs, config, ... }:
{
  wsl = {
    enable = true;
    defaultUser = "ryzengrind";

    # CRITICAL FIX: Add the required binaries to the early boot environment.
    extraBin = with pkgs; [
      { src = "${gnugrep}/bin/grep"; }
      { src = "${systemd}/bin/systemctl"; }
      { src = "${systemd}/bin/loginctl"; }
    ];
    wslConf.network = {
      generateHosts = true;
      generateResolvConf = true;
    };
  };
  boot.isContainer = true;

  # Just need a user and a password to log in
  users.users.ryzengrind = {
    isNormalUser = true;
    linger = true;
    hashedPassword = "$6$VOP1Yx5OUXwpOFaG$tVWf3Ai0.kzXpblhnatoeHHZb1xGKUuSEEQO79y1efrSyXR0sGmvFjo7oHbZBuQgZ3NFZi0MahU5hbyzsIwqq.";
  };
  users.users.root.hashedPassword = "$6$VOP1Yx5OUXwpOFaG$tVWf3Ai0.kzXpblhnatoeHHZb1xGKUuSEEQO79y1efrSyXR0sGmvFjo7oHbZBuQgZ3NFZi0MahU5hbyzsIwqq.";
  virtualisation.docker.enable = true;
  users.groups.docker.members = [ config.wsl.defaultUser ];

  # Only include git, so you can pull your real configs if needed.
  environment.systemPackages = with pkgs; [ git gnugrep nix systemd home-manager fish neofetch wget curl ];

  # Basic Nix settings
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
      "auto-allocate-uids"
    ];
    auto-optimise-store = true;
    max-jobs = 1;
    cores = 1;
    warn-dirty = true;  # quietens flake warnings in dev
  };

  system.stateVersion = "24.11";
}
