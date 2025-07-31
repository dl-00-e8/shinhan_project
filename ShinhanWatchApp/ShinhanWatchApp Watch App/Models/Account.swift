//
//  Account.swift
//  ShinhanWatchApp
//
//  Created by 이정진 on 7/29/25.
//

import Foundation

struct Account: Codable, Identifiable {
    var id: UUID // 초기화는 따로
    let accountNumber: String
    let accountName: String
    let balance: Int
    let bankCode: String
    
    init(accountNumber: String, accountName: String, balance: Int, bankCode: String) {
        self.id = UUID()
        self.accountNumber = accountNumber
        self.accountName = accountName
        self.balance = balance
        self.bankCode = bankCode
    }
}
