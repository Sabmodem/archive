# Archive System

Btrfs-based archive storage managed with Nix flakes and disko. Creates partitioned disk with subvolumes for ingress, archive, live data, and snapshots.

## Quick Start

### 1. Format disk

```bash
sudo nix run github:nix-community/disko -- --flake .#archive --argstr device /dev/loop0 --mode format
```

### 2. Enter dev shell

```bash
ARCHIVE_MOUNT_POINT=/mnt/archive ARCHIVE_DEVICE=/dev/loop0p1 nix develop --command zsh
```

### 3. Mount subvolumes

```bash
ARCHIVE_MOUNT_POINT=/mnt/archive ARCHIVE_DEVICE=/dev/loop0p1 nix run .#mount-archive
```

## Commands

| Command | Description |
|---------|-------------|
| `nix run .#mount-archive` | Mount all Btrfs subvolumes |
| `nix run .#umount-archive` | Unmount all subvolumes |
| `nix run .#syncthing-archive` | Run syncthing in `@live/syncthing` |
| `nix run .#mbsync-archive` | Sync emails to `@live/mail` |

## Architecture

```
@ingress/    # Temporary intake area
@archive/    # Long-term storage
@live/       # Active data (syncthing, mail, etc.)
@snapshots/  # Btrfs snapshots
```

## mbsync

Run `mbsync-archive` to sync emails. First run creates `@live/mail/mbsyncrc.template` — edit `Host/User/PassCmd` before next run.

Password decryption uses `age`:
```bash
age -d -i ~/.config/age/keys.txt @live/mail/pass.age
```

## VSCode

Included `my-vscode` with extensions:
- `ms-azuretools.vscode-containers`
- `jnoortheen.nix-ide`

## Development

Enter shell:
```bash
ARCHIVE_MOUNT_POINT=/mnt/archive ARCHIVE_DEVICE=/dev/loop0p1 nix develop
```
