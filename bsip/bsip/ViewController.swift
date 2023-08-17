//
//  ViewController.swift
//  bsip
//
//  Created by wesley on 2023/8/17.
//

import UIKit
import WebrtcLib

class ViewController: UIViewController {
        
        override func viewDidLoad() {
                super.viewDidLoad()
        }
        
        @IBAction func startVideoAction(_ sender: UIButton) {
                var err:NSError?
                WebrtcLibStartCamera(&err)
                if err != nil{
                        print("------->>>",err?.localizedDescription)
                }
        }
        
}

