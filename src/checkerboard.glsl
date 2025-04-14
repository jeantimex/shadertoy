/*
 * Simple Checkerboard Shader
 * 
 * This shader renders a basic infinite checkerboard pattern using ray marching.
 * It demonstrates a minimal implementation without complex lighting or shadows.
 */
 
// --- Ray Marching Constants ---
// Maximum number of steps to take when ray marching before giving up
const int MAX_MARCHING_STEPS = 255;
// Minimum distance to start ray marching from
const float MIN_DIST = 0.0;
// Maximum distance to consider when ray marching (beyond this is considered a miss)
const float MAX_DIST = 100.0;
// Precision threshold for considering a hit (when distance < PRECISION)
const float PRECISION = 0.001;
// Default background color for rays that don't hit any object
const vec3 COLOR_BACKGROUND = vec3(0.835, 1, 1);

// --- Signed Distance Functions (SDFs) ---
// SDF for an infinite horizontal floor at y = -1
// p: the point to calculate distance from
float sdFloor(vec3 p) {
  float d = p.y + 1.; // +1 shifts the floor down to y = -1
  return d;
}

// --- Scene Description ---
// Maps a 3D point to the closest object in the scene
// Returns the signed distance to the closest object
float map(vec3 p) {
  return sdFloor(p);
}

// --- Ray Marching Implementation ---
// Marches a ray through the scene to find intersections
// ro: ray origin (camera position)
// rd: ray direction
// Returns distance traveled along ray until hit
float rayMarch(vec3 ro, vec3 rd) {
  float depth = MIN_DIST; // Start from minimum distance
  
  // Main ray marching loop
  for(int i = 0; i < MAX_MARCHING_STEPS; i++) {
    vec3 p = ro + depth * rd;
    float dist = map(p);
    
    // If we're very close to the surface, consider it a hit
    if(dist < PRECISION) {
      return depth;
    }
    
    // Move along the ray by the safe distance
    depth += dist;
    
    // If we've gone too far, consider it a miss
    if(depth > MAX_DIST) {
      return MAX_DIST;
    }
  }
  
  // If we've used all steps and still haven't hit anything
  return MAX_DIST;
}

// Calculate surface normal at point p
vec3 calcNormal(vec3 p) {
  const float h = 0.0001; // Small step for numerical differentiation
  vec3 n = vec3(
    map(p + vec3(h, 0, 0)) - map(p - vec3(h, 0, 0)),
    map(p + vec3(0, h, 0)) - map(p - vec3(0, h, 0)),
    map(p + vec3(0, 0, h)) - map(p - vec3(0, 0, h))
  );
  return normalize(n);
}

// --- Rendering Function ---
// Calculates the color for a ray based on intersection
// ro: ray origin (camera position)
// rd: ray direction
vec3 render(vec3 ro, vec3 rd) {
  vec3 col = COLOR_BACKGROUND; // Default to background color
  
  // Perform ray marching to find intersection
  float d = rayMarch(ro, rd);
  
  // If we hit something (didn't reach MAX_DIST)
  if(d < MAX_DIST) {
    // Calculate the 3D point of intersection
    vec3 p = ro + rd * d;
    
    // Calculate surface normal at intersection point
    vec3 normal = calcNormal(p);
    
    // Checkerboard pattern
    // Create high contrast black and white squares
    if(mod(floor(p.x) + floor(p.z), 2.0) < 1.0) {
      col = vec3(0.1); // Dark squares
    } else {
      col = vec3(0.9); // Light squares
    }
  }
  
  return col;
}

// --- Main Entry Point ---
// ShaderToy entry point - called for each pixel
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
  // Convert pixel coordinates to normalized device coordinates (-1 to 1)
  // Centered at origin and adjusted for aspect ratio
  vec2 uv = (fragCoord - .5 * iResolution.xy) / iResolution.y;
  
  // --- Camera Setup ---
  // Position the camera higher and further back to see more of the scene
  vec3 ro = vec3(0, 2, 6); // Ray origin (camera position)
  // Look slightly downward toward the scene
  vec3 lookAt = vec3(0, -0.5, 0);
  vec3 forward = normalize(lookAt - ro);
  vec3 right = normalize(cross(vec3(0, 1, 0), forward));
  vec3 up = cross(forward, right);
  vec3 rd = normalize(forward + uv.x * right + uv.y * up);
  
  // Render the scene for this ray
  vec3 col = render(ro, rd);
  
  // Output final color to screen
  fragColor = vec4(col, 1.0);
}