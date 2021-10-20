//
//  CredoApiError.swift
//  Cosmic Ray
//
//  Created by Maciek Siadkowski on 20/10/2021.
//

import Foundation

struct CredoApiError: Error, Decodable {
    let message: String?
}
