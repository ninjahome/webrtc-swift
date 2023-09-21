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
                
                guard let bufFromData = d.makePCMBuffer(format: outputFormat) else{
                        print("------->>> makePCMBuffer err")
                        return
                }
                
                print("------>>> length: \(bufFromData.frameLength) format: \(bufFromData.format) " )
                
                let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
                        outStatus.pointee = AVAudioConverterInputStatus.haveData
                        return bufFromData
                }
                let targetFrameCapacity = AVAudioFrameCount(inputFormat.sampleRate) * bufFromData.frameLength / AVAudioFrameCount(bufFromData.format.sampleRate)
                guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: targetFrameCapacity) else{
                        print("------->>> convertedBuffer err")
                        return
                }
                var error: NSError?
                self.recocer.convert(to: convertedBuffer, error: &error, withInputFrom:inputBlock)
                if let e = error{
                        print("------->>> convert err:", e.localizedDescription)
                }
                self.player.scheduleBuffer(convertedBuffer)
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
        var recocer:AVAudioConverter!
        var outputFormat:AVAudioFormat!
        var inputFormat:AVAudioFormat!
        
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
        
        @IBAction func startCalledAudioAction(_ sender: UIButton) {
                startAudio(isCaller: false)
        }
        
        @IBAction func startCallingAudioAction(_ sender: UIButton) {
                startAudio(isCaller: true)
        }
        
        private func startAudio(isCaller:Bool = true){
                do{
                        var err:NSError?
                        WebrtcLibStartVideo(isCaller,self, &err)
                        if let e = err{
                                throw e
                        }
                }catch let e{
                        print("------>>>startVideoAction:",e.localizedDescription)
                }
        }
        
        @IBAction func AnswerAudio(_ sender: UIButton) {
                guard let sdp = descTxtView.text else{
                        return
                }
                WebrtcLibSetAnswerForOffer(sdp)
        }
        
        @IBAction func StartEcho(_ sender: UIButton) {
                
#if false
                try! engine.start()
                audioPlayer.play()
#else
                var err:NSError?
                WebrtcLibStartVideo(true, self, &err)
                if let e = err{
                        print("------>>>start failed:",e.localizedDescription)
                }
#endif
        }
        
        private func initEngine() {
                
                do{
                        try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .voiceChat,options: [.allowBluetooth,.allowAirPlay,.mixWithOthers])
                        try AVAudioSession.sharedInstance().overrideOutputAudioPort(.none)
                        try AVAudioSession.sharedInstance().setActive(true)
                        isSpeaker = false
                        let input = engine.inputNode
                        try input.setVoiceProcessingEnabled(true)
                        
                        player = AVAudioPlayerNode()
                        engine.attach(player)
                        
                        let bus = 0
                        
                        inputFormat = input.inputFormat(forBus: bus)
                        
                        print("------>>>input format \(inputFormat! ) \(inputFormat.formatDescription)")
                        
                        guard  let of = AVAudioFormat(commonFormat: AVAudioCommonFormat.pcmFormatInt16,
                                                                sampleRate: 44100,
                                                                channels: 1,
                                                                interleaved: true) else{
                                return
                        }
                        print("------>>>input format \(of) \(of.formatDescription)")
                        outputFormat = of
                        
                        engine.connect(player, to: engine.outputNode, format: inputFormat)
                        guard let c = AVAudioConverter(from: outputFormat, to: inputFormat) else{
                                print("------>>> convert failed")
                                return
                        }
                        self.recocer = c
                        
                        input.installTap(onBus: bus, bufferSize: 4096, format: outputFormat) { (buffer, time) -> Void in
                                self.conversionQueue.async {
#if false
                                        self.localTestFunc(buffer: buffer, time: time)
#else
                                        let data = Data(pcmBuffer:buffer, time: time)
                                        var err:NSError?
                                        WebrtcLibSendAudioToPeer(data, &err)
                                        if let e = err{
                                                print("------>>> write audio data err:", e.localizedDescription)
                                        }
#endif
                                }
                        }
                        
                        engine.prepare()
                        
                }catch let err{
                        print("------>>>", err.localizedDescription)
                }
        }
        
        
        func localTestFunc(buffer:AVAudioPCMBuffer,time:AVAudioTime){
                let data = Data(pcmBuffer:buffer, time: time)
                
                
                guard let pcmuData = WebrtcLibAudioEncodePcmu(data)else{
                        print("------->>> WebrtcLibAudioEncodePcmu err")
                        return
                }
                
                guard let lpcmData = WebrtcLibAudioDecodePcmu(pcmuData) else{
                        print("------->>> WebrtcLibAudioDecodePcmu err")
                        return
                }
                
                print("------>>>raw size \(data.count) encoded size:\(pcmuData.count), decode size \(lpcmData.count)")
                guard let bufFromData = lpcmData.makePCMBuffer(format: outputFormat) else{
                        print("------->>> makePCMBuffer err")
                        return
                }
                
                print("------>>> length: \(bufFromData.frameLength) format: \(bufFromData.format) data size \(data.count)" )
                
                let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
                        outStatus.pointee = AVAudioConverterInputStatus.haveData
                        return bufFromData
                }
                let targetFrameCapacity = AVAudioFrameCount(inputFormat.sampleRate) * bufFromData.frameLength / AVAudioFrameCount(bufFromData.format.sampleRate)
                guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: targetFrameCapacity) else{
                        print("------->>> convertedBuffer err")
                        return
                }
                var error: NSError?
                self.recocer.convert(to: convertedBuffer, error: &error, withInputFrom:inputBlock)
                if let e = error{
                        print("------->>> convert err:", e.localizedDescription)
                }
                self.player.scheduleBuffer(convertedBuffer)
        }
}

