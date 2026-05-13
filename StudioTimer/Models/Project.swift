// StudioTimer/Models/Project.swift
import Foundation

struct Project: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let customerID: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case customerID = "customer_id"
    }
}
