# This work is licensed under the Creative Commons Attribution-NonCommercial 4.0 International License. To view a copy of this license, visit http://creativecommons.org/licenses/by-nc/4.0/.
extends Spatial

# A cell is encoded with 4 bits. Each bit represent a wall.
const NORTH : int = 1
const SOUTH : int = 2
const WEST  : int = 4
const EAST  : int = 8

const MazeGlobal = preload("res://scripts/maze/MazeType.gd")

# Sub-scenes
onready var meshCrossing = load("res://volumes/maze/crossing.tscn")
onready var meshTjunction = load("res://volumes/maze/T.tscn")
onready var meshLjunction = load("res://volumes/maze/L.tscn")
onready var meshStraight = load("res://volumes/maze/straight.tscn")
onready var meshDeadend = load("res://volumes/maze/ending.tscn")
onready var meshWeave = load("res://volumes/maze/weave.tscn")

onready var meshPathEnd = load("res://volumes/maze/pathEnd.tscn")
onready var meshPathL = load("res://volumes/maze/pathL.tscn")
onready var meshPathStraight = load("res://volumes/maze/pathStraight.tscn")
onready var meshPathDot = load("res://volumes/maze/pathDot.tscn")

onready var meshAssoc = [
	meshCrossing,    # 0
	meshTjunction,   # 1
	meshTjunction,   # 2
	meshStraight,    # 3
	meshTjunction,   # 4
	meshLjunction,   # 5
	meshLjunction,   # 6
	meshDeadend,     # 7
	meshTjunction,   # 8
	meshLjunction,   # 9
	meshLjunction,   # 10
	meshDeadend,     # 11
	meshStraight,    # 12
	meshDeadend,     # 13
	meshDeadend,     # 14
	null,            # 15
	meshWeave,       # 16
	meshWeave        # 17
	 ]

# A cell type is determined by the number of wall.
# 'X' = Crossing
# 'E' = Ending
# 'L' = Turn
# 'T' = T-Section
# 'S' = Straight
# 'O' = Isolated (should not occur)
#                                0    1    2    3    4    5    6    7    8    9    10   11   12   13   14   15   16,  17
const TYPE                  = [ 'X', 'T', 'T', 'S', 'T', 'L', 'L', 'E', 'T', 'L', 'L', 'E', 'S', 'E', 'E', 'O', "W", "w" ]
onready var meshOrientation = [   0,  90, -90,  90, 180,  90, 180, 180,   0,   0, -90,   0,   0,  90, -90,   0,   0,  90 ]

const END_ORIENTATION = [[0, 180, 0],[270, 0, 90],[0, 0, 0]]

# Integer position inner class.
class IntegerPosition:
	# Relative of absolute position
	var x : int
	var y : int
	# Relative movement to arrive to this position
	var vx : int
	var vy : int
	
	func _init(a : int, b : int, va : int = 0, vb : int = 0):
		x = a
		y = b
		vx = va
		vy = vb
	
	func getX() -> int :
		return x
	
	func getY() -> int :
		return y
	
	func getVx() -> int :
		return vx
	
	func getVy() -> int :
		return vy

	func decal(dx : int, dy : int) -> IntegerPosition :
		var dec : IntegerPosition = IntegerPosition.new(x + dx, y + dy, dx, dy)
		return dec
	
	func decalByPos(pos : IntegerPosition) -> IntegerPosition:
		return decal(pos.x, pos.y)
	
	func isSameDir(other : IntegerPosition) -> bool:
		return vx == other.vx and vy == other.vy

	func _to_string():
		return "(%d, %d)[%d, %d]" % ([x, y, vx, vy])


class PathOrientation:
	# Mesh
	var mesh
	# Orientation
	var angle : float
	# Description
	var description : String
	
	# Constructor.
	func _init(m, a : float, d : String):
		mesh = m
		angle = a
		description = d

	func instantiate(pos : Vector2) -> Node:
		var instance = mesh.instance()
		instance.translation = Vector3(pos.x, 0, pos.y)
		# Orientation
		instance.rotation_degrees = Vector3(0, angle, 0)
		return instance
		
	func _to_string():
		return "Path '%s'" % (description)

var pathData : Array

