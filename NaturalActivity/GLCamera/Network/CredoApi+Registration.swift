//
//  CredoApi+Registration.swift
//  Cosmic Ray
//
//  Created by Michał Frontczak on 13/03/2022.
//

import Foundation
import Alamofire

// User Login /api/v2/user/register
struct RegisterDeviceRequest: Encodable, CommonRequest {
    let email: String?
    let username: String?
    let display_name: String
    let password: String
    let team: String?
    let language: String?
    let device_id: String
    let device_type: String
    let device_model: String
    let system_version: String
    let app_version: String
}

struct RegisterDeviceResponse: Decodable {
    let message: String?
    let username: String
    let display_name: String
    let email: String
    let team: String
    let language: String
    let token: String
}

enum RegisterDeviceError: Error {
    case invalidUserNameOrEmail
    case unknown
}

extension CredoApi {
    
    func registerDevice(email: String,
                        username: String,
                        display_name: String,
                        password: String,
                        team: String?,
                        completion: @escaping (Result<RegisterDeviceResponse, RegisterDeviceError>) -> Void) {
        let request = RegisterDeviceRequest(email: email,
                                            username: username,
                                            display_name: display_name,
                                            password: password,
                                            team: team,
                                            language: Locale.current.languageCode,
                                            device_id: deviceID,
                                            device_type: deviceType,
                                            device_model: deviceModel,
                                            system_version: systemVersion,
                                            app_version: appVersion)
        CredoApi.last_on_time = Int64(Date().timeIntervalSince1970 * 1000);
        
        AF.request("\(CredoApi.BASE_URL)/api/v2/user/register",
                method: .post,
                parameters: request,
                encoder: JSONParameterEncoder.default
        ).responseDecodable(of: RegisterDeviceResponse.self) { response in
            debugPrint(response)

            switch response.result {
            case .success(let RegisterDeviceResponse):
                completion(.success(RegisterDeviceResponse))
            case .failure(_):
                if let data = response.data,
                   let apiError = try? JSONDecoder().decode(CredoApiError.self, from: data) {
                    // TODO: Find other errors in documentation
                    completion(.failure(RegisterDeviceError.invalidUserNameOrEmail))
                } else {
                    completion(.failure(RegisterDeviceError.unknown))
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
