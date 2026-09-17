//
//  UserProfile.swift
//  NAGORI
//

import Foundation

struct UserProfile: Codable, Identifiable, Equatable {
    let id: UUID
    var userName: String
    var iconUrl: String?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userName = "user_name"
        case iconUrl = "icon_url"
        case createdAt = "created_at"
    }
}
