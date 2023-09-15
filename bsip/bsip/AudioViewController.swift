//
//  AudioViewController.swift
//  bsip
//
//  Created by wesley on 2023/9/14.
//

import UIKit
import AVFoundation

class AudioViewController: UIViewController {
        
        var engine = AVAudioEngine()
        var player:AVAudioPlayerNode!
        var isSpeaker:Bool!
        
        override func viewDidLoad() {
                super.viewDidLoad()
                
                initEngine()
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
        
        @IBAction func StartEcho(_ sender: UIButton) {
                
                
                engine.prepare()
                try! engine.start()
                player.play()
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
                        engine.connect(player, to: engine.outputNode, format: inputFormat)
                        
                        
                        input.installTap(onBus: bus, bufferSize: 512, format: inputFormat) { (buffer, time) -> Void in
                                self.player.scheduleBuffer(buffer)
                        }
                        
                }catch let err{
                        print("------>>>", err.localizedDescription)
                }
        }
        
}
