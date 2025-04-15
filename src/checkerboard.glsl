/*
 * Simple Checkerboard Shader with Camera Rotation
 * 
 * This shader renders a basic infinite checkerboard pattern using ray marching.
 * It demonstrates a minimal implementation without lighting or shadows.
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
 * not in the Common tab.
 */

// -------------------------------------------------------
// Common Tab - Paste this in both Buffer A and Image tabs
// -------------------------------------------------------
// Only constants needed by both Buffer A and Image
const float PI = 3.14159265359;
const float EPSILON = 1.0e-3;
const float PRADIUS = 0.01; // Small radius for special pixels

// -------------------------------------------------------
// Buffer A Tab - Paste this in Buffer A tab only
// -------------------------------------------------------
// This buffer is used only for persistent data storage between frames

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
  
  // For all other pixels, just pass through previous frame's data
  fragColor = texture(iChannel0, uv);
}

// -------------------------------------------------------
// Image Tab - Paste this in Image tab only
// -------------------------------------------------------
// --- Ray Marching Constants ---
const int MAX_MARCHING_STEPS = 100; // Reduced from 255 since we only have a plane
const float MIN_DIST = 0.0;
const float MAX_DIST = 100.0;
const float PRECISION = 0.001;
const vec3 COLOR_BACKGROUND = vec3(0.835, 1, 1);
const vec3 COLOR_DARK = vec3(0.1);
const vec3 COLOR_LIGHT = vec3(0.9);

// --- Signed Distance Functions (SDFs) ---
// SDF for an infinite horizontal floor at y = -1
float sdFloor(vec3 p) {
  return p.y + 1.0; // +1 shifts the floor down to y = -1
}

// --- Scene Description ---
// Maps a 3D point to the closest object in the scene
float map(vec3 p) {
  return sdFloor(p);
}

// --- Ray Marching Implementation ---
// Simplified ray marching that only looks for floor intersection
vec3 rayMarchFloor(vec3 ro, vec3 rd) {
  // For a ray hitting a horizontal plane at y = -1, we can solve directly:
  // ro.y + t * rd.y = -1
  // t = (-1 - ro.y) / rd.y
  
  // Check if ray is parallel to the floor or pointing up
  if (rd.y >= 0.0) {
    return vec3(MAX_DIST); // No intersection
  }
  
  // Calculate intersection distance
  float t = (-1.0 - ro.y) / rd.y;
  
  // Check if intersection is too close or too far
  if (t < MIN_DIST || t > MAX_DIST) {
    return vec3(MAX_DIST); // Out of range
  }
  
  // Return the intersection point
  return ro + rd * t;
}

// --- Rendering Function ---
// Calculates the color for a given ray.
vec3 render(vec3 ro, vec3 rd) {
  // Default to background color
  vec3 col = COLOR_BACKGROUND;
  
  // Get intersection point with floor
  vec3 p = rayMarchFloor(ro, rd);
  
  // If we hit the floor (didn't reach MAX_DIST)
  if (p.x < MAX_DIST) {
    // Checkerboard pattern with antialiasing using sine waves and fwidth
    float s = sin(PI * p.x) * sin(PI * p.z);
    
    // Get the width of s across a pixel to determine smoothing amount
    float fw = fwidth(s);
    
    // Smoothly mix between colors based on 's' and its derivative (fw).
    float checker = smoothstep(1.0, -1.0, s / fw);
    
    // Mix between dark and light colors
    col = mix(COLOR_DARK, COLOR_LIGHT, checker);
  }
  
  return col;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
  // Get rotation angle from special pixel in Buffer A
  vec2 du = vec2(1.0, 1.0) / iResolution.xy;
  vec4 rot = 2.0 * texture(iChannel0, vec2(1.0, 1.0) - du) - 1.0;
  float rotationAngle = rot.x;
  
  // Convert pixel coordinates to normalized device coordinates (-1 to 1)
  vec2 ndc = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
  
  // Calculate camera position with rotation
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