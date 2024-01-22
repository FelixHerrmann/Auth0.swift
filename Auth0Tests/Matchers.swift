import Foundation
import Nimble
import OHHTTPStubs
#if SWIFT_PACKAGE
import OHHTTPStubsSwift
#endif

@testable import Auth0

func hasAllOf(_ parameters: [String: String]) -> HTTPStubsTestBlock {
    return { request in
        guard let payload = request.payload else { return false }
        return parameters.count == payload.count && parameters.reduce(true, { (initial, entry) -> Bool in
            return initial && payload[entry.0] as? String == entry.1
        })
    }
}

func hasAtLeast(_ parameters: [String: String]) -> HTTPStubsTestBlock {
    return { request in
        guard let payload = request.payload else { return false }
        let entries = parameters.filter { (key, _) in payload.contains { (name, _) in  key == name } }
        return entries.count == parameters.count && entries.reduce(true, { (initial, entry) -> Bool in
            return initial && payload[entry.0] as? String == entry.1
        })
    }
}

func hasUserMetadata(_ metadata: [String: String]) -> HTTPStubsTestBlock {
    return hasObjectAttribute("user_metadata", value: metadata)
}

func hasObjectAttribute(_ name: String, value: [String: String]) -> HTTPStubsTestBlock {
    return { request in
        guard let payload = request.payload, let actualValue = payload[name] as? [String: Any] else { return false }
        return value.count == actualValue.count && value.reduce(true, { (initial, entry) -> Bool in
            guard let value = actualValue[entry.0] as? String else { return false }
            return initial && value == entry.1
        })
    }
}

func hasNoneOf(_ names: [String]) -> HTTPStubsTestBlock {
    return { request in
        guard let payload = request.payload else { return false }
        return payload.filter { names.contains($0.0) }.isEmpty
    }
}

func hasQueryParameters(_ parameters: [String: String]) -> HTTPStubsTestBlock {
    return { request in
        guard
            let url = request.url,
            let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
            let items = components.queryItems
            else { return false }
        return items.count == parameters.count && items.reduce(true, { (initial, item) -> Bool in
            return initial && parameters[item.name] == item.value
        })
    }
}

func isToken(_ domain: String) -> HTTPStubsTestBlock {
    return isMethodPOST() && isHost(domain) && isPath("/oauth/token")
}

func isSignUp(_ domain: String) -> HTTPStubsTestBlock {
    return isMethodPOST() && isHost(domain) && isPath("/dbconnections/signup")
}

func isResetPassword(_ domain: String) -> HTTPStubsTestBlock {
    return isMethodPOST() && isHost(domain) && isPath("/dbconnections/change_password")
}

func isPasswordless(_ domain: String) -> HTTPStubsTestBlock {
    return isMethodPOST() && isHost(domain) && isPath("/passwordless/start")
}

func isUserInfo(_ domain: String) -> HTTPStubsTestBlock {
    return isMethodGET() && isHost(domain) && isPath("/userinfo")
}

func isRevokeToken(_ domain: String) -> HTTPStubsTestBlock {
    return isMethodPOST() && isHost(domain) && isPath("/oauth/revoke")
}

func isUsersPath(_ domain: String, identifier: String? = nil) -> HTTPStubsTestBlock {
    let path: String
    if let identifier = identifier {
        path = "/api/v2/users/\(identifier)"
    } else {
        path = "/api/v2/users/"
    }
    return isHost(domain) && isPath(path)
}

func isLinkPath(_ domain: String, identifier: String) -> HTTPStubsTestBlock {
    return isHost(domain) && isPath("/api/v2/users/\(identifier)/identities")
}

func isUnlinkPath(_ domain: String, identifier: String, provider: String, identityId: String) -> HTTPStubsTestBlock {
    return isHost(domain) && isPath("/api/v2/users/\(identifier)/identities/\(provider)/\(identityId)")
}

func isJWKSPath(_ domain: String) -> HTTPStubsTestBlock {
    return isHost(domain) && isPath("/.well-known/jwks.json")
}

func isMultifactorChallenge(_ domain: String) -> HTTPStubsTestBlock {
    return isMethodPOST() && isHost(domain) && isPath("/mfa/challenge")
}

func hasHeader(_ name: String, value: String) -> HTTPStubsTestBlock {
    return { request in
        return request.value(forHTTPHeaderField: name) == value
    }
}

