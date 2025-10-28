shader_type spatial;
uniform float time;

const int MAX_WAVE_COUNT = 15;

uniform int waveCount;
uniform float amplitude[MAX_WAVE_COUNT];
uniform float wavelength[MAX_WAVE_COUNT];
uniform float speed[MAX_WAVE_COUNT];
uniform vec2  direction[MAX_WAVE_COUNT];
uniform float steepness[MAX_WAVE_COUNT];

varying vec3 v_normal_geom; // normale géométrique (analytique) vers le fragment

void vertex() {
	vec3 pos = VERTEX;

    // Tangentes initiales
    vec3 Tx = vec3(1.0, 0.0, 0.0);
    vec3 Tz = vec3(0.0, 0.0, 1.0);

    for (int i = 0; i < waveCount; i++) {
        vec2 d = normalize(direction[i]);
        float k = 2.0 * 3.14159265 / wavelength[i];
        float w = sqrt(9.8 * k);
        float phi = k * dot(d, pos.xz) - w * time * speed[i];

        float A = amplitude[i];
        float Q = steepness[i];
        float c = cos(phi);
        float s = sin(phi);

        // Déplacement position (Gerstner)
        pos.x += Q * A * d.x * c;
        pos.z += Q * A * d.y * c;
        pos.y += A * s;

		// Dérivé
        vec3 dPx_dx = vec3(1.0 - Q*A*k*d.x*d.x*s,  A*k*d.x*c,  -Q*A*k*d.x*d.y*s);
        vec3 dPx_dz = vec3(-Q*A*k*d.x*d.y*s,      A*k*d.y*c,   1.0 - Q*A*k*d.y*d.y*s);

        Tx += (dPx_dx - vec3(1.0, 0.0, 0.0));
        Tz += (dPx_dz - vec3(0.0, 0.0, 1.0));
	}
    

    VERTEX = pos;

    // Normale analytique
    v_normal_geom = normalize(cross(Tz, Tx)); // swap si inversée
}

void fragment() {
    // Donne la normale analytique à Godot
    NORMAL = normalize(v_normal_geom);

    // Couleur de base de l’eau
    ALBEDO = vec3(0.0, 0.25, 0.45);

    // Paramètres PBR pour activer réflexions et lumière
    METALLIC = 0.0;      // pas métallique (sinon reflets “chrome”)
    ROUGHNESS = 0.5;    // surface très lisse → fortes réflexions
    SPECULAR = 1.0;      // intensité du canal spéculaire
}
