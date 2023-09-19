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

extension AVAudioPCMBuffer {
    func data() -> Data {
        let channelCount = 1  // given PCMBuffer channel count is 1
        let channels = UnsafeBufferPointer(start: self.floatChannelData, count: channelCount)
        let ch0Data = NSData(bytes: channels[0], length:Int(self.frameCapacity * self.format.streamDescription.pointee.mBytesPerFrame))
        return ch0Data as Data
    }
}

extension Data {
    init(pcmBuffer: AVAudioPCMBuffer, time: AVAudioTime) {
        let audioBuffer = pcmBuffer.audioBufferList.pointee.mBuffers
        self.init(bytes: audioBuffer.mData!, count: Int(audioBuffer.mDataByteSize))
    }

    func makePCMBuffer(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let streamDesc = format.streamDescription.pointee
        let frameCapacity = UInt32(count) / streamDesc.mBytesPerFrame
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity) else { return nil }

        buffer.frameLength = buffer.frameCapacity
        let audioBuffer = buffer.audioBufferList.pointee.mBuffers

        withUnsafeBytes { (bufferPointer) in
            guard let addr = bufferPointer.baseAddress else { return }
            audioBuffer.mData?.copyMemory(from: addr, byteCount: Int(audioBuffer.mDataByteSize))
        }

        return buffer
    }
}


public class OpusEncoder {
        private let framesPerPacket: AVAudioFrameCount
        private let converter: AVAudioConverter
        
        public init?(inputFormat: AVAudioFormat, frameDurationSec: Double = 0.02, bitRate: Int = 64000) {
                
                self.framesPerPacket = AVAudioFrameCount(48000 * frameDurationSec)
                
                print("------>>> frame per packet \(framesPerPacket)")
                var outputDescription = AudioStreamBasicDescription(mSampleRate: 48000,
                                                                    mFormatID: kAudioFormatOpus,
                                                                    mFormatFlags: 0,
                                                                    mBytesPerPacket: 0,
                                                                    mFramesPerPacket: framesPerPacket,
                                                                    mBytesPerFrame: 0,
                                                                    mChannelsPerFrame: inputFormat.channelCount,
                                                                    mBitsPerChannel: 0,
                                                                    mReserved: 0)
                
                guard let outputFormat = AVAudioFormat(streamDescription: &outputDescription) else{
                        return nil
                }
                guard let c = AVAudioConverter(from: inputFormat, to: outputFormat) else{
                        return nil
                }
                self.converter = c
                converter.bitRate = bitRate
        }
        
        public func encode(from pcm: AVAudioPCMBuffer) throws -> Data {
                //TODO::
                //                if pcm.frameLength != framesPerPacket { throw NSError(domain: "Frames must be \(framesPerPacket) now is \(pcm.frameLength)", code: -1) }
                let compressed = AVAudioCompressedBuffer(format: converter.outputFormat, packetCapacity: 1, maximumPacketSize: 9600)
                
                var error: NSError?
                converter.convert(to: compressed, error: &error) { (_: AVAudioPacketCount,
                                                                    outStatus: UnsafeMutablePointer<AVAudioConverterInputStatus>) in
                        outStatus.pointee = .haveData
                        print("------>>> pcm frame length \(pcm.frameLength)")
                        return pcm
                }
                
                if let error { throw error }
                let data = Data(bytes: compressed.data, count: Int(compressed.byteLength))
                return data
        }
}

public class OpusDecoder {
        private let framesPerPacket: AVAudioFrameCount
        private let converter: AVAudioConverter
        
        public init?(outputFormat: AVAudioFormat, frameDurationSec: Double = 0.02) {
                self.framesPerPacket = AVAudioFrameCount(48000 * frameDurationSec)
                var inputDescription = AudioStreamBasicDescription(mSampleRate: 48000,
                                                                   mFormatID: kAudioFormatOpus,
                                                                   mFormatFlags: 0,
                                                                   mBytesPerPacket: 0,
                                                                   mFramesPerPacket: framesPerPacket,
                                                                   mBytesPerFrame: 0,
                                                                   mChannelsPerFrame: outputFormat.channelCount,
                                                                   mBitsPerChannel: 0,
                                                                   mReserved: 0)
                guard let inputFormat = AVAudioFormat(streamDescription: &inputDescription) else{
                        return nil
                }
                guard let c = AVAudioConverter(from: inputFormat, to: outputFormat) else{
                        return nil
                }
                self.converter = c
        }
        
        
        public func decode(from data: Data) throws -> AVAudioPCMBuffer {
                let compressed = AVAudioCompressedBuffer(format: converter.inputFormat, packetCapacity: 1, maximumPacketSize: data.count)
                _ = data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
                        memcpy(compressed.data, ptr.baseAddress!, data.count)
                }
                compressed.packetDescriptions?.pointee = AudioStreamPacketDescription(mStartOffset: 0,
                                                                                      mVariableFramesInPacket: 0,
                                                                                      mDataByteSize: UInt32(data.count))
                compressed.packetCount = 1
                compressed.byteLength = UInt32(data.count)
                let pcm = AVAudioPCMBuffer(pcmFormat: converter.outputFormat, frameCapacity: framesPerPacket)!
                var error: NSError?
                converter.convert(to: pcm, error: &error) { (_: AVAudioPacketCount, outStatus:
                                                                UnsafeMutablePointer<AVAudioConverterInputStatus>) in
                        outStatus.pointee = .haveData
                        return compressed
                }
                if let error { throw error }
                print("------>>> 转换后的pcm \(pcm.frameLength)")
                return pcm
        }
}

