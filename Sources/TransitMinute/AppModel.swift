import Combine
import CoreLocation
import Foundation
import TransitMinuteCore

@MainActor
final class AppModel: ObservableObject {
    @Published var apiKey = ""
    @Published var settings = SettingsStore.load()
    @Published var countdown = CountdownState(mode: .setupNeeded)
    @Published var isPlanning = false
    @Published var setupError: String?
    @Published var lastPlan: TransitPlan?
    @Published var currentCoordinate: Coordinate?
    @Published var locationStatus: LocationStatus = .idle
    @Published var manualOrigin: PlaceLabel = .home
    @Published var alertActive = false
    @Published var diagnostics = RouteDiagnostics()

    let places: PlacesProviding
    let routes: RoutesProviding
    let keychain: KeychainStoring
    let locationService: LocationService
    let alertService: AlertService

    private var timer: Timer?
    private var refreshTask: Task<Void, Never>?
    private var alertTask: Task<Void, Never>?
    private var lockedDestination: PlaceLabel?
    private var alertDismissal = AlertDismissalState()
    private var hasStarted = false

    init(
        places: PlacesProviding = GooglePlacesService(),
        routes: RoutesProviding = GoogleRoutesService(),
        keychain: KeychainStoring = KeychainStore(),
        locationService: LocationService = LocationService(),
        alertService: AlertService = AlertService()
    ) {
        self.places = places
        self.routes = routes
        self.keychain = keychain
        self.locationService = locationService
        self.alertService = alertService
        self.apiKey = (try? keychain.readAPIKey()) ?? ""

        Task { [weak self] in
            await self?.start()
        }
    }

    var setupComplete: Bool {
        APIKeyValidator.looksValid(apiKey) && settings.isSetupComplete
    }

    func start() async {
        guard !hasStarted else {
            return
        }
        hasStarted = true

        locationService.onCoordinate = { [weak self] coordinate in
            Task { @MainActor in
                self?.currentCoordinate = coordinate
                await self?.refreshPlan()
            }
        }
        locationService.onStatusChange = { [weak self] status in
            self?.locationStatus = status
        }
        locationService.requestLocation()
        startCountdownTimer()
        await refreshPlan()
    }

    func saveAPIKey() {
        do {
            try keychain.saveAPIKey(apiKey)
            setupError = nil
        } catch {
            setupError = error.localizedDescription
        }
    }

    func saveSettings() {
        SettingsStore.save(settings)
        Task {
            await refreshPlan()
        }
    }

    func suggestions(for query: String) async -> [PlaceSuggestion] {
        do {
            return try await places.suggestions(for: query, apiKey: apiKey)
        } catch {
            setupError = error.localizedDescription
            return []
        }
    }

    func saveSuggestion(_ suggestion: PlaceSuggestion, as label: PlaceLabel) async {
        do {
            let place = try await places.placeDetails(
                placeID: suggestion.placeID,
                label: label,
                apiKey: apiKey
            )
            switch label {
            case .home:
                settings.home = place
            case .work:
                settings.work = place
            }
            saveSettings()
        } catch {
            setupError = error.localizedDescription
        }
    }

    func useCurrentLocation(as label: PlaceLabel) {
        locationService.requestLocation()
        guard let coordinate = currentCoordinate else {
            setupError = locationStatus.message
            return
        }

        let place = SavedPlace(
            label: label,
            formattedAddress: "Current Location",
            placeID: "current-\(label.rawValue)",
            coordinate: coordinate
        )
        switch label {
        case .home:
            settings.home = place
        case .work:
            settings.work = place
        }
        saveSettings()
    }

    func requestCurrentLocation() {
        locationService.requestLocation()
    }

