{ config, pkgs, lib, ... }:

let
  # Robust hardware-configuration.nix import pattern for flakes/WSL/CI
  hardwareConfigPath = ./hardware-configuration.nix;
  importHardwareConfig =
    if builtins.pathExists (toString hardwareConfigPath)
    then [ hardwareConfigPath ]
    else [];
in
{
  # System-scoped configuration for WSL host "pc"
  imports = importHardwareConfig;

  # Generate hardware-configuration.nix at activation if missing (for ephemeral/CI/WSL)
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
    description = "ryzengrind";
    extraGroups = [ "docker" "wheel" "ryzengrind" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPL6GOQ1zpvnxJK0Mz+vUHgEd0f/sDB0q3pa38yHHEsC ryzengrind@git"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH29BMQNo3O6KvvuquVcmCt2gF7bhD0EPvZyUD47G+3R ryzengrind@oci"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILaDf9eWQpCOZfmuCwkc0kOH6ZerU7tprDlFTc+RHxCq ryzengrind@termius"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAitSzTpub1baCfA94ja3DNZpxd74kDSZ8RMLDwOZEOw ryzengrind@nixos"
    ];
    # Do NOT add user packages here; use Home Manager for user-scoped packages.
    packages = with pkgs; [
      rustdesk-flutter
    ];
    hashedPassword = "$6$VOP1Yx5OUXwpOFaG$tVWf3Ai0.kzXpblhnatoeHHZb1xGKUuSEEQO79y1efrSyXR0sGmvFjo7oHbZBuQgZ3NFZi0MahU5hbyzsIwqq.";
    linger = true;
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

  # --- Ghostty Integration: system-wide, with terminfo and shell integration for all major shells ---
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
    ghostty
    ghostty.terminfo
  ];

  # Bash shell integration for Ghostty (enables OSC features, etc.)
  programs.bash.interactiveShellInit = ''
    if [[ "$TERM" == "xterm-ghostty" ]]; then
      builtin source ${pkgs.ghostty.shell_integration}/bash/ghostty.bash
    fi
  '';

  # Zsh shell integration for Ghostty
  programs.zsh.interactiveShellInit = ''
    if [[ "$TERM" == "xterm-ghostty" ]]; then
      source ${pkgs.ghostty.shell_integration}/zsh/ghostty.zsh
    fi
  '';

  # Fish shell integration for Ghostty
  programs.fish.interactiveShellInit = ''
    if test "$TERM" = "xterm-ghostty"
      source ${pkgs.ghostty.shell_integration}/fish/ghostty.fish
    end
  '';

  # Ensure /usr/bin/systemctl and /usr/bin/grep exist for compatibility
  environment.extraInit = ''
    mkdir -p /usr/bin
    sudo ln -sf ${pkgs.systemd}/bin/systemctl /usr/bin/systemctl
    sudo ln -sf ${pkgs.gnugrep}/bin/grep /usr/bin/grep
  '';

  # Ensure proper user session handling
  services.logind.killUserProcesses = false;

  # Enable lingering for your user
  system.stateVersion = "24.11";

  # Set Ghostty as the default terminal emulator for the user (system-wide)
  environment.variables.TERMINAL = "ghostty";
  # Set Ghostty as the default terminal for graphical DEs (if supported)
  xdg.terminal-exec.settings.default = [ "ghostty.desktop" ];
}
