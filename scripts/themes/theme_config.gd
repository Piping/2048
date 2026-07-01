extends Resource
class_name ThemeConfig

@export var theme_id := "classic"
@export var display_name := "Classic"

@export var background_color := Color("f6f2e6")
@export var flash_overlay_color := Color(1.0, 0.6, 0.15, 1.0)

@export var title_color := Color("776e65")
@export var subtitle_color := Color("776e65")
@export var help_color := Color("776e65")
@export var status_color := Color("776e65")

@export var score_card_color := Color("bbada0")
@export var score_label_color := Color("eee4da")
@export var score_value_color := Color.WHITE

@export var board_frame_color := Color("bbada0")
@export var board_padding_color := Color("cdc1b4")

@export var button_color := Color("8f7a66")
@export var button_text_color := Color("f9f6f2")

@export var tile_colors: Dictionary = {}
@export var tile_text_colors: Dictionary = {}

@export var tile_corner_radius := 18
@export var tile_border_color_128 := Color(1.0, 0.96, 0.72, 0.72)
@export var tile_border_color_256 := Color(1.0, 0.90, 0.48, 0.90)
@export var tile_border_color_fire := Color(1.0, 0.84, 0.25, 0.98)

@export var combo_label_color := Color(1.0, 0.92, 0.60, 1.0)
@export var milestone_badge_color := Color(1.0, 0.55, 0.10, 1.0)
@export var celebration_banner_color := Color(1.0, 0.84, 0.18, 1.0)

@export var screen_core_low := Color(1.0, 0.95, 0.65, 1.0)
@export var screen_core_high := Color(1.0, 0.82, 0.28, 1.0)
@export var screen_outer_low := Color(1.0, 0.62, 0.14, 1.0)
@export var screen_outer_high := Color(1.0, 0.28, 0.05, 1.0)
@export var fracture_tint_low := Color(1.0, 0.82, 0.36, 1.0)
@export var fracture_tint_high := Color(1.0, 0.46, 0.12, 1.0)
@export var impact_flash_low := Color(1.0, 0.98, 0.94, 1.0)
@export var impact_flash_high := Color(1.0, 0.82, 0.54, 1.0)

@export var scene_4096_flash := Color(1.0, 0.95, 0.66, 1.0)
@export var scene_4096_ring := Color(1.0, 0.72, 0.18, 1.0)
@export var scene_4096_label := Color(1.0, 0.94, 0.74, 1.0)
