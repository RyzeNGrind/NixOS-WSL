{ config, pkgs, lib, ... }:

let
  # Robust hardware detection for Home Manager context
  hasHardware = config ? hardware;
  hasNvidia = hasHardware && (config.hardware ? nvidia) && (config.hardware.nvidia.enable or false);
  hasAmd = hasHardware && (config.hardware ? amd) && (config.hardware.amd.enable or false);
  hasOpenGL = hasHardware && (config.hardware ? opengl) && (config.hardware.opengl.enable or false);
  openglExtra = if hasOpenGL && (config.hardware.opengl ? extraPackages) then config.hardware.opengl.extraPackages else [];

  btopPkg =
    if hasOpenGL && openglExtra != [] && lib.any (pkg: lib.getName pkg == "rocm-opencl-icd") openglExtra
    then pkgs.btop-rocm
    else if hasOpenGL && hasNvidia
    then pkgs.btop-cuda
    else pkgs.btop;

  nvtopPkg =
    if hasOpenGL && hasNvidia
    then pkgs.nvtopPackages.nvidia
    else if hasOpenGL && hasAmd
    then pkgs.nvtopPackages.amd
    else pkgs.nvtopPackages.full;

  nerdFontsPatched = pkgs.nerdfonts.override { fonts = [ "FiraCode" "JetBrainsMono" "NerdFontsSymbolsOnly" "Noto" ]; };

  # Central alias list for pretty printing in all shells
  myAliases = [
    { name = "nos"; value = "nh os switch . --dry && nh home switch . --dry"; }
    { name = "nosa"; value = "nh os switch . && nh home switch ."; }
    { name = "ndiff"; value = "nvd diff /run/current-system /nix/var/nix/profiles/system"; }
    { name = "nhs"; value = "nh home switch ."; }
    { name = "ngc"; value = "nh clean all --keep-since 7d --keep 10"; }
    { name = "ngcd"; value = "nh clean all --dry --keep-since 7d --keep 10"; }
    { name = "nsc"; value = "nh search"; }
    { name = "ll"; value = "eza -l --icons=always --group-directories-first --git"; }
    { name = "la"; value = "eza -la --icons=always --group-directories-first --git"; }
    { name = "ls"; value = "eza --icons=always --group-directories-first"; }
    { name = "lt"; value = "eza --tree --icons=always --group-directories-first"; }
    { name = "cat"; value = "bat"; }
    { name = "cd"; value = "z"; }
    { name = "nc"; value = "nix-fast-build .#checks.$(nix eval --impure --raw --expr 'builtins.currentSystem')"; }
    { name = "nd"; value = "nix-fast-build .#devShells.$(nix eval --impure --raw --expr 'builtins.currentSystem').default"; }
    { name = "nb"; value = "nix-fast-build"; }
    { name = "nbtime"; value = "hyperfine 'nix-fast-build .#checks.$(nix eval --impure --raw --expr \\'builtins.currentSystem\\')' 'nix flake check'"; }
    { name = "nix flake check"; value = "nix-fast-build .#checks.$(nix eval --impure --raw --expr 'builtins.currentSystem')"; }
    { name = "nix-build"; value = "nix-fast-build"; }
  ];

  # Git aliases for pretty printing in all shells
  myGitAliases = [
    { name = "gs"; value = "status"; }
    { name = "gb"; value = "branch"; }
    { name = "gc"; value = "commit"; }
    { name = "gco"; value = "checkout"; }
    { name = "gl"; value = "log"; }
    { name = "grl"; value = "reflog"; }
    { name = "gl1"; value = "log -1 HEAD"; }
    { name = "gus"; value = "reset HEAD --"; }
    { name = "gk"; value = "!gitk"; }
  ];

  # Helper to pretty print aliases and git aliases in shell
  fishAliasPrint = ''
    function __print_aliases_pretty
      set_color cyan
      echo "╭─────────────────────────────── Aliases ───────────────────────────────╮"
      set_color normal
      printf "%-18s %s\n" "Alias" "Command"
      set_color brblack
      echo "────────────────────────────────────────────────────────────────────────"
      set_color normal
  '' + (lib.concatMapStringsSep "\n" (a: ''
      printf "%-18s %s\n" '${a.name}' '${a.value}'
  '') myAliases) + ''
      set_color cyan
      echo "╰───────────────────────────────────────────────────────────────────────╯"
      set_color normal
      set_color magenta
      echo "╭─────────────────────────────── Git Aliases ───────────────────────────╮"
      set_color normal
      printf "%-18s %s\n" "Alias" "Git Command"
      set_color brblack
      echo "────────────────────────────────────────────────────────────────────────"
      set_color normal
  '' + (lib.concatMapStringsSep "\n" (a: ''
      printf "%-18s %s\n" '${a.name}' '${a.value}'
  '') myGitAliases) + ''
      set_color magenta
      echo "╰───────────────────────────────────────────────────────────────────────╯"
      set_color normal
    end
    __print_aliases_pretty
  '';

  zshAliasPrint = ''
    __print_aliases_pretty() {
      echo -e "\033[36m╭─────────────────────────────── Aliases ───────────────────────────────╮\033[0m"
      printf "%-18s %s\n" "Alias" "Command"
      echo -e "\033[90m────────────────────────────────────────────────────────────────────────\033[0m"
  '' + (lib.concatMapStringsSep "\n" (a: ''
      printf "%-18s %s\n" '${a.name}' '${a.value}'
  '') myAliases) + ''
      echo -e "\033[36m╰───────────────────────────────────────────────────────────────────────╯\033[0m"
      echo -e "\033[35m╭─────────────────────────────── Git Aliases ───────────────────────────╮\033[0m"
      printf "%-18s %s\n" "Alias" "Git Command"
      echo -e "\033[90m────────────────────────────────────────────────────────────────────────\033[0m"
  '' + (lib.concatMapStringsSep "\n" (a: ''
      printf "%-18s %s\n" '${a.name}' '${a.value}'
  '') myGitAliases) + ''
      echo -e "\033[35m╰───────────────────────────────────────────────────────────────────────╯\033[0m"
    }
    __print_aliases_pretty
  '';

  bashAliasPrint = ''
    __print_aliases_pretty() {
      echo -e "\033[36m╭─────────────────────────────── Aliases ───────────────────────────────╮\033[0m"
      printf "%-18s %s\n" "Alias" "Command"
      echo -e "\033[90m────────────────────────────────────────────────────────────────────────\033[0m"
  '' + (lib.concatMapStringsSep "\n" (a: ''
      printf "%-18s %s\n" '${a.name}' '${a.value}'
  '') myAliases) + ''
      echo -e "\033[36m╰───────────────────────────────────────────────────────────────────────╯\033[0m"
      echo -e "\033[35m╭─────────────────────────────── Git Aliases ───────────────────────────╮\033[0m"
      printf "%-18s %s\n" "Alias" "Git Command"
      echo -e "\033[90m────────────────────────────────────────────────────────────────────────\033[0m"
  '' + (lib.concatMapStringsSep "\n" (a: ''
      printf "%-18s %s\n" '${a.name}' '${a.value}'
  '') myGitAliases) + ''
      echo -e "\033[35m╰───────────────────────────────────────────────────────────────────────╯\033[0m"
    }
    __print_aliases_pretty
  '';
