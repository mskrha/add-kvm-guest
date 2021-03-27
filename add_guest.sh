#! /bin/bash

ISO_BASE='/srv/iso/'
IMAGES=($(ls -1 ${ISO_BASE}))
CPU_TOTAL=4
DOMAIN='testing.local'

DEBIAN_PRESEED_PATH='http://10.10.2.80/preseed'
DEBIAN_DISTS=(
	[8]='jessie'
	[9]='stretch'
	[10]='buster'
)
DEBIAN_NAMES=(
	[8]='Jessie'
	[9]='Stretch'
	[10]='Buster'
)
DEBIAN_VERSIONS=(${!DEBIAN_DISTS[@]})

echo 'KVM guest installer, version 0.2'

echo

echo 'Select type of installation:'
echo -e '\t0: Debian with preseed (default)'
echo -e '\t1: Custom ISO'
read inst
if [ "${inst}" == '' ]; then inst=0; fi
case ${inst} in
0)
	echo 'Available Debian versions:'
	for d in ${!DEBIAN_NAMES[@]}; do
		if [ ${d} -lt 10 ]
			then dd=" ${d}"
		else
			dd=${d}
		fi
		if [ ${d} -eq ${DEBIAN_VERSIONS[-1]} ]; then
			mm=' (default)'
		fi
		echo -e "\t${dd}: ${DEBIAN_NAMES[${d}]}${mm}"
	done
	read deb
	if [ "${deb}" == '' ]; then deb=${DEBIAN_VERSIONS[-1]}; fi
	if [ $(echo "${deb}" | sed 's/[0-9]*//g' | wc -c) -ne 1 ]; then
		echo 'Invalid input (must contain only numbers)'
		exit
	fi
	if [ ${deb} -lt ${DEBIAN_VERSIONS[0]} -o ${deb} -gt ${DEBIAN_VERSIONS[-1]} ]; then
		echo 'Wrong Debian version!'
		exit
	fi
	msg1='Debian with preseed'
	msg2="Debian version:    ${DEBIAN_NAMES[${deb}]} (${deb})"
	;;
1)
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
	msg1='Custom ISO'
	msg2="Installation ISO:  ${IMAGES[${img}]}"
	;;
*)
	echo 'Wrong installation type!'
	exit
	;;
esac

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

	Installation type: ${msg1}
	${msg2}

	VNC port: ${vnc}
	==============================

EOF

echo -n 'Deploy? [Y/n]'; read -n 1 -s q
echo
if [ ${q:-Y} == 'n' ]; then exit; fi
echo

lvcreate -L "${size}g" -n ${lv} ${vg} || exit

case ${inst} in
0)
	args="--location http://ftp.cz.debian.org/debian/dists/${DEBIAN_DISTS[${deb}]}/main/installer-amd64/ --extra-args auto=true --extra-args url=${DEBIAN_PRESEED_PATH}/${DEBIAN_DISTS[${deb}]}-kvm --extra-args hostname=${name} --extra-args domain=${DOMAIN}"
	;;
1)
	args="--cdrom ${iso}"
	;;
*)
	echo 'BUG BUG BUG'
	exit 1
	;;
esac

virt-install \
	--virt-type=kvm \
	--name ${name} \
	--memory ${ram} \
	--vcpus ${cpu} \
	--cpu host-model-only \
	--disk path=${dev},device=disk,bus=virtio \
	--network bridge=lan,model=virtio \
	--graphics vnc,listen=10.10.10.200,port=${vnc} \
	--noautoconsole \
	--noreboot \
	${args}
