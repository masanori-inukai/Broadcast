//
//  RTMPBroadcaster.swift
//  cast
//
//  Created by masanori on 2018/05/28.
//

import HaishinKit
import Foundation
import CoreMedia

@available(iOS 11.0, *)
public class RTMPBroadcaster: RTMPConnection {
    
    public lazy var stream: RTMPStream = {
        return RTMPStream(connection: self)
    }()

    private lazy var spliter: SoundSpliter = {
        var spliter: SoundSpliter = SoundSpliter()
        spliter.delegate = self
        return spliter
    }()
    
    private var connecting = false
    private let lockQueue = DispatchQueue(label: "com.masanori.inukai.broadcast.cast.lock")

    public override init() {
        super.init()
        addEventListener(Event.RTMP_STATUS, selector: #selector(rtmpStatusEvent), observer: self)
    }

    deinit {
        removeEventListener(Event.RTMP_STATUS, selector: #selector(rtmpStatusEvent), observer: self)
    }

    override public func connect(_ command: String, arguments: Any?...) {
        self.lockQueue.sync {
            if self.connecting { return }
            self.connecting = true
            self.spliter.clear()
            super.connect(command, arguments: arguments)
        }
    }

    func appendSampleBuffer(_ sampleBuffer: CMSampleBuffer, withType: CMSampleBufferType, options: [NSObject: AnyObject]? = nil) {
        self.stream.appendSampleBuffer(sampleBuffer, withType: withType)
    }

    override public func close() {
        self.lockQueue.sync {
            self.connecting = false
            super.close()
        }
    }

    @objc func rtmpStatusEvent(_ status: Notification) {
        let event = Event.from(status)
        guard let data = event.data as? ASObject, let code = data["code"] as? String else {
            return
        }
        
        switch code {
            case RTMPConnection.Code.connectSuccess.rawValue:
                self.stream.publish("myStream")
            default:
                // NOP
                break
        }
    }
}

@available(iOS 11.0, *)
extension RTMPBroadcaster: SoundSpliterDelegate {
    
    public func outputSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        self.stream.appendSampleBuffer(sampleBuffer, withType: .audio)
    }
}