func hasBearerToken(_ token: String) -> HTTPStubsTestBlock {
    return hasHeader("Authorization", value: "Bearer \(token)")
}

func containItem(withName name: String, value: String? = nil) -> Nimble.Matcher<[URLQueryItem]> {
    return Matcher<[URLQueryItem]>.define("contain item with name <\(name)>") { expression, failureMessage -> MatcherResult in
        guard let items = try expression.evaluate() else { return MatcherResult(status: .doesNotMatch, message: failureMessage) }
        let outcome = items.contains { item -> Bool in
            return item.name == name && ((value == nil && item.value != nil) || item.value == value)
        }
        return MatcherResult(bool: outcome, message: failureMessage)
    }
}

func haveAuthenticationError<T>(code: String, description: String) -> Nimble.Matcher<AuthenticationResult<T>> {
    return Matcher<AuthenticationResult<T>>.define("be an error response with code <\(code)> and description <\(description)") { expression, failureMessage -> MatcherResult in
        return try beUnsuccessful(expression, failureMessage) { (error: AuthenticationError) -> Bool in
            return code == error.code && description == error.localizedDescription
        }
    }
}

#if WEB_AUTH_PLATFORM
func haveAuthenticationError<T>(code: String, description: String) -> Nimble.Matcher<WebAuthResult<T>> {
    return Matcher<WebAuthResult<T>>.define("be an error response with code <\(code)> and description <\(description)") { expression, failureMessage -> MatcherResult in
        return try beUnsuccessful(expression, failureMessage) { (error: WebAuthError) -> Bool in
            guard let cause = error.cause as? AuthenticationError else { return false }
            return code == cause.code && description == cause.localizedDescription
        }
    }
}
#endif

func haveManagementError<T>(_ errorString: String, description: String, code: String, statusCode: Int) -> Nimble.Matcher<ManagementResult<T>> {
    return Matcher<ManagementResult<T>>.define("be an error response with code <\(code)> and description <\(description)") { expression, failureMessage -> MatcherResult in
        return try beUnsuccessful(expression, failureMessage) { (error: ManagementError) -> Bool in
            return errorString == error.info["error"] as? String
                && code == error.code
                && description == error.localizedDescription
                && statusCode == error.statusCode
        }
    }
}

func haveManagementError<T>(description: String, code: String, statusCode: Int = 0, cause: Error? = nil) -> Nimble.Matcher<ManagementResult<T>> {
    return Matcher<ManagementResult<T>>.define("be an error response with code <\(code)> and description <\(description)") { expression, failureMessage -> MatcherResult in
        return try beUnsuccessful(expression, failureMessage) { (error: ManagementError) -> Bool in
            return code == error.code
                && description == error.localizedDescription
                && statusCode == error.statusCode
                && (cause == nil || error.cause?.localizedDescription == cause?.localizedDescription)
        }
    }
}

func haveManagementError<T>(description: String, statusCode: Int) -> Nimble.Matcher<ManagementResult<T>> {
    return Matcher<ManagementResult<T>>.define("be an error result") { expression, failureMessage -> MatcherResult in
        return try beUnsuccessful(expression, failureMessage) { (error: ManagementError) -> Bool in
            return error.localizedDescription == description && error.statusCode == statusCode
        }
    }
}

#if WEB_AUTH_PLATFORM
func haveWebAuthError<T>(_ expected: WebAuthError) -> Nimble.Matcher<WebAuthResult<T>> {
    return Matcher<WebAuthResult<T>>.define("be an error result") { expression, failureMessage -> MatcherResult in
        return try beUnsuccessful(expression, failureMessage) { (error: WebAuthError) -> Bool in
            return error == expected
                && (expected.cause == nil || error.cause?.localizedDescription == expected.cause?.localizedDescription)
        }
    }
}
#endif

func haveCredentialsManagerError<T>(_ expected: CredentialsManagerError) -> Nimble.Matcher<CredentialsManagerResult<T>> {
    return Matcher<CredentialsManagerResult<T>>.define("be an error result") { expression, failureMessage -> MatcherResult in
        return try beUnsuccessful(expression, failureMessage) { (error: CredentialsManagerError) -> Bool in
            return error == expected
                && (expected.cause == nil || error.cause?.localizedDescription == expected.cause?.localizedDescription)
        }
    }
}

