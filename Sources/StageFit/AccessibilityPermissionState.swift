// Session-only state: permissions must be checked live, including after an update.
// A persisted "help already shown" flag must not hide recovery instructions.
struct AccessibilityPermissionState {
    private var didPresentHelp = false
    private var didRequestSystemPrompt = false

    mutating func shouldPresentHelp(isTrusted: Bool, explicitlyRequested: Bool = false) -> Bool {
        if isTrusted {
            didPresentHelp = false
            didRequestSystemPrompt = false
            return false
        }
        guard explicitlyRequested || !didPresentHelp else { return false }
        didPresentHelp = true
        return true
    }

    mutating func shouldRequestSystemPrompt(isTrusted: Bool) -> Bool {
        guard !isTrusted, !didRequestSystemPrompt else { return false }
        didRequestSystemPrompt = true
        return true
    }

    mutating func didResetPermission() {
        didPresentHelp = false
        didRequestSystemPrompt = false
    }
}
