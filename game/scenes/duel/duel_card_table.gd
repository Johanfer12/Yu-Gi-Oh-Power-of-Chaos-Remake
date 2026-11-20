class_name DuelCardTable
extends RefCounted
## Tabla de objetos visuales de las cartas de la mesa (DAT_005af738, creada en 0x4387d0: un
## bloque de 0x410 por jugador). El original nunca reconstruye la mesa desde la memoria del
## motor: cada carta es un objeto (0x4111b0) que los comandos crean, mueven, voltean y llevan a
## las pilas, y lo que se dibuja es esa tabla. Aqui cada objeto es un diccionario
## {card, face, defense, owner}; `card` es el id de carta (-1 = sin carta; 0 es Blue-Eyes).
##
## Huecos por jugador (0x413170 / 0x412f20):
## - mano: vector +4..+0xc, se renumera al quitar o insertar (0x4133c0, 0x4422e0 / 0x4426f0);
## - campo k = 0..10 (+0x10 + k * 0x10);
## - k = 0xc..0xf: cartas en vuelo hacia la pila de esa ubicacion;
## - pilas 0xc fusion, 0xd mazo, 0xe cementerio, 0xf excluidas (clase 0x4384c0): numero de
##   cartas (+0xb8) e imagen de arriba. La imagen solo cambia cuando la carta llega (0x4135f0 ->
##   push 0x42edc0); al sacar una carta, la nueva imagen se lee de la memoria (0x413f50 ->
##   0x541a90). Una pila vacia no se dibuja (0x42f0e0).
##
## La escena inicializa objetos al cargar el duelo. Después, cada petición cambia esos objetos.

const PILES := [DuelMem.LOC_FUSION, DuelMem.LOC_DECK, DuelMem.LOC_GRAVE, DuelMem.LOC_BANISH]
const ClassicPile := preload("res://scenes/duel/classic_pile.gd")

var field: Array = [[], []]
var hand: Array = [[], []]
var piles: Array = [{}, {}]
## Cartas en vuelo hacia una pila (huecos 0xc-0xf): ubicacion -> objeto.
var inflight: Array = [{}, {}]
## Índice lógico retirado antes del movimiento de su objeto (0x78).
var detached := {}
## Sube con cada cambio de la tabla (la mesa se redibuja cuando cambia).
var revision := 0


func _init() -> void:
	clear()


func clear() -> void:
	revision += 1
	for p in 2:
		field[p] = []
		for z in 11: field[p].append({})
		hand[p] = []
		piles[p] = {}
		for loc in PILES: piles[p][loc] = {"count": 0, "top": -1}
		inflight[p] = {}
	detached.clear()

## 413250 consulta la espera de las cartas, incluidas las que vuelan a una pila.
func objects_busy() -> bool:
	for p in 2:
		for objects: Array in [field[p], hand[p], inflight[p].values()]:
			for card: Dictionary in objects:
				if card.get("moving", false) or card.has("counter_animation"):
					return true
	return false


func tick_piles() -> void:
	for p in 2:
		for pile: Dictionary in piles[p].values():
			if ClassicPile.tick(pile): revision += 1


# --- lectura de la memoria del motor ---------------------------------------------------------

static func memory_zone(duel: Duel, p: int, z: int) -> Dictionary:
	var at := DuelMem.zone(p, z)
	var index := duel.m.u16(at) & 0xfff
	if index == 0: return {}
	var flags := duel.m.u8(at + 6)
	return {"card": duel.cards.id_of(index), "face": (flags & 2) != 0, "defense": z < 5 and (flags & 1) != 0,
			"owner": (duel.m.u16(at) >> 12) & 1}


static func memory_hand(duel: Duel, p: int) -> Array:
	var out := []
	for i in duel.m.u8(DuelMem.pl(p) + DuelMem.P_HAND_N):
		var index := duel.m.u16(DuelMem.pl(p) + DuelMem.P_HAND + i * 4) & 0xfff
		# 0xc4/0xc5 vacian el hueco antes del vuelo: ya no es un objeto de la mano.
		if index == 0: continue
		out.append({"card": duel.cards.id_of(index), "face": true, "defense": false, "owner": p})
	return out


