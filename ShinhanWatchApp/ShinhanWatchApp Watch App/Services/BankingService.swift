//
//  BankingService.swift
//  ShinhanWatchApp
//
//  Created by 이정진 on 7/29/25.
//

import Foundation
import Combine

class BankingService: ObservableObject {
    private let baseURL = "http://127.0.0.1:8080/api"
    private var accessToken: String?
    
    // MARK: - Authentication
    func login(username: String, password: String) async throws -> LoginResponse {
        let url = URL(string: "\(baseURL)/auth/login")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let loginRequest = LoginRequest(username: username, password: password)
        
        print("🔐 로그인 시도: \(username)")
        print("🔐 요청 URL: \(url)")
        
        do {
            request.httpBody = try JSONEncoder().encode(loginRequest)
        } catch {
            print("❌ JSON 인코딩 오류: \(error)")
            throw BankingError.networkError("요청 데이터 인코딩 실패")
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ HTTP 응답이 아님")
                throw BankingError.invalidResponse
            }
            
            print("🔐 응답 상태 코드: \(httpResponse.statusCode)")
            
            if let responseString = String(data: data, encoding: .utf8) {
                print("🔐 응답 데이터: \(responseString)")
            }
            
            if httpResponse.statusCode == 200 {
                do {
                    let loginResponse = try JSONDecoder().decode(LoginResponse.self, from: data)
                    self.accessToken = loginResponse.accessToken
                    print("✅ 로그인 성공! 토큰 저장됨: \(loginResponse.accessToken.prefix(10))...")
                    return loginResponse
                } catch {
                    print("❌ 로그인 응답 파싱 오류: \(error)")
                    throw BankingError.invalidResponse
                }
            } else {
                let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data)
                let errorMessage = errorResponse?.error ?? "로그인에 실패했습니다. (상태코드: \(httpResponse.statusCode))"
                print("❌ 로그인 실패: \(errorMessage)")
                throw BankingError.serverError(errorMessage)
            }
        } catch {
            if error is BankingError {
                throw error
            } else {
                print("❌ 네트워크 오류: \(error)")
                throw BankingError.networkError(error.localizedDescription)
            }
        }
    }
    
    // MARK: - Account Management
    func fetchAccounts() async throws -> [Account] {
        guard let token = accessToken else {
            print("❌ 토큰이 없음")
            throw BankingError.notAuthenticated
        }
        
        let url = URL(string: "\(baseURL)/accounts")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"  // 명시적으로 GET 설정
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        print("💳 계좌 조회 시도")
        print("💳 요청 URL: \(url)")
        print("💳 토큰: Bearer \(token.prefix(10))...")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ HTTP 응답이 아님")
                throw BankingError.invalidResponse
            }
            
            print("💳 응답 상태 코드: \(httpResponse.statusCode)")
            
            if let responseString = String(data: data, encoding: .utf8) {
                print("💳 응답 데이터: \(responseString)")
            }
            
            if httpResponse.statusCode == 200 {
                do {
                    // 먼저 raw JSON 구조 확인
                    if let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        print("💳 JSON 구조:")
                        print("💳 - success: \(jsonObject["success"] ?? "없음")")
                        print("💳 - count: \(jsonObject["count"] ?? "없음")")
                        
                        if let accounts = jsonObject["accounts"] as? [[String: Any]], !accounts.isEmpty {
                            print("💳 첫 번째 계좌 필드:")
                            for (key, value) in accounts[0] {
                                print("💳   - \(key): \(value)")
                            }
                        }
                    }
                    
                    let accountResponse = try JSONDecoder().decode(AccountResponse.self, from: data)
                    print("✅ 계좌 조회 성공! 계좌 수: \(accountResponse.accounts.count)")
                    
                    
                    return accountResponse.accounts
                } catch {
                    print("❌ 계좌 응답 파싱 오류: \(error)")
                    if let decodingError = error as? DecodingError {
                        print("❌ 디코딩 상세 오류: \(decodingError)")
                    }
                    throw BankingError.invalidResponse
                }
            } else if httpResponse.statusCode == 401 {
                print("❌ 인증 토큰 만료 또는 무효")
                self.accessToken = nil  // 토큰 초기화
                throw BankingError.notAuthenticated
            } else {
                let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data)
                let errorMessage = errorResponse?.error ?? "계좌 조회에 실패했습니다. (상태코드: \(httpResponse.statusCode))"
                print("❌ 계좌 조회 실패: \(errorMessage)")
                throw BankingError.serverError(errorMessage)
            }
        } catch {
            if error is BankingError {
                throw error
            } else {
                print("❌ 네트워크 오류: \(error)")
                throw BankingError.networkError(error.localizedDescription)
            }
        }
    }
    
    // MARK: - Voice Transfer (통합 API)
    func executeVoiceTransfer(audioData: Data, text: String) async throws -> TransferResult {
        guard let token = accessToken else {
            throw BankingError.notAuthenticated
        }
        
        let url = URL(string: "\(baseURL)/transfer/voice")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        // Multipart form data 생성
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        let body = createMultipartBody(boundary: boundary, audioData: audioData, text: text)
        request.httpBody = body
        
        print("🎤 음성 이체 요청: \(url)")
        print("🎤 텍스트: \(text)")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw BankingError.invalidResponse
            }
            
            print("🎤 응답 상태 코드: \(httpResponse.statusCode)")
            
            if let responseString = String(data: data, encoding: .utf8) {
                print("🎤 응답 데이터: \(responseString)")
            }
            
            if httpResponse.statusCode == 200 {
                return try JSONDecoder().decode(TransferResult.self, from: data)
            } else {
                let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data)
                let errorMessage = errorResponse?.error ?? "음성 이체 처리 중 오류가 발생했습니다."
                throw BankingError.serverError(errorMessage)
            }
        } catch {
            if error is BankingError {
                throw error
            } else {
                throw BankingError.networkError(error.localizedDescription)
            }
        }
    }
    
    // MARK: - Voice Profile Registration
    func registerVoiceProfile(audioData: Data) async throws -> VoiceRegistrationResult {
        guard let token = accessToken else {
            throw BankingError.notAuthenticated
        }
        
        let url = URL(string: "\(baseURL)/voice/register")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        // Multipart form data 생성
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"voice.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        print("🎙️ 음성 프로필 등록 요청: \(url)")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw BankingError.invalidResponse
            }
            
            print("🎙️ 응답 상태 코드: \(httpResponse.statusCode)")
            
            if let responseString = String(data: data, encoding: .utf8) {
                print("🎙️ 응답 데이터: \(responseString)")
            }
            
            if httpResponse.statusCode == 200 {
                return try JSONDecoder().decode(VoiceRegistrationResult.self, from: data)
            } else {
                let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data)
                throw BankingError.serverError(errorResponse?.error ?? "음성 프로필 등록에 실패했습니다.")
            }
        } catch {
            if error is BankingError {
                throw error
            } else {
                throw BankingError.networkError(error.localizedDescription)
            }
        }
    }
    
    // MARK: - Helper Methods
    private func createMultipartBody(boundary: String, audioData: Data, text: String) -> Data {
        var body = Data()
        
        // 오디오 파일 추가
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"voice.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        
        // 텍스트 추가
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"text\"\r\n\r\n".data(using: .utf8)!)
        body.append(text.data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        return body
    }
    
    // MARK: - Debug Methods
    func getStoredToken() -> String? {
        return accessToken
    }
    
    func clearToken() {
        accessToken = nil
        print("🔑 토큰 삭제됨")
    }
    
    // 토큰 유효성 테스트
    func testToken() async throws -> Bool {
        guard let token = accessToken else {
            print("❌ 토큰이 없음")
            return false
        }
        
        let url = URL(string: "\(baseURL)/debug/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        print("🔍 토큰 테스트 요청: \(url)")
        print("🔍 토큰: Bearer \(token.prefix(10))...")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🔍 토큰 테스트 응답 상태: \(httpResponse.statusCode)")
            }
            
            if let responseString = String(data: data, encoding: .utf8) {
                print("🔍 토큰 테스트 응답: \(responseString)")
            }
            
            return true
        } catch {
            print("❌ 토큰 테스트 실패: \(error)")
            return false
        }
    }
    
    // 헤더 디버깅 테스트
    func testHeaders() async throws {
        let url = URL(string: "\(baseURL)/debug/headers")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        print("🔍 헤더 테스트 요청: \(url)")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let responseString = String(data: data, encoding: .utf8) {
                print("🔍 헤더 테스트 응답: \(responseString)")
            }
        } catch {
            print("❌ 헤더 테스트 실패: \(error)")
        }
    }
}

// MARK: - Data Models
struct LoginRequest: Codable {
    let username: String
    let password: String
}

struct LoginResponse: Codable {
    let accessToken: String
    let userId: Int
    let username: String
    let success: Bool?  // 옵셔널로 변경
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case userId = "user_id"
        case username
        case success
    }
}

struct AccountResponse: Codable {
    let accounts: [Account]
    let count: Int
    let success: Bool?  // 옵셔널로 변경
}

struct ErrorResponse: Codable {
    let error: String
    let success: Bool?  // 옵셔널로 변경
}

struct VoiceRegistrationResult: Codable {
    let success: Bool
    let message: String
}

enum BankingError: Error, LocalizedError {
    case notAuthenticated
    case invalidResponse
    case serverError(String)
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "로그인이 필요합니다."
        case .invalidResponse:
            return "서버 응답이 올바르지 않습니다."
        case .serverError(let message):
            return message
        case .networkError(let message):
            return "네트워크 오류: \(message)"
        }
    }
}
