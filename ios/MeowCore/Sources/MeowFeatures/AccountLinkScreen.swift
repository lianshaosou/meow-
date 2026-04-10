import SwiftUI

public struct AccountLinkScreen: View {
    @StateObject private var viewModel: AccountLinkViewModel
    private let providersViewModel: AccountProvidersViewModel

    public init(
        viewModel: @autoclosure @escaping () -> AccountLinkViewModel,
        providersViewModel: AccountProvidersViewModel
    ) {
        _viewModel = StateObject(wrappedValue: viewModel())
        self.providersViewModel = providersViewModel
    }

    public var body: some View {
        Form {
            Section("Link Email Sign-In") {
                TextField("Email", text: $viewModel.email)
#if os(iOS)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
#endif

                SecureField("Password", text: $viewModel.password)
            }

            Section {
                Button("Link Email") {
                    Task { await viewModel.linkEmailToCurrentAccount() }
                }
                .disabled(viewModel.isLoading)

                NavigationLink("Manage Linked Providers") {
                    AccountProvidersScreen(viewModel: providersViewModel)
                }
            }

            if let message = viewModel.message {
                Section("Status") {
                    Text(message)
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
        .navigationTitle("Account")
    }
}