in
{
  home.username = "ryzengrind";
  home.homeDirectory = "/home/ryzengrind";
  home.stateVersion = "24.11";

  # XDG compliance for config/data/cache/state
  xdg = {
    enable = true;
    configHome = "${config.home.homeDirectory}/.config";
    cacheHome = "${config.home.homeDirectory}/.cache";
    dataHome = "${config.home.homeDirectory}/.local/share";
    stateHome = "${config.home.homeDirectory}/.local/state";
  };

  # Shell and environment: fish > zsh > bash (first-class parity)
  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      set -gx LANG en_US.UTF-8
      set -gx LC_ALL en_US.UTF-8
      set -gx TERMINAL_FONT "JetBrainsMono Nerd Font Mono"
      set -gx SSH_AUTH_SOCK "/mnt/wsl/ssh-agent.sock"
      set -gx EZA_ICONS_AUTO 1
      set -gx EZA_ICON_SPACING 2
      set -gx EZA_ICON_TYPE "nerd"
      if test ! -f ~/.cache/nix-index/files
        echo "Initializing nix-index database..."
        nix-index
      end
      function ,,
        nix run "nixpkgs#$argv[1]" -- $argv[2..-1]
      end
      function ,s
        nix shell "nixpkgs#$argv[1]" -- $argv[2..-1]
      end
      # Aliases (parity with zsh)
      alias nos 'nh os switch . --dry && nh home switch . --dry'
      alias nosa 'nh os switch . && nh home switch .'
      alias ndiff 'nvd diff /run/current-system /nix/var/nix/profiles/system'
      alias nhs 'nh home switch .'
      alias ngc 'nh clean all --keep-since 7d --keep 10'
      alias ngcd 'nh clean all --dry --keep-since 7d --keep 10'
      alias nsc 'nh search'
      alias ll 'eza -l --icons=always --group-directories-first --git'
      alias la 'eza -la --icons=always --group-directories-first --git'
      alias ls 'eza --icons=always --group-directories-first'
      alias lt 'eza --tree --icons=always --group-directories-first'
      alias cat 'bat'
      alias cd 'z'
      function nc
        nix-fast-build .#checks.(nix eval --impure --raw --expr 'builtins.currentSystem')
      end
      function nd
        nix-fast-build .#devShells.(nix eval --impure --raw --expr 'builtins.currentSystem').default
      end
      function nb
        nix-fast-build $argv
      end
      function nbtime
        hyperfine "nix-fast-build .#checks.(nix eval --impure --raw --expr 'builtins.currentSystem')" "nix flake check"
      end
      alias "nix flake check" "nix-fast-build .#checks.$(nix eval --impure --raw --expr 'builtins.currentSystem')"
      alias "nix-build" "nix-fast-build"
      # Ghostty shell integration for fish
      if test "$TERM" = "xterm-ghostty"
        source ${pkgs.ghostty.shell_integration}/fish/ghostty.fish
      end
      # Pretty print all aliases and git aliases on shell start
  '' + fishAliasPrint + ''
    '';
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    defaultKeymap = "emacs";
    history = {
      size = 10000;
      path = "${config.xdg.dataHome}/zsh/history";
    };
    oh-my-zsh = {
      enable = true;
      plugins = [
        "git"
        "docker"
        "docker-compose"
        "sudo"
        "history"
        "direnv"
        "colored-man-pages"
        "extract"
        "z"
        "fzf"
        "dirhistory"
        "per-directory-history"
      ];
      theme = "robbyrussell";
    };
    initExtra = ''
      export ZSH_CACHE_DIR="$HOME/.cache/oh-my-zsh"
      if [[ ! -d "$ZSH_CACHE_DIR" ]]; then
        mkdir -p "$ZSH_CACHE_DIR"
        chmod 755 "$ZSH_CACHE_DIR"
      fi
      if [[ ! -d "$ZSH_CACHE_DIR/completions" ]]; then
        mkdir -p "$ZSH_CACHE_DIR/completions"
        chmod 755 "$ZSH_CACHE_DIR/completions"
      fi
      if [ -f "$ZSH_CACHE_DIR/completions/_docker" ]; then
        chmod 644 "$ZSH_CACHE_DIR/completions/_docker"
      fi
      bindkey '^[[A' history-substring-search-up
      bindkey '^[[B' history-substring-search-down
      eval "$(zoxide init zsh)"
      if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
        . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
      fi
      export SSH_AUTH_SOCK="/mnt/wsl/ssh-agent.sock"
      export EZA_ICONS_AUTO=1
      export EZA_ICON_SPACING=2
      export EZA_ICON_TYPE="nerd"
      export LANG=en_US.UTF-8
      export LC_ALL=en_US.UTF-8
      export TERMINAL_FONT="JetBrainsMono Nerd Font Mono"
      if [ ! -f ~/.cache/nix-index/files ]; then
        echo "Initializing nix-index database..."
        nix-index
      fi
      function ,,() {
        nix run "nixpkgs#$1" -- "''${@:2}"
      }
      function ,s() {
        nix shell "nixpkgs#$1" -- "''${@:2}"
      }
      # Fast Nix flake check/devshell aliases (nix-fast-build)
      alias nc='nix-fast-build .#checks.$(nix eval --impure --raw --expr "builtins.currentSystem")'
      alias nd='nix-fast-build .#devShells.$(nix eval --impure --raw --expr "builtins.currentSystem").default'
      alias nb='nix-fast-build'
      alias nbtime='hyperfine "nix-fast-build .#checks.$(nix eval --impure --raw --expr \"builtins.currentSystem\")" "nix flake check"'
      alias "nix flake check"='nix-fast-build .#checks.$(nix eval --impure --raw --expr "builtins.currentSystem")'
      alias "nix-build"='nix-fast-build'
      # Ghostty shell integration for zsh
      if [[ "$TERM" == "xterm-ghostty" ]]; then
        builtin source ${pkgs.ghostty.shell_integration}/zsh/ghostty.zsh
      fi
      # Pretty print all aliases and git aliases on shell start
  '' + zshAliasPrint + ''
    '';
    shellAliases = builtins.listToAttrs (map (a: { name = a.name; value = a.value; }) myAliases);
  };

  programs.bash = {
    enable = true;
    enableCompletion = true;
    shellAliases = builtins.listToAttrs (map (a: { name = a.name; value = a.value; }) myAliases);
    bashrcExtra = ''
      export LANG=en_US.UTF-8
      export LC_ALL=en_US.UTF-8
      export TERMINAL_FONT="JetBrainsMono Nerd Font Mono"
      export SSH_AUTH_SOCK="/mnt/wsl/ssh-agent.sock"
      export EZA_ICONS_AUTO=1
      export EZA_ICON_SPACING=2
      export EZA_ICON_TYPE="nerd"
      # zoxide init
      if command -v zoxide >/dev/null 2>&1; then
        eval "$(zoxide init bash)"
      fi
      # Source nix-daemon if present
      if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
        . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
      fi
      # Initialize nix-index database if missing
      if [ ! -f ~/.cache/nix-index/files ]; then
        echo "Initializing nix-index database..."
        nix-index
      fi
      # Functions for ephemeral package support
      ,,() {
        nix run "nixpkgs#$1" -- "''${@:2}"
      }
      ,s() {
        nix shell "nixpkgs#$1" -- "''${@:2}"
      }
      # Context-aware devshell for future MCP/Agent integration
      export NIX_CONFIG="experimental-features = nix-command flakes"
      export EDITOR="nvim"
      # Ghostty shell integration for bash
      if [[ "$TERM" == "xterm-ghostty" ]]; then
        builtin source ${pkgs.ghostty.shell_integration}/bash/ghostty.bash
      fi
      # Pretty print all aliases and git aliases on shell start
  '' + bashAliasPrint + ''
    '';
  };

  programs.tmux.enable = true;
  programs.neovim.enable = true;

  # Direnv for reproducible dev environments
  programs.direnv = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
    stdlib = ''
      use_devenv() {
        watch_file devenv.nix
        watch_file devenv.lock
        watch_file devenv.yaml
        watch_file pyproject.toml
        watch_file uv.lock
        local max_attempts=3
        local attempt=1
        local timeout=300
        while [ $attempt -le $max_attempts ]; do
          if timeout $timeout devenv shell --print-bash; then
            eval "$(timeout $timeout devenv shell --print-bash)"
            return 0
          fi
          echo "Attempt $attempt failed, retrying..."
          attempt=$((attempt + 1))
          sleep 5
        done
        echo "Failed to initialize devenv after $max_attempts attempts"
        return 1
      }
    '';
  };

  # Git configuration (user-specific)
  programs.git = {
    enable = true;
    userName = "RyzeNGrind";
    userEmail = "git@ryzengrind.xyz";
    delta.enable = true;
    lfs.enable = true;
    extraConfig = {
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
      core.autocrlf = "input";
      diff.colorMoved = "default";
      merge.conflictStyle = "diff3";
      rebase.autoStash = true;
    };
    aliases = {
      gs = "status";
      gb = "branch";
      gc = "commit";
      gco = "checkout";
      gl = "log";
      grl = "reflog";
      gl1 = "log -1 HEAD";
      gus = "reset HEAD --";
      gk = "!gitk";
    };
  };

  # Starship prompt with Catppuccin theme
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    enableFishIntegration = true;
    settings = {
      palette = "catppuccin_mocha";
      palettes.catppuccin_mocha = {
        rosewater = "#f5e0dc";
        flamingo = "#f2cdcd";
        pink = "#f5c2e7";
        mauve = "#cba6f7";
        red = "#f38ba8";
        maroon = "#eba0ac";
        peach = "#fab387";
        yellow = "#f9e2af";
        green = "#a6e3a1";
        teal = "#94e2d5";
        sky = "#89dceb";
        sapphire = "#74c7ec";
        blue = "#89b4fa";
        lavender = "#b4befe";
        text = "#cdd6f4";
        subtext1 = "#bac2de";
        subtext0 = "#a6adc8";
        overlay2 = "#9399b2";
        overlay1 = "#7f849c";
        overlay0 = "#6c7086";
        surface2 = "#585b70";
        surface1 = "#45475a";
        surface0 = "#313244";
        base = "#1e1e2e";
        mantle = "#181825";
        crust = "#11111b";
      };
      character = {
        success_symbol = "[➜](bold green)";
        error_symbol = "[✗](bold red)";
      };
      aws.disabled = true;
      gcloud.disabled = true;
      kubernetes.disabled = true;
      directory = {
        truncation_length = 5;
        truncate_to_repo = true;
      };
      git_branch = {
        symbol = "🌱 ";
        truncation_length = 20;
        truncation_symbol = "...";
      };
      git_status = {
        conflicted = "🏳";
        ahead = "🏎💨";
        behind = "😰";
        diverged = "😵";
        up_to_date = "✓";
        untracked = "🤷";
        stashed = "📦";
        modified = "📝";
        staged = "[++\\($count\\)](green)";
        renamed = "👅";
        deleted = "🗑";
      };
      nix_shell = {
        symbol = "❄️ ";
        format = "via [$symbol$state( \($name\))]($style) ";
      };
    };
  };

  # Nix-index for ephemeral package support
  programs.nix-index = {
    enable = true;
    enableZshIntegration = true;
    enableFishIntegration = true;
  };

  # User-scoped packages, hardware-aware and deduplicated
  home.packages = with pkgs; [
    # Password manager
    _1password-gui-beta
    # Nix
    nixVersions.stable
    # Dev tools
    vim wget curl gh jq yq httpie delta lazygit alejandra home-manager nil just difftastic shellcheck nodePackages.prettier
    nerdFontsPatched
    # System tools
    nvtopPkg
    btopPkg
    ripgrep fd tree duf ncdu bottom du-dust procs sd choose
    # Shell tools
    fzf bat eza zoxide
    # Config/.dotfiles
    dconf2nix
    # Utils
    tldr neofetch p7zip unzip zip
    # Python development tools
    uv ruff nh vivid
    # Useful tools
    comma nix-output-monitor nixpkgs-review statix
    # Optional but recommended
    devenv direnv
    # Ephemeral package support
    nix-index comma
    # Ghostty terminal and terminfo for full shell integration
    ghostty
    ghostty.terminfo
  ];

  # Place user dotfiles, custom scripts, or home.file here as needed
}
