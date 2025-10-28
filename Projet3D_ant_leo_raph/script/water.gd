extends MeshInstance3D

@export var wave_settings: WaveSettings
@onready var mat := get_surface_override_material(0)

func _ready():
	if mat == null:
		mat = get_active_material(0)
	
	if mat and mat is ShaderMaterial:
		update_shader_from_settings(mat)
	else:
		push_error("Aucun ShaderMaterial trouvé sur la surface 0 de " + str(self))


func update_shader_from_settings(shader: ShaderMaterial) -> void:
	if not wave_settings:
		push_warning("wave_settings n'est pas assigné.")
		return
	
	# Envoi des paramètres de la ressource vers le shader
	shader.set_shader_parameter("waveCount", wave_settings.wave_count)
	shader.set_shader_parameter("amplitude", wave_settings.amplitude)
	shader.set_shader_parameter("wavelength", wave_settings.wavelength)
	shader.set_shader_parameter("speed", wave_settings.speed)
	shader.set_shader_parameter("direction", wave_settings.direction)
	shader.set_shader_parameter("steepness", wave_settings.steepness)


# Renvoie la position du point sur la surface (Vector3).
# (Si tu veux juste la hauteur, utilise get_wave_height_scalar)
func get_pose_on_wave(point: Vector3, time: float, max_iters := 4, alpha := 0.6, eps := 1e-4) -> Vector3:
	var offset := Vector3.ZERO
	var pos_on_wave := Vector3.ZERO

	for i in range(max_iters):
		var new_point := point - offset                # estimation courante (x,z plats)
		pos_on_wave = get_point_position(new_point, time)

		var new_offset := get_wave_offset(new_point, pos_on_wave)  # <-- fonction dédiée

		# relaxation pour éviter l’overshoot
		offset += (new_offset - offset) * alpha

		# critère d'arrêt robuste
		if (new_offset - offset).length() < eps:
			break

	return pos_on_wave


# Version pratique qui ne renvoie que la hauteur (float).
func get_wave_height(point: Vector3, time: float, max_iters := 8, alpha := 0.6, eps := 1e-4) -> float:
        return get_pose_on_wave(point, time, max_iters, alpha, eps).y


# ---- Fonctions de support ---------------------------------------------------

func get_height_and_normal(world_point: Vector3, time: float = -1.0) -> Dictionary:
        if time < 0.0:
                time = Time.get_ticks_msec() / 1000.0

        var local_point := to_local(world_point)
        var local_pose := get_pose_on_wave(local_point, time)
        var world_position := to_global(local_pose)

        var local_normal := _get_wave_normal(local_point, time)
        var world_normal := (global_transform.basis * local_normal).normalized()

        return {
                "height": world_position.y,
                "position": world_position,
                "normal": world_normal,
        }

# Position (Gerstner somme) pour un point (x,z) "plat"
func get_point_position(point: Vector3, time: float) -> Vector3:
        var pos := point
        var origin_xz := Vector2(point.x, point.z)

        for i in range(wave_settings.wave_count):
		var d := wave_settings.direction[i].normalized()
		var k := TAU / wave_settings.wavelength[i]
		var w := sqrt(9.8 * k)
		var phi := k * d.dot(origin_xz) - w * time * wave_settings.speed[i]

		var A := wave_settings.amplitude[i]
		var Q := wave_settings.steepness[i]
		var c := cos(phi)
		var s := sin(phi)

		pos.x += Q * A * d.x * c
		pos.z += Q * A * d.y * c
		pos.y += A * s

        return pos


# ⚠️ Fonction DÉDIÉE : offset horizontal entre l’estimation (new_point) et la position déplacée (pos_on_wave)
func get_wave_offset(new_point: Vector3, pos_on_wave: Vector3) -> Vector3:
        return Vector3(
                pos_on_wave.x - new_point.x,
                0.0,
                pos_on_wave.z - new_point.z
        )

func _get_wave_normal(point: Vector3, time: float) -> Vector3:
        var origin_xz := Vector2(point.x, point.z)
        var grad := Vector2.ZERO

        for i in range(wave_settings.wave_count):
                var d := wave_settings.direction[i].normalized()
                var k := TAU / wave_settings.wavelength[i]
                var w := sqrt(9.8 * k)
                var phi := k * d.dot(origin_xz) - w * time * wave_settings.speed[i]
                var A := wave_settings.amplitude[i]

                grad += d * (A * k * cos(phi))

        var normal := Vector3(-grad.x, 1.0, -grad.y)
        return normal.normalized()
	
func _process(delta):
	var t = Time.get_ticks_msec() / 1000.0
	if mat and mat is ShaderMaterial:
		mat.set_shader_parameter("time", t)
