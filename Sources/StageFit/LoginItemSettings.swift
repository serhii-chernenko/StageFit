import AppKit
import ServiceManagement

protocol LoginItemService {
    var status: SMAppService.Status { get }
    func register() throws
    func unregister() throws
}

extension SMAppService: LoginItemService {}

struct LoginItemSettings {
    let service: any LoginItemService
    let preferences: UserDefaults
    private let preferenceKey = "launchAtLogin"

    var menuState: NSControl.StateValue {
        switch service.status {
        case .enabled: return .on
        case .requiresApproval: return .mixed
        default: return .off
        }
    }

    var requiresApproval: Bool { service.status == .requiresApproval }

    func configureOnFirstLaunch() throws {
        // The existing preference also marks that setup has already happened.
        // Never undo a later removal or denial in System Settings on app launch.
        guard preferences.object(forKey: preferenceKey) == nil else { return }
        preferences.set(false, forKey: preferenceKey)
        if service.status == .notRegistered { try service.register() }
        preferences.set(service.status == .enabled || requiresApproval, forKey: preferenceKey)
    }

    func toggle() throws {
        switch service.status {
        case .enabled, .requiresApproval:
            try service.unregister()
            preferences.set(false, forKey: preferenceKey)
        default:
            try service.register()
            preferences.set(true, forKey: preferenceKey)
        }
    }
}
