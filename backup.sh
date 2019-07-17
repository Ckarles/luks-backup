#!/usr/bin/env bash

VGNAME="tkp_bk"
VOLUME_LABEL="tkp_bk_all"
VOLUME_PATH="/dev/disk/by-label/${VOLUME_LABEL}"

declare -a parts
parts=(
  "suse_root"
  "suse_boot"
  "EFI"
  "shared_home"
)

declare -A part_mount
part_mount=(
  ["suse_root"]="/"
  ["suse_boot"]="/boot/"
  ["EFI"]="/boot/efi/"
  ["shared_home"]="/mnt/shared_home/"
)

declare -A part_extraopts
part_extraopts=(
  ["shared_home"]="--exclude=steamapps/"
)

# root permissions required
[ "$UID" -eq 0 ] || exec sudo bash "$0" "$@"

if [ ! -d /dev/${VGNAME} ]; then
  echo "Open encrypted volume..."

  if ! /sbin/cryptsetup --verbose open ${VOLUME_PATH} ${VOLUME_LABEL}; then
    echo "Cannot open luks volume ${VOLUME_PATH}" 1>&2
    exit 1
  fi
fi

# necessary sleep to wait for the discovery of the LVs
sleep 1

if [ ! -d /dev/${VGNAME} ]; then
  echo "Cannot find VG. Please mount and decrypt ${VOLUME_LABEL} partition manually." 1>&2
  exit 2
fi

for p in ${!part_mount[@]}; do
  if [ ! -L "/dev/${VGNAME}/${p}" ]; then
    echo "${p} volume does not seem to exists, please create it and retry." 1>&2
    exit 3
  fi
done

mkdir -pv /mnt/backup

for p in ${parts[@]}; do
  m=${part_mount[${p}]}
  x=${part_extraopts[${p}]}
  
  mount -v /dev/${VGNAME}/${p} /mnt/backup${m}
  rsync -aAHXx --delete --no-inc-recursive --info=progress2 ${x} ${m} /mnt/backup${m}

done

umount -Rv /mnt/backup
rmdir -v /mnt/backup

for p in ${parts[@]}; do

  dmsetup -v remove ${VGNAME}-${p}

done

echo "Close encrypted volume..."
/sbin/cryptsetup --verbose close ${VOLUME_LABEL}
