//
//  YNVideoPlayer.swift
//  VideoPlayer
//
//  Created by 张艳能 on 2018/3/29.
//  Copyright © 2018年 张艳能. All rights reserved.
//

import UIKit
import AVFoundation
import MediaPlayer

class YNVideoPlayer: UIView,UIGestureRecognizerDelegate {

    var url: URL? //播放url
    var isForceLandscape = false //是否强制横屏
    
    //添加注释，注释啊
    //再次添加注释，进行合并啊
    private var playerItem: AVPlayerItem?
    private var player:AVPlayer?
    private var playerLayer:AVPlayerLayer?
    
    //UI
    private let playButton = UIButton()
    private let toolPlayBtn = UIButton()
    private let toolView = UIView()
    private let currentLabel = UILabel()
    private let totalLabel = UILabel()
    private let processSlider = UISlider()
    private let minMaxBtn = UIButton()
    private let processView = UIProgressView()
    
    private let device = UIDevice.current
    
    private var originalFrame: CGRect?
    private var originalOrientation: UIDeviceOrientation? //记录原始设备方向
    private var periodicTimeObserver: Any?
    private var sysVolume: Float = 0.0
    
    private var isPlaying = false //记录播放状态
    private var isLandscape = false //记录当前状态是否横屏
    private var isEnlargeModel = false //是否是方法模式
    
    private let OBSERVER_STATUS = "status" //播放状态
    private let OBSERVER_LOADEDTIMERANGES = "loadedTimeRanges" // 检测缓存状态
    private let OBSERVER_PLAYBACKBUFFEREMPTY = "playbackBufferEmpty" //缓存为空
    private let OBSERVER_PLAYBACKLIKELYTOKEEPUP = "playbackLikelyToKeepUp" //缓存足够播放
    private let OBSERVER_RATE = "rate"
    
