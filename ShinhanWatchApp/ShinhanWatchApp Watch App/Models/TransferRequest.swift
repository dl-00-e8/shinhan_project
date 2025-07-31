//
//  TransferRequest.swift
//  ShinhanWatchApp
//
//  Created by 이정진 on 7/29/25.
//

struct TransferRequest: Codable {
    let recipientName: String
    let amount: Int
    let fromAccount: String
    let memo: String?
    let voiceAuthenticationScore: Float
}
