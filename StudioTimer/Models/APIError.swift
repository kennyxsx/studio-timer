// StudioTimer/Models/APIError.swift
import Foundation

/// Matches the backend `{ "error": { "code": "...", "message": "..." } }` envelope.
struct APIErrorPayload: Codable {
    let error: Inner
    struct Inner: Codable {
        let code: String
        let message: String
    }
}

enum APIError: Error, LocalizedError {
    case network(Error)
    case decoding(Error)
    case http(status: Int, code: String, message: String)
    case unauthorized
    case offline

    var errorDescription: String? {
        switch self {
        case .network(let e): return "Network error: \(e.localizedDescription)"
        case .decoding(let e): return "Response decoding failed: \(e.localizedDescription)"
        case .http(_, _, let msg): return msg
        case .unauthorized: return "Sign in again."
        case .offline: return "You're offline."
        }
    }
}
