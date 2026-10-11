#!/bin/bash
# wled-cam.sh — userspace webcam watcher for WLED.
#
# Runs as a plain LaunchAgent (no administrator access needed).
#   1. Set WLED_IP below.
#   2. Copy this file somewhere in your home dir, e.g. ~/wled-cam.sh
#      and make it executable:  chmod +x ~/wled-cam.sh
#   3. Edit wled.cam.plist (in this repo) to point at the path above,
#      then run:
#         mkdir -p ~/Library/LaunchAgents
#         cp wled.cam.plist ~/Library/LaunchAgents/
#         launchctl load ~/Library/LaunchAgents/wled.cam.plist
#   4. It starts at login and runs forever in the background.
#      To stop it:  launchctl unload ~/Library/LaunchAgents/wled.cam.plist

WLED_IP="192.168.1.50"
POLL_SECONDS=3
OFF_DELAY=5                 # seconds camera must stay idle before turning sign off
CAM_GREP='VDCAssistant|VCA[0-9]'

cam_in_use() {
    /usr/sbin/lsof -n 2>/dev/null | /usr/bin/grep -iqE "$CAM_GREP"
}

wled_on() {
    /usr/bin/curl -s -m 5 "http://$WLED_IP/json/state" | /usr/bin/grep -q '"on":true'
}

wled_set() {   # $1 = true|false, $2 = optional payload
    /usr/bin/curl -s -m 5 -X POST -H 'Content-Type: application/json' \
        -d "${2:-{\"on\":$1}}" "http://$WLED_IP/json/state" >/dev/null
}

idle_count=0
while true; do
    if cam_in_use; then
        idle_count=0
        if ! wled_on; then
            wled_set true
        fi
    else
        idle_count=$((idle_count + POLL_SECONDS))
        if wled_on && [ "$idle_count" -ge "$OFF_DELAY" ]; then
            wled_set false
        fi
    fi
    sleep "$POLL_SECONDS"
done