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
    
    // 받아쓰기 시작
    func recognizeSpeech() {
        isRecognizing = true
        showDictation = true
        
        // WatchOS에서는 시스템 받아쓰기를 사용
        // 실제 구현에서는 WKInterfaceController의 presentTextInputController 사용
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

