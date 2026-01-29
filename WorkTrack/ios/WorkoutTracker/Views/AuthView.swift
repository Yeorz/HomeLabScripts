import SwiftUI

struct AuthView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var email = ""
    @State private var password = ""
    @State private var isRegister = false
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text(isRegister ? "Create Account" : "Login")
                    .font(.system(size: 28, weight: .bold))
                    .padding(.bottom, 20)
                
                TextField("Email", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                
                SecureField("Password", text: $password)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                
                if let error = authManager.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                Button(action: {
                    isLoading = true
                    Task {
                        if isRegister {
                            await authManager.register(email: email, password: password)
                        } else {
                            await authManager.login(email: email, password: password)
                        }
                        isLoading = false
                    }
                }) {
                    Text(isRegister ? "Register" : "Login")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .opacity(isLoading ? 0.6 : 1)
                }
                .disabled(isLoading || email.isEmpty || password.isEmpty)
                
                Button(action: { isRegister.toggle() }) {
                    Text(isRegister ? "Already have an account?" : "Don't have an account?")
                        .foregroundColor(.blue)
                }
                
                Spacer()
            }
            .padding()
            .background(Color(.systemGray5))
            .ignoresSafeArea()
        }
    }
}

#Preview {
    AuthView()
        .environmentObject(AuthManager())
}
