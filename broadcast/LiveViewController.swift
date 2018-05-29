//
//  LiveViewController.swift
//  cast
//
//  Created by masanori on 2018/05/28.
//

import HaishinKit
import UIKit
import AVFoundation
import Photos
import VideoToolbox

class RecorderDelegate: DefaultAVMixerRecorderDelegate {
    
    override func didFinishWriting(_ recorder: AVMixerRecorder) {
        guard let writer = recorder.writer else {
            return
        }
        
        PHPhotoLibrary.shared().performChanges({() -> Void in
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: writer.outputURL)
        }, completionHandler: { (_, error) -> Void in
            do {
                try FileManager.default.removeItem(at: writer.outputURL)
            } catch let error {
                print(error)
            }
        })
    }
}

final class LiveViewController: UIViewController {
    // RTMP対応のServer情報を下さい　※認証が入らない場合は[user name]:[password]@は入らないです。
    fileprivate let targetURL = "rtmp://[user name]:[password]@[ip]:[port]/[application name]"
    
    var rtmpConnection: RTMPConnection = RTMPConnection()
    var rtmpStream: RTMPStream!
    var sharedObject: RTMPSharedObject!
    var currentPosition: AVCaptureDevice.Position = .back

    @IBOutlet weak var torchButton: UIButton!
    @IBOutlet weak var cameraButton: UIButton!
    @IBOutlet weak var lfView: GLHKView!
    @IBOutlet weak var publishButton: UIButton!
    @IBOutlet weak var micButton: UIButton!
    @IBOutlet weak var bitrateControl: UISegmentedControl!

    override func viewDidLoad() {
        super.viewDidLoad()
        self.rtmpStream = RTMPStream(connection: self.rtmpConnection)
        self.rtmpStream.syncOrientation = true
        self.rtmpStream.captureSettings = [
            "sessionPreset": AVCaptureSession.Preset.hd1280x720.rawValue,
            "continuousAutofocus": true,
            "continuousExposure": true,
            "fps": 30.0
        ]
        self.rtmpStream.videoSettings = [
            "bitrate": 500 * 1024,
            "width": 720,
            "height": 1280,
        ]
        self.rtmpStream.audioSettings = ["sampleRate": 44_100, "bitrate": 96 * 1024]
        self.rtmpStream.mixer.recorder.delegate = RecorderDelegate()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.rtmpStream.attachAudio(AVCaptureDevice.default(for: .audio))
        self.rtmpStream.attachCamera(DeviceUtil.device(withPosition: self.currentPosition))
        self.lfView.attachStream(self.rtmpStream)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.rtmpStream.close()
        self.rtmpStream.dispose()
    }

    @IBAction func rotateCamera(_ sender: UIButton) {
        let position: AVCaptureDevice.Position = self.currentPosition == .back ? .front : .back
        let device = DeviceUtil.device(withPosition: position)
        self.rtmpStream.attachCamera(device)
        self.currentPosition = position
    }

    @IBAction func toggleTorch(_ sender: UIButton) {
        self.rtmpStream.torch = !self.rtmpStream.torch
        self.torchButton.setImage(UIImage(named: self.rtmpStream.torch ? "torch_off_button" : "torch_on_button"), for: UIControlState())
    }

    @IBAction func onPauseMic(_ sender: UIButton) {
        if sender.isSelected {
            self.rtmpStream.audioSettings["muted"] = false
            self.micButton.setImage(UIImage(named: "mic_on_button"), for: UIControlState())
        } else {
            self.rtmpStream.audioSettings["muted"] = true
            self.micButton.setImage(UIImage(named: "mic_off_button"), for: UIControlState())
        }
        sender.isSelected = !sender.isSelected
    }

    @IBAction func on(publish: UIButton) {
        if publish.isSelected {
            // ロックしない
            UIApplication.shared.isIdleTimerDisabled = false
            self.rtmpConnection.close()
            self.rtmpConnection.removeEventListener(Event.RTMP_STATUS, selector: #selector(rtmpStatusHandler), observer: self)
            publish.setImage(UIImage(named: "play_button"), for: UIControlState())
        } else {
            UIApplication.shared.isIdleTimerDisabled = true
            self.rtmpConnection.addEventListener(Event.RTMP_STATUS, selector: #selector(rtmpStatusHandler), observer: self)
            self.rtmpConnection.connect(self.targetURL)
            publish.setImage(UIImage(named: "pause_button"), for: UIControlState())
        }
        publish.isSelected = !publish.isSelected
    }

    @objc func rtmpStatusHandler(_ notification: Notification) {
        let e: Event = Event.from(notification)
        if let data = e.data as? ASObject, let code = data["code"] as? String {
            switch code {
                case RTMPConnection.Code.connectSuccess.rawValue:
                    self.rtmpStream!.publish("myStream")
                default: break
            }
        }
    }
    
    @IBAction func onBitrateValueChanged(_ segment: UISegmentedControl) {
        var btrate = 500 * 1024
        switch segment.selectedSegmentIndex {
            case 0: btrate = 500 * 1024
            case 1: btrate = 1000 * 1024
            case 2: btrate = 1500 * 1024
            case 3: btrate = 2000 * 1024
            default: break
        }
        self.rtmpStream.videoSettings["bitrate"] = btrate
    }
}
