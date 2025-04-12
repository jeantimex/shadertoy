// Fork of "easy soft shadow" by lambwww. https://shadertoy.com/view/dlfGz8
// 2025-04-09 06:14:58

struct ray {
  vec3 start;
  vec3 dir;
};
struct material {
  float d;
  float id;
  vec3 color;
};

float diffuse(vec3 light, vec3 normal) {
  float k = 0.2;
  float halfLamb = dot(light, normal) * 0.5 + 0.5;
  return halfLamb;
}
float sphere(vec3 p, vec3 center, float radius) {
  return length(p - center) - radius;
}
float plane(vec3 p) {
  return p.y + 1.5;
}
//场景图，并且根据不同的id赋不同的颜色值
material map(vec3 p) {
  material mat;
  mat.color = vec3(1, 1, 1);
  vec3 center = vec3(0, 0, 4);
  float sphere1 = sphere(p, vec3(-2, 0, 4), 1.);
  float sphere2 = sphere(p, vec3(2, 0, 4), 1.);
  float plane1 = plane(p);
  if(sphere1 <= 0.001) {
    mat.id = 0.;
    mat.color = vec3(1, 0.5, 0.5);
  }
  if(sphere2 <= 0.001) {
    mat.id = 1.;
  }
  if(plane1 <= 0.001) {
    mat.id = 2.;
    mat.color = vec3(1, 1, 0);
  }
  mat.d = min(sphere1, min(sphere2, plane1));
  return mat;
}
//利用曲面的梯度求法线，就是对xyz分量求偏导
vec3 GetNormal(vec3 p) {
  float d = map(p).d;
  vec2 e = vec2(0.001, 0.0);
  float fdx = d - map(p - e.xyy).d;
  float fdy = d - map(p - e.yxy).d;
  float fdz = d - map(p - e.yyx).d;
  return normalize(vec3(fdx, fdy, fdz));
}
//求光线到球表面的距离，使用光线无限接近
material rayMatch(vec3 rayS, vec3 rayD) {
  material mat;
  float d = 0.;
  for(int i = 0; i < 250; i++)//之前循环次数少了，有的地方没找到
  {
    vec3 p = rayS + rayD * d;
    mat = map(p);
    float tempD = mat.d;
    if(tempD <= 0.001 || tempD >= 40.) //太近代表找到了，太远代表看不见
      break;
    d += tempD;
  }
  mat.d = d;
  return mat;
}
//从物体的点沿着光线方向继续寻找物体，找到了那就是阴影点，赋颜色值黑色
float shadow(vec3 ro, vec3 rd) {

  for(float i = 0.; i < 40.;) {
    vec3 p = ro + rd * i;
    float h = map(p).d;
    if(h < 0.001)
      return 0.;
    i += h;
  }
  return 1.;
}
//0代表硬阴影，res代表软阴影，1代表没有阴影。因为越接近0越靠近黑色
float softshadow(vec3 ro, vec3 rd, float k) {
  float res = 1.0;
  float t = 0.;
  for(int i = 0; i < 100; i++) {
    float h = map(ro + rd * t).d;
    if(h < 0.001)
      return 0.;
        //这里h是sdf的距离值，t表示从起点到点现在所在位置走过路程的长度，二者比值代表了安全角度的大小
        //k是控制角度对应的阴影取值，k越大角度和阴影关系越敏感
    res = min(res, k * h / t);

    t += h;
  }
  return res;
}
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    //uv初始化
  vec2 uv = fragCoord / iResolution.xy;
  uv -= 0.5;
  uv.x *= iResolution.x / iResolution.y;
    //生成视线
  ray viewRay;
  viewRay.start = vec3(0, 0, -3);
  viewRay.dir = normalize(vec3(uv, 1));//光线向量，要限制在【0，1】中间
    //求眼睛到球体的距离，如果在距离内代表可以被看见，就进行着色
  material mat = rayMatch(viewRay.start, viewRay.dir);
  if(mat.d <= 40.) {
        //视线起点到球表面的最小距离
    float d = rayMatch(viewRay.start, viewRay.dir).d;
        //球表面的点
    vec3 p = viewRay.start + viewRay.dir * d;
        //生成光线，光线射向当前看到的物体表面点
    ray light;
    light.start = vec3(-5, 8, 2);
    light.dir = normalize(light.start - p - 5. * sin(iTime * 0.4));
        //表面那个点对应的法线
    vec3 normal = GetNormal(p);
        //diffuse
    float diffuse = dot(normal, light.dir);
    vec3 color = vec3(1, 1, 1);
        //shadow
    p = p + normal * 0.002;
    diffuse *= softshadow(p, light.dir, 8.);

    color = diffuse * color;
    fragColor = vec4(color, 1);
  } else {
    fragColor = vec4(0.1, 0.2, 0.4, 1);
  }
}