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
                      
                        let audioFormat = AVAudioFormat(commonFormat: AVAudioCommonFormat.pcmFormatInt16 , sampleRate: 48000.0, channels: 1, interleaved: true)
                        engine.connect(player, to: engine.outputNode, format: inputFormat)
                        
                        input.installTap(onBus: bus, bufferSize: 4096, format: audioFormat) { (buffer, time) -> Void in
                                let data = audioBufferToNSData(PCMBuffer: buffer)
                                var err:NSError?
                                WebrtcLibSendAudioToPeer(data, &err)
                                if let e = err{
                                        print("------>tap err:",e.localizedDescription)
                                }
//                                let b2 = toPCMBuffer(data: data as NSData)
//                                self.player.scheduleBuffer(b2)
                        }
                        
                }catch let err{
                        print("------>>>", err.localizedDescription)
                }
        }
}
