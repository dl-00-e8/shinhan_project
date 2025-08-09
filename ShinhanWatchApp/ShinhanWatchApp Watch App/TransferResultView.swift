//
//  TransferResultView.swift
//  ShinhanWatchApp
//
//  Created by 이정진 on 8/10/25.
//

import SwiftUI

struct TransferResultView: View {
    let result: TransferResult
    let onClose: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerView
                transactionDetailsView
                actionButtons
            }
            .padding()
        }
        .navigationTitle(result.isSuccess ? "이체 완료" : "이체 실패")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var headerView: some View {
        VStack(spacing: 12) {
            statusIcon
            statusTitle
            statusMessage
        }
        .padding(.vertical, 8)
    }
    
    private var statusIcon: some View {
        ZStack {
            Circle()
                .fill(result.isSuccess ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                .frame(width: 60, height: 60)
            
            Image(systemName: result.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 28))
                .foregroundColor(result.isSuccess ? .green : .red)
        }
    }
    
    private var statusTitle: some View {
        Text(result.isSuccess ? "이체 완료" : "이체 실패")
            .font(.headline)
            .fontWeight(.bold)
            .multilineTextAlignment(.center)
    }
    
    private var statusMessage: some View {
        Text(result.message ?? "처리가 완료되었습니다.")
            .font(.caption)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
    }
    
    private var transactionDetailsView: some View {
        VStack(spacing: 12) {
            Text("거래 내역")
                .font(.system(size: 14, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 8) {
                if result.isSuccess {
                    successDetails
                } else {
                    failureDetails
                }
            }
            .padding(12)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
        }
    }
    
    private var successDetails: some View {
        VStack(spacing: 6) {
            if let transactionId = result.transactionId {
                detailRow(title: "거래번호", value: transactionId)
            }
            
            if let amount = result.amount {
                detailRow(title: "이체 금액", value: formattedAmount(amount))
            }
            
            if let fee = result.fee {
                detailRow(title: "수수료", value: formattedAmount(fee))
            }
            
            if let amount = result.amount, let fee = result.fee {
                Divider()
                detailRow(title: "총 출금액", value: formattedAmount(amount + fee), isHighlight: true)
            }
            
            detailRow(title: "거래일시", value: formattedDateTime(result.timestamp ?? Date()))
        }
    }
    
    private var failureDetails: some View {
        VStack(spacing: 6) {
            if let amount = result.amount {
                detailRow(title: "이체 금액", value: formattedAmount(amount))
            }
            detailRow(title: "실패 시간", value: formattedDateTime(result.timestamp ?? Date()))
        }
    }
    
    private func detailRow(title: String, value: String, isHighlight: Bool = false) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 11, weight: isHighlight ? .bold : .medium))
                .foregroundColor(isHighlight ? .primary : .secondary)
        }
    }
    
    private var actionButtons: some View {
        VStack(spacing: 8) {
            if result.isSuccess {
                successButtons
            } else {
                failureButtons
            }
        }
    }
    
    private var successButtons: some View {
        VStack(spacing: 6) {
            Button("확인") {
                dismiss()
                onClose()
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 32)
            .background(Color.blue)
            .cornerRadius(16)
            
            Button("메인으로") {
                dismiss()
                onClose()
            }
            .font(.system(size: 11))
            .foregroundColor(.secondary)
        }
    }
    
    private var failureButtons: some View {
        VStack(spacing: 6) {
            Button("다시 시도") {
                dismiss()
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 32)
            .background(Color.blue)
            .cornerRadius(16)
            
            Button("취소") {
                dismiss()
                onClose()
            }
            .font(.system(size: 11))
            .foregroundColor(.secondary)
        }
    }
    
    private func formattedAmount(_ amount: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let formattedNumber = formatter.string(from: NSNumber(value: amount)) ?? "0"
        return "\(formattedNumber)원"
    }
    
    private func formattedDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationView {
        TransferResultView(
            result: TransferResult(
                success: true,
                message: "김철수님에게 50,000원 이체가 완료되었습니다."
            ),
            onClose: {}
        )
    }
}
