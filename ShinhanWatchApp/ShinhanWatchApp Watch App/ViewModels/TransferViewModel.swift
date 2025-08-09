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
    @Published var isProcessing = false
    @Published var showAuthError = false
    @Published var showingConfirmation = false
    @Published var transferResult: TransferResult?
    @Published var errorMessage: String?
    
    private let speechService = SpeechRecognitionService()
    private let audioService = AudioService()
    private let bankingService = BankingService()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // SpeechService의 상태를 바인딩
        speechService.$recognizedText
            .receive(on: DispatchQueue.main)
            .assign(to: \.recognizedText, on: self)
            .store(in: &cancellables)
    }
    
    func startSpeechRecognition() {
        showAuthError = false
        errorMessage = nil
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
        errorMessage = nil
        transferResult = nil
        speechService.recognizedText = ""
    }
    
    func processVoiceTransfer() async {
        guard !recognizedText.isEmpty else {
            await MainActor.run {
                self.errorMessage = "음성 입력이 필요합니다."
            }
            return
        }
        
        await MainActor.run {
            self.isProcessing = true
            self.errorMessage = nil
            self.transferResult = nil
        }
        
        do {
            // 더미 오디오 데이터 생성 (실제로는 audioService.getAudioData() 사용)
            let dummyAudioData = Data([0x00, 0x01, 0x02, 0x03]) // 실제 구현시 제거
            
            let result = try await bankingService.executeVoiceTransfer(
                audioData: dummyAudioData,
                text: recognizedText
            )
            
            await MainActor.run {
                self.isProcessing = false
                self.transferResult = result
                
                if result.isSuccess {
                    self.showingConfirmation = true
                } else {
                    self.errorMessage = result.message
                }
            }
            
        } catch {
            await MainActor.run {
                self.isProcessing = false
                self.errorMessage = error.localizedDescription
            }
        }
    }
}
