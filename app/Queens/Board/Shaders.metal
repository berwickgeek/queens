#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// Value noise and a 3-octave fBm, standing in for the SVG feTurbulence used in the mockups.
static float hash21(float2 p) {
    p = fract(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

static float vnoise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash21(i), hash21(i + float2(1, 0)), u.x),
               mix(hash21(i + float2(0, 1)), hash21(i + float2(1, 1)), u.x), u.y);
}

static float fbm(float2 p) {
    float v = 0.0, a = 0.5;
    for (int k = 0; k < 3; k++) {
        v += a * vnoise(p);
        p *= 2.0;
        a *= 0.5;
    }
    return v;
}

static float2 offsetAt(float2 position, float frequency, float amount) {
    float2 p = position * frequency;
    return float2(fbm(p) - 0.5, fbm(p + float2(17.3, 9.1)) - 0.5) * amount * 2.0;
}

// Watercolour bleed. Pixels inside the board sample from a nearby displaced point,
// clamped to the board so no paper shows through at the frame.
[[ stitchable ]] float2 washBleed(float2 position, float2 size, float inset, float frequency, float amount) {
    float2 lo = float2(inset + 0.5);
    float2 hi = size - inset - 0.5;
    if (any(position < lo) || any(position > hi)) { return position; }
    return clamp(position + offsetAt(position, frequency, amount), lo, hi);
}

// Hand-drawn wobble for ink lines.
[[ stitchable ]] float2 inkWobble(float2 position, float frequency, float amount) {
    return position + offsetAt(position, frequency, amount);
}

// Pigment granulation: slight light and dark mottling across the wash.
[[ stitchable ]] half4 granulate(float2 position, half4 color, float frequency, float strength) {
    if (color.a == 0.0h) { return color; }
    float n = fbm(position * frequency) * 0.7 + vnoise(position * frequency * 6.0) * 0.3;
    half m = half(1.0 + (n - 0.5) * strength);
    return half4(min(color.rgb * m, color.a), color.a);
}
