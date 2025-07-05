{ config, pkgs, lib, ... }:

let
  # Helper: Check if hardware-configuration.nix exists at /etc/nixos at evaluation time.
  # In NixOS, this is not possible at pure evaluation time, so we use a pattern:
  # - If ./hardware-configuration.nix exists in the flake, import it.
  # - If not, generate a minimal hardware-configuration.nix at activation time.
  #
  # For robust, reproducible NixOS flake-based systems, always check in a hardware-configuration.nix.
  # But for WSL or ephemeral systems, we can generate it if missing.
  #
  # This pattern uses lib.optional and builtins.pathExists for local dev, and a fallback for CI/first-run.
  hardwareConfigPath = ./hardware-configuration.nix;
  importHardwareConfig =
    if builtins.pathExists (toString hardwareConfigPath)
    then [ hardwareConfigPath ]
    else [];
in
{
  # System-scoped configuration for WSL host "pc"
  imports = importHardwareConfig;

  # If hardware-configuration.nix is missing, generate it at activation time.
  # This is a NixOS module trick: run nixos-generate-config if needed.
  system.activationScripts.generateHardwareConfig.text =
    lib.optionalString (importHardwareConfig == [])
      ''
        if [ ! -e /etc/nixos/hardware-configuration.nix ]; then
          echo "Generating hardware-configuration.nix..."
          nixos-generate-config --no-filesystems --root / || true
        fi
      '';

  wsl = {
    enable = true;
    defaultUser = "ryzengrind";
    wslConf = {
      network = {
        hostname = "pc";
        generateHosts = true;
        generateResolvConf = true;
      };
      automount = {
        enabled = true;
        options = "metadata,umask=22,fmask=11,uid=1000,gid=100";
        root = "/mnt";
      };
      interop.appendWindowsPath = false;
    };
    startMenuLaunchers = true;
    docker-desktop.enable = false;
    extraBin = with pkgs; [
      { src = "${coreutils}/bin/mkdir"; }
      { src = "${coreutils}/bin/cat"; }
      { src = "${coreutils}/bin/whoami"; }
      { src = "${coreutils}/bin/ls"; }
      { src = "${busybox}/bin/addgroup"; }
      { src = "${su}/bin/groupadd"; }
      { src = "${su}/bin/usermod"; }
      { src = "${shadow}/sbin/unix_chkpwd"; }
      { src = "${systemd}/bin/systemctl"; }
      { src = "${systemd}/bin/loginctl"; }
      { src = "${gnugrep}/bin/grep"; }
    ];
  };

  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
    autoPrune.enable = true;
  };

  users.groups.docker.members = [ config.wsl.defaultUser ];

  users.users.ryzengrind = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" ];
    linger = true;
    # All user-scoped config (shell, packages, etc) should be managed in home.nix via home-manager.
  };

  users.users.root = {
    # Set a secure password or manage via secrets in production
    hashedPassword = "$6$VOP1Yx5OUXwpOFaG$tVWf3Ai0.kzXpblhnatoeHHZb1xGKUuSEEQO79y1efrSyXR0sGmvFjo7oHbZBuQgZ3NFZi0MahU5hbyzsIwqq.";
  };

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];
  };

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "yes";
      PasswordAuthentication = true;
      PubkeyAuthentication = true;
    };
    ports = [ 22 ];
  };

  # Nix settings for reproducible, flake-based workflows
  nixpkgs.config.allowUnfree = true;
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" "auto-allocate-uids" ];
    max-jobs = 1;
  };

  boot.isContainer = true;

  # Provide a minimal set of system packages; user packages go in home.nix
  environment.systemPackages = with pkgs; [
    curl
    git
    wget
    neofetch
    fish
    home-manager
    tmux
    nix
    tzdata
  ];

  # Ensure /usr/bin/systemctl and /usr/bin/grep exist for compatibility
  environment.extraInit = ''
    mkdir -p /usr/bin
    ln -sf ${pkgs.systemd}/bin/systemctl /usr/bin/systemctl
    ln -sf ${pkgs.gnugrep}/bin/grep /usr/bin/grep
  '';

  # Ensure proper user session handling
  services.logind.killUserProcesses = false;

  # Enable lingering for your user
  system.stateVersion = "24.11";
}
