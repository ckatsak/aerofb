#!/bin/bash
#
# ckatsak, Thu Nov 13 05:51:21 AM EET 2025
# ckatsak, Sun Jun  7 06:28:24 PM EEST 2026
#
# Based on:
# - <https://github.com/cslab-ntua/fbpml-systor22/blob/main/scripts/build_rootfs_multi.sh>
# - <https://github.com/cslab-ntua/fbpml-systor22/blob/main/benches/video_processing/scripts/build_rootfs_multi.sh>
#
# Required Environment:
#   $BENCH          The name of the benchmark (e.g., 'helloworld')
#   $TAG            The tag to use when downloading OCI images (e.g., '0.0.3')
# Optional Environment:
#   $DEBUG          Create "debug-mode" rootfs (default: `false`)
#   $WHOSE          User to `chown` the rootfs image (default: `$USER`)
#   $ROOTFS_IMG     Path to new rootfs image (default: `$SCRIPT_DIR/$BENCH.ext`)
#   $ROOTFS_TMP_MP  Path to temporary mountpoint (default: `$(mktemp -d)`)

set -euxo pipefail

SCRIPT_DIR="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"

# The Linux distro of the base image of each `$BENCH` (see README.md).
declare -A -r BASE_IMG=(
	['chameleon']='alpine'
	['cnn_serving']='debian'
	['helloworld']='alpine'
	['image_processing']='alpine'
	['json_serdes']='alpine'
	['lr_serving']='alpine'
	['lr_training']='alpine'
	['matmul']='alpine'
	['pyaes']='alpine'
	['rnn_serving']='debian'
	['video_processing']='debian'
)
# The `$BASE_IMG` of the current `$BENCH` (i.e., "${BASE_IMG[$BENCH]}").
DISTRO="${BASE_IMG[$BENCH]}"
# Path to the service definition file for each `$DISTRO`, on host.
declare -A -r SVC_FILE=(
	['alpine']="${SCRIPT_DIR}/openrc-fbpml.sh"
	['debian']="${SCRIPT_DIR}/fbpml.service"
)
# Path where the service definition file for each `$DISTRO` should end up on
# the new rootfs.
declare -A -r SVC_TARGET=(
	['alpine']='/etc/init.d/fbpml'
	['debian']='/etc/systemd/system/fbpml.service'
)
# Path to the script that populates uVM's rootfs for each `$DISTRO`.
declare -A -r POPULATE_SCRIPT=(
	['alpine']="${SCRIPT_DIR}/populate_alpine.sh"
	['debian']="${SCRIPT_DIR}/populate_debian.sh"
)

OCI_IMAGE_REF="ghcr.io/aero-project-eu/aerofb-${BENCH}:${TAG}"
: "${WHOSE:=$USER}"

# Debug mode?
: "${DEBUG:=false}"
# If in "debug mode", append '-debug' to name of new rootfs.
ROOTFS_SUFFIX=''
if [ "$DEBUG" = true ]; then ROOTFS_SUFFIX='-debug'; fi

# Path to new rootfs ext4 image (on host).
: "${ROOTFS_IMG:=${SCRIPT_DIR}/${BENCH}-flask${ROOTFS_SUFFIX}.ext4}"
# Path to temporary mountpoint of rootfs image (on host).
: "${ROOTFS_TMP_MP:=$(mktemp -d)}"
# Path to uvm rootfs mountpoint inside the container's rootfs.
UVM_ROOTFS_MP='/rootfs'

[ "$EUID" -ne 0 ] \
	&& echo 'ERROR: Mounting the image requires root privileges' && exit 1

if [[ "$(uname -m)" == 'aarch64' && "$ROOTFS_IMG" == *'cnn_serving'* ]]; then
	dd if=/dev/zero of="$ROOTFS_IMG" bs=2M count=$((4096-1024))  # 6 GiB
else
	dd if=/dev/zero of="$ROOTFS_IMG" bs=2M count=1024  # 2 GiB
fi
/sbin/mkfs.ext4 "$ROOTFS_IMG"

mkdir -vp "$ROOTFS_TMP_MP"
mount -v "$ROOTFS_IMG" "$ROOTFS_TMP_MP"

docker run --rm \
	--hostname "${BENCH//_/-}-uvm" \
	--volume "${PWD}/server_flask.py":/bench/server_flask.py \
	--volume "${PWD}/ptpsync.py":/bench/ptpsync.py \
	--volume "${SCRIPT_DIR}/overlay-init":/sbin/overlay-init \
	--volume "${SVC_FILE[$DISTRO]}":"${SVC_TARGET[$DISTRO]}" \
	--volume "${POPULATE_SCRIPT[$DISTRO]}":/populate.sh \
	--volume "$ROOTFS_TMP_MP":"$UVM_ROOTFS_MP" \
	--env "UVM_ROOTFS=$UVM_ROOTFS_MP" \
	--env "DEBUG=$DEBUG" \
	"$OCI_IMAGE_REF" \
	/populate.sh

umount -v "$ROOTFS_TMP_MP" && rmdir -v "$ROOTFS_TMP_MP"
chown -v "$WHOSE" "$ROOTFS_IMG"

