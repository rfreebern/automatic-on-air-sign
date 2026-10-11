# WLED Webcam Sign

Runs on your Mac (userspace, no administrator access needed) and turns a
LAN-connected WLED sign **on whenever your webcam is in use** and **off when
it isn't**.

Two interchangeable implementations are included — pick one:

| File | How it runs | Good for |
|---|---|---|
| `wled-cam.applescript` | Paste into Script Editor, save as an Application with "Stay Open" ticked | The dead-simple AppleScript route |
| `wled-cam.sh` + `wled.cam.plist` | Background LaunchAgent started at login | "Set and forget" / no Dock icon |

## How it works

- **Webcam detection:** on macOS, `lsof` is setgid, so an ordinary user can
  see *other* processes' open files without `sudo`. While any app is actually
  streaming video, the macOS camera daemon (`VDCAssistant`) and the client
  app hold open files matching `VDCAssistant`/`VCA0..3`; those disappear the
  moment the camera is released. The script polls for that every few seconds
  and toggles the sign only on a state change (with a small delay before
  turning off, so brief camera hiccups don't flicker the sign).
- **WLED control:** plain HTTP — `POST http://<wled-ip>/json/state` with
  `{"on":true}` / `{"on":false}` via `curl`. No libraries, no installs.
- Everything uses only tools that ship with macOS. Nothing is installed,
  nothing needs root, no privacy-permission prompts appear (it only reads
  open-file listings; it never looks *into* the camera stream).

## Setup — AppleScript version

1. Open **Script Editor** (`/Applications/Utilities/Script Editor.app`).
2. Paste in `wled-cam.applescript`.
3. Change `property WLED_IP : "192.168.1.50"` to your WLED device's IP.
   (Optional tweaks: `ON_BRIGHTNESS` forces a brightness when switching on;
   `OFF_DELAY_SECONDS` controls the off-hysteresis.)
4. **File ▸ Save…**, set *File Format* to **Application**, tick **Stay Open**,
   and save to your home folder, e.g. `~/Applications/WLED Cam.app`.
5. Double-click the app. It has no windows — just a Dock icon. Quit it via
   right-click on the Dock icon ▸ Quit. To auto-start at login: System
   Settings ▸ General ▸ Login Items ▸ add the app.

## Setup — shell/LaunchAgent version

```bash
# 1. Put the script in your home dir and make it executable
cp wled-cam.sh ~/wled-cam.sh
chmod +x ~/wled-cam.sh
#    edit WLED_IP at the top of ~/wled-cam.sh

# 2. Point the plist at your username
sed -i '' "s/YOURUSER/$(whoami)/g" wled.cam.plist

# 3. Install the agent
mkdir -p ~/Library/LaunchAgents
cp wled.cam.plist ~/Library/LaunchAgents/wled.cam.plist
launchctl load ~/Library/LaunchAgents/wled.cam.plist

# 4. Check it's running and controlling the sign
tail -f ~/wled-cam.log        # (curl output goes here)
launchctl unload ~/Library/LaunchAgents/wled.cam.plist   # to stop
```

## Verify the camera detection on your Mac (one-time test)

The `lsof` marker is standard on current macOS, but external/USB cameras and
future macOS versions can shift details — calibrate once:

1. Make sure the camera is **not** in use, then run:

   ```bash
   lsof -n | grep -iE 'VDCAssistant|VCA[0-9]' | head -3
   ```

   Expected: **empty output**.

2. Open **Photo Booth** (or FaceTime) so the camera light turns on, then run
   the same command again.

   Expected: several lines, e.g. `VDCAssistant … VCA0` and/or lines from the
   camera app. Note what actually shows up.

3. If nothing appears, look for the camera-related entries yourself:

   ```bash
   lsof -n | grep -iE 'vca|vdc|camera|avfoundation' | head -10
   ```

   and put a matching pattern into the script (`CAM_GREP` in the AppleScript,
   `CAM_GREP=` in the shell script).

4. Test the WLED side directly:

   ```bash
   curl -s http://<wled-ip>/json/state        # should print the current state
   curl -s -X POST -d '{"on":true}'  http://<wled-ip>/json/state
   curl -s -X POST -d '{"on":false}' http://<wled-ip>/json/state
   ```

## Notes & limitations

- **WLED reachability:** the Mac must be able to reach `http://<wled-ip>` on
  your LAN. If the WLED device is sleeping it will ignore requests; the
  script just retries on the next poll, so it self-heals.
- The script reads the WLED's current power state each cycle (via
  `GET /json/state`) rather than trusting its own memory, so manual toggles
  of the sign (web UI, buttons) are corrected on the next poll.
- Detection covers any process using any camera on the Mac (built-in or USB),
  including FaceTime, Zoom, Teams, browser tabs, etc., since all capture goes
  through the system camera stack.
- If the Mac's user account is logged out, both variants stop — that's
  inherent to userspace, no-admin operation.