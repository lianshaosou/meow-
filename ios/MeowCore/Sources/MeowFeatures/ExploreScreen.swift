import SwiftUI
import MapKit
import MeowDomain

public struct ExploreScreen: View {
    @StateObject private var viewModel: ExploreViewModel
    @State private var mapCameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.3400, longitude: -122.0400),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
    )
    @State private var visibleRegion: MKCoordinateRegion?
    private let userID: UUID

    public init(userID: UUID, viewModel: @autoclosure @escaping () -> ExploreViewModel) {
        self.userID = userID
        _viewModel = StateObject(wrappedValue: viewModel())
    }

    public var body: some View {
        Form {
            Section("Mode") {
                Toggle("Use Live Location", isOn: $viewModel.useLiveLocation)
                Text(viewModel.locationStatus)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Location") {
                if viewModel.useLiveLocation {
                    LabeledContent("Latitude", value: String(format: "%.6f", viewModel.latitude))
                    LabeledContent("Longitude", value: String(format: "%.6f", viewModel.longitude))
                    LabeledContent("Accuracy", value: "\(Int(viewModel.horizontalAccuracyMeters))m")
                } else {
                    Map(position: $mapCameraPosition, interactionModes: .all) {
                        Marker("Explore", coordinate: CLLocationCoordinate2D(latitude: viewModel.latitude, longitude: viewModel.longitude))
                            .tint(.orange)
                        if let home = viewModel.activeHomeArea {
                            Marker("Home", coordinate: CLLocationCoordinate2D(latitude: home.center.latitude, longitude: home.center.longitude))
                                .tint(.blue)
                        }
                    }
                    .frame(minHeight: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .onMapCameraChange { context in
                        visibleRegion = context.region
                    }

                    Button("Use Map Center as Explore Point") {
                        let center = visibleRegion?.center ?? CLLocationCoordinate2D(latitude: viewModel.latitude, longitude: viewModel.longitude)
                        viewModel.latitude = center.latitude
                        viewModel.longitude = center.longitude
                    }

                    if let home = viewModel.activeHomeArea {
                        Button("Use Home Center") {
                            viewModel.latitude = home.center.latitude
                            viewModel.longitude = home.center.longitude
                            recenterDebugRegion()
                        }

                        Button("Set Outside Home (Debug)") {
                            let outside = outsidePoint(for: home)
                            viewModel.latitude = outside.latitude
                            viewModel.longitude = outside.longitude
                            recenterDebugRegion()
                        }

                        LabeledContent("Home Radius", value: "\(Int(home.radiusMeters))m")
                    }

                    LabeledContent("Latitude", value: String(format: "%.6f", viewModel.latitude))
                    LabeledContent("Longitude", value: String(format: "%.6f", viewModel.longitude))
                    Stepper(value: $viewModel.horizontalAccuracyMeters, in: 5...150, step: 1) {
                        Text("Accuracy: \(Int(viewModel.horizontalAccuracyMeters))m")
                    }
                }
            }

            Section {
                Button("Check Nearby Cats") {
                    Task {
                        await viewModel.checkNearbyCats(userID: userID)
                    }
                }
                .disabled(viewModel.isLoading)
            }

            if let status = viewModel.statusMessage {
                Section("Status") {
                    Text(status)
                }
            }

            if let encounter = viewModel.encounterMessage {
                Section("Encounter") {
                    Text(encounter)
                        .font(.headline)
                }
            }
        }
        .navigationTitle("Explore")
        .task {
            viewModel.onAppear()
            await viewModel.refreshHomeContext(userID: userID)
            recenterDebugRegion()
        }
        .onDisappear {
            viewModel.onDisappear()
        }
        .onChange(of: viewModel.useLiveLocation) { _, isLive in
            if isLive == false {
                recenterDebugRegion()
            }
        }
        .onChange(of: viewModel.latitude) { _, _ in
            if viewModel.useLiveLocation {
                recenterDebugRegion()
            }
        }
        .onChange(of: viewModel.longitude) { _, _ in
            if viewModel.useLiveLocation {
                recenterDebugRegion()
            }
        }
    }

    private func recenterDebugRegion() {
        mapCameraPosition = .region(
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: viewModel.latitude, longitude: viewModel.longitude),
                span: visibleRegion?.span ?? MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        )
    }

    private func outsidePoint(for home: HomeArea) -> Coordinate {
        let offsetMeters = home.radiusMeters + 60
        let latitudeOffset = offsetMeters / 111_111
        return Coordinate(
            latitude: home.center.latitude + latitudeOffset,
            longitude: home.center.longitude
        )
    }
}
