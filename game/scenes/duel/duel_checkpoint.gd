extends RefCounted
## El punto de guardado queda fuera de animaciones y cuadros del motor.

const Store := preload("res://core/duel_checkpoint_store.gd")
const CLASSIC_STATE := ["executed", "frame_stage", "_ui_answer", "_dialog_msg",
	"_dialog_subs", "_dialog_constructor_closed", "_response_text", "_f_gui_input_packet",
	"_answer_visits", "headless_detached", "cursor_action"]
const JOEY_STATE := ["native_ticks", "_battle_player", "_battle_attacker", "_mail_stamp",
	"_last_text_symbol", "_dialog_template", "_lp_held", "_lp_started", "_lp_targets", "_field_target"]
const JOEY_ENGINE_STATE := ["phase_choice", "_visual_object_slots", "deferred_results",
	"defer_later", "_lp_projection"]


static func image_id(duel: Duel) -> PackedByteArray:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(duel.m.bytes)
	if duel is JoeyPresentationAdapter:
		context.update(duel.engine.m.bytes)
	return context.finish()


static func save(scene: Node, initial := false) -> Error:
	var value := {
		"game": scene.game, "lp": [8000, 8000], "image_id": scene._checkpoint_image,
		"match": [Game.duel_mode, Game.match_duel, Game.match_results, Game.match_outcome, Game.rival_deck],
		"decks": scene._replay_decks, "options": scene._replay_options, "seed": scene._replay_seed,
		"initial": initial,
	}
	if initial:
		return Store.write(Paths.save_dir, value)
	var duel: Duel = scene._duel
	var table: DuelCardTable = scene._visual.table
	value.merge({
		"lp": scene._shown_lp(),
		"memory": duel.m.bytes, "stack": duel.m._stack_top, "random": duel.rng.holdrand,
		"state": _capture(duel, CLASSIC_STATE), "commands": duel.recorded,
		"table": [table.field, table.hand, table.piles, table.inflight, table.detached],
		"phase": [scene._ph_p, scene._ph_phase], "visual_tick": scene._visual.visual_tick,
	}, true)
	if duel is JoeyPresentationAdapter:
		value["joey"] = {
			"memory": duel.engine.m.bytes, "stack": duel.engine.m._stack_top,
			"random": duel.engine.rng.holdrand, "local_player": duel.local_native_player,
			"commands": duel.engine.recorded, "file_commands": duel.file_recorded,
			"state": _capture(duel, JOEY_STATE), "engine_state": _capture(duel.engine, JOEY_ENGINE_STATE),
		}
	return Store.write(Paths.save_dir, value)


static func restore_engine(duel: Duel, value: Dictionary, id: PackedByteArray) -> bool:
	if value.get("image_id") != id:
		return false
	var native: Dictionary = value.get("joey", {})
	if not value.initial:
		if not value.get("memory") is PackedByteArray or value.memory.size() != duel.m.bytes.size():
			return false
		if duel is JoeyPresentationAdapter and (not native.get("memory") is PackedByteArray \
				or native.memory.size() != duel.engine.m.bytes.size()):
			return false
	var decks: Array[Dictionary] = []
	decks.assign(value.decks)
	duel.start_normal(decks, value.options, value.seed)
	if value.initial:
		return true
	duel.events.clear()
	duel.m.bytes = value.memory
	duel.m._stack_top = value.stack
	duel.rng.holdrand = value.random
	duel.recorded.assign(value.commands)
	_restore(duel, value.state)
	if duel is JoeyPresentationAdapter:
		duel.engine.m.bytes = native.memory
		duel.engine.m._stack_top = native.stack
		duel.engine.rng.holdrand = native.random
		duel.engine.events.clear()
		duel.engine.recorded.assign(native.commands)
		duel.file_recorded.assign(native.file_commands)
		duel.local_native_player = native.local_player
		duel._native_record_pos = duel.engine.recorded.size()
		duel._native_event_pos = 0
		_restore(duel, native.state)
		_restore(duel.engine, native.engine_state)
		duel.synchronize_view()
	return true


static func restore_board(scene: Node, value: Dictionary) -> void:
	var table: DuelCardTable = scene._visual.table
	table.field = value.table[0]
	table.hand = value.table[1]
	table.piles = value.table[2]
	table.inflight = value.table[3]
	table.detached.merge(value.table[4])
	table.revision += 1
	scene._visual.visual_tick = value.visual_tick
	scene._phase_panel_set(value.phase[0], value.phase[1])
	scene._ph_intro = 0x200
	scene._ph_fade = 0x100
	scene._sync_hand_layout()


static func _capture(object: Object, keys: Array) -> Dictionary:
	var state := {}
	for key: String in keys:
		state[key] = object.get(key)
	return state


static func _restore(object: Object, state: Dictionary) -> void:
	for key: String in state:
		object.set(key, state[key])
