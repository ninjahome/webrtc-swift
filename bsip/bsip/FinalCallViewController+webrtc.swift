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
                if self.muteRemote{
                        return
                }
                
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
                guard let data = h264data else{
                        return
                }
                naluParser.parsingQueue.async {
                        self.naluParser.enqueue(typ, data)
                }
        }
        
        func offerCreated(_ p0: String?) {
                guard let offer = p0 else{
                        print("------>>> empty offer string")
                        self.endingCall()
                        return
                }
//                print("------>>>offer crete success \n \(offer)")
                let answer = WebrtcLibSdpToRelay(RelayHostUrl, offer)
                if answer.isEmpty{
                        print("------>>> send offer to relay server failed")
                        self.endingCall()
                        return
                }
//                print("------>>>get answer from relay  success \n \(answer)")
                WebrtcLibSetAnswerForOffer(answer)
        }
}
