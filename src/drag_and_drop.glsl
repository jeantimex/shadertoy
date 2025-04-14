// -------------------------------------------------------
// Common Tab
// -------------------------------------------------------
const float PI = 3.141592653;

// ----------------------- Light ----------------------- //
struct SpotLight {
    vec3 position;
    vec3 direction;
    float angle;
};

SpotLight new_light(vec3 position, vec3 direction, float angle) {
    SpotLight light;
    light.position = position;
    light.direction = direction;
    light.angle = angle;
    return light;
}

// ----------------------- Camera ----------------------- //
struct Camera {
    vec3 position;
    vec3 direction;
    vec3 up_direction;
    float fov;
    float aspect; // x / y
};

Camera new_camera(vec3 position, vec3 direction, vec3 up_direction, float fov, float aspect) {
    Camera camera;
    camera.position = position;
    camera.direction = direction;
    camera.up_direction = up_direction;
    camera.fov = fov;
    camera.aspect = aspect;
    return camera;
}

// perspective camera ray
// cf: https://qiita.com/aa_debdeb/items/301dfc54788f1219b554
vec3 camera_ray(in Camera camera, in vec2 uv) {
    uv = uv * 2.0 - 1.0;
    float radian = camera.fov;
    float h = tan(radian * 0.5);
    float w = h * camera.aspect;
    vec3 right = normalize(cross(camera.direction, camera.up_direction));
    vec3 up = normalize(cross(right, camera.direction));
    return normalize(right * w * uv.x + up * h * uv.y + camera.direction);  
}

// ----------------------- Basic Math ----------------------- //
// Rodrigues' rotation formula
mat3 rot(vec3 axis, float angle) {
    return mat3(
        axis[0] * axis[0] * (1.0 - cos(angle)) + cos(angle),
        axis[0] * axis[1] * (1.0 - cos(angle)) + axis[2] * sin(angle),
        axis[0] * axis[2] * (1.0 - cos(angle)) - axis[1] * sin(angle),
        axis[0] * axis[1] * (1.0 - cos(angle)) - axis[2] * sin(angle),
        axis[1] * axis[1] * (1.0 - cos(angle)) + cos(angle),
        axis[1] * axis[2] * (1.0 - cos(angle)) + axis[0] * sin(angle),
        axis[0] * axis[2] * (1.0 - cos(angle)) + axis[1] * sin(angle),
        axis[1] * axis[2] * (1.0 - cos(angle)) - axis[0] * sin(angle),
        axis[2] * axis[2] * (1.0 - cos(angle)) + cos(angle)
    );
}

// determinant of a 3x3 matrix
float det(in mat3 a) {
    return a[0][0] * a[1][1] * a[2][2]
        + a[0][1] * a[1][2] * a[2][0]
        + a[0][2] * a[1][0] * a[2][1]
        - a[0][1] * a[1][0] * a[2][2]
        - a[0][2] * a[1][1] * a[2][0]
        - a[0][0] * a[1][2] * a[2][1];
}

// Solves the equation Ax = b.
vec3 solve(in mat3 a, in vec3 b) {
    return vec3(
        det(mat3(b, a[1], a[2])),
        det(mat3(a[0], b, a[2])),
        det(mat3(a[0], a[1], b))
    ) / det(a);
}

// the square of the distance between a point pt and a line stipulated by its origin and its direction
// The direction vector have to be normalized.
float distance2_point_line(in vec3 point, in vec3 origin, in vec3 direction) {
    vec3 a = point - origin;
    vec3 h = a - dot(a, direction) * direction;
    return dot(h, h);
}

// the distance between a point pt and a line stipulated by its origin and its direction
// The direction vector have to be normalized.
float distance_point_line(in vec3 point, in vec3 origin, in vec3 direction) {
    return sqrt(distance2_point_line(point, origin, direction));
}

// ------------------- good old Phong model ------------------- //
float phong_ambient() {
    return 1.0;
}

float phong_diffuse(vec3 position, vec3 normal, SpotLight light) {
    vec3 dir = normalize(light.position - position);
    return dot(dir, normal);
}

float phong_specular(vec3 position, vec3 normal, SpotLight light, Camera camera, float alpha) {
    vec3 light_dir = normalize(light.position - position);
    if (dot(light_dir, normal) < 0.0) return 0.0;
    vec3 camera_dir = normalize(camera.position - position);
    vec3 reflect_dir = reflect(-light_dir, normal);
    float cos_alpha = clamp(dot(camera_dir, reflect_dir), 0.0, 1.0);
    return pow(cos_alpha, alpha);
}

vec3 phong_vector(
    vec3 position,
    vec3 normal,
    SpotLight light,
    Camera camera,
    float specular_alpha
) {
    return vec3(
        phong_ambient(),
        phong_diffuse(position, normal, light),
        phong_specular(position, normal, light, camera, specular_alpha)
    );
}

// -------------------------------------------------------
// BufferA Tab
// -------------------------------------------------------
// The MIT License
// Copyright © 2020 IWBTShyGuy

