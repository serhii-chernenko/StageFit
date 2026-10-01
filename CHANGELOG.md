# Changelog

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
