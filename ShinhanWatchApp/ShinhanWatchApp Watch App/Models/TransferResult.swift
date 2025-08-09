//
//  TransferResult.swift
//  ShinhanWatchApp
//
//  Created by 이정진 on 7/29/25.
//

import Foundation

struct TransferResult: Codable {
    let success: Bool
    let message: String?
    let transactionId: String?
    let amount: Int?
    let fee: Int?
    let timestamp: Date?
    
    // 편의 프로퍼티
    var isSuccess: Bool {
        return success
    }
    
    // 기본 초기화
    init(success: Bool, message: String? = nil, transactionId: String? = nil, amount: Int? = nil, fee: Int? = nil, timestamp: Date? = nil) {
        self.success = success
        self.message = message
        self.transactionId = transactionId
        self.amount = amount
        self.fee = fee
        self.timestamp = timestamp ?? Date()
    }
    
    // 서버 응답용 초기화 (BankingService에서 사용)
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        success = try container.decode(Bool.self, forKey: .success)
        message = try container.decodeIfPresent(String.self, forKey: .message)
        transactionId = try container.decodeIfPresent(String.self, forKey: .transactionId)
        amount = try container.decodeIfPresent(Int.self, forKey: .amount)
        fee = try container.decodeIfPresent(Int.self, forKey: .fee)
        
        // 타임스탬프는 ISO8601 문자열로 받아서 Date로 변환
        if let timestampString = try container.decodeIfPresent(String.self, forKey: .timestamp) {
            let formatter = ISO8601DateFormatter()
            timestamp = formatter.date(from: timestampString) ?? Date()
        } else {
            timestamp = Date()
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case success
        case message
        case transactionId
        case amount
        case fee
        case timestamp
    }
}
