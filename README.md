# TimeTracker

A minimal macOS menu-bar timer that keeps a note with every session.

Click the **clock** in the menu bar — a Liquid Glass panel opens. Start, stop, write down what you did. No Dock icon — just the menu bar. Runs in the background while you work.

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

Tests:

```bash
swift test
```

## Use

1. Click the clock icon in the menu bar
2. Press **Start** to begin tracking
3. Press **Pause** to freeze the clock
4. From pause: **Resume** (green), **Save time** (blue) to log what you did, or the red trash to discard
5. After **Save time**, type a note and press **Save** (or Return)

A note is required when saving time. The menu bar icon pulses while running, shows
pause while paused, and a pencil while a note is pending.



## History

The calendar button in the panel opens the **History** window. It shows a month
calendar with a dot under every day that has entries, and a table of that day's
sessions with start, end, duration and note.

- Click a day to see its sessions and total
- Click a note to edit it, then press Return
- Select rows and press the trash button (or ⌫) to delete, with a confirmation

## Storage

Entries are stored as a JSON array in:

```text
~/Library/Application Support/TimeTracker/entries.json
```

Writes are atomic, so an interrupted save cannot truncate the file. If the file is
unreadable the app starts with an empty history instead of refusing to launch.

Set `TIMETRACKER_DATA_DIR` to store entries somewhere else — handy for testing:

```bash
TIMETRACKER_DATA_DIR=$(mktemp -d) swift run
```

## Structure

| Path                       | Contents                                                     |
| -------------------------- | ------------------------------------------------------------ |
| `Sources/TimetrackerCore/` | `WorkEntry`, `EntryStore`, `TimerSession` — no UI, fully tested |
| `Timetracker/`             | SwiftUI app: menu bar panel, history window                  |
| `Tests/TimetrackerCoreTests/` | Swift Testing suites for the timer state machine and storage |

`TimerSession` is a pure state machine (`idle → running ⇄ paused → logging → idle`)
wrapped by `TimerManager`, which owns the tick timer and publishes the clock.


## Stack

Native Swift + SwiftUI (`MenuBarExtra`, `Window`, `Table`). Liquid Glass
(`glassEffect`, `.glass` / `.glassProminent`). No Electron, no dependencies.

## License

MIT
