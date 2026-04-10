import Foundation
import MeowDomain

public struct AuthSession: Sendable, Equatable, Codable {
    public let userID: UUID
    public let provider: AuthProviderKind
    public let createdAt: Date

    public init(userID: UUID, provider: AuthProviderKind, createdAt: Date) {
        self.userID = userID
        self.provider = provider
        self.createdAt = createdAt
    }
}

public enum AuthError: Error, Equatable {
    case invalidEmail
    case weakPassword
    case invalidAppleToken
    case unauthorized
    case reauthenticationRequired
    case cannotUnlinkLastProvider
    case providerNotLinked
    case operationNotSupported
    case server(String)
}

public protocol AuthService: Sendable {
    func currentSession() async -> AuthSession?
    func signInWithEmail(email: String, password: String) async throws -> AuthSession
    func signInWithApple(identityToken: String) async throws -> AuthSession
    func linkEmailCredentialToCurrentUser(email: String, password: String) async throws -> AuthSession
    func linkedProviders() async throws -> [AuthProviderKind]
    func reauthenticateCurrentSession() async throws -> AuthSession
    func unlinkProvider(_ provider: AuthProviderKind) async throws -> AuthSession
    func signOut() async
}

public actor InMemoryAuthService: AuthService {
    private var session: AuthSession?
    private let userID: UUID
    private var providers: Set<AuthProviderKind> = []

    public init(seedUserID: UUID = UUID()) {
        self.userID = seedUserID
    }

    public func currentSession() async -> AuthSession? {
        session
    }

    public func signInWithEmail(email: String, password: String) async throws -> AuthSession {
        guard email.contains("@"), email.contains(".") else {
            throw AuthError.invalidEmail
        }
        guard password.count >= 8 else {
            throw AuthError.weakPassword
        }
        let next = AuthSession(userID: userID, provider: .email, createdAt: Date())
        session = next
        providers.insert(.email)
        return next
    }

    public func signInWithApple(identityToken: String) async throws -> AuthSession {
        guard identityToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            throw AuthError.invalidAppleToken
        }
        let next = AuthSession(userID: userID, provider: .apple, createdAt: Date())
        session = next
        providers.insert(.apple)
        return next
    }

    public func signOut() async {
        session = nil
        providers = []
    }

    public func linkEmailCredentialToCurrentUser(email: String, password: String) async throws -> AuthSession {
        guard email.contains("@"), email.contains(".") else {
            throw AuthError.invalidEmail
        }
        guard password.count >= 8 else {
            throw AuthError.weakPassword
        }
        guard let existing = session else {
            throw AuthError.unauthorized
        }

        let linked = AuthSession(userID: existing.userID, provider: .email, createdAt: Date())
        session = linked
        providers.insert(.email)
        return linked
    }

    public func linkedProviders() async throws -> [AuthProviderKind] {
        Array(providers).sorted { $0.rawValue < $1.rawValue }
    }

    public func reauthenticateCurrentSession() async throws -> AuthSession {
        guard let existing = session else {
            throw AuthError.unauthorized
        }
        let refreshed = AuthSession(userID: existing.userID, provider: existing.provider, createdAt: Date())
        session = refreshed
        return refreshed
    }

    public func unlinkProvider(_ provider: AuthProviderKind) async throws -> AuthSession {
        guard var existing = session else {
            throw AuthError.unauthorized
        }
        guard providers.contains(provider) else {
            throw AuthError.providerNotLinked
        }
        if providers.count <= 1 {
            throw AuthError.cannotUnlinkLastProvider
        }
        if Date().timeIntervalSince(existing.createdAt) > 600 {
            throw AuthError.reauthenticationRequired
        }

        providers.remove(provider)
        if existing.provider == provider,
           let fallback = providers.sorted(by: { $0.rawValue < $1.rawValue }).first {
            existing = AuthSession(userID: existing.userID, provider: fallback, createdAt: Date())
            session = existing
        }
        return session ?? existing
    }
}

