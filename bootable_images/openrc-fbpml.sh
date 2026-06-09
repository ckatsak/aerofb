#!/sbin/openrc-run
#
# ckatsak, Thu Nov 13 05:51:21 AM EET 2025
# ckatsak, Sun Jun  7 06:28:24 PM EEST 2026

name=$RC_SVCNAME
description="snaplace-fbpml agent"
supervisor="supervise-daemon"
command="/usr/local/bin/gunicorn"
command_args="-b 0.0.0.0:8000 -w 1 -t 0 'server_flask:app'"
directory="/bench"
command_user="root:root"
pidfile="/run/$RC_SVCNAME.pid"

# Tell supervise-daemon to redirect stdout and stderr to the console:
supervise_daemon_args="--stdout /dev/ttyS0 --stderr /dev/ttyS0"

depend() {
	#need net
	# NOTE(ckatsak): `after` merely starts `fbpml` service after `net` has
	# started, whereas `need` would make sure `net` has been correctly started
	# before starting `fbpml`.  For now, let's go with `after` for speed, and
	# hope for the best; it's probably unlikely, but it may worth to fallback
	# to `need` if random networking issues occur inside the guest.
	after net
}

