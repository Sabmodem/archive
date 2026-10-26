{
  description = "Archive: disko + devShell с mbsync/syncthing/vscode";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, disko }:
  let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; config.allowUnfree = true; };

    my-vscode = pkgs.vscode-with-extensions.override {
      vscodeExtensions = with pkgs.vscode-extensions; [
        ms-azuretools.vscode-containers
        jnoortheen.nix-ide
      ];
    };

    mbsyncrcTemplate = pkgs.writeText "mbsyncrc.template" ''
      IMAPAccount work
      Host imap.example.com
      User me@example.com
      PassCmd "secret-tool lookup service imap user me@example.com"
      TLSType IMAPS

      IMAPStore work-remote
      Account work

      MaildirStore work-local
      Path __ARCHIVE__/archive/work/
      Inbox __ARCHIVE__/archive/work/Inbox
      SubFolders Verbatim

      Channel work
      Far :work-remote:
      Near :work-local:
      Patterns *
      Create Both
      Expunge Both
      SyncState *
    '';

    syncthing-archive = pkgs.writeShellApplication {
      name = "syncthing-archive";
      runtimeInputs = [ pkgs.syncthing pkgs.coreutils ];
      text = ''
        : "''${ARCHIVE:?ARCHIVE is not set}"
        ST_HOME="$ARCHIVE/live/syncthing"
        mkdir -p "$ST_HOME"
        exec syncthing -home "$ST_HOME" -no-browser -no-restart "$@"
      '';
    };

    mbsync-archive = pkgs.writeShellApplication {
      name = "mbsync-archive";
      runtimeInputs = [ pkgs.isync pkgs.coreutils ];
      text = ''
        : "''${ARCHIVE:?ARCHIVE is not set}"
        CFG="$ARCHIVE/live/mbsync/.mbsyncrc"
        if [ ! -f "$CFG" ]; then
          echo "no config at $CFG — run: archive-init" >&2
          exit 1
        fi
        exec mbsync -c "$CFG" "$@"
      '';
    };

    archive-init = pkgs.writeShellApplication {
      name = "archive-init";
      runtimeInputs = [ pkgs.coreutils pkgs.gnused ];
      text = ''
        : "''${ARCHIVE:?ARCHIVE is not set}"

        mkdir -p "$ARCHIVE/live/mbsync" "$ARCHIVE/live/syncthing"

        CFG="$ARCHIVE/live/mbsync/.mbsyncrc"
        if [ ! -f "$CFG" ]; then
          sed "s|__ARCHIVE__|$ARCHIVE|g" ${mbsyncrcTemplate} > "$CFG"
          chmod 600 "$CFG"
          echo "created $CFG"
        else
          echo "exists: $CFG"
        fi

        echo "syncthing home: $ARCHIVE/live/syncthing"
      '';
    };
  in {
    # ── disko ───────────────────────────────────────────────────────────
    # Остаётся функцией с параметром device.
    # --argstr device /dev/loop1 → сюда прилетит строка.
    diskoConfigurations.archive = { device, ... }: {
      disko.devices.disk.archive = {
        type = "disk";
        inherit device;
        content = {
          type = "gpt";
          partitions.data = {
            size = "100%";
            content = {
              type = "btrfs";
              extraArgs = [ "-f" "-L" "archive" ];
              subvolumes = {
                "@ingress"      = { };
                "@archive" = { };
                "@live"     = { };
                "@snapshots" = { };
              };
            };
          };
        };
      };
    };

    # ── devShell ────────────────────────────────────────────────────────
    devShells.${system}.default = pkgs.mkShell {
      packages = with pkgs; [
        isync syncthing btrfs-progs util-linux
        my-vscode
        archive-init syncthing-archive mbsync-archive
      ];
      shellHook = ''
        if [ -z "''${ARCHIVE:-}" ]; then
          echo "warning: ARCHIVE not set; set it to the mounted archive root" >&2
        else
          export MBSYNC_CONFIG="$ARCHIVE/live/mbsync/.mbsyncrc"
          export SYNCTHING_HOME="$ARCHIVE/live/syncthing"
          echo "archive=$ARCHIVE"
        fi
      '';
    };

    # ── пакеты ──────────────────────────────────────────────────────────
    packages.${system} = {
      inherit mbsyncrcTemplate syncthing-archive mbsync-archive archive-init;
    };

    # ── nixosModules (опционально) ──────────────────────────────────────
    nixosModules.syncthing-archive = { lib, ... }: {
      imports = [ disko.nixosModules.disko ];
      # ...
    };
  };
}

# TODO: one env var with the archive location, all scripts follow it. systemd unit for syncthing, proper naming of subvolumes