/*
 * Simple Checkerboard Shader with Camera Rotation
 * 
 * This shader renders a basic infinite checkerboard pattern using ray marching.
 * It demonstrates a minimal implementation without complex lighting or shadows.
 * 
 * Controls:
 * - Click and drag horizontally to rotate the camera around the scene
 * 
 * Setup Instructions:
 * 1. In ShaderToy, create a new shader
 * 2. Add a Buffer A (click + button next to Buffers)
 * 3. Set Buffer A's resolution to match the main resolution
 * 4. Paste the Common code in both tabs (only constants and functions)
 * 5. Paste the Buffer A code in the Buffer A tab
 * 6. Paste the Image code in the Image tab
 * 7. In the Image tab, set iChannel0 to Buffer A
 * 
 * Note: ShaderToy uniforms like iResolution are only available in the shader tabs,
 * not in the Common tab. That's why we keep mouse_dragging in the Buffer A tab.
 */

// -------------------------------------------------------
// Common Tab - Paste this in both Buffer A and Image tabs
// -------------------------------------------------------
const float PI = 3.14159265359;
const float EPSILON = 1.0e-3;
const float PRADIUS = 0.01; // Small radius for special pixels

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

// -------------------------------------------------------
// Buffer A Tab - Paste this in Buffer A tab only
// -------------------------------------------------------
// Mouse dragging detection - returns true if mouse is being dragged
// Also outputs the displacement since last frame
bool mouse_dragging(out vec2 disp) {
  vec2 du = vec2(1.0, 1.0) / iResolution.xy;
  vec4 p_mouse = 2.0 * texture(iChannel0, du) - 1.0;
  vec4 mouse = iMouse / iResolution.xyxy;
  disp = mouse.xy - p_mouse.xy;
  return p_mouse.z > 0.0 && mouse.z > 0.0;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
  vec2 uv = fragCoord / iResolution.xy;
  
  // Special pixel to store mouse state
  if (length(uv) < PRADIUS) {
    // Store normalized mouse position (0 to 1 range)
    fragColor = (iMouse / iResolution.xyxy + 1.0) / 2.0;
    return;
  }
  
  // First Frame
  if (iFrame == 0) {
    fragColor = vec4(0.0, 0.0, 0.0, 1.0);
    return;
  }
  
  // Special pixel to store rotation angle
  if (length(uv - vec2(1.0, 1.0)) < PRADIUS) {
    // Get previous rotation
    vec2 du = vec2(1.0, 1.0) / iResolution.xy;
    vec4 rot = 2.0 * texture(iChannel0, vec2(1.0, 1.0) - du) - 1.0;
    
    // Check for mouse dragging
    vec2 dm;
    bool drag = mouse_dragging(dm);
    
    // Update rotation based on drag
    if (drag && length(dm) > EPSILON) {
      // Use horizontal movement for rotation around y-axis
      rot.x += dm.x * 3.0;
      
      // Keep rotation within bounds
      if (rot.x > PI) rot.x -= 2.0 * PI;
      if (rot.x < -PI) rot.x += 2.0 * PI;
    }
    
    // Store rotation for next frame
    fragColor = (rot + 1.0) / 2.0;
    return;
  }
  
  // For all other pixels, render the scene normally
  // Convert pixel coordinates to normalized device coordinates (-1 to 1)
  // Centered at origin and adjusted for aspect ratio
  vec2 ndc = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
  
  // Get rotation angle from special pixel
  vec2 du = vec2(1.0, 1.0) / iResolution.xy;
  vec4 rot = 2.0 * texture(iChannel0, vec2(1.0, 1.0) - du) - 1.0;
  float rotationAngle = rot.x;
  
  // Calculate camera position with rotation
  float cameraDistance = 6.0;
  vec3 ro = vec3(
    cameraDistance * sin(rotationAngle),
    2.0, // Height
    cameraDistance * cos(rotationAngle)
  );
  
  // Look at the center of the scene
  vec3 lookAt = vec3(0, -0.5, 0);
  vec3 forward = normalize(lookAt - ro);
  vec3 right = normalize(cross(vec3(0, 1, 0), forward));
  vec3 up = cross(forward, right);
  vec3 rd = normalize(forward + ndc.x * right + ndc.y * up);
  
  // Render the scene for this ray
  vec3 col = render(ro, rd);
  
  // Output color
  fragColor = vec4(col, 1.0);
}

// -------------------------------------------------------
// Image Tab - Paste this in Image tab only
// -------------------------------------------------------
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
  // Simply display the rendered result from Buffer A
  vec2 uv = fragCoord / iResolution.xy;
  fragColor = texture(iChannel0, uv);
}