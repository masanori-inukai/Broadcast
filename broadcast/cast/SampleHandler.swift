//
//  SampleHandler.swift
//  cast
//
//  Created by masanori on 2018/05/28.
//

import HaishinKit
import VideoToolbox
import ReplayKit
import Logboard

@available(iOS 11.0, *)
class SampleHandler: RPBroadcastSampleHandler {
    
    // RTMP対応のServer情報を下さい　※認証が入らない場合は[username]:[password]@は入らないです。
    // HACK: ただなぜかここで、認証情報を入れるとconnectに失敗するので、認証情報は入れないことにする。(サーバーで認証なしにすると上手くいく)
    fileprivate let targetURL = "rtmp://[user name]:[password]@[ip]:[port]/[application name]"
    // マイクと内部音声を合わせると悲惨になるので、一旦マイクだけにして、ゲームの音はマイクを通して拾うようにする
    fileprivate let micOnly = true

    public lazy var broadcaster: RTMPBroadcaster = {
        return RTMPBroadcaster()
    }()
    
    private lazy var spliter: SoundSpliter = {
        var spliter: SoundSpliter = SoundSpliter()
        spliter.delegate = self
        return spliter
    }()
    
    override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {    
        print("broadcastStarted")
        // setupUIから送られてくるが、今回は拡張UIは使用しない
        super.broadcastStarted(withSetupInfo: setupInfo)
        self.broadcaster.connect(self.targetURL)
    }
    
    override func broadcastFinished() {
        print("broadcastFinished")
        self.broadcaster.close()
    }
    
    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        switch sampleBufferType {
            case .video:
                if let description = CMSampleBufferGetFormatDescription(sampleBuffer) {
                    let dim = CMVideoFormatDescriptionGetDimensions(description)
                    self.broadcaster.stream.videoSettings = [
                        "width": dim.width,
                        "height": dim.height,
                        "profileLevel": kVTProfileLevel_H264_Baseline_AutoLevel
                    ]
                }
                self.broadcaster.appendSampleBuffer(sampleBuffer, withType: .video)
            case .audioApp:
                if self.micOnly { break }
                self.spliter.appendSampleBuffer(sampleBuffer)
            case .audioMic:
                self.broadcaster.appendSampleBuffer(sampleBuffer, withType: .audio)
        }
    }
}

@available(iOS 11.0, *)
extension SampleHandler: SoundSpliterDelegate {

    public func outputSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        self.broadcaster.appendSampleBuffer(sampleBuffer, withType: .audio)
    }
}

