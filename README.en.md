# duo-verify

[中文](README.md) | **English**

Let Claude Code check a screen on the **iPhone Duo simulator** for you.

Related: [SimPilot](https://github.com/peter6601/SimPilot), a tool that reads button positions, taps buttons and switches Duo poses. This skill uses it by default.

Slides: [Nine-cell inspection](https://ios-dev-skill-deck.vercel.app/duo/) (Traditional Chinese): what duo-verify runs, how it judges, and how to read the report.

## Why

- iPhone Duo is a foldable: it has an outer display, an inner display and a fold in the middle.
- One screen has to work in every pose and every orientation.
- A regular iPhone won't show Duo bugs: Duo's status bar is on the side, and there's a fold.
- Folding and checking each combination by hand is slow and easy to get wrong.
- This skill lets Claude run all of it and hand back a list of problems.

## What you get

Type `/duo-verify` after you finish a feature. Claude will:

- Switch Duo to closed, book (half folded) and open.
- Rotate book and open through 4 orientations each, plus 1 cell for closed: 9 cells in total.
- Read every button's position and check it against the status bar, the home indicator and the fold.
- Tap the buttons you named and confirm they respond.
- After each pose change, confirm the screen is still there and didn't jump back home.
- Look at the screenshots and compare them with your description.

Then you get a report:

- The first line is the verdict: no problems, N problems, or N cells that couldn't be judged.
- A 9-cell table: screen size, FAIL count and WARN count for each cell.
- Each problem: which button, where it is, and the matching screenshot.
- Screenshots and data are saved in `~/duo-verify-runs/`, never in your project.

The report only covers these 9 cells on the simulator. Real-device feel, performance and the physical fold can't be tested there.

## What you need

| Item | Needed? | What for |
|---|---|---|
| Mac + Xcode 27.1 or later | Required | Tested on Xcode 27.2 |
| iOS 27.1 or later simulator | Required | To create an iPhone Duo simulator |
| Claude Code | Required | The Mac app or the terminal CLI |
| Python 3 | Required | Runs the check script |
| [SimPilot](https://github.com/peter6601/SimPilot) | Recommended | Reads button positions and taps; the CLI also uses it to switch poses |
| [RocketSim](https://www.rocketsim.app/) | Alternative | Used when SimPilot isn't installed; the free plan has a daily limit |
| Device Hub + Accessibility permission | CLI only | Switches poses and rotates from the terminal |
| Test account | Required | Screenshots are sent to Claude |

- It still runs without SimPilot or RocketSim.
- In that case Claude judges from screenshots. It's less precise, and the report says so.

## Install

1. Install the skill:

   ```bash
   git clone https://github.com/peter6601/duo-verify-skill.git
   ln -s "$PWD/duo-verify-skill/duo-verify" ~/.claude/skills/duo-verify
   ```

2. Install SimPilot (recommended):

   ```bash
   brew install xcodegen
   git clone https://github.com/peter6601/SimPilot.git
   cd SimPilot
   scripts/make-app.sh
   build/simpilot runner build
   ln -s "$PWD/build/simpilot" /usr/local/bin/simpilot
   ```

- Install once, then use `/duo-verify` in any project.
- SimPilot must be on your PATH so the skill can find it.
- Keep SimPilot's cloned folder. See [SimPilot's README](https://github.com/peter6601/SimPilot/blob/main/README.en.md#install) for details.

## How to run

1. Boot an iPhone Duo simulator and sign in with a test account.
2. Open the app you want to test.
3. If you use the terminal CLI, open Device Hub and select this Duo.
4. In Claude Code, type `/duo-verify` and give three lines:

```text
/duo-verify
Screen: Home → Settings → Account
Expected: avatar and name at the top, a row of three buttons below, Sign Out at the bottom
Buttons: Edit (opens the edit page), Sign Out (shows a confirmation)
```

- **Screen**: how to get there from the home screen.
- **Expected**: one or two sentences, or a Figma link. Without it, only the rule checks run.
- **Buttons**: which buttons to tap, and what should happen.
- **Engine** (optional): `simpilot` or `rocketsim`. SimPilot is used first if you leave it out.

5. Wait for the report. Read the first line and the FAIL list. If there's a FAIL, fix it and run again.

## Reading the report

- **FAIL**: a button is under the status bar or home indicator, off screen, or across the fold. Fix it.
- **WARN**: text or an image touches an edge. Claude checks the screenshot to see if it's intentional.
- **Your call**: a button is in the status bar area but not covered by the clock or Wi-Fi icon.
- **Can't judge**: the pose didn't switch, or the screenshot is black. The report says why.

duo-verify only tests; it doesn't change code. When there's a FAIL and you have the plugin Xcode exports (`xcode@claude-plugins-official`), the report suggests handing the fix to its `app-resizability` skill. These problems usually come from `UIScreen.main`, `interfaceOrientation`, or assumptions about the safe area. Run duo-verify again after the fix.

## Mac app vs CLI

| | Mac app (Claude Code Desktop) | CLI (terminal) |
|---|---|---|
| Switch pose | Built in, any angle | Three fixed poses through Device Hub |
| Rotate | Built-in button | Device Hub's Rotate Right |
| See the screen | Live, next to the chat | Screenshot files |
| Open first | Desktop v4.29.0 or later | Device Hub, with this Duo selected |

- Both run the same `/duo-verify` and give the same results.
- To test a specific angle or watch as it runs, use the Mac app.
- To rerun the same set or work in the terminal, use the CLI.

## SimPilot vs RocketSim

- Both read button positions and tap buttons, with the same output format.
- On the same screen, all 9 cells found exactly the same problems.

| | SimPilot | RocketSim |
|---|---|---|
| Get it | [GitHub](https://github.com/peter6601/SimPilot), free and open source | [rocketsim.app](https://www.rocketsim.app/), paid, with a free plan |
| Usage limit | None | Daily limit on the free plan |
| Duplicate labels | Taps only the visible one | May tap the wrong one |
| After a tap | Reports which elements moved | Only reports whether the screen changed |
| Hinge angle | Not available; only the pose | Available |

- SimPilot holds an xcodebuild process while it runs.
- The skill stops it when it's done; it also stops after 3 idle minutes.

## Known limits

- Simulator only; no real devices.
- The fold position is estimated: 10 pt on each side of the screen's center line.
- The simulator doesn't rotate while closed, so the outer display in landscape can't be tested.
- The hinge has hysteresis: at the same angle, which display is lit depends on how you got there. Always judge by screen size.
- Rotation depends on Device Hub's window layout and may break with a new Xcode.
- Measured values are for Xcode 27.2 only. Measure again after upgrading (see below).

## Measured values (Xcode 27.2 / iOS 27.2)

| Screen | Size (pt) | Safe area (top / left / bottom / right) |
|---|---|---|
| Outer, portrait | 466×678 | 0 / 0 / 34 / 84 |
| Inner, landscape | 951×669 | 0 / 0 / 34 / 84 |
| Inner, portrait | 669×951 | 82 / 0 / 34 / 0 |

- No outer landscape: the simulator doesn't rotate while closed.
- After changing Xcode versions, measure again with the probe app and update the `INSETS` table in `duo_check.py`.

## Files

```
duo-verify/
├── SKILL.md                  the skill: steps, rules, report format
├── scripts/
│   ├── duo_check.py          checks button coordinates against measured safe areas and the fold
│   ├── duo_pose.sh           switches pose with RocketSim and confirms it
│   ├── duo_rotate.sh         clicks Rotate Right in Device Hub
│   ├── devicehub_pose.sh     switches pose with Device Hub when RocketSim isn't available
│   └── safe-xcodebuild.sh    refuses to run while another xcodebuild is running
└── probe/
    ├── main.swift            probe app: shows the safe area and pose on screen
    ├── Info.plist
    └── build.sh              builds and installs the probe app
```

The skill itself (SKILL.md) is written in Traditional Chinese. Claude follows it in any language.

## License

MIT. See [LICENSE](LICENSE).
