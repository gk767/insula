import Cocoa
import Combine
import CoreAudio

final class MicMuteManager: ObservableObject {

    @Published private(set) var isMuted = false

    private var defaultListener: AudioObjectPropertyListenerBlock?
    private var muteListener: AudioObjectPropertyListenerBlock?
    private var volumeListener: AudioObjectPropertyListenerBlock?
    private var watchedDevice: AudioDeviceID = 0
    private var savedVolume: Float?

    init() {
        let stored = UserDefaults.standard.object(forKey: Self.savedVolumeKey) as? Float
        savedVolume = stored
        refresh()
        listenDefault()
    }

    deinit {
        unlistenDefault()
        unlistenDevice()
    }

    func toggle() {
        setMuted(!isMuted)
    }

    func setMuted(_ muted: Bool) {
        guard let device = defaultInput() else { return }
        if setMuteProperty(muted, on: device) {
            if !muted { clearSavedVolume() }
            refresh()
            return
        }
        if muted {
            if savedVolume == nil {
                savedVolume = volume(on: device) ?? 0.8
                persistSavedVolume()
            }
            setVolume(0, on: device)
        } else {
            setVolume(savedVolume ?? 0.8, on: device)
            clearSavedVolume()
        }
        refresh()
    }

    private func refresh() {
        let device = defaultInput()
        let muted: Bool
        if let device {
            if let hardware = muteProperty(on: device) {
                muted = hardware
            } else if let level = volume(on: device) {
                muted = level < 0.001
            } else {
                muted = false
            }
        } else {
            muted = false
        }
        if isMuted != muted {
            isMuted = muted
        }
        if let device, device != watchedDevice {
            unlistenDevice()
            listenDevice(device)
        }
    }

    private func listenDefault() {
        let system = AudioObjectID(kAudioObjectSystemObject)
        defaultListener = { [weak self] _, _ in
            self?.refresh()
        }
        if let defaultListener {
            addListener(
                system,
                kAudioHardwarePropertyDefaultInputDevice,
                kAudioObjectPropertyScopeGlobal,
                defaultListener
            )
        }
        if let device = defaultInput() {
            listenDevice(device)
        }
    }

    private func listenDevice(_ device: AudioDeviceID) {
        watchedDevice = device
        muteListener = { [weak self] _, _ in
            self?.refresh()
        }
        volumeListener = { [weak self] _, _ in
            self?.refresh()
        }
        if let muteListener {
            addListener(
                device,
                kAudioDevicePropertyMute,
                kAudioDevicePropertyScopeInput,
                muteListener
            )
        }
        if let volumeListener {
            addListener(
                device,
                kAudioDevicePropertyVolumeScalar,
                kAudioDevicePropertyScopeInput,
                volumeListener
            )
        }
    }

    private func unlistenDefault() {
        if let defaultListener {
            removeListener(
                AudioObjectID(kAudioObjectSystemObject),
                kAudioHardwarePropertyDefaultInputDevice,
                kAudioObjectPropertyScopeGlobal,
                defaultListener
            )
        }
        defaultListener = nil
    }

    private func unlistenDevice() {
        if watchedDevice != 0 {
            if let muteListener {
                removeListener(
                    watchedDevice,
                    kAudioDevicePropertyMute,
                    kAudioDevicePropertyScopeInput,
                    muteListener
                )
            }
            if let volumeListener {
                removeListener(
                    watchedDevice,
                    kAudioDevicePropertyVolumeScalar,
                    kAudioDevicePropertyScopeInput,
                    volumeListener
                )
            }
        }
        muteListener = nil
        volumeListener = nil
        watchedDevice = 0
    }

    private func addListener(
        _ object: AudioObjectID,
        _ selector: AudioObjectPropertySelector,
        _ scope: AudioObjectPropertyScope,
        _ block: @escaping AudioObjectPropertyListenerBlock
    ) {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectAddPropertyListenerBlock(object, &address, .main, block)
    }

    private func removeListener(
        _ object: AudioObjectID,
        _ selector: AudioObjectPropertySelector,
        _ scope: AudioObjectPropertyScope,
        _ block: @escaping AudioObjectPropertyListenerBlock
    ) {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectRemovePropertyListenerBlock(object, &address, .main, block)
    }

    private func defaultInput() -> AudioDeviceID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var device = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &device
        )
        return status == noErr && device != 0 ? device : nil
    }

    private func hasProperty(
        _ device: AudioDeviceID,
        _ selector: AudioObjectPropertySelector,
        element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain
    ) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: element
        )
        return AudioObjectHasProperty(device, &address)
    }

    private func muteProperty(on device: AudioDeviceID) -> Bool? {
        let element = muteElement(on: device)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: element
        )
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr else {
            return nil
        }
        return value != 0
    }

    private func setMuteProperty(_ muted: Bool, on device: AudioDeviceID) -> Bool {
        guard hasProperty(device, kAudioDevicePropertyMute) || hasProperty(device, kAudioDevicePropertyMute, element: 1) else {
            return false
        }
        let element = muteElement(on: device)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: element
        )
        var value: UInt32 = muted ? 1 : 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        return AudioObjectSetPropertyData(device, &address, 0, nil, size, &value) == noErr
    }

    private func muteElement(on device: AudioDeviceID) -> AudioObjectPropertyElement {
        if hasProperty(device, kAudioDevicePropertyMute) {
            return kAudioObjectPropertyElementMain
        }
        return 1
    }

    private func volume(on device: AudioDeviceID) -> Float? {
        let element = volumeElement(on: device)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: element
        )
        var value: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr else {
            return nil
        }
        return value
    }

    private func setVolume(_ value: Float, on device: AudioDeviceID) {
        let element = volumeElement(on: device)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: element
        )
        var scalar = Float32(max(0, min(1, value)))
        var size = UInt32(MemoryLayout<Float32>.size)
        _ = AudioObjectSetPropertyData(device, &address, 0, nil, size, &scalar)
        if element == kAudioObjectPropertyElementMain {
            setVolumeOnChannels(scalar, on: device)
        }
    }

    private func setVolumeOnChannels(_ value: Float32, on device: AudioDeviceID) {
        for channel: AudioObjectPropertyElement in [1, 2] {
            guard hasProperty(device, kAudioDevicePropertyVolumeScalar, element: channel) else { continue }
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: channel
            )
            var scalar = value
            var size = UInt32(MemoryLayout<Float32>.size)
            _ = AudioObjectSetPropertyData(device, &address, 0, nil, size, &scalar)
        }
    }

    private func volumeElement(on device: AudioDeviceID) -> AudioObjectPropertyElement {
        if hasProperty(device, kAudioDevicePropertyVolumeScalar) {
            return kAudioObjectPropertyElementMain
        }
        return 1
    }

    private func persistSavedVolume() {
        if let savedVolume {
            UserDefaults.standard.set(savedVolume, forKey: Self.savedVolumeKey)
        }
    }

    private func clearSavedVolume() {
        savedVolume = nil
        UserDefaults.standard.removeObject(forKey: Self.savedVolumeKey)
    }

    private static let savedVolumeKey = "island.mic.savedVolume"
}
