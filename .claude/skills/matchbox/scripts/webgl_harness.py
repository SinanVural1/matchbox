#!/usr/bin/env python3
"""
Build a WebGL page that compiles a single-pass Matchbox shader and renders it.

Usage:
    python3 webgl_harness.py <shader.glsl> <out.html> <configs.json> <W> <H>

configs.json is a list of {"name": ..., "u": {uniform: value}}; anything not
given takes its default from the shader's XML. Serve the page with serve.py
and open it in the browser pane. The page defines:

    render({name, u})  draws one configuration and returns its canvas
    frontImg, backImg, matteImg   2D canvases bound to the samplers named
                                  front, back and matte; draw into them first

What it proves and what it doesn't is in reference/testing.md.

Translation from Flame's legacy GLSL to WebGL's GLSL ES 1.00:
  - a precision statement is added
  - GL_ARB_shader_texture_lod becomes GL_EXT_shader_texture_lod, with
    texture2DLod mapped to texture2DLodEXT
  - textures are uploaded flipped, so gl_FragCoord and uv run bottom-up as
    in Flame, and get mipmaps, which WebGL 1 only builds for power-of-two
    sizes: keep W and H powers of two when the shader reads mip levels
"""
import json, sys, re, xml.etree.ElementTree as ET
glsl = open(sys.argv[1]).read()
W, H = int(sys.argv[4]), int(sys.argv[5])
defaults = {}
for u in ET.parse(sys.argv[1][:-5] + '.xml').getroot().iter('Uniform'):
    n, t = u.get('Name'), u.get('Type')
    if t == 'sampler2D': continue
    if t in ('vec2', 'vec3'): defaults[n] = [float(s.get('Default')) for s in u.findall('SubUniform')]
    elif t == 'bool': defaults[n] = 1 if u.get('Default') == 'True' else 0
    elif t == 'int': defaults[n] = int(u.get('Default'))
    else: defaults[n] = float(u.get('Default'))
types = {n: t for t, n in re.findall(r'uniform\s+(\w+)\s+(\w+)\s*;', glsl)}
ext = '#extension GL_ARB_shader_texture_lod : enable'
head, tail = glsl.split(ext, 1) if ext in glsl else ('', glsl)
src = head + '#extension GL_EXT_shader_texture_lod : enable\n#define texture2DLod texture2DLodEXT\nprecision highp float;\n' + tail
html = '''<!doctype html><html><head><meta charset="utf-8"><title>Harness</title>
<style>body{background:#222;color:#ddd;font:12px sans-serif;margin:8px}.c{display:inline-block;margin:4px}canvas{display:block;width:var(--cw,400px)}</style></head><body>
<div id="log"></div><div id="grid"></div><script id="fs" type="x-shader">''' + src.replace('</', '<\\/') + '''</script><script>
const W=%d,H=%d;const DEF=%s;const TYPES=%s;const CONFIGS=%s;
function mk(d){const c=document.createElement('canvas');c.width=W;c.height=H;d(c.getContext('2d'));return c;}
const frontImg=mk(g=>{g.fillStyle='#808080';g.fillRect(0,0,W,H);});const backImg=mk(g=>{g.fillStyle='#000';g.fillRect(0,0,W,H);});const matteImg=mk(g=>{g.fillStyle='#fff';g.fillRect(0,0,W,H);});
const log=m=>document.getElementById('log').innerHTML+=m+'<br>';
function render(cfg){const cv=document.createElement('canvas');cv.width=W;cv.height=H;
 const gl=cv.getContext('webgl',{preserveDrawingBuffer:true,premultipliedAlpha:false,alpha:false});gl.getExtension('EXT_shader_texture_lod');
 const vs=gl.createShader(gl.VERTEX_SHADER);gl.shaderSource(vs,'attribute vec2 p;void main(){gl_Position=vec4(p,0.,1.);}');gl.compileShader(vs);
 const fs=gl.createShader(gl.FRAGMENT_SHADER);gl.shaderSource(fs,document.getElementById('fs').textContent);gl.compileShader(fs);
 if(!gl.getShaderParameter(fs,gl.COMPILE_STATUS)){log('COMPILE ERROR: '+gl.getShaderInfoLog(fs));return null;}
 const pr=gl.createProgram();gl.attachShader(pr,vs);gl.attachShader(pr,fs);gl.linkProgram(pr);gl.useProgram(pr);
 const b=gl.createBuffer();gl.bindBuffer(gl.ARRAY_BUFFER,b);gl.bufferData(gl.ARRAY_BUFFER,new Float32Array([-1,-1,1,-1,-1,1,1,1]),gl.STATIC_DRAW);
 const loc=gl.getAttribLocation(pr,'p');gl.enableVertexAttribArray(loc);gl.vertexAttribPointer(loc,2,gl.FLOAT,false,0,0);
 [['front',frontImg],['back',backImg],['matte',matteImg]].forEach(([n,img],i)=>{const t=gl.createTexture();gl.activeTexture(gl.TEXTURE0+i);gl.bindTexture(gl.TEXTURE_2D,t);
  gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL,true);gl.texImage2D(gl.TEXTURE_2D,0,gl.RGBA,gl.RGBA,gl.UNSIGNED_BYTE,img);gl.generateMipmap(gl.TEXTURE_2D);
  gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MIN_FILTER,gl.LINEAR_MIPMAP_LINEAR);gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_WRAP_S,gl.CLAMP_TO_EDGE);gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_WRAP_T,gl.CLAMP_TO_EDGE);
  gl.uniform1i(gl.getUniformLocation(pr,n),i);});
 const v=Object.assign({},DEF,{adsk_result_w:W,adsk_result_h:H},cfg.u);
 for(const [n,val] of Object.entries(v)){const l=gl.getUniformLocation(pr,n);if(l===null)continue;const t=TYPES[n];
  if(t==='float')gl.uniform1f(l,val);else if(t==='int'||t==='bool')gl.uniform1i(l,val);else if(t==='vec2')gl.uniform2fv(l,val);else if(t==='vec3')gl.uniform3fv(l,val);}
 gl.drawArrays(gl.TRIANGLE_STRIP,0,4);const d=document.createElement('div');d.className='c';d.appendChild(cv);d.appendChild(document.createTextNode(cfg.name));document.getElementById('grid').appendChild(d);return cv;}
CONFIGS.forEach(render);log('done');
</script></body></html>''' % (W, H, json.dumps(defaults), json.dumps(types), open(sys.argv[3]).read())
open(sys.argv[2], 'w').write(html)
