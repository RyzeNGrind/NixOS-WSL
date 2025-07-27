{ config, lib, pkgs, ... }:

{
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    # Add required runtime libraries here, example:
    stdenv.cc.cc
    glib
    zlib
    mesa.drivers
    libdrm
    xorg.libxcb
    xorg.libX11
    libGL
    vulkan-loader
    # You might want to include more if nvidia-smi complains about missing libs.
  ];

  # Custom configurations specific to my NixOS-WSL setup
  wsl = {
    enable = true;
    defaultUser = "ryzengrind"; ##EDIT_ME##
    docker-desktop.enable = true;
    startMenuLaunchers = true;
    useWindowsDriver = true;
    wslConf = {
      automount = {
        enabled = true;
        options = "metadata,umask=22,fmask=11,uid=1000,gid=100";
        root = "/mnt";
      };
      network = {
        generateHosts = true;
        generateResolvConf = true;
        hostname = "pc"; ##EDIT_ME##
      };
      interop = {
        appendWindowsPath = true;
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
      { src = "${shadow}/sbin/unix_chkpwd"; } #<-- CRUCIAL for PAM
      { src = "${systemd}/bin/systemctl"; }
      { src = "${systemd}/bin/loginctl"; } # Good to include for any linger checks
      { src = "${gnugrep}/bin/grep"; }

    ];
  };
  
  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
    autoPrune.enable = true;
    rootless = {
      enable = true;
      setSocketVariable = true;
      daemon.settings = {
        features.cdi = true;
        cdi-spec-dirs = ["/home/${config.users.users.ryzengrind.name}/.cdi" "/etc/cdi"];
      };
    };
    daemon.settings = {
      features.cdi = true;
      cdi-spec-dirs = ["/etc/cdi"];
    };
  };
  hardware = {
    # Use hardware.graphics for NixOS 24.11+
    graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [
        mesa.drivers
        vulkan-loader
        vulkan-validation-layers
        intel-media-driver
        libvdpau-va-gl
        vaapiVdpau
      ];
      extraPackages32 = with pkgs.pkgsi686Linux; [
        mesa.drivers
        vulkan-loader
      ];
    };
    nvidia = {
      modesetting.enable = true;
      nvidiaSettings = false;
      open = false;
      package = config.boot.kernelPackages.nvidiaPackages.stable;
    };
    nvidia-container-toolkit = {
      enable = true;    
      mount-nvidia-executables = false;
    };
  };
  services.xserver.videoDrivers = ["nvidia"];

  users.groups.docker.members = [
    config.wsl.defaultUser
  ];

  environment.systemPackages = with pkgs; [ ##EDIT_ME##
    curl
    git
    wget
    neofetch
    nvtopPackages.full
    nvidia-docker
    _1password-gui-beta
    fish
    home-manager
    sd-switch
    dconf2nix
    tmux
    nixops_unstable_minimal
    nixops-dns
    nixVersions.stable  
    #nixVersions.minimal
    #nixVersions
    nix
    tzdata
    # Graphics and GPU tools
    glxinfo
    vulkan-tools
    mesa-demos
    # CDI tools are included via nvidia-container-toolkit
  ];

  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" "auto-allocate-uids" ];
  nix.settings.max-jobs = 1;
  boot.isContainer = true;

  users.users.ryzengrind = { ##EDIT_ME##
    isNormalUser = true;
    hashedPassword = "$6$VOP1Yx5OUXwpOFaG$tVWf3Ai0.kzXpblhnatoeHHZb1xGKUuSEEQO79y1efrSyXR0sGmvFjo7oHbZBuQgZ3NFZi0MahU5hbyzsIwqq."; ##EDIT_ME##
    linger = true;
    extraGroups = [ "wheel" "docker" ]; # Add necessary groups
  };
  
  users.users.root = { ##EDIT_ME##
    hashedPassword = "$6$VOP1Yx5OUXwpOFaG$tVWf3Ai0.kzXpblhnatoeHHZb1xGKUuSEEQO79y1efrSyXR0sGmvFjo7oHbZBuQgZ3NFZi0MahU5hbyzsIwqq."; ##EDIT_ME##
  };
  services.earlyoom = {
    enable = true;
    enableNotifications = false;
    enableDebugInfo = true;
  
    # Use the dedicated NixOS options instead of extraArgs for basic parameters
    freeMemThreshold = 10;          # Equivalent to -m 10
    freeMemKillThreshold = 5;       # Second threshold for SIGKILL
    freeSwapThreshold = 5;          # Equivalent to -s 5  
    freeSwapKillThreshold = 2;      # Second threshold for SIGKILL
    reportInterval = 3600;          # Equivalent to -r (in seconds)
  
    # Only use extraArgs for options not covered by dedicated NixOS options
    extraArgs = [
      # Add any additional earlyoom options here that don't have dedicated NixOS options
      # For example: "--prefer" or "--avoid" regexes
    ];
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

  # Open firewall for SSH
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];
  };
  systemd.slices."nix-daemon".sliceConfig = {
    ManagedOOMMemoryPressure = "kill";
    ManagedOOMMemoryPressureLimit = "60%";
  };

  systemd.services.nix-daemon.serviceConfig = {
    Slice = "nix-daemon.slice";
    OOMScoreAdjust = 1000;
  };
  # FIX #2: Use extraInit for creating the symlink, as it's more reliable.
  environment.extraInit = ''
    mkdir -p /usr/bin
    ln -sf ${pkgs.systemd}/bin/systemctl /usr/bin/systemctl
    ln -sf ${pkgs.gnugrep}/bin/grep /usr/bin/grep
  '';
  
  # Critical: Environment variables for WSL2 GPU acceleration
  environment.sessionVariables = {
    # NVIDIA-specific paths for WSL2 - combine with nix-ld path
    NIX_LD_LIBRARY_PATH = lib.mkForce "/usr/lib/wsl/lib:/run/current-system/sw/share/nix-ld/lib";
    MESA_D3D12_DEFAULT_ADAPTER_NAME = "NVIDIA";
    # Vulkan WSL2 workaround - use dzn (Direct3D 12 to Vulkan translation)
    VK_DRIVER_FILES = "/usr/share/vulkan/icd.d/dzn_icd.x86_64.json";
    # Additional library path for Mesa D3D12 support
    LD_LIBRARY_PATH = "/usr/lib/wsl/lib:/run/opengl-driver/lib";
    # Force Mesa to use D3D12 backend in WSL2
    MESA_LOADER_DRIVER_OVERRIDE = "d3d12";
    # Enable Vulkan validation layers for debugging (optional)
    # VK_INSTANCE_LAYERS = "VK_LAYER_KHRONOS_validation";
  };

  # System-level environment variables that persist across sessions
  environment.variables = {
    MESA_D3D12_DEFAULT_ADAPTER_NAME = "NVIDIA";
  };

  # CDI generation service - runs on boot to generate NVIDIA CDI specs
  systemd.services.nvidia-cdi-generate = {
    description = "Generate NVIDIA CDI specifications for containers";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "nvidia-cdi-setup" ''
        set -eu
        
        # Ensure CDI directories exist
        mkdir -p /etc/cdi
        mkdir -p /home/${config.wsl.defaultUser}/.cdi
        
        # Generate system-wide CDI spec
        if ! test -f /etc/cdi/nvidia.yaml; then
          echo "Generating system-wide NVIDIA CDI spec..."
          ${pkgs.nvidia-container-toolkit}/bin/nvidia-ctk cdi generate --output="/etc/cdi/nvidia.yaml" || echo "Failed to generate system CDI spec"
        fi
        
        # Generate user CDI spec with proper ownership
        if ! test -f /home/${config.wsl.defaultUser}/.cdi/nvidia.yaml; then
          echo "Generating user NVIDIA CDI spec..."
          ${pkgs.nvidia-container-toolkit}/bin/nvidia-ctk cdi generate --output="/home/${config.wsl.defaultUser}/.cdi/nvidia.yaml" || echo "Failed to generate user CDI spec"
          chown -R ${config.wsl.defaultUser}:users /home/${config.wsl.defaultUser}/.cdi/ || true
        fi
        
        echo "NVIDIA CDI setup completed"
      '';
    };
  };

  # User service for CDI generation (runs as user, not root)
  systemd.user.services.nvidia-cdi-user = {
    description = "Generate user NVIDIA CDI specifications";
    wantedBy = [ "default.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "nvidia-cdi-user-setup" ''
        set -eu
        
        # Ensure user CDI directory exists
        mkdir -p "$HOME/.cdi"
        
        # Generate user CDI spec
        if ! test -f "$HOME/.cdi/nvidia.yaml"; then
          echo "Generating user NVIDIA CDI spec..."
          ${pkgs.nvidia-container-toolkit}/bin/nvidia-ctk cdi generate --output="$HOME/.cdi/nvidia.yaml" || echo "Failed to generate user CDI spec"
        fi
        
        echo "User NVIDIA CDI setup completed"
      '';
    };
  };
  
  # Ensure proper user session handling
  services.logind.killUserProcesses = false;
  # Enable lingering for your user
  system.stateVersion = "24.11";
}

