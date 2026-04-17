#version 450

// top left (-1, -1)
// center (0, 0)
// bottom right (1, 1)

layout(location=0) in vec3 fragColor;
layout(location=0) out vec4 outColor;

void main() {
    outColor = vec4(fragColor, 1.0);
}