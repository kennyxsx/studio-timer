// StudioTimer/Services/APIClient.swift
import Foundation

/// Reads Studio backend mobile JSON API. Handles JWT bearer auth + 401 refresh.
actor APIClient {
    private let baseURL: URL
    private let keychain: KeychainStore
    private let session: URLSession

    init(baseURL: URL, keychain: KeychainStore = KeychainStore(), session: URLSession = .shared) {
        self.baseURL = baseURL
        self.keychain = keychain
        self.session = session
    }

    // MARK: - Public endpoints

    struct LoginResponse: Codable {
        let accessToken: String
        let refreshToken: String
        let user: User
        let workspaces: [Workspace]
        struct User: Codable {
            let id: String
            let email: String
            let name: String
        }
        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
            case user, workspaces
        }
    }

    func login(email: String, password: String) async throws -> LoginResponse {
        let req = try makeRequest(path: "/api/mobile/auth/login", method: "POST", body: [
            "email": email, "password": password,
        ], authed: false)
        return try await send(req)
    }

    func refresh() async throws -> String {
        guard let token = keychain.refreshToken else { throw APIError.unauthorized }
        let req = try makeRequest(path: "/api/mobile/auth/refresh", method: "POST", body: [
            "refresh_token": token,
        ], authed: false)
        struct R: Codable { let accessToken: String; enum CodingKeys: String, CodingKey { case accessToken = "access_token" } }
        let resp: R = try await send(req)
        try keychain.setAccessToken(resp.accessToken)
        return resp.accessToken
    }

    func logout() async throws {
        guard let refresh = keychain.refreshToken else { return }
        let req = try makeRequest(path: "/api/mobile/auth/logout", method: "POST", body: [
            "refresh_token": refresh,
        ], authed: true)
        _ = try await sendVoid(req)
        keychain.clearAll()
    }

    struct MeResponse: Codable {
        let user: LoginResponse.User
        let workspaces: [Workspace]
    }

    func me() async throws -> MeResponse {
        let req = try makeRequest(path: "/api/mobile/me", method: "GET", authed: true)
        return try await send(req)
    }

    // MARK: - Web session handoff

    /// Calls /api/mobile/auth/exchange-token to obtain a short-lived
    /// single-use token. The token is then used as `?token=X` on
    /// /auth/exchange in a WKWebView to set the web auth_token cookie
    /// without prompting for credentials a second time.
    func exchangeToken() async throws -> String {
        let req = try makeRequest(path: "/api/mobile/auth/exchange-token", method: "POST", authed: true)
        struct R: Codable {
            let exchangeToken: String
            enum CodingKeys: String, CodingKey {
                case exchangeToken = "exchange_token"
            }
        }
        let resp: R = try await send(req)
        return resp.exchangeToken
    }

    // Time entries

    struct EntriesList: Codable { let entries: [Entry] }

    func listEntries(workspaceID: String, from: Date, to: Date, status: Entry.Status? = nil) async throws -> [Entry] {
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "workspace_id", value: workspaceID),
            URLQueryItem(name: "from", value: Self.makeEncoder().iso(from)),
            URLQueryItem(name: "to", value: Self.makeEncoder().iso(to)),
        ]
        if let status { components.queryItems?.append(URLQueryItem(name: "status", value: status.rawValue)) }
        let path = "/api/mobile/time/entries?\(components.percentEncodedQuery ?? "")"
        let req = try makeRequest(path: path, method: "GET", authed: true)
        let resp: EntriesList = try await send(req)
        return resp.entries
    }

    struct CreateEntryRequest: Codable {
        let workspaceID: String
        let startedAt: Date
        let durationMinutes: Int
        let status: String
        enum CodingKeys: String, CodingKey {
            case workspaceID = "workspace_id"
            case startedAt = "started_at"
            case durationMinutes = "duration_minutes"
            case status
        }
    }

    func createDraft(workspaceID: String, startedAt: Date, durationMinutes: Int) async throws -> Entry {
        let body = CreateEntryRequest(workspaceID: workspaceID, startedAt: startedAt, durationMinutes: durationMinutes, status: "draft")
        let req = try makeRequest(path: "/api/mobile/time/entries", method: "POST", body: body, authed: true)
        return try await send(req)
    }

    /// Patch payload. Each field is `Optional`; nil means "omit this key" via the
    /// custom `encode(to:)` below. To explicitly clear `customerUserID` server-side,
    /// pass `clearCustomer: true`; otherwise the `customerUserID` field is sent
    /// only when non-nil.
    struct PatchEntryRequest: Encodable {
        var durationMinutes: Int?
        var customerUserID: String?
        var clearCustomer: Bool = false
        var splits: [Entry.Split]?
        var category: String?
        var notes: String?
        var status: String?

        enum CodingKeys: String, CodingKey {
            case durationMinutes = "duration_minutes"
            case customerUserID = "customer_user_id"
            case splits, category, notes, status
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encodeIfPresent(durationMinutes, forKey: .durationMinutes)
            if clearCustomer {
                try c.encodeNil(forKey: .customerUserID)
            } else if let cust = customerUserID {
                try c.encode(cust, forKey: .customerUserID)
            }
            try c.encodeIfPresent(splits, forKey: .splits)
            try c.encodeIfPresent(category, forKey: .category)
            try c.encodeIfPresent(notes, forKey: .notes)
            try c.encodeIfPresent(status, forKey: .status)
        }
    }

    func updateEntry(_ id: String, patch: PatchEntryRequest) async throws -> Entry {
        let req = try makeRequest(path: "/api/mobile/time/entries/\(id)", method: "PATCH", body: patch, authed: true)
        return try await send(req)
    }

    func deleteEntry(_ id: String) async throws {
        let req = try makeRequest(path: "/api/mobile/time/entries/\(id)", method: "DELETE", authed: true)
        _ = try await sendVoid(req)
    }

    // Lookups

    struct ProjectsList: Codable { let projects: [Project] }
    func listProjects(workspaceID: String) async throws -> [Project] {
        let req = try makeRequest(path: "/api/mobile/workspaces/\(workspaceID)/projects", method: "GET", authed: true)
        let resp: ProjectsList = try await send(req)
        return resp.projects
    }

    struct CustomersList: Codable { let customers: [Customer] }
    func listCustomers(workspaceID: String) async throws -> [Customer] {
        let req = try makeRequest(path: "/api/mobile/workspaces/\(workspaceID)/customers", method: "GET", authed: true)
        let resp: CustomersList = try await send(req)
        return resp.customers
    }

    struct CategoriesList: Codable { let categories: [String] }
    func listCategories(workspaceID: String) async throws -> [String] {
        let req = try makeRequest(path: "/api/mobile/workspaces/\(workspaceID)/time/categories", method: "GET", authed: true)
        let resp: CategoriesList = try await send(req)
        return resp.categories
    }

    // MARK: - Internals

    private func makeRequest(path: String, method: String, body: Encodable? = nil, authed: Bool) throws -> URLRequest {
        // `appendingPathComponent` is unsuitable when `path` already contains a
        // query string (`?`); resolve via URL(string:relativeTo:) instead.
        guard let url = URL(string: path, relativeTo: baseURL)?.absoluteURL else {
            throw APIError.network(URLError(.badURL))
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if authed, let token = keychain.accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            req.httpBody = try Self.makeEncoder().encode(AnyEncodable(body))
        }
        return req
    }

    private func send<T: Decodable>(_ request: URLRequest, retryOn401: Bool = true) async throws -> T {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.network(URLError(.badServerResponse)) }
        if http.statusCode == 401, retryOn401 {
            // Try refresh once.
            do {
                _ = try await self.refresh()
            } catch {
                keychain.clearAll()
                throw APIError.unauthorized
            }
            // Rebuild request with new access token and retry, without further refresh.
            var retried = request
            if let token = keychain.accessToken {
                retried.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            return try await send(retried, retryOn401: false)
        }
        if !(200..<300).contains(http.statusCode) {
            if let envelope = try? Self.makeDecoder().decode(APIErrorPayload.self, from: data) {
                throw APIError.http(status: http.statusCode, code: envelope.error.code, message: envelope.error.message)
            }
            throw APIError.http(status: http.statusCode, code: "UNKNOWN", message: "Request failed (\(http.statusCode))")
        }
        do {
            return try Self.makeDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }

    private func sendVoid(_ request: URLRequest, retryOn401: Bool = true) async throws {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.network(URLError(.badServerResponse)) }
        if http.statusCode == 401, retryOn401 {
            do { _ = try await self.refresh() } catch { keychain.clearAll(); throw APIError.unauthorized }
            var retried = request
            if let token = keychain.accessToken {
                retried.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            try await sendVoid(retried, retryOn401: false)
            return
        }
        if !(200..<300).contains(http.statusCode) {
            if let envelope = try? Self.makeDecoder().decode(APIErrorPayload.self, from: data) {
                throw APIError.http(status: http.statusCode, code: envelope.error.code, message: envelope.error.message)
            }
            throw APIError.http(status: http.statusCode, code: "UNKNOWN", message: "Request failed (\(http.statusCode))")
        }
    }

    static func makeDecoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let s = try container.decode(String.self)
            // Try with fractional seconds first (Go's default time.Time JSON format).
            let withFractional = ISO8601DateFormatter()
            withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = withFractional.date(from: s) { return date }
            // Fall back to plain ISO8601 (no fractional seconds).
            let plain = ISO8601DateFormatter()
            plain.formatOptions = [.withInternetDateTime]
            if let date = plain.date(from: s) { return date }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid ISO8601 date: \(s)")
        }
        return d
    }

    static func makeEncoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .custom { date, encoder in
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            var container = encoder.singleValueContainer()
            try container.encode(formatter.string(from: date))
        }
        return e
    }
}

private extension JSONEncoder {
    func iso(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}

/// Type-erased Encodable so a single `makeRequest` signature accepts any body type.
private struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void
    init(_ wrapped: Encodable) { self._encode = wrapped.encode }
    func encode(to encoder: Encoder) throws { try _encode(encoder) }
}
