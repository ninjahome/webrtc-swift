//
//  FinalCallViewController+audio.swift
//  bsip
//
//  Created by wesley on 2023/9/21.
//

import Foundation
import AVFAudio
import AVFoundation
import WebrtcLib

// MARK: - audio logic
extension FinalCallViewController{
        
        func initAudioEngine() throws{
                
                try AVAudioSession.sharedInstance().setCategory(.playAndRecord,
                                                                mode: .voiceChat,
                                                                options: [.allowBluetooth])
                
                try AVAudioSession.sharedInstance().overrideOutputAudioPort(.none)
                try AVAudioSession.sharedInstance().setActive(true)
                
                isSpeaker = false
               
                let input = audioEngine.inputNode
                try input.setVoiceProcessingEnabled(true)
                
                let bus = 0
                let inputFormat = input.inputFormat(forBus: bus)
                
                guard  let of = AVAudioFormat(commonFormat: AVAudioCommonFormat.pcmFormatInt16,
                                              sampleRate: 44100,
                                              channels: 1,
                                              interleaved: true) else{
                        throw NSError(domain: "audio output foramt err", code: -1)
                }
                let outputFormat = of
                
                guard let c = AudioRecover(fromFmt: outputFormat, toFmt: inputFormat) else{
                        throw  NSError(domain: "audio recover err", code: -1)
                }
                audioRecover = c
                
                audioPlayer = AVAudioPlayerNode()
                audioEngine.attach(audioPlayer)
                
                audioEngine.connect(audioPlayer,
                                    to: audioEngine.outputNode,
                                    format: inputFormat)
                input.installTap(onBus: bus,
                                 bufferSize: 4096,
                                 format: outputFormat,
                                 block: self.audioProcess)
                
                audioEngine.prepare()
        }
        
        func audioProcess(buffer:AVAudioPCMBuffer, time:AVAudioTime) {
                self.audioProcessQueue.async {
                        let data = Data(pcmBuffer:buffer, time: time)
                        var err:NSError?
                        WebrtcLibSendAudioToPeer(data, &err)
                        if let e = err{
                                print("------>>> write audio data err:", e.localizedDescription)
                        }
                }
        }
        
        func switchSpeaker(){
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
                        self.endingCall()
                }
        }
}
