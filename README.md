# StageFit

StageFit is a small, open-source macOS menu bar app that fits the front window to the usable display area while keeping space for Stage Manager's recent apps. Press **Control–Option–F** in any resizable window.

- With Stage Manager on, StageFit leaves a 202-point gap by default. The gap is on the left unless your Dock is on the left, in which case it is on the right. You can override the side and width from the menu bar.
- With Stage Manager off, the window uses the full area between the menu bar and Dock.
- The shortcut registers automatically when StageFit launches. The app also adds itself to **Open at Login** on first launch; you can turn that off from its menu.
- Choose **Check for Updates…** from the menu bar to download, install, and relaunch a newer version in the app.
- StageFit targets **macOS 13 or later**, on Apple Silicon and Intel Macs. This release was tested on macOS 27.

## Install from the DMG

1. Download `StageFit-0.2.1-universal.dmg` from [Releases](https://github.com/serhii-chernenko/StageFit/releases/latest) and open it.
2. Drag **StageFit.app** onto the **Applications** shortcut in the disk image. Eject the image, then open StageFit from Applications.
3. On the first launch, macOS may show **“StageFit” Not Opened** and say that Apple could not verify it is free of malware. Click **Done** in that dialog.
4. Open **System Settings → Privacy & Security**, scroll down to **Security**, and click **Open Anyway** for StageFit. When the warning returns, click **Open** and enter your Mac password if asked. If **Open Anyway** is missing, try opening StageFit from Applications again, then return to this settings page. Apple makes the button available for [about an hour after a blocked launch](https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unknown-developer-mh40616/mac). This approves only StageFit; you do not need to disable Gatekeeper. [Apple's instructions](https://support.apple.com/102445)
5. Choose **Open Settings** in StageFit's permission help. In **System Settings → Privacy & Security → Accessibility** (called **Device Control and Data Access** on macOS 27), turn on **StageFit**. Return to your window and press **Control–Option–F**.

This first-launch warning appears because the downloadable app is **ad-hoc signed and not notarized**. The app cannot approve its own Gatekeeper exception.

**Accessibility approval cannot be automatic.** macOS requires the person using the Mac to grant it. StageFit requests the permission and opens the right settings page, but cannot switch its own permission on. The global shortcut and login item are set up by the app itself. [Apple's Accessibility API](https://developer.apple.com/documentation/applicationservices/1459186-axisprocesstrustedwithoptions)

> [!NOTE]
> Builds made without an Apple Developer ID cannot be notarized. macOS may ask for Accessibility approval again after an update because each ad-hoc signed build has a different code identity. If StageFit appears enabled but asks again, remove its old Accessibility entry, reopen StageFit, and enable the new entry. [Apple's distribution guidance](https://developer.apple.com/developer-id/)

### Accessibility enabled, but resizing still asks for access

An enabled entry can refer to an older ad-hoc signature. The update's Ed25519 signature proves who published the download; macOS tracks Accessibility permission using the app's separate code-signing identity.

1. Choose **Repair Accessibility Access…** from the StageFit menu.
2. Try turning StageFit off and on in **Accessibility / Device Control and Data Access**. If it still fails, return to StageFit's help and choose **Reset StageFit Access…**, then confirm **Reset Access**. This clears only StageFit's grant; it does not enable access automatically.
3. In System Settings, enable the new StageFit entry. If it is missing, use **+** to add `/Applications/StageFit.app`. Close old permission dialogs and restart StageFit if the change is not picked up immediately.

StageFit shows recovery help once per session, and the menu can reopen it. It requests the native macOS permission prompt only when you choose to open the settings or confirm a reset.

## Use

Look for the StageFit window icon in the menu bar. Click or right-click it to fit the front window, change the Stage Manager gap (160–280 points), choose **Automatic**, **Left**, or **Right** for the gap side, toggle **Open at Login**, check for updates, or quit.

**Open at Login** shows a checkmark when enabled and a dash with **Approval Required** when macOS needs your approval. Choose **Approve Open at Login…** to open the relevant System Settings page, or click the toggle to cancel the registration. **Login Items Settings…** is also available when approval is not pending. Changes made in System Settings are reflected the next time you open the menu and are respected when StageFit restarts.

**Check for Updates…** shows release notes when a newer version is available and offers **Install Update**. StageFit downloads the update, verifies its signature, then installs it and relaunches. Update checks are manual; background checks, automatic installation, and system-profile reporting are disabled by default. Offline and failed checks show an error and can be retried. Install StageFit in Applications first so it can update in place.

If you are upgrading from **0.1.0**, install **0.2.1** from the DMG once to get the updater. Later releases can be installed through the menu. Accessibility approval still needs to be renewed after an update because the published builds are ad-hoc signed.

The app changes only the focused window's position and size. Some macOS dialogs, full-screen windows, and apps that block window resizing cannot be fitted. If **Control–Option–F** is already registered by another app, StageFit reports the conflict at launch.

## Build from source

Install Xcode or the Xcode Command Line Tools, then run:

```sh
Scripts/build-dmg.sh
```

The script builds a universal app, runs geometry and login-item tests, generates the icon, ad-hoc signs the app, and writes DMG and ZIP archives plus SHA-256 checksums to `dist/`. It downloads [Sparkle 2.10.0](https://github.com/sparkle-project/Sparkle/releases/tag/2.10.0), verifies its pinned SHA-256 hash, and embeds the framework and its license. No TestFlight, Apple Developer account, or credential is needed to build.

To preserve the app's code identity across builds, set `STAGEFIT_SIGNING_IDENTITY` to an existing code-signing certificate name or SHA-1 identity before building or preparing a release. For example:

```sh
STAGEFIT_SIGNING_IDENTITY='Developer ID Application: Your Name (TEAMID)' Scripts/prepare-release.sh
```

Use the same certificate for subsequent builds. The first switch from ad-hoc signing still needs renewed approval. This option does not configure notarization; notarized distribution also needs proper signing of nested Sparkle components, Hardened Runtime, and Apple's notarization process. See [Apple's code-signing guidance](https://developer.apple.com/library/archive/technotes/tn2206/_index.html). Without a selected certificate, builds remain ad-hoc signed and the script warns that Accessibility approval must be renewed. No weaker custom identity requirement or TCC database modification is used.

## Publish a release

1. Update both version fields in `Resources/Info.plist` (the build number must increase), `Resources/ReleaseNotes.html`, this README, and `CHANGELOG.md`.
2. Run `Scripts/prepare-release.sh` on the maintainer Mac. It builds the archives and signs the ZIP and appcast with the StageFit Ed25519 key stored in the login Keychain under account `com.serhiichernenko.stagefit`. It refuses to sign if the key does not match the app's public key. The private key is never stored in the repository. Keep a secure backup: ad-hoc signed apps cannot recover from a lost update-signing key through Developer ID key rotation.
3. After merging the release PR and passing CI, publish a GitHub release tagged `v<version>` with `StageFit-<version>-universal.dmg`, `StageFit-<version>-universal.zip`, `appcast.xml`, and `SHA256SUMS.txt` from `dist/`.

The updater reads `appcast.xml` from the latest GitHub release. Publish all four assets together and keep older release archives available. The app requires signed feeds and verifies update archives before extraction. See [Sparkle's signing documentation](https://sparkle-project.org/documentation/) for key backup and recovery guidance. CI builds downloadable artifacts without needing access to the private signing key; release signing happens on the maintainer Mac.

## Privacy and uninstall

StageFit uses macOS Accessibility to read the front window's bounds and move or resize that window when you invoke it. It does not use Input Monitoring or collect telemetry. When you check for updates, it connects to GitHub to read the release feed and download an update you choose to install. System-profile reporting is disabled. The source is available in this repository for inspection.

To update, use **Check for Updates…** from the menu, or quit StageFit before manually replacing it in Applications. To uninstall, turn off **Open at Login**, quit StageFit, then move StageFit.app from Applications to Trash. You can also remove it from **System Settings → General → Login Items & Extensions** and remove its Accessibility entry from **Privacy & Security → Accessibility**.

## License

MIT. See [LICENSE](LICENSE).
