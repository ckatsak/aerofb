#
# ckatsak, Wed Nov 12 03:48:29 AM EET 2025
#

%_debug:
	TAG=$(TAG) BENCH=$(@:_debug=) DEBUG=true ./build_rootfs.sh

%:
	TAG=$(TAG) BENCH=$@ ./build_rootfs.sh

