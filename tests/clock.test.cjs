const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const path = require('node:path');
const html = fs.readFileSync(path.join(__dirname, '../docs/index.html'), 'utf8');
const source = html.match(/<script>([\s\S]*)<\/script>/)[1];
const ctx = new Proxy({}, {get: (o, k) => o[k] || (() => {}), set: (o,k,v) => (o[k]=v,true)});
const canvas = {width:0,height:0,getContext:()=>ctx};
const env = vm.createContext({document:{querySelector:s=>s==='canvas'?canvas:{},body:{classList:{add(){},remove(){}}}},window:{addEventListener(){}},setTimeout(){},clearTimeout(){},setInterval(){},innerWidth:1280,innerHeight:800,devicePixelRatio:1,performance:{now:()=>0},Date,Math,String});
vm.runInContext(source, env);
for(const [h,m,s,eh,em] of [[0,0,0,0,0],[6,15,0,6.25/24,.25],[12,30,0,12.5/24,.5],[18,45,0,18.75/24,.75],[23,59,59,86399/86400,3599/3600],[1,0,0,1/24,0]]) {
 const result=vm.runInContext(`progressAt(new Date(2026,0,1,${h},${m},${s}))`,env);
 assert(Math.abs(result.hours-eh)<1e-10);
 assert(Math.abs(result.minutes-em)<1e-10);
}
const fractional=vm.runInContext('progressAt(new Date(2026,0,1,0,0,0,500))',env);
assert(Math.abs(fractional.minutes-.5/3600)<1e-10);
assert(Math.abs(fractional.hours-.5/86400)<1e-10);
assert.equal(canvas.width,1280);
env.innerWidth=390;env.innerHeight=844;vm.runInContext('draw()',env);
assert.equal(canvas.width,390);assert.equal(canvas.height,844);
assert.equal(html,fs.readFileSync(path.join(__dirname,'../windows/Previa.html'),'utf8'));
console.log('OK: ciclos de 24h/60min, viradas, fracao de segundo, escala e paridade das versoes HTML.');