# Array about neighbors and walls
const WALLS = [ [ 0, 1, 0 ], [ 4, 0, 8 ], [ 0, 2, 0 ] ]

# Gameplay variables.
var maze # Actually maze.
var entry : IntegerPosition
var exit : IntegerPosition
var path = [] # Current player path.
var segments = [] # Segment of path.

# Flag to be set to true if the solution as been achieved.
onready var isFinished : bool = false
onready var timeLimit

var timespent : float
var onPause : bool = false

onready var possibleChoiceColor : Color = Color(1, 1, 1)
onready var turnBackColor : Color = Color(0.2, 0.2, 0.6)

# Scene entry point.
func _ready():
	if meshPathL == null:
		print("Mesh path 'L' is null")
	if meshPathStraight == null:
		print("Mesh path 'S' is null")
	var pathStraight = PathOrientation.new(meshPathStraight, 0, "Straigth")
	var pathStraight90 = PathOrientation.new(meshPathStraight, 90, "Straigth 90")
	var pathLTurn0 = PathOrientation.new(meshPathL, 0, "L 0")
	var pathLTurn90 = PathOrientation.new(meshPathL, 90, "L 90")
	var pathLTurn180 = PathOrientation.new(meshPathL, 180, "L 180")
	var pathLTurn270 = PathOrientation.new(meshPathL, 270, "L 270")
	var pathNoSolution = [[null, null, null],[null, null, null],[null, null, null]]
	var pathMinusOne = [pathNoSolution,[[null, pathStraight, null],[pathLTurn90, null, pathLTurn180],[null, null, null]],pathNoSolution]
	var pathZero = [[[null, pathLTurn270, null],[pathStraight90, null, null],[null, pathLTurn180, null]],pathNoSolution,[[null, pathLTurn0, null],[null, null, pathStraight90],[null, pathLTurn90, null]]]
	var pathPlusOne = [pathNoSolution,[[null, null, null],[pathLTurn0, null, pathLTurn270],[null, pathStraight, null]],pathNoSolution]
	pathData = [ pathMinusOne, pathZero, pathPlusOne ]
	onPause = true
	$Settings.visible = true
	$GUI/IndicationLabel.visible = false
	reinit()

# Create a locked (all walls up) grid.
func createGrid(width : int, height : int, value : int = 255) :
	var result = []
	for _i in range(width):
		var line = []
		for _j in range(height):
			line.append(value)
		result.append(line)
	return result

# Maze Generation
func generateMaze(width : int, height : int, straightP : int = 1, turnP : int = 1) :
	var grid = createGrid(width, height, 255) # 255 is a magic value for unexplored cell.
	
	if straightP < 1:
		straightP = 1
	if turnP < 1:
		turnP = 1
	randomize()
	var startingCell : IntegerPosition = IntegerPosition.new(randi() % width, randi() % height)
	var stack = []
	stack.push_back(startingCell)
	grid[startingCell.getX()][startingCell.getY()] = 15
	
	while not stack.empty():
		var current : IntegerPosition = stack.pop_back()
		var neighbors = []
		for i in range(-1, 2):
			for j in range(-1, 2):
				var nx = current.getX() + i
				var ny = current.getY() + j
				if abs(i + j) == 1 and nx >= 0 and ny >= 0 and nx < width and ny < height and grid[nx][ny] == 255:
					var candidate : IntegerPosition = IntegerPosition.new(i, j, i, j)
					var occurrence : int = 0
					if candidate.isSameDir(current):
						occurrence = straightP
					else:
						occurrence = turnP
					for _k in range(occurrence):
						neighbors.append(candidate) # we store the relative position
		if not neighbors.empty():
			var selected : int = randi() % neighbors.size()
			var selectedPos : IntegerPosition = neighbors[selected]
			var wallvalue : int = WALLS[selectedPos.getX()+1][selectedPos.getY()+1]
			grid[current.getX()][current.getY()] &= ~wallvalue
			var newPos = current.decalByPos(selectedPos)
			var mirrorPos : IntegerPosition = IntegerPosition.new(-selectedPos.getX(), -selectedPos.getY())
			grid[newPos.getX()][newPos.getY()] = ~WALLS[mirrorPos.getX() + 1][mirrorPos.getY() + 1] & 0xF
			stack.push_back(current) # Re-inject the previous step
			stack.push_back(newPos)
	return grid

