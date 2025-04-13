/*
 * Cube on Plane with Soft Shadows
 * 
 * This shader demonstrates ray marching techniques to render a cube on a checkerboard plane
 * with physically-based lighting and soft shadows. Key features include:
 * 
 * - Ray marching with signed distance functions (SDFs)
 * - Toggleable soft/hard shadows with configurable softness
 * - Physically-based lighting with proper light attenuation
 * - Blinn-Phong specular reflections
 * - Rotating light source that circles the scene
 * - ACES-inspired tone mapping for improved contrast
 * - Checkerboard floor pattern with proper shadowing
 * 
 * The shadow implementation uses ray marching from surface points toward the light source,
 * calculating penumbra based on the proximity of occluders to the shadow ray.
 * 
 * Controls:
 * - Modify USE_SOFT_SHADOWS to toggle between soft and hard shadows
 * - Adjust SHADOW_SOFTNESS to control the softness of shadow edges
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

// --- Shadow Settings ---
// Set to true for soft shadows, false for hard shadows
const bool USE_SOFT_SHADOWS = true;
// Controls the softness of shadows when USE_SOFT_SHADOWS is true
// Higher values = sharper shadows, lower values = softer shadows
const float SHADOW_SOFTNESS = 8.0;

// --- Signed Distance Functions (SDFs) ---
// SDF for a cube - returns the signed distance from point p to a cube
// Negative inside, positive outside, zero on the surface
// p: the point to calculate distance from
// center: the center position of the cube
// size: half the length of the cube's sides
float sdCube(vec3 p, vec3 center, float size) {
  // Offset p by the center of the cube
  vec3 q = abs(p - center) - vec3(size);
  // Distance to the closest point on the cube
  return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
}

// SDF for an infinite horizontal floor at y = -1
// p: the point to calculate distance from
float sdFloor(vec3 p) {
  float d = p.y + 1.; // +1 shifts the floor down to y = -1
  return d;
}

// --- Scene Composition Operations ---
// Union operation for combining two objects
// Takes two vec2 values where:
//   x component = signed distance
//   y component = material ID
// Returns the object with the smallest distance (closest to the ray)
vec2 opU(vec2 d1, vec2 d2) {
  return (d1.x < d2.x) ? d1 : d2; // the x-component is the signed distance value
}

// --- Scene Description ---
// Maps a 3D point to the closest object in the scene
// Returns vec2 where:
//   x component = signed distance to closest object
//   y component = material ID of closest object
vec2 map(vec3 p) {
  vec2 res = vec2(1e10, 0.); // Initialize with a very large distance and ID = 0
  vec2 flooring = vec2(sdFloor(p), 0.5); // Floor with ID = 0.5
  vec2 cube = vec2(sdCube(p, vec3(0, 0, 0), 1.0), 1.5); // Centered cube with ID = 1.5

  // Combine objects using union operation
  res = opU(res, flooring);
  res = opU(res, cube);
  return res; // the y-component is the ID of the object hit by the ray
}

// --- Ray Marching Implementation ---
// Marches a ray through the scene to find intersections
// ro: ray origin (camera position)
// rd: ray direction
// Returns vec2 where:
//   x component = distance traveled along ray until hit
//   y component = material ID of hit object
vec2 rayMarch(vec3 ro, vec3 rd) {
  float depth = MIN_DIST; // Start from minimum distance
  vec2 res = vec2(0.0);   // Initialize result (distance and ID)
  float id = 0.;          // Material ID of hit object
  
  // Main ray marching loop
  for(int i = 0; i < MAX_MARCHING_STEPS; i++) {
    vec3 p = ro + depth * rd; // Current position along ray
    res = map(p);             // Get distance to closest object and its ID
    depth += res.x;           // Move along ray by the safe distance
    id = res.y;               // Store the object ID
    
    // Exit conditions: hit something or went too far
    if(res.x < PRECISION || depth > MAX_DIST)
      break;
  }
  return vec2(depth, id);
}

// --- Normal Calculation ---
// Calculates the surface normal at point p using the gradient of the SDF
// This uses central differences to approximate the gradient
// p: the point to calculate normal at
// center: the center of the cube (parameter kept for consistency)
vec3 calcNormal(in vec3 p, in vec3 center) {
  const float eps = 0.0005; // Small epsilon for offset sampling
  const vec2 h = vec2(eps, 0.0);
  
  // Sample the distance field at 4 nearby points and calculate the gradient
  return normalize(vec3(
    map(p + h.xyy).x - map(p - h.xyy).x,
    map(p + h.yxy).x - map(p - h.yxy).x,
    map(p + h.yyx).x - map(p - h.yyx).x
  ));
}

// --- Shadow Calculation ---
// Calculates hard shadows (0 or 1)
// ro: ray origin (the point on the surface)
// rd: ray direction (direction to the light)
float hardShadow(vec3 ro, vec3 rd, float mint, float maxt) {
  for(float t = mint; t < maxt;) {
    vec3 p = ro + rd * t;
    float h = map(p).x;
    if(h < PRECISION)
      return 0.0; // In shadow
    t += h;
  }
  return 1.0; // Not in shadow
}

// --- Soft Shadow Calculation ---
// Calculates soft shadows with penumbra
// ro: ray origin (the point on the surface)
// rd: ray direction (direction to the light)
// k: controls the softness of the shadow (higher = sharper shadow edges)
float softShadow(vec3 ro, vec3 rd, float mint, float maxt, float k) {
  float res = 1.0;
  float t = mint;
  
  for(int i = 0; i < 64; i++) {
    if(t >= maxt) break;
    
    vec3 p = ro + rd * t;
    float h = map(p).x;
    
    if(h < PRECISION)
      return 0.0; // Complete shadow
    
    // This is the key part of soft shadows:
    // The ratio h/t represents the "angle" to the potential occluder
    // Smaller h/t means the ray passes closer to an object
    // k controls how quickly the shadow value drops off with angle
    res = min(res, k * h / t);
    
    t += h;
  }
  
  return res;
}

// --- Rendering Function ---
// Calculates the color for a ray based on intersection and lighting
// ro: ray origin (camera position)
// rd: ray direction
vec3 render(vec3 ro, vec3 rd) {
  vec3 col = COLOR_BACKGROUND; // Default to background color
  
  // Perform ray marching to find intersection
  vec2 res = rayMarch(ro, rd);
  float d = res.x; // Distance traveled along ray
  
  // If ray didn't hit anything (went beyond MAX_DIST), return background color
  if(d > MAX_DIST)
    return col;
    
  float id = res.y; // Material ID of hit object
  vec3 p = ro + rd * d; // Intersection point in 3D space
  
  // Get the center for normal calculation (only matters for cubes)
  vec3 center = vec3(0, 0, 0); // Cube center
  vec3 normal = calcNormal(p, center); // Surface normal at intersection
  
  // --- Lighting Calculation ---
  // Rotating point light source
  float lightAngle = iTime * 0.5; // Control rotation speed with the multiplier
  float lightRadius = 3.0; // Distance from origin
  float lightHeight = 3.0; // Height above the plane
  vec3 lightPosition = vec3(
    lightRadius * cos(lightAngle), // X position rotates with time
    lightHeight,                   // Fixed height
    lightRadius * sin(lightAngle)  // Z position rotates with time
  );
  vec3 lightDirection = normalize(lightPosition - p);
  
  // Calculate distance to light for attenuation
  float lightDistance = length(lightPosition - p);
  
  // Light attenuation (falloff with distance)
  // Using inverse square law: intensity ∝ 1/distance²
  float lightAttenuation = 1.0 / (1.0 + 0.1 * lightDistance + 0.01 * lightDistance * lightDistance);
  
  // Base ambient lighting (different for floor and cube)
  float ambient = 0.1;
  
  // Diffuse lighting (Lambert)
  float diffuse = max(dot(normal, lightDirection), 0.0);
  
  // Specular lighting (Blinn-Phong)
  vec3 viewDirection = normalize(ro - p);
  vec3 halfwayDirection = normalize(lightDirection + viewDirection);
  float specularPower = (id < 1.0) ? 32.0 : 16.0; // Higher for floor (more shiny)
  float specular = pow(max(dot(normal, halfwayDirection), 0.0), specularPower);
  
  // Shadow calculation
  // Offset the origin slightly to avoid self-shadowing
  vec3 shadowRayOrigin = p + normal * 0.01;
  
  // Calculate shadow (1.0 = fully lit, 0.0 = fully in shadow)
  float shadow;
  if (USE_SOFT_SHADOWS) {
    shadow = softShadow(shadowRayOrigin, lightDirection, 0.1, 10.0, SHADOW_SOFTNESS);
  } else {
    shadow = hardShadow(shadowRayOrigin, lightDirection, 0.1, 10.0);
  }
  
  // Material properties
  vec3 materialColor;
  float materialShininess;
  
  if(id < 1.) {
    // Floor with checkerboard pattern - increased contrast
    materialColor = vec3(0.95) * (0.3 + 0.7 * mod(floor(p.x) + floor(p.z), 2.0));
    materialShininess = 0.08; // Slightly increased specular for floor
  } else {
    // Cube with blue color
    materialColor = vec3(0.2, 0.4, 0.8);
    materialShininess = 0.6; // Higher specular for cube
  }
  
  // Combine lighting components
  vec3 ambientComponent = ambient * materialColor;
  vec3 diffuseComponent = diffuse * materialColor * lightAttenuation * shadow;
  vec3 specularComponent = specular * vec3(1.0) * materialShininess * lightAttenuation * shadow;
  
  // Final color
  col = ambientComponent + diffuseComponent + specularComponent;
  
  // Add a subtle environmental lighting
  col += COLOR_BACKGROUND * 0.02; // Reduced environmental contribution
  
  // Apply contrast enhancement
  col = pow(col, vec3(1.1)); // Increase contrast by applying a power function
  
  // Apply improved tone mapping (ACES-inspired)
  // This gives better contrast than the simple Reinhard operator
  const float tm_a = 2.51;
  const float tm_b = 0.03;
  const float tm_c = 2.43;
  const float tm_d = 0.59;
  const float tm_e = 0.14;
  col = (col * (tm_a * col + tm_b)) / (col * (tm_c * col + tm_d) + tm_e);
  
  // Gamma correction with slightly lower gamma for more contrast
  col = pow(col, vec3(1.0/2.1)); // Standard is 2.2, using 2.1 for slightly higher contrast
  
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
  vec3 ro = vec3(0, 2, 6); // Ray origin (camera position) - moved back and up
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