    //记录是否要开启延迟操作
    private var _isDelayHide = false
    private var isDelayHide: Bool  {
        
        get {
            return _isDelayHide
        }
        set {
            _isDelayHide = newValue
            
            if newValue {
                //取消延迟操作
                NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(delayHideAction), object: nil)
                //添加延迟操作
                self.perform(#selector(delayHideAction), with: nil, afterDelay: Double(3.0))
            } else {
                //取消延迟操作
                NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(delayHideAction), object: nil)
            }
        }
    }
    
    private let assetKeys:[String] = ["tracks","duration","commonMetadata","availableMediaCharacteristicsWithMediaSelectionOptions"]
    
    init(frame: CGRect, url: URL) {
        super.init(frame: frame)
        self.originalFrame = frame
        self.url = url
        self.initDefualtDatas()
        self.initPlayer()
        self.addToolBar()
        self.addTapGesture()
        self.addPanGesture()
        self.addPlayerItemObserver()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    //init defualt datas
    private func initDefualtDatas() {
        
        self.clipsToBounds = true
        self.backgroundColor = UIColor.black
        self.originalOrientation = UIDevice.current.orientation

        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        NotificationCenter.default.addObserver(self, selector: #selector(deviceOrientationChange(_:)), name: NSNotification.Name.UIDeviceOrientationDidChange, object: nil)
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
        
        self.sysVolume = AVAudioSession.sharedInstance().outputVolume //获取系统音量
    }
    
    //初始化播放器
    private func initPlayer() {
        
        guard let playUrl = self.url else {
            print("play url is nil")
            return
        }
        //网络请求还是本地加载
        var asset:AVAsset
        if playUrl.absoluteString.contains("http") {
            asset = AVURLAsset(url: playUrl, options: nil)
        } else {
            asset = AVAsset(url: playUrl)
        }
        self.playerItem = AVPlayerItem(asset: asset, automaticallyLoadedAssetKeys: self.assetKeys)
        self.player = AVPlayer(playerItem: self.playerItem!)
        self.playerLayer = AVPlayerLayer(player: self.player!)
        self.playerLayer!.frame = self.bounds
        
        self.layer.addSublayer(self.playerLayer!)
    }
    

    @objc
    private func deviceOrientationChange(_ notification: Notification) {
        
        //根据设备自动转换
        UIView.animate(withDuration: 0.25) {
            if self.device.orientation ==  .portrait {
                self.originalFrame!.size.width = min(self.originalFrame!.size.width, UIScreen.main.bounds.width)
                self.frame = self.originalFrame!
                self.isLandscape = false
            } else if self.device.orientation == .landscapeLeft || self.device.orientation == .landscapeRight {
                self.frame = UIScreen.main.bounds
                self.isLandscape = true
            }
            
            self.subViewsChangeFrame()
        }
    }
    private func subViewsChangeFrame() {
        
        self.playerLayer!.frame = self.bounds
        self.playButton.size = CGSize(width: 44, height: 44)
        self.playButton.center = CGPoint(x: self.width * 0.5, y: self.height * 0.5)
        self.toolView.frame = CGRect(x: 0, y: self.height - 44, width: self.width, height: 44)
        self.toolPlayBtn.size = CGSize(width: 44, height: 44)
        self.toolPlayBtn.left = 0
        self.toolPlayBtn.top = 0
        self.minMaxBtn.size = CGSize(width: 44.0, height: 44.0)
        self.minMaxBtn.left = self.width - self.minMaxBtn.width
        self.minMaxBtn.centerY = self.toolPlayBtn.centerY
        self.currentLabel.left = toolPlayBtn.right + 5
        self.currentLabel.height = 20
        self.currentLabel.width = 60
        self.totalLabel.width = 60
        self.totalLabel.height = 20
        self.totalLabel.left = self.minMaxBtn.left - self.totalLabel.width - 5
        
        if self.isLandscape {
            self.currentLabel.centerY = self.toolPlayBtn.centerY
            self.totalLabel.centerY = self.currentLabel.centerY
            self.processSlider.centerY = self.currentLabel.centerY
            self.processSlider.left = self.currentLabel.right + 5
            self.processSlider.width = self.totalLabel.left - 5 - self.processSlider.left
        } else {
            self.currentLabel.top = self.toolPlayBtn.centerY
            self.totalLabel.centerY = self.currentLabel.centerY
            self.processSlider.centerY = self.toolPlayBtn.centerY - 5
            self.processSlider.left = self.currentLabel.left
            self.processSlider.width = self.totalLabel.right - self.processSlider.left
        }
        
        self.processView.left = self.processSlider.left + 2
        self.processView.width = self.processSlider.width - 4
        self.processView.centerY = self.processSlider.centerY
    }
    
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        removeStatusObserver()
        removePlayerItemObserver()
    }
}

extension YNVideoPlayer {
    
