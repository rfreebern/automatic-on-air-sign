// mic-helper.swift — prints "1" if any microphone/input device on this Mac
// is being actively captured right now, "0" otherwise. This is the signal
// call apps (Teams, Slack huddles, Zoom...) produce even with the camera
// off, and it needs no special permissions.
//
// OPTIONAL build (only if Xcode Command Line Tools are already installed —
// no administrator access needed):
//   mkdir -p ~/bin
//   swiftc -O mic-helper.swift -o ~/bin/wled-mic-helper
// If the helper is not built, the watcher scripts fall back to camera +
// UDP-socket detection on their own.
//
// Compile check / manual test:
//   ~/bin/wled-mic-helper                        # prints 0 when idle
//   (start a QuickTime audio recording in another window, then run it again —
//    it should print 1 while the recording is live)

import CoreAudio
import Foundation

func propAddress(_ selector: AudioObjectPropertySelector,
                 _ scope: AudioObjectPropertyScope) -> AudioObjectPropertyAddress {
    AudioObjectPropertyAddress(mSelector: selector,
                               mScope: scope,
                               mElement: kAudioObjectPropertyElementMain)
}

// All AudioDeviceIDs on the system that have at least one input stream
// (i.e. microphones — this excludes pure output devices like speakers,
// whose "running" state would otherwise trigger whenever any audio plays).
func inputDeviceIDs() -> [AudioDeviceID] {
    let sysObject = AudioObjectID(kAudioObjectSystemObject)
    var devAddr = propAddress(kAudioHardwarePropertyDevices, kAudioObjectPropertyScopeGlobal)
    var size: UInt32 = 0
    guard AudioObjectGetPropertyDataSize(sysObject, &devAddr, 0, nil, &size) == noErr, size > 0 else {
        return []
    }
    var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.stride)
    var used = size
    guard AudioObjectGetPropertyData(sysObject, &devAddr, 0, nil, &used, &ids) == noErr else {
        return []
    }
    return ids.filter { id in
        var streamAddr = propAddress(kAudioDevicePropertyStreams, kAudioObjectPropertyScopeInput)
        var streamSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &streamAddr, 0, nil, &streamSize) == noErr else {
            return false
        }
        return streamSize >= UInt32(MemoryLayout<AudioStreamID>.stride)
    }
}

// True if some process (any process, any user) currently has the device open
// for capture. Same API family that camera/mic indicator apps use.
func isRunningSomewhere(_ id: AudioDeviceID) -> Bool {
    var addr = propAddress(kAudioDevicePropertyDeviceIsRunningSomewhere, kAudioObjectPropertyScopeGlobal)
    var running: UInt32 = 0
    var size = UInt32(MemoryLayout<UInt32>.stride)
    guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &running) == noErr else {
        return false
    }
    return running != 0
}

let inUse = inputDeviceIDs().contains(where: isRunningSomewhere)
print(inUse ? "1" : "0")
exit(0)