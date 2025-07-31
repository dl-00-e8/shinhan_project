//
//  TransferViewModel.swift
//  ShinhanWatchApp
//
//  Created by 이정진 on 7/29/25.
//

import SwiftUI
import Combine

class TransferViewModel: ObservableObject {
    @Published var inputText = ""
    @Published var recognizedText = ""
    @Published var isRecognizing = false
    @Published var showAuthError = false
    @Published var showingConfirmation = false
    @Published var transferRequest: TransferRequest?
    
    private let speechService = SpeechRecognitionService()
    private let voiceAuthService = VoiceAuthenticationService()
    private let parsingService = TransferParsingService()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // SpeechService의 상태를 바인딩
        speechService.$recognizedText
            .receive(on: DispatchQueue.main)
            .assign(to: \.recognizedText, on: self)
            .store(in: &cancellables)
        
        speechService.$isRecognizing
            .receive(on: DispatchQueue.main)
            .assign(to: \.isRecognizing, on: self)
            .store(in: &cancellables)
    }
    
    func startSpeechRecognition() {
        showAuthError = false
        speechService.recognizeSpeech()
    }
    
    func handleRecognizedText(_ text: String) {
        if !text.isEmpty {
            recognizedText = text
            speechService.handleDictationResult(text)
        }
    }
    
    func resetInput() {
        inputText = ""
        recognizedText = ""
        showAuthError = false
        speechService.recognizedText = ""
    }
    
    func processTransfer() {
        // 이체 정보 파싱
        if let request = parsingService.parseTransferInfo(from: recognizedText) {
            // 성문 인증 (받아쓰기에서는 생략하거나 다른 방식 사용)
            Task {
                // 임시로 항상 인증 성공으로 처리
                let isAuthenticated = await authenticateUser()
                
                await MainActor.run {
                    if isAuthenticated {
                        self.transferRequest = request
                        self.showingConfirmation = true
                    } else {
                        self.showAuthError = true
                    }
                }
            }
        } else {
            // 파싱 실패 시 오류 표시
            showAuthError = true
        }
    }
    
    private func authenticateUser() async -> Bool {
        // 실제 구현에서는 다양한 인증 방식 사용
        // 예: PIN, 생체인증, 디바이스 잠금 상태 확인 등
        
        // 임시로 1초 대기 후 성공 반환
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        return true
    }
}
