//
//  TransferParsingService.swift
//  ShinhanWatchApp
//
//  Created by 이정진 on 7/29/25.
//

import Foundation

class TransferParsingService {
    func parseTransferInfo(from text: String) -> TransferRequest? {
        // 정규식 또는 NLP를 활용한 파싱
        let patterns = [
            "([가-힣]+)에게 ([0-9,]+)원",
            "([가-힣]+) ([0-9,]+)원 보내",
            "([0-9,]+)원을 ([가-힣]+)에게"
        ]
        
        for pattern in patterns {
            if let result = parseWithPattern(text: text, pattern: pattern) {
                return result
            }
        }
        
        return nil
    }
    
    private func parseWithPattern(text: String, pattern: String) -> TransferRequest? {
        // 정규식 매칭 로직
        let regex = try? NSRegularExpression(pattern: pattern)
        // 구현 로직...
        return nil
    }
}