func addWeaves(grid, proba : float) :
	var width : int = len(grid)
	for i in range(1, width - 1):
		randomize()
		var height : int = len(grid[i])
		for j in range(1, height - 1):
			var value : int = grid[i][j]
			if value == 3 or value == 12:
				var p : float = randf()
				if p < proba:
					p = randf()
					var weaveValue = 16 if p < 0.5 else 17
					grid[i][j] = weaveValue
					if value == 12:
						if grid[i][j - 1] < 15:
							grid[i][j - 1] &= ~WALLS[1][2]
						if grid[i][j + 1] < 15:
							grid[i][j + 1] &= ~WALLS[1][0]
					elif value == 3:
						if grid[i - 1][j] < 15:
							grid[i - 1][j] &= ~WALLS[2][1]
						if grid[i + 1][j] < 15:
							grid[i + 1][j] &= ~WALLS[0][1]
	return grid

func generateInstances(grid, width : int, height : int, distance, maxDist : int, exitPos : IntegerPosition):
	var startPos : Vector2 = Vector2(-width, -height)
	for i in range(width):
		for j in range(height):
			var code : int = grid[i][height - j - 1]
			var cellScene = meshAssoc[code].instance()
			# Material
			var material : SpatialMaterial = SpatialMaterial.new()
			if exitPos.getX() == i and exitPos.getY() == height - j - 1:
				material.albedo_color = Color(0, 1, 0)
			else:
				var color : float = ((distance[i][height - j - 1] / float(maxDist)) * 0.8)
				material.albedo_color = Color(0.2 + color, 0.3, 0.2 + color)
			for mesh in cellScene.get_children():
				mesh.set_surface_material(0, material)
			# Position
			var offset : Vector2 = Vector2(startPos.x + (i * 2), startPos.y + (j * 2))
			cellScene.translation = Vector3(offset.x, 0, offset.y)
			# Orientation
			cellScene.rotation_degrees = Vector3(0, meshOrientation[code], 0)
			$Maze.add_child(cellScene)

var width : int
var height : int

func reinit():
	width = $Settings.sizeX
	height = $Settings.sizeY
	var cameraPos : Vector3 = Vector3(-1, $Settings.cameraY, $Settings.cameraZ)
	$Camera.translation = cameraPos
	$Camera.rotation_degrees = Vector3($Settings.cameraAngle, 0, 0)

	path.clear()
	for s in segments:
		s.clear()
	segments.clear()
	timespent = 0

	var lines : int = 1
	var turns : int = 1
	
	if $Settings.mazeType == MazeGlobal.MazeType.twisted:
		turns = 7
		lines = 1
	elif $Settings.mazeType == MazeGlobal.MazeType.elongated:
		turns = 1
		lines = 7
	else:
		turns = 1
		lines = 1

	maze = generateMaze(width, height, lines, turns)
	#maze = addWeaves(maze, 0.6)

	# Compute entry and exit
	# Compute exit.
	var distanceFromEntry = createGrid(width, height, -1)
	var cursors = []
	cursors.append(IntegerPosition.new(0, 0))
	distanceFromEntry[0][0] = 0
	var distanceMax : int = 0
	while not cursors.empty():
		var current = cursors.pop_back()
		var i : int = current.getX()
		var j : int = current.getY()
		var score = distanceFromEntry[i][j] + 1
		if score > distanceMax:
			distanceMax = score
		var walls = maze[i][j]
		if walls & WALLS[1][0] == 0 and distanceFromEntry[i][j-1] < 0:
			distanceFromEntry[i][j - 1] = score
			cursors.push_back(IntegerPosition.new(i, j - 1))
		if walls & WALLS[1][2] == 0 and distanceFromEntry[i][j+1] < 0:
			distanceFromEntry[i][j + 1] = score
			cursors.push_back(IntegerPosition.new(i, j + 1))
		if walls & WALLS[0][1] == 0 and distanceFromEntry[i-1][j] < 0:
			distanceFromEntry[i-1][j] = score
			cursors.push_back(IntegerPosition.new(i - 1, j))
		if walls & WALLS[2][1] == 0 and distanceFromEntry[i+1][j] < 0:
			distanceFromEntry[i + 1][j] = score
			cursors.push_back(IntegerPosition.new(i + 1, j))
	# Browse the border to determine the exit.
	var maxScore : int = 0
	var posX : int
	var posY : int
	var wallToBreak : int
	for i in range(width):
		var curScore : int = distanceFromEntry[i][0]
		if curScore >= maxScore:
			maxScore = curScore
			posX = i
			posY = 0
			wallToBreak = WALLS[1][0]
		curScore = distanceFromEntry[i][height - 1]
		if curScore >= maxScore:
			maxScore = curScore
			posX = i
			posY = height - 1
			wallToBreak = WALLS[1][2]
	for i in range(height):
		var curScore : int = distanceFromEntry[0][i]
		if curScore >= maxScore:
			maxScore = curScore
			posX = 0
			posY = i
			wallToBreak = WALLS[0][1]
		curScore = distanceFromEntry[width - 1][i]
		if curScore >= maxScore:
			maxScore = curScore
			posX = width - 1
			posY = i
			wallToBreak = WALLS[2][1]
	exit = IntegerPosition.new(posX, posY) # Direction ?
	maze[posX][posY] &= ~wallToBreak
	
	# Entry is (0, 0).
	entry = IntegerPosition.new(0, 0, 1, 0)
	maze[0][0] &= ~WALLS[0][1]
	path.clear()
	path.push_back(entry)

	# Compute graphism
	generateInstances(maze, width, height, distanceFromEntry, distanceMax, exit)
	# Add path start (We start at (0,0) and finish at (width - 1, height - 1))
	setStarter()
	updateIndicators()

