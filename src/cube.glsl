/*
 * Cube on Checkerboard Shader with Camera Rotation and Soft Shadows
 * 
 * This shader renders a cube on a checkerboard pattern using ray marching,
 * with physically-based lighting and soft shadows. It demonstrates:
 * 
 * - Ray marching with signed distance functions (SDFs)
 * - Toggleable soft/hard shadows with configurable softness
 * - Physically-based lighting with proper light attenuation
 * - Blinn-Phong specular reflections
 * - Rotating light source that circles the scene
 * - ACES-inspired tone mapping for improved contrast
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
 * not in the Common tab. That's why we keep mouse_dragging in the Buffer A tab
 * and pass the light position through a special pixel.
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
// Object colors
const vec3 COLOR_DARK = vec3(0.1);
const vec3 COLOR_LIGHT = vec3(0.9);
const vec3 COLOR_CUBE = vec3(0.2, 0.4, 0.8); // Blue cube

// --- Shadow Settings ---
// Set to true for soft shadows, false for hard shadows
const bool USE_SOFT_SHADOWS = true;
// Controls the softness of shadows when USE_SOFT_SHADOWS is true
// Higher values = sharper shadows, lower values = softer shadows
const float SHADOW_SOFTNESS = 8.0;

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

// Union operation for combining two objects with material IDs
// Takes two vec2 values where:
//   x component = signed distance
//   y component = material ID
// Returns the object with the smallest distance (closest to the ray)
vec2 opU(vec2 d1, vec2 d2) {
  return (d1.x < d2.x) ? d1 : d2;
}

// --- Scene Description ---
// Maps a 3D point to the closest object in the scene
// Returns a vec2 where:
//   x component = signed distance to closest object
//   y component = material ID (0.5 = floor, 1.5 = cube)
vec2 map(vec3 p) {
  vec2 res = vec2(1e10, 0.); // Initialize with a very large distance and ID = 0
  vec2 flooring = vec2(sdFloor(p), 0.5); // Floor with ID = 0.5
  vec2 cube = vec2(sdCube(p, vec3(0.0, 0.0, 0.0), 1.0), 1.5); // Cube with ID = 1.5
  
  // Combine objects using union operation
  res = opU(res, flooring);
  res = opU(res, cube);
  return res;
}

// --- Ray Marching Implementation ---
// Marches a ray through the scene to find intersections
// ro: ray origin (camera position)
// rd: ray direction
// Returns a vec2 where:
//   x component = distance traveled along ray until hit
//   y component = material ID of hit object
vec2 rayMarch(vec3 ro, vec3 rd) {
  float depth = MIN_DIST;
  vec2 res = vec2(0.0);
  
  // Main ray marching loop
  for(int i = 0; i < MAX_MARCHING_STEPS; i++) {
    vec3 p = ro + depth * rd;
    vec2 result = map(p);
    float dist = result.x;
    
    // If we're very close to the surface, consider it a hit
    if(dist < PRECISION) {
      res = vec2(depth, result.y);
      break;
    }
    
    // Move along the ray by the safe distance
    depth += dist;
    
    // If we've gone too far, consider it a miss
    if(depth > MAX_DIST) {
      res = vec2(MAX_DIST, -1.0);
      break;
    }
  }
  
  return res;
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

// --- Shadow Calculation ---
// Calculates hard shadows (0 or 1)
// ro: ray origin (the point on the surface)
// rd: ray direction (direction to the light)
float hardShadow(vec3 ro, vec3 rd, float mint, float maxt) {
  for(float t = mint; t < maxt;) {
    vec3 p = ro + rd * t;
    float h = map(p).x;
    
    if(h < PRECISION) {
      return 0.0; // In shadow
    }
    
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
  float res = 1.0; // Start with full light
  
  for(float t = mint; t < maxt;) {
    vec3 p = ro + rd * t;
    float h = map(p).x;
    
    // If we hit something, we're completely in shadow
    if(h < PRECISION) {
      return 0.0; // Complete shadow
    }
    
    // This is the key part of soft shadows:
    // The closer the ray gets to an object, the darker the shadow
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
// lightPosition: position of the light source
vec3 render(vec3 ro, vec3 rd, vec3 lightPosition) {
  // Default to background color
  vec3 col = COLOR_BACKGROUND;
  
  // Perform ray marching to find intersection
  vec2 res = rayMarch(ro, rd);
  float depth = res.x;
  float id = res.y;
  
  // If we hit something (didn't reach MAX_DIST)
  if(depth < MAX_DIST) {
    // Calculate the 3D point of intersection
    vec3 p = ro + rd * depth;
    
    // Calculate surface normal at intersection point
    vec3 normal = calcNormal(p);
    
    // --- Lighting Calculation ---
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
    
    if(id < 1.0) {
      // Floor with checkerboard pattern - increased contrast
      if(mod(floor(p.x) + floor(p.z), 2.0) < 1.0) {
        materialColor = COLOR_DARK;
      } else {
        materialColor = COLOR_LIGHT;
      }
      materialShininess = 0.08; // Slightly increased specular for floor
    } else {
      // Cube with blue color
      materialColor = COLOR_CUBE;
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
  
  // Special pixel to store light position
  if (length(uv - vec2(0.0, 1.0)) < PRADIUS) {
    // Calculate rotating light position
    float lightAngle = iTime * 0.5; // Light rotates around the scene
    float lightRadius = 3.0; // Distance from origin
    float lightHeight = 3.0; // Height above the plane
    
    // Normalize to 0-1 range for storage
    vec3 lightPosition = vec3(
      lightRadius * cos(lightAngle), // X position rotates with time
      lightHeight,                   // Fixed height
      lightRadius * sin(lightAngle)  // Z position rotates with time
    );
    
    // Store light position (normalized to 0-1 range)
    fragColor = vec4((lightPosition + vec3(lightRadius, lightHeight, lightRadius)) / 
                     (2.0 * vec3(lightRadius, lightHeight, lightRadius)), 1.0);
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
  
  // Get light position from special pixel
  vec4 lightData = texture(iChannel0, vec2(0.0, 1.0) - du);
  
  // Convert light position back from 0-1 range to world space
  float lightRadius = 3.0;
  float lightHeight = 3.0;
  vec3 lightPosition = lightData.xyz * (2.0 * vec3(lightRadius, lightHeight, lightRadius)) - 
                      vec3(lightRadius, lightHeight, lightRadius);
  
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
  vec3 col = render(ro, rd, lightPosition);
  
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