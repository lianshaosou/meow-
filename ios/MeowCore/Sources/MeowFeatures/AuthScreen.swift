import SwiftUI

#if os(iOS)
import AuthenticationServices
#endif

public struct AuthScreen: View {
    @StateObject private var viewModel: AuthViewModel
    private let onAuthenticated: () -> Void

    public init(viewModel: @autoclosure @escaping () -> AuthViewModel, onAuthenticated: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: viewModel())
        self.onAuthenticated = onAuthenticated
    }

    public var body: some View {
        VStack(spacing: 16) {
            Text("Welcome to Meow")
                .font(.title.bold())

            TextField("Email", text: $viewModel.email)
                .textFieldStyle(.roundedBorder)

#if os(iOS)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()
#endif

            SecureField("Password", text: $viewModel.password)
                .textFieldStyle(.roundedBorder)

            Button("Sign In with Email") {
                Task {
                    await viewModel.signInWithEmail()
                    if viewModel.isAuthenticated { onAuthenticated() }
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isLoading)

#if os(iOS)
            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.email, .fullName]
            } onCompletion: { result in
                handleAppleAuth(result)
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 44)
            .disabled(viewModel.isLoading)
#else
            Button("Sign In with Apple") {
                Task {
                    await viewModel.signInWithApple(identityToken: "dev-apple-token")
                    if viewModel.isAuthenticated { onAuthenticated() }
                }
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isLoading)
#endif

            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.footnote)
            }
        }
        .padding()
    }

#if os(iOS)
    private func handleAppleAuth(_ result: Result<ASAuthorization, Error>) {
        guard case .success(let authorization) = result,
              let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let token = String(data: tokenData, encoding: .utf8) else {
            Task { await viewModel.signInWithApple(identityToken: "") }
            return
        }

        Task {
            await viewModel.signInWithApple(identityToken: token)
            if viewModel.isAuthenticated { onAuthenticated() }
        }
    }
#endif
}
