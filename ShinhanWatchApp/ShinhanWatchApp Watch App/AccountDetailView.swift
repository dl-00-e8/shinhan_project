//
//  AccountDetailView.swift
//  ShinhanWatchApp
//
//  Created by 이정진 on 7/31/25.
//

import SwiftUI

struct AccountDetailView: View {
    let account: Account
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 계좌 정보 헤더
                VStack(spacing: 8) {
                    Text(account.accountName)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(account.accountNumber)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(formattedBalance + "원")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
                .padding(.vertical)
                
                Divider()
                
                // 최근 거래내역 (더미 데이터)
                VStack(alignment: .leading, spacing: 8) {
                    Text("최근 거래내역")
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    VStack(spacing: 6) {
                        TransactionRowView(
                            description: "ATM 출금",
                            amount: -50000,
                            date: "07/28"
                        )
                        
                        TransactionRowView(
                            description: "급여 입금",
                            amount: 3500000,
                            date: "07/25"
                        )
                        
                        TransactionRowView(
                            description: "카페 결제",
                            amount: -4500,
                            date: "07/24"
                        )
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal)
        }
        .navigationTitle("계좌 상세")
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
    
    private var formattedBalance: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: account.balance)) ?? "0"
    }
}

struct TransactionRowView: View {
    let description: String
    let amount: Int
    let date: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(description)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary)
                
                Text(date)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(formattedAmount)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(amount > 0 ? .blue : .red)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.gray.opacity(0.15))
        .cornerRadius(6)
    }
    
    private var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let sign = amount > 0 ? "+" : ""
        return sign + (formatter.string(from: NSNumber(value: amount)) ?? "0")
    }
}
