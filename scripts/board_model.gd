extends RefCounted
class_name BoardModel

const GRID_SIZE := 4
const CELL_COUNT := GRID_SIZE * GRID_SIZE

var board: Array[int] = []


func _init() -> void:
	board.resize(CELL_COUNT)
	board.fill(0)


func new_game(rng: RandomNumberGenerator) -> Dictionary:
	board.fill(0)
	var spawned: Array[int] = []
	spawned.append(spawn_random_tile(rng))
	spawned.append(spawn_random_tile(rng))
	return {
		"board": get_board(),
		"spawned_indices": spawned.filter(func(index: int) -> bool: return index >= 0)
	}


func get_board() -> Array[int]:
	return board.duplicate()


func set_board(values: Array[int]) -> void:
	board = values.duplicate()
	if board.size() < CELL_COUNT:
		board.resize(CELL_COUNT)
		for index in range(values.size(), CELL_COUNT):
			board[index] = 0


func apply_move(direction: Vector2i) -> Dictionary:
	var result = _move_board(direction, board)
	board = result["board"]
	return result


func simulate_move(direction: Vector2i, source_board: Array[int]) -> Dictionary:
	return _move_board(direction, source_board)


func spawn_random_tile(rng: RandomNumberGenerator) -> int:
	var empties: Array[int] = []
	for index in CELL_COUNT:
		if board[index] == 0:
			empties.append(index)
	if empties.is_empty():
		return -1

	var slot := empties[rng.randi_range(0, empties.size() - 1)]
	board[slot] = 4 if rng.randf() < 0.1 else 2
	return slot


func is_game_over(source_board: Array[int] = []) -> bool:
	var values = source_board if not source_board.is_empty() else board
	for index in CELL_COUNT:
		if values[index] == 0:
			return false

		for row in GRID_SIZE:
			for column in GRID_SIZE:
				var value = values[row * GRID_SIZE + column]
				if column + 1 < GRID_SIZE and value == values[row * GRID_SIZE + column + 1]:
					return false
				if row + 1 < GRID_SIZE and value == values[(row + 1) * GRID_SIZE + column]:
					return false
	return true


func max_value(source_board: Array[int] = []) -> int:
	var values = source_board if not source_board.is_empty() else board
	var best := 0
	for value in values:
		best = max(best, value)
	return best


func _move_board(direction: Vector2i, source_board: Array[int]) -> Dictionary:
	var board_copy: Array[int] = source_board.duplicate()
	var moved := false
	var score_gain := 0
	var max_tile := 0
	var merged_indices: Array[int] = []
	var animations: Array[Dictionary] = []

	match direction:
		Vector2i.LEFT:
			for row in GRID_SIZE:
				var line := _extract_row(board_copy, row)
				var merged = _compress_line(line, _row_indices(row))
				if merged["line"] != line:
					moved = true
					_apply_row(board_copy, row, merged["line"])
				score_gain += merged["score_gain"]
				max_tile = max(max_tile, merged["max_tile"])
				merged_indices.append_array(merged["merged_indices"])
				animations.append_array(merged["animations"])
		Vector2i.RIGHT:
			for row in GRID_SIZE:
				var original := _extract_row(board_copy, row)
				var line := original.duplicate()
				var index_map := _row_indices(row)
				line.reverse()
				index_map.reverse()
				var merged = _compress_line(line, index_map)
				var merged_line: Array[int] = merged["line"]
				merged_line.reverse()
				if merged_line != original:
					moved = true
					_apply_row(board_copy, row, merged_line)
				score_gain += merged["score_gain"]
				max_tile = max(max_tile, merged["max_tile"])
				merged_indices.append_array(merged["merged_indices"])
				animations.append_array(merged["animations"])
		Vector2i.UP:
			for column in GRID_SIZE:
				var line := _extract_column(board_copy, column)
				var merged = _compress_line(line, _column_indices(column))
				if merged["line"] != line:
					moved = true
					_apply_column(board_copy, column, merged["line"])
				score_gain += merged["score_gain"]
				max_tile = max(max_tile, merged["max_tile"])
				merged_indices.append_array(merged["merged_indices"])
				animations.append_array(merged["animations"])
		Vector2i.DOWN:
			for column in GRID_SIZE:
				var original := _extract_column(board_copy, column)
				var line := original.duplicate()
				var index_map := _column_indices(column)
				line.reverse()
				index_map.reverse()
				var merged = _compress_line(line, index_map)
				var merged_line: Array[int] = merged["line"]
				merged_line.reverse()
				if merged_line != original:
					moved = true
					_apply_column(board_copy, column, merged_line)
				score_gain += merged["score_gain"]
				max_tile = max(max_tile, merged["max_tile"])
				merged_indices.append_array(merged["merged_indices"])
				animations.append_array(merged["animations"])

	return {
		"board": board_copy,
		"moved": moved,
		"score_gain": score_gain,
		"max_tile": max_tile,
		"merged_indices": merged_indices,
		"animations": animations
	}


func _compress_line(values: Array[int], target_indices: Array[int]) -> Dictionary:
	var compacted: Array[int] = []
	var compacted_sources: Array[int] = []
	for index in values.size():
		var value := values[index]
		if value != 0:
			compacted.append(value)
			compacted_sources.append(target_indices[index])

	var merged: Array[int] = []
	var score_gain := 0
	var max_tile := 0
	var cursor := 0
	var merged_indices: Array[int] = []
	var animations: Array[Dictionary] = []

	while cursor < compacted.size():
		var value := compacted[cursor]
		var destination := target_indices[merged.size()]
		if cursor + 1 < compacted.size() and compacted[cursor + 1] == value:
			value *= 2
			score_gain += value
			merged_indices.append(destination)
			animations.append({
				"from": compacted_sources[cursor],
				"to": destination,
				"value": compacted[cursor],
				"merge": true
			})
			animations.append({
				"from": compacted_sources[cursor + 1],
				"to": destination,
				"value": compacted[cursor + 1],
				"merge": true
			})
			cursor += 1
		else:
			animations.append({
				"from": compacted_sources[cursor],
				"to": destination,
				"value": compacted[cursor],
				"merge": false
			})
		merged.append(value)
		max_tile = max(max_tile, value)
		cursor += 1

	while merged.size() < GRID_SIZE:
		merged.append(0)

	return {
		"line": merged,
		"score_gain": score_gain,
		"max_tile": max_tile,
		"merged_indices": merged_indices,
		"animations": animations
	}


func _row_indices(row: int) -> Array[int]:
	var indices: Array[int] = []
	for column in GRID_SIZE:
		indices.append(row * GRID_SIZE + column)
	return indices


func _column_indices(column: int) -> Array[int]:
	var indices: Array[int] = []
	for row in GRID_SIZE:
		indices.append(row * GRID_SIZE + column)
	return indices


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


func _apply_row(target_board: Array[int], row: int, values: Array[int]) -> void:
	for column in GRID_SIZE:
		target_board[row * GRID_SIZE + column] = values[column]


func _apply_column(target_board: Array[int], column: int, values: Array[int]) -> void:
	for row in GRID_SIZE:
		target_board[row * GRID_SIZE + column] = values[row]
