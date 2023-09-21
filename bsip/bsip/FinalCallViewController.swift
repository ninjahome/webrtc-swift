//
//  AudioTestViewController.swift
//  bsip
//
//  Created by wesley on 2023/9/17.
//

import UIKit
import AVFAudio

class FinalCallViewController: UIViewController {
        
        var player: AVAudioPlayer!
        
        override func viewDidLoad() {
                super.viewDidLoad()
                
                guard let fxURL = Bundle.main.url(forResource: "output", withExtension: "ogg") else {
                        return
                }
                
                do {
                        let data = try Data(contentsOf: fxURL)
                        print("------>>>data length :", data.count)
                        let file: AVAudioFile!
                        try file = AVAudioFile(forReading: fxURL)
                        let format = file.processingFormat
                        print("------>>>format \(format.formatDescription)")
                } catch {
                        print("------->>>Could not load file: \(error)")
                        return
                }
                
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
