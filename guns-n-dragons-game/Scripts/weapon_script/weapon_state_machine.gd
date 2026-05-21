extends Node
class_name WeaponStateMachine
enum State {
	IDLE,
	FIRING,
	RELOADING,
	EQUIPPING,
	UNEQUIPPING
}
var current_state: State = State.IDLE
var state_timers: Dictionary = {}  # state -> timer_duration
var state_change_callbacks: Array = []  # Signals that state changed
signal state_changed(new_state: State, old_state: State)
func _init() -> void:
	pass
func _ready() -> void:
	pass
func _process(delta: float) -> void:
	# Update any active state timers
	for state_name: String in state_timers:
		state_timers[state_name] -= delta
		if state_timers[state_name] <= 0:
			state_timers.erase(state_name)
# Request a state change
func enter_state(new_state: State, duration: float = 0.0) -> bool:
	var old_state: State = current_state
	current_state = new_state
	
	if duration > 0:
		state_timers[State.keys()[new_state]] = duration
	
	if old_state != new_state:
		state_changed.emit(new_state, old_state)
	return true
# Check if we can perform an action
func can_perform_action(action: State) -> bool:
	match action:
		State.FIRING:
			return current_state == State.IDLE
		State.RELOADING:
			return current_state in [State.IDLE, State.FIRING]
		State.EQUIPPING:
			return true
		_:
			return true
# Get current state as readable string
func get_state_name() -> String:
	return State.keys()[current_state]
# Debug print
func debug_print_state() -> void:
	pass
