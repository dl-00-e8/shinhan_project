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
                Image("shinhan_logo")
                    .resizable()
                    .frame(width: 80, height: 30)
                
                NavigationLink("계좌 조회", destination: AccountView())
                    .buttonStyle(.borderedProminent)
                
                NavigationLink("이체하기", destination: TransferView())
                    .buttonStyle(.bordered)
            }
            .navigationTitle("신한은행")
        }
    }
}

#Preview {
    ContentView()
}
