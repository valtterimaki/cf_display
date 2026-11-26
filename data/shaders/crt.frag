// CRT composite signal: each pixel row is encoded into a PAL (or NTSC) composite
// TV signal and decoded again, so colour bleed, dot crawl and rainbows come out of
// the signal itself. See docs/crt.md.
//
// GLSL ES 1.00 so the same file runs on the Raspberry Pi and the desktop.
// fx_crt.pde adds "#define TAPS n" and "#define PAL n" in front when it compiles this
// (loop bounds must be constants), and sets the uniforms from data/crt.json.
//
// The trick that makes it cheap: the signal is sampled at exactly 4 samples per
// colour subcarrier cycle, so the subcarrier's cos/sin are only ever 1, 0 or -1.
// No trig at all. Tap i is at phase (first tap's phase + i) mod 4, and since the loop
// is unrolled, i mod 4 is known when compiling: each tap is one texture read,
// one dot product and a few multiply-adds.

#ifdef GL_ES
precision highp float;
#endif

#define PROCESSING_TEXTURE_SHADER

#ifndef TAPS
#define TAPS 6
#endif
#ifndef PAL
#define PAL 1
#endif

// Texture reads per pixel
#define N (2 * TAPS + 1)

// Subcarrier phase step in quarter cycles, per scan line and per frame.
//   PAL  283.7516 cycles/line -> 0.75 cycle -> 3
//   NTSC 227.5    cycles/line -> 0.5 cycle  -> 2
#if PAL
  #define LINE_SHIFT  3.0
  #define FRAME_SHIFT 3.0
#else
  #define LINE_SHIFT  2.0
  #define FRAME_SHIFT 2.0
#endif

uniform sampler2D texture;
uniform vec2  resolution;
uniform float phaseFrame;     // frameCount % 4: moves the dot pattern each frame (dot crawl)
uniform float noiseSeed;

uniform float chromaWeight[N];  // Gaussian colour filter, one weight per tap
uniform float chromaSumEven;    // sum of the even taps' weights (for normalising)
uniform float chromaSumOdd;     // sum of the odd taps' weights
uniform float lumaWeight[N];    // brightness filter: [1,2,2,2,1]/8 subcarrier trap + leak
uniform float chromaDelay;      // px, colour sits this far right of brightness

uniform float chromaGain;
uniform vec2  hueRotation;      // cos and sin of the hue error
uniform float nonlin;
uniform float clipHi;
uniform float noise;

varying vec4 vertTexCoord;

float hash(vec3 p) {
  p = fract(p * 0.1031);
  p += dot(p, p.yzx + 33.33);
  return fract((p.x + p.y) * p.z);
}

void main() {
  float x    = floor(vertTexCoord.x * resolution.x);
  float line = floor(vertTexCoord.y * resolution.y);

  // Taps run from `first` to first + 2*TAPS. The colour taps are centred
  // chromaDelay px to the left, so colour lands to the right of edges.
  float first = x - chromaDelay - float(TAPS);

  // Phase of the first tap in quarter cycles, and the subcarrier's cos (c0)
  // and sin (s0) there: one of (1,0), (0,1), (-1,0), (0,-1).
  float q = mod(first + LINE_SHIFT * line + FRAME_SHIFT * phaseFrame, 4.0);
  float c0 = q < 0.5 ? 1.0 : ((q > 1.5 && q < 2.5) ? -1.0 : 0.0);
  float s0 = (q > 0.5 && q < 1.5) ? 1.0 : (q > 2.5 ? -1.0 : 0.0);

  // Encoding R'G'B' into the composite signal is a dot product with a vector that
  // depends on the phase. Brightness Y plus colour on the subcarrier:
  //   PAL:  Y + gain * (U sin + sw V cos), sw flips every line
  //   NTSC: Y + gain * (I cos + Q sin)
  vec3 toY = vec3(0.299, 0.587, 0.114);
#if PAL
  float sw = mod(line, 2.0) < 0.5 ? 1.0 : -1.0;
  vec3 onSin = chromaGain * vec3(-0.147141, -0.288869,  0.436010);        // U
  vec3 onCos = chromaGain * sw * vec3(0.614975, -0.514965, -0.100010);    // V
#else
  vec3 onSin = chromaGain * vec3(0.2115, -0.5227,  0.3112);               // Q
  vec3 onCos = chromaGain * vec3(0.5959, -0.2746, -0.3213);               // I
#endif
  // The 4 phases: (cos, sin) = (c0, s0), (-s0, c0), (-c0, -s0), (s0, -c0)
  vec3 p = s0 * onSin + c0 * onCos;
  vec3 r = c0 * onSin - s0 * onCos;
  vec3 enc0 = toY + p;
  vec3 enc1 = toY + r;
  vec3 enc2 = toY - p;
  vec3 enc3 = toY - r;

  float u  = (first + 0.5) / resolution.x;   // texel centre of the first tap
  float du = 1.0 / resolution.x;

  float y = 0.0;    // brightness
  float ev = 0.0;   // colour from the even taps (phases 0 and 2)
  float od = 0.0;   // colour from the odd taps (phases 1 and 3)

  for (int i = 0; i < N; i++) {
    int m = i - 4 * (i / 4);   // phase of this tap, a constant once unrolled
    vec3 enc = m == 0 ? enc0 : (m == 1 ? enc1 : (m == 2 ? enc2 : enc3));

    vec3 rgb = texture2D(texture, vec2(u + float(i) * du, vertTexCoord.y)).rgb;
    float c = dot(rgb, enc);
    c = min(c + nonlin * c * c, clipHi);   // amplifier nonlinearity, then clipping

    y += c * lumaWeight[i];
    float cw = c * chromaWeight[i];
    if (m == 0) ev += cw;
    else if (m == 1) od += cw;
    else if (m == 2) ev -= cw;
    else od -= cw;
  }

  // Back from the rotated sums to the two colour components (quadrature demodulation).
  // c0 or s0 is zero, so each sum is normalised by its own taps' weights.
  float a = (c0 * ev - s0 * od) / (c0 != 0.0 ? chromaSumEven : chromaSumOdd);   // cos part
  float b = (s0 * ev + c0 * od) / (c0 != 0.0 ? chromaSumOdd : chromaSumEven);   // sin part

  y += noise * (hash(vec3(x, line, noiseSeed)) - 0.5);
  a += noise * 0.7 * (hash(vec3(line, x, noiseSeed + 11.0)) - 0.5);

  // Hue error: rotate the colour
  float ra = a * hueRotation.x - b * hueRotation.y;
  float rb = a * hueRotation.y + b * hueRotation.x;

#if PAL
  float U = rb, V = sw * ra;
  vec3 outRgb = vec3(y + 1.140 * V,
                     y - 0.395 * U - 0.581 * V,
                     y + 2.032 * U);
#else
  float I = ra, Q = rb;
  vec3 outRgb = vec3(y + 0.9563 * I + 0.6210 * Q,
                     y - 0.2721 * I - 0.6474 * Q,
                     y - 1.1070 * I + 1.7046 * Q);
#endif

  gl_FragColor = vec4(clamp(outRgb, 0.0, 1.0), 1.0);
}
