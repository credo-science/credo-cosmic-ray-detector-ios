//
//  CredoApi+Detection.swift
//  Cosmic Ray
//
//  Created by Maciek Siadkowski on 27/10/2021.
//

import Foundation
import Alamofire

// Detection api/v2/detection

struct Detection: Encodable {
    let timestamp: Int64
    let latitude: Float
    let longitude: Float
    let altitude: Float
    let accuracy: Float
    let provider: String
    let width: Int
    let height: Int
    let x: Int
    let y: Int
    let average: Float
    let blacks: Float
    let ax: Float
    let ay: Float
    let az: Float
    let orientation: Float
    let temperature: Float
    let id: Int
    let black_threshold: Int
    let frame_content: String
    let max: Int
}

// Can't use strict in objective-c
class DetectionWrapper: NSObject {
    @objc var timestamp: Int64 = 0
    @objc var latitude: Float = 0.0
    @objc var longitude: Float = 0.0
    @objc var altitude: Float = 0.0
    @objc var accuracy: Float = 0.0
    @objc var provider: String = "gps"
    @objc var width: Int = 0
    @objc var height: Int = 0
    @objc var x: Int = 0
    @objc var y: Int = 0
    @objc var average: Float = 0.0
    @objc var blacks: Float = 0.0
    @objc var ax: Float = 0.0
    @objc var ay: Float = 0.0
    @objc var az: Float = 0.0
    @objc var orientation: Float = 0.0
    @objc var temperature: Float = 0.0
    @objc var id: Int = 0
    @objc var black_threshold: Int = 0
    @objc var frame_content: String = ""
    @objc var max: Int = 0
    
    func map() -> Detection {
        return Detection(timestamp: timestamp, latitude: latitude, longitude: longitude, altitude: altitude, accuracy: accuracy, provider: provider, width: width, height: height, x: x, y: y, average: average, blacks: blacks, ax: ax, ay: ay, az: az, orientation: orientation, temperature: temperature, id: id, black_threshold: black_threshold, frame_content: frame_content, max: max)
    }
}

struct DetectionRequest: Encodable, CommonRequest {
    let detections: [Detection]
    let device_id: String
    let device_type: String
    let device_model: String
    let system_version: String
    let app_version: String
}

extension CredoApi {
    
    @objc func detection(_ detections: [DetectionWrapper], completion: ((Data?) -> Void)?) {
        let detectionList = detections.map { it in
            it.map()
        }
        let request = DetectionRequest(detections: detectionList, device_id: deviceID, device_type: deviceType, device_model: deviceModel, system_version: systemVersion, app_version: appVersion)
        
        let headers: HTTPHeaders = [
            "Authorization": "Token \(token)",
        ]
        AF.request("\(CredoApi.BASE_URL)/api/v2/detection",
                   method: .post,
                   parameters: request,
                   encoder: JSONParameterEncoder.default,
                   headers: headers
        ).response { response in
            let data = try? response.result.get()
            CredoApi.last_on_time = Int64(Date().timeIntervalSince1970 * 1000);
            completion?(data)
        }
    }
}
