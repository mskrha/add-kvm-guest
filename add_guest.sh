#! /bin/bash

ISO_BASE='/srv/iso/'
IMAGES=($(ls -1 ${ISO_BASE}))
CPU_TOTAL=4

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
virsh domid ${name} >/dev/null 2>/dev/null
if [ ${?} -eq 0 ]; then
	echo "Guest with name ${name} alredy exists"
	exit
fi

echo -n 'RAM (MB) (default 512 MB): '; read ram
if [ "${ram}" == '' ]; then ram=512; fi
if [ $(echo "${ram}" | sed 's/[0-9]*//g' | wc -c) -ne 1 ]; then
	echo 'Invalid input (must contain only numbers)'
	exit
fi
if [ ${ram} -lt 64 -o ${ram} -gt 4096 ]; then
	echo 'RAM must be in range 64MB to 4096MB'
	exit
fi

echo -n 'CPUs (default 1): '; read cpu
if [ "${cpu}" == '' ]; then cpu=1; fi
if [ $(echo "${cpu}" | sed 's/[0-9]*//g' | wc -c) -ne 1 ]; then
	echo 'Invalid input (must contain only numbers)'
	exit
fi
if [ ${cpu} -lt 1 -o ${cpu} -gt ${CPU_TOTAL} ]; then
	echo "CPUs must be in range 1 to ${CPU_TOTAL}"
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

echo
echo -n 'Storage size (GB) (default 2 GB): '
read size
if [ "${size}" == '' ]; then size=2; fi
if [ $(echo "${size}" | sed 's/[0-9]*//g' | wc -c) -ne 1 ]; then
	echo 'Invalid input (must contain only numbers)'
	exit
fi
if [ ${size} -lt 1 -o ${size} -gt 512 ]; then
	echo 'Storage size must be in range 1 GB to 512 GB'
	exit
fi

ports=$(grep vnc /etc/libvirt/qemu/*.xml 2>/dev/null)
if [ ${?} -ne 0 ]; then
	vnc=5900
else
	used=$(echo "${ports}" | sed 's/.*port=.\([0-9]\+\).*/\1/' | sort -n)
	for vnc in {5900..5999}; do
		echo "${used}" | grep ^${vnc}$ >/dev/null 2>/dev/null
		if [ ${?} -eq 1 ]; then break; fi
	done
fi

cat <<- EOF

	==============================
	Name: ${name}

	Memory:    ${ram} MB
	CPU cores: ${cpu}
	Storage:   ${dev} (${size} GB)

	Installation ISO: ${IMAGES[${img}]}

	VNC port: ${vnc}
	==============================

EOF

echo -n 'Deploy? [Y/n]'; read -n 1 -s q
echo
if [ ${q:-Y} == 'n' ]; then exit; fi
echo

lvcreate -L "${size}g" -n ${lv} ${vg} || exit

virt-install \
	--virt-type=kvm \
	--name ${name} \
	--memory ${ram} \
	--vcpus ${cpu} \
	--cpu host-model-only \
	--cdrom "${iso}" \
	--disk path=${dev},device=disk,bus=virtio \
	--network bridge=lan,model=virtio \
	--graphics vnc,listen=10.10.10.200,port=${vnc} \
	--noautoconsole \
	--noreboot
