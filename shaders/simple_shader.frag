#version 450

// top left (-1, -1)
// center (0, 0)
// bottom right (1, 1)

layout(location=0) out vec4 outColor;

layout(push_constant) uniform Push {
    vec2 offset;
    vec3 color;
} push;

void main() {
    outColor = vec4(push.color, 1.0);
}