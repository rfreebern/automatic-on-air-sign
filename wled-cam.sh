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
OFF_DELAY=5                 # seconds signals must stay idle before turning sign off
CAM_GREP='VDCAssistant|VCA[0-9]'
CALL_APPS_GREP='zoom|teams|slack'   # process-name filter for the UDP call heuristic (clear to disable)
MIC_HELPER="$HOME/bin/wled-mic-helper"   # optional compiled helper, see README

cam_in_use() {
    /usr/sbin/lsof -n 2>/dev/null | /usr/bin/grep -iqE "$CAM_GREP"
}

mic_in_use() {
    [ -x "$MIC_HELPER" ] && "$MIC_HELPER" 2>/dev/null | /usr/bin/grep -q '^1$'
}

call_media_active() {
    [ -n "$CALL_APPS_GREP" ] || return 1
    /usr/sbin/lsof -n -i UDP +c0 2>/dev/null | /usr/bin/grep -iqE "$CALL_APPS_GREP"
}

on_air() {   # any signal counts: mic, camera, or a call app with live UDP media
    mic_in_use && return 0
    cam_in_use && return 0
    call_media_active
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
    if on_air; then
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