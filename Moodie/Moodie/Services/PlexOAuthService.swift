import Foundation
import AuthenticationServices

class PlexOAuthService: NSObject {
    static let shared = PlexOAuthService()
    private let clientID = UUID().uuidString // Persist this if you want to reuse across launches
    private let product = "Moodie"
    private let platform = "iOS"
    private let device = "iPhone"
    private let redirectScheme = "moodie"
    private var pinId: Int?
    private var pinCode: String?
    private var authSession: ASWebAuthenticationSession?
    
    // MARK: - Public API
    func startLogin(completion: @escaping (Result<String, Error>) -> Void) {
        requestPin { [weak self] result in
            switch result {
            case .success(let pin):
                self?.pinId = pin.id
                self?.pinCode = pin.code
                self?.launchAuthSession(pin: pin, completion: completion)
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Step 1: Request PIN
    private func requestPin(completion: @escaping (Result<(id: Int, code: String), Error>) -> Void) {
        var request = URLRequest(url: URL(string: "https://plex.tv/api/v2/pins?strong=true")!)
        request.httpMethod = "POST"
        request.setValue(clientID, forHTTPHeaderField: "X-Plex-Client-Identifier")
        request.setValue(product, forHTTPHeaderField: "X-Plex-Product")
        request.setValue(platform, forHTTPHeaderField: "X-Plex-Platform")
        request.setValue(device, forHTTPHeaderField: "X-Plex-Device")
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error { completion(.failure(error)); return }
            guard let data = data else {
                completion(.failure(NSError(domain: "PlexOAuth", code: 1, userInfo: [NSLocalizedDescriptionKey: "No data"])))
                return
            }
            // Parse XML for <pin id="..." code="..."/>
            DispatchQueue.main.async {
                let parser = XMLParser(data: data)
                let delegate = PlexPinXMLDelegate()
                parser.delegate = delegate
                if parser.parse(), let id = delegate.id, let code = delegate.code {
                    completion(.success((id, code)))
                } else {
                    completion(.failure(NSError(domain: "PlexOAuth", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid PIN response"])))
                }
            }
        }
        task.resume()
    }
    
    // MARK: - Step 2: Launch OAuth Session
    private func launchAuthSession(pin: (id: Int, code: String), completion: @escaping (Result<String, Error>) -> Void) {
        let urlString = "https://app.plex.tv/auth#?clientID=\(clientID)&code=\(pin.code)&context[device][product]=\(product)&context[device][platform]=\(platform)&context[device][device]=\(device)"
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "PlexOAuth", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid auth URL"])))
            return
        }
        authSession = ASWebAuthenticationSession(url: url, callbackURLScheme: redirectScheme) { [weak self] callbackURL, error in
            // Always start polling for the token, regardless of error or callbackURL
            self?.pollForToken(completion: completion)
        }
        authSession?.presentationContextProvider = self
        authSession?.start()
    }
    
    // MARK: - Step 3: Poll for Token
    private func pollForToken(completion: @escaping (Result<String, Error>) -> Void) {
        guard let pinId = pinId else {
            print("[PlexOAuthService] Error: Missing PIN ID")
            completion(.failure(NSError(domain: "PlexOAuth", code: 3, userInfo: [NSLocalizedDescriptionKey: "Missing PIN ID"])))
            return
        }
        let url = URL(string: "https://plex.tv/api/v2/pins/\(pinId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(clientID, forHTTPHeaderField: "X-Plex-Client-Identifier")
        request.setValue(product, forHTTPHeaderField: "X-Plex-Product")
        request.setValue(platform, forHTTPHeaderField: "X-Plex-Platform")
        request.setValue(device, forHTTPHeaderField: "X-Plex-Device")
        // Poll every 2 seconds, up to 90 seconds
        let maxAttempts = 45
        var attempts = 0
        func poll() {
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("[PlexOAuthService] Poll error: \(error)")
                    completion(.failure(error)); return
                }
                guard let data = data else {
                    attempts += 1
                    print("[PlexOAuthService] Poll attempt \(attempts): No data received.")
                    if attempts < maxAttempts {
                        DispatchQueue.global().asyncAfter(deadline: .now() + 2) { poll() }
                    } else {
                        print("[PlexOAuthService] Timeout waiting for Plex token after \(attempts) attempts.")
                        completion(.failure(NSError(domain: "PlexOAuth", code: 4, userInfo: [NSLocalizedDescriptionKey: "Timeout waiting for Plex token"])))
                    }
                    return
                }
                print("[PlexOAuthService] Poll attempt \(attempts + 1): Response: ", String(data: data, encoding: .utf8) ?? "nil")
                // Parse XML for <pin authToken="..."/>
                DispatchQueue.main.async {
                    let parser = XMLParser(data: data)
                    let delegate = PlexPinPollXMLDelegate()
                    parser.delegate = delegate
                    parser.parse()
                    if let authToken = delegate.authToken {
                        print("[PlexOAuthService] Received authToken: \(authToken)")
                        // Save token securely
                        let saved = KeychainService.shared.saveToken(authToken)
                        print("[PlexOAuthService] Keychain saveToken result: \(saved)")
                        if saved {
                            completion(.success(authToken))
                        } else {
                            print("[PlexOAuthService] Failed to save token to Keychain")
                            completion(.failure(NSError(domain: "PlexOAuth", code: 5, userInfo: [NSLocalizedDescriptionKey: "Failed to save token to Keychain"])))
                        }
                    } else {
                        attempts += 1
                        print("[PlexOAuthService] Poll attempt \(attempts): No authToken yet.")
                        if attempts < maxAttempts {
                            DispatchQueue.global().asyncAfter(deadline: .now() + 2) { poll() }
                        } else {
                            print("[PlexOAuthService] Timeout waiting for Plex token after \(attempts) attempts.")
                            completion(.failure(NSError(domain: "PlexOAuth", code: 4, userInfo: [NSLocalizedDescriptionKey: "Timeout waiting for Plex token"])))
                        }
                    }
                }
            }
            task.resume()
        }
        poll()
    }

    var isAuthenticated: Bool {
        if let token = KeychainService.shared.getToken() {
            return !token.isEmpty
        }
        return false
    }
}

extension PlexOAuthService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        if Thread.isMainThread {
            return getPresentationAnchor()
        } else {
            // Ensure UI API is called on main thread
            return DispatchQueue.main.sync {
                getPresentationAnchor()
            }
        }
    }

    private func getPresentationAnchor() -> ASPresentationAnchor {
        if let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
           let window = windowScene.windows.first(where: { $0.isKeyWindow }) {
#if swift(>=5.9)
            if #available(iOS 17.0, *) {
                return ASPresentationAnchor(windowScene: windowScene)
            }
#endif
            return window
        }
        if let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first,
           let window = windowScene.windows.first {
#if swift(>=5.9)
            if #available(iOS 17.0, *) {
                return ASPresentationAnchor(windowScene: windowScene)
            }
#endif
            return window
        }
        // Fallback for older iOS versions
        return ASPresentationAnchor()
    }
}

class PlexPinXMLDelegate: NSObject, XMLParserDelegate {
    var id: Int?
    var code: String?
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        if elementName == "pin" {
            if let idStr = attributeDict["id"], let idInt = Int(idStr) {
                id = idInt
            }
            code = attributeDict["code"]
        }
    }
}

class PlexPinPollXMLDelegate: NSObject, XMLParserDelegate {
    var authToken: String?
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        if elementName == "pin" {
            authToken = attributeDict["authToken"]
        }
    }
} 