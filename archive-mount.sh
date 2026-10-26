#!/usr/bin/env bash
#
# mount_btrfs.sh — монтирует все subvolume'ы Btrfs-диска в подпапки
#
# Использование:
#   sudo ./mount_btrfs.sh <device> <mount_point>
#
# Пример:
#   sudo ./mount_btrfs.sh /dev/sdb /mnt/data
#
# Результат:
#   /mnt/data/@ingress   <- subvol @ingress
#   /mnt/data/@archive   <- subvol @archive
#   /mnt/data/@live      <- subvol @live
#   /mnt/data/@snapshots <- subvol @snapshots
#

set -euo pipefail

# ---------- Проверки ----------
if [[ $EUID -ne 0 ]]; then
    echo "Ошибка: скрипт должен запускаться от root." >&2
    exit 1
fi

if [[ $# -ne 2 ]]; then
    echo "Использование: $0 <device> <mount_point>" >&2
    echo "Пример: $0 /dev/sdb /mnt/data" >&2
    exit 1
fi

DEVICE="$1"
MOUNT_ROOT="$2"

if [[ ! -b "$DEVICE" ]]; then
    echo "Ошибка: '$DEVICE' не является блочным устройством." >&2
    exit 1
fi

# Список subvolume'ов для монтирования
SUBVOLS=(@ingress @archive @live @snapshots)

# ---------- Создаём точку монтирования ----------
if [[ ! -d "$MOUNT_ROOT" ]]; then
    echo ">> Создаём точку монтирования $MOUNT_ROOT..."
    mkdir -p "$MOUNT_ROOT"
fi

# ---------- Временная точка для проверки subvolume'ов ----------
TMP_MNT="$(mktemp -d /tmp/btrfs-check.XXXXXX)"
cleanup_tmp() {
    umount "$TMP_MNT" 2>/dev/null || true
    rmdir "$TMP_MNT" 2>/dev/null || true
}
trap cleanup_tmp EXIT

echo ">> Проверяем subvolume'ы на $DEVICE..."
mount -o ro "$DEVICE" "$TMP_MNT"

# Собираем список реально существующих subvolume'ов
mapfile -t EXISTING < <(btrfs subvolume list "$TMP_MNT" | awk '{print $NF}')

umount "$TMP_MNT"

if [[ ${#EXISTING[@]} -eq 0 ]]; then
    echo "Ошибка: на $DEVICE не найдено subvolume'ов." >&2
    exit 1
fi

echo ">> Найдены subvolume'ы:"
printf '   - %s\n' "${EXISTING[@]}"

# ---------- Монтируем каждый subvolume ----------
MOUNTED=()
SKIPPED=()

for sv in "${SUBVOLS[@]}"; do
    # Проверяем, что subvolume существует на диске
    if ! printf '%s\n' "${EXISTING[@]}" | grep -qx "$sv"; then
        echo ">> ПРОПУСК: subvolume '$sv' отсутствует на $DEVICE."
        SKIPPED+=("$sv")
        continue
    fi

    TARGET="$MOUNT_ROOT/$sv"

    # Уже смонтирован?
    if mountpoint -q "$TARGET"; then
        echo ">> УЖЕ СМОНТИРОВАН: $TARGET — пропускаем."
        MOUNTED+=("$TARGET (уже был смонтирован)")
        continue
    fi

    # Создаём целевую папку
    mkdir -p "$TARGET"

    echo ">> Монтируем $sv -> $TARGET"
    mount -o "subvol=$sv,noatime" "$DEVICE" "$TARGET"

    MOUNTED+=("$TARGET")
done

# ---------- Итог ----------
echo
echo "=========================================================="
echo " Готово."
echo "=========================================================="
if [[ ${#MOUNTED[@]} -gt 0 ]]; then
    echo "Смонтировано:"
    printf '   %s\n' "${MOUNTED[@]}"
fi
if [[ ${#SKIPPED[@]} -gt 0 ]]; then
    echo "Пропущено (нет на диске):"
    printf '   %s\n' "${SKIPPED[@]}"
fi
echo
echo "Текущий статус:"
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT "$DEVICE" || true