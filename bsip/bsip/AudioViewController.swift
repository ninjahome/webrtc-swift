//
//  AudioViewController.swift
//  bsip
//
//  Created by wesley on 2023/9/14.
//

import UIKit
import AVFoundation
import WebrtcLib

class AudioViewController: UIViewController, WebrtcLibCallBackProtocol {
        
        
        func connected() {
                engine.prepare()
                try! engine.start()
                player.play()
        }
        
        func disconnected() {
                engine.stop()
                player.stop()
        }
        func answerCreated(_ p0: String?) {
                guard let answer = p0 else{
                        return
                }
                print(answer)
        }
        
        func newAudioData(_ data: Data?) {
                guard let d = data else{
                        return
                }
                let buffer = toPCMBuffer(data: d as NSData)
                self.player.scheduleBuffer(buffer)
        }
        func newVideoData(_ typ: Int, h264data: Data?) {
                print("------>>>why video")
        }
        
        func offerCreated(_ p0: String?) {
                guard let offer = p0 else{
                        return
                }
                print(offer)
        }
        // MARK: Instance Variables
        private let conversionQueue = DispatchQueue(label: "conversionQueue")
        
        @IBOutlet var descTxtView: UITextView!
        
        var engine = AVAudioEngine()
        var player:AVAudioPlayerNode!
        var isSpeaker:Bool!
        
        override func viewDidLoad() {
                super.viewDidLoad()
                
                initEngine()
                self.hideKeyboardWhenTappedAround()
        }
        
        override func viewWillAppear(_ animated: Bool) {
                super.viewWillAppear(animated)
                
                // MARK: 1 - Asks user for microphone permission
                
                if AVCaptureDevice.authorizationStatus(for: AVMediaType.audio) != .authorized {
                        AVCaptureDevice.requestAccess(for: AVMediaType.audio,
                                                      completionHandler: { (granted: Bool) in
                        })
                }
        }
        
        @IBAction func SwitchToSpeaker(_ sender: UIButton) {
                do{
                        if self.isSpeaker{
                                try AVAudioSession.sharedInstance().overrideOutputAudioPort(.none)
                                self.isSpeaker = false
                        }else{
                                try AVAudioSession.sharedInstance().overrideOutputAudioPort(.speaker)
                                self.isSpeaker = true
                        }
                        try AVAudioSession.sharedInstance().setActive(true)
                }catch let err{
                        print("------>>>", err.localizedDescription)
                }
        }
        
        @IBAction func AnswerAudio(_ sender: UIButton) {
                guard let sdp = descTxtView.text else{
                        return
                }
                WebrtcLibSetAnswerForOffer(sdp)
                //                var err:NSError?
                //                WebrtcLibAnswerVideo(sdp, self, &err)
                //                if let e = err{
                //                        print("------>>>start failed:",e.localizedDescription)
                //                }
        }
        @IBAction func StartEcho(_ sender: UIButton) {
                var err:NSError?
                WebrtcLibStartVideo(true, self, &err)
                if let e = err{
                        print("------>>>start failed:",e.localizedDescription)
                }
        }
        
        private func initEngine(){
                
                do{
                        try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .voiceChat,options: [.allowBluetooth,.allowAirPlay])
                        try AVAudioSession.sharedInstance().overrideOutputAudioPort(.none)
                        try AVAudioSession.sharedInstance().setActive(true)
                        isSpeaker = false
                        let input = engine.inputNode
                        try input.setVoiceProcessingEnabled(true)
                        
                        player = AVAudioPlayerNode()
                        engine.attach(player)
                        
                        let bus = 0
                        let inputFormat = input.inputFormat(forBus: bus)
                        print("------>>>channel number:\(inputFormat.channelCount)")
                        
                        var opusASBD = AudioStreamBasicDescription(mSampleRate: 48000.0,
                                                                   mFormatID: kAudioFormatOpus,
                                                                   mFormatFlags: 0,
                                                                   mBytesPerPacket: 0,
                                                                   mFramesPerPacket: 2880,
                                                                   mBytesPerFrame: 0,
                                                                   mChannelsPerFrame: 1,
                                                                   mBitsPerChannel: 0,
                                                                   mReserved: 0)
                        
                        let recordingFormat = AVAudioFormat(streamDescription: &opusASBD)!
                        engine.connect(player, to: engine.outputNode, format: inputFormat)
                        
                        guard let converter = AVAudioConverter(from: inputFormat, to: recordingFormat) else{
                                print("------>>> no valid converter")
                                return
                        }
                        input.installTap(onBus: bus, bufferSize: 4096, format: inputFormat) { (buffer, time) -> Void in
                                self.conversionQueue.async {
                                        let pcmBuffer = AVAudioPCMBuffer(pcmFormat: recordingFormat, frameCapacity: AVAudioFrameCount(recordingFormat.sampleRate * 2.0))
                                        
                                        var err:NSError?
                                        let inputBlock: AVAudioConverterInputBlock = {inNumPackets, outStatus in
                                                outStatus.pointee = AVAudioConverterInputStatus.haveData
                                                return buffer
                                        }
                                        converter.convert(to: pcmBuffer!, error: &err, withInputFrom: inputBlock)
                                        if let e = err {
                                                print("------>>>convert failed:",e.localizedDescription)
                                                return
                                        }
                                        
                                        guard let convertedBuffer = pcmBuffer else{
                                                print("------>>>converted pcm buffer is empty:")
                                                return
                                        }
                                        let data = audioBufferToNSData(PCMBuffer: convertedBuffer)
//                                        if let channelData = pcmBuffer!.int16ChannelData {
//
//                                                let channelDataValue = channelData.pointee
//                                                let channelDataValueArray = stride(from: 0,
//                                                                                   to: Int(pcmBuffer!.frameLength),
//                                                                                   by: buffer.stride).map{ channelDataValue[$0] }
//
//                                                // Converted pcm 16 values are delegated to the controller.
//                                                Data(channelDataValueArray)
//                                                self.delegate?.didOutput(channelData: channelDataValueArray)
//                                                // completion(channelDataValueArray)
//                                        }
                                        
                                        
//                                        let data = audioBufferToNSData(PCMBuffer: buffer)
                                        
                                        WebrtcLibSendAudioToPeer(data, &err)
                                        if let e = err{
                                                print("------>tap err:",e.localizedDescription)
                                        }
                                        //                                let b2 = toPCMBuffer(data: data as NSData)
                                        //                                self.player.scheduleBuffer(b2)
                                }
                        }
                        
                }catch let err{
                        print("------>>>", err.localizedDescription)
                }
        }
}
