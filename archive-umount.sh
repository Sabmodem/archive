#!/usr/bin/env bash
#
# umount_btrfs.sh — размонтирует все subvolume'ы Btrfs-диска из указанной папки
#
# Использование:
#   sudo ./umount_btrfs.sh <mount_point>
#
# Пример:
#   sudo ./umount_btrfs.sh /mnt/data
#
# Скрипт размонтирует:
#   <mount_point>/@ingress
#   <mount_point>/@archive
#   <mount_point>/@live
#   <mount_point>/@snapshots
#
# Сама папка <mount_point> и подпапки НЕ удаляются.
#

set -euo pipefail

# ---------- Проверки ----------
if [[ $EUID -ne 0 ]]; then
    echo "Ошибка: скрипт должен запускаться от root." >&2
    exit 1
fi

if [[ $# -ne 1 ]]; then
    echo "Использование: $0 <mount_point>" >&2
    echo "Пример: $0 /mnt/data" >&2
    exit 1
fi

MOUNT_ROOT="$1"

if [[ ! -d "$MOUNT_ROOT" ]]; then
    echo "Ошибка: папка '$MOUNT_ROOT' не существует." >&2
    exit 1
fi

# Список subvolume'ов (те же, что монтировали)
SUBVOLS=(@ingress @archive @live @snapshots)

# ---------- Размонтируем ----------
UNMOUNTED=()
NOT_MOUNTED=()
FAILED=()

# Чтобы не плодить дубли, если какой-то subvol был смонтирован раньше,
# размонтируем в обратном порядке (на всякий случай — хотя независимы).
for sv in "${SUBVOLS[@]}"; do
    TARGET="$MOUNT_ROOT/$sv"

    if [[ ! -d "$TARGET" ]]; then
        echo ">> ПРОПУСК: папка '$TARGET' не существует."
        NOT_MOUNTED+=("$TARGET")
        continue
    fi

    if ! mountpoint -q "$TARGET"; then
        echo ">> НЕ СМОНТИРОВАН: $TARGET"
        NOT_MOUNTED+=("$TARGET")
        continue
    fi

    echo ">> Размонтируем $TARGET..."
    if umount "$TARGET"; then
        UNMOUNTED+=("$TARGET")
    else
        echo "!! Не удалось размонтировать $TARGET" >&2
        FAILED+=("$TARGET")
    fi
done

# ---------- Итог ----------
echo
echo "=========================================================="
echo " Готово."
echo "=========================================================="

if [[ ${#UNMOUNTED[@]} -gt 0 ]]; then
    echo "Размонтировано:"
    printf '   %s\n' "${UNMOUNTED[@]}"
fi

if [[ ${#NOT_MOUNTED[@]} -gt 0 ]]; then
    echo "Не были смонтированы (или отсутствуют):"
    printf '   %s\n' "${NOT_MOUNTED[@]}"
fi

if [[ ${#FAILED[@]} -gt 0 ]]; then
    echo "Не удалось размонтировать:" >&2
    printf '   %s\n' "${FAILED[@]}" >&2
    echo
    echo "Подсказка: возможно, папка занята процессом. Проверьте:" >&2
    echo "  lsof +D <path>   или   fuser -vm <path>" >&2
    exit 1
fi

# ---------- Опционально: показать оставшиеся монтирования ----------
if mount | grep -q "$MOUNT_ROOT"; then
    echo
    echo "Внимание: под $MOUNT_ROOT всё ещё есть монтирования:"
    mount | grep "$MOUNT_ROOT" || true
fi

echo
echo "Готово."