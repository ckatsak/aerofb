#!/bin/bash
#
# ckatsak, Thu Nov 13 05:51:21 AM EET 2025
# ckatsak, Sun Jun  7 06:28:24 PM EEST 2026
#
# Based on
# <https://github.com/cslab-ntua/fbpml-systor22/blob/main/benches/video_processing/scripts/populate_multi.sh>

set -euxo pipefail

# Exit if provided either a non-mountpoint or '/'.  Maybe useless?
[ "$UVM_ROOTFS" != '/' ] && mountpoint -q "$UVM_ROOTFS" || exit 42

export DEBIAN_FRONTEND=noninteractive
apt-get update && apt-get install -y --no-install-recommends \
	systemd systemd-sysv udev procps \
	iproute2 iputils-ping ca-certificates curl tar

## NOTE(ckatsak): these symlinks are required only for `rnn_serving`
#ln -vs /opt/bitnami/python/bin/pip /usr/local/bin/ || true
#pip install --no-cache-dir Flask gunicorn
#ln -vs /opt/bitnami/python/bin/gunicorn /usr/local/bin/ || true
## NOTE(ckatsak): these symlinks are required only for `cnn_serving`
#ln -vs /home/ubuntu/python3-venv/bin/pip /usr/local/bin/ || true
#ln -vs /home/ubuntu/python3-venv/bin/gunicorn /usr/local/bin/ || true
##
#if [[ -x '/opt/bitnami/python/bin/pip' ]]; then
#	ln -vs /opt/bitnami/python/bin/pip /usr/local/bin/ || true
#elif [[ -x '/home/ubuntu/python3-venv/bin/pip' ]]; then
#	ln -vs /home/ubuntu/python3-venv/bin/pip /usr/local/bin/ || true
#fi
pip install --no-cache-dir Flask gunicorn
#pip --no-cache-dir install -i https://test.pypi.org/simple/ ptpsync
if [[ -x '/opt/bitnami/python/bin/gunicorn' ]]; then
	# required only for `rnn_serving`/aarch64
	ln -vst /usr/local/bin/ /opt/bitnami/python/bin/gunicorn || true
elif [[ -x '/home/ubuntu/python3-venv/bin/gunicorn' ]]; then
	# required only for `cnn_serving`/aarch64
	ln -vst /usr/local/bin/ /home/ubuntu/python3-venv/bin/gunicorn || true
fi


##
## Configure targets & services to load at boot
##
# Default target
ln -vsf /lib/systemd/system/multi-user.target \
	/etc/systemd/system/default.target
# Volatile journal to reduce churn/size
mkdir -vp /etc/systemd && cat >/etc/systemd/journald.conf <<'EOF'
[Journal]
Storage=volatile
Compress=yes
SystemMaxUse=30M
EOF
# serial getty on ttyS0 (firecracker console)
mkdir -vp /etc/systemd/system/getty.target.wants
ln -vsf /lib/systemd/system/serial-getty@.service \
	/etc/systemd/system/getty.target.wants/serial-getty@ttyS0.service

# Install `fbpml.service`
ln -vsf /etc/systemd/system/fbpml.service \
	/etc/systemd/system/multi-user.target.wants/fbpml.service

# Clean machine-id for new uVMs to get fresh, unique ones
truncate -s0 /etc/machine-id
ln -vsf /etc/machine-id /var/lib/dbus/machine-id || true

if [ "$DEBUG" = true ]; then
	# Disable root password
	passwd -d root

	# Install & configure SSH server
	apt-get install -y --no-install-recommends openssh-server
	ln -vsf /lib/systemd/system/ssh.service \
		/etc/systemd/system/multi-user.target.wants/ssh.service
	{
		echo 'PermitRootLogin yes'
		echo 'PasswordAuthentication yes'
		echo 'PermitEmptyPasswords yes'
	} >>/etc/ssh/sshd_config
else
	# Configure root password
	echo 'root:root' | chpasswd
fi

# Clean apt's cache & remnants, and also system docs (few MiBs)
apt-get clean && rm -rf \
	/var/lib/apt/lists/* \
	/var/cache/apt/archives/*.deb \
	/usr/share/doc/* \
	/usr/share/info/* \
	/usr/share/man/*

# Populate `/`
for d in bin etc lib lib64 root sbin usr var opt bench; do
	if [ ! -d "/$d" ]; then
		echo ''
		echo "WARN[aerofb]: Directory \"/$d\" does not exist; skipping it"
		echo ''
		continue
	fi
	tar -c "/$d" | tar -x -C "/$UVM_ROOTFS"
done
for d in dev proc run sys var/log var/tmp tmp; do
	mkdir -vp "$UVM_ROOTFS/$d"
done
chmod -v 1777 "$UVM_ROOTFS/tmp" "$UVM_ROOTFS/var/tmp"
for d in mnt overlay rom; do
	mkdir -vp "$UVM_ROOTFS/$d"  # for overlay-init
done
# NOTE(ckatsak): cnn_serving/aarch64 currently has python installed under /home:
if [[ "$(uname -m)" == 'aarch64' && "$(hostname)" == *'cnn-serving'* ]]; then
	rm -rf '/home/ubuntu/examples/'
	tar -c '/home' | tar -x -C "/$UVM_ROOTFS"
fi

chown -v root:root "$UVM_ROOTFS/sbin/overlay-init"
chmod -v 0755      "$UVM_ROOTFS/sbin/overlay-init"

chown -v root:root "$UVM_ROOTFS/etc/systemd/system/fbpml.service"
chmod -v 0644      "$UVM_ROOTFS/etc/systemd/system/fbpml.service"

chown -v root:root "$UVM_ROOTFS/bench/server_flask.py"
chmod -v 0755      "$UVM_ROOTFS/bench/server_flask.py"

# Populate `/etc/resolv.conf`.  According to nfsroot.txt, we may just symlink.
ln -vsf /proc/net/pnp "$UVM_ROOTFS/etc/resolv.conf"

