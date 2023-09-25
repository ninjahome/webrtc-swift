//
//  UIVideoViewController.swift
//  bsip
//
//  Created by wesley on 2023/9/24.
//

import UIKit
import AVFoundation

class UIVideoViewController: UIViewController {
        
        override func viewDidLoad() {
                super.viewDidLoad()
                
                // Do any additional setup after loading the view.
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

class SampleBufferVideoCallView: UIView {
        override class var layerClass: AnyClass {
                AVSampleBufferDisplayLayer.self
        }
        
        var sampleBufferDisplayLayer: AVSampleBufferDisplayLayer {
                layer as! AVSampleBufferDisplayLayer
        }
}
