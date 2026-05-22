# Screenshots for the README

Drop the following PNG files into this folder — the main `README.md` already references them:

| File | What to capture | Suggested size |
|---|---|---|
| `hero.png` | Hero banner — main window with a macro playing (status “Playing 3/10”), nice macOS background visible behind | 1440×900 (Retina) |
| `main-window.png` | The whole app window in idle state with one saved macro selected | 1040×960 |
| `playback-controls.png` | Crop of the Speed / Repeats / Interval section | 1040×260 |
| `macro-list.png` | The Saved macros list with 3–5 entries | 1040×400 |
| `permissions.png` | The PermissionsView shown before Accessibility is granted | 1040×600 |

## How to capture clean macOS screenshots

```bash
# Window-only screenshot with shadow → goes to ~/Desktop
# Press ⇧⌘4 then SPACE then click the Clicker window.

# Or scripted (no shadow, transparent background):
screencapture -o -w ~/Desktop/main-window.png
```

After capturing, move the files here:

```bash
mv ~/Desktop/main-window.png   docs/screenshots/main-window.png
mv ~/Desktop/playback-controls.png docs/screenshots/playback-controls.png
# etc.
```

Optional polish:
- run them through `pngquant --quality=80-95` to shrink without quality loss
- compose the hero with a subtle gradient background in Figma / Keynote
