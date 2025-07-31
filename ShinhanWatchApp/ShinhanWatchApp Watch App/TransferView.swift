//
//  TransferView.swift
//  ShinhanWatchApp
//
//  Created by 이정진 on 7/29/25.
//

import SwiftUI

struct TransferView: View {
    @StateObject private var viewModel = TransferViewModel()
    
    var body: some View {
        VStack(spacing: 16) {
            Text("음성으로 이체 정보를 입력하세요")
                .font(.headline)
                .multilineTextAlignment(.center)

            // STT 텍스트 입력 필드
            // TransferView.swift에서도 수정 필요
            TextField("예: 홍길동에게 10만원", text: $viewModel.inputText)
                .padding(8)
                .background(Color.gray.opacity(0.15))
                .cornerRadius(8)
                .onChange(of: viewModel.inputText) { newValue in
                    viewModel.handleRecognizedText(newValue)
                }

            // 음성 입력 버튼
            Button("음성 입력 시작") {
                viewModel.startSpeechRecognition()
            }
            .buttonStyle(.borderedProminent)
            
            // 진행 상태
            if viewModel.isRecognizing {
                Text("음성 입력 대기 중...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if viewModel.showAuthError {
                Text("성문 인증에 실패했습니다.")
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            // 인식된 텍스트 표시
            if !viewModel.recognizedText.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("인식된 내용:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(viewModel.recognizedText)
                        .font(.body)
                        .padding()
                        .background(Color.gray.opacity(0.15))
                        .cornerRadius(8)
                    
                    HStack {
                        Button("다시 입력") {
                            viewModel.resetInput()
                        }
                        .buttonStyle(.bordered)
                        
                        Spacer()
                        
                        Button("확인") {
                            viewModel.processTransfer()
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
        .sheet(isPresented: $viewModel.showingConfirmation) {
            if let request = viewModel.transferRequest {
                TransferConfirmationView(transferRequest: request)
            }
        }
    }
}