public actor SupabaseAuthService: AuthService {
    private struct TokenResponse: Decodable {
        struct UserPayload: Decodable {
            let id: UUID
        }

        let access_token: String
        let refresh_token: String?
        let user: UserPayload
    }

    private struct UserResponse: Decodable {
        struct Identity: Decodable {
            let id: String?
            let identity_id: String?
            let provider: String?

            var resolvedID: String? {
                if let identity_id, identity_id.isEmpty == false {
                    return identity_id
                }
                if let id, id.isEmpty == false {
                    return id
                }
                return nil
            }
        }

        let identities: [Identity]?
    }

    private let client: SupabaseHTTPClient
    private let store: SupabaseSessionStore

    public init(
        config: SupabaseConfig,
        sessionStore: SupabaseSessionStore = SupabaseSessionStore(),
        session: URLSession = .shared
    ) {
        self.store = sessionStore
        self.client = SupabaseHTTPClient(config: config, session: session, sessionStore: sessionStore)
    }

    public func currentSession() async -> AuthSession? {
        await store.current()?.authSession
    }

    public func signInWithEmail(email: String, password: String) async throws -> AuthSession {
        guard email.contains("@"), email.contains(".") else {
            throw AuthError.invalidEmail
        }
        guard password.count >= 8 else {
            throw AuthError.weakPassword
        }

        let body = ["email": email, "password": password]
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        let data: Data
        do {
            data = try await client.request(
                path: "/auth/v1/token?grant_type=password",
                method: "POST",
                body: bodyData,
                requiresAuth: false
            )
        } catch let error as SupabaseHTTPError {
            throw Self.map(error: error)
        }

        let payload = try SupabaseHTTPClient.jsonDecoder().decode(TokenResponse.self, from: data)
        let session = AuthSession(userID: payload.user.id, provider: .email, createdAt: Date())
        await store.set(.init(authSession: session, accessToken: payload.access_token, refreshToken: payload.refresh_token))
        return session
    }

    public func signInWithApple(identityToken: String) async throws -> AuthSession {
        guard identityToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            throw AuthError.invalidAppleToken
        }

        let body: [String: Any] = [
            "provider": "apple",
            "id_token": identityToken
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        let data: Data
        do {
            data = try await client.request(
                path: "/auth/v1/token?grant_type=id_token",
                method: "POST",
                body: bodyData,
                requiresAuth: false
            )
        } catch let error as SupabaseHTTPError {
            throw Self.map(error: error)
        }

        let payload = try SupabaseHTTPClient.jsonDecoder().decode(TokenResponse.self, from: data)
        let session = AuthSession(userID: payload.user.id, provider: .apple, createdAt: Date())
        await store.set(.init(authSession: session, accessToken: payload.access_token, refreshToken: payload.refresh_token))
        return session
    }

    public func signOut() async {
        do {
            _ = try await client.request(path: "/auth/v1/logout", method: "POST", requiresAuth: true)
        } catch {
            // Best effort logout; local session is still cleared.
        }
        await store.clear()
    }

    public func linkEmailCredentialToCurrentUser(email: String, password: String) async throws -> AuthSession {
        guard email.contains("@"), email.contains(".") else {
            throw AuthError.invalidEmail
        }
        guard password.count >= 8 else {
            throw AuthError.weakPassword
        }

        guard let existing = await store.current() else {
            throw AuthError.unauthorized
        }

        let body = ["email": email, "password": password]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        do {
            _ = try await client.request(
                path: "/auth/v1/user",
                method: "PUT",
                body: bodyData,
                requiresAuth: true
            )
        } catch let error as SupabaseHTTPError {
            throw Self.map(error: error)
        }

        let linked = AuthSession(userID: existing.authSession.userID, provider: .email, createdAt: Date())
        await store.set(.init(authSession: linked, accessToken: existing.accessToken, refreshToken: existing.refreshToken))
        return linked
    }

    public func linkedProviders() async throws -> [AuthProviderKind] {
        let data: Data
        do {
            data = try await client.request(path: "/auth/v1/user", method: "GET", requiresAuth: true)
        } catch let error as SupabaseHTTPError {
            throw Self.map(error: error)
        }

        let user = try SupabaseHTTPClient.jsonDecoder().decode(UserResponse.self, from: data)
        let providers = (user.identities ?? []).compactMap { identity -> AuthProviderKind? in
            guard let raw = identity.provider?.lowercased() else { return nil }
            switch raw {
            case "apple": return .apple
            case "email": return .email
            default: return nil
            }
        }
        let unique = Array(Set(providers)).sorted { $0.rawValue < $1.rawValue }
        if unique.isEmpty, let session = await store.current()?.authSession {
            return [session.provider]
        }
        return unique
    }

    public func reauthenticateCurrentSession() async throws -> AuthSession {
        guard let refreshed = try await refreshSessionIfPossible() else {
            throw AuthError.unauthorized
        }
        return refreshed
    }

    public func unlinkProvider(_ provider: AuthProviderKind) async throws -> AuthSession {
        guard var existing = await store.current()?.authSession else {
            throw AuthError.unauthorized
        }

        let data: Data
        do {
            data = try await client.request(path: "/auth/v1/user", method: "GET", requiresAuth: true)
        } catch let error as SupabaseHTTPError {
            throw Self.map(error: error)
        }

        let user = try SupabaseHTTPClient.jsonDecoder().decode(UserResponse.self, from: data)
        let identities = user.identities ?? []

        let targetIdentity = identities.first { identity in
            identity.provider?.lowercased() == provider.rawValue
        }
        guard let targetIdentity else {
            throw AuthError.providerNotLinked
        }

        let linkedProviders = Set(identities.compactMap { identity -> AuthProviderKind? in
            guard let raw = identity.provider?.lowercased() else { return nil }
            switch raw {
            case "apple": return .apple
            case "email": return .email
            default: return nil
            }
        })

        let providers = Array(linkedProviders)
        if providers.count <= 1 {
            throw AuthError.cannotUnlinkLastProvider
        }
        if Date().timeIntervalSince(existing.createdAt) > 600 {
            throw AuthError.reauthenticationRequired
        }

        guard let identityID = targetIdentity.resolvedID,
              let encodedID = identityID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            throw AuthError.server("Could not resolve provider identity id")
        }

        do {
            _ = try await client.request(
                path: "/auth/v1/user/identities/\(encodedID)",
                method: "DELETE",
                requiresAuth: true
            )
        } catch let error as SupabaseHTTPError {
            throw Self.map(error: error)
        }

        if existing.provider == provider,
           let fallback = providers.first(where: { $0 != provider }) {
            existing = AuthSession(userID: existing.userID, provider: fallback, createdAt: Date())
            if let current = await store.current() {
                await store.set(
                    .init(
                        authSession: existing,
                        accessToken: current.accessToken,
                        refreshToken: current.refreshToken
                    )
                )
            }
            return existing
        }

        return existing
    }

    public func sessionStore() -> SupabaseSessionStore {
        store
    }

    public func refreshSessionIfPossible() async throws -> AuthSession? {
        guard let current = await store.current(),
              let refreshToken = current.refreshToken,
              refreshToken.isEmpty == false else {
            return await store.current()?.authSession
        }

        let body = ["refresh_token": refreshToken]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        do {
            data = try await client.request(
                path: "/auth/v1/token?grant_type=refresh_token",
                method: "POST",
                body: bodyData,
                requiresAuth: false
            )
        } catch let error as SupabaseHTTPError {
            throw Self.map(error: error)
        }

        let payload = try SupabaseHTTPClient.jsonDecoder().decode(TokenResponse.self, from: data)
        let session = AuthSession(
            userID: payload.user.id,
            provider: current.authSession.provider,
            createdAt: Date()
        )
        await store.set(.init(authSession: session, accessToken: payload.access_token, refreshToken: payload.refresh_token))
        return session
    }

    private static func map(error: SupabaseHTTPError) -> AuthError {
        switch error {
        case .missingAuthToken:
            return .unauthorized
        case .badResponse:
            return .server("Unexpected response from auth service")
        case .statusCode(let code, let message):
            if code == 401 || code == 403 {
                return .unauthorized
            }
            return .server(message.isEmpty ? "Auth request failed (\(code))" : message)
        }
    }
}
