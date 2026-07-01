extends SceneTree

const BOARD_MODEL_SCRIPT := preload("res://scripts/board_model.gd")
const SELF_PLAY_AGENT_SCRIPT := preload("res://scripts/self_play_agent.gd")
const TARGET_TILE := 2048


func _init() -> void:
	var runs := 30
	var base_seed: int = 1337
	var user_args := OS.get_cmdline_user_args()
	if user_args.size() >= 1:
		runs = max(1, int(user_args[0]))
	if user_args.size() >= 2:
		base_seed = int(user_args[1])

	var reached_2048 := 0
	var total_score := 0
	var best_score := -1
	var best_max_tile := 0
	var max_tile_histogram := {}
	var sample_failures: Array[Dictionary] = []

	for run_index in runs:
		var result := _play_one_game(base_seed + run_index)
		var max_tile := int(result["max_tile"])
		var score := int(result["score"])
		total_score += score
		best_score = max(best_score, score)
		best_max_tile = max(best_max_tile, max_tile)
		max_tile_histogram[max_tile] = int(max_tile_histogram.get(max_tile, 0)) + 1
		if max_tile >= TARGET_TILE:
			reached_2048 += 1
		elif sample_failures.size() < 5:
			sample_failures.append(result)

	print("runs=%d reached_2048=%d rate=%.3f avg_score=%.1f best_score=%d best_max_tile=%d" % [
		runs,
		reached_2048,
		float(reached_2048) / float(runs),
		float(total_score) / float(runs),
		best_score,
		best_max_tile
	])

	var sorted_tiles := max_tile_histogram.keys()
	sorted_tiles.sort()
	for tile in sorted_tiles:
		print("max_tile=%d count=%d" % [int(tile), int(max_tile_histogram[tile])])

	for failure in sample_failures:
		print("failure seed=%d score=%d max_tile=%d board=%s" % [
			int(failure["seed"]),
			int(failure["score"]),
			int(failure["max_tile"]),
			str(failure["board"])
		])

	quit()


func _play_one_game(seed: int) -> Dictionary:
	var board_model = BOARD_MODEL_SCRIPT.new()
	var agent = SELF_PLAY_AGENT_SCRIPT.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed

	var setup = board_model.new_game(rng)
	var board: Array[int] = setup["board"]
	var score := 0
	var turns := 0

	while not board_model.is_game_over(board) and turns < 20000:
		var direction := agent.choose_best_direction(board_model, board)
		if direction == Vector2i.ZERO:
			break
		board_model.set_board(board)
		var move_result = board_model.apply_move(direction)
		if not move_result["moved"]:
			break
		score += int(move_result["score_gain"])
		board_model.spawn_random_tile(rng)
		board = board_model.get_board()
		turns += 1

	return {
		"seed": seed,
		"score": score,
		"turns": turns,
		"max_tile": board_model.max_value(board),
		"board": board
	}
