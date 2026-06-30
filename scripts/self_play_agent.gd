extends RefCounted
class_name SelfPlayAgent

const GRID_SIZE := 4
const CELL_COUNT := GRID_SIZE * GRID_SIZE
const PREFERRED_DIRECTIONS := [Vector2i.DOWN, Vector2i.RIGHT, Vector2i.LEFT]


func choose_best_direction(board_model, board: Array[int]) -> Vector2i:
	var best_direction := Vector2i.ZERO
	var best_score := -1e18

	for direction in PREFERRED_DIRECTIONS:
		var result = board_model.simulate_move(direction, board)
		if not result["moved"]:
			continue
		var candidate_board: Array[int] = result["board"]
		var candidate_score = _evaluate_board_state(candidate_board, board_model)
		if candidate_score > best_score:
			best_score = candidate_score
			best_direction = direction

	return best_direction


func _evaluate_board_state(candidate_board: Array[int], board_model) -> float:
	var empties := 0
	var monotonicity := 0.0
	var smoothness := 0.0
	var merge_potential := 0.0
	var bottom_row_bonus := 0.0
	var right_column_bonus := 0.0
	for index in CELL_COUNT:
		if candidate_board[index] == 0:
			empties += 1

	for row in GRID_SIZE:
		for column in GRID_SIZE - 1:
			var current := candidate_board[row * GRID_SIZE + column]
			var right := candidate_board[row * GRID_SIZE + column + 1]
			if current == right and current != 0:
				merge_potential += float(current) * 1.2
			smoothness -= absf(float(current - right))
			if row == GRID_SIZE - 1:
				bottom_row_bonus += float(current) * float(column + 1)

	for column in GRID_SIZE:
		for row in GRID_SIZE - 1:
			var current := candidate_board[row * GRID_SIZE + column]
			var down := candidate_board[(row + 1) * GRID_SIZE + column]
			if current == down and current != 0:
				merge_potential += float(current) * 1.2
			smoothness -= absf(float(current - down))
			if column == GRID_SIZE - 1:
				right_column_bonus += float(current) * float(row + 1)

	for row in GRID_SIZE:
		var row_values := _extract_row(candidate_board, row)
		for idx in row_values.size() - 1:
			if row_values[idx] >= row_values[idx + 1]:
				monotonicity += float(row_values[idx])

	for column in GRID_SIZE:
		var column_values := _extract_column(candidate_board, column)
		for idx in column_values.size() - 1:
			if column_values[idx] >= column_values[idx + 1]:
				monotonicity += float(column_values[idx])

	var corner_bonus := 0.0
	var max_value = board_model.max_value(candidate_board)
	if candidate_board[CELL_COUNT - 1] == max_value:
		corner_bonus = float(max_value) * 8.0

	return (
		float(empties) * 220.0
		+ corner_bonus
		+ bottom_row_bonus * 0.32
		+ right_column_bonus * 0.26
		+ monotonicity * 0.12
		+ merge_potential * 0.4
		+ smoothness * 0.02
		+ float(max_value) * 0.75
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
