//
//  TransferResult.swift
//  ShinhanWatchApp
//
//  Created by 이정진 on 7/29/25.
//

import Foundation

struct TransferResult: Codable {
    let isSuccess: Bool
    let message: String
    let transactionId: String?
    let timestamp: Date
}
