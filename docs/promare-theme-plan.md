# Promare Theme Plan

## Goal

Add a new `Promare`-inspired visual theme to the 2048 project while keeping
gameplay and effect trigger logic unchanged.

This rollout is intentionally **not** building a generic reusable theme system.
Instead, it adds two explicit theme variants:

- `classic`
- `promare`

The user can switch between them from the main UI.

## Constraints

- Business logic stays unchanged.
- Theme assets and theme code should live in a dedicated directory tree and
  should not be mixed into gameplay logic more than necessary.
- We do not need cross-project theme reuse or a generic theme plugin.
- Existing VFX behavior remains functionally the same. Only visual styling,
  palette, and presentation should change with the selected theme.

## Promare-Inspired Style Targets

This theme should capture the overall visual language, not copy copyrighted
film art or character assets.

### Visual language

- Dark navy or near-black background base.
- High-energy accent colors:
  - cyan / electric blue
  - magenta / hot pink
  - orange / yellow flame tones
- High-contrast shapes instead of soft pastel blocks.
- Harder outlines, sharper contrast, brighter highlights.
- More poster-like energy and less "cozy board game" warmth.

### Tile treatment

- Empty tiles: dark, low-contrast sockets.
- Low-value tiles: cool neon base colors.
- High-value tiles: hotter gradients and more aggressive borders.
- `128+` should start glowing more visibly.
- `512+` should feel hotter and more unstable.
- `1024+` and above should read as intense, high-energy tiles.

### UI treatment

- Header, score cards, board frame, controls, and status line all receive a
  distinct Promare palette.
- Typography should feel more forceful than the classic theme.
- Button styling should shift away from the current rounded pastel card look.

### VFX treatment

- Existing effect timing and trigger rules stay as-is.
- Colors should shift to the Promare palette.
- Screen flashes, fracture colors, milestone banners, combo labels, and 4096
  scene cue visuals should all align with the active theme.

## Implementation Strategy

## Directory layout

Add dedicated theme directories under `assets/themes/`:

- `assets/themes/classic/`
- `assets/themes/promare/`

Each theme directory contains its own resource file(s). We explicitly avoid a
shared abstract theme framework beyond the minimum needed to load/apply a theme.

## Runtime structure

Use a minimal runtime selector in `game_2048.gd`:

- export or preload two explicit theme resources
- track the active theme id
- expose a small theme picker in the main UI
- reapply theme visuals when the selection changes

This is not intended to become a generic theme marketplace or inheritance
system. It only supports the concrete built-in themes we ship.

## Theme data scope

Each theme resource should provide values for:

- background color
- flash overlay base color
- title / subtitle / help / status colors
- score / best card colors
- board frame colors
- button colors
- tile background colors
- tile text colors
- tile border colors
- tile radius / border widths / glow tuning
- VFX accent palette
- 4096 scene cue colors

## Code touch points

### Main UI

`scripts/game_2048.gd`

- remove hardcoded UI palette values from `_apply_theme()`
- remove hardcoded tile palette values from `_refresh_ui()`
- add theme picker UI hookup
- save and restore selected theme if desired

### Board rendering

`scripts/board_view.gd`

- no gameplay changes expected
- only panel/label styling remains driven by the active theme

### Runtime VFX palette

`scripts/vfx_controller.gd`

- keep current effect logic and thresholds
- route palette-dependent colors through the active theme
- update ghost tiles, heat sweeps, screen blast colors, combo labels, banners,
  and impact flash colors

### 4096 scene cue

`scripts/effects/effect_scene_player.gd`
`scenes/effects/merge_4096_effect.tscn`

- keep AnimationPlayer-driven orchestration
- allow runtime recoloring from the active theme

## UI switching approach

Add a `ThemePicker` control to the main scene near the existing controls.

Expected UX:

- `Classic`
- `Promare`

When the user switches:

- apply theme immediately
- refresh board visuals immediately
- keep current game state intact
- do not restart the board

## Rollout phases

1. Add docs and establish dedicated theme directories.
2. Add the theme picker to the main UI.
3. Add two theme resource files: `classic` and `promare`.
4. Move current classic palette into the `classic` theme resource.
5. Implement Promare palette and UI styling.
6. Wire VFX palette colors to the selected theme.
7. Recolor the 4096 scene cue from theme data.
8. Validate with headless check and desktop runtime inspection.

## Out of scope

- No gameplay changes.
- No audio redesign in this rollout.
- No generalized theme authoring framework.
- No editor plugin for theme authoring.
- No Android-specific theme tuning in this pass.
