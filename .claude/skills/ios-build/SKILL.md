---
name: ios-build
description: Build and archive the iOS app for App Store distribution. Bumps the build number in pubspec.yaml, commits that bump, produces a signed .xcarchive and .ipa, then opens Transporter with the IPA revealed in Finder. Use whenever asked to build, archive, or prepare an iOS/App Store/TestFlight release ("gerar build", "build ios", "archive", "make a build"). Stops at the handoff — the user uploads it themselves.
---

# iOS build & archive

Produce a signed App Store archive + IPA. **Always** bump the build number, **always** commit that bump, **always** archive. **Never** upload — the user does that step.

## Project signing facts

Verified in this project; treat as expected values, not things to reconfigure:

| Item | Value |
|---|---|
| Team | `VL7N29DY3D` |
| Signing identity | `Apple Distribution: Douglas Pereira (VL7N29DY3D)` |
| Profile | "Acertos mobile", UUID `78e0691a-02d7-482e-a25d-1376e58fd6bd` (App Store, expires Jun 2027) |
| Bundle ID | `com.example.acertosMobile` |
| Style | Manual signing (set in `ios/Runner.xcodeproj/project.pbxproj`) |

## Steps

### 1. Preflight

```bash
git rev-parse --abbrev-ref HEAD          # note the branch
git status --short                        # note pre-existing changes
flutter pub get
```

If `pubspec.yaml` already has uncommitted changes, ask before committing — the bump commit must contain *only* the version bump.

### 2. Bump the build number

Increment the `+N` suffix only. Leave the semantic version (`1.0.0`) alone unless the user explicitly asks for a version change.

```bash
perl -i -pe 's/^(version:\s*\d+\.\d+\.\d+\+)(\d+)\s*$/$1.($2+1)."\n"/e' pubspec.yaml
grep '^version:' pubspec.yaml
```

### 3. Commit the bump

Stage `pubspec.yaml` **and nothing else** — other files in the tree stay uncommitted.

```bash
git add pubspec.yaml
git commit -m "$(cat <<'EOF'
chore: bump build number to <NEW_VERSION>

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

Do not push. Do not commit the build artifacts — `build/` is generated.

### 4. Build the archive + IPA

Takes ~90s. Run it in the background so the session isn't blocked:

```bash
flutter build ipa --release --export-method app-store
```

Both artifacts come out of this one command:
- Archive → `build/ios/archive/Runner.xcarchive`
- IPA → `build/ios/ipa/acertos_mobile.ipa`

### 5. Verify

Confirm the artifacts exist and the signing/version actually landed — don't trust exit code 0 alone:

```bash
ls -lh build/ios/ipa/*.ipa
/usr/libexec/PlistBuddy -c 'Print :ApplicationProperties' build/ios/archive/Runner.xcarchive/Info.plist
```

Check that `CFBundleVersion` matches the number you just committed and `SigningIdentity` is the Apple Distribution cert above. If either is wrong, report it rather than proceeding.

### 6. Open Transporter and reveal the IPA

Hand off for upload. Transporter uploads independently of Xcode, so it's safe to use while the user has another project open in Xcode.

```bash
open -a Transporter
open -R "$(pwd)/build/ios/ipa/acertos_mobile.ipa"
```

That launches Transporter (or brings it to the front if already running) and opens a Finder window with the IPA selected, ready to drag across.

If Transporter isn't installed (`ls -d /Applications/Transporter.app`), say so and fall back to the altool command in step 7.

### 7. Report and stop

Give the user the archive path, IPA path, size, and the version/build number, and tell them to drag the revealed IPA into Transporter and hit **Deliver**. Then **stop** — do not upload, and do not run altool on their behalf.

Alternative upload path, for reference only:

```bash
xcrun altool --upload-app --type ios -f build/ios/ipa/acertos_mobile.ipa --apiKey KEY --apiIssuer ISSUER
```

## Expected warnings — not failures

`flutter build ipa` prints these every run. Report them once, don't try to fix them mid-build:

- **Default `com.example` bundle identifier** — builds and uploads fine; permanent after first App Store submission.
- **Default app icon** and **default launch image** — fine for TestFlight, but App Store *review will reject* the app until real assets replace them.

## Troubleshooting

- **`cannot pull with rebase: You have unstaged changes`** — this repo has `pull.rebase` set. Unrelated to building; if a pull is needed and it's a fast-forward, use `git merge --ff-only origin/main`.
- **Signing failures** — check the cert is still valid: `security find-identity -v -p codesigning`. Several older certs in this keychain show `CSSMERR_TP_CERT_REVOKED`; the live distribution cert is `085B07648B9E894F7B7E67F048A3C16487572BB8`.
- **Profile problems** — confirm it's still on disk: `ls ~/Library/Developer/Xcode/UserData/Provisioning\ Profiles/78e0691a-02d7-482e-a25d-1376e58fd6bd.mobileprovision`
