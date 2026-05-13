// StudioTimer/Models/Entry.swift
import Foundation

/// A time entry returned by `/api/mobile/time/entries`.
struct Entry: Codable, Identifiable, Equatable {
    let id: String
    let workspaceID: String
    let userID: String
    let customerUserID: String?
    let startedAt: Date
    let durationMinutes: Int
    let category: String?
    let notes: String?
    let splits: [Split]
    let status: Status
    let createdAt: Date
    let updatedAt: Date

    struct Split: Codable, Equatable {
        let projectID: String
        let percentage: Double

        enum CodingKeys: String, CodingKey {
            case projectID = "project_id"
            case percentage
        }
    }

    enum Status: String, Codable {
        case draft
        case classified
    }

    enum CodingKeys: String, CodingKey {
        case id
        case workspaceID = "workspace_id"
        case userID = "user_id"
        case customerUserID = "customer_user_id"
        case startedAt = "started_at"
        case durationMinutes = "duration_minutes"
        case category
        case notes
        case splits
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
