#!/bin/sh
### BEGIN INIT INFO
# Provides:          xrdp-idle-killer
# Required-Start:    $remote_fs $syslog xrdp
# Required-Stop:     $remote_fs $syslog xrdp
# X-Start-Before:    kdm gdm3 xdm lightdm
# X-Stop-After:      kdm gdm3 xdm lightdm
# Default-Start:     2 3 4 5
# Default-Stop:      
# Short-Description: Kill idle xRDP sessions
# Description:       Kill idle X11 + xrdp sessions
### END INIT INFO

set -e

STARTER="/bin/bash"
DAEMON="/usr/local/bin/xrdp-idle-killer"
DEFAULTS="/etc/default/xrdp-idle-killer"
PIDFILE="/var/run/xrdp-iddle-killer.pid"

# Check for daemon presence
[ -x "$DAEMON" ] || exit 0

# Include acpid defaults if available
[ -r "$DEFAULTS" ] && . "$DEFAULTS"

# Get lsb functions
. /lib/lsb/init-functions

case "$1" in
  start)
    log_begin_msg "Starting XrdpIdleKiller service..."
    start-stop-daemon --start --background --quiet --make-pidfile --pidfile=$PIDFILE --exec $STARTER -- "$DAEMON"
    log_end_msg $?
    ;;
  stop)
    log_begin_msg "Stopping XrdpIdleKiller service..."
    start-stop-daemon --stop --quiet --retry=TERM/5/KILL/1 --pidfile=$PIDFILE --exec $STARTER -- "$DAEMON"
    log_end_msg $?
    ;;
  restart)
    $0 stop
    sleep 1
    $0 start
    ;;
  reload|force-reload)
    log_begin_msg "Reloading XrdpIdleKiller service..."
    log_end_msg $?
    ;;
  status)
    status_of_proc "$DAEMON" xrdp-idle-killer
    ;;
  *)
    log_success_msg "Usage: /etc/init.d/xrdp-idle-killer {start|stop|restart|reload|force-reload|status}"
    exit 1
esac
