{ config, pkgs, lib, inputs, ... }:

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

  # --- WSL configuration with zsh as login shell, fish as daily shell ---
  wsl = {
    enable = true;
    defaultUser = "ryzengrind";
    wslConf = {
      # Set the default login shell for WSL sessions to zsh
      boot.command = "${pkgs.zsh}/bin/zsh";
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
    # Appended: enable Windows driver if not present
    useWindowsDriver = true;
  };

  # Enable zsh and fish system-wide for robust shell support
  programs.zsh.enable = true;
  programs.fish.enable = true;

  # Set zsh as the default user shell for all users (login shell)
  users.defaultUserShell = pkgs.zsh;

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
    # Set daily terminal to fish by making it the interactive shell in zsh
    shell = pkgs.zsh;
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
    zsh
    # Appended: WSL/CLI/Dev tools from reference config
    nvtopPackages.full
    socat
    starship
    nvd
    wslu
    coreutils
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
    # If this is an interactive shell, exec fish for daily work
    if [[ $- == *i* ]] && [[ -z "$INSIDE_FISH" ]]; then
      exec ${pkgs.fish}/bin/fish
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

  # Set Ghostty as the default terminal for graphical DEs (if supported)
  xdg.terminal-exec.settings.default = [ "ghostty.desktop" ];

  # --- Appended: missing elements from reference config ---

  # PATCH: Remove recursive config.environment.variables reference to fix infinite recursion
  environment.variables = {
    LD_LIBRARY_PATH = "/usr/lib/wsl/lib:$LD_LIBRARY_PATH";
    SSH_AUTH_SOCK = "/mnt/wsl/ssh-agent.sock";
    TERMINAL = "ghostty";
  };

  programs.ssh.startAgent = false;

  programs.nix-ld = {
    enable = true;
    package = pkgs.nix-ld-rs;
  };

  # PATCH: Remove recursive config.nix references to fix infinite recursion
  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" "auto-allocate-uids" ];
      auto-optimise-store = true;
      trusted-users = [ "root" "nixos" ];
      max-jobs = "auto";
      cores = 0;
      keep-outputs = true;
      keep-derivations = true;
      fallback = true;
      require-sigs = true;
      accept-flake-config = true;
      allow-dirty = true;
      warn-dirty = false;
      trusted-substituters = [
        "https://nixpkgs-ci.cachix.org"
        "https://cache.nixos.org"
        "https://nix-community.cachix.org"
        "https://cuda-maintainers.cachix.org"
        "https://devenv.cachix.org"
      ];
      trusted-public-keys = [
        "nixpkgs-ci.cachix.org-1:D/DUreGnMgKVRcw6d/5WxgBDev0PqYElnVB+hZJ+JWw="
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="  
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
        "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
      ];
      sandbox = true;
      use-xdg-base-directories = true;
      download-attempts = 3;
      connect-timeout = 5;
      min-free = 128000000;
      max-free = 1000000000;
    };
    registry = {
      nixpkgs.flake = inputs.nixpkgs;
      nixpkgs-unstable.flake = inputs.nixpkgs-unstable;
      default.flake = inputs.nixpkgs;
    };
  };

  systemd.user.services.ssh-agent-proxy = {
    description = "Windows SSH agent proxy";
    path = [ pkgs.wslu pkgs.coreutils pkgs.bash ];
    serviceConfig = {
      ExecStartPre = [
        "${pkgs.coreutils}/bin/mkdir -p /mnt/wsl"
        "${pkgs.coreutils}/bin/rm -f /mnt/wsl/ssh-agent.sock"
      ];
      ExecStart = "${pkgs.writeShellScript "ssh-agent-proxy" ''
        set -x  # Enable debug output

        # Get Windows username using wslvar
        WIN_USER="$("${pkgs.wslu}/bin/wslvar" USERNAME 2>/dev/null || echo $USER)"

        # Check common npiperelay locations
        NPIPE_PATHS=(
          "/mnt/c/Users/$WIN_USER/AppData/Local/Microsoft/WinGet/Links/npiperelay.exe"
          "/mnt/c/ProgramData/chocolatey/bin/npiperelay.exe"
        )

        NPIPE_PATH=""
        for path in "''${NPIPE_PATHS[@]}"; do
          echo "Checking npiperelay at: $path"
          if [ -f "$path" ]; then
            NPIPE_PATH="$path"
            break
          fi
        done

        if [ -z "$NPIPE_PATH" ]; then
          echo "npiperelay.exe not found in expected locations!"
          exit 1
        fi

        echo "Using npiperelay from: $NPIPE_PATH"

        exec ${pkgs.socat}/bin/socat -d UNIX-LISTEN:/mnt/wsl/ssh-agent.sock,fork,mode=600 \
          EXEC:"$NPIPE_PATH -ei -s //./pipe/openssh-ssh-agent",nofork
      ''}";
      Type = "simple";
      Restart = "always";
      RestartSec = "5";
      StandardOutput = "journal";
      StandardError = "journal";
      RuntimeDirectory = "ssh-agent";
    };
    wantedBy = [ "default.target" ];
  };

  # Disable the default command-not-found
  programs.command-not-found.enable = false;

  programs.nh = {
    enable = true;
    clean = {
      enable = true;
      extraArgs = "--keep-since 7d --keep 10";
    };
    flake = "/home/${config.networking.hostName}/nixos-config";
  };

}
