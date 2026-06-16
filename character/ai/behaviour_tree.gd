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
	sequence, [
		[ selector, [
				[always_fail],
				[always_fail],
				[print, "Hello", "World"],
				[print, "Foo", "Bar"],
			]
		],
		[delay, 1.0],
		[print, "PAUSE"]
	]
]

func _cur_path() -> String:
	return "/".join(current_path)

func _res_fmt(res: Variant) -> String:
	if not res is int or res < Status.FAILURE or res > Status.COUNT: return str(res)
	return Status.keys()[res]

func _get_indent():
	return " " + "│ ".repeat(current_path.size() - 1)

func _print(...args):
	args.push_front("[color=#5c5c5c][BT] %s[/color]" % _get_indent())
	print_rich.callv(args)

func _cbl_fmt(c):
	if c is Callable:
		var reg = RegEx.create_from_string("[^:]+::")
		return reg.sub(str(c), "")
	if c is Array:
		return "[" + ", ".join(c.map(func(e): return _cbl_fmt(e))) + "]"
	return str(c)

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
		if debug: _print("Node \"%s\" no args" % _cbl_fmt(head))
		res = head.call()
	else:
		var tail = sexp.slice(1)
		if debug: _print("Node \"%s\" args: %s" % [_cbl_fmt(head), _cbl_fmt(tail)])
		res = head.callv(tail)
	if not res is Status: # Support for functions that don't return a Status
		if res == true:   # Explicitely "cast" booleans to success/failure
			res = Status.SUCCESS
		elif res == false:
			res = Status.FAILURE
		else:
			res = Status.SUCCESS # Returning anything else (null included) means we succeeded
	if debug and res != Status.SUCCESS:
		_print("Result %s" % _res_fmt(res))
		#_print("BT: State dict for is %s" % [str(state)])
	current_path.pop_back()
	return res

func tick() -> Status:
	if debug:
		print(" ")
	print(Time.get_ticks_msec() / 1000.0)
	if not tree.size(): return Status.SUCCESS
	var res = eval(tree)
	return res

func sequence(...tail) -> Status:
	tail = tail[0]
	var current_idx = state_get("resume_child_idx")
	if state_get("resume_child_idx") == null: current_idx = 0

	while current_idx < tail.size():
		current_path.append(str(current_idx))
		var res = eval(tail[current_idx])
		current_path.pop_back()

		match res:
			Status.RUNNING:
				state_set("resume_child_idx", current_idx)
				return res
			Status.FAILURE:
				state_erase("resume_child_idx")
				return res
			Status.EXIT:
				state_erase()
				return res
			Status.SUCCESS:
				current_idx += 1

	state_erase()
	return Status.SUCCESS

func selector(...tail) -> Status:
	tail = tail[0]
	var current_idx = state_get("resume_child_idx")
	if state_get("resume_child_idx") == null: current_idx = 0

	while current_idx < tail.size():
		current_path.append(str(current_idx))
		var res = eval(tail[current_idx])
		current_path.pop_back()

		match res:
			Status.RUNNING:
				state_set("resume_child_idx", current_idx)
				return res
			Status.EXIT:
				state_erase()
				return res
			Status.SUCCESS:
				state_erase()
				return res
			Status.FAILURE:
				current_idx += 1

	state_erase()
	return Status.FAILURE

func always_fail(): return Status.FAILURE
func always_succeed(): return Status.SUCCESS
func always_exit(): return Status.EXIT

func delay(duration: float, ..._args) -> Status:
	if duration == 0: return Status.SUCCESS
	if duration < 0: return Status.FAILURE
	var last_time = state_get("last_time")
	var cur_time = Time.get_ticks_msec()
	if last_time == null:
		state_set("last_time", cur_time)
		return Status.RUNNING
	if cur_time - last_time < duration * 1000.0:
		return Status.RUNNING
	state_erase()
	return Status.SUCCESS


func cond(...tail) -> Status:
	return eval(tail)

## Maybe not needed?
func cooldown(duration: float, ..._tail) -> Status:
	if debug:
		_print("[color=red]cooldown is not implemented[/color]")
	return Status.FAILURE

func check_signal(signal_name: String, ...tail) -> Status:
	if debug:
		_print("[color=red]check_signal is not implemented[/color]")
	return Status.FAILURE

func play_animation(anim_name: String, ...tail) -> Status:
	if debug:
		_print("[color=red]play_animation not implemented[/color]")
	return Status.FAILURE
