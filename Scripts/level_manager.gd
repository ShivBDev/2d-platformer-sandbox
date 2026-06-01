extends Node

@export var SCREENS_BELOW_TO_LOAD : int = 5
@export var SCREENS_ABOVE_TO_LOAD : int = 1

@onready var _player : Player = %Player
const _levels : Array[String] = [
	#region Caves
	"uid://b6ov1tltaebkb",	# 1
	"uid://ivu61fyw4ygq"	#2
]
var _max_lvl_idx : int = _levels.size() - 1
var _loaded_levels : Dictionary[String, LevelData] = {}
var _active_async_loads : Array[int] = []
var _currLvlIdx : int = 0
var _prevLvlIdx : int = 0

var _chunkLowLvlIdx : int :
	get: return maxi(0, _currLvlIdx - SCREENS_BELOW_TO_LOAD)
var _chunkHighLvlIdx : int :
	get: return mini(_max_lvl_idx, _currLvlIdx + SCREENS_ABOVE_TO_LOAD)

class LevelData:
	var lvl : Resource = null
	var instance : Node = null
	var index : int = 0
	func _init(level : Resource = null, inst : Node = null, idx : int = 0):
		self.lvl = level
		self.instance = inst
		self.index = idx

#region helpers
func __instance_lvl(lvl_data : LevelData):
	print("Instancing Lvl %d : %s" % [lvl_data.index, _levels[lvl_data.index]])
	var instance : Node = lvl_data.lvl.instantiate()
	instance.lvl_idx = lvl_data.index
	add_child(instance)
	lvl_data.instance = instance

func __finish_load(lvl_idx:int, lvl : Resource) -> void:
	var lvl_id = _levels[lvl_idx]
	var lvl_data = LevelData.new(lvl)
	lvl_data.index = lvl_idx
	_loaded_levels[lvl_id] = lvl_data
	# only instantiate if the lvl id is within our chunk
	if lvl_idx >= _chunkLowLvlIdx and lvl_idx <= _chunkHighLvlIdx:
		__instance_lvl(lvl_data)

func _poll_async_loads() -> void:
	var loaded_idx : Array[int] = []
	for lvl_idx in _active_async_loads:
		var lvl_id : String = _levels[lvl_idx]
		var status : ResourceLoader.ThreadLoadStatus = \
			ResourceLoader.load_threaded_get_status(lvl_id)
		match status:
			ResourceLoader.ThreadLoadStatus.THREAD_LOAD_FAILED:
				push_error("Failed to load level %s" % [lvl_id])
			ResourceLoader.ThreadLoadStatus.THREAD_LOAD_INVALID_RESOURCE:
				push_error("Tried to load invalid level: %s" % [lvl_id])
			ResourceLoader.ThreadLoadStatus.THREAD_LOAD_IN_PROGRESS:
				continue
			ResourceLoader.ThreadLoadStatus.THREAD_LOAD_LOADED:
				var lvl : Resource = ResourceLoader.load_threaded_get(lvl_id)
				__finish_load(lvl_idx, lvl)
				loaded_idx.append(lvl_idx)
	for lvl_idx in loaded_idx:
		_active_async_loads.erase(lvl_idx)

func _load_level(lvl_idx : int, async : bool = true) -> void:
	var lvl_id : String = _levels[lvl_idx]
	var lvl_data : LevelData
	if _loaded_levels.has(lvl_id):
		lvl_data = _loaded_levels[lvl_id]
		if lvl_data.instance != null : return # nothing to do, already instanced
		__instance_lvl(lvl_data)
		return
	if async:
		print("Queueing for Async Load: Lvl %d : %s"  % [lvl_idx, lvl_id])
		ResourceLoader.load_threaded_request(lvl_id)
		_active_async_loads.append(lvl_idx)
		return
	# Blocking load
	print("Loading Lvl %d : %s" % [lvl_idx, lvl_id])
	var lvl : Resource = load(lvl_id)
	__finish_load(lvl_idx, lvl)

func _unload_level(lvl_id : String) -> void:
	# level has never been loaded
	if not _loaded_levels.has(lvl_id) : return
	var lvl_data : LevelData = _loaded_levels[lvl_id]
	# level not currently instanced
	if lvl_data.instance == null : return
	# remove instance
	print("Removing Lvl id %s from tree." % [lvl_id])
	remove_child(lvl_data.instance)
	lvl_data.instance = null

func _update_chunk():
	for lvl_idx in range(0, _max_lvl_idx + 1):
		var lvl_id : String = _levels[lvl_idx]
		if lvl_idx >= _chunkLowLvlIdx and lvl_idx <= _chunkHighLvlIdx:
			_load_level(lvl_idx)
		else:
			_unload_level(lvl_id)
#endregion helpers

func _ready() -> void:
	_currLvlIdx = 0
	_prevLvlIdx = 0
	print("Loading First Level")
	_load_level(_currLvlIdx, false)
	_update_chunk()

func _process(_delta: float) -> void:
	var y : float = absf(_player.position.y)
	_currLvlIdx = int(floorf(y / GameData.LEVEL_HEIGHT))
	if _currLvlIdx != _prevLvlIdx:
		_update_chunk()
		_prevLvlIdx = _currLvlIdx
	_poll_async_loads()
