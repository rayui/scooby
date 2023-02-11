#!/bin/bash
set -e

touch /boot/meta-data
touch /boot/user-data

apt-get install cloud-init -y

cat - > /etc/cloud/templates/sources.list.debian.tmpl <<'EOF'
## template:jinja
## Note, this file is written by cloud-init on first boot of an instance
## modifications made here will not survive a re-bundle.
## if you wish to make changes you can:
## a.) add 'apt_preserve_sources_list: true' to /etc/cloud/cloud.cfg
##     or do the same in user-data
## b.) add sources in /etc/apt/sources.list.d
## c.) make changes to template file /etc/cloud/templates/sources.list.debian.tmpl
###

deb {{mirror}} {{codename}} main contrib non-free rpi
deb-src {{mirror}} {{codename}} main contrib non-free rpi
EOF

cat - > /etc/cloud/cloud.cfg.d/99_fake_cloud.cfg <<'EOF'
# configure cloud-init for NoCloud
datasource_list: [ NoCloud, None ]
datasource:
  NoCloud:
    fs_label: boot
EOF

cat - > /etc/cloud/cloud.cfg.d/99_raspbian.cfg <<'EOF'
system_info:
  default_user:
    name: spike 
    lock_passwd: true 
    groups: [adm,dialout,cdrom,sudo,audio,video,plugdev,games,users,input,netdev,spi,i2c,gpio]
    sudo: ["ALL=(ALL) NOPASSWD: ALL"]
    shell: /bin/bash
  package_mirrors:
    - arches: [default]
      failsafe:
        primary: http://raspbian.raspberrypi.org/raspbian
        security: http://raspbian.raspberrypi.org/raspbian

ssh_authorized_keys:
  - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCuUOzRM1sPenNhmf75aU473eNoH/UGcMfJKITGCXpxayP9dGWyytjpKa1Xuu4TJXHtqqE/dpZSo6TlmoK0pmOR0bt0Knp0YslriNBRL+hRsqYcKat8vSOhUSz0otxBR3eC5x4/7jBBuwLGNM3tyQL/3pGDw9FVntJ1clqRW881F6r7qcan5VOkyviwtYldG0haIV2XoQ7GMB2AJytokj/xrSJBlNEzda4WH9MwpnO8zF2YSoHsdh+qNAzwFvvI2+34CDk3oBM/vzi48dHjVm/a3S6ymCL/zlfMKjrFUgSAqrlz8JNJwp0v43Lf2W1+vEUZAFSDil18VFZS3WkkiMbV8vHYzwVEh2u3PFmcV4IHooam7zNeSL4mGRHIM4F0+9PJ80adQsBH1UGcw+7K926b4WrJWXtolh+g2wDjSmJY/moAGLoiQXtoeBYiw9S7FeNaR+gLYfFgtq0s81C0uCBus3L5a8a4u+oth4D5e1YRHqBFGOmKt1qKwu99xpBFePawf/VFp8s4yEf+koe/oX1hdLUnYHaap/EvX2M0Tb0Y1NMEpfcLwUx1IiGlCdQ7Cu4OA0PVMYartcWi291CigxSC65lkl4iUQejtv9tqKFW+tfA9iITpKSOeyXJbhWpMOTgNygXpMiqNq4s14t+1S3A0NsEyzRei0FE4Cs3Qo5N2w== ray.userinterface@gmail.com
EOF

#add required arguments to kernel
sed -i '$s/$/ cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory/' /boot/cmdline.txt

#disable wifi and bluetooth
sed -i '$s/$/ \ndtoverlay=disable-wifi\n\dtoverlay=disable-bt/' /boot/config.txt

# Disable dhcpcd - it has a conflict with cloud-init network config
systemctl mask dhcpcd
