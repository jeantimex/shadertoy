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
 * not in the Common tab.
 */

// -------------------------------------------------------
// Common Tab - Paste this in both Buffer A and Image tabs
// -------------------------------------------------------
const float PI = 3.14159265359;
const float EPSILON = 1.0e-3;
const float PRADIUS = 0.01; // Small radius for special pixels

// -------------------------------------------------------
// Buffer A Tab - Paste this in Buffer A tab only
// -------------------------------------------------------
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
    vec2 du = vec2(1.0, 1.0) / iResolution.xy;
    vec4 rot = 2.0 * texture(iChannel0, vec2(1.0, 1.0) - du) - 1.0;
    
    vec2 dm;
    bool drag = mouse_dragging(dm);
    
    if (drag && length(dm) > EPSILON) {
      rot.x += dm.x * 3.0;
      
      if (rot.x > PI) rot.x -= 2.0 * PI;
      if (rot.x < -PI) rot.x += 2.0 * PI;
    }
    
    fragColor = (rot + 1.0) / 2.0;
    return;
  }
  
  // Special pixel to store light position
  if (length(uv - vec2(0.0, 1.0)) < PRADIUS) {
    float lightAngle = iTime * 0.5;
    float lightRadius = 3.0;
    float lightHeight = 3.0;
    
    vec3 lightPosition = vec3(
      lightRadius * cos(lightAngle),
      lightHeight,
      lightRadius * sin(lightAngle)
    );
    
    fragColor = vec4((lightPosition + vec3(lightRadius, lightHeight, lightRadius)) / 
                     (2.0 * vec3(lightRadius, lightHeight, lightRadius)), 1.0);
    return;
  }
  
  fragColor = texture(iChannel0, uv);
}

// -------------------------------------------------------
// Image Tab - Paste this in Image tab only
// -------------------------------------------------------
const int MAX_MARCHING_STEPS = 255;
const float MIN_DIST = 0.0;
const float MAX_DIST = 100.0;
const float PRECISION = 0.001;
const vec3 COLOR_BACKGROUND = vec3(0.835, 1, 1);
const vec3 COLOR_DARK = vec3(0.1);
const vec3 COLOR_LIGHT = vec3(0.9);
const vec3 COLOR_CUBE = vec3(0.2, 0.4, 0.8);
const bool USE_SOFT_SHADOWS = true;
const float SHADOW_SOFTNESS = 8.0;

float sdFloor(vec3 p) {
  return p.y + 1.0;
}

float sdCube(vec3 p, vec3 center, float size) {
  vec3 q = abs(p - center) - vec3(size);
  return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
}

vec2 opU(vec2 d1, vec2 d2) {
  return (d1.x < d2.x) ? d1 : d2;
}

vec2 map(vec3 p) {
  vec2 res = vec2(1e10, 0.);
  vec2 flooring = vec2(sdFloor(p), 0.5);
  vec2 cube = vec2(sdCube(p, vec3(0.0, 0.0, 0.0), 1.0), 1.5);
  
  res = opU(res, flooring);
  res = opU(res, cube);
  return res;
}

vec2 rayMarch(vec3 ro, vec3 rd) {
  float depth = MIN_DIST;
  vec2 res = vec2(0.0);
  
  for(int i = 0; i < MAX_MARCHING_STEPS; i++) {
    vec3 p = ro + depth * rd;
    vec2 result = map(p);
    float dist = result.x;
    
    if(dist < PRECISION) {
      res = vec2(depth, result.y);
      break;
    }
    
    depth += dist;
    
    if(depth > MAX_DIST) {
      res = vec2(MAX_DIST, -1.0);
      break;
    }
  }
  
  return res;
}

vec3 calcNormal(vec3 p) {
  const float h = 0.0001;
  vec2 k = vec2(1.0, -1.0);
  return normalize(
    k.xyy * map(p + k.xyy * h).x +
    k.yxy * map(p + k.yxy * h).x +
    k.yyx * map(p + k.yyx * h).x +
    k.xxx * map(p + k.xxx * h).x
  );
}

float hardShadow(vec3 ro, vec3 rd, float mint, float maxt) {
  for(float t = mint; t < maxt;) {
    vec3 p = ro + rd * t;
    float h = map(p).x;
    
    if(h < PRECISION) {
      return 0.0;
    }
    
    t += h;
  }
  return 1.0;
}

