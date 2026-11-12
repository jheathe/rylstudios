# Sonic Swipe, Phase 0: USB playback milestone

Case study 001. Scope is Phase 0 only, as defined in `sonic_swipe_claude_code_brief.json`.

**Goal:** prove an iPhone app can pick a folder on a USB drive through the Files UI, list the tracks, and play one, without ever changing the drive.

Not in this milestone: preview mode, swipe cards, classification, persistence, A/B modes, Rekordbox or Lexicon work, any write to a USB, any cloud service.

## Status in plain words

| Item | Status |
| --- | --- |
| Code written for every Phase 0 deliverable | Done |
| Compiled in Xcode | **NOT done.** The sandbox that wrote this has no Mac, Xcode or Swift toolchain. Expect a first build to possibly need small fixes. |
| Unit tests run | **NOT run.** They exist but have not been executed. |
| Run on a real iPhone with a real USB | **NOT done.** Only you can do this. |

The one thing that was verified: the WAV header layout used by the mock tone generator, checked by mirroring the byte layout in Python and reading it back with Python's `wave` module. That checks my reasoning about the format, not the Swift code itself.

## What is in the folder

```
SonicSwipe/
  project.yml                      Project recipe for XcodeGen
  SonicSwipe/                      The iPhone app
    SonicSwipeApp.swift
    Services/LibraryModel.swift    Folder access, scanning, mock folder
    Services/PlayerController.swift  AVFoundation player and failure reporting
    Views/                         Folder picker screen, track list, player bar
  Packages/SonicSwipeCore/         Logic with no iPhone dependency, plus tests
    TrackScanner, TrackFile, PlaybackTime, MockLibrary
```

Why two parts: the logic that does not need an iPhone lives in a small package so `swift test` can check it on your Mac in seconds.

## Prerequisites (check what you have, do not assume)

1. A Mac with Xcode installed. Run `xcodebuild -version` in Terminal to see your version. The app is set to a minimum of iOS 16.0 in `project.yml`. If your iPhone runs an older iOS, change `deploymentTarget` there.
2. An Apple ID signed in to Xcode. A free Apple ID can install on your own iPhone. Free provisioning has limits (apps expire after a short period and need reinstalling). See Apple's docs on running apps on a device.
3. XcodeGen, which turns `project.yml` into an Xcode project. Install with Homebrew: `brew install xcodegen`.
4. Your iPhone, a cable to the Mac, and your USB drive with a USB adapter that works with your iPhone.

## Build and run, step by step

1. Open Terminal and go to this folder: `cd path/to/rylstudios/SonicSwipe`
2. Run the logic tests first: `swift test --package-path Packages/SonicSwipeCore`. Report any failure to me with the full output.
3. Generate the project: `xcodegen generate`. This creates `SonicSwipe.xcodeproj`.
4. Open it: `open SonicSwipe.xcodeproj`
5. In Xcode, click the **SonicSwipe** project in the left list, choose the **SonicSwipe** target, open the **Signing & Capabilities** tab, and pick your Team. If Xcode says the bundle identifier is taken, change `com.rylstudios.SonicSwipe` to something unique to you.
6. Plug your iPhone into the Mac. Unlock it. Tap Trust if asked.
7. At the top of Xcode, choose your iPhone as the run destination, then press Run.
8. First install on a device may need Developer Mode on the iPhone (Settings, Privacy & Security, Developer Mode) and trusting your developer profile (Settings, General, VPN & Device Management). These menu names are from my memory of iOS. If yours differ, search Settings for "Developer Mode" and tell me what you see.

**If XcodeGen gives you trouble:** in Xcode choose File, New, Project, iOS, App, SwiftUI. Delete the template Swift files. Drag the `SonicSwipe/SonicSwipe` folder into the project. Then File, Add Package Dependencies, Add Local, and pick `Packages/SonicSwipeCore`.

## Test without a USB first (mock data)

In the app, tap **Try Mock Tones (no USB)**. It writes four small files into the app's temporary folder. Everything is labeled MOCK in the list.

Expected result:
- 4 tracks listed: three tones (including one in a subfolder) and `MOCK Broken File.mp3`
- Footer says 1 other file was ignored (a text note)
- Tapping a tone plays it and shows Plays
- Tapping the broken mp3 shows Could not play with a plain message, and the app stays open

This proves the scan, playback and error paths. It does not prove USB access.

## Phase 0 device checklist (mark each when done)

Use a disposable USB, not your performance drive.

- [ ] App installs on the physical iPhone from Xcode
- [ ] Plug in the USB. Open the Files app and confirm the drive appears under Locations. If it does not, the problem is the drive, adapter, power or format, not this app
- [ ] In Sonic Swipe, choose **Choose Folder in Files**, then pick the drive folder with music
- [ ] Tracks are listed with the right names
- [ ] One MP3 plays
- [ ] One WAV plays (if you have one)
- [ ] Try one each of m4a, aiff and flac if you have them. Note which show Could not play
- [ ] Unplug the drive during playback. The app must not crash. Expect a plain message within a few seconds
- [ ] Plug it back in, use Rescan Folder, play again
- [ ] Look at the drive on your Mac afterward. Nothing should have been added, changed or removed

When you finish, write down for me: iPhone model, iOS version, adapter, drive file system (exFAT, FAT32, other), and which formats played. These answer the open questions in the brief.

## Decisions I made, and why

- **Swift 5 language mode, iOS 16 minimum, no new concurrency features.** Fewer things to break on a first build I could not compile. Easy to raise later.
- **Folder access:** SwiftUI `fileImporter` limited to folders. Security scoped access stays open while the folder is in use, because playback reads files later. Reads go through `NSFileCoordinator` with read only options.
- **Hidden files skipped.** This avoids `._track.mp3` stub files that Macs leave on USB drives.
- **Symbolic links are skipped, depth is capped at 16.** Prevents loops.
- **Track list shows what actually happened** (Plays or Could not play) instead of guessing codec support from file extensions. Extensions probed: mp3, m4a, wav, aiff, aif, flac. The brief warns not to assume these all play.
- **Titles come from file names for now.** Reading embedded title and artist metadata from every file on a USB would slow the scan. That is later work.
- **Track id is the relative path.** Good enough for Phase 0. A stable id that survives unplug and replug is Phase 2 work.
- **No persistence, no background audio, no analytics, no network.**

## Known gaps to watch for

1. Playback stops when the app goes to the background. Background audio was not requested for Phase 0.
2. The unplug check is a best guess: if playback waits for 3 seconds and the file is not reachable, it reports a disconnected drive. Real hardware may behave differently. This needs your device test.
3. Large folders are scanned in one pass with no progress count.

## Next smallest step (Phase 1, after this checklist passes)

Add the 32 beat preview and automatic advance: a `PreviewPlan` function in the core package (beats, BPM to seconds, with the seconds fallback clearly labeled), unit tested at 128 BPM equals 15 seconds, then wire it into the player. I will not start this until you report the Phase 0 results.
