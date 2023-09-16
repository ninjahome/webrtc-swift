//
//  Util.swift
//  bsip
//
//  Created by wesley on 2023/8/19.
//

import Foundation
import UIKit
import AVFAudio

let NotifySceneBecomeActive = NSNotification.Name(rawValue:"scene_become_active")
let NotifySceneDidEnterBackground = NSNotification.Name(rawValue:"scene_did_enter_background")

extension UIViewController {
        
        @objc func dismissKeyboard() {
                view.endEditing(true)
        }
        
        func hideKeyboardWhenTappedAround() { DispatchQueue.main.async {
                let tap = UITapGestureRecognizer(target: self, action: #selector(UIViewController.dismissKeyboard))
                tap.cancelsTouchesInView = false
                self.view.addGestureRecognizer(tap)
        }}
}
public extension UnsafePointer {
        
        func copy(capacity: Int) -> UnsafePointer {
                
                let mutablePointer = UnsafeMutablePointer<Pointee>.allocate(capacity: capacity)
                mutablePointer.initialize(from: self, count:capacity)
                return UnsafePointer(mutablePointer)
                
        }
        
}

public func audioBufferToNSData(PCMBuffer: AVAudioPCMBuffer) -> Data {
        
        let audioBuffer = PCMBuffer.audioBufferList.pointee.mBuffers
        return   Data.init(bytes: audioBuffer.mData!, count: Int(audioBuffer.mDataByteSize))
        
}


public func toPCMBuffer(data: NSData) -> AVAudioPCMBuffer {
        let audioFormat = AVAudioFormat(commonFormat: AVAudioCommonFormat.pcmFormatInt16 , sampleRate: 48000.0, channels: 1, interleaved: true)  // given NSData audio format
        let PCMBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat!, frameCapacity: UInt32(data.length) / audioFormat!.streamDescription.pointee.mBytesPerFrame )
        PCMBuffer!.frameLength = PCMBuffer!.frameCapacity
        let channels = UnsafeBufferPointer(start: PCMBuffer?.int16ChannelData, count: Int(PCMBuffer!.format.channelCount))
        data.getBytes(UnsafeMutableRawPointer(channels[0]) , length: data.length)
        return PCMBuffer!
}
