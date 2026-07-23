# Release Process

This document defines how TaskMatrix releases are prepared and published.

## Versioning

Use semantic version tags:

```sh
vMAJOR.MINOR.PATCH
```

Examples:

- `v1.0.0` for the first stable public release.
- `v1.0.1` for a bug fix release.
- `v1.1.0` for a backward-compatible feature release.

## Release Checklist

1. Confirm the working tree is clean.
2. Update `CHANGELOG.md`.
3. Run the app build:

   ```sh
   xcodebuild build -project TaskMatrix.xcodeproj -scheme TaskMatrix -destination 'platform=macOS'
   ```

4. Run tests:

   ```sh
   xcodebuild test -project TaskMatrix.xcodeproj -scheme TaskMatrixTests -destination 'platform=macOS'
   ```

5. Build Release:

   ```sh
   xcodebuild build -project TaskMatrix.xcodeproj -scheme TaskMatrix -configuration Release -destination 'platform=macOS' -derivedDataPath DerivedData
   ```

6. Package the DMG:

   ```sh
   scripts/package_dmg.sh DerivedData/Build/Products/Release/TaskMatrix.app TaskMatrix-1.0.0.dmg
   hdiutil verify TaskMatrix-1.0.0.dmg
   ```

7. Create and push the release tag:

   ```sh
   git tag v1.0.0
   git push origin v1.0.0
   ```

8. Confirm the GitHub Release workflow succeeds and uploads the DMG.

## Automated GitHub Release

`.github/workflows/release.yml` runs when a `v*` tag is pushed. It:

- Checks out the repository.
- Builds the Release configuration.
- Runs the test suite.
- Packages `TaskMatrix.app` into a DMG.
- Verifies the DMG.
- Creates a GitHub Release and uploads the DMG.

The generated DMG is unsigned unless the workflow is extended with a Developer
ID certificate and notarization step.

## Signing and Notarization

Public end-user distribution should use Apple Developer ID signing and Apple
notarization. Do not commit certificates, provisioning profiles, passwords, or
notarization credentials.

If signing automation is added later, store credentials only in GitHub Actions
Secrets. Typical secret categories are:

- Developer ID Application certificate in an encrypted export format.
- Certificate password.
- Apple ID or App Store Connect API key credentials.
- Apple Team ID.

Document any required secret names in this file when the workflow is extended.

## Manual Release Notes

Use `CHANGELOG.md` as the source of truth for release notes. GitHub Release
notes can summarize the relevant version section and link back to the changelog.

