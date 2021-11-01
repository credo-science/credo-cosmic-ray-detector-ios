//
//  CredoApi+Ping.swift
//  Cosmic Ray
//
//  Created by Michał Frontczak on 01/11/2021.
//

import Foundation
import Alamofire

struct PingRequest: Encodable, CommonRequest {
    let device_id: String
    let device_type: String
    let device_model: String
    let system_version: String
    let app_version: String
    let on_time: Int
    let delta_time: Int64
    let timestamp: Int64
}

extension CredoApi {
    @objc func ping() {
        let request = PingRequest(device_id: appVersion, device_type: deviceID, device_model: deviceType, system_version: deviceModel, app_version: appVersion, on_time: 0, delta_time: 0, timestamp: Int64(Date().timeIntervalSince1970 * 1000)
        )
        
        let headers: HTTPHeaders = [
            "Authorization": "Token \(token)"
        ]
        
        AF.request("\(CredoApi.BASE_URL)/api/v2/ping",
                    method: .post,
                    parameters: request,
                    encoder: JSONParameterEncoder.default,
                    headers: headers
        ).response { response in
        }
    }
}
