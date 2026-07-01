# Godot 2048

A Godot 4.7 implementation of the 2048 puzzle game with:

- Desktop controls via arrow keys and `W/A/S/D`
- Mobile controls via swipe gestures
- Score and best-score persistence
- Export presets for macOS desktop and Android APK

## Project layout

- `project.godot`: Godot project config
- `scenes/main.tscn`: main playable scene
- `scripts/game_2048.gd`: 2048 game logic, input handling, UI updates
- `export_presets.cfg`: export presets for macOS and Android

## Run locally

```bash
'/Applications/Godot.app/Contents/MacOS/Godot' --path /Users/bytedance/code/godot-2048
```

Run the VFX lab as a separate desktop tool window:

```bash
/Users/bytedance/code/godot-2048/run_vfx_lab.sh
```

This launches `res://scenes/vfx_lab.tscn` directly with a desktop-friendly
window size instead of the main game's portrait-oriented default project
resolution.

Headless validation:

```bash
'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path /Users/bytedance/code/godot-2048 --quit
```

## Export macOS desktop

The project includes a `macOS` export preset targeting:

- output: `build/2048.app`
- bundle id: `com.bytedance.godot2048`

CLI export:

```bash
'/Applications/Godot.app/Contents/MacOS/Godot' \
  --headless \
  --path /Users/bytedance/code/godot-2048 \
  --export-release macOS /Users/bytedance/code/godot-2048/build/2048.app
```

Required local prerequisite:

- Godot 4.7 export templates installed under `~/Library/Application Support/Godot/export_templates/4.7.stable/`

## Export Android app

The project includes an `Android` export preset targeting:

- output: `build/2048.apk`
- package id: `com.bytedance.godot2048`

CLI export:

```bash
'/Applications/Godot.app/Contents/MacOS/Godot' \
  --headless \
  --path /Users/bytedance/code/godot-2048 \
  --export-debug Android /Users/bytedance/code/godot-2048/build/2048.apk
```

Required local prerequisites:

- Godot 4.7 Android export templates installed under `~/Library/Application Support/Godot/export_templates/4.7.stable/`
- A valid Java SDK / JDK configured in Godot editor settings
- Android SDK configured in Godot editor settings
- Debug or release keystore configured in Godot editor settings

Current machine status checked during setup:

- Android SDK path is configured: `/Users/bytedance/Library/Android/sdk`
- A debug keystore exists: `~/.android/debug.keystore`
- A Java runtime was not yet available when export verification started
- Godot export templates were missing and had to be installed separately

## Gameplay

- Merge equal-valued tiles by moving in one direction.
- A `2` or `4` spawns after each valid move.
- Reaching `2048` shows a win message and the game can continue.
- When no legal moves remain, the game shows a game-over message.
