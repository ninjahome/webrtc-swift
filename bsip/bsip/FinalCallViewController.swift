//
//  AudioTestViewController.swift
//  bsip
//
//  Created by wesley on 2023/9/17.
//

import UIKit
import AVFAudio
import AVFoundation
import WebrtcLib

class FinalCallViewController: UIViewController {
        let audioProcessQueue = DispatchQueue(label: "audio process queue")
        var audioEngine = AVAudioEngine()
        var audioPlayer:AVAudioPlayerNode!
        var isSpeaker:Bool!
        var audioRecover:AudioRecover!
        var hasVideoChannel:Bool = false
        var host:String = "http://192.168.1.122:50000/sdp"
        
        // MARK: - ui logic
        override func viewDidLoad() {
                super.viewDidLoad()
                self.hideKeyboardWhenTappedAround()
                
                do{
                        try initAudioEngine()
                        
                }catch let err{
                        print("------>>> init system err:", err.localizedDescription)
                }
        }
        
        @IBAction func startAudioCall(_ sender: UIButton) {
                startAudio(isCaller: true)
        }
        
        @IBAction func answerAudioCall(_ sender: UIButton) {
                startAudio(isCaller: false)
        }
        
        private func startAudio(isCaller:Bool){
                self.hasVideoChannel = false
                var err:NSError?
                WebrtcLibStartCall(self.hasVideoChannel, isCaller, "alice-to-bob", self, &err)
                if let e = err{
                        print("------>>> start audio call failed \(e.localizedDescription)")
                        return
                }
        }
        
        @IBAction func startVideoCall(_ sender: UIButton) {
                self.hasVideoChannel = true
        }
        
        @IBAction func answerVideoCall(_ sender: UIButton) {
        }
        
        @IBAction func switchSpeaker(_ sender: UIButton) {
                self.switchSpeaker()
        }
        
}

//MARK: - business logic
extension FinalCallViewController{
        func endingCall(){
                audioPlayer.reset()
                audioEngine.reset()
        }
}