func haveCredentials(_ accessToken: String? = nil, _ idToken: String? = nil) -> Nimble.Matcher<AuthenticationResult<Credentials>> {
    return Matcher<AuthenticationResult<Credentials>>.define("be a successful authentication result") { expression, failureMessage -> MatcherResult in
        return try haveCredentials(accessToken: accessToken,
                                   idToken: idToken,
                                   refreshToken: nil,
                                   expression,
                                   failureMessage)
    }
}

#if WEB_AUTH_PLATFORM
func haveCredentials(_ accessToken: String? = nil, _ idToken: String? = nil) -> Nimble.Matcher<WebAuthResult<Credentials>> {
    return Matcher<WebAuthResult<Credentials>>.define("be a successful authentication result") { expression, failureMessage -> MatcherResult in
        return try haveCredentials(accessToken: accessToken,
                                   idToken: idToken,
                                   refreshToken: nil,
                                   expression,
                                   failureMessage)
    }
}
#endif

func haveCredentials(_ accessToken: String, _ idToken: String? = nil, _ refreshToken: String? = nil) -> Nimble.Matcher<CredentialsManagerResult<Credentials>> {
    return Matcher<CredentialsManagerResult<Credentials>>.define("be a successful credentials retrieval") { expression, failureMessage -> MatcherResult in
        return try haveCredentials(accessToken: accessToken,
                                   idToken: idToken,
                                   refreshToken: refreshToken,
                                   expression,
                                   failureMessage)
    }
}

func haveCredentials() -> Nimble.Matcher<CredentialsManagerResult<Credentials>> {
    return Matcher<CredentialsManagerResult<Credentials>>.define("be a successful credentials retrieval") { expression, failureMessage -> MatcherResult in
        return try beSuccessful(expression, failureMessage)
    }
}

func haveCreatedUser(_ email: String, username: String? = nil) -> Nimble.Matcher<AuthenticationResult<DatabaseUser>> {
    return Matcher<AuthenticationResult<DatabaseUser>>.define("have created user with email <\(email)>") { expression, failureMessage -> MatcherResult in
        return try beSuccessful(expression, failureMessage) { (created: DatabaseUser) -> Bool in
            return created.email == email && (username == nil || created.username == username)
        }
    }
}

func beSuccessful<T>() -> Nimble.Matcher<AuthenticationResult<T>> {
    return Matcher<AuthenticationResult<T>>.define("be a successful result") { expression, failureMessage -> MatcherResult in
        return try beSuccessful(expression, failureMessage)
    }
}

func beSuccessful<T>() -> Nimble.Matcher<ManagementResult<T>> {
    return Matcher<ManagementResult<T>>.define("be a successful result") { expression, failureMessage -> MatcherResult in
        return try beSuccessful(expression, failureMessage)
    }
}

#if WEB_AUTH_PLATFORM
func beSuccessful<T>() -> Nimble.Matcher<WebAuthResult<T>> {
    return Matcher<WebAuthResult<T>>.define("be a successful result") { expression, failureMessage -> MatcherResult in
        return try beSuccessful(expression, failureMessage)
    }
}
#endif

func beSuccessful<T>() -> Nimble.Matcher<CredentialsManagerResult<T>> {
    return Matcher<CredentialsManagerResult<T>>.define("be a successful result") { expression, failureMessage -> MatcherResult in
        return try beSuccessful(expression, failureMessage)
    }
}

func beUnsuccessful<T>(_ cause: String? = nil) -> Nimble.Matcher<AuthenticationResult<T>> {
    return Matcher<AuthenticationResult<T>>.define("be a failure result") { expression, failureMessage -> MatcherResult in
        if let cause = cause {
            _ = failureMessage.appended(message: " with cause \(cause)")
        } else {
            _ = failureMessage.appended(message: " from authentication api")
        }
        return try beUnsuccessful(expression, failureMessage)
    }
}

#if WEB_AUTH_PLATFORM
func beUnsuccessful<T>(_ cause: String? = nil) -> Nimble.Matcher<WebAuthResult<T>> {
    return Matcher<WebAuthResult<T>>.define("be a failure result") { expression, failureMessage -> MatcherResult in
        if let cause = cause {
            _ = failureMessage.appended(message: " with cause \(cause)")
        } else {
            _ = failureMessage.appended(message: " from web auth")
        }
        return try beUnsuccessful(expression, failureMessage)
    }
}
#endif

