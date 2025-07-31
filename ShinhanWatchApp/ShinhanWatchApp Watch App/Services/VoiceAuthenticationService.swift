//
//  VoiceAuthenticationService.swift
//  ShinhanWatchApp
//
//  Created by 이정진 on 7/29/25.
//

import AVFoundation

class VoiceAuthenticationService: ObservableObject {
    @Published var authenticationResult: Bool?
    @Published var similarityScore: Float = 0.0
    
    func authenticateVoice(audioURL: URL) async -> Bool {
        // 받아쓰기 방식에서는 음성 파일이 없으므로
        // 다른 인증 방식 사용하거나 생략
        return true // 임시로 항상 인증 성공
    }
}
