// StudioTimer/Models/Workspace.swift
import Foundation

struct Workspace: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let role: String
}
