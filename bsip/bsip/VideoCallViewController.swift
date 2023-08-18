//
//  VideoCallViewController.swift
//  bsip
//
//  Created by wesley on 2023/8/18.
//

import UIKit
import WebrtcLib
import AVFoundation

class VideoCallViewController: UIViewController{
        private lazy var videoQueue = DispatchQueue.init(label: "videolayer.queue",
                                                         qos: .userInteractive)
        private lazy var convertQueue = DispatchQueue.init(label: "convert.queue",
                                                           qos: .background)
        
        private let layer = AVSampleBufferDisplayLayer()
        private lazy var captureManager = VideoCaptureManager()
        
        override func viewDidLoad() {
                super.viewDidLoad()
                layer.frame = view.frame
                layer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        }
        
        @IBAction func startVedioAction(_ sender: UIButton) {
                view.layer.addSublayer(layer)
                captureManager.setVideoOutputDelegate(with: self)
        }
        
        /*
         // MARK: - Navigation
         
         // In a storyboard-based application, you will often want to do a little preparation before navigation
         override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
         // Get the new view controller using segue.destination.
         // Pass the selected object to the new view controller.
         }
         */
}

extension VideoCallViewController:AVCaptureVideoDataOutputSampleBufferDelegate{
        func captureOutput(_ output: AVCaptureOutput,
                           didOutput sampleBuffer: CMSampleBuffer,
                           from connection: AVCaptureConnection) {
                
                guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else{
                        return
                }
                
                let ciimage = CIImage(cvPixelBuffer: imageBuffer)
                let image = self.convert(cmage: ciimage)
                let imgData = image.jpegData(compressionQuality: 1.0)!
                videoQueue.async {
                        self.layer.enqueue(sampleBuffer)
                }
                
                convertQueue.async {

                        var err:NSError?
                        WebrtcLibFrameData(imgData, &err)
                        if let e = err{
                                print(e.localizedDescription)
                        }
                }
        }
        
        func convert(cmage: CIImage) -> UIImage {
                let context = CIContext(options: nil)
                let cgImage = context.createCGImage(cmage, from: cmage.extent)!
                let image = UIImage(cgImage: cgImage)
                return image
        }
}
