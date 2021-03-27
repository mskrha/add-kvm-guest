## add-kvm-guest

### Description
Simple script used to deploy new guests on the KVM hypervisor.

It is designed primary for Debian guests, but can be used with standard ISO installers.

### Usage
```shell
add-kvm-guest
```

### Example
```shell
KVM guest installer, version 0.3

Select type of installation:
        0: Debian with preseed (default)
        1: Custom ISO

Available Debian versions:
         8: Jessie
         9: Stretch
        10: Buster (default)


Name: testvm
RAM (MB) (default 512 MB): 2048
CPUs (default 1): 2

Storage size (GB) (default 2 GB): 

==============================
Name: testvm

Memory:    2048 MB
CPU cores: 2
Storage:   /dev/ssd/testvm-root (2 GB)

Network bridge: lan

Installation type: Debian with preseed (http://127.0.0.1/preseed/buster-kvm)
Debian version:    Buster (10)

VNC port: 5907
==============================

Deploy? [Y/n]

  Logical volume "testvm-root" created.

Starting install...
Retrieving file linux...
Retrieving file initrd.gz...
Creating domain...
Domain installation still in progress. You can reconnect to the console to complete the installation process.
```