float softShadow(vec3 ro, vec3 rd, float mint, float maxt, float k) {
  float res = 1.0;
  
  for(float t = mint; t < maxt;) {
    vec3 p = ro + rd * t;
    float h = map(p).x;
    
    if(h < PRECISION) {
      return 0.0;
    }
    
    res = min(res, k * h / t);
    
    t += h;
  }
  
  return res;
}

vec3 render(vec3 ro, vec3 rd, vec3 lightPosition) {
  vec3 col = COLOR_BACKGROUND;
  
  vec2 res = rayMarch(ro, rd);
  float depth = res.x;
  float id = res.y;
  
  if(depth < MAX_DIST) {
    vec3 p = ro + rd * depth;
    vec3 normal = calcNormal(p);
    
    vec3 lightDirection = normalize(lightPosition - p);
    float lightDistance = length(lightPosition - p);
    float lightAttenuation = 1.0 / (1.0 + 0.1 * lightDistance + 0.01 * lightDistance * lightDistance);
    
    float ambient = 0.1;
    float diffuse = max(dot(normal, lightDirection), 0.0);
    vec3 viewDirection = normalize(ro - p);
    vec3 halfwayDirection = normalize(lightDirection + viewDirection);
    float specularPower = (id < 1.0) ? 32.0 : 16.0;
    float specular = pow(max(dot(normal, halfwayDirection), 0.0), specularPower);
    
    vec3 shadowRayOrigin = p + normal * 0.01;
    float shadow;
    if (USE_SOFT_SHADOWS) {
      shadow = softShadow(shadowRayOrigin, lightDirection, 0.1, 10.0, SHADOW_SOFTNESS);
    } else {
      shadow = hardShadow(shadowRayOrigin, lightDirection, 0.1, 10.0);
    }
    
    vec3 materialColor;
    float materialShininess;
    
    if(id < 1.0) {
      if(mod(floor(p.x) + floor(p.z), 2.0) < 1.0) {
        materialColor = COLOR_DARK;
      } else {
        materialColor = COLOR_LIGHT;
      }
      materialShininess = 0.08;
    } else {
      materialColor = COLOR_CUBE;
      materialShininess = 0.6;
    }
    
    vec3 ambientComponent = ambient * materialColor;
    vec3 diffuseComponent = diffuse * materialColor * lightAttenuation * shadow;
    vec3 specularComponent = specular * vec3(1.0) * materialShininess * lightAttenuation * shadow;
    
    col = ambientComponent + diffuseComponent + specularComponent;
    
    col += COLOR_BACKGROUND * 0.02;
    
    col = pow(col, vec3(1.1));
    
    const float tm_a = 2.51;
    const float tm_b = 0.03;
    const float tm_c = 2.43;
    const float tm_d = 0.59;
    const float tm_e = 0.14;
    col = (col * (tm_a * col + tm_b)) / (col * (tm_c * col + tm_d) + tm_e);
    
    col = pow(col, vec3(1.0/2.1));
  }
  
  return col;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
  vec2 du = vec2(1.0, 1.0) / iResolution.xy;
  vec4 rot = 2.0 * texture(iChannel0, vec2(1.0, 1.0) - du) - 1.0;
  float rotationAngle = rot.x;
  
  vec4 lightData = texture(iChannel0, vec2(0.0, 1.0) - du);
  
  float lightRadius = 3.0;
  float lightHeight = 3.0;
  vec3 lightPosition = lightData.xyz * (2.0 * vec3(lightRadius, lightHeight, lightRadius)) - 
                      vec3(lightRadius, lightHeight, lightRadius);
  
  vec2 ndc = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
  
  float cameraDistance = 6.0;
  float cameraHeight = 2.0;
  vec3 ro = vec3(
    cameraDistance * sin(rotationAngle),
    cameraHeight,
    cameraDistance * cos(rotationAngle)
  );
  
  vec3 lookAt = vec3(0, -0.5, 0);
  vec3 forward = normalize(lookAt - ro);
  vec3 right = normalize(cross(vec3(0, 1, 0), forward));
  vec3 up = cross(forward, right);
  vec3 rd = normalize(forward + ndc.x * right + ndc.y * up);
  
  vec3 col = render(ro, rd, lightPosition);
  
  fragColor = vec4(col, 1.0);
}