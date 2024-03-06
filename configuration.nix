{ config, lib, pkgs, ... }:

{
  # Custom configurations specific to my NixOS-WSL setup
  wsl = {
    enable = true;
    defaultUser = "ryzengrind"; ##EDIT_ME##
    docker-desktop.enable = false;
    nativeSystemd = true;
    startMenuLaunchers = true;
    wslConf = {
      automount = {
        enabled = true;
        options = "metadata,umask=22,fmask=11,uid=1000,gid=100";
        root = "/mnt";
      };
      network = {
        generateHosts = true;
        generateResolvConf = true;
        hostname = "daimyo00"; ##EDIT_ME##
      };
      interop = {
        appendWindowsPath = false;
      };
    };
    extraBin = with pkgs; [
      { src = "${coreutils}/bin/mkdir"; }
      { src = "${coreutils}/bin/cat"; }
      { src = "${coreutils}/bin/whoami"; }
      { src = "${coreutils}/bin/ls"; }
      { src = "${busybox}/bin/addgroup"; }
      { src = "${su}/bin/groupadd"; }
      { src = "${su}/bin/usermod"; }
    ];
    tarball.configPath = ./configuration.nix;
  };
  programs.bash.loginShellInit = "nixos-wsl-welcome";
  systemd.services.docker-desktop-proxy.script = lib.mkForce ''${config.wsl.wslConf.automount.root}/wsl/docker-desktop/docker-desktop-user-distro proxy --docker-desktop-root ${config.wsl.wslConf.automount.root}/wsl/docker-desktop "C:\Program Files\Docker\Docker\resources"'';

  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
    autoPrune.enable = true;
  };

  users.groups.docker.members = [
    config.wsl.defaultUser
  ];

  environment.systemPackages = with pkgs; [ ##EDIT_ME##
    curl
    git
    wget
    neofetch
    nvtop
    _1password-gui-beta
    fish
    home-manager
    sd-switch
    dconf2nix
    screen
    nixops_unstable
    nixops-dns
    nixFlakes
  ];

  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" "repl-flake" "auto-allocate-uids" ];
  boot.isContainer = true;
  users.users.ryzengrind = { ##EDIT_ME##
    isNormalUser = true;
    hashedPassword = "$6$VOP1Yx5OUXwpOFaG$tVWf3Ai0.kzXpblhnatoeHHZb1xGKUuSEEQO79y1efrSyXR0sGmvFjo7oHbZBuQgZ3NFZi0MahU5hbyzsIwqq."; ##EDIT_ME##
  };
  system.stateVersion = config.system.nixos.release;

  systemd.services.nix-daemon-check = {
    script = ''
      if [ ${toString config.wsl.nativeSystemd} = "true" ]; then
        echo "Checking nix-daemon status..."
        systemctl is-active --quiet nix-daemon && echo "nix-daemon is active" || echo "nix-daemon is not active"
        echo "Attempting to start and enable nix-daemon..."
        systemctl start nix-daemon && systemctl enable nix-daemon
        if systemctl is-active --quiet nix-daemon; then
          echo "nix-daemon successfully restarted."
        else
          echo "Failed to restart nix-daemon."
        fi
      else
        echo "Systemd is not enabled. Skipping nix-daemon check."
      fi
    '';
  };
}