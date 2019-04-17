//
//  Mute.swift
//  Mute Me
//
//  Created by Alexandr Promakh on 24/12/2018.
//  Copyright © 2018 Pixel Point. All rights reserved.
//

import Cocoa
import AMCoreAudio

@objc public enum MuteState : Int {
    case all // All devices muted
    case partially // Some devices muted, some not
    case none // All devices not muted
}

class DeviceInfo : NSObject {
    @objc public var name: String
    @objc public var muted: Bool
    
    init(name: String, muted: Bool) {
        self.name = name;
        self.muted = muted;
    }
}

class Mute: NSObject {
    static let defaultChannel = kAudioObjectPropertyElementMaster;
    static let defaultDirection = Direction.recording;
    static let notificationCenter = AMCoreAudio.NotificationCenter.defaultCenter;
    static let instance = Mute();
    static var savedVolumeByDeviceId: [AudioDeviceID: Float] = [:];
    
    static var lastMuteState: MuteState = MuteState.none;
    static var changeCallback: (MuteState) -> Void = { state in };
    static var devicesMuteChangeCallback: ([DeviceInfo]) -> Void = { muted in }
    
    @objc static public func preformInitialization(changeCallback: @escaping (MuteState) -> Void) {
        self.changeCallback = changeCallback;
        
        lastMuteState = getMuteOfAllInputDevices()
        self.changeCallback(lastMuteState);
        
        notificationCenter.subscribe(instance, eventType: AudioHardwareEvent.self)
        notificationCenter.subscribe(instance, eventType: AudioDeviceEvent.self)
    }
    
    @objc static public func deinitialize() {
        notificationCenter.unsubscribe(instance, eventType: AudioHardwareEvent.self)
        notificationCenter.unsubscribe(instance, eventType: AudioDeviceEvent.self)
    }
    
    @objc static public func subscribeToDevicesMutedChange(callback: @escaping ([DeviceInfo]) -> Void) {
        self.devicesMuteChangeCallback = callback;
        publishDevicesMuteChange();
    }
    
    @objc public static func setMuteToAllInputDevices(shouldMute: Bool) {
        setMuteToDevices(devices: AudioDevice.allInputDevices(), shouldMute: shouldMute)
    }
    
    private static func setMuteToDevices(devices: [AudioDevice], shouldMute: Bool) {
        for device in devices {
            setMuteToDevice(device, shouldMute: shouldMute);
        }
    }
    
    private static func setMuteToDevice(_ device: AudioDevice, shouldMute: Bool) {
        let canMute = device.canMute(channel: defaultChannel, direction: Direction.recording)
        let canVolume = device.canSetVolume(channel: defaultChannel, direction: Direction.recording)
        let volume = device.volume(channel: defaultChannel, direction: defaultDirection);
        
        if (canMute) {
            device.setMute(shouldMute, channel: defaultChannel, direction: Direction.recording)
        }
        
        if (canVolume ) {
            if (shouldMute && volume != 0) {
                savedVolumeByDeviceId[device.id] = volume;
                device.setVolume(0, channel: defaultChannel, direction: Direction.recording)
            } else if (!shouldMute && volume == 0) {
                let restoredVolume = savedVolumeByDeviceId[device.id] ?? 1;
                device.setVolume(restoredVolume, channel: defaultChannel, direction: Direction.recording)
            }
        }
    }
    
    @objc public static func getMuteOfAllInputDevices() -> MuteState {
        let devices = AudioDevice.allInputDevices();
        let devicesCount = devices.count;
        
        var mutedDevicesCount = 0;
        
        for device in devices {
            if (getMuteOfDevice(device)) {
                mutedDevicesCount += 1;
            }
        }
        
        if (mutedDevicesCount == devicesCount) {
            return MuteState.all;
        } else if (mutedDevicesCount == 0) {
            return MuteState.none;
        }
        return MuteState.partially;
    }
    
    private static func getMuteOfDevice(_ device: AudioDevice) -> Bool {
        let isMuted = device.isMuted(channel: defaultChannel, direction: defaultDirection) ?? false;
        let volume = device.volume(channel: defaultChannel, direction: defaultDirection);
        
        return isMuted || volume == 0;
    }
    
    @objc public static func toggleMuteOfAllInputDevices() {
        setMuteToAllInputDevices(shouldMute: !shouldAllInputDevicesBeMuted());
    }
    
    public static func shouldAllInputDevicesBeMuted() -> Bool {
        let currentState = getMuteOfAllInputDevices();
        return currentState == MuteState.none ? false : true;
    }
}

extension Mute : EventSubscriber {
    func eventReceiver(_ event: Event) {
        switch event {
        case let event as AudioHardwareEvent:
            switch event {
            case .deviceListChanged(let addedDevices, _):
                Mute.publishDevicesMuteChange()
                
                if (Mute.shouldAllInputDevicesBeMuted()) {
                    Mute.setMuteToDevices(devices: addedDevices, shouldMute: true)
                }
            default:
                ()
            }
        case let event as AudioDeviceEvent:
            switch event {
            case .muteDidChange(_, _, _),
                 .volumeDidChange(_, _, _):
                Mute.publishDevicesMuteChange()
                
                let muteState = Mute.getMuteOfAllInputDevices();
                if (muteState != Mute.lastMuteState) {
                    Mute.lastMuteState = muteState;
                    Mute.changeCallback(muteState);
                }
            default:
                ()
            }
        default:
            ()
        }
    }
    
    private static func publishDevicesMuteChange() {
        let devices = AudioDevice.allInputDevices();
        let infos = devices.map { DeviceInfo(name: $0.name, muted: Mute.getMuteOfDevice($0)) }
        
        self.devicesMuteChangeCallback(infos)
    }
}