static func memory_pile(duel: Duel, p: int, loc: int) -> Dictionary:
	var count_at: int = {DuelMem.LOC_FUSION: DuelMem.P_FUSION_N, DuelMem.LOC_DECK: DuelMem.P_DECK_N,
			DuelMem.LOC_GRAVE: DuelMem.P_GRAVE_N, DuelMem.LOC_BANISH: DuelMem.P_BANISH_N}[loc]
	var list_at: int = {DuelMem.LOC_FUSION: DuelMem.P_FUSION, DuelMem.LOC_DECK: DuelMem.P_DECK,
			DuelMem.LOC_GRAVE: DuelMem.P_GRAVE, DuelMem.LOC_BANISH: DuelMem.P_BANISH}[loc]
	var n := duel.m.u8(DuelMem.pl(p) + count_at)
	var top := -1
	if n > 0:
		# El mazo tiene la carta de arriba en la posicion 0; las demas pilas, al final.
		var slot := 0 if loc == DuelMem.LOC_DECK else n - 1
		top = duel.cards.id_of(duel.m.u16(DuelMem.pl(p) + list_at + slot * 4) & 0xfff)
	return {"count": n, "top": top}


## Reconstruye la tabla entera desde la memoria (inicio del duelo o de un escenario).
func sync(duel: Duel) -> void:
	clear()
	for p in 2:
		for z in 11: field[p][z] = memory_zone(duel, p, z)
		hand[p] = memory_hand(duel, p)
		for loc in PILES: piles[p][loc] = memory_pile(duel, p, loc)


## Compara al terminar una secuencia. Las cartas separadas por 0x78 siguen
## siendo objetos válidos aunque su índice lógico haya desaparecido.
func compare_memory(duel: Duel) -> Array[Dictionary]:
	var differences: Array[Dictionary] = []
	for p in 2:
		for z in 11:
			var expected := memory_zone(duel, p, z)
			var actual: Dictionary = field[p][z]
			if expected.is_empty() and detached.has("%d:%d" % [p, z]): continue
			if not _same(actual, expected):
				differences.append({"where": "campo", "p": p, "z": z, "tabla": actual, "memoria": expected})
		var expected_hand := _hand_cards(memory_hand(duel, p))
		var actual_hand := _hand_cards(hand[p])
		if actual_hand != expected_hand:
			differences.append({"where": "mano", "p": p, "tabla": actual_hand, "memoria": expected_hand})
		for loc in PILES:
			var expected := memory_pile(duel, p, loc)
			var actual: Dictionary = piles[p][loc]
			var check_top: bool = loc in [DuelMem.LOC_GRAVE, DuelMem.LOC_BANISH]
			if expected["count"] != actual["count"] or (check_top and expected["top"] != actual["top"]):
				differences.append({"where": "pila", "p": p, "loc": loc, "tabla": actual, "memoria": expected})
	return differences


static func _same(a: Dictionary, b: Dictionary) -> bool:
	if a.is_empty() or b.is_empty(): return a.is_empty() == b.is_empty()
	return int(a["card"]) == int(b["card"]) and bool(a["face"]) == bool(b["face"]) and bool(a["defense"]) == bool(b["defense"])


static func _hand_cards(list: Array) -> Array:
	return list.map(func(o: Dictionary) -> int: return int(o["card"]))


# --- movimientos (0x414190) -------------------------------------------------------------------

## Saca el objeto de su origen. Mano: el hueco desaparece y las demas se renumeran. Pila: la
## pila pierde una carta y su nueva imagen se lee de la memoria (0x413f50 -> 0x541a90).
func take(duel: Duel, p: int, loc: int, i: int) -> Dictionary:
	revision += 1
	if loc < 11:
		var z := _field_slot(loc, i)
		var obj: Dictionary = field[p][z]
		field[p][z] = {}
		detached.erase("%d:%d" % [p, z])
		return obj
	if loc == DuelMem.LOC_HAND:
		if i < 0 or i >= hand[p].size(): return {}
		return hand[p].pop_at(i)
	if loc in PILES:
		var pile: Dictionary = piles[p][loc]
		if int(pile["count"]) == 0: return {}
		var obj := {"card": int(pile["top"]), "face": loc != DuelMem.LOC_DECK, "defense": false, "owner": p}
		var mem := memory_pile(duel, p, loc)
		pile["count"] = maxi(0, int(pile["count"]) - 1)
		pile["top"] = mem["top"] if int(mem["count"]) == int(pile["count"]) else _pile_top_below(duel, p, loc, int(pile["count"]))
		return obj
	return {}


