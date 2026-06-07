#!/sbin/openrc-run
#
# ckatsak, Thu Nov 13 05:51:21 AM EET 2025

name=$RC_SVCNAME
description="snaplace-fbpml agent"
supervisor="supervise-daemon"
command="/usr/local/bin/gunicorn"
command_args="-b 0.0.0.0:80 -w 1 'server_flask:app'"
directory="/bench"
command_user="root:root"
pidfile="/run/$RC_SVCNAME.pid"
output_log="/var/log/$RC_SVCNAME.stdout"
error_log="/var/log/$RC_SVCNAME.stderr"

depend() {
	#need net
	# NOTE(ckatsak): `after` merely starts `fbpml` service after `net` has
	# started, whereas `need` would make sure `net` has been correctly started
	# before starting `fbpml`.  For now, let's go with `after` for speed, and
	# hope for the best; it's probably unlikely, but it may worth to fallback
	# to `need` if random networking issues occur inside the guest.
	after net
}

