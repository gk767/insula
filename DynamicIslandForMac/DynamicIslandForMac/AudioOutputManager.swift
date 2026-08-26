import Cocoa
import Combine
import CoreAudio
import IOBluetooth

enum AudioOutputRoute: Equatable {
    case mac
    case headphones
    case speakers
    case car
}

final class AudioOutputManager: ObservableObject {

    @Published private(set) var headphonesAvailable = false
    @Published private(set) var speakersAvailable = false
    @Published private(set) var carAvailable = false
    @Published private(set) var route: AudioOutputRoute = .mac

    private var defaultListener: AudioObjectPropertyListenerBlock?
    private var devicesListener: AudioObjectPropertyListenerBlock?
    private var sourceListener: AudioObjectPropertyListenerBlock?
    private var sourceDevice: AudioDeviceID = 0

    init() {
        refresh()
        listen()
    }

    deinit {
        unlisten()
    }

    func select(_ target: AudioOutputRoute) {
        switch target {
        case .mac:
            guard let builtIn = builtInOutput() else { return }
            setDefaultOutput(builtIn)
            if let speakers = speakerSource(on: builtIn) {
                setDataSource(speakers, on: builtIn)
            }
        case .headphones:
            if let builtIn = builtInOutput(), let jack = headphoneSource(on: builtIn) {
                setDefaultOutput(builtIn)
                setDataSource(jack, on: builtIn)
            } else if let device = firstDevice(of: .headphones) {
                setDefaultOutput(device)
            }
        case .speakers:
            if let device = firstDevice(of: .speakers) {
                setDefaultOutput(device)
            }
        case .car:
            if let device = firstDevice(of: .car) {
                setDefaultOutput(device)
            }
        }
        refresh()
    }

    private func refresh() {
        let current = defaultOutput()
        let builtIn = builtInOutput()
        let jack = builtIn.flatMap { headphoneSource(on: $0) } != nil

        let nextHeadphones = jack || firstDevice(of: .headphones) != nil
        let nextSpeakers = firstDevice(of: .speakers) != nil
        let nextCar = firstDevice(of: .car) != nil

        let nextRoute: AudioOutputRoute
        if let current {
            if let builtIn, current == builtIn {
                nextRoute = isHeadphoneSourceCurrent(on: builtIn) ? .headphones : .mac
            } else {
                nextRoute = classify(current) ?? .mac
            }
        } else {
            nextRoute = .mac
        }

        if headphonesAvailable != nextHeadphones { headphonesAvailable = nextHeadphones }
        if speakersAvailable != nextSpeakers { speakersAvailable = nextSpeakers }
        if carAvailable != nextCar { carAvailable = nextCar }
        if route != nextRoute { route = nextRoute }

        if let builtIn, builtIn != sourceDevice {
            unlistenSource()
            listenSource(builtIn)
        }
    }

    private func listen() {
        let system = AudioObjectID(kAudioObjectSystemObject)
        defaultListener = { [weak self] _, _ in
            self?.refresh()
        }
        devicesListener = { [weak self] _, _ in
            self?.refresh()
        }
        if let defaultListener {
            addListener(
                system,
                kAudioHardwarePropertyDefaultOutputDevice,
                kAudioObjectPropertyScopeGlobal,
                defaultListener
            )
        }
        if let devicesListener {
            addListener(
                system,
                kAudioHardwarePropertyDevices,
                kAudioObjectPropertyScopeGlobal,
                devicesListener
            )
        }
        if let builtIn = builtInOutput() {
            listenSource(builtIn)
        }
    }

    private func listenSource(_ device: AudioDeviceID) {
        sourceDevice = device
        sourceListener = { [weak self] _, _ in
            self?.refresh()
        }
        if let sourceListener {
            addListener(
                device,
                kAudioDevicePropertyDataSource,
                kAudioDevicePropertyScopeOutput,
                sourceListener
            )
        }
    }

    private func unlistenSource() {
        if sourceDevice != 0, let sourceListener {
            removeListener(
                sourceDevice,
                kAudioDevicePropertyDataSource,
                kAudioDevicePropertyScopeOutput,
                sourceListener
            )
        }
        sourceListener = nil
        sourceDevice = 0
    }

