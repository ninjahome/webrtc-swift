//
//  FinalCallViewController+video.swift
//  bsip
//
//  Created by wesley on 2023/9/21.
//

import Foundation
import AVFAudio
import AVFoundation
import WebrtcLib

extension FinalCallViewController: AVCaptureVideoDataOutputSampleBufferDelegate{
        
        func initVidoeEngine(){
                captureManager.setVideoOutputDelegate(with: self)
                videoEncoder.naluHandling = self.compressedData
                naluParser.sampleBufferCallback = self.presentResult
                
                
                NotificationCenter.default.addObserver(self,
                                                       selector:#selector(checkCallSession(notification:)),
                                                       name: NotifySceneBecomeActive,
                                                       object: nil)
                
                NotificationCenter.default.addObserver(self,
                                                       selector:#selector(removLayers(notification:)),
                                                       name: NotifySceneDidEnterBackground,
                                                       object: nil)
                setupLayer()
        }
        
        private func setupLayer(){
                selfLayer = AVSampleBufferDisplayLayer()
                peerLayer = AVSampleBufferDisplayLayer()
//                peerLayer.frame = CGRect(origin: CGPoint(x: 0,y: 120), size: CGSize(width: 240, height: 480))
                let viewFrame = view.frame
                peerLayer.frame =  CGRect(origin: CGPoint(x: viewFrame.width/2,
                                                          y: viewFrame.height/2),
                                          size: CGSize(width: viewFrame.width/2,
                                                       height: viewFrame.height/2))
                
                peerLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
                selfLayer.frame = CGRect(origin: CGPoint(x: 0,y: 0), size: CGSize(width: 72, height: 120))
        }
        
        @objc func checkCallSession(notification: NSNotification) {
                print("------>>>isrunning:=>",captureManager.running(), captureManager.isInter())
                setupLayer()
                if captureManager.running()||captureManager.isInter(){
                        try? videoEncoder.configureCompressSession()
                        view.layer.addSublayer(peerLayer)
                        view.layer.addSublayer(selfLayer)
                }
        }
        
        @objc func removLayers(notification: NSNotification) {
                self.peerLayer.removeFromSuperlayer()
                self.selfLayer.removeFromSuperlayer()
        }
        
        private func compressedData(data:Data){
                self.videoEncoder.encoderQueue.async {//TODO::change this queue to lib queue
                        var err:NSError?
                        WebrtcLibSendVideoToPeer(data, &err)
                        if let e = err{
                                print("------>>>send video err:",e.localizedDescription)
                        }
                }
        }
        
        private  func presentResult(_ sample:CMSampleBuffer){
                peerLayer.enqueue(sample)
        }
        
        func captureOutput(_ output: AVCaptureOutput,
                           didOutput sampleBuffer: CMSampleBuffer,
                           from connection: AVCaptureConnection) {
                selfLayer.enqueue(sampleBuffer)
                videoEncoder.encode(buffer: sampleBuffer)
        }
}
