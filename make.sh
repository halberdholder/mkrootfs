#!/bin/bash 
set -e

BASE_ROOTFS_SYSTEM=$RK_ROOTFS_SYSTEM
OUTPUT=output
SOURCE_ROOTFS_DIR=${OUTPUT}/${BASE_ROOTFS_SYSTEM}
MOUNTPOINT=${OUTPUT}/tmpfs
ROOTFSIMAGE=${OUTPUT}/rootfs.${RK_ROOTFS_TYPE}

BS=$((1 * 1024 * 1024))	# 1M
BC=4096

function mount_trap()
{
	sudo umount ${MOUNTPOINT} || true
	echo -e "\e[31m MAKE ROOTFS FAILED.\e[0m"
	exit -1
}

function prepare()
{
	if [ ! -f ${BASE_ROOTFS_SYSTEM}.tar.gz ]; then
		echo "the base rootfs system ${BASE_ROOTFS_SYSTEM}.tar.gz doesn't exist"
		exit 1
	fi

	rm -rf $OUTPUT
	mkdir -p $OUTPUT

	tar xvf ${BASE_ROOTFS_SYSTEM}.tar.gz -C $OUTPUT/

	echo " prepare image: $ROOTFSIMAGE"

	echo Making rootfs!

	if [ -e ${ROOTFSIMAGE} ]; then 
		rm ${ROOTFSIMAGE}
	fi
	if [ -e ${MOUNTPOINT} ]; then 
		rm -r ${MOUNTPOINT}
	fi

	# Create directories
	mkdir -p ${MOUNTPOINT}

	dd if=/dev/zero of=${ROOTFSIMAGE} bs=$BS count=$BC

	echo Format rootfs to ext4
	mkfs.ext4 ${ROOTFSIMAGE}

	echo Mount rootfs to ${MOUNTPOINT}
	sudo mount ${ROOTFSIMAGE} ${MOUNTPOINT}
	trap mount_trap ERR

	echo Copy rootfs to ${MOUNTPOINT}
	sudo cp -drfp ${SOURCE_ROOTFS_DIR}/* ${MOUNTPOINT}/

	if [ ! -e ${MOUNTPOINT}/etc/firstboot ]; then
		touch ${MOUNTPOINT}/etc/firstboot
	fi
}

function finish()
{
	USE_SIZE=$(du -s ${MOUNTPOINT} | awk '{print $1}')
	IMG_SIZE=$(($BS * $BC / 1024))

	echo "USE_SIZE=${USE_SIZE}"
	echo "IMG_SIZE=${IMG_SIZE}"

	echo Umount rootfs
	sudo umount ${MOUNTPOINT}

	if [ $USE_SIZE -ge $IMG_SIZE ]; then
		echo "Img size exceeded"
		rm -f $ROOTFSIMAGE
		exit 1
	fi

	echo Rootfs Image: ${ROOTFSIMAGE}

	e2fsck -p -f ${ROOTFSIMAGE}
	resize2fs -M ${ROOTFSIMAGE}
}

for option in ${@}; do
        echo "processing option: $option"
        case $option in
                prepare)
			prepare
                        ;;
		finish)
			finish
                        ;;
                *)
			echo "error option: ${option}"
                        exit 1
                        ;;
        esac
done
