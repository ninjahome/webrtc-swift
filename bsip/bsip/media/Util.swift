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


func copyAudioBufferBytes(_ audioBuffer: AVAudioPCMBuffer) -> [UInt8] {
        let srcLeft = audioBuffer.floatChannelData![0]
        let bytesPerFrame = audioBuffer.format.streamDescription.pointee.mBytesPerFrame
        let numBytes = Int(bytesPerFrame * audioBuffer.frameLength)
        
        // initialize bytes to 0 (how to avoid?)
        var audioByteArray = [UInt8](repeating: 0, count: numBytes)
        
        // copy data from buffer
        srcLeft.withMemoryRebound(to: UInt8.self, capacity: numBytes) { srcByteData in
                audioByteArray.withUnsafeMutableBufferPointer {
                        $0.baseAddress!.initialize(from: srcByteData, count: numBytes)
                }
        }
        
        return audioByteArray
}

func bytesToAudioBuffer(_ buf: [UInt8]) -> AVAudioPCMBuffer {
        // format assumption! make this part of your protocol?
        let fmt = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 44100, channels: 1, interleaved: true)
        let frameLength = UInt32(buf.count) / fmt!.streamDescription.pointee.mBytesPerFrame
        
        let audioBuffer = AVAudioPCMBuffer(pcmFormat: fmt!, frameCapacity: frameLength)
        audioBuffer!.frameLength = frameLength
        
        let dstLeft = audioBuffer?.floatChannelData![0]
        // for stereo
        // let dstRight = audioBuffer.floatChannelData![1]
        
        buf.withUnsafeBufferPointer {
                let src = UnsafeRawPointer($0.baseAddress!).bindMemory(to: Float.self, capacity: Int(frameLength))
                dstLeft!.initialize(from: src, count: Int(frameLength))
        }
        
        return audioBuffer!
}


func audioBufferToNSData(PCMBuffer: AVAudioPCMBuffer) -> NSData {
        let channelCount = 1  // given PCMBuffer channel count is 1
        let channels = UnsafeBufferPointer(start: PCMBuffer.floatChannelData, count: channelCount)
        let data = NSData(bytes: channels[0], length:Int(PCMBuffer.frameLength * PCMBuffer.format.streamDescription.pointee.mBytesPerFrame))
        
        return data
}

func dataToPCMBuffer(format: AVAudioFormat, data: NSData) -> AVAudioPCMBuffer {
        
        let audioBuffer = AVAudioPCMBuffer(pcmFormat: format,
                                           frameCapacity: UInt32(data.length) / format.streamDescription.pointee.mBytesPerFrame)!

        audioBuffer.frameLength = audioBuffer.frameCapacity
        let channels = UnsafeBufferPointer(start: audioBuffer.floatChannelData, count: Int(audioBuffer.format.channelCount))
        data.getBytes(UnsafeMutableRawPointer(channels[0]) , length: data.length)
        return audioBuffer
}
