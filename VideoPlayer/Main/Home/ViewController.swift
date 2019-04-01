//
//  ViewController.swift
//  VideoPlayer
//
//  Created by 张艳能 on 2018/3/27.
//  Copyright © 2018年 张艳能. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: BaseViewController {
    
    //网络资源加载
    //分支上添加代码了
    let networkUrl = "http://flv3.bn.netease.com/tvmrepo/2018/4/N/J/EDDSUKMNJ/SD/EDDSUKMNJ-mobile.mp4"

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(AVAudioSessionCategoryAmbient)
            try session.setActive(true)
            
        }catch{
            print("session setting fail")
        }
        
//        let url = Bundle.main.url(forResource: "hubblecast", withExtension: "m4v")
        let url = URL(string: self.networkUrl)
        let videoPlayer = YNVideoPlayer(frame: CGRect(x: 0, y: 100, width: self.view.bounds.size.width, height: 200), url: url!)
        self.view.addSubview(videoPlayer)
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    

}

