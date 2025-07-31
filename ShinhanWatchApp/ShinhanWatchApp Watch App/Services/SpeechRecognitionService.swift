//
//  SpeechRecognitionService.swift
//  ShinhanWatchApp
//
//  Created by 이정진 on 7/29/25.
//

import Foundation

class SpeechRecognitionService: ObservableObject {
    @Published var recognizedText = ""
    @Published var isRecognizing = false
    @Published var showDictation = false
    
    // 받아쓰기 시작 (audioURL 파라미터 제거)
    func recognizeSpeech() {
        isRecognizing = true
        showDictation = true
    }
    
    // 받아쓰기 완료 처리
    func handleDictationResult(_ text: String) {
        recognizedText = text
        isRecognizing = false
        showDictation = false
    }
    
    // 받아쓰기 취소 처리
    func handleDictationCancel() {
        isRecognizing = false
        showDictation = false
    }
}
