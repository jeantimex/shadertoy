/*
 * Cube on Checkerboard Shader with Camera Rotation
 * 
 * This shader renders a cube on a checkerboard pattern using ray marching.
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
const int MAX_MARCHING_STEPS = 100;
// Minimum distance to start ray marching from
const float MIN_DIST = 0.0;
// Maximum distance to consider when ray marching (beyond this is considered a miss)
const float MAX_DIST = 100.0;
// Precision threshold for considering a hit (when distance < PRECISION)
const float PRECISION = 0.001;
// Default background color for rays that don't hit any object
const vec3 COLOR_BACKGROUND = vec3(0.835, 1, 1);
// Object colors
const vec3 COLOR_DARK = vec3(0.1);
const vec3 COLOR_LIGHT = vec3(0.9);
const vec3 COLOR_CUBE = vec3(0.2, 0.4, 0.8); // Blue cube

// --- Signed Distance Functions (SDFs) ---
// SDF for an infinite horizontal floor at y = -1
// p: the point to calculate distance from
float sdFloor(vec3 p) {
  return p.y + 1.0; // +1 shifts the floor down to y = -1
}

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

// --- Scene Composition Operations ---
// Union operation for combining two objects
// Takes two distances and returns the smallest one
float opUnion(float d1, float d2) {
  return min(d1, d2);
}

// --- Scene Description ---
// Maps a 3D point to the closest object in the scene
// Returns a vec2 where:
//   x component = signed distance to closest object
//   y component = material ID (0 = floor, 1 = cube)
vec2 map(vec3 p) {
  // Floor with ID = 0
  float floorDist = sdFloor(p);
  vec2 floor = vec2(floorDist, 0.0);
  
  // Cube with ID = 1
  float cubeDist = sdCube(p, vec3(0.0, 0.0, 0.0), 1.0);
  vec2 cube = vec2(cubeDist, 1.0);
  
  // Return the closest object
  return (floor.x < cube.x) ? floor : cube;
}

// --- Ray Marching Implementation ---
// Marches a ray through the scene to find intersections
// ro: ray origin (camera position)
// rd: ray direction
// Returns a vec3 where:
//   x component = distance traveled along ray until hit
//   y component = material ID of hit object
//   z component = 0 (unused)
vec3 rayMarch(vec3 ro, vec3 rd) {
  float depth = MIN_DIST;
  float materialID = -1.0;
  
  // Main ray marching loop
  for(int i = 0; i < MAX_MARCHING_STEPS; i++) {
    vec3 p = ro + depth * rd;
    vec2 result = map(p);
    float dist = result.x;
    
    // If we're very close to the surface, consider it a hit
    if(dist < PRECISION) {
      materialID = result.y;
      break;
    }
    
    // Move along the ray by the safe distance
    depth += dist;
    
    // If we've gone too far, consider it a miss
    if(depth > MAX_DIST) {
      break;
    }
  }
  
  return vec3(depth, materialID, 0.0);
}

// Calculate surface normal at point p
vec3 calcNormal(vec3 p) {
  const float h = 0.0001; // Small step for numerical differentiation
  vec2 k = vec2(1.0, -1.0);
  return normalize(
    k.xyy * map(p + k.xyy * h).x +
    k.yxy * map(p + k.yxy * h).x +
    k.yyx * map(p + k.yyx * h).x +
    k.xxx * map(p + k.xxx * h).x
  );
}

// --- Rendering Function ---
// Calculates the color for a ray based on intersection
// ro: ray origin (camera position)
// rd: ray direction
vec3 render(vec3 ro, vec3 rd) {
  // Default to background color
  vec3 col = COLOR_BACKGROUND;
  
  // Perform ray marching to find intersection
  vec3 result = rayMarch(ro, rd);
  float depth = result.x;
  float materialID = result.y;
  
  // If we hit something (didn't reach MAX_DIST)
  if(depth < MAX_DIST) {
    // Calculate the 3D point of intersection
    vec3 p = ro + rd * depth;
    
    // Calculate surface normal at intersection point
    vec3 normal = calcNormal(p);
    
    // Simple lighting
    vec3 lightDir = normalize(vec3(1.0, 1.0, 1.0));
    float diffuse = max(dot(normal, lightDir), 0.2); // Add some ambient
    
    // Determine color based on material ID
    if(materialID < 0.5) {
      // Floor with checkerboard pattern
      if(mod(floor(p.x) + floor(p.z), 2.0) < 1.0) {
        col = COLOR_DARK * diffuse;
      } else {
        col = COLOR_LIGHT * diffuse;
      }
    } else {
      // Cube
      col = COLOR_CUBE * diffuse;
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
  // Using the same initial position as cube_on_plane_with_shadow.glsl
  float cameraDistance = 6.0;
  float cameraHeight = 2.0;
  vec3 ro = vec3(
    cameraDistance * sin(rotationAngle),
    cameraHeight, // Height
    cameraDistance * cos(rotationAngle)
  );
  
  // Use the same lookAt point as cube_on_plane_with_shadow.glsl
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