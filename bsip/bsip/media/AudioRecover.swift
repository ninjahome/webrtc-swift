//
//  AudioRecover.swift
//  bsip
//
//  Created by wesley on 2023/9/21.
//

import Foundation

import AVFAudio
import AVFoundation
class AudioRecover:NSObject{
        var audioDecoder:AVAudioConverter!
        var fromFormat:AVAudioFormat!
        var toFormat:AVAudioFormat!
        
        init?(fromFmt: AVAudioFormat!, toFmt: AVAudioFormat!) {
                
                self.fromFormat = fromFmt
                self.toFormat = toFmt
                
                guard let c = AVAudioConverter(from: fromFmt, to: toFmt) else{
                        print("------>>> convert failed")
                        return nil
                }
                self.audioDecoder = c
        }
        
        func recover(data:Data)->AVAudioPCMBuffer?{
                
                guard let bufFromData = data.makePCMBuffer(format: fromFormat) else{
                        print("------->>> makePCMBuffer err")
                        return nil
                }
                let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
                        outStatus.pointee = AVAudioConverterInputStatus.haveData
                        return bufFromData
                }
                
                let targetFrameCapacity = AVAudioFrameCount(toFormat.sampleRate) * bufFromData.frameLength / AVAudioFrameCount(bufFromData.format.sampleRate)
                
                guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: toFormat, frameCapacity: targetFrameCapacity) else{
                        print("------->>> convertedBuffer err")
                        return nil
                }
                
                var error: NSError?
                self.audioDecoder.convert(to: convertedBuffer, error: &error, withInputFrom:inputBlock)
                if let e = error{
                        print("------->>> convert err:", e.localizedDescription)
                        return nil 
                }
                
                return convertedBuffer
        }
}
