#! /bin/bash

echo -n 'Name:     '; read name
echo -n 'RAM (MB): '; read ram
echo -n 'CPUs:     '; read cpu
echo
echo -n 'VG/LV: '; read lv
echo
echo -n 'VNC port: '; read vnc
echo
echo 'ISO:   '
images=($(ls -1 /var/tmp/iso/))
for k in ${!images[@]}; do echo "${k}: ${images[${k}]}"; done
read image
if [ ${image} -ge ${#images[@]} ]; then echo 'Index out of range'; exit; fi
iso="/var/tmp/iso/${images[${image}]}"
cat <<- EOF

	==============================
	Name:     ${name}
	RAM:      ${ram} MB
	CPUs:     ${cpu}

	ISO:      ${iso}
	Disk:     /dev/${lv}

	VNC port: ${vnc}
	==============================

EOF
echo -n 'Deploy? [Y/n]'; read -n 1 -s q
echo
if [ ${q} == 'n' ]; then exit; fi
echo
virt-install \
	--virt-type=kvm \
	--name ${name} \
	--memory ${ram} \
	--vcpus ${cpu} \
	--cpu host-model-only \
	--cdrom "${iso}" \
	--disk path=/dev/${lv},device=disk,bus=virtio \
	--network bridge=lan,model=virtio \
	--graphics vnc,listen=0.0.0.0,port=${vnc} \
	--noautoconsole \
	--noreboot
