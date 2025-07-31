//
//  VoiceRecordingView.swift
//  ShinhanWatchApp
//
//  Created by 이정진 on 7/29/25.
//

import SwiftUI

struct VoiceRecordingView: View {
    @StateObject private var audioService = AudioService()
    @StateObject private var speechService = SpeechRecognitionService()
    @StateObject private var voiceAuthService = VoiceAuthenticationService()
    
    @State private var showingConfirmation = false
    @State private var transferRequest: TransferRequest?
    @State private var dictationText = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("음성으로 이체 정보를 말해주세요")
                .font(.headline)
                .multilineTextAlignment(.center)
            
            // 받아쓰기 입력 필드
            TextField("예: 홍길동에게 10만원", text: $dictationText)
                .padding(8)
                .background(Color.gray.opacity(0.15))
                .cornerRadius(8)
                .onChange(of: dictationText) { newValue in
                    if !newValue.isEmpty {
                        speechService.handleDictationResult(newValue)
                    }
                }
            
            // 음성 입력 버튼
            Button(action: {
                speechService.recognizeSpeech()
                // 받아쓰기를 위해 텍스트 필드에 포커스
            }) {
                HStack {
                    Image(systemName: speechService.isRecognizing ? "mic.fill" : "mic.circle.fill")
                        .font(.system(size: 24))
                    Text(speechService.isRecognizing ? "음성 입력 중..." : "음성으로 입력하기")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(speechService.isRecognizing ? .red : .blue)
                .cornerRadius(22)
            }
            .buttonStyle(PlainButtonStyle())
            
            if !speechService.recognizedText.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("인식된 내용:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(speechService.recognizedText)
                        .font(.body)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                    
                    HStack {
                        Button("다시 입력") {
                            speechService.recognizedText = ""
                            dictationText = ""
                            speechService.recognizeSpeech()
                        }
                        .buttonStyle(.bordered)
                        
                        Spacer()
                        
                        Button("확인") {
                            processRecognizedText()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            
            // 예시 문장
            VStack(alignment: .leading, spacing: 4) {
                Text("음성 입력 예시:")
                    .font(.caption)
                    .fontWeight(.medium)
                
                Group {
                    Text("• 홍길동에게 10만원")
                    Text("• 김철수 5만원 보내줘")
                    Text("• 이영희에게 삼만원 이체")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.gray.opacity(0.15))
            .cornerRadius(8)
        }
        .padding()
        .navigationTitle("음성 이체")
        .sheet(isPresented: $showingConfirmation) {
            if let request = transferRequest {
                TransferConfirmationView(transferRequest: request)
            }
        }
    }
    
    private func processRecognizedText() {
        // 이체 정보 파싱
        let parsingService = TransferParsingService()
        if let request = parsingService.parseTransferInfo(from: speechService.recognizedText) {
            transferRequest = request
            showingConfirmation = true
        }
    }
}
