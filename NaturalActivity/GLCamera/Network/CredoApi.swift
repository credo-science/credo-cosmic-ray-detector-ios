//
//  CredoApi.swift
//  Cosmic Ray
//
//  Created by Maciek Siadkowski on 19/10/2021.
//

import UIKit
import Alamofire

class CredoApi: NSObject {
    
    #if DEBUG
    static let BASE_URL = "https://api.credo.science"
    #else
    static let BASE_URL = "http://46.101.167.242"
    #endif
    
    // Singleton
    @objc static let shared = CredoApi()
    
    var token: String = ""
    
    internal lazy var deviceID: String = {
        UIDevice.current.identifierForVendor?.uuidString ?? ""
    }()
    
    internal lazy var deviceType: String = {
        UIDevice.current.model
    }()

    internal lazy var deviceModel: String = {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        return machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
    }()
    
    internal lazy var systemVersion: String = {
        "iOS \(ProcessInfo.processInfo.operatingSystemVersionString)"
    }()
    
    internal lazy var appVersion: String = {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
    }()
    
    private override init() {
        // TODO: Consider add API Timeout
    }
}

protocol CommonRequest {
    var device_id: String { get }
    var device_type: String { get }
    var device_model: String { get }
    var system_version: String { get }
    var app_version: String { get }
}
