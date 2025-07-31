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
                // 헤더
                headerView
                
                // 이체 정보
                transferInfoView
                
                // 버튼들
                buttonView
                
                // 처리 상태
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
            // 받는 사람
            infoRow(title: "받는 사람", value: transferRequest.recipientName, icon: "person.fill")
            
            Divider()
            
            // 이체 금액
            infoRow(title: "이체 금액", value: formattedAmount, icon: "won.sign.circle.fill")
            
            Divider()
            
            // 보내는 계좌
            infoRow(title: "보내는 계좌", value: transferRequest.fromAccount, icon: "creditcard.fill")
            
            if let memo = transferRequest.memo, !memo.isEmpty {
                Divider()
                infoRow(title: "메모", value: memo, icon: "text.bubble.fill")
            }
            
            // 인증 점수 (개발용)
            #if DEBUG
            Divider()
            infoRow(title: "인증 점수", value: String(format: "%.2f", transferRequest.voiceAuthenticationScore), icon: "checkmark.shield.fill")
            #endif
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
            // 이체 실행 버튼
            Button(action: {
                viewModel.executeTransfer(transferRequest)
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
            
            // 취소 버튼
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
            Image(systemName: result.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 32))
                .foregroundColor(result.isSuccess ? .green : .red)
            
            Text(result.isSuccess ? "이체 완료" : "이체 실패")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(result.message)
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
                        viewModel.executeTransfer(transferRequest)
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
        .padding()
        .background(Color.gray.opacity(0.15))
        .cornerRadius(12)
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
