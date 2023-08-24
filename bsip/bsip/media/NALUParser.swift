//
//  NALUParser.swift
//  bsip
//
//  Created by wesley on 2023/8/18.
//

import Foundation
import AVFoundation

class NALUParser {
        
        private var dataStream = Data()
        
        private lazy var parsingQueue = DispatchQueue.init(label: "parsing.queue",
                                                           qos: .userInteractive)
        var sampleBufferCallback: ((CMSampleBuffer) -> Void)?
        private var sps: H264Unit?
        private var pps: H264Unit?
        
        private var description: CMVideoFormatDescription?
        
        func enqueue(_ typ:Int, _ data: Data) {
                
                switch typ{
                case 7:
                        sps = H264Unit(type: .sps, payload: data)
//                        print("------>>>found sps:",data)
                        createDescription()
                        return
                case 8:
                        pps = H264Unit(type: .pps, payload: data)
//                        print("------>>>found pps:",data)
                        createDescription()
                        return
                default:
                        guard let _ = description else{
                                print("------>>>no description type:")
                                return
                        }
                        var naluLength = UInt32(data.count)
                        naluLength = CFSwapInt32HostToBig(naluLength)

                        let lengthData = Data(bytes: &naluLength, count: 4)
                        let rawData = lengthData + data
                        
                        guard let blockBuffer = createBlockBuffer(with: rawData),
                              let sampleBuffer = createSampleBuffer(with: blockBuffer) else {
                                print("------>>> create sample buffer failed!")
                                return
                        }
                        
                        sampleBufferCallback?(sampleBuffer)
                        return
                }
        }
        
        private func createDescription() {
                
                guard let sps = sps,
                      let pps = pps else {
                        return
                }
                
                let spsPointer = UnsafeMutablePointer<UInt8>.allocate(capacity: sps.payload.count)
                sps.payload.copyBytes(to: spsPointer, count: sps.payload.count)
                
                let ppsPointer = UnsafeMutablePointer<UInt8>.allocate(capacity: pps.payload.count)
                pps.payload.copyBytes(to: ppsPointer, count: pps.payload.count)
                
                let parameterSet = [UnsafePointer(spsPointer), UnsafePointer(ppsPointer)]
                let parameterSetSizes = [sps.payload.count, pps.payload.count]
                
                defer {
                        parameterSet.forEach {
                                $0.deallocate()
                        }
                }
                
                let status = CMVideoFormatDescriptionCreateFromH264ParameterSets(allocator: kCFAllocatorDefault,
                                                                                 parameterSetCount: 2,
                                                                                 parameterSetPointers: parameterSet,
                                                                                 parameterSetSizes: parameterSetSizes,
                                                                                 nalUnitHeaderLength: 4,
                                                                                 formatDescriptionOut: &description)
                
                if(status != noErr){
                        print("------>>>create descrition err :", status)
                }
                self.sps = nil
                self.pps = nil
//                print("------>>>creat description success:")
        }
        
        
        
        private func createSampleBuffer(with blockBuffer: CMBlockBuffer) -> CMSampleBuffer? {
                var sampleBuffer : CMSampleBuffer?
                var timingInfo = CMSampleTimingInfo()
                timingInfo.decodeTimeStamp = .invalid
                timingInfo.duration = CMTime.invalid
                timingInfo.presentationTimeStamp = .zero
                
                let error = CMSampleBufferCreateReady(allocator: kCFAllocatorDefault,
                                                      dataBuffer: blockBuffer,
                                                      formatDescription: description,
                                                      sampleCount: 1,
                                                      sampleTimingEntryCount: 1,
                                                      sampleTimingArray: &timingInfo,
                                                      sampleSizeEntryCount: 0,
                                                      sampleSizeArray: nil,
                                                      sampleBufferOut: &sampleBuffer)
                
                guard error == noErr,
                      let sampleBuffer = sampleBuffer else {
                        print("------>>>fail to create sample buffer")
                        return nil
                }
                
                if let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer,
                                                                             createIfNecessary: true) {
                        let dic = unsafeBitCast(CFArrayGetValueAtIndex(attachments, 0),
                                                to: CFMutableDictionary.self)
                        
                        CFDictionarySetValue(dic,
                                             Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately).toOpaque(),
                                             Unmanaged.passUnretained(kCFBooleanTrue).toOpaque())
                }
                
                return sampleBuffer
        }
        
        private func createBlockBuffer(with rawData: Data) -> CMBlockBuffer? {
                
                let pointer = UnsafeMutablePointer<UInt8>.allocate(capacity: rawData.count)
                
                rawData.copyBytes(to: pointer, count: rawData.count)
                var blockBuffer: CMBlockBuffer?
                
                let error = CMBlockBufferCreateWithMemoryBlock(allocator: kCFAllocatorDefault,
                                                               memoryBlock: pointer,
                                                               blockLength: rawData.count,
                                                               blockAllocator: kCFAllocatorDefault,
                                                               customBlockSource: nil,
                                                               offsetToData: 0,
                                                               dataLength: rawData.count,
                                                               flags: .zero,
                                                               blockBufferOut: &blockBuffer)
                
                guard error == kCMBlockBufferNoErr else {
                        print("------>>>fail to create block buffer")
                        return nil
                }
                
                return blockBuffer
        }
}