func clearStage():
	for i in $Maze.get_children():
		$Maze.remove_child(i)
	for i in $Path.get_children():
		$Path.remove_child(i)
	reinit()

func _process(_delta):
	if onPause:
		return
	if isFinished:
		var curTime = OS.get_ticks_msec()
		if curTime > timeLimit:
			$Wining.visible = false
			clearStage()
			timespent = 0
			isFinished = false
	else:
		timespent += _delta
		$GUI/TimeSpent.text = "%.2fs" % (timespent)

func _input(event):
	if isFinished or onPause:
		return
	if event.is_action_pressed("ui_cancel"):
		onPause = true
		$Settings.visible = true
		$GUI/IndicationLabel.visible = false
		return
	var current : IntegerPosition = path[path.size() - 1] if not path.empty() else null
	var mask : int = maze[current.getX()][current.getY()] if not current == null else 15
	var dx : int = 0
	var dy : int = 0
	if event.is_action_pressed("ui_up"):
		dx = 0
		dy = 1
	elif event.is_action_pressed("ui_down"):
		dx = 0
		dy = -1
	elif event.is_action_pressed("ui_left"):
		dx = -1
		dy = 0
	elif event.is_action_pressed("ui_right"):
		dx = 1
		dy = 0
	if abs(dx + dy) == 1:
		# Is it a progression or a regression ?
		if (dx + current.getVx()) == 0 and (dy + current.getVy()) == 0:
			## regression
			if not segments.empty():
				segments.pop_back()
				path.pop_back()
		else:
			var progression = progressToNextChoice(maze, current, dx, dy)
			if progression.size() < 2:
				pass # Nothing to add.
			else:
				segments.append(progression)
				var next = progression[progression.size() - 1]
				path.append(next)
				if exit.getX() == next.getX() and exit.getY() == next.getY():
					isFinished = true
					$Wining.visible = true
					$Wining/WinText.text = "Completed in\n%.02f seconds" % timespent
					timeLimit = OS.get_ticks_msec() + 5000 # Next maze in 5 secs
		# Clear models for old path.
		for i in $Path.get_children():
			$Path.remove_child(i)
		# Redraw path from scratch.

		var segmentsCount : int = segments.size()
		var previousStep : IntegerPosition = segments[0][0] if not segments.empty() and not segments[0].empty() else null
		if previousStep != null:
			for s in range(0, segmentsCount):
				var segment = segments[s]
				var pointsCount : int = segment.size()
				for i in range(0, pointsCount):
					var pointInPath : IntegerPosition = segment[i]
					if previousStep.getX() != pointInPath.getX() or previousStep.getY() != pointInPath.getY():
