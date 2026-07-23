# Contributing to TaskMatrix

Thanks for helping improve TaskMatrix. This project is a small native macOS app,
so contributions should keep the codebase simple, dependency-light, and easy to
build from Xcode.

## Development Setup

Requirements:

- macOS
- Xcode with Swift 5 and AppKit support

Open the project:

```sh
open TaskMatrix.xcodeproj
```

Build from the command line:

```sh
xcodebuild build -project TaskMatrix.xcodeproj -scheme TaskMatrix -destination 'platform=macOS'
```

Run tests:

```sh
xcodebuild test -project TaskMatrix.xcodeproj -scheme TaskMatrixTests -destination 'platform=macOS'
```

## Contribution Flow

1. Open an issue before starting large behavior or UI changes.
2. Create a focused branch from `main`.
3. Keep changes scoped to one feature or fix.
4. Add or update tests when changing model, storage, sorting, archive, settings,
   date formatting, or statistics behavior.
5. Run the build and test commands before opening a pull request.
6. Fill out the pull request template with verification details.

## Code Style

- Follow the existing AppKit and Swift patterns in the repository.
- Prefer explicit, readable code over clever abstractions.
- Keep source files ASCII unless a file already uses non-ASCII text for a clear
  reason.
- Avoid adding third-party dependencies unless the benefit is substantial and
  discussed first.
- Keep user-facing app text in English.

## Pull Request Checklist

- The app target builds.
- The test target passes.
- Relevant documentation is updated.
- No local user settings, build artifacts, DMGs, credentials, provisioning
  profiles, or signing certificates are committed.

