//
//  CreadoApi+Login.swift
//  Cosmic Ray
//
//  Created by Maciek Siadkowski on 20/10/2021.
//

import Foundation
import Alamofire

// User Login /api/v2/user/login

struct LoginRequest: Encodable, CommonRequest {
    let email: String?
    let username: String?
    let password: String
    let device_id: String
    let device_type: String
    let device_model: String
    let system_version: String
    let app_version: String

    func copy(email: String?, username: String?) -> LoginRequest {
        LoginRequest(email: email, username: username, password: self.password, device_id: self.device_id, device_type: self.device_type, device_model: self.device_model, system_version: self.system_version, app_version: self.app_version)
    }
}

struct LoginResponse: Decodable {
    let message: String?
    let username: String
    let display_name: String
    let email: String
    let team: String
    let language: String
    let token: String
}

enum LoginError: Error {
    case invalidLoginAndPassword
    case unknown
}

extension CredoApi {
    
    func login(login: String,
               password: String,
               completion: @escaping (Result<LoginResponse, LoginError>) -> Void) {
        let trimmedLogin = login.trimmingCharacters(in: .whitespacesAndNewlines)
        var request = LoginRequest(email: nil, username: trimmedLogin, password: password, device_id: deviceID, device_type: deviceType, device_model: deviceModel, system_version: systemVersion, app_version: appVersion)
        let dataDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let range = NSMakeRange(0, NSString(string: trimmedLogin).length)
        let allMatches = dataDetector?.matches(in: trimmedLogin, options: [], range: range)
        let isEmail = allMatches?.count == 1 && allMatches?.first?.url?.absoluteString.contains("mailto:") == true
        if isEmail {
            request = request.copy(email: trimmedLogin, username: nil)
        }
        
        CredoApi.last_on_time = Int64(Date().timeIntervalSince1970 * 1000);
        
        AF.request("\(CredoApi.BASE_URL)/api/v2/user/login",
                method: .post,
                parameters: request,
                encoder: JSONParameterEncoder.default
        ).responseDecodable(of: LoginResponse.self) { response in
            debugPrint(response)

            switch response.result {
            case .success(let loginResponse):
                completion(.success(loginResponse))
            case .failure(_):
                if let data = response.data,
                   let apiError = try? JSONDecoder().decode(CredoApiError.self, from: data) {
                    // TODO: Find other errors in documentation
                    completion(.failure(LoginError.invalidLoginAndPassword))
                } else {
                    completion(.failure(LoginError.unknown))
                }
            }
        }
    }
}

extension LoginError {
    var localizedDescription: String {
        switch self {
        case .invalidLoginAndPassword:
            return "Invalid username/email and password combination or unverified email."
        case .unknown:
            return "Unknown error."
        }
    }
}
