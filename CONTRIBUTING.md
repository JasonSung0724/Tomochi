# Contributing to Tomochi

Thanks for helping! Issues and PRs are welcome.

## Build

No Xcode required — Apple's Command Line Tools are enough.

```sh
make dev      # debug build + run in place
make run      # release build → install to /Applications → launch
make clean
```

Or open `Package.swift` in Xcode and hit Run.

## Code style

- Swift 5 mode, SwiftUI, no dependencies beyond Sparkle.
- Match the existing style: `// MARK: -` sections, tolerant `Codable`
  decoding for anything the AI may edit, `@MainActor` for observable state.
- UI text is English and terse. Comments and docs are English.

## Testing your changes

- `bash scripts/build.sh release` must produce a working `Tomochi.app`.
- If you touch the AI workspace schema, update `WorkspacePrimer.swift`
  (bump its `version`) and the README architecture section together.

## PR process

1. Fork, branch from `main`.
2. Keep PRs focused; describe the user-visible change.
3. CI must pass (release build on macOS).

## Releasing (maintainers)

Bump `CFBundleShortVersionString` in `Info.plist`, update `CHANGELOG.md`, and
push to `main` — CI builds, signs the appcast, and publishes the GitHub
release automatically.