    private func addToolBar() {
        self.playButton.setImage(UIImage(named: "CLPlayBtn"), for: UIControlState.normal)
        self.playButton.setImage(UIImage(named: "CLPauseBtn"), for: UIControlState.highlighted)
        self.playButton.setImage(UIImage(named: "CLPauseBtn"), for: UIControlState.selected)
        self.playButton.addTarget(self, action: #selector(playButtonClick(_:)), for: .touchUpInside)
        self.addSubview(self.playButton)
        
        self.toolView.backgroundColor = UIColor(white: 0.6, alpha: 0.4)
        self.addSubview(self.toolView)
        
        
        self.toolPlayBtn.setImage(UIImage(named: "CLPlayBtn"), for: UIControlState.normal)
        self.toolPlayBtn.setImage(UIImage(named: "CLPauseBtn"), for: UIControlState.highlighted)
        self.toolPlayBtn.setImage(UIImage(named: "CLPauseBtn"), for: UIControlState.selected)
        self.toolPlayBtn.addTarget(self, action: #selector(playButtonClick(_:)), for: .touchUpInside)
        self.toolView.addSubview(self.toolPlayBtn)
        
        self.currentLabel.text = "00:00:00"
        self.currentLabel.textColor = UIColor.white
        self.currentLabel.font = UIFont.systemFont(ofSize: 12)
        self.currentLabel.textAlignment = .left
        
        self.toolView.addSubview(self.currentLabel)
        
        self.totalLabel.text = "00:00:00"
        self.totalLabel.textColor = UIColor.white
        self.totalLabel.font = UIFont.systemFont(ofSize: 12)
        self.totalLabel.textAlignment = .right
        
        self.toolView.addSubview(self.totalLabel)
        
        self.processView.progressTintColor = UIColor.gray
        self.processView.trackTintColor = UIColor.black
        self.processView.progress = 0.0
        self.toolView.addSubview(self.processView)
        
        self.processSlider.minimumValue = 0
        self.processSlider.maximumValue = 100
        self.processSlider.value = 0
        self.processSlider.setThumbImage(UIImage(named: "CLRound"), for: .normal)
        self.processSlider.maximumTrackTintColor = UIColor.clear
        self.processSlider.minimumTrackTintColor = UIColor.white
        self.processSlider.addTarget(self, action: #selector(processSliderTouchBegin), for: .touchDown)
        self.processSlider.addTarget(self, action: #selector(processSliderTouchEnd), for: .touchUpInside)
        self.processSlider.addTarget(self, action: #selector(processSliderTouchMove), for: .valueChanged)
        self.toolView.addSubview(self.processSlider)
        
        
        self.minMaxBtn.setImage(UIImage(named: "CLMaxBtn"), for: UIControlState.normal)
        self.minMaxBtn.setImage(UIImage(named: "CLMinBtn"), for: UIControlState.selected)
        self.minMaxBtn.addTarget(self, action: #selector(minMaxButtonClick(_:)), for: .touchUpInside)
        self.toolView.addSubview(self.minMaxBtn)
        
        self.subViewsChangeFrame()//约束布局
    }

    private func hideToolView() {
        
        if !self.toolView.isHidden {
            UIView.animate(withDuration: 0.25, animations: {
                self.toolView.transform = CGAffineTransform(translationX: 0, y: 44)
            }) { (flag) in
                self.toolView.isHidden = true
                self.toolView.transform = CGAffineTransform.identity
            }
        }
    }
    
    private func showToolView() {
        
        if self.toolView.isHidden {
            self.toolView.transform = CGAffineTransform(translationX: 0, y: 44)
            self.toolView.isHidden = false
            UIView.animate(withDuration: 0.25, animations: {
                self.toolView.transform = CGAffineTransform.identity
            })
        }
        
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        //6
        self.isDelayHide = false
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        //1
        self.isDelayHide = true
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        //7
        self.isDelayHide = true
    }
    
    
    private func addTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(tapGestureAction(_:)))
        tapGesture.numberOfTapsRequired = 1
        self.addGestureRecognizer(tapGesture)
    }
    
    private func addPanGesture () {
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(panGestureAction(_:)))
        panGesture.maximumNumberOfTouches = 1
        panGesture.delegate = self
        self.addGestureRecognizer(panGesture)
    }
    
    private func addPlayerItemObserver() {
        
        guard let playerItemTmp = self.playerItem else { return }
        addStatusObserver()
        playerItemTmp.addObserver(self, forKeyPath: OBSERVER_LOADEDTIMERANGES, options: .new, context: nil)
        playerItemTmp.addObserver(self, forKeyPath: OBSERVER_PLAYBACKBUFFEREMPTY, options: .new, context: nil)
        playerItemTmp.addObserver(self, forKeyPath: OBSERVER_PLAYBACKLIKELYTOKEEPUP, options: .new, context: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(playFinished), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil)
        
    }
    
    private func removePlayerItemObserver() {
        guard let playerItemTmp = self.playerItem else { return }
        playerItemTmp.removeObserver(self, forKeyPath: OBSERVER_LOADEDTIMERANGES)
        playerItemTmp.removeObserver(self, forKeyPath: OBSERVER_PLAYBACKBUFFEREMPTY)
        playerItemTmp.removeObserver(self, forKeyPath: OBSERVER_PLAYBACKLIKELYTOKEEPUP)
        
        NotificationCenter.default.removeObserver(self)
    }
    
    
    private func addStatusObserver() {
        guard let playerItemTmp = self.playerItem else { return }
        playerItemTmp.addObserver(self, forKeyPath: OBSERVER_STATUS, options: NSKeyValueObservingOptions.new, context: nil)
    }
    
    private func removeStatusObserver() {
        guard let playerItemTmp = self.playerItem else { return }
        playerItemTmp.removeObserver(self, forKeyPath: OBSERVER_STATUS)
    }
    
    private func addPlayerItemTimeObserver() {
        let interval = CMTime(seconds: Double(0.5), preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        
       self.periodicTimeObserver = self.player!.addPeriodicTimeObserver(forInterval: interval, queue: DispatchQueue.main) { (cmtime) in
            let currentTime = CMTimeGetSeconds(cmtime)
            let duration = CMTimeGetSeconds(self.playerItem!.duration)
            self.setCurrentTime(Int(currentTime), duration: Int(duration))
        }
    }
    
    private func removePlayerItemTimeObserver() {
        guard let timeObserver = self.periodicTimeObserver else {return}
        self.player!.removeTimeObserver(timeObserver)
        self.periodicTimeObserver = nil
    }
    
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        if keyPath == OBSERVER_STATUS {
     
            DispatchQueue.main.async {
                
                self.removeStatusObserver()
                
                if self.playerItem!.status == AVPlayerItemStatus.readyToPlay {
                   
                    self.addPlayerItemTimeObserver()
                    //默认赋值
                    self.setCurrentTime(Int(CMTimeGetSeconds(kCMTimeZero)), duration: Int(CMTimeGetSeconds(self.playerItem!.duration)))
                    
                } else if self.playerItem!.status == AVPlayerItemStatus.failed {
                    print("资源文件不存在")
                } else {
                    print("load video fail")
                }
            }
        }
        
        if keyPath == OBSERVER_LOADEDTIMERANGES {
            //设置缓存进度
            let loadedTimeRanges = self.playerItem!.loadedTimeRanges
            if loadedTimeRanges.count < 1 { return }
            let timeRange:CMTimeRange = loadedTimeRanges.first!.timeRangeValue
            let bufferingTime = CMTimeGetSeconds(timeRange.start) + CMTimeGetSeconds(timeRange.duration)
            let totalTime = CMTimeGetSeconds(playerItem!.duration)
            self.processView.setProgress(Float(bufferingTime/totalTime), animated: true)
            
        }
        
        if keyPath == OBSERVER_PLAYBACKBUFFEREMPTY {
            
            if self.playerItem!.isPlaybackBufferEmpty {
                //如果缓存为空，处理这块逻辑
            }
        }
        
        if keyPath == OBSERVER_PLAYBACKLIKELYTOKEEPUP {
            if self.playerItem!.isPlaybackLikelyToKeepUp {
                //如果缓存足够去播放，逻辑处理
                
            }
            
        }
        
        if keyPath == OBSERVER_RATE {
            //播放速度
            
        }
        
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        //屏蔽掉滑动条
        if touch.view == self.processSlider {
            return false
        }
        return true
    }
    
    @objc
    private func minMaxButtonClick(_ sender: UIButton) {
    
        sender.isSelected = !sender.isSelected
        
        if sender.isSelected {
            UIDevice.current.setValue(UIDeviceOrientation.landscapeLeft.rawValue, forKey: "orientation")
        } else {
            UIDevice.current.setValue(UIDeviceOrientation.portrait.rawValue, forKey: "orientation")
        }
        
    }
    
    
    @objc
    private func playButtonClick(_ sender: UIButton) {

        self.playButton.isHidden = true
        
        if self.toolPlayBtn.isSelected {
            self.toolPlayBtn.isSelected = false
            self.pauseVideo()
        } else {
            self.toolPlayBtn.isSelected = true
            self.playVideo()
            if sender == self.playButton {
                self.hideToolView()
            }
        }
        
        //强制横屏
        if self.isForceLandscape {
            UIDevice.current.setValue(UIDeviceOrientation.landscapeLeft.rawValue, forKey: "orientation")
        }
        
        //4
        self.isDelayHide = true
    }
    
    @objc
    private func tapGestureAction(_ gestureRecognizer: UITapGestureRecognizer) {

        self.playButton.isSelected = true
        if self.toolView.isHidden {
            self.showToolView()
        } else {
            self.hideToolView()
        }
        
        //2
        self.isDelayHide = true
    }
    
    @objc
    func processSliderTouchBegin() {
        self.pauseVideo() //暂停播放
        self.removePlayerItemTimeObserver()
        //5
        self.isDelayHide = false
    }
    
    @objc
    func processSliderTouchMove() {
        self.playerItem!.cancelPendingSeeks()
        
        let time = self.processSlider.value
        
        self.player!.seek(
            to: CMTime(seconds: Double(time), preferredTimescale: CMTimeScale(NSEC_PER_SEC)),
                       toleranceBefore: kCMTimeZero,
                       toleranceAfter: kCMTimeZero)
    }
    
    @objc
    func processSliderTouchEnd() {
        
        self.addPlayerItemTimeObserver()
        self.playVideo()
        
        //3
        self.isDelayHide = true
    }
    
    @objc
    func delayHideAction() {
        self.hideToolView()
    }
    
    @objc
    func playFinished() {
        
        print("播放完毕")
    }
    
    
    @objc
    func panGestureAction(_ recognizer: UIPanGestureRecognizer) {
        
        if !self.isLandscape { return } //全屏才响应手势
        let toolPoint = recognizer.location(in: self.toolView)
        if toolPoint.y > 0 { return } //如果在工具栏上，则不触发手势事件
        
        let maxVolume: Float = 1.0
        let minVolume: Float = 0.0
        
        /*
         translationInView: 手指在视图上移动的位置（x,y）向下和向右为正，向上和向左为负。
         locationInView：手指在视图上的位置（x,y）就是手指在视图本身坐标系的位置。
         velocityInView：手指在视图上移动的速度（x,y）, 正负也是代表方向，值得一体的是在绝对值上|x| > |y| 水平移动， |y|>|x| 竖直移动。
         */
        let point = recognizer.location(in: self)
        let transpoint = recognizer.translation(in: self)
        let velpoint = recognizer.velocity(in: self)
        let dy = transpoint.y
        
        if fabs(velpoint.y) > fabs(velpoint.x) {
            //竖直方向滑动
            if point.x > self.frame.size.width * 0.5 {
                //右边 控制声音
                var volume:Float = self.sysVolume
                if dy < 0 { // 上滑
                    volume += 0.1
                    if volume > maxVolume {
                        volume = maxVolume
                    }
                } else {
                    volume -= 0.1
                    if volume < minVolume {
                        volume = minVolume
                    }
                }
                self.volumeChange(volume)
                
            } else {
                //左边 设置屏幕亮度
                if dy < 0 { // 上滑
                    UIScreen.main.brightness += 0.05
                    if UIScreen.main.brightness > CGFloat(1) {
                        UIScreen.main.brightness = CGFloat(1)
                    }
                } else {
                    UIScreen.main.brightness -= 0.05
                    if UIScreen.main.brightness < CGFloat(0) {
                        UIScreen.main.brightness = CGFloat(0)
                    }
                }
            }
        }
        
    }
    
    //必须在真机上调试才有效
    private func volumeChange(_ value: Float) {
        guard let slider = self.getSysSlider() else {return}
        slider.setValue(value, animated: true)
        self.sysVolume = AVAudioSession.sharedInstance().outputVolume
       
    }
    
    private func getSysSlider()->UISlider? {
        let sysVolumeView = MPVolumeView()
        var sysSlider: UISlider?
        for newView in sysVolumeView.subviews {
            if newView is UISlider {
                sysSlider = newView as? UISlider
                break;
            }
        }
        return sysSlider
    }
    
}

extension YNVideoPlayer {
    
    func resetPlayVideo() {
        //重新播放
        
        
    }
    
    func playVideo() {
        if self.player != nil && self.isPlaying == false {
            self.player!.play()
            self.isPlaying = true
        }
    }
    
    func pauseVideo() {
        if self.player != nil && self.isPlaying {
            self.player!.pause()
            self.isPlaying = false
        }
    }
    
    func setCurrentTime(_ time: Int,duration: Int) {
        
        self.currentLabel.text = self.getTimeSting(time)
        self.totalLabel.text = self.getTimeSting(duration)
        self.processSlider.minimumValue = 0.0
        self.processSlider.maximumValue = Float(duration)
        self.processSlider.value = Float(time)
    }
    
    private func getTimeSting(_ interval: Int) -> String {
        let hours: Int = Int(interval / 3600)
        let minutes: Int = Int(Int(interval / 60) % 60)
        let seconds: Int = Int(Int(interval) % 60)
        return String(format: "%02d:%02d:%02d", hours,minutes,seconds)
    }
    
}