const float EPSILON = 1.0e-3;
const float PRADIUS = 0.01;
const vec3 CYLINDER_COLOR = vec3(220.0, 214.0, 231.0) / 255.0;
const vec3 CYLINDER_REFLECT_RATIO = vec3(0.2, 0.6, 0.2);
const vec3 FLOOR_COLOR = vec3(117.0, 109.0, 145.0) / 255.0;

// a[0]i + a[1]j + a[2]k + a[3]
vec4 qmult(vec4 a, vec4 b) {
    return vec4(
        a[0] * b[3] + a[1] * b[2] - a[2] * b[1] + a[3] * b[0],
        -a[0] * b[2] + a[1] * b[3] + a[2] * b[0] + a[3] * b[1],
        a[0] * b[1] - a[1] * b[0] + a[2] * b[3] + a[3] * b[2],
        - a[0] * b[0] - a[1] * b[1] - a[2] * b[2] + a[3] * b[3]
    );
}

// rotation by quaternion
vec3 qrot(vec4 q, vec3 x) {
    vec4 x_prime = vec4(x, 0.0);
    vec4 q_bar = vec4(-q.xyz, q.w);
    return qmult(qmult(q, x_prime), q_bar).xyz;
}

bool mouse_dragging(out vec2 disp) {
    vec2 du = vec2(1.0, 1.0) / iResolution.xy;
    vec4 p_mouse = 2.0 * texture(iChannel0, du) - 1.0;
    vec4 mouse = iMouse / iResolution.xyxy;
    disp = mouse.xy - p_mouse.xy;
    return p_mouse.z > 0.0 && mouse.z > 0.0;
}

// --------------------- cylinder --------------------- //
struct Cylinder {
    vec3 origin;
    vec3 direction; // have to be normalized
    float radius;
    float height;
};

// Returns positive value if a point is in a cylinde.
float in_cylinder(
    in vec3 point,
    in Cylinder cylinder
) {
    float dist2 = distance2_point_line(point, cylinder.origin, cylinder.direction);
    return cylinder.radius * cylinder.radius - dist2;
}

// Creats an orthogonal matrix whose z_axis is dir.
mat3 create_matrix(in vec3 dir) {
    int tmp = abs(dir[0]) < abs(dir[1]) ? 0 : 1;
    int midx = abs(dir[tmp]) < abs(dir[2]) ? tmp : 2;
    vec3 axis0 = vec3(0.0);
    axis0[(midx + 1) % 3] = dir[(midx + 2) % 3];
    axis0[(midx + 2) % 3] = -dir[(midx + 1) % 3];
    vec3 axis1 = cross(dir, axis0);
    return mat3(axis0, axis1, dir);
}

// Find the intersection of a ray of light with a cylinder extending infinitely around the z-axis.
// @param[in] origin the origin of the ray
// @param[in] ray the direction of the ray
// @param[in] radius the radius of the cylinder
// @param[out] position the intersection point
// @param[out] normal the normal vector of the cylinder at the intersection point
// @return radius^2 - (the distance between the ray and the z-axis)^2
float regular_infinite_cylinder_intersection(
    in vec3 origin,
    in vec3 ray,
    in float radius,
    out vec3 position,
    out vec3 normal
) {
    vec2 p_ray = normalize(ray.xy);
    vec2 p_org = origin.xy;
    vec2 p_h = dot(p_ray, p_org) * p_ray - p_org;
    float res = radius * radius - dot(p_h, p_h);
    if (res < 0.0) {
        return res;
    }
    float t = dot(p_ray, -p_org) - sqrt(res);
    t *= 1.0 / length(ray.xy);
    position = origin + t * ray;
    normal = vec3(position.xy, 0.0);
    return res;
}

// Find the intersection of a ray of light with a cylinder around the z-axis.
// @param[in] origin the origin of the ray
// @param[in] ray the direction of the ray
// @param[in] radius the radius of the cylinder
// @param[in] height the height of the cylinder
// @param[out] position the intersection point
// @param[out] normal the normal vector of the cylinder at the intersection point
// @return Returns a positive value if the ray and the cylinder have a intersection.
float regular_cylinder_intersection(
    in vec3 origin,
    in vec3 ray,
    in float radius,
    in float height,
    out vec3 position,
    out vec3 normal
) {
    float res = regular_infinite_cylinder_intersection(
        origin,
        ray,
        radius,
        position,
        normal
    );
    if (position.z < 0.0) {
        position = origin - origin.z / ray.z * ray;
        res = radius * radius - dot(position.xy, position.xy);
    } else if (position.z > height) {
        position = origin + (height - origin.z) / ray.z * ray;
        res = radius * radius - dot(position.xy, position.xy);
    }
    return res;
}

