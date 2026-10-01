# Changelog

## 0.2.2 — 2026-10-01

- Add a permanent **Help → Accessibility After Updates…** menu item with recovery steps, available even when Accessibility is granted. Opening help does not request or reset permission.
- Add **Help → Troubleshooting Online…** linking directly to the README's Troubleshooting section.
- Explain that each ad-hoc signed update can require renewed Accessibility approval, whether installed in the app or from a DMG. Try toggling access first; reset only if that fails.

## 0.2.1 — 2026-10-01

- Stop requesting macOS permission and showing an overlapping app dialog on every resize attempt. Show recovery help once per session, with an explicit menu action to reopen it.
- Add **Repair Accessibility Access…** with instructions for an enabled but stale permission after an update. A confirmed reset clears only StageFit's Accessibility grant and opens System Settings for user approval.
- Show fresh permission-recovery instructions after updates even if an older version already displayed first-launch help.
- Use **Device Control and Data Access** as the settings name on macOS 27.
- Support `STAGEFIT_SIGNING_IDENTITY` in the build script so maintainers can use the same certificate across builds, preserving code identity instead of relying on changing ad-hoc hashes. An invalid selected identity fails the build rather than falling back.
- Add regression tests for repeated shortcuts, explicit recovery, grant/revocation, and reset.

This release remains ad-hoc signed and not notarized. User approval is still needed after updating; signing update archives with Ed25519 does not preserve macOS Accessibility grants. Stable certificate signing is required to address that identity change across future builds.

## 0.2.0 — 2026-10-01

- Add **Check for Updates…** to the menu bar menu, available by click or right-click. Sparkle shows release notes, downloads signed updates, installs them, and relaunches StageFit.
- Require signed update feeds and verify Ed25519 archive signatures before extraction. Update checks are manual by default; automatic installation and system-profile reporting are disabled.
- Improve **Open at Login** with live system status, a visible approval-pending state, and a shortcut to Login Items settings.
- Respect login-item changes made in System Settings and previous preferences across app launches and upgrades.
- Show login-item registration failures and allow retrying from the menu.
- Add login-item regression tests and a release-signing script, and distribute a ZIP update archive alongside the DMG.
- Read the About version from the app bundle and correct the README release link.

Users on 0.1.0 need to install 0.2.0 from the DMG once to gain in-app updates. Builds remain ad-hoc signed and not notarized; macOS may require renewed Accessibility approval after updates.

## 0.1.0 — 2026-09-24

- Initial universal macOS menu bar app with Control–Option–F window fitting, Stage Manager gap controls, Accessibility setup, and Open at Login.
- Add an ad-hoc signed DMG, checksums, and a reproducible build script for macOS 13 and later.
