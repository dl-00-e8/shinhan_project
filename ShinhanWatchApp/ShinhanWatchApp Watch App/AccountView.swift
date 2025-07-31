//
//  AccountView.swift
//  ShinhanWatchApp
//
//  Created by 이정진 on 7/29/25.
//

import SwiftUI

struct AccountView: View {
    @StateObject private var viewModel = AccountViewModel()
    @State private var showingTransfer = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // 헤더
                headerView
                
                // 계좌 목록
                if viewModel.isLoading {
                    loadingView
                } else if viewModel.accounts.isEmpty {
                    emptyView
                } else {
                    accountListView
                }
                
                // 이체 버튼
                transferButton
            }
            .padding(.horizontal, 8)
        }
        .navigationTitle("내 계좌")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.loadAccounts()
        }
        .sheet(isPresented: $showingTransfer) {
            TransferView()
        }
        .refreshable {
            await viewModel.refreshAccounts()
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 4) {
            Text("신한은행")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("홍길동 님")
                .font(.headline)
                .fontWeight(.semibold)
        }
        .padding(.vertical, 8)
    }
    
    private var loadingView: some View {
        VStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.8)
            Text("계좌 정보 조회 중...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(height: 80)
    }
    
    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "creditcard")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            Text("등록된 계좌가 없습니다")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(height: 80)
    }
    
    private var accountListView: some View {
        LazyVStack(spacing: 8) {
            ForEach(viewModel.accounts) { account in
                AccountRowView(account: account)
            }
        }
    }
    
    private var transferButton: some View {
        Button(action: {
            showingTransfer = true
        }) {
            HStack {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 16))
                Text("이체하기")
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .background(Color.blue)
            .cornerRadius(18)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.top, 8)
    }
}

struct AccountRowView: View {
    let account: Account
    @State private var showingDetail = false
    
    var body: some View {
        Button(action: {
            showingDetail = true
        }) {
            VStack(spacing: 6) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(account.accountName)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Text(maskedAccountNumber)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(formattedBalance)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text("원")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                
                // 잔액 바 (시각적 표현)
                GeometryReader { geometry in
                    HStack(spacing: 2) {
                        ForEach(0..<5, id: \.self) { index in
                            Rectangle()
                                .fill(balanceColor(for: index))
                                .frame(height: 2)
                                .cornerRadius(1)
                        }
                    }
                }
                .frame(height: 2)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.gray.opacity(0.15))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingDetail) {
            AccountDetailView(account: account)
        }
    }
    
    private var maskedAccountNumber: String {
        let accountNumber = account.accountNumber
        guard accountNumber.count > 8 else { return accountNumber }
        
        let prefix = String(accountNumber.prefix(3))
        let suffix = String(accountNumber.suffix(4))
        return "\(prefix)-****-\(suffix)"
    }
    
    private var formattedBalance: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: account.balance)) ?? "0"
    }
    
    private func balanceColor(for index: Int) -> Color {
        let balanceLevel = min(account.balance / 1000000, 5) // 100만원 단위로 계산
        return index < balanceLevel ? .blue : .gray.opacity(0.3)
    }
}

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

// MARK: - AccountViewModel
class AccountViewModel: ObservableObject {
    @Published var accounts: [Account] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let bankingService = BankingService()
    
    func loadAccounts() {
        isLoading = true
        errorMessage = nil
        
        // 실제 구현에서는 BankingService를 통해 API 호출
        // 현재는 더미 데이터로 구현
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.accounts = self.createDummyAccounts()
            self.isLoading = false
        }
    }
    
    func refreshAccounts() async {
        await MainActor.run {
            isLoading = true
        }
        
        // 실제 API 호출 시뮬레이션
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        await MainActor.run {
            self.accounts = self.createDummyAccounts()
            self.isLoading = false
        }
    }
    
    private func createDummyAccounts() -> [Account] {
        return [
            Account(
                accountNumber: "356-12-345678",
                accountName: "신한 입출금통장",
                balance: 2480000,
                bankCode: "088"
            ),
            Account(
                accountNumber: "356-15-987654",
                accountName: "신한 적금통장",
                balance: 15600000,
                bankCode: "088"
            ),
            Account(
                accountNumber: "356-20-111222",
                accountName: "e-머니 계좌",
                balance: 127000,
                bankCode: "088"
            )
        ]
    }
}

// MARK: - Preview
#Preview {
    NavigationView {
        AccountView()
    }
}
