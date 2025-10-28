extends RigidBody3D

@export var floater_markers: Array[Node3D] = []
@export var water_path: NodePath

@export var k_buoyancy: float = 600.0
@export var c_damping: float = 220.0
@export var max_force: float = 4000.0
@export var disable_above_surface := true

@onready var water := get_node_or_null(water_path)

func _physics_process(_delta: float) -> void:
        if water == null:
                return

        var time := Time.get_ticks_msec() / 1000.0

        for marker in floater_markers:
                if marker == null:
                        continue

                var world_point: Vector3 = marker.global_transform.origin
                if not water.has_method("get_height_and_normal"):
                        push_warning("Le noeud d'eau ne fournit pas get_height_and_normal().")
                        return

                var info: Dictionary = water.get_height_and_normal(world_point, time)
                var height := float(info.get("height", 0.0))
                var normal := (info.get("normal", Vector3.UP) as Vector3).normalized()

                var depth := height - world_point.y
                if disable_above_surface and depth <= 0.0:
                        continue

                var r := world_point - global_transform.origin
                var v_point := linear_velocity + angular_velocity.cross(r)
                var v_along_n := v_point.dot(normal)

                var spring := normal * (k_buoyancy * max(depth, 0.0))
                var damp := -normal * (c_damping * v_along_n)

                var force := spring + damp
                if force.length() > max_force:
                        force = force.normalized() * max_force

                apply_force(force, r)
