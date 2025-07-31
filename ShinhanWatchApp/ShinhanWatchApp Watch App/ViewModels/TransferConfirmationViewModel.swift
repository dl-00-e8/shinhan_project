//
//  TransferConfirmationViewModel.swift
//  ShinhanWatchApp
//
//  Created by 이정진 on 7/31/25.
//

import Foundation

class TransferConfirmationViewModel: ObservableObject {
    @Published var isProcessing = false
    @Published var transferResult: TransferResult?
    
    private let bankingService = BankingService()
    
    func executeTransfer(_ request: TransferRequest) {
        isProcessing = true
        transferResult = nil
        
        Task {
            // 실제 구현에서는 BankingService를 통해 API 호출
            let result = await performTransfer(request)
            
            await MainActor.run {
                self.isProcessing = false
                self.transferResult = result
            }
        }
    }
    
    private func performTransfer(_ request: TransferRequest) async -> TransferResult {
        // 실제 이체 처리 시뮬레이션
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2초 대기
        
        // 임시로 랜덤 성공/실패
        let isSuccess = Bool.random()
        
        if isSuccess {
            return TransferResult(
                isSuccess: true,
                message: "\(request.recipientName)님에게 \(formattedAmount(request.amount))이 성공적으로 이체되었습니다.",
                transactionId: "TXN\(Date().timeIntervalSince1970)",
                timestamp: Date()
            )
        } else {
            return TransferResult(
                isSuccess: false,
                message: "잔액 부족 또는 네트워크 오류로 이체에 실패했습니다.",
                transactionId: nil,
                timestamp: Date()
            )
        }
    }
    
    private func formattedAmount(_ amount: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return (formatter.string(from: NSNumber(value: amount)) ?? "0") + "원"
    }
}
