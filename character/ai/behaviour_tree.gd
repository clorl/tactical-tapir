extends Resource
class_name BehaviourTree

@export var debug := false

enum Status {
	FAILURE = 0,
	SUCCESS,
	RUNNING,
	EXIT,
	COUNT
}

var current_path = []

var state = {}

var tree = [
	sequence,
		[print, "Hello", "World"],
		[delay, 1.0],
		[print, "Goodbye", "World"],
		[delay, 1.0],
]

# var tree = [
# 	sequence, [
# 			[print, "Foo", "Bar"],
# 			[delay, 5.0],
# 			[print, "Bar", "Baz"],
# 			[delay, 5.0],
# 		]
# ]

func _cur_path() -> String:
	return "/".join(current_path)

func _res_fmt(res: Variant) -> String:
	if not res is int or res < Status.FAILURE or res > Status.COUNT: return str(res)
	return Status.keys()[res]

func _cbl_fmt(c):
	if c is Callable:
		var reg = RegEx.create_from_string("[^:]+::")
		return reg.sub(str(c), "")
	if c is Array:
		return "[" + ", ".join(c.map(func(e): return _cbl_fmt(e))) + "]"
	return str(c)

var strip_length = "resource(behaviour_tree)::".length()
func add_to_path(key: Callable):
	current_path.append(str(key).to_snake_case())

func state_get(key: String) -> Variant:
	var ob = state.get(_cur_path())
	if ob == null: return null
	return ob.get(key)

func state_set(key: String, value: Variant):
	if state.get(_cur_path()) == null:
		state.set(_cur_path(), {})
	state.get(_cur_path()).set(key, value)

func state_erase(key: String = ""):
	if not key:
		state.erase(_cur_path())
	else:
		var ob = state.get(_cur_path())
		if ob != null and ob is Dictionary:
			ob.erase(key)

## Evaluates an s-expression
func eval(sexp) -> Status:
	if not sexp.size(): return Status.SUCCESS
	if not sexp[0] is Callable:
		push_error("On BehaviourTree: unknown node type %s (should be a callable)" % _cbl_fmt(sexp[0]))
		return Status.FAILURE

	var res: Variant
	var head = sexp[0]
	add_to_path(head)
	if sexp.size() == 1:
		if debug: print("BT: Calling %s with no arguments" % _cbl_fmt(head))
		res = head.call()
	else:
		var tail = sexp.slice(1)
		if debug: print("BT: Calling %s with args: %s" % [_cbl_fmt(head), _cbl_fmt(tail)])
		res = head.callv(tail)
	if debug:
		print("BT: Result of %s is %s" % [_cbl_fmt(head), _res_fmt(res)])
		print("BT: State dict for is %s" % [str(state)])
	if res == null:
		return Status.SUCCESS
	current_path.pop_back()
	print(res, _cbl_fmt(sexp))
	return res

func tick() -> Status:
	if debug:
		print("  ")
		print("BT: Tick")
	if not tree.size(): return Status.SUCCESS
	var res = eval(tree)
	return res

func _seq_eval_child(idx, child) -> Status:
	current_path.append(idx)
	var res = eval.callv(child)
	print(res, _cbl_fmt(child))
	current_path.pop_back()
	if res == Status.RUNNING:
		return Status.RUNNING
	else:
		state_erase()
		if res == 0:
			print("oops", _cbl_fmt(child))
		return res

func sequence(...tail) -> Status:
	var idx = state_get("running_child_idx")
	if idx != null:
		var child = tail[idx]
		return _seq_eval_child(idx, child)

	for i in range(tail.size()):
		var child = tail[i]
		var res = _seq_eval_child(i, child)
		if res == Status.RUNNING:
			state_set("running_child_idx", i)
		if res != Status.SUCCESS:
			return res
	return Status.SUCCESS

func selector(...tail) -> Status:
	return Status.SUCCESS

func delay(duration_seconds: float, ..._args) -> Status:
	if duration_seconds == 0: return Status.SUCCESS
	if duration_seconds < 0: return Status.FAILURE

	var timestamp = state_get("delay_start")
	if timestamp == null:
		state_set("delay_start", Time.get_ticks_msec())
		return Status.RUNNING
	var cur_time = Time.get_ticks_msec()
	var time_over = cur_time - timestamp >= duration_seconds * 1000
	if time_over:
		state_erase()
		return Status.SUCCESS
	return Status.RUNNING

func cooldown(duration: float, ...tail) -> Status:
	return Status.SUCCESS

func cond(...tail) -> Status:
	return Status.SUCCESS

func check_signal(signal_name: String, ...tail) -> Status:
	return Status.SUCCESS

func play_animation(anim_name: String, ...tail) -> Status:
	return Status.SUCCESS
