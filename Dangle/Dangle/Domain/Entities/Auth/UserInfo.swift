//
//  User.swift
//  Dangle
//
//  Created by Jae hyuk Yim on 2023/08/18.
//

import Foundation

struct UserInfo: Codable {
    let email: String
    let password: String?
    let location: String?
    let nickname: String?
    let longitude: String?
    let latitude: String?
}
