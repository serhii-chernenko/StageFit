# StageFit

StageFit is a small, open-source macOS menu bar app that fits the front window to the usable display area while keeping space for Stage Manager's recent apps. Press **Control–Option–F** in any resizable window.

- With Stage Manager on, StageFit leaves a 202-point gap by default. The gap is on the left unless your Dock is on the left, in which case it is on the right. You can override the side and width from the menu bar.
- With Stage Manager off, the window uses the full area between the menu bar and Dock.
- The shortcut registers automatically when StageFit launches. The app also adds itself to **Open at Login** on first launch; you can turn that off from its menu.
- StageFit targets **macOS 13 or later**, on Apple Silicon and Intel Macs. This release was tested on macOS 27.

## Install from the DMG

1. Download `StageFit-0.1.0-universal.dmg` from [Releases](https://github.com/serhii-chernenko/macos-window-resizer-for-stage-manager/releases) and open it.
2. Drag **StageFit.app** onto the **Applications** shortcut in the disk image. Eject the image, then open StageFit from Applications.
3. On the first launch, macOS may show **“StageFit” Not Opened** and say that Apple could not verify it is free of malware. Click **Done** in that dialog.
4. Open **System Settings → Privacy & Security**, scroll down to **Security**, and click **Open Anyway** for StageFit. When the warning returns, click **Open** and enter your Mac password if asked. If **Open Anyway** is missing, try opening StageFit from Applications again, then return to this settings page. Apple makes the button available for [about an hour after a blocked launch](https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unknown-developer-mh40616/mac). This approves only StageFit; you do not need to disable Gatekeeper. [Apple's instructions](https://support.apple.com/102445)
5. StageFit will request Accessibility access. In **System Settings → Privacy & Security → Accessibility**, turn on **StageFit**. Return to your window and press **Control–Option–F**.

This first-launch warning appears because the downloadable app is **ad-hoc signed and not notarized**. The app cannot approve its own Gatekeeper exception.

**Accessibility approval cannot be automatic.** macOS requires the person using the Mac to grant it. StageFit requests the permission and opens the right settings page, but cannot switch its own permission on. The global shortcut and login item are set up by the app itself. [Apple's Accessibility API](https://developer.apple.com/documentation/applicationservices/1459186-axisprocesstrustedwithoptions)

> [!NOTE]
> Builds made without an Apple Developer ID cannot be notarized. macOS may ask for Accessibility approval again after an update because each ad-hoc signed build has a different code identity. If StageFit appears enabled but asks again, remove its old Accessibility entry, reopen StageFit, and enable the new entry. [Apple's distribution guidance](https://developer.apple.com/developer-id/)

## Use

Look for the StageFit window icon in the menu bar. Its menu lets you fit the front window, change the Stage Manager gap (160–280 points), choose **Automatic**, **Left**, or **Right** for the gap side, toggle **Open at Login**, and quit.

The app changes only the focused window's position and size. Some macOS dialogs, full-screen windows, and apps that block window resizing cannot be fitted. If **Control–Option–F** is already registered by another app, StageFit reports the conflict at launch.

## Build from source

Install Xcode or the Xcode Command Line Tools, then run:

```sh
Scripts/build-dmg.sh
```

The script builds a universal app, runs a geometry self-test on the host architecture, generates the icon, ad-hoc signs the app, and writes the DMG and its SHA-256 checksum to `dist/`. It uses only tools shipped with Xcode and macOS. No TestFlight, Apple Developer account, third-party dependency, or credential is needed.

## Privacy and uninstall

StageFit uses macOS Accessibility to read the front window's bounds and move or resize that window when you invoke it. It does not use Input Monitoring, send network requests, or collect telemetry. The source is available in this repository for inspection.

To update, quit StageFit before replacing it in Applications. To uninstall, quit StageFit from its menu, remove it from **System Settings → General → Login Items & Extensions** if present, then move StageFit.app from Applications to Trash. You can also remove its Accessibility entry from **Privacy & Security → Accessibility**.

## License

MIT. See [LICENSE](LICENSE).
