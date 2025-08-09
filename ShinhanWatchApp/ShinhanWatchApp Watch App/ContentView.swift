//
//  ContentView.swift
//  ShinhanWatchApp Watch App
//
//  Created by 이정진 on 7/29/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var accountViewModel = AccountViewModel()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 로고 및 타이틀
                VStack(spacing: 8) {
                    Image("shinhan_logo")
                        .resizable()
                        .frame(width: 50, height: 50)
                    
                    Text("신한은행")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    if accountViewModel.isAuthenticated {
                        Text("\(accountViewModel.username)님")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // 메뉴 버튼들
                VStack(spacing: 12) {
                    NavigationLink(destination: AccountView()) {
                        HStack {
                            Image(systemName: "creditcard.fill")
                                .font(.system(size: 16))
                            Text("계좌 조회")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.blue)
                        .cornerRadius(22)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    NavigationLink(destination: TransferView()) {
                        HStack {
                            Image(systemName: "mic.circle.fill")
                                .font(.system(size: 16))
                            Text("음성 이체")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 22)
                                .stroke(Color.blue, lineWidth: 2)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // 연결 상태 표시
                connectionStatusView
            }
            .padding()
            .navigationBarHidden(true)
        }
    }
    
    private var connectionStatusView: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Circle()
                    .fill(accountViewModel.isAuthenticated ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                
                Text(accountViewModel.isAuthenticated ? "서버 연결됨" : "서버 연결 중...")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            
            if let errorMessage = accountViewModel.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 8))
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 20)
    }
}

#Preview {
    ContentView()
}
