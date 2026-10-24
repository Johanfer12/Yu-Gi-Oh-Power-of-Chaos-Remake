extends Node
## Actualizador de la plataforma, con la misma API en PC y Android. Windows descarga y aplica
## el ejecutable publicado (core/updates_desktop.gd); Android valida el APK publicado y delega
## su instalación en el sistema (core/updates_android.gd).
signal changed

const REPOSITORY := "https://github.com/Johanfer12/Yu-Gi-Oh-Power-of-Chaos-Remake"
const _FORWARDED := [&"current", &"available", &"state", &"detail", &"_http"]

# Por el script y no por el autoload: las pruebas pueden compilar este archivo antes.
var impl: Node = load("res://core/updates_android.gd" if preload("res://autoload/paths.gd").android_platform()
		else "res://core/updates_desktop.gd").new()


func _ready() -> void:
	impl.name = "Implementation"
	impl.changed.connect(changed.emit)
	add_child(impl)


func _get(property: StringName) -> Variant:
	return impl.get(property) if property in _FORWARDED else null


func supported() -> bool:
	return impl.supported()


func check_once() -> void:
	impl.check_once()


func check() -> void:
	impl.check()


func download() -> void:
	impl.download()


func cancel() -> void:
	impl.cancel()


## Fracción descargada (0..1) o -1 si la plataforma o el servidor no la informan.
func progress() -> float:
	return impl.progress() if impl.has_method("progress") else -1.0
