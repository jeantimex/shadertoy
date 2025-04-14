/*
 * Rain and Water Effects Shader
 * 
 * This shader creates realistic rain and water effects on a surface, including:
 * - Animated raindrops with proper physics
 * - Water ripples that spread and interact
 * - Realistic refraction and reflection
 * - Dynamic droplet trails
 * 
 * Based on the RainEffect repository by Codrops
 * https://github.com/codrops/RainEffect
 * 
 * Buffer A: Raindrop simulation
 * Buffer B: Water ripple physics
 * Buffer C: Normal map generation
 * Buffer D: Final composition
 */

// --- Constants ---
const float PI = 3.14159265359;
const float EPSILON = 0.001;

// --- Rain Settings ---
const float DROP_RATE = 0.5;      // Rate of raindrop generation
const float DROP_SIZE = 0.3;      // Size of raindrops
const float TRAIL_RATE = 0.8;     // Rate of trail formation
const float MIN_DROP_SIZE = 0.1;  // Minimum size of raindrops
const float MAX_DROP_SIZE = 0.4;  // Maximum size of raindrops

// --- Water Settings ---
const float RIPPLE_SPEED = 0.5;   // Speed of ripple propagation
const float DAMPING = 0.98;       // Damping factor for ripples
const float NORMAL_STRENGTH = 1.0; // Strength of normal map effect
const float REFRACTION = 0.1;     // Strength of refraction effect

// --- Random Functions ---
float hash(float n) {
    return fract(sin(n) * 43758.5453123);
}

vec2 hash2(float n) {
    return fract(sin(vec2(n, n + 1.0)) * vec2(43758.5453123, 22578.1459123));
}

float random(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// --- Raindrop Functions ---
float sdCircle(vec2 p, float r) {
    return length(p) - r;
}

vec2 raindrop(vec2 uv, vec2 pos, float size) {
    vec2 p = uv - pos;
    float d = sdCircle(p, size);
    
    // Add trail effect
    float trail = smoothstep(0.0, size * 2.0, p.y) * smoothstep(size * 3.0, size * 2.0, p.y);
    d = min(d, (length(p * vec2(1.0, 4.0)) - size * 0.5) * trail);
    
    return vec2(smoothstep(0.0, EPSILON, d), trail);
}

// --- Buffer A: Raindrop Simulation ---
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec2 texel = 1.0 / iResolution.xy;
    
    // Read previous state
    vec4 previous = texture(iChannel0, uv);
    
    // Initialize or update raindrops
    float time = iTime * DROP_RATE;
    vec2 seed = floor(vec2(time));
    vec2 dropPos = hash2(seed.x);
    float dropSize = mix(MIN_DROP_SIZE, MAX_DROP_SIZE, hash(seed.y));
    
    // Generate new raindrop
    vec2 drop = raindrop(uv, dropPos, dropSize);
    
    // Combine with previous state
    vec2 velocity = previous.zw;
    velocity.y -= 0.1 * texel.y; // Gravity
    velocity *= 0.98; // Damping
    
    vec2 pos = previous.xy + velocity;
    
    // Add new drop if needed
    if (drop.x < 0.5) {
        pos = dropPos;
        velocity = vec2(0.0, -0.05);
    }
    
    // Output: xy = position, zw = velocity
    fragColor = vec4(pos, velocity);
}

// --- Buffer B: Water Ripple Physics ---
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec2 texel = 1.0 / iResolution.xy;
    
    // Sample neighboring pixels
    vec4 center = texture(iChannel1, uv);
    vec4 left = texture(iChannel1, uv - vec2(texel.x, 0.0));
    vec4 right = texture(iChannel1, uv + vec2(texel.x, 0.0));
    vec4 top = texture(iChannel1, uv - vec2(0.0, texel.y));
    vec4 bottom = texture(iChannel1, uv + vec2(0.0, texel.y));
    
    // Calculate wave propagation
    float height = center.x;
    float velocity = center.y;
    
    // Simple wave equation
    float acceleration = (left.x + right.x + top.x + bottom.x - 4.0 * height) * RIPPLE_SPEED;
    velocity = velocity * DAMPING + acceleration;
    height += velocity;
    
    // Add raindrop impacts from Buffer A
    vec4 drop = texture(iChannel0, uv);
    if (drop.x > 0.5) {
        height += 1.0;
        velocity = 0.0;
    }
    
    fragColor = vec4(height, velocity, 0.0, 1.0);
}

// --- Buffer C: Normal Map Generation ---
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec2 texel = 1.0 / iResolution.xy;
    
    // Sample heights from Buffer B
    float left = texture(iChannel1, uv - vec2(texel.x, 0.0)).x;
    float right = texture(iChannel1, uv + vec2(texel.x, 0.0)).x;
    float top = texture(iChannel1, uv - vec2(0.0, texel.y)).x;
    float bottom = texture(iChannel1, uv + vec2(0.0, texel.y)).x;
    
    // Calculate normal from height field
    vec3 normal = normalize(vec3(
        (left - right) * NORMAL_STRENGTH,
        (bottom - top) * NORMAL_STRENGTH,
        2.0
    ));
    
    // Output normal map
    fragColor = vec4(normal * 0.5 + 0.5, 1.0);
}

// --- Buffer D: Final Composition ---
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    
    // Sample normal map
    vec3 normal = texture(iChannel2, uv).xyz * 2.0 - 1.0;
    
    // Sample background image with refraction
    vec2 refractedUV = uv + normal.xy * REFRACTION;
    vec4 background = texture(iChannel3, refractedUV);
    
    // Add specular highlights
    vec3 lightDir = normalize(vec3(1.0, 1.0, -1.0));
    float specular = pow(max(dot(normal, lightDir), 0.0), 32.0);
    
    // Add fresnel effect
    float fresnel = pow(1.0 - max(dot(normal, vec3(0.0, 0.0, 1.0)), 0.0), 5.0);
    
    // Combine effects
    vec3 color = background.rgb;
    color += specular * 0.5;
    color = mix(color, vec3(1.0), fresnel * 0.3);
    
    fragColor = vec4(color, 1.0);
}

// --- Main Image: Active Buffer ---
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    // This is Buffer A by default
    // Uncomment the appropriate buffer code above and comment out others to switch between buffers
    vec2 uv = fragCoord / iResolution.xy;
    vec2 texel = 1.0 / iResolution.xy;
    
    // Read previous state
    vec4 previous = texture(iChannel0, uv);
    
    // Initialize or update raindrops
    float time = iTime * DROP_RATE;
    vec2 seed = floor(vec2(time));
    vec2 dropPos = hash2(seed.x);
    float dropSize = mix(MIN_DROP_SIZE, MAX_DROP_SIZE, hash(seed.y));
    
    // Generate new raindrop
    vec2 drop = raindrop(uv, dropPos, dropSize);
    
    // Combine with previous state
    vec2 velocity = previous.zw;
    velocity.y -= 0.1 * texel.y; // Gravity
    velocity *= 0.98; // Damping
    
    vec2 pos = previous.xy + velocity;
    
    // Add new drop if needed
    if (drop.x < 0.5) {
        pos = dropPos;
        velocity = vec2(0.0, -0.05);
    }
    
    // Output: xy = position, zw = velocity
    fragColor = vec4(pos, velocity);
}