//
//  KeychainManager.swift
//  Cosmic Ray
//
//  Created by Maciek Siadkowski on 20/10/2021.
//

import Foundation
import KeychainAccess

class KeychainManager {
    
    // Singleton
    static let shared = KeychainManager()
    
    private let keychain = Keychain(server: CredoApi.BASE_URL, protocolType: .https)
    
    private init() {}

    func saveCredentials(_ credentials: Credentials) {
        try? keychain.set(credentials.login, key: "login")
        try? keychain.set(credentials.password, key: "password")
    }
    
    func getCredentials() -> Credentials? {
        if let login = try? keychain.getString("login"),
           let password = try? keychain.getString("password") {
            return Credentials(login: login, password: password)
        } else {
            return nil
        }
    }
}
