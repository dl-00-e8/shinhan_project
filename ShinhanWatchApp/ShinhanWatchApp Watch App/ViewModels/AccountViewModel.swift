//
//  AccountViewModel.swift
//  ShinhanWatchApp
//
//  Created by 이정진 on 7/29/25.
//

import SwiftUI

class AccountViewModel: ObservableObject {
    @Published var accounts: [Account] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isAuthenticated = false
    @Published var username: String = ""
    
    private let bankingService = BankingService()
    
    init() {
        // 자동 로그인 시도 (테스트용)
        Task {
            await autoLogin()
        }
    }
    
    // MARK: - Authentication
    private func autoLogin() async {
        await login(username: "testuser1", password: "password")
    }
    
    func login(username: String, password: String) async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let response = try await bankingService.login(username: username, password: password)
            
            await MainActor.run {
                self.isAuthenticated = true
                self.username = response.username
                self.isLoading = false
            }
            
            // 로그인 성공 후 계좌 정보 자동 로드
            await loadAccounts()
            
        } catch {
            await MainActor.run {
                self.isAuthenticated = false
                self.isLoading = false
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    // MARK: - Account Management
    func loadAccounts() async {
        guard isAuthenticated else {
            await MainActor.run {
                errorMessage = "로그인이 필요합니다."
            }
            return
        }
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let fetchedAccounts = try await bankingService.fetchAccounts()
            
            await MainActor.run {
                self.accounts = fetchedAccounts
                self.isLoading = false
            }
            
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    func refreshAccounts() async {
        await loadAccounts()
    }
}
