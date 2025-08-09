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
                
                // 로그인 상태 확인
                if !viewModel.isAuthenticated {
                    loginRequiredView
                } else if viewModel.isLoading {
                    loadingView
                } else if viewModel.accounts.isEmpty {
                    emptyView
                } else {
                    accountListView
                }
                
                // 오류 메시지
                if let errorMessage = viewModel.errorMessage {
                    errorView(message: errorMessage)
                }
                
                // 이체 버튼
                if viewModel.isAuthenticated && !viewModel.accounts.isEmpty {
                    transferButton
                }
            }
            .padding(.horizontal, 8)
        }
        .navigationTitle("내 계좌")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if viewModel.isAuthenticated {
                Task {
                    await viewModel.loadAccounts()
                }
            }
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
            HStack(spacing: 4) {
                Image(systemName: "building.columns.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 16))
                Text("신한은행")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text("\(viewModel.username)님" + (viewModel.username.isEmpty ? "고객" : ""))
                .font(.headline)
                .fontWeight(.semibold)
        }
        .padding(.vertical, 8)
    }
    
    private var loginRequiredView: some View {
        VStack(spacing: 8) {
            Image(systemName: "person.circle")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            Text("로그인 중...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(height: 80)
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
    
    private func errorView(message: String) -> some View {
        Text(message)
            .font(.caption)
            .foregroundColor(.red)
            .padding(.horizontal)
            .multilineTextAlignment(.center)
    }
    
    private var transferButton: some View {
        Button(action: {
            showingTransfer = true
        }) {
            HStack {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 16))
                Text("음성으로 이체하기")
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

// MARK: - Preview
#Preview {
    NavigationView {
        AccountView()
    }
}
