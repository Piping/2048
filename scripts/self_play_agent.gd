extends RefCounted
class_name SelfPlayAgent

const GRID_SIZE := 4
const CELL_COUNT := GRID_SIZE * GRID_SIZE
const MOVE_ORDER := [Vector2i.DOWN, Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP]
const POSITION_WEIGHTS := [
	0.08, 0.14, 0.26, 0.48,
	0.14, 0.22, 0.38, 0.72,
	0.24, 0.40, 0.68, 1.20,
	0.46, 0.82, 1.40, 2.30
]
const SNAKE_ORDERS := [
	[15, 14, 13, 12, 8, 9, 10, 11, 7, 6, 5, 4, 0, 1, 2, 3],
	[15, 11, 7, 3, 2, 6, 10, 14, 13, 9, 5, 1, 0, 4, 8, 12]
]


func choose_best_direction(board_model, board: Array[int]) -> Vector2i:
	var best_direction := Vector2i.ZERO
	var best_score := -1e18

	for direction in MOVE_ORDER:
		var result = board_model.simulate_move(direction, board)
		if not result["moved"]:
			continue
		var candidate_board: Array[int] = result["board"]
		var candidate_score := _score_move(board_model, candidate_board, result)
		if candidate_score > best_score:
			best_score = candidate_score
			best_direction = direction

	return best_direction


func _score_move(board_model, candidate_board: Array[int], move_result: Dictionary) -> float:
	var immediate_score := float(int(move_result.get("score_gain", 0))) * 0.16
	var immediate_max_tile := float(int(move_result.get("max_tile", 0))) * 0.03
	var follow_up_bonus := _best_follow_up_score(board_model, candidate_board) * 0.14
	return (
		_evaluate_board_state(candidate_board, board_model)
		+ immediate_score
		+ immediate_max_tile
		+ follow_up_bonus
	)


func _best_follow_up_score(board_model, board: Array[int]) -> float:
	var best_score := -1e18
	for direction in MOVE_ORDER:
		var result = board_model.simulate_move(direction, board)
		if not result["moved"]:
			continue
		var score: float = _evaluate_board_state(result["board"], board_model)
		score += float(int(result.get("score_gain", 0))) * 0.08
		if score > best_score:
			best_score = score
	return 0.0 if best_score <= -1e17 else best_score

func _evaluate_board_state(candidate_board: Array[int], board_model) -> float:
	var empties := 0
	var smoothness_penalty := 0.0
	var merge_potential := 0.0
	var mobility := 0
	var position_score := 0.0

	for index in CELL_COUNT:
		var value := candidate_board[index]
		if value == 0:
			empties += 1
			continue
		position_score += float(value) * POSITION_WEIGHTS[index]

	for direction in MOVE_ORDER:
		var move_result = board_model.simulate_move(direction, candidate_board)
		if move_result["moved"]:
			mobility += 1

	for row in GRID_SIZE:
		var row_values := _extract_row(candidate_board, row)
		for idx in row_values.size() - 1:
			if row_values[idx] != 0 and row_values[idx] == row_values[idx + 1]:
				merge_potential += _tile_log(row_values[idx]) + 1.0

	for column in GRID_SIZE:
		var column_values := _extract_column(candidate_board, column)
		for idx in column_values.size() - 1:
			if column_values[idx] != 0 and column_values[idx] == column_values[idx + 1]:
				merge_potential += _tile_log(column_values[idx]) + 1.0

	for row in GRID_SIZE:
		for column in GRID_SIZE:
			var index := row * GRID_SIZE + column
			var value := candidate_board[index]
			if value == 0:
				continue
			var current_log := _tile_log(value)
			if column + 1 < GRID_SIZE and candidate_board[index + 1] != 0:
				smoothness_penalty += absf(current_log - _tile_log(candidate_board[index + 1]))
			if row + 1 < GRID_SIZE and candidate_board[index + GRID_SIZE] != 0:
				smoothness_penalty += absf(current_log - _tile_log(candidate_board[index + GRID_SIZE]))

	var corner_bonus := 0.0
	var max_value = board_model.max_value(candidate_board)
	if candidate_board[CELL_COUNT - 1] == max_value:
		corner_bonus = float(max_value) * 9.0
	else:
		corner_bonus = -float(max_value) * 6.0

	var max_log := _tile_log(max_value)
	var empty_score := float(empties * empties) * 720.0
	var snake_shape := _best_snake_shape(candidate_board)
	var snake_score := float(snake_shape["score"])
	var snake_penalty := float(snake_shape["penalty"])
	var anchor_neighbor_bonus := _anchor_neighbor_bonus(candidate_board)
	var spawn_risk_penalty := _spawn_risk_penalty(candidate_board)

	return (
		empty_score
		+ snake_score * 420.0
		+ corner_bonus
		+ anchor_neighbor_bonus * 320.0
		+ position_score * 1.8
		+ merge_potential * 150.0
		+ float(mobility) * 180.0
		+ max_log * 240.0
		- snake_penalty * 260.0
		- smoothness_penalty * 28.0
		- spawn_risk_penalty * 180.0
	)


