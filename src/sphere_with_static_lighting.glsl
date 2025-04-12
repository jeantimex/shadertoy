// Sphere SDF function with center parameter
float sdSphere(vec3 p, vec3 center, float r) {
  return length(p - center) - r;
}

// Calculate normal vector
vec3 calcNormal(vec3 p, vec3 center) {
  const float eps = 0.001;
  const vec2 h = vec2(eps, 0.0);
  float r = 1.0;  // Sphere radius
  return normalize(vec3(sdSphere(p + h.xyy, center, r) - sdSphere(p - h.xyy, center, r), sdSphere(p + h.yxy, center, r) - sdSphere(p - h.yxy, center, r), sdSphere(p + h.yyx, center, r) - sdSphere(p - h.yyx, center, r)));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    // Center the coordinate system at the screen center, maintaining aspect ratio
  vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;

    // Set camera parameters
  vec3 ro = vec3(0.0, 0.0, -3.0);  // Camera position
  vec3 rd = normalize(vec3(uv, 1.0));  // Ray direction

    // Define sphere parameters
  vec3 sphereCenter = vec3(0.0, 0.0, 0.0);  // Sphere center position
  float sphereRadius = 1.0;                 // Sphere radius

  // Static light source position
  vec3 lightPos = vec3(2.0, 1.0, 2.0);
  vec3 lightDir = normalize(lightPos);

  // Ray marching parameters
  float t = 0.0;
  float tmax = 20.0;
  int maxSteps = 100;

  // Ray marching loop
  for(int i = 0; i < maxSteps; i++) {
    vec3 p = ro + rd * t;
    float h = sdSphere(p, sphereCenter, sphereRadius);

    if(h < 0.001 || t > tmax)
      break;
    t += h;
  }

    // Default background color
  vec3 col = vec3(0.05, 0.05, 0.1);

    // If ray hit the sphere
  if(t < tmax) {
        // Calculate intersection point
    vec3 p = ro + rd * t;

        // Calculate normal vector
    vec3 normal = calcNormal(p, sphereCenter);

        // Basic lighting calculations
    float diff = max(dot(normal, lightDir), 0.0);  // Diffuse lighting
    float amb = 0.5 + 0.5 * normal.y;  // Ambient lighting
    float spec = pow(max(dot(reflect(-lightDir, normal), -rd), 0.0), 16.0);  // Specular highlight

        // Final color
    col = vec3(0.8, 0.3, 0.2) * diff + vec3(0.1, 0.1, 0.2) * amb + vec3(1.0) * spec * 0.5;
  }

    // Simple gamma correction
  col = sqrt(col);

    // Output to screen
  fragColor = vec4(col, 1.0);
}