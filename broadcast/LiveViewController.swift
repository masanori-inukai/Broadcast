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
    fileprivate let targetURL = "rtmp://[username]:[password]@[ip]:[port]/[application name]"
    
    var rtmpConnection: RTMPConnection = RTMPConnection()
    var rtmpStream: RTMPStream!
    var sharedObject: RTMPSharedObject!
    var currentEffect: VisualEffect?
    var currentPosition: AVCaptureDevice.Position = .back

    @IBOutlet var lfView: GLHKView?
    @IBOutlet var publishButton: UIButton?
    @IBOutlet var pauseButton: UIButton?
    @IBOutlet var videoBitrateLabel: UILabel?
    @IBOutlet var videoBitrateSlider: UISlider?
    @IBOutlet var audioBitrateLabel: UILabel?
    @IBOutlet var audioBitrateSlider: UISlider?
    @IBOutlet var fpsControl: UISegmentedControl?

    override func viewDidLoad() {
        super.viewDidLoad()
        self.rtmpStream = RTMPStream(connection: self.rtmpConnection)
        self.rtmpStream.syncOrientation = true
        self.rtmpStream.captureSettings = [
            "sessionPreset": AVCaptureSession.Preset.hd1280x720.rawValue,
            "continuousAutofocus": true,
            "continuousExposure": true
        ]
        self.rtmpStream.videoSettings = ["width": 720, "height": 1280]
        self.rtmpStream.audioSettings = ["sampleRate": 44_100]
        self.rtmpStream.mixer.recorder.delegate = RecorderDelegate()

        self.videoBitrateSlider?.value = Float(RTMPStream.defaultVideoBitrate) / 1024
        self.audioBitrateSlider?.value = Float(RTMPStream.defaultAudioBitrate) / 1024
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.rtmpStream.attachAudio(AVCaptureDevice.default(for: .audio))
        self.rtmpStream.attachCamera(DeviceUtil.device(withPosition: self.currentPosition))
        self.lfView?.attachStream(self.rtmpStream)
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
    }

    @IBAction func on(slider: UISlider) {
        if slider == self.audioBitrateSlider {
            self.audioBitrateLabel?.text = "音声 \(Int(slider.value))/kbps"
            self.rtmpStream.audioSettings["bitrate"] = slider.value * 1024
        }
        if slider == self.videoBitrateSlider {
            self.videoBitrateLabel?.text = "映像 \(Int(slider.value))/kbps"
            self.rtmpStream.videoSettings["bitrate"] = slider.value * 1024
        }
    }

    @IBAction func on(pause: UIButton) {
        self.rtmpStream.togglePause()
        
        if pause.isSelected {
            pause.setTitle("P", for: [])
        } else {
            pause.setTitle("M", for: [])
        }
        pause.isSelected = !pause.isSelected
    }

    @IBAction func on(publish: UIButton) {
        if publish.isSelected {
            UIApplication.shared.isIdleTimerDisabled = false
            self.rtmpConnection.close()
            self.rtmpConnection.removeEventListener(Event.RTMP_STATUS, selector: #selector(rtmpStatusHandler), observer: self)
            publish.setTitle("●", for: [])
        } else {
            // ロックしない
            UIApplication.shared.isIdleTimerDisabled = true
            self.rtmpConnection.addEventListener(Event.RTMP_STATUS, selector: #selector(rtmpStatusHandler), observer: self)
            self.rtmpConnection.connect(self.targetURL)
            publish.setTitle("■", for: [])
        }
        publish.isSelected = !publish.isSelected
    }

    @objc func rtmpStatusHandler(_ notification: Notification) {
        let e: Event = Event.from(notification)
        if let data = e.data as? ASObject, let code = data["code"] as? String {
            switch code {
                case RTMPConnection.Code.connectSuccess.rawValue:
                    self.rtmpStream!.publish("myStream")
                default:
                    // NOP
                    break
            }
        }
    }

    @IBAction func onFPSValueChanged(_ segment: UISegmentedControl) {
        switch segment.selectedSegmentIndex {
            case 0:
                self.rtmpStream.captureSettings["fps"] = 15.0
            case 1:
                self.rtmpStream.captureSettings["fps"] = 30.0
            case 2:
                self.rtmpStream.captureSettings["fps"] = 60.0
            default:
                // NOP
                break
        }
    }
}
