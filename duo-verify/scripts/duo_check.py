#!/usr/bin/env python3
"""Check a RocketSim `elements` snapshot against iPhone Duo safe area and fold.

usage: duo_check.py <elements.json> --pose closed|book|open [--baseline parent.json] [--ignore LABEL ...]

Reads the JSON written by `rocketsim elements --udid <UDID>` (no --agent).
Safe-area insets come from the canvas size, using values measured on the
iPhone Duo simulator (Xcode 27.2 / iOS 27.2) with the HingeProbe app.

Exit code: 0 = no FAIL, 1 = at least one FAIL, 2 = cannot judge.
"""
import argparse, json, sys

# canvas (w, h) -> list of candidate insets (top, left, bottom, right)
INSETS = {
    (466, 678): [(0, 0, 34, 84)],                      # closed, portrait
    (678, 466): [(0, 0, 34, 84), (0, 84, 34, 0)],      # closed, landscapeLeft / landscapeRight
    (951, 669): [(0, 0, 34, 84)],                      # book/open, landscapeLeft and landscapeRight
    (669, 951): [(82, 0, 34, 0)],                      # book/open, portrait / upsideDown
}
INTERACTIVE = {"button", "checkBox", "radioButton", "slider", "textField", "secureTextField",
               "searchField", "switch", "link", "tab", "segmentedControl", "popUpButton", "menuButton",
               "incrementor", "comboBox", "textView"}
FOLD_HALF_WIDTH = 10  # pt either side of the fold line; simulator does not draw the fold


def rect(e):
    (x, y), (w, h) = e["frame"]
    return x, y, x + w, y + h


def overlap(a, b):
    return max(0, min(a[2], b[2]) - max(a[0], b[0])) * max(0, min(a[3], b[3]) - max(a[1], b[1]))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("snapshot")
    ap.add_argument("--pose", required=True, choices=["closed", "book", "open"])
    ap.add_argument("--ignore", action="append", default=[], help="label substring to skip")
    ap.add_argument("--baseline", help="elements.json of the screen underneath; its elements are skipped "
                    "(RocketSim also lists elements hidden behind full-screen covers and sheets)")
    a = ap.parse_args()

    d = json.load(open(a.snapshot))
    if not d.get("ok", True):
        print("CANNOT_JUDGE snapshot error:", d.get("error")); sys.exit(2)
    d = d.get("data", d)
    W, H = (round(v) for v in d["canvasSize"])
    cands = INSETS.get((W, H))
    if not cands:
        print(f"CANNOT_JUDGE unknown canvas {W}x{H}; measure insets with HingeProbe first"); sys.exit(2)
    canvas = (0, 0, W, H)
    ambiguous = len(cands) > 1
    # union of unsafe strips over all candidates (conservative when orientation is ambiguous)
    strips = []
    for t, l, b, r in cands:
        if t: strips.append(("top inset", (0, 0, W, t)))
        if l: strips.append(("left inset", (0, 0, l, H)))
        if b: strips.append(("bottom inset", (0, H - b, W, H)))
        if r: strips.append(("right inset", (W - r, 0, W, H)))
    fold = None
    outer = (W, H) in ((466, 678), (678, 466))
    if a.pose == "book" and outer:
        print("NOTE book pose but the outer display is lit (hinge hysteresis): fold check skipped")
    if a.pose == "book" and not outer:
        if W > H:
            fold = (W / 2 - FOLD_HALF_WIDTH, 0, W / 2 + FOLD_HALF_WIDTH, H)
        else:
            fold = (0, H / 2 - FOLD_HALF_WIDTH, W, H / 2 + FOLD_HALF_WIDTH)

    base = set()
    if a.baseline:
        bd = json.load(open(a.baseline)); bd = bd.get("data", bd)
        base = {e.get("stableKey") for e in bd["elements"] if e.get("stableKey")}
    fails, warns, checked, skipped = [], [], 0, 0
    for e in d["elements"]:
        if not e.get("frame"):
            continue
        label = e.get("label") or ""
        if any(s in label for s in a.ignore) or (e.get("stableKey") in base):
            skipped += 1
            continue
        r = rect(e)
        area = (r[2] - r[0]) * (r[3] - r[1])
        if area <= 0:
            continue
        on = overlap(r, canvas)
        if on == 0:
            continue  # fully off-screen (e.g. closed side menu)
        if area >= 0.7 * W * H:
            continue  # full-screen container or invisible full-screen control (e.g. AVRoutePickerView)
        role = e.get("role") or e.get("type") or ""
        inter = role in INTERACTIVE
        checked += 1
        name = f"#{e.get('id')} {role} '{label[:40]}' frame=({r[0]:.0f},{r[1]:.0f})-({r[2]:.0f},{r[3]:.0f})"
        bucket = fails if inter else warns
        if on < area - 0.5:
            bucket.append(f"{name}: partly off-screen")
        for sname, s in strips:
            ov = overlap(r, s)
            if ov > 0.5:
                bucket.append(f"{name}: {ov:.0f}pt² inside {sname}")
        if fold and inter and role != "slider" and overlap(r, fold) > 0.5:  # scroll indicators may cross
            fails.append(f"{name}: crosses the fold")

    print(f"canvas {W}x{H} pose={a.pose} insets={cands if ambiguous else cands[0]}"
          + (" (orientation ambiguous: checked both sides, confirm on screenshot)" if ambiguous else ""))
    print(f"checked {checked} on-screen elements, skipped {skipped} (baseline/ignore)")
    for f in fails: print("FAIL", f)
    for w in warns: print("WARN", w)
    if not fails and not warns: print("PASS")
    sys.exit(1 if fails else 0)


if __name__ == "__main__":
    main()
