//
//  Account.swift
//  ShinhanWatchApp
//
//  Created by 이정진 on 7/29/25.
//

import Foundation

struct Account: Codable, Identifiable {
    let id: Int
    let accountNumber: String
    let accountType: String
    let accountTypeName: String
    let balance: Int
    let balanceFormatted: String
    let ownerName: String
    let bankName: String
    let bankCode: String
    let maskedAccountNumber: String
    let isActive: Bool
    let createdAt: String
    
    // UI에서 사용할 computed properties
    var accountName: String {
        return "\(accountTypeName) 계좌"
    }
    
    // 서버가 camelCase로 보내므로 자동 매핑됨
    // CodingKeys 정의 불필요 (Swift가 자동으로 매핑)
    
    // 기존 코드와의 호환성을 위한 추가 init (필요시)
    init(id: Int, accountNumber: String, accountName: String, balance: Int, bankCode: String = "SH") {
        self.id = id
        self.accountNumber = accountNumber
        self.accountType = "checking"
        self.accountTypeName = accountName
        self.balance = balance
        self.balanceFormatted = "\(balance.formatted())원"
        self.ownerName = "사용자"
        self.bankName = "신한은행"
        self.bankCode = bankCode
        self.maskedAccountNumber = String(accountNumber.prefix(4)) + "****" + String(accountNumber.suffix(4))
        self.isActive = true
        self.createdAt = ISO8601DateFormatter().string(from: Date())
    }
}
