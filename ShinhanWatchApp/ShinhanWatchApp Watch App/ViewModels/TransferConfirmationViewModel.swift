//
//  TransferConfirmationViewModel.swift
//  ShinhanWatchApp
//
//  Created by 이정진 on 7/31/25.
//

import Foundation
import SwiftUI

@MainActor
class TransferConfirmationViewModel: ObservableObject {
    @Published var isProcessing = false
    @Published var transferResult: TransferResult?
    @Published var errorMessage: String?
    
    private let bankingService = BankingService()
    
    func executeVoiceTransfer(with text: String) async {
        isProcessing = true
        errorMessage = nil
        transferResult = nil
        
        do {
            // 실제 서버 호출 시뮬레이션
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2초 대기
            
            // 성공적인 이체 결과 생성 (실제로는 서버에서 받음)
            let result = TransferResult(
                success: true,
                message: "이체가 성공적으로 완료되었습니다.",
                transactionId: "TX\(Int.random(in: 100000...999999))",
                amount: extractAmount(from: text),
                fee: 1000,
                timestamp: Date()
            )
            
            transferResult = result
            isProcessing = false
            
        } catch {
            // 실패 처리
            let failureResult = TransferResult(
                success: false,
                message: "이체 처리 중 오류가 발생했습니다.",
                transactionId: nil,
                amount: extractAmount(from: text),
                fee: nil,
                timestamp: Date()
            )
            
            transferResult = failureResult
            isProcessing = false
            errorMessage = error.localizedDescription
        }
    }
    
    private func extractAmount(from text: String) -> Int {
        // 간단한 금액 추출 로직
        let patterns = [
            (#"(\d+)\s*만\s*원"#, 10000),
            (#"(\d+)\s*천\s*원"#, 1000),
            (#"(\d+)\s*원"#, 1),
            (#"(\d+)\s*만"#, 10000),
            (#"(\d+)\s*천"#, 1000)
        ]
        
        for (pattern, multiplier) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text),
               let number = Int(String(text[range])) {
                return number * multiplier
            }
        }
        
        return 50000 // 기본값
    }
}
