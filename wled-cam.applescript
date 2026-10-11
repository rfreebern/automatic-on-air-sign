-- wled-cam.applescript
-- Turns a WLED sign on when the webcam is in use, off when it isn't.
--
-- HOW TO USE:
--   1. Open "Script Editor" (in /Applications/Utilities).
--   2. Paste this whole file in.
--   3. Set WLED_IP below to your WLED device's IP (find it in the WLED app
--      or at http://<ip> — the sign's web UI shows it in Settings > WiFi).
--   4. File > Save, choose File Format: "Application", and tick "Stay Open".
--      Save it somewhere in your home folder (e.g. ~/Applications/WLED Cam.app).
--   5. Double-click the app to run it. Quit it any time from the Dock
--      (right-click the app icon > Quit) — it has no windows, only a Dock icon.
--
-- No administrator access is required at any point. It only uses tools that
-- ship with macOS: osascript, lsof, grep and curl.

-- ---------- CONFIGURATION ----------

-- IP address or hostname of the WLED controller
property WLED_IP : "192.168.1.50"

-- Seconds between webcam checks
property POLL_SECONDS : 3

-- Seconds to wait before turning the sign OFF after the camera frees up.
-- Stops the sign flickering during brief camera hiccups. Set to 0 to disable.
property OFF_DELAY_SECONDS : 5

-- Optional: force a brightness when switching on (0-255). Set to -1 to
-- leave whatever brightness the WLED device was last set to.
property ON_BRIGHTNESS : -1

-- What lsof looks for. VDCAssistant is the macOS camera daemon; it and the
-- client app only hold these "VCA*" files open while the camera is actually
-- streaming. If your Mac ever fails to detect the camera, see the TEST
-- section in README.md to calibrate this.
property CAM_GREP : "VDCAssistant|VCA[0-9]"

-- ---------- MAIN LOOP ----------

-- "idle" is called every time the returned number of seconds elapses.
on idle
	set camOn to my cameraInUse()
	set signOn to my wledIsOn()

	if camOn and not signOn then
		my wledSetPower(true)
	else if (not camOn) and signOn then
		-- Only actually turn the sign off if the camera has stayed idle
		-- for OFF_DELAY_SECONDS in a row.
		if OFF_DELAY_SECONDS is 0 then
			my wledSetPower(false)
		else
			if my cameraIdleFor(OFF_DELAY_SECONDS) then
				my wledSetPower(false)
			end if
		end if
	end if

	return POLL_SECONDS
end idle

-- ---------- CAMERA DETECTION ----------

-- True if any process on the Mac is streaming from a webcam right now.
-- macOS's lsof is setgid, so it can see other users' (and root's) open
-- files without sudo — no admin needed.
on cameraInUse()
	try
		set hits to do shell script "/usr/sbin/lsof -n 2>/dev/null | /usr/bin/grep -iE " & quoted form of CAM_GREP & " | /usr/bin/head -n 1"
		return (hits is not "")
	on error
		return false
	end try
end cameraInUse

-- True if the camera has been idle continuously for N seconds.
on cameraIdleFor(seconds)
	set start to current date
	repeat
		if my cameraInUse() then return false
		if ((current date) - start) ≥ seconds then return true
		delay 1
	end repeat
end cameraIdleFor

-- ---------- WLED CONTROL ----------

on wledIsOn()
	try
		set stateJson to do shell script "/usr/bin/curl -s -m 5 http://" & WLED_IP & "/json/state"
		return stateJson contains "\"on\":true"
	on error
		return false
	end try
end wledIsOn

on wledSetPower(powerOn)
	if powerOn and ON_BRIGHTNESS > -1 then
		set payload to "{\"on\":true,\"bri\":" & ON_BRIGHTNESS & "}"
	else if powerOn then
		set payload to "{\"on\":true}"
	else
		set payload to "{\"on\":false}"
	end if
	try
		do shell script "/usr/bin/curl -s -m 5 -X POST -H 'Content-Type: application/json' -d " & quoted form of payload & " http://" & WLED_IP & "/json/state"
	on error errMsg
		log "Could not reach WLED at http://" & WLED_IP & " — " & errMsg
	end try
end wledSetPower