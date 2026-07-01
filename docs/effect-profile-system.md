# EffectProfile System

## Goal

This project now routes gameplay feedback through an event-driven, data-driven
effect layer so `VFX`, `Audio`, and higher-level presentation can be tuned in
one place instead of being hard-coded across gameplay scripts.

The immediate design target is merge readability and escalation:

- `128 -> 2048` must feel progressively stronger.
- `1024` must not read weaker than `512`.
- gameplay and VFX debug playback must use the same runtime path.

## Runtime Architecture

The current chain is:

1. `Game2048` emits semantic effect events.
2. `EffectDirector` resolves the best matching `EffectProfile`.
3. The profile expands into `EffectCue` entries.
4. Cue execution fans out into:
   - `VfxController`
   - `EffectAudioManager`

Current event names:

- `spawn`
- `merge_move`
- `screen_merge`
- `milestone`
- `celebration`

## Core Types

Scripts:

- `scripts/effects/effect_profile.gd`
- `scripts/effects/effect_profile_set.gd`
- `scripts/effects/effect_cue.gd`
- `scripts/effects/vfx_effect_cue.gd`
- `scripts/effects/audio_effect_cue.gd`
- `scripts/effects/effect_director.gd`
- `scripts/effects/effect_audio_manager.gd`

Resource entrypoint:

- `assets/effects/default_effect_profiles.tres`

### `EffectProfile`

Represents a tiered recipe for one gameplay event.

Key fields:

- `event_name`
- `min_tile_value`
- `max_tile_value`
- `priority`
- `intensity_rank`
- `cues`

Profiles are matched by event name plus tile-value range. If multiple profiles
match, higher `priority` wins.

### `VfxEffectCue`

Calls into `VfxController` using one of the supported actions:

- `spawn_pulse`
- `merge_feedback`
- `screen_merge_feedback`
- `milestone_feedback`
- `celebration`

Key tuning fields:

- `scale_boost`
- `intensity_boost`

### `AudioEffectCue`

Current audio is intentionally export-safe and asset-independent: it generates a
short procedural waveform at runtime so the full chain can be validated before
real SFX assets are added.

Key tuning fields:

- `waveform`
- `frequency`
- `frequency_end`
- `attack`
- `sustain`
- `release`
- `volume_db`
- `pitch_random_range`
- `delay`

This is a temporary bridge, not the long-term end state. The expected next step
is to add a stream-based cue type for authored `.wav` / `.ogg` assets and keep
the same director/profile flow.

## Editor Workflow

The system is designed to stay editable in the Godot editor.

Open `scenes/main.tscn`, then select `EffectDirector`.

The `profile_set` field points at:

- `res://assets/effects/default_effect_profiles.tres`

From there you can inspect and adjust each profile directly in the Inspector:

- choose which event it responds to
- adjust tier ranges
- tune `scale_boost`
- tune `intensity_boost`
- tune synthesized audio envelope and pitch

This gives a minimal editor-native workflow without requiring a custom editor
plugin.

The project now also includes a scene-based cue example for `4096` merges:

- `res://scenes/effects/merge_4096_effect.tscn`

That scene is driven by `AnimationPlayer`, instantiated by `SceneEffectCue`,
and attached by `EffectDirector` at runtime. Use it as the reference pattern
when a tier needs editor-authored timeline choreography instead of pure numeric
cue tuning.

## Current Mapping

The shipped default profile set currently contains:

- `spawn_basic`
- `merge_128`
- `merge_256`
- `merge_512`
- `merge_1024`
- `merge_2048_plus`
- `screen_merge_2048_plus`
- `milestone_2048_plus`
- `celebration_2048`

The strength ladder is explicit in the profile data:

- higher merge tiers increase both `scale_boost` and `intensity_boost`
- higher merge tiers also lower pitch and raise loudness so the impact reads
  heavier
- screen-level feedback remains gated at `2048+`

## Gameplay Integration

`scripts/game_2048.gd` no longer hard-codes the full VFX path directly.

It now builds an effect context and calls `EffectDirector` for:

- new tile spawn
- merge beat
- screen-level merge feedback
- milestone feedback
- celebration

The in-game debug presets also route through `EffectDirector.preview_profile()`
so debug playback stays aligned with real gameplay triggers.

## Current Limits

This rollout deliberately keeps the existing `VfxController` rendering code and
wraps it with profile-based orchestration. It does not yet provide:

- authored audio asset playback
- timeline scenes per cue
- explicit screen shake nodes
- packed-scene cue types
- custom inspector tools

Those can be added incrementally without changing the event/profile contract.

## Recommended Next Extensions

1. Add `AudioStreamEffectCue` for real imported SFX assets.
2. Expand `SceneEffectCue` usage beyond the current `4096` example so more
   complex tier effects can be authored as `.tscn` prefabs with
   `AnimationPlayer`.
3. Add `ScreenShakeCue` and a small shake node.
4. Move special-case `1024` and `2048+` composition deeper into profile-owned
   scenes once art direction stabilizes.
