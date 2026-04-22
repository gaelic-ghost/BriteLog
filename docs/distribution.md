# Distribution

BriteLog now has two planned direct-distribution artifact shapes:

- a system-wide macOS installer package for `/usr/local/...`
- a per-user zip bundle with a small installer script for `~/.local/...`

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

- The packaged binary is staged at `/usr/local/libexec/gaelic-ghost/britelog/<version>/britelog`
- The installer creates or updates `/usr/local/bin/britelog` as the public command path
- The final artifact is a `.pkg`

Build it with:

```bash
scripts/distribution/package-system-pkg.sh
```

### Per-User Zip Bundle

The per-user bundle is intended for people who do not want a system-wide install.

- The zip contains the `britelog` payload plus `install.sh`
- `install.sh` defaults to `~/.local/lib/gaelic-ghost/britelog/<version>/britelog`
- `install.sh` creates or updates `~/.local/bin/britelog`

Build it with:

```bash
scripts/distribution/package-user-zip.sh
```

## Signing and Notarization Inputs

The packaging scripts support notarization-oriented follow-through, but only when the necessary credentials are present.

Optional environment variables:

- `BRITELOG_INSTALLER_CERT`
  - A `Developer ID Installer` identity name used to sign the `.pkg`
- `BRITELOG_NOTARY_PROFILE`
  - A keychain profile name configured for `xcrun notarytool`
- `BRITELOG_ALLOW_UNSIGNED_RELEASE_ASSETS`
  - Defaults to `false`
  - When left at the default, GitHub release uploads require both signing inputs
  - Set it to `true` only for deliberate smoke testing of unsigned release assets

If those values are not set:

- the `.pkg` is still built, but left unsigned at the installer layer
- notarization is skipped
- the `.zip` is still built, but notarization is skipped

The Xcode build itself is still expected to produce a properly signed Release binary.

## Release Build Surface

The packaging scripts build the Xcode-managed wrapper target:

- project: `Apps/BriteLogTool/BriteLogTool.xcodeproj`
- scheme: `BriteLogTool`
- configuration: `Release`

The scripts use a derived data root under `dist/DerivedData/` so packaging output stays isolated from everyday development builds.

## GitHub Release Hosting

The intended release-hosting shape is now implemented:

- upload the final `.pkg` to a GitHub release as the default system-wide installer
- upload the final `.zip` to the same GitHub release as the per-user install option

The repo-maintenance release workflow now builds and uploads those artifacts automatically after the GitHub release object exists:

```bash
BRITELOG_INSTALLER_CERT="Developer ID Installer: Your Name (TEAMID)" \
BRITELOG_NOTARY_PROFILE="britelog-notary" \
scripts/repo-maintenance/release.sh --version v0.1.0
```

That release flow will:

- create or reuse the `v0.1.0` tag locally
- push the branch and tag
- create the GitHub release object
- build the Release wrapper binary
- package the `.pkg` and `.zip`
- notarize them when the notary profile is configured
- upload both artifacts to the GitHub release

If you need to publish the git tag and GitHub release without packaging artifacts, pass:

```bash
scripts/repo-maintenance/release.sh --version v0.1.0 --skip-distribution-assets
```
