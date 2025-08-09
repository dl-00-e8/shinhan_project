//
//  TransferView.swift
//  ShinhanWatchApp
//
//  Created by 이정진 on 7/29/25.
//

import SwiftUI

struct TransferView: View {
    @StateObject private var viewModel = TransferViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerView
                
                inputSection
                
                if viewModel.isProcessing {
                    processingView
                }
                
                if let errorMessage = viewModel.errorMessage {
                    errorView(message: errorMessage)
                }
                
                if let result = viewModel.transferResult {
                    resultView(result: result)
                }
                
                examplesView
            }
            .padding()
        }
        .navigationTitle("음성 이체")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("닫기") {
                    dismiss()
                }
                .font(.caption)
            }
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 8) {
            Image(systemName: "mic.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.blue)
            
            Text("음성으로 이체 정보를\n입력하세요")
                .font(.headline)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical)
    }
    
    private var inputSection: some View {
        VStack(spacing: 12) {
            TextField("예: 홍길동에게 10만원", text: $viewModel.inputText)
                .padding(8)
                .background(Color.gray.opacity(0.15))
                .cornerRadius(8)
                .onChange(of: viewModel.inputText) {
                    viewModel.handleRecognizedText(viewModel.inputText)
                }
            
            Button(action: {
                viewModel.startSpeechRecognition()
            }) {
                HStack {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 16))
                    Text("음성 입력 시작")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color.blue)
                .cornerRadius(22)
            }
            .buttonStyle(PlainButtonStyle())
            
            if !viewModel.recognizedText.isEmpty {
                recognizedTextView
            }
        }
    }
    
    private var recognizedTextView: some View {
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
                
                Button("이체 실행") {
                    Task {
                        await viewModel.processVoiceTransfer()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
    
    private var processingView: some View {
        VStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.8)
            Text("음성 인증 및 이체 처리 중...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.gray.opacity(0.15))
        .cornerRadius(8)
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 24))
                .foregroundColor(.red)
            
            Text(message)
                .font(.caption)
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
    }
    
    private func resultView(result: TransferResult) -> some View {
        VStack(spacing: 12) {
            Image(systemName: result.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 32))
                .foregroundColor(result.isSuccess ? .green : .red)
            
            Text(result.isSuccess ? "이체 완료" : "이체 실패")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(result.message ?? "처리가 완료되었습니다.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            if result.isSuccess {
                Button("확인") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .padding(.top)
            } else {
                HStack {
                    Button("다시 시도") {
                        viewModel.resetInput()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("닫기") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.top)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.15))
        .cornerRadius(12)
    }
    
    private var examplesView: some View {
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
}