func beUnsuccessful<T>() -> Nimble.Matcher<CredentialsManagerResult<T>> {
    return Matcher<CredentialsManagerResult<T>>.define("be a failure result") { expression, failureMessage -> MatcherResult in
        _ = failureMessage.appended(message: " from credentials manager")
        return try beUnsuccessful(expression, failureMessage)
    }
}

func haveProfile(_ sub: String) -> Nimble.Matcher<AuthenticationResult<UserInfo>> {
    return Matcher<AuthenticationResult<UserInfo>>.define("have userInfo for sub: <\(sub)>") { expression, failureMessage -> MatcherResult in
        return try beSuccessful(expression, failureMessage) { (userInfo: UserInfo) -> Bool in userInfo.sub == sub }
    }
}

func haveObjectWithAttributes(_ attributes: [String]) -> Nimble.Matcher<ManagementResult<[String: Any]>> {
    return Matcher<ManagementResult<[String: Any]>>.define("have attributes \(attributes)") { expression, failureMessage -> MatcherResult in
        return try beSuccessful(expression, failureMessage) { (value: [String: Any]) -> Bool in
            return Array(value.keys).reduce(true, { (initial, value) -> Bool in
                return initial && attributes.contains(value)
            })
        }
    }
}

func haveJWKS() -> Nimble.Matcher<AuthenticationResult<JWKS>> {
    return Matcher<AuthenticationResult<JWKS>>.define("have a JWKS object with at least one key") { expression, failureMessage -> MatcherResult in
        return try beSuccessful(expression, failureMessage) { (jwks: JWKS) -> Bool in !jwks.keys.isEmpty }
    }
}

func beURLSafeBase64() -> Nimble.Matcher<String> {
    return Matcher<String>.define("be url safe base64") { expression, failureMessage -> MatcherResult in
        var set = CharacterSet()
        set.formUnion(.alphanumerics)
        set.insert(charactersIn: "-_/")
        set.invert()
        if let actual = try expression.evaluate() , actual.rangeOfCharacter(from: set) == nil {
            return MatcherResult(status: .matches, message: failureMessage)
        }
        return MatcherResult(status: .doesNotMatch, message: failureMessage)
    }
}

// MARK: - Private Functions

private func beSuccessful<T, E>(_ expression: Expression<Result<T, E>>,
                                _ message: ExpectationMessage,
                                Matcher: @escaping (T) -> Bool = { _ in true }) throws -> MatcherResult {
    if let actual = try expression.evaluate(), case .success(let value) = actual {
        return MatcherResult(bool: Matcher(value), message: message)
    }
    return MatcherResult(status: .doesNotMatch, message: message)
}

private func beUnsuccessful<T, E>(_ expression: Expression<Result<T, E>>,
                             _ message: ExpectationMessage,
                             Matcher: @escaping (E) -> Bool = { _ in true }) throws -> MatcherResult {
    if let actual = try expression.evaluate(), case .failure(let error) = actual {
        return MatcherResult(bool: Matcher(error), message: message)
    }
    return MatcherResult(status: .doesNotMatch, message: message)
}

private func haveCredentials<E>(accessToken: String?,
                                idToken: String?,
                                refreshToken: String?,
                                _ expression: Expression<Result<Credentials, E>>,
                                _ message: ExpectationMessage) throws -> MatcherResult {
    if let accessToken = accessToken {
        _ = message.appended(message: " <access_token: \(accessToken)>")
    }
    if let idToken = idToken {
        _ = message.appended(message: " <id_token: \(idToken)>")
    }
    if let refreshToken = refreshToken {
        _ = message.appended(message: " <refresh_token: \(refreshToken)>")
    }
    return try beSuccessful(expression, message) { (credentials: Credentials) -> Bool in
        return (accessToken == nil || credentials.accessToken == accessToken)
            && (idToken == nil || credentials.idToken == idToken)
            && (refreshToken == nil || credentials.refreshToken == refreshToken)
    }
}

// MARK: - Extensions

extension URLRequest {

    var payload: [String: Any]? {
        return URLProtocol.property(forKey: parameterPropertyKey, in: self) as? [String: Any]
    }

}
