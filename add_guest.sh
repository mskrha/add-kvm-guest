#! /bin/bash

ISO_BASE='/var/tmp/iso/'
IMAGES=($(ls -1 ${ISO_BASE}))
STORAGE_SIZE='2g'

echo 'KVM guest installer, version 0.1'

echo
echo 'Available installation ISOs:'
for k in ${!IMAGES[@]}; do echo "${k}: ${IMAGES[${k}]}"; done
echo -n 'Select install ISO: '; read img
if [ "x${img}" == 'x' ]; then
	echo 'No installation ISO chosen'
	exit
fi
if [ $(echo "${img}" | sed 's/[0-9]*//g' | wc -c) -ne 1 ]; then
	echo 'Invalid input (must contain only numbers)'
	exit
fi
if [ ${img} -lt 0 -o ${img} -ge ${#IMAGES[@]} ]; then
	echo 'Index out of range'
	exit
fi
iso="${ISO_BASE}${IMAGES[${img}]}"

echo
echo -n 'Name:     '; read name
if [ "x${name}" == 'x' ]; then
	echo 'Guest name must not be empty'
	exit
fi
if [ $(echo "${name}" | sed 's/[a-zA-Z0-9_-]*//g' | wc -c) -ne 1 ]; then
	echo 'Invalid input (must contain only a-z A-Z 0-9 _ -)'
	exit
fi
if [ $(echo ${name} | wc -c) -gt 65 ]; then
	echo 'Guest name must have maximum 64 chars'
	exit
fi

echo -n 'RAM (MB): '; read ram
if [ $(echo "${ram}" | sed 's/[0-9]*//g' | wc -c) -ne 1 ]; then
	echo 'Invalid input (must contain only numbers)'
	exit
fi
if [ ${ram} -lt 64 -o ${ram} -gt 4096 ]; then
	echo 'RAM must be in range 64MB to 4096MB'
	exit
fi

echo -n 'CPUs:     '; read cpu
if [ $(echo "${cpu}" | sed 's/[0-9]*//g' | wc -c) -ne 1 ]; then
	echo 'Invalid input (must contain only numbers)'
	exit
fi
if [ ${cpu} -lt 1 -o ${cpu} -gt 4 ]; then
	echo 'CPUs must be in range 1 to 4'
	exit
fi

echo
echo 'Storage: 0: SSD (default)'
echo '         1: HDD'
read stor
if [ "${stor}" == '' ]; then stor=0; fi
lv="${name}-root"
case ${stor} in
0)
	vg='ssd'
	;;
1)
	vg='hdd'
	;;
*)
	echo 'Index out of range'
	exit
	;;
esac
dev="/dev/${vg}/${lv}"

if [ -L ${dev} ]; then
	echo "Device ${dev} alredy exists"
	exit
fi

echo -n 'VNC port: '; read vnc
if [ "x${vnc}" == 'x' ]; then
	echo 'VPN port must not be empty'
	exit
fi
if [ $(echo "${vnc}" | sed 's/[0-9]*//g' | wc -c) -ne 1 ]; then
	echo 'Invalid input (must contain only numbers)'
	exit
fi
if [ ${vnc} -lt 5900 -o ${vnc} -gt 5999 ]; then
	echo 'VNC port must be in range 5900 to 5999'
	exit
fi

cat <<- EOF

	==============================
	Name:     ${name}
	RAM:      ${ram} MB
	CPUs:     ${cpu}

	ISO:      ${iso}
	Disk:     ${dev}

	VNC port: ${vnc}
	==============================

EOF

echo -n 'Deploy? [Y/n]'; read -n 1 -s q
echo
if [ ${q} == 'n' ]; then exit; fi
echo

lvcreate -L ${STORAGE_SIZE} -n ${lv} ${vg} || exit

virt-install \
	--virt-type=kvm \
	--name ${name} \
	--memory ${ram} \
	--vcpus ${cpu} \
	--cpu host-model-only \
	--cdrom "${iso}" \
	--disk path=${dev},device=disk,bus=virtio \
	--network bridge=lan,model=virtio \
	--graphics vnc,listen=0.0.0.0,port=${vnc} \
	--noautoconsole \
	--noreboot
