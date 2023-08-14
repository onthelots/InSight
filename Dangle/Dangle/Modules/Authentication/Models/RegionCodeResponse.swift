//
//  RegionCodeResponse.swift
//  Dangle
//
//  Created by Jae hyuk Yim on 2023/08/14.
//

import Foundation

// MARK: - Geocoding
struct RegionCodeResponse: Codable {
    let regcodes: [Regcode]
}

// MARK: - Regcode
struct Regcode: Codable {
    let code, name: String
}