    private func unlisten() {
        let system = AudioObjectID(kAudioObjectSystemObject)
        if let defaultListener {
            removeListener(
                system,
                kAudioHardwarePropertyDefaultOutputDevice,
                kAudioObjectPropertyScopeGlobal,
                defaultListener
            )
        }
        if let devicesListener {
            removeListener(
                system,
                kAudioHardwarePropertyDevices,
                kAudioObjectPropertyScopeGlobal,
                devicesListener
            )
        }
        unlistenSource()
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

    private func outputDevices() -> [AudioDeviceID] {
        allDevices().filter { hasOutput($0) && !isAggregate($0) }
    }

    private func allDevices() -> [AudioDeviceID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let system = AudioObjectID(kAudioObjectSystemObject)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr, size > 0 else {
            return []
        }
        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        var devices = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &devices) == noErr else {
            return []
        }
        return devices
    }

    private func defaultOutput() -> AudioDeviceID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
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

    private func setDefaultOutput(_ device: AudioDeviceID) {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value = device
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            size,
            &value
        )
    }

    private func builtInOutput() -> AudioDeviceID? {
        outputDevices().first { transport($0) == kAudioDeviceTransportTypeBuiltIn }
    }

    private func firstDevice(of route: AudioOutputRoute) -> AudioDeviceID? {
        outputDevices().first { classify($0) == route }
    }

    private func classify(_ device: AudioDeviceID) -> AudioOutputRoute? {
        let kind = transport(device)
        if kind == kAudioDeviceTransportTypeBuiltIn { return nil }
        if kind == kAudioDeviceTransportTypeHDMI { return nil }
        if kind == kAudioDeviceTransportTypeDisplayPort { return nil }
        if kind == kAudioDeviceTransportTypeVirtual { return nil }

        let title = name(device)
        let lower = title.lowercased()
        if isMonitorName(lower) { return nil }
        if looksLikeCar(lower) { return .car }
        if let bluetooth = bluetoothRoute(matching: title) { return bluetooth }
        if looksLikeHeadphones(lower) { return .headphones }
        if looksLikeSpeakers(lower) { return .speakers }
        if kind == kAudioDeviceTransportTypeAirPlay { return .speakers }
        if kind == kAudioDeviceTransportTypeBluetooth
            || kind == kAudioDeviceTransportTypeBluetoothLE
            || kind == kAudioDeviceTransportTypeUSB {
            return .headphones
        }
        return nil
    }

    private func isMonitorName(_ title: String) -> Bool {
        title.contains("display")
            || title.contains("monitor")
            || title.contains("hdmi")
            || title.contains("apple tv")
            || title.contains("телевизор")
    }

    private func looksLikeCar(_ title: String) -> Bool {
        let keys = [
            "mbux", "mercedes", "benz", "bmw", "mini cooper",
            "audi", "volkswagen", "porsche", "tesla",
            "toyota", "lexus", "honda", "volvo", "hyundai", "kia",
            "mazda", "subaru", "nissan", "skoda", "ford sync",
            "carplay", "android auto", "car audio", "uconnect", "idrive"
        ]
        return keys.contains { title.contains($0) }
    }

    private func looksLikeHeadphones(_ title: String) -> Bool {
        title.contains("headphone")
            || title.contains("headset")
            || title.contains("airpods")
            || title.contains("beats")
            || title.contains("наушник")
            || title.contains("гарнитур")
    }

    private func looksLikeSpeakers(_ title: String) -> Bool {
        title.contains("speaker")
            || title.contains("homepod")
            || title.contains("soundbar")
            || title.contains("колонк")
            || title.contains("boom")
            || title.contains("jbl")
            || title.contains("marshall")
            || title.contains("sonos")
            || title.contains("bose")
    }

    /// Bluetooth Class of Device: Mercedes MBUX usually reports as car audio.
    private func bluetoothRoute(matching title: String) -> AudioOutputRoute? {
        let needle = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty,
              let paired = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else {
            return nil
        }
        let match = paired.first { device in
            guard device.isConnected() else { return false }
            let n = (device.name ?? "").lowercased()
            guard !n.isEmpty else { return false }
            return n == needle || needle.contains(n) || n.contains(needle)
        }
        guard let match else { return nil }
        if looksLikeCar((match.name ?? "").lowercased()) { return .car }
        guard Int(match.deviceClassMajor) == kBluetoothDeviceClassMajorAudio else { return nil }
        switch Int(match.deviceClassMinor) {
        case kBluetoothDeviceClassMinorAudioCar:
            return .car
        case kBluetoothDeviceClassMinorAudioLoudspeaker,
             kBluetoothDeviceClassMinorAudioPortable,
             kBluetoothDeviceClassMinorAudioHiFi:
            return .speakers
        case kBluetoothDeviceClassMinorAudioHeadset,
             kBluetoothDeviceClassMinorAudioHandsFree,
             kBluetoothDeviceClassMinorAudioHeadphones:
            return .headphones
        default:
            return nil
        }
    }

    private func isAggregate(_ device: AudioDeviceID) -> Bool {
        transport(device) == kAudioDeviceTransportTypeAggregate
    }

    private func hasOutput(_ device: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        return AudioObjectGetPropertyDataSize(device, &address, 0, nil, &size) == noErr && size > 0
    }

    private func transport(_ device: AudioDeviceID) -> UInt32 {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr else {
            return 0
        }
        return value
    }

    private func name(_ device: AudioDeviceID) -> String {
        stringValue(device, kAudioObjectPropertyName, kAudioObjectPropertyScopeGlobal)
    }

    private func stringValue(
        _ object: AudioObjectID,
        _ selector: AudioObjectPropertySelector,
        _ scope: AudioObjectPropertyScope
    ) -> String {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<CFString?>.size)
        guard AudioObjectGetPropertyData(object, &address, 0, nil, &size, &value) == noErr,
              let value else {
            return ""
        }
        return value.takeUnretainedValue() as String
    }

    private func dataSources(on device: AudioDeviceID) -> [UInt32] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDataSources,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(device, &address, 0, nil, &size) == noErr, size > 0 else {
            return []
        }
        let count = Int(size) / MemoryLayout<UInt32>.size
        var sources = [UInt32](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &sources) == noErr else {
            return []
        }
        return sources
    }

    private func currentDataSource(on device: AudioDeviceID) -> UInt32? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDataSource,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var source: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &source) == noErr else {
            return nil
        }
        return source
    }

    private func setDataSource(_ source: UInt32, on device: AudioDeviceID) {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDataSource,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var value = source
        var size = UInt32(MemoryLayout<UInt32>.size)
        AudioObjectSetPropertyData(device, &address, 0, nil, size, &value)
    }

    private func dataSourceName(_ source: UInt32, on device: AudioDeviceID) -> String {
        var sourceID = source
        var cfName: Unmanaged<CFString>?
        var translation = AudioValueTranslation(
            mInputData: &sourceID,
            mInputDataSize: UInt32(MemoryLayout<UInt32>.size),
            mOutputData: &cfName,
            mOutputDataSize: UInt32(MemoryLayout<CFString?>.size)
        )
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDataSourceNameForIDCFString,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var size = UInt32(MemoryLayout<AudioValueTranslation>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &translation) == noErr,
              let cfName else {
            return fourCC(source)
        }
        return cfName.takeUnretainedValue() as String
    }

    private func headphoneSource(on device: AudioDeviceID) -> UInt32? {
        dataSources(on: device).first { isHeadphoneSource($0, on: device) }
    }

    private func speakerSource(on device: AudioDeviceID) -> UInt32? {
        dataSources(on: device).first { isSpeakerSource($0, on: device) }
    }

    private func isHeadphoneSourceCurrent(on device: AudioDeviceID) -> Bool {
        guard let current = currentDataSource(on: device) else { return false }
        return isHeadphoneSource(current, on: device)
    }

    private func isHeadphoneSource(_ source: UInt32, on device: AudioDeviceID) -> Bool {
        let title = dataSourceName(source, on: device).lowercased()
        if title.contains("headphone") || title.contains("наушник") { return true }
        let code = fourCC(source).lowercased()
        return code == "hdpn" || code == "hphn"
    }

    private func isSpeakerSource(_ source: UInt32, on device: AudioDeviceID) -> Bool {
        let title = dataSourceName(source, on: device).lowercased()
        if title.contains("headphone") || title.contains("наушник") { return false }
        if title.contains("speaker") || title.contains("динамик") || title.contains("internal") {
            return true
        }
        let code = fourCC(source).lowercased()
        return code == "spkr" || code == "ispk"
    }

    private func fourCC(_ value: UInt32) -> String {
        let bytes = [
            UInt8((value >> 24) & 0xff),
            UInt8((value >> 16) & 0xff),
            UInt8((value >> 8) & 0xff),
            UInt8(value & 0xff)
        ]
        return String(bytes: bytes, encoding: .macOSRoman) ?? ""
    }
}
