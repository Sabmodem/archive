#!/usr/bin/env bash
#
# format_btrfs.sh — форматирование диска в Btrfs с набором subvolume'ов
# Data profile: single
#
# ВНИМАНИЕ: скрипт УНИЧТОЖИТ все данные на указанном устройстве!
#
# Использование:
#   sudo ./format_btrfs.sh /dev/sdX
#

set -euo pipefail

# ---------- Проверки ----------
if [[ $EUID -ne 0 ]]; then
    echo "Ошибка: скрипт должен запускаться от root." >&2
    exit 1
fi

if [[ $# -ne 1 ]]; then
    echo "Использование: $0 <device>" >&2
    echo "Пример: $0 /dev/sdb" >&2
    exit 1
fi

DEVICE="$1"

if [[ ! -b "$DEVICE" ]]; then
    echo "Ошибка: '$DEVICE' не является блочным устройством." >&2
    exit 1
fi

# ---------- Подтверждение ----------
echo "=========================================================="
echo " ВНИМАНИЕ! Все данные на $DEVICE будут УНИЧТОЖЕНЫ!"
echo "=========================================================="
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT "$DEVICE" || true
echo
read -r -p "Продолжить? Введите 'yes' для подтверждения: " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
    echo "Отменено."
    exit 1
fi

# ---------- Монтирование (если уже смонтирован — размонтируем) ----------
if mount | grep -q "^${DEVICE}"; then
    echo ">> Размонтируем $DEVICE..."
    umount -R "$DEVICE"* 2>/dev/null || umount -R "$DEVICE" || true
fi

# ---------- Проверка утилит ----------
for cmd in mkfs.btrfs mount umount; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Ошибка: утилита '$cmd' не найдена. Установите btrfs-progs." >&2
        exit 1
    fi
done

# ---------- Форматирование ----------
echo ">> Форматируем $DEVICE в Btrfs (data profile: single)..."
# По умолчанию mkfs.btrfs использует single для data и metadata,
# но укажем явно для прозрачности.
mkfs.btrfs -f -d single -m single -L "BTRFS_DATA" "$DEVICE"

# ---------- Создание subvolume'ов ----------
MNT_DIR="$(mktemp -d /tmp/btrfs-format.XXXXXX)"
cleanup() {
    echo ">> Размонтируем $MNT_DIR..."
    umount "$MNT_DIR" 2>/dev/null || true
    rmdir "$MNT_DIR" 2>/dev/null || true
}
trap cleanup EXIT

echo ">> Монтируем верхний уровень в $MNT_DIR..."
mount "$DEVICE" "$MNT_DIR"

echo ">> Создаём subvolume'ы..."
for sv in @ingress @archive @live @snapshots; do
    btrfs subvolume create "$MNT_DIR/$sv"
done

echo ">> Список созданных subvolume'ов:"
btrfs subvolume list "$MNT_DIR"

echo
echo "Готово. Устройство $DEVICE отформатировано."
echo "Subvolume'ы: @ingress, @archive, @live, @snapshots"