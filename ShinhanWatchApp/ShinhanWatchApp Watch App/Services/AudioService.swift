//
//  AudioService.swift
//  ShinhanWatchApp
//
//  Created by 이정진 on 7/29/25.
//

import AVFoundation
import WatchKit

class AudioService: NSObject, ObservableObject {
    private var audioRecorder: AVAudioRecorder?
    private var audioSession: AVAudioSession = AVAudioSession.sharedInstance()
    
    @Published var isRecording = false
    @Published var recordingURL: URL?
    
    func startRecording() {
        // 권한 확인 및 녹음 시작
        requestMicrophonePermission { [weak self] granted in
            if granted {
                self?.beginRecording()
            }
        }
    }
    
    func stopRecording() {
        audioRecorder?.stop()
        isRecording = false
    }
    
    private func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        audioSession.requestRecordPermission { granted in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }
    
    private func beginRecording() {
        // 녹음 설정 및 시작 로직
    }
}
