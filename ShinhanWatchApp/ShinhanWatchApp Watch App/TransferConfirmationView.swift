//
//  TransferConfirmationView.swift
//  ShinhanWatchApp
//
//  Created by 이정진 on 7/29/25.
//

import SwiftUI

struct TransferConfirmationView: View {
    let transferRequest: TransferRequest
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = TransferConfirmationViewModel()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerView
                transferInfoView
                buttonView
                
                if viewModel.isProcessing {
                    processingView
                }
                
                if let result = viewModel.transferResult {
                    resultView(result: result)
                }
            }
            .padding()
        }
        .navigationTitle("이체 확인")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var headerView: some View {
        VStack(spacing: 8) {
            Image(systemName: "arrow.right.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.blue)
            
            Text("이체 정보를 확인하세요")
                .font(.headline)
                .fontWeight(.semibold)
        }
        .padding(.vertical)
    }
    
    private var transferInfoView: some View {
        VStack(spacing: 12) {
            infoRow(title: "받는 사람", value: transferRequest.recipientName, icon: "person.fill")
            Divider()
            infoRow(title: "이체 금액", value: formattedAmount, icon: "won.sign.circle.fill")
            Divider()
            infoRow(title: "보내는 계좌", value: transferRequest.fromAccount ?? "기본 계좌", icon: "creditcard.fill")
            
            if let memo = transferRequest.memo, !memo.isEmpty {
                Divider()
                infoRow(title: "메모", value: memo, icon: "text.bubble.fill")
            }
        }
        .padding()
        .background(Color.gray.opacity(0.15))
        .cornerRadius(12)
    }
    
    private func infoRow(title: String, value: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.blue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
    }
    
    private var buttonView: some View {
        VStack(spacing: 12) {
            Button(action: {
                Task {
                    await viewModel.executeVoiceTransfer(with: transferRequest.recipientName + " " + String(transferRequest.amount) + "원")
                }
            }) {
                HStack {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 16))
                    Text("이체 실행")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color.blue)
                .cornerRadius(22)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(viewModel.isProcessing)
            
            Button("취소") {
                dismiss()
            }
            .buttonStyle(.bordered)
        }
    }
    
    private var processingView: some View {
        VStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.8)
            Text("이체 처리 중...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
    
    private func resultView(result: TransferResult) -> some View {
        VStack(spacing: 12) {
            resultIcon(isSuccess: result.isSuccess)
            resultTitle(isSuccess: result.isSuccess)
            resultMessage(result.message)
            resultButtons(result: result)
        }
        .padding()
        .background(Color.gray.opacity(0.15))
        .cornerRadius(12)
    }
    
    private func resultIcon(isSuccess: Bool) -> some View {
        Image(systemName: isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
            .font(.system(size: 32))
            .foregroundColor(isSuccess ? .green : .red)
    }
    
    private func resultTitle(isSuccess: Bool) -> some View {
        Text(isSuccess ? "이체 완료" : "이체 실패")
            .font(.headline)
            .fontWeight(.semibold)
    }
    
    private func resultMessage(_ message: String?) -> some View {
        Text(message ?? "처리가 완료되었습니다.")
            .font(.body)
            .multilineTextAlignment(.center)
            .foregroundColor(.secondary)
    }
    
    private func resultButtons(result: TransferResult) -> some View {
        Group {
            if result.isSuccess {
                Button("확인") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .padding(.top)
            } else {
                HStack {
                    Button("다시 시도") {
                        Task {
                            await viewModel.executeVoiceTransfer(with: transferRequest.recipientName + " " + String(transferRequest.amount) + "원")
                        }
                    }
                    .buttonStyle(.bordered)
                    
                    Button("취소") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.top)
            }
        }
    }
    
    private var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let formattedNumber = formatter.string(from: NSNumber(value: transferRequest.amount)) ?? "0"
        return "\(formattedNumber)원"
    }
}

#Preview {
    let sampleRequest = TransferRequest(
        recipientName: "홍길동",
        amount: 100000,
        fromAccount: "356-12-345678",
        memo: "용돈",
        voiceAuthenticationScore: 0.95
    )
    
    NavigationView {
        TransferConfirmationView(transferRequest: sampleRequest)
    }
}
