import AppKit
import ApplicationServices
import Carbon
import ServiceManagement

private let hotKeySignature: OSType = 0x53544654 // STFT
private let defaultGap: CGFloat = 202
private let bundleID = "com.serhiichernenko.stagefit"

private enum GapSide: Int {
    case automatic = 0
    case left = 1
    case right = 2
}

private func stageManagerIsEnabled() -> Bool {
    UserDefaults(suiteName: "com.apple.WindowManager")?.bool(forKey: "GloballyEnabled") ?? false
}

private func effectiveSide(_ preference: GapSide) -> GapSide {
    if preference != .automatic { return preference }
    let dockPosition = UserDefaults(suiteName: "com.apple.dock")?.string(forKey: "orientation")
    return dockPosition == "left" ? .right : .left
}

private func fittedFrame(visible: CGRect, stageManagerEnabled: Bool,
                         side: GapSide, gap: CGFloat) -> CGRect {
    guard stageManagerEnabled else { return visible }
    let inset = min(max(gap, 0), visible.width * 0.4)
    switch side {
    case .right:
        return CGRect(x: visible.minX, y: visible.minY,
                      width: visible.width - inset, height: visible.height)
    case .left, .automatic:
        return CGRect(x: visible.minX + inset, y: visible.minY,
                      width: visible.width - inset, height: visible.height)
    }
}

private func copyAttribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
    return value
}

private func readFrame(_ window: AXUIElement) -> CGRect? {
    guard let positionRaw = copyAttribute(window, kAXPositionAttribute),
          let sizeRaw = copyAttribute(window, kAXSizeAttribute),
          CFGetTypeID(positionRaw) == AXValueGetTypeID(),
          CFGetTypeID(sizeRaw) == AXValueGetTypeID() else { return nil }
    var point = CGPoint.zero
    var size = CGSize.zero
    guard AXValueGetValue(positionRaw as! AXValue, .cgPoint, &point),
          AXValueGetValue(sizeRaw as! AXValue, .cgSize, &size) else { return nil }
    return CGRect(origin: point, size: size)
}

private func writeFrame(_ window: AXUIElement, _ frame: CGRect) -> Bool {
    var point = frame.origin
    var size = frame.size
    guard let pointValue = AXValueCreate(.cgPoint, &point),
          let sizeValue = AXValueCreate(.cgSize, &size) else { return false }
    let firstMove = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, pointValue)
    let resize = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
    let lastMove = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, pointValue)
    return firstMove == .success && resize == .success && lastMove == .success
}