## Imagen de la pila con `count` cartas segun la memoria (si la memoria ya tiene otra cuenta,
## la carta que queda en esa posicion).
static func _pile_top_below(duel: Duel, p: int, loc: int, count: int) -> int:
	if count <= 0: return -1
	var list_at: int = {DuelMem.LOC_FUSION: DuelMem.P_FUSION, DuelMem.LOC_DECK: DuelMem.P_DECK,
			DuelMem.LOC_GRAVE: DuelMem.P_GRAVE, DuelMem.LOC_BANISH: DuelMem.P_BANISH}[loc]
	var slot := 0 if loc == DuelMem.LOC_DECK else count - 1
	return duel.cards.id_of(duel.m.u16(DuelMem.pl(p) + list_at + slot * 4) & 0xfff)


## Pone el objeto en su destino al empezar el movimiento: campo o mano directamente; si es una
## pila, en el hueco de vuelo hasta que llegue (`land`).
func place(p: int, loc: int, i: int, obj: Dictionary) -> void:
	revision += 1
	if loc < 11:
		var z := _field_slot(loc, i)
		field[p][z] = obj
		detached.erase("%d:%d" % [p, z])
	elif loc == DuelMem.LOC_HAND:
		hand[p].insert(hand[p].size() if i < 0 else clampi(i, 0, hand[p].size()), obj)
	elif loc in PILES:
		inflight[p][loc] = obj


## Llegada a la pila (0x4135f0): suma una carta y, si va arriba, cambia la imagen.
func land(p: int, loc: int, on_top := true) -> void:
	if not inflight[p].has(loc): return
	revision += 1
	var obj: Dictionary = inflight[p][loc]
	inflight[p].erase(loc)
	var pile: Dictionary = piles[p][loc]
	pile["count"] = int(pile["count"]) + 1
	if on_top or int(pile["count"]) == 1: pile["top"] = int(obj.get("card", -1))


static func _field_slot(loc: int, i: int) -> int:
	if loc == 0 or loc == 5: return mini(loc + i, 10)
	return loc


# --- consultas (0x413170 / 0x412f20) ---------------------------------------------------------

## Indice de carta del objeto (-1 sin objeto, 0 objeto sin carta), como lee el motor +0x10.
func object_index(duel: Duel, p: int, loc: int) -> int:
	if loc in PILES:
		var top := int(piles[p][loc]["top"])
		return duel.cards.index_of(top) if int(piles[p][loc]["count"]) > 0 and top >= 0 else 0
	if loc < 0 or loc >= 11: return -1
	var obj: Dictionary = field[p][loc]
	if obj.is_empty(): return -1
	return duel.cards.index_of(int(obj["card"])) if int(obj["card"]) >= 0 else 0


## D03: parte inmovil en campo de410030. +14/+18 gobiernan411300;
## no equivale a la espera global413250 (faltan estados de otras rutas).
static func field_turn(previous: int, target: int, player: int) -> Dictionary:
	return {"previous": previous & 3, "target": target & 3, "player": player & 1,
		"counter": 0, "state": 0, "subcounter": 0, "angle": ((previous & 1) + (player & 1) * 2) * 128,
		"scale": 65536, "face_phase": ((previous >> 1) & 1) * 256, "tick": 0}

static func field_turn_busy(obj: Dictionary) -> bool:
	return int(obj.counter) != 256 or int(obj.state) != 0

static func field_turn_tick(obj: Dictionary) -> void:
	obj.tick = int(obj.tick) + 1
	if int(obj.counter) == 256:
		if int(obj.state) >= 1 and int(obj.state) <= 4:
			obj.subcounter = int(obj.subcounter) - 16
			if int(obj.subcounter) == 0: obj.state = 0
		return
	obj.counter = int(obj.counter) + 32
	var old_angle: int = ((int(obj.previous) & 1) + int(obj.player) * 2) * 128
	var new_angle: int = ((int(obj.target) & 1) + int(obj.player) * 2) * 128
	var constant_fields := 2 # Escala y posicion no cambian en este bloque de campo.
	if old_angle == new_angle:
		obj.angle = new_angle
		constant_fields += 1
	elif ((new_angle - old_angle) & 511) < 257:
		obj.angle = (old_angle + int(obj.counter) / 2) & 511
	else:
		obj.angle = (old_angle - int(obj.counter) / 2) & 511
	var old_face: int = (int(obj.previous) >> 1) & 1
	var new_face: int = (int(obj.target) >> 1) & 1
	if old_face == new_face:
		constant_fields += 1
		obj.face_phase = new_face * 256
	else:
		obj.face_phase = int(obj.counter) if new_face != 0 else 256 - int(obj.counter)
	if constant_fields == 4: obj.counter = 256

static func field_turn_at(obj: Dictionary, tick: int) -> void:
	while int(obj.tick) < tick: field_turn_tick(obj)
