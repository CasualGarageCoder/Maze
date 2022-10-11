# This work is licensed under the Creative Commons Attribution-NonCommercial 4.0 International License. To view a copy of this license, visit http://creativecommons.org/licenses/by-nc/4.0/.
extends Control

export var cameraY : float = 30
export var cameraZ : float = 15
export var cameraAngle : float = -70
export var sizeX : int = 21
export var sizeY : int = 21

const MazeGlobal = preload("res://scripts/maze/MazeType.gd")

export (MazeGlobal.MazeType) var mazeType = MazeGlobal.MazeType.normal

func _ready():
	pass

func _on_TinySize_toggled(button_pressed):
	if button_pressed:
		sizeX = 5
		sizeY = 5
		cameraY = 7
		cameraZ = 3.8
		cameraAngle = -64

func _on_SmallSize_toggled(button_pressed):
	if button_pressed:
		sizeX = 11
		sizeY = 11
		cameraY = 15
		cameraZ = 7.5
		cameraAngle = -68

func _on_RegularSize_toggled(button_pressed):
	if button_pressed:
		sizeX = 21
		sizeY = 21
		cameraY = 30
		cameraZ = 15
		cameraAngle = -70

func _on_LargeSize_toggled(button_pressed):
	if button_pressed:
		sizeX = 41
		sizeY = 41
		cameraY = 60
		cameraZ = 30
		cameraAngle = -69

func _on_ExtraLargeSize_toggled(button_pressed):
	if button_pressed:
		sizeX = 71
		sizeY = 71
		cameraY = 85
		cameraZ = 52.5
		cameraAngle = -68

func _on_Twisted_toggled(button_pressed):
	if button_pressed:
		mazeType = MazeGlobal.MazeType.twisted

func _on_Normal_toggled(button_pressed):
	if button_pressed:
		mazeType = MazeGlobal.MazeType.normal


func _on_Elongated_toggled(button_pressed):
	if button_pressed:
		mazeType = MazeGlobal.MazeType.elongated
