import SwiftUI
import MeowDomain

public struct AccountProvidersScreen: View {
    @StateObject private var viewModel: AccountProvidersViewModel

    public init(viewModel: @autoclosure @escaping () -> AccountProvidersViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel())
    }

    public var body: some View {
        Form {
            Section("Linked Providers") {
                if viewModel.linkedProviders.isEmpty {
                    Text("No providers loaded.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.linkedProviders, id: \.rawValue) { provider in
                        Text(label(for: provider))
                    }
                }
            }

            Section("Unlink Provider") {
                Picker("Provider", selection: $viewModel.selectedProviderForUnlink) {
                    ForEach(viewModel.linkedProviders, id: \.rawValue) { provider in
                        Text(label(for: provider)).tag(Optional(provider))
                    }
                }

                Button("Unlink Selected") {
                    Task { await viewModel.unlinkSelectedProvider() }
                }
                .disabled(viewModel.canAttemptUnlink == false || viewModel.isLoading)

                Button("Re-authenticate") {
                    Task { await viewModel.reauthenticate() }
                }
                .disabled(viewModel.isLoading)
            }

            if let status = viewModel.statusMessage {
                Section("Status") {
                    Text(status)
                        .foregroundStyle(.green)
                }
            }

            if let error = viewModel.errorMessage {
                Section("Error") {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Providers")
        .alert("Re-authentication Required", isPresented: $viewModel.shouldPromptReauthentication) {
            Button("Not Now", role: .cancel) {}
            Button("Re-authenticate & Unlink") {
                Task { await viewModel.reauthenticateAndRetryUnlink() }
            }
        } message: {
            Text("For security, please re-authenticate to unlink this provider. We'll retry unlink automatically after re-authentication.")
        }
        .task {
            await viewModel.refresh()
        }
    }

    private func label(for provider: AuthProviderKind) -> String {
        switch provider {
        case .apple: return "Apple"
        case .email: return "Email"
        }
    }
}
