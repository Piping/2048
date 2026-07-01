# AGENTS

## Export Rules

- Do not apply `DisplayServer.get_display_safe_area()` margins on desktop builds. In this project, the main UI lives under `SafeArea`, and desktop safe-area values can push the entire gameplay UI outside the window while root-level overlays still remain visible.
- Treat `macos`, `windows`, `linuxbsd`, and `web` as desktop-style targets for the safe-area guard unless there is concrete evidence that a platform-specific notch workflow is needed.

## VFX Asset Rules

- For gameplay/runtime VFX, do not load raw PNG files through `ProjectSettings.globalize_path()`, `Image.load()`, or host filesystem paths when the asset is under `res://`. Exported apps package these assets into the `pck`, and raw file access becomes unreliable or fails outright.
- Prefer export-safe Godot resource loading for packaged art assets: `load("res://...") as Texture2D`, then derive `Image` data from `Texture2D.get_image()` only when frame slicing is required.
- If a VFX loader needs directory enumeration, `DirAccess.get_files_at("res://...")` is acceptable only when the per-file payload is still loaded through Godot resources rather than host-path PNG reads.

## Verification Rules

- After changing export-related UI logic or VFX resource loading, verify three things:
  1. `Godot --headless --path ... --quit` still passes.
  2. Re-export the desktop app.
  3. Run the exported app and inspect both the visible window and the latest Godot log under `~/Library/Application Support/Godot/app_userdata/2048/logs/`.

## Debug Workflow Rules

- Keep the in-game VFX debug panel behavior aligned with real gameplay triggers. If a merge tier is excluded from screen-level feedback in gameplay, the debug preset for that tier must use the same rule.
