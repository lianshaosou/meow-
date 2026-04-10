import SwiftUI

public struct OnboardingScreen: View {
    @StateObject private var viewModel: OnboardingViewModel
    private let userID: UUID
    private let onCompleted: () -> Void

    public init(
        userID: UUID,
        viewModel: @autoclosure @escaping () -> OnboardingViewModel,
        onCompleted: @escaping () -> Void
    ) {
        self.userID = userID
        _viewModel = StateObject(wrappedValue: viewModel())
        self.onCompleted = onCompleted
    }

    public var body: some View {
        Form {
            Section("Profile") {
                TextField("Nickname", text: $viewModel.nickname)
            }

            Section("Home Area") {
                TextField("Label", text: $viewModel.homeLabel)
                TextField("Latitude", value: $viewModel.homeLatitude, format: .number)
                TextField("Longitude", value: $viewModel.homeLongitude, format: .number)
                Stepper(value: $viewModel.homeRadiusMeters, in: 20...500, step: 5) {
                    Text("Radius: \(Int(viewModel.homeRadiusMeters))m")
                }
            }

            Section {
                Button("Complete Setup") {
                    Task {
                        await viewModel.complete(userID: userID)
                        if viewModel.isComplete { onCompleted() }
                    }
                }
                .disabled(viewModel.isSaving)

                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            }
        }
    }
}