private final class StageFitController: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var hotKey: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var lastActivePID: pid_t?
    private let preferences = UserDefaults.standard

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        if Bundle.main.bundleURL.path.hasPrefix("/Volumes/") {
            DispatchQueue.main.async { [weak self] in
                self?.showMessage("Move StageFit to Applications",
                                  "Drag StageFit.app from the disk image to Applications, eject the disk image, then open StageFit from Applications. This keeps Open at Login working after the disk image is ejected.")
                NSApp.terminate(nil)
            }
            return
        }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "rectangle.inset.filled",
                                           accessibilityDescription: "StageFit")
        statusItem.button?.toolTip = "StageFit — Control–Option–F"
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(applicationActivated(_:)),
            name: NSWorkspace.didActivateApplicationNotification, object: nil)

        registerHotKey()
        registerLoginItemIfWanted()
        requestAccessibilityOnFirstLaunch()
    }

    private func registerHotKey() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        let handlerStatus = InstallEventHandler(GetApplicationEventTarget(), hotKeyHandler,
                                                1, &eventType, nil, &eventHandler)
        let shortcutStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_F), UInt32(controlKey | optionKey),
            EventHotKeyID(signature: hotKeySignature, id: 1),
            GetApplicationEventTarget(), 0, &hotKey)
        if handlerStatus != noErr || shortcutStatus != noErr {
            NSLog("StageFit: hotkey registration failed (%d, %d)", handlerStatus, shortcutStatus)
            DispatchQueue.main.async { [weak self] in
                self?.showMessage("Shortcut unavailable",
                                  "Control–Option–F may already be used by macOS or another app. Quit that app or change its shortcut, then restart StageFit.")
            }
        }
    }

    private func registerLoginItemIfWanted() {
        if preferences.object(forKey: "launchAtLogin") == nil {
            preferences.set(true, forKey: "launchAtLogin")
        }
        guard preferences.bool(forKey: "launchAtLogin"),
              SMAppService.mainApp.status == .notRegistered else { return }
        do { try SMAppService.mainApp.register() }
        catch { NSLog("StageFit: could not register login item: %@", String(describing: error)) }
    }

    private func requestAccessibilityOnFirstLaunch() {
        guard !AXIsProcessTrusted() else { return }
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        guard !preferences.bool(forKey: "didShowAccessibilityHelp") else { return }
        preferences.set(true, forKey: "didShowAccessibilityHelp")
        DispatchQueue.main.async { [weak self] in
            let alert = NSAlert()
            alert.messageText = "One step before StageFit can resize windows"
            alert.informativeText = "macOS requires you to turn on StageFit in System Settings → Privacy & Security → Accessibility. StageFit cannot grant this permission for you."
            alert.addButton(withTitle: "Open Accessibility Settings")
            alert.addButton(withTitle: "Later")
            NSApp.activate(ignoringOtherApps: true)
            if alert.runModal() == .alertFirstButtonReturn { self?.openAccessibilitySettings() }
        }
    }

    @objc private func applicationActivated(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                as? NSRunningApplication,
              app.bundleIdentifier != bundleID else { return }
        lastActivePID = app.processIdentifier
    }

    func fitWindow() {
        guard AXIsProcessTrusted() else {
            _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
            showMessage("Accessibility access needed",
                        "Turn on StageFit in System Settings → Privacy & Security → Accessibility, then try the shortcut again.")
            return
        }
        let active = NSWorkspace.shared.frontmostApplication
        let pid = active?.bundleIdentifier == bundleID ? lastActivePID : active?.processIdentifier
        guard let pid else { NSSound.beep(); return }
        let application = AXUIElementCreateApplication(pid)
        guard let windowRaw = copyAttribute(application, kAXFocusedWindowAttribute)
                ?? copyAttribute(application, kAXMainWindowAttribute),
              CFGetTypeID(windowRaw) == AXUIElementGetTypeID(),
              let mainScreen = NSScreen.screens.first else { NSSound.beep(); return }
        let window = windowRaw as! AXUIElement
        guard let current = readFrame(window) else { NSSound.beep(); return }

        // Accessibility uses a top-left origin. AppKit uses a bottom-left origin.
        let primaryTop = mainScreen.frame.maxY
        let cocoaWindow = CGRect(x: current.minX, y: primaryTop - current.maxY,
                                 width: current.width, height: current.height)
        let screen = NSScreen.screens.max { a, b in
            let aFrame = a.frame.intersection(cocoaWindow)
            let bFrame = b.frame.intersection(cocoaWindow)
            return aFrame.width * aFrame.height < bFrame.width * bFrame.height
        } ?? mainScreen
        let chosenGap = preferences.object(forKey: "gapPoints") == nil
            ? defaultGap : CGFloat(preferences.integer(forKey: "gapPoints"))
        let side = effectiveSide(GapSide(rawValue: preferences.integer(forKey: "gapSide")) ?? .automatic)
        let targetInCocoa = fittedFrame(visible: screen.visibleFrame,
                                       stageManagerEnabled: stageManagerIsEnabled(),
                                       side: side, gap: chosenGap)
        let target = CGRect(x: targetInCocoa.minX,
                            y: primaryTop - targetInCocoa.maxY,
                            width: targetInCocoa.width,
                            height: targetInCocoa.height)
        if !writeFrame(window, target) { NSSound.beep() }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let fit = NSMenuItem(title: "Fit Front Window     ⌃⌥F", action: #selector(fitFromMenu), keyEquivalent: "")
        fit.target = self
        menu.addItem(fit)
        menu.addItem(.separator())

        let access = NSMenuItem(title: AXIsProcessTrusted() ? "Accessibility: Granted" : "Grant Accessibility…",
                                action: #selector(openAccessibilitySettings), keyEquivalent: "")
        access.target = self
        menu.addItem(access)

        let login = NSMenuItem(title: "Open at Login", action: #selector(toggleLoginItem), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)

        let gapMenu = NSMenu()
        let currentGap = preferences.object(forKey: "gapPoints") == nil
            ? Int(defaultGap) : preferences.integer(forKey: "gapPoints")
        for value in [160, 180, 202, 220, 240, 280] {
            let item = NSMenuItem(title: "\(value) points", action: #selector(selectGap(_:)), keyEquivalent: "")
            item.target = self
            item.tag = value
            item.state = value == currentGap ? .on : .off
            gapMenu.addItem(item)
        }
        let gap = NSMenuItem(title: "Stage Manager Gap", action: nil, keyEquivalent: "")
        gap.submenu = gapMenu
        menu.addItem(gap)

        let sideMenu = NSMenu()
        let currentSide = preferences.integer(forKey: "gapSide")
        for (value, title) in [(0, "Automatic"), (1, "Left"), (2, "Right")] {
            let item = NSMenuItem(title: title, action: #selector(selectSide(_:)), keyEquivalent: "")
            item.target = self
            item.tag = value
            item.state = value == currentSide ? .on : .off
            sideMenu.addItem(item)
        }
        let side = NSMenuItem(title: "Gap Side", action: nil, keyEquivalent: "")
        side.submenu = sideMenu
        menu.addItem(side)

        menu.addItem(.separator())
        let about = NSMenuItem(title: "About StageFit", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)
        let quit = NSMenuItem(title: "Quit StageFit", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    @objc private func fitFromMenu() { fitWindow() }
    @objc private func selectGap(_ item: NSMenuItem) { preferences.set(item.tag, forKey: "gapPoints") }
    @objc private func selectSide(_ item: NSMenuItem) { preferences.set(item.tag, forKey: "gapSide") }
    @objc private func toggleLoginItem() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
                preferences.set(false, forKey: "launchAtLogin")
            } else {
                try service.register()
                preferences.set(true, forKey: "launchAtLogin")
            }
        } catch { showMessage("Could not change Open at Login", error.localizedDescription) }
    }
    @objc private func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }
    @objc private func showAbout() {
        showMessage("StageFit 0.1.0", "Press Control–Option–F to fit a window while leaving room for Stage Manager. Open source under the MIT License.")
    }
    @objc private func quit() { NSApp.terminate(nil) }

    private func showMessage(_ title: String, _ text: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}

private var controller: StageFitController?
private let hotKeyHandler: EventHandlerUPP = { _, event, _ in
    guard let event else { return noErr }
    var identifier = EventHotKeyID()
    let result = GetEventParameter(event, EventParamName(kEventParamDirectObject),
                                   EventParamType(typeEventHotKeyID), nil,
                                   MemoryLayout<EventHotKeyID>.size, nil, &identifier)
    if result == noErr && identifier.signature == hotKeySignature && identifier.id == 1 {
        controller?.fitWindow()
    }
    return noErr
}

if CommandLine.arguments.contains("--self-test") {
    let screen = CGRect(x: 0, y: 0, width: 1728, height: 1000)
    let left = fittedFrame(visible: screen, stageManagerEnabled: true, side: .left, gap: 202)
    let right = fittedFrame(visible: screen, stageManagerEnabled: true, side: .right, gap: 202)
    let off = fittedFrame(visible: screen, stageManagerEnabled: false, side: .left, gap: 202)
    precondition(left == CGRect(x: 202, y: 0, width: 1526, height: 1000))
    precondition(right == CGRect(x: 0, y: 0, width: 1526, height: 1000))
    precondition(off == screen)
    print("Geometry self-test passed")
    exit(0)
}

let app = NSApplication.shared
controller = StageFitController()
app.delegate = controller
app.run()
