import AppKit
import ServiceManagement

enum TestError: Error { case failed }

final class FakeLoginItem: LoginItemService {
    var status: SMAppService.Status = .notRegistered
    var registeredStatus: SMAppService.Status = .enabled
    var registerCount = 0
    var unregisterCount = 0
    var shouldFail = false

    func register() throws {
        registerCount += 1
        if shouldFail { throw TestError.failed }
        status = registeredStatus
    }

    func unregister() throws {
        unregisterCount += 1
        if shouldFail { throw TestError.failed }
        status = .notRegistered
    }
}

func test(_ body: (FakeLoginItem, UserDefaults, LoginItemSettings) throws -> Void) throws {
    let suite = "StageFitTests.\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let service = FakeLoginItem()
    try body(service, preferences, LoginItemSettings(service: service, preferences: preferences))
}

try test { service, preferences, settings in
    try settings.configureOnFirstLaunch()
    precondition(service.registerCount == 1 && settings.menuState == .on)
    precondition(preferences.bool(forKey: "launchAtLogin"))
    // Removal outside StageFit must survive a restart.
    service.status = .notRegistered
    try settings.configureOnFirstLaunch()
    precondition(service.registerCount == 1 && settings.menuState == .off)
    try settings.toggle()
    precondition(service.registerCount == 2 && settings.menuState == .on)
    try settings.toggle()
    precondition(service.unregisterCount == 1 && !preferences.bool(forKey: "launchAtLogin"))
}

for oldPreference in [false, true] {
    try test { service, preferences, settings in
        preferences.set(oldPreference, forKey: "launchAtLogin")
        try settings.configureOnFirstLaunch()
        precondition(service.registerCount == 0)
    }
}

try test { service, preferences, settings in
    service.registeredStatus = .requiresApproval
    try settings.configureOnFirstLaunch()
    precondition(settings.requiresApproval && settings.menuState == .mixed)
    try settings.configureOnFirstLaunch()
    precondition(service.registerCount == 1)
    try settings.toggle()
    precondition(service.unregisterCount == 1 && service.registerCount == 1)
    precondition(settings.menuState == .off && !preferences.bool(forKey: "launchAtLogin"))
}

for initialStatus: SMAppService.Status in [.enabled, .requiresApproval, .notFound] {
    try test { service, _, settings in
        service.status = initialStatus
        try settings.configureOnFirstLaunch()
        precondition(service.registerCount == 0 && service.unregisterCount == 0)
    }
}

try test { service, preferences, settings in
    service.shouldFail = true
    do { try settings.configureOnFirstLaunch(); preconditionFailure("Expected registration failure") }
    catch TestError.failed {}
    precondition(!preferences.bool(forKey: "launchAtLogin"))
    try settings.configureOnFirstLaunch()
    precondition(service.registerCount == 1)
    service.shouldFail = false
    try settings.toggle()
    service.shouldFail = true
    do { try settings.toggle(); preconditionFailure("Expected removal failure") }
    catch TestError.failed {}
    precondition(settings.menuState == .on && preferences.bool(forKey: "launchAtLogin"))
}

print("Login item tests passed (first launch, upgrades, external removal, approval, errors)")
