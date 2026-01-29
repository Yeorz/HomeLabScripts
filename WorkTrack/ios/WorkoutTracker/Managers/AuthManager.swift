import Foundation

class AuthManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var token: String?
    @Published var userId: Int?
    @Published var errorMessage: String?
    
    private let tokenKey = "jwt_token"
    private let userIdKey = "user_id"
    private let apiBaseURL = "http://localhost:3001"
    
    init() {
        // Restore token from keychain/defaults on app launch
        self.token = UserDefaults.standard.string(forKey: tokenKey)
        self.userId = UserDefaults.standard.integer(forKey: userIdKey)
        self.isAuthenticated = self.token != nil
    }
    
    func register(email: String, password: String) async {
        let url = URL(string: "\(apiBaseURL)/register")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = ["email": email, "password": password]
        request.httpBody = try? JSONEncoder().encode(body)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                // Auto-login after registration
                await login(email: email, password: password)
            } else {
                DispatchQueue.main.async {
                    self.errorMessage = "Registration failed"
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    func login(email: String, password: String) async {
        let url = URL(string: "\(apiBaseURL)/login")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = ["email": email, "password": password]
        request.httpBody = try? JSONEncoder().encode(body)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                let loginResponse = try JSONDecoder().decode(LoginResponse.self, from: data)
                DispatchQueue.main.async {
                    self.token = loginResponse.token
                    self.isAuthenticated = true
                    self.errorMessage = nil
                    UserDefaults.standard.set(loginResponse.token, forKey: self.tokenKey)
                }
            } else {
                DispatchQueue.main.async {
                    self.errorMessage = "Invalid credentials"
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    func logout() {
        self.token = nil
        self.userId = nil
        self.isAuthenticated = false
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: userIdKey)
    }
}

struct LoginResponse: Codable {
    let token: String
}