    func refreshPlan() async {
        guard setupComplete else {
            countdown = .init(mode: .setupNeeded)
            diagnostics.recordNextRefresh(at: nil)
            return
        }
        isPlanning = true
        countdown = .init(mode: .planning, plan: lastPlan)
        defer { isPlanning = false }

        guard let home = settings.home, let work = settings.work else {
            countdown = .init(mode: .setupNeeded)
            return
        }

        let destination: SavedPlace
        if let coordinate = currentCoordinate {
            let planner = RoutePlanner(settings: settings)
            let choice = planner.destinationChoice(from: coordinate)
            guard let chosenDestination = choice.destination else {
                countdown = .init(mode: .setupNeeded)
                return
            }
            destination = chosenDestination
        } else {
            locationService.requestLocation()
            destination = manualOrigin == .home ? work : home
        }

        let effectiveDestination: SavedPlace
        if let lockedDestination {
            effectiveDestination = lockedDestination == .home ? home : work
        } else {
            effectiveDestination = destination
            lockedDestination = destination.label
        }
        let effectiveOrigin = effectiveDestination.label == .home ? work : home
        diagnostics.recordRequest(
            origin: effectiveOrigin,
            destination: effectiveDestination,
            requestedAt: Date()
        )

        do {
            let plan = try await routes.transitPlan(
                origin: effectiveOrigin,
                destination: effectiveDestination,
                apiKey: apiKey,
                bufferMinutes: settings.bufferMinutes
            )
            if lastPlan?.transitDepartureAt != plan.transitDepartureAt {
                alertDismissal.clear()
                stopAlertLoop()
            }
            lastPlan = plan
            diagnostics.recordSuccess(completedAt: Date())
            updateCountdown(now: Date())
            scheduleNextRefresh(for: plan)
        } catch {
            let message = error.localizedDescription
            diagnostics.recordFailure(message, completedAt: Date())
            diagnostics.recordNextRefresh(at: nil)
            countdown = .init(mode: .error(message), plan: lastPlan)
        }
    }

    func dismissAlert() {
        if let transitDepartureAt = lastPlan?.transitDepartureAt {
            alertDismissal.dismiss(transitDepartureAt: transitDepartureAt)
        }
        stopAlertLoop()
    }

    private func stopAlertLoop() {
        alertActive = false
        alertTask?.cancel()
        alertTask = nil
    }

    private func startCountdownTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateCountdown(now: Date())
            }
        }
    }

    private func updateCountdown(now: Date) {
        guard let plan = lastPlan else {
            if !setupComplete {
                countdown = .init(mode: .setupNeeded)
            }
            return
        }

        countdown = CountdownState(plan: plan, now: now)
        if case .missed = countdown.mode {
            lockedDestination = nil
            alertDismissal.clear()
            stopAlertLoop()
        }
        if settings.alertsEnabled && countdown.shouldAlert && alertDismissal.canAlert(for: plan.transitDepartureAt, now: now) {
            startAlertLoop(for: plan)
        }
    }

    private func scheduleNextRefresh(for plan: TransitPlan) {
        refreshTask?.cancel()
        let secondsUntilLeave = plan.leaveAt.timeIntervalSinceNow
        let interval = settings.refreshPolicy.interval(secondsUntilLeave: secondsUntilLeave)
        diagnostics.recordNextRefresh(at: Date().addingTimeInterval(interval))
        refreshTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(interval))
            guard !Task.isCancelled else { return }
            await self?.refreshPlan()
        }
    }

    private func startAlertLoop(for plan: TransitPlan) {
        guard !alertActive else {
            return
        }
        alertActive = true
        alertTask = Task { [weak self] in
            await self?.alertService.requestAuthorization()
            while !Task.isCancelled {
                let sentAt = Date()
                guard await MainActor.run(body: {
                    self?.alertDismissal.canAlert(for: plan.transitDepartureAt, now: sentAt) == true
                }) else {
                    break
                }

                await self?.alertService.sendDepartureAlert(plan: plan)
                let shouldContinue = await MainActor.run {
                    self?.alertDismissal.recordAlertSent(for: plan.transitDepartureAt, now: sentAt)
                    return self?.alertDismissal.canAlert(for: plan.transitDepartureAt, now: Date()) == true
                }
                guard shouldContinue else {
                    break
                }
                try? await Task.sleep(for: .seconds(30))
            }
            await MainActor.run {
                self?.stopAlertLoop()
            }
        }
    }
}
