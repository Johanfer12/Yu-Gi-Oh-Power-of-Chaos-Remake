extends Node2D
## Ilustracion exterior al viewport nativo: el duelo conserva800x600 e input local.
const BACKGROUNDS := {
	"kaiba": "res://assets/backgrounds/kaiba_duel.png",
	"yugi": "res://assets/backgrounds/yugi_duel.jpg",
	"joey": "res://assets/backgrounds/joey_duel.png",
}
var _duel: Node
var _background := TextureRect.new()
var _shade := ColorRect.new()
var _shade_material := ShaderMaterial.new()
var _container := SubViewportContainer.new()
var _viewport := SubViewport.new()
var _window: Window

func _init(duel: Node) -> void:
	_duel = duel

func _ready() -> void:
	_window = get_tree().root
	_window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	var path: String = BACKGROUNDS.get(_duel.game, "")
	if path != "" and ResourceLoader.exists(path):
		_background.texture = load(path)
	_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shade.visible = false
	_shade_material.shader = preload("res://scenes/duel/duel_start_shade.gd").SHADER
	add_child(_shade)
	_container.mouse_filter = Control.MOUSE_FILTER_PASS
	_container.stretch = false
	add_child(_container)
	_viewport.size = Vector2i(800, 600)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_container.add_child(_viewport)
	_window.size_changed.connect(_layout)
	_layout()
	_viewport.add_child(_duel)
	_process(0.0)

func _process(_delta: float) -> void:
	# El duelo puede liberarse antes que este envoltorio (cambio de escena o prueba).
	if not is_instance_valid(_duel): return
	# El visor puede crear su presentacion despues de cargar una repeticion.
	if _duel._visual != null and not _duel._visual.background_shade_changed.is_connected(_sync_shade):
		_duel._visual.background_shade_changed.connect(_sync_shade)
		_duel._visual._render()

func _sync_shade(alpha: float, band_progress: int) -> void:
	_shade.visible = alpha > 0.0
	_shade.color = Color(0, 0, 0, alpha)
	_shade.material = _shade_material if band_progress >= 0 else null
	_shade_material.set_shader_parameter("progress", band_progress)

func _layout() -> void:
	var area := _window.get_visible_rect()
	_background.position = area.position
	_background.size = area.size
	_shade.position = area.position
	_shade.size = area.size
	_container.position = area.position + (area.size - Vector2(800, 600)) * 0.5
	_container.size = Vector2(800, 600)

func _exit_tree() -> void:
	if is_instance_valid(_window):
		if _window.size_changed.is_connected(_layout): _window.size_changed.disconnect(_layout)
