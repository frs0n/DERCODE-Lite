// ========== FRAGMENT SHADER ==========
#version 450 compatibility

out vec3 albedoData;

/* DRAWBUFFERS:0 */

uniform sampler2D tex;
uniform float frameTimeCounter;

in vec2 texcoord;
in float tint;

void main() {
    // Твой оригинальный код
    vec2 rainUV = texcoord * vec2(4.0, 2.0);
    float albedoAlpha = texture(tex, rainUV).a;

    if (albedoAlpha < 0.1) discard;

    // === ДЕЛАЕМ КАПЛИ ЯРЧЕ И ЗАМЕТНЕЕ ===
    
    // Усиливаем альфу (видимость капель)
    albedoAlpha = pow(albedoAlpha, 0.6); // делаем плотнее
    albedoAlpha *= 3.0; // увеличиваем в 3 раза
    albedoAlpha = clamp(albedoAlpha, 0.0, 1.0);
    
    // Добавляем яркость
    vec3 color = vec3(albedoAlpha);
    color *= 2.5; // делаем ярче
    
    // Добавляем блик в центре капли
    vec2 center = rainUV - vec2(0.5, 0.5);
    float dist = length(center);
    float highlight = exp(-dist * dist * 8.0) * 1.5;
    color += highlight;
    
    // Легкое мерцание для заметности
    float flicker = sin(frameTimeCounter * 5.0 + texcoord.x * 10.0) * 0.1 + 1.0;
    color *= flicker;
    
    // Финальный вывод
    albedoData.b = color.r * tint;
}