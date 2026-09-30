# TimeTracker

A minimal macOS menu-bar timer.

Click the **clock** in the menu bar — a Liquid Glass panel opens. Start, stop, reset. No Dock icon — just the menu bar. Runs in the background while you work.

## Requirements

- macOS 26+
- Xcode 26+ / Swift 6.2+ (`xcode-select --install`)

## Run

```bash
swift run
```

Build only:

```bash
swift build
open .build/debug/Timetracker
```

Release build:

```bash
swift build -c release
open .build/release/Timetracker
```

## Use

1. Click the clock icon in the menu bar
2. Press **Start** to begin tracking
3. Press **Stop** to pause (time is kept), **Reset** to clear

The menu bar icon pulses while the timer is running.

## Stack

Native Swift + SwiftUI (`MenuBarExtra`). Liquid Glass (`glassEffect`, `.glass` / `.glassProminent`). No Electron, no dependencies.

## License

MIT
