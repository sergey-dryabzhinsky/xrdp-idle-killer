#!/bin/bash

export LANG=en_US.UTF-8

# Width of username column in w's output
export PROCPS_USERLEN=32

IDLE=$((1*60*60))       # 60 minutes
GRACE=10                # 10 minutes
TIMEOUT=15s

IDLE_SUBJECT="You have been idle for more than $((IDLE / 60)) minutes."
IDLE_MESSAGE="You will be logged out in $GRACE minutes if no activity is detected."
IDLE_ICON="system-log-out"

LOGOUT_ROOT="mate-session-save --logout-dialog"
LOGOUT_USER="mate-session-save --force-logout"

[ -f /etc/default/xrdp-idle-killer ] && . /etc/default/xrdp-idle-killer

NOTIFY=$((GRACE*60*1000))       # GRACE minutes in milliseconds, for notify-send

declare -gA watched_users
declare -gA idle_time
declare -gA idle_seat

# Log to syslog with tag "XRDP-IDLE-KILLER"
log ()
{
	logger -t "XRDP-IDLE-KILLER" -i -- "$@"
}

# We use the `xprintidle` command, which returns idle
# time in milliseconds. We convert all this to seconds.
parse_idle ()
{
	local user=$1
	local seat=$2

	xidle=$(/usr/bin/sudo -u $user DISPLAY=$seat xprintidle)
	echo $(($xidle / 1000))
}

# Given an idle user and session, notify the user in *that session*
# and go to sleep for the grace period. Then check if the user had
# made any activity in *that session*. If not, kill them all.
grace ()
{
	local user=$1
	local seat=$2

	notify_user $user $seat
	sleep ${GRACE}m

	# Get the new idle time for this session.
	new_idle=$(parse_idle $user $seat)
	if [[ $new_idle -gt $IDLE ]]
	then
		# For root, special considerations. :)
		if [ "$user" = "root" ]; then
			DISPLAY=$seat $LOGOUT_ROOT
		else
			/usr/bin/sudo -u $user DISPLAY=$seat $LOGOUT_USER
		fi

		log "Idle session of $user at $seat has been terminated."
	else
		log "User $user waked up at $seat. Session termination delayed."
	fi
}

# Use `notify-send` for the GUI.
notify_user ()
{
	local user=$1
	local seat=$2

	/usr/bin/sudo -u $user DISPLAY=$seat \
		notify-send --urgency critical --expire-time $NOTIFY --icon "$LOGOUT_ICON" \
		"$IDLE_SUBJECT" "$IDLE_MESSAGE"

	log "Notifying $user at $seat."
}

while sleep $TIMEOUT # Loop indefinitely.
do
	while read uid seat
	do
		user=`id -u $uid -n`
		# If the user has already been recorded as idle, continue.
		[[ -n ${watched_users["$user"]} ]] && continue

		idle=$(parse_idle $user $seat)
		[[ -z ${idle_time["$user"]} ]] && idle_time["$user"]=$idle
		# Store the smallest idle time for each user.
		if [[ $idle -le ${idle_time["$user"]} ]]
		then
			idle_time["$user"]=$idle
			idle_seat["$user"]=$seat
		fi
	done < <(ps alx | grep Xorg | grep xrdp | awk '{print $2,$14}')

#	echo Idle users: ${!watched_users[@]}

	# Loop over the minimum idle time of each user
	for user in "${!idle_time[@]}"
	do
		idle=${idle_time["$user"]}
		seat=${idle_seat["$user"]}
		unset -v idle_seat["$user"]
		unset -v idle_time["$user"]
		# If the user has already been recorded as idle, continue.
		[[ -n ${watched_users["$user"]} ]] && continue
		if [[ $idle -gt $IDLE ]]
		then
			grace $user $seat &
			watched_users["$user"]=$!
#			echo $user has been idle for over "$idle" seconds - kill job: ${watched_users["$user"]}.
		fi
	done

	# Check if kill jobs have ended.
	for user in ${!watched_users[@]}
	do
		if ! kill -0 ${watched_users["$user"]}  2>/dev/null
		then
			unset -v watched_users["$user"]
		fi
	done
done
