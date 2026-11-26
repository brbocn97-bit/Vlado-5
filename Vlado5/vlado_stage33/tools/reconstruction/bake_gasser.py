#!/usr/bin/env python3
import json,struct
from pathlib import Path
import numpy as np
from scipy.spatial.transform import Rotation as R
from scipy.optimize import least_squares
P=Path('/tmp/vlado_rebuild/Vlado5/vlado_stage33/assets/characters/vlado/Vlado_Sipcic_ReRigged.glb');b=bytearray(P.read_bytes());o=12
while o<len(b):
 n,t=struct.unpack_from('<II',b,o);o+=8
 if t==0x4e4f534a:j=json.loads(bytes(b[o:o+n]).decode().rstrip('\0 \t\r\n'))
 elif t==0x004e4942:bo=o;bl=n
 o+=n
bn=memoryview(b)[bo:bo+bl];N={n.get('name'):i for i,n in enumerate(j['nodes'])};par={c:i for i,n in enumerate(j['nodes']) for c in n.get('children',[])}
def av(i):
 a=j['accessors'][i];v=j['bufferViews'][a['bufferView']];nn={'SCALAR':1,'VEC3':3,'VEC4':4}[a['type']];q=v.get('byteOffset',0)+a.get('byteOffset',0);return np.ndarray((a['count'],nn),dtype='<f4',buffer=bn,offset=q,strides=(v.get('byteStride',4*nn),4))
def rest(i):n=j['nodes'][i];return np.array(n.get('translation',[0,0,0]),float),R.from_quat(n.get('rotation',[0,0,0,1]))
def tracks(a):
 x={}
 for c in a['channels']:
  s=a['samplers'][c['sampler']];x[(c['target']['node'],c['target']['path'])]=s['output']
 return x
def rots(a):
 t=tracks(a);return {i:R.from_quat(av(t[(i,'rotation')])[-1].copy()) if (i,'rotation') in t else rest(i)[1] for i in range(len(j['nodes']))}
def glob(q):
 m={}
 def f(i):
  if i in m:return m[i]
  t,_=rest(i);x=np.eye(4);x[:3,:3]=q[i].as_matrix();x[:3,3]=t;m[i]=f(par[i])@x if i in par else x;return m[i]
 for i in range(len(j['nodes'])):f(i)
 return m
LU,LL,LH,RH=[N[x] for x in ['LeftUpperArm','LeftLowerArm','LeftHand','RightHand']];a=next(x for x in j['animations'] if x['name']=='PistolAim');base=rots(a);g=glob(base);target=g[RH][:3,3]+g[N['Root']][:3,:3]@np.array([-.065,-.03,.015])
def fun(x):
 q=base.copy();q[LU]=base[LU]*R.from_rotvec(x[:3]);q[LL]=base[LL]*R.from_rotvec(x[3:]);return np.r_[(glob(q)[LH][:3,3]-target)*12,x*.055]
s=least_squares(fun,np.zeros(6),bounds=(-2.2,2.2),max_nfev=3000)
for nm in ['PistolIdle','PistolAim','PistolFire']:
 t=tracks(next(x for x in j['animations'] if x['name']==nm))
 for bi,d in [(LU,s.x[:3]),(LL,s.x[3:])]:
  x=av(t[(bi,'rotation')]);x[:]=(R.from_quat(x.copy())*R.from_rotvec(d)).as_quat().astype('f4')
bn.release();P.write_bytes(b);print('GASSER_BAKED err',np.linalg.norm(fun(s.x)[:3]/12))
