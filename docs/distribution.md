# Distribution

BriteLog now packages the signed native app host only. The shared package executable remains a development harness, not a supported standalone product surface.

The current direct-distribution artifact shapes are:

- a system-wide macOS installer package for `BriteLog.app`
- a notarizable zip bundle containing `BriteLog.app`

The packaging scripts live under [`scripts/distribution/`](../scripts/distribution).

## Build Helpers

Build both release artifacts together with:

```bash
scripts/distribution/build-release-artifacts.sh
```

Upload both artifacts to an existing GitHub release with:

```bash
BRITELOG_INSTALLER_CERT="Developer ID Installer: Your Name (TEAMID)" \
BRITELOG_NOTARY_PROFILE="britelog-notary" \
scripts/distribution/upload-github-release-artifacts.sh --release-tag v0.1.0 --build
```

## Artifact Shapes

### System-Wide Installer Package

The system-wide installer is intended to be the default download for most users.

- the package installs `BriteLog.app` into `/Applications`
- the final artifact is a `.pkg`

Build it with:

```bash
scripts/distribution/package-system-pkg.sh
```

### App Zip Bundle

The zip bundle is intended for manual or drag-and-drop installation.

- the zip contains `BriteLog.app`
- users can unpack it and move the app into `/Applications`
- the final artifact is a `.zip`

Build it with:

```bash
scripts/distribution/package-app-zip.sh
```

## Signing and Notarization Inputs

The packaging scripts support notarization-oriented follow-through, but only when the necessary credentials are present.

Optional environment variables:

- `BRITELOG_INSTALLER_CERT`
  - a `Developer ID Installer` identity name used to sign the `.pkg`
- `BRITELOG_NOTARY_PROFILE`
  - a keychain profile name configured for `xcrun notarytool`
- `BRITELOG_ALLOW_UNSIGNED_RELEASE_ASSETS`
  - defaults to `false`
  - when left at the default, GitHub release uploads require both signing inputs
  - set it to `true` only for deliberate smoke testing of unsigned release assets

If those values are not set:

- the `.pkg` is still built, but left unsigned at the installer layer
- notarization is skipped
- the `.zip` is still built, but notarization is skipped

The Xcode build itself is still expected to produce a properly signed Release app bundle.

## Release Build Surface

The packaging scripts build the Xcode-managed app target:

- project: `Apps/BriteLog/BriteLog.xcodeproj`
- scheme: `BriteLog`
- configuration: `Release`

The scripts use a derived data root under `dist/DerivedData/` so packaging output stays isolated from everyday development builds.

## Restricted Entitlement Note

Apple documents that `OSLogStore.local()` requires `com.apple.logging.local-store`, and local verification in this repo shows that macOS treats that as a restricted entitlement that needs a matching provisioning profile before launch is allowed.

So these packaging scripts now describe the right product shape, but successful launch of the built app still depends on the provisioning story being satisfied for that entitlement-bearing app build.

## GitHub Release Hosting

The intended release-hosting shape is now:

- upload the final `.pkg` to a GitHub release as the default installer
- upload the final `.zip` to the same GitHub release as the manual-install option

The repo-maintenance release workflow builds and uploads those artifacts automatically after the GitHub release object exists:

```bash
BRITELOG_INSTALLER_CERT="Developer ID Installer: Your Name (TEAMID)" \
BRITELOG_NOTARY_PROFILE="britelog-notary" \
scripts/repo-maintenance/release.sh --version v0.1.0
```

That release flow will:

- create or reuse the `v0.1.0` tag locally
- push the branch and tag
- create the GitHub release object
- build the Release app bundle
- package the `.pkg` and `.zip`
- notarize them when the notary profile is configured
- upload both artifacts to the GitHub release

If you need to publish the git tag and GitHub release without packaging artifacts, pass:

```bash
scripts/repo-maintenance/release.sh --version v0.1.0 --skip-distribution-assets
```
