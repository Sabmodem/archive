# Archive System — Nix Flake

## Setup

### Partition & format disk
```bash
sudo nix run github:nix-community/disko -- --flake .#archive --argstr device /dev/loop0 --mode format
```

### Enter dev shell
```bash
ARCHIVE_MOUNT_POINT=/mnt/archive ARCHIVE_DEVICE=/dev/loop0p1 nix develop --command zsh
```

## Commands

Run flake packages:
- `nix run .#mount-archive` — mount Btrfs subvolumes (requires `ARCHIVE_DEVICE`, `ARCHIVE_MOUNT_POINT`)
- `nix run .#umount-archive` — unmount all subvolumes
- `nix run .#syncthing-archive` — run syncthing with config/data in `@live/syncthing`
- `nix run .#mbsync-archive` — run mbsync (creates temp config from template)

## Architecture

- **diskoConfigurations.archive** — partitions disk, creates Btrfs subvolumes: `@ingress`, `@archive`, `@live`, `@snapshots`
- **devShells.default** — includes: opencode, isync, syncthing, btrfs-progs, util-linux, my-vscode (with containers + nix-ide extensions)
- **Shell helpers** — `mount-archive`, `umount-archive`, `syncthing-archive`, `mbsync-archive`

## Notes

- `mbsync-archive` creates `mbsyncrc.template` if missing — edit `Host/User/PassCmd` before running again
- `mbsync` uses `age` to decrypt passwords: `age -d -i @HOME@/.config/age/keys.txt @ARCHIVE@/pass.age`
- VSCode extensions: `ms-azuretools.vscode-containers`, `jnoortheen.nix-ide`
