#!/bin/sh
#
# ckatsak, Thu Nov 13 05:51:21 AM EET 2025
# ckatsak, Sun Jun  7 06:28:24 PM EEST 2026
#
# Based on
# <https://github.com/cslab-ntua/fbpml-systor22/blob/main/scripts/populate_multi.sh>

set -eu

# Exit if provided either a non-mountpoint or '/'.  Maybe useless?
[ "$UVM_ROOTFS" != '/' ] && mountpoint -q "$UVM_ROOTFS" || exit 42

apk add --no-cache openrc util-linux

pip install --no-cache-dir Flask gunicorn
#pip --no-cache-dir install -i https://test.pypi.org/simple/ ptpsync

# Configure targets & services to load at boot
ln -s agetty /etc/init.d/agetty.ttyS0
echo 'ttyS0' >/etc/securetty
rc-update add agetty.ttyS0 default
rc-update add devfs boot
rc-update add procfs boot
rc-update add sysfs boot
rc-update add hostname boot

rc-update add fbpml boot

if [ "$DEBUG" = true ]; then
	# Disable root password
	echo 'root:' | chpasswd

	# Install & configure SSH server
	apk add --no-cache openssh
	rc-update add sshd default
	{
		echo 'PermitRootLogin yes'
		echo 'PasswordAuthentication yes'
		echo 'PermitEmptyPasswords yes'
	} >>/etc/ssh/sshd_config
else
	# Configure root password
	echo 'root:root' | chpasswd
fi

# Populate `/`
for d in bin etc lib root sbin usr bench; do
	tar -c "/$d" | tar -x -C "$UVM_ROOTFS"
done
for d in dev proc run sys var/log var/tmp tmp; do
	mkdir -vp "$UVM_ROOTFS/$d"
done
chmod -v 1777 "$UVM_ROOTFS/tmp"
for d in mnt overlay rom; do
	mkdir -vp "$UVM_ROOTFS/$d"  # for overlay-init
done

chown -v root:root "$UVM_ROOTFS/sbin/overlay-init"
chmod -v 0755      "$UVM_ROOTFS/sbin/overlay-init"

chown -v root:root "$UVM_ROOTFS/etc/init.d/fbpml"
chmod -v 0755      "$UVM_ROOTFS/etc/init.d/fbpml"

chown -v root:root "$UVM_ROOTFS/bench/server_flask.py"
chmod -v 0755      "$UVM_ROOTFS/bench/server_flask.py"

# Populate `/etc/resolv.conf`.  According to nfsroot.txt, we may just symlink.
ln -vsf /proc/net/pnp "$UVM_ROOTFS/etc/resolv.conf"

