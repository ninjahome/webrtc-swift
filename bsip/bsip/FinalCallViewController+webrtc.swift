//
//  FinalCallViewController+webrtc.swift
//  bsip
//
//  Created by wesley on 2023/9/21.
//

import Foundation
import WebrtcLib


//MARK: - web rtc logic
extension FinalCallViewController:WebrtcLibCallBackProtocol{
        func answerCreated(_ p0: String?) {
        }
        
        func connected() {
                do{
                        try audioEngine.start()
                        audioPlayer.play()
                }catch let e{
                        print("------>>>audio engine start failed:",e.localizedDescription)
                        self.endingCall()
                }
        }
        
        func disconnected() {
                self.endingCall()
        }
        
        func newAudioData(_ data: Data?) {
                self.audioProcessQueue.async{
                        guard let d = data else{
                                print("------>>> receive empty audio data")
                                return
                        }
                        
                        guard let buffer = self.audioRecover.recover(data: d) else{
                                print("------>>> recover audio data failed")
                                return
                        }
                        self.audioPlayer.scheduleBuffer(buffer)
                }
        }
        
        func newVideoData(_ typ: Int, h264data: Data?) {
                
        }
        
        func offerCreated(_ p0: String?) {
                guard let offer = p0 else{
                        print("------>>> empty offer string")
                        self.endingCall()
                        return
                }
                print("------>>>offer crete success \n \(offer)")
                let answer = WebrtcLibSdpToRelay(host, offer)
                if answer.isEmpty{
                        print("------>>> send offer to relay server failed")
                        self.endingCall()
                        return
                }
                print("------>>>get answer from relay  success \n \(answer)")
                WebrtcLibSetAnswerForOffer(answer)
        }
}