func _extract_row(source_board: Array[int], row: int) -> Array[int]:
	var line: Array[int] = []
	for column in GRID_SIZE:
		line.append(source_board[row * GRID_SIZE + column])
	return line


func _extract_column(source_board: Array[int], column: int) -> Array[int]:
	var line: Array[int] = []
	for row in GRID_SIZE:
		line.append(source_board[row * GRID_SIZE + column])
	return line


func _empty_indices(board: Array[int]) -> Array[int]:
	var empties: Array[int] = []
	for index in CELL_COUNT:
		if board[index] == 0:
			empties.append(index)
	return empties


func _spawn_neighbor_pressure(board: Array[int], index: int) -> float:
	var row := index / GRID_SIZE
	var column := index % GRID_SIZE
	var pressure: float = 0.0
	var neighbors := [
		Vector2i(column - 1, row),
		Vector2i(column + 1, row),
		Vector2i(column, row - 1),
		Vector2i(column, row + 1)
	]
	for point in neighbors:
		if point.x < 0 or point.x >= GRID_SIZE or point.y < 0 or point.y >= GRID_SIZE:
			continue
		pressure += _tile_log(board[point.y * GRID_SIZE + point.x]) * 0.35
	return pressure


func _spawn_risk_penalty(board: Array[int]) -> float:
	var empties := _empty_indices(board)
	if empties.is_empty():
		return 8.0

	var highest: float = 0.0
	var second: float = 0.0
	for i in empties.size():
		var index: int = int(empties[i])
		var risk: float = float(POSITION_WEIGHTS[index]) + _spawn_neighbor_pressure(board, index)
		if risk > highest:
			second = highest
			highest = risk
		elif risk > second:
			second = risk
	return highest + second * 0.45


func _best_snake_shape(board: Array[int]) -> Dictionary:
	var best_score := -1e18
	var best_penalty := 1e18
	for order in SNAKE_ORDERS:
		var score := 0.0
		var penalty := 0.0
		var weight := 1.0
		for index in order:
			score += _tile_log(board[index]) * weight
			weight *= 0.5
		for idx in order.size() - 1:
			var current := _tile_log(board[order[idx]])
			var next := _tile_log(board[order[idx + 1]])
			if next > current:
				penalty += (next - current) * (2.0 + float(idx) * 0.1)
		var shape_value := score - penalty * 1.5
		if shape_value > best_score:
			best_score = shape_value
			best_penalty = penalty
	return {
		"score": best_score,
		"penalty": best_penalty
	}


func _anchor_neighbor_bonus(board: Array[int]) -> float:
	var anchor := board[CELL_COUNT - 1]
	if anchor == 0:
		return 0.0
	var anchor_log := _tile_log(anchor)
	var left := _tile_log(board[CELL_COUNT - 2])
	var up := _tile_log(board[CELL_COUNT - GRID_SIZE - 1])
	var bonus := 0.0
	if left <= anchor_log and left > 0.0:
		bonus += left
	else:
		bonus -= absf(anchor_log - left) * 0.8
	if up <= anchor_log and up > 0.0:
		bonus += up
	else:
		bonus -= absf(anchor_log - up) * 0.8
	return bonus


func _tile_log(value: int) -> float:
	if value <= 0:
		return 0.0
	return log(float(value)) / log(2.0)