#					var entryPos : Vector2 = Vector2(-width + (pointInPath.getX() * 2), height - 2 - (2 * pointInPath.getY()))
						var entryPos : Vector2 = Vector2(-width + (previousStep.getX() * 2), height - 2 - (2 * previousStep.getY()))
						var entryPath = pathData[previousStep.getVx()+1][previousStep.getVy()+1][pointInPath.getVx()+1][pointInPath.getVy()+1]
						if entryPath != null:
							var entryMesh = entryPath.instantiate(entryPos)
							entryMesh.translation = Vector3(entryPos.x, 0, entryPos.y)
							$Path.add_child(entryMesh)
					previousStep = pointInPath
			# Draw path end !
			var instanceEnd = meshPathEnd.instance()
			instanceEnd.translation = Vector3(-width + (previousStep.getX() * 2), 0, height - 2 - (2 * previousStep.getY()))
			
			instanceEnd.rotation_degrees = Vector3(0, END_ORIENTATION[previousStep.getVx()+1][previousStep.getVy()+1], 0)
			$Path.add_child(instanceEnd)
		else:
			setStarter()
		updateIndicators()

func updateIndicators():
	var position = IntegerPosition.new(0, 0, 1, 0) if segments.empty() else segments[segments.size() - 1][segments[segments.size() - 1].size() - 1]
	var walls = maze[position.getX()][position.getY()]
	var mask = WALLS[position.getVx() + 1][position.getVy() + 1]
	$GUI/UpIndicator.visible = walls & EAST == 0
	$GUI/UpIndicator.modulate = possibleChoiceColor if mask & WEST == 0 else turnBackColor
	$GUI/DownIndicator.visible = walls & WEST == 0
	$GUI/DownIndicator.modulate = possibleChoiceColor if mask & EAST == 0 else turnBackColor
	$GUI/LeftIndicator.visible = walls & NORTH == 0
	$GUI/LeftIndicator.modulate = possibleChoiceColor if mask & SOUTH == 0 else turnBackColor
	$GUI/RightIndicator.visible = walls & SOUTH == 0
	$GUI/RightIndicator.modulate = possibleChoiceColor if mask & NORTH == 0 else turnBackColor

func setStarter():
	var entryPos : Vector2 = Vector2(-width, height - 2)
	var entryPath = meshPathEnd.instance()
	entryPath.translation = Vector3(entryPos.x, 0, entryPos.y)
	$Path.add_child(entryPath)


func progressToNextChoice(grid, start : IntegerPosition, dx : int, dy : int) -> Array :
	# grid is the maze
	# start is the starting point.
	# dx, dy is the chosen direction.
	var progression : Array = []

	progression.push_back(start)
	
	# First, determine if the first move is valid.
	var current : int = grid[start.getX()][start.getY()]
	if current & WALLS[dx + 1][dy + 1] != 0:
		return progression
	
	var cursor : IntegerPosition = IntegerPosition.new(start.getX() + dx, start.getY() + dy, dx, dy)
	progression.push_back(cursor)
	current = grid[cursor.getX()][cursor.getY()]
	var watchdog : int = 0
	while TYPE[current] == "L" or TYPE[current] == "S":
		if cursor.getX() == exit.getX() and cursor.getY() == exit.getY():
			break
		watchdog += 1
		if watchdog > (len(grid) * len(grid[0])):
			break
		# Test next.
		var found : bool = false
		for vx in range(-1, 2):
			for vy in range(-1, 2):
				if (abs(vx + vy) == 1) and not(current & WALLS[vx + 1][vy + 1] != 0 or ((vx + cursor.getVx()) == 0 and (vy + cursor.getVy()) == 0)):
					# We can go there.
					cursor = IntegerPosition.new(cursor.getX() + vx, cursor.getY() + vy, vx, vy)
					current = grid[cursor.getX()][cursor.getY()]
					progression.push_back(cursor)
					found = true
					break
			if found:
				break
		if not found:
			break
	return progression

func _on_Play_pressed():
	$Settings.visible = false
	$GUI/IndicationLabel.visible = true
	clearStage()
	onPause = false

func _on_Cancel_pressed():
	$Settings.visible = false
	$GUI/IndicationLabel.visible = true
	onPause = false

func _on_Exit_pressed():
	get_tree().quit()
