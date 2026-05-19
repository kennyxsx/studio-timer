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

/// True when `error` represents "the in-flight request was cancelled because
/// the caller went away" — typically a SwiftUI `.task` whose view disappeared
/// (tab switch, sheet dismiss, etc.) which auto-cancels its child Task and the
/// URLSession request inside it. These are NOT user-facing errors and should
/// never be surfaced as alerts; treat them like a no-op.
///
/// Catches three flavours:
///   1. Swift's `CancellationError` (from structured concurrency)
///   2. `URLError.cancelled` (from URLSession.data(for:) being cancelled)
///   3. `APIError.network(URLError.cancelled)` — our own wrapper around (2)
func isCancellation(_ error: Error) -> Bool {
    if error is CancellationError { return true }
    if let urlError = error as? URLError, urlError.code == .cancelled { return true }
    if case let APIError.network(inner) = error,
       let urlError = inner as? URLError,
       urlError.code == .cancelled {
        return true
    }
    return false
}