// Find the intersection of a ray of light with a cylinder.
// @param[in] origin the origin of the ray
// @param[in] ray the direction of the ray
// @param[in] radius the radius of the cylinder
// @param[out] position the intersection point
// @param[out] normal the normal vector of the cylinder at the intersection point
// @return radius^2 - (the distance between the ray and the z-axis)^2
float cylinder_intersection(
    in vec3 origin,
    in vec3 ray,
    in Cylinder cylinder,
    out vec3 position,
    out vec3 normal
) {
    mat3 mat = create_matrix(cylinder.direction);
    if (abs(det(mat)) < 1.0e-3) {
        return -1.0;
    }
    float res = regular_cylinder_intersection(
        solve(mat, origin - cylinder.origin),
        solve(mat, ray),
        cylinder.radius,
        cylinder.height,
        position,
        normal
    );
    position = mat * position + cylinder.origin;
    normal = mat * normal;
    return res;
}

// Renders the intersection of two cylinders
float render_core(
    in vec2 uv,
    in Camera camera,
    in SpotLight light,
    in Cylinder cylinder[2],
    out vec3 col
) {
    vec3 ray = camera_ray(camera, uv);
    vec3 position0, normal0, position1, normal1;
    float res0 = cylinder_intersection(camera.position, ray, cylinder[0], position0, normal0);
    float res1 = cylinder_intersection(camera.position, ray, cylinder[1], position1, normal1);
    float res = min(res0, res1);
    if (res < 0.0) {
        return res;
    }
    vec3 position, normal;
    float res01 = in_cylinder(position0, cylinder[1]);
    float res10 = in_cylinder(position1, cylinder[0]);
    if (res01 < 0.0 && res10 < 0.0) {
        return -1.0;
    } else if (res01 < 0.0) {
        position = position1;
        normal = normal1;
    } else if (res10 < 0.0) {
        position = position0;
        normal = normal0;
    } else {
        float depth0 = length(position0 - camera.position);
        float depth1 = length(position1 - camera.position);
        position = depth0 < depth1 ? position0 : position1;
        normal = depth0 < depth1 ? normal0 : normal1;
    }
    vec3 phong_vector = phong_vector(position, normal, light, camera, 5.0);
    col = CYLINDER_COLOR * dot(phong_vector, CYLINDER_REFLECT_RATIO);
    return res;
}

// -------------------------------------------------------
// Image Tab
// -------------------------------------------------------
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
  
    // the (0, 0) pixel is the buffer for mouse
    if (length(uv) < PRADIUS) {
        fragColor = (iMouse / iResolution.xyxy + 1.0) / 2.0;
        return;
    }
    
    // First Frame
    if (iFrame == 0) {
        fragColor = vec4(0.40, 0.70, 0.5, 1.0);
        return;
    }

    vec2 du = vec2(1.0, 1.0) / iResolution.xy;
    vec4 rot = 2.0 * texture(iChannel0, vec2(1.0, 1.0) - du) - 1.0;
    
    vec2 dm;
    bool drag = mouse_dragging(dm);
    if (drag && length(dm) > EPSILON) {
        vec3 axis = normalize(vec3(dm.y, -dm.x, 0.0));
        float angle = length(dm) * 3.0;
        vec4 frot = vec4(axis * sin(angle / 2.0), cos(angle / 2.0));
        rot = qmult(rot, frot);
    }

    if (length(uv - vec2(1.0, 1.0)) < PRADIUS) {
        fragColor = (rot + 1.0) / 2.0;
        return;
    }

    vec3 pos = qrot(rot, vec3(0.0, 0.0, 1.0));
    vec3 up = qrot(rot, vec3(0.0, 1.0, 0.0));
    float asp = iResolution.x / iResolution.y;
    Camera camera = new_camera(5.0 * pos, -pos, up, PI / 4.0, asp);
    SpotLight light = new_light(5.0 * pos, -pos, PI / 2.0);

    Cylinder cylinder[2];
    cylinder[0].origin = vec3(-2.0, 0.0, 0.0);
    cylinder[0].direction = vec3(1.0, 0.0, 0.0);
    cylinder[0].radius = 1.0;
    cylinder[0].height = 4.0;
    cylinder[1].origin = vec3(0.0, -2.0, 0.0);
    cylinder[1].direction = vec3(0.0, 1.0, 0.0);
    cylinder[1].radius = 1.0;
    cylinder[1].height = 4.0;

    vec3 col;
    render_core(uv, camera, light, cylinder, col);
    fragColor = vec4(col, 1.0);
}


void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec2 du = vec2(1.0, 0.0) / iResolution.xy;
    vec2 dv = vec2(0.0, 1.0) / iResolution.xy;

    vec3 col = vec3(0.0);
    col += texture(iChannel0, uv + du + dv).xyz;
    col += texture(iChannel0, uv + du).xyz;
    col += texture(iChannel0, uv + du - dv).xyz;
    col += texture(iChannel0, uv + dv).xyz;
    col += texture(iChannel0, uv - dv).xyz;
    col += texture(iChannel0, uv - du + dv).xyz;
    col += texture(iChannel0, uv - du).xyz;
    col += texture(iChannel0, uv - du - dv).xyz;
    col /= 8.0;
    fragColor = vec4(col, 1.0);
}