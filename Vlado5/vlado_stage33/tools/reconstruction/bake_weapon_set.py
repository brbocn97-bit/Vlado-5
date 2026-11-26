#!/usr/bin/env python3
import json,struct
from pathlib import Path
import numpy as np
from scipy.spatial.transform import Rotation as R,Slerp
from scipy.optimize import least_squares
P=Path('/tmp/vlado_rebuild/Vlado5/vlado_stage33/assets/characters/vlado/Vlado_Sipcic_ReRigged.glb')
def load():
 b=P.read_bytes();o=12;j=None;bn=b''
 while o<len(b):
  n,t=struct.unpack_from('<II',b,o);o+=8;c=b[o:o+n];o+=n
  if t==0x4e4f534a:j=json.loads(c.decode().rstrip('\0 \t\r\n'))
  elif t==0x004e4942:bn=c
 return j,bytearray(bn)
j,b=load();N={n.get('name'):i for i,n in enumerate(j['nodes'])};par={c:i for i,n in enumerate(j['nodes']) for c in n.get('children',[])}
def av(i):
 a=j['accessors'][i];v=j['bufferViews'][a['bufferView']];nn={'SCALAR':1,'VEC3':3,'VEC4':4}[a['type']];q=v.get('byteOffset',0)+a.get('byteOffset',0);return np.ndarray((a['count'],nn),dtype='<f4',buffer=b,offset=q,strides=(v.get('byteStride',4*nn),4)).copy()
def add(x,typ):
 x=np.asarray(x,dtype='<f4');b.extend(b'\0'*((-len(b))%4));o=len(b);z=x.tobytes();b.extend(z);vi=len(j['bufferViews']);j['bufferViews'].append({'buffer':0,'byteOffset':o,'byteLength':len(z)});ai=len(j['accessors']);d={'bufferView':vi,'componentType':5126,'count':len(x),'type':typ};
 if typ=='SCALAR':d.update(min=[float(x.min())],max=[float(x.max())])
 j['accessors'].append(d);return ai
def rest(i):n=j['nodes'][i];return np.array(n.get('translation',[0,0,0]),float),R.from_quat(n.get('rotation',[0,0,0,1]))
def amap(name):
 a=next(x for x in j['animations'] if x['name']==name);m={}
 for c in a['channels']:
  s=a['samplers'][c['sampler']];m[(c['target']['node'],c['target']['path'])]=(av(s['input']).reshape(-1),av(s['output']))
 return m
def sample(name,t):
 m=amap(name);q={i:rest(i)[1] for i in range(len(j['nodes']))};p={}
 for (i,k),(ts,v) in m.items():
  t2=np.clip(t,ts[0],ts[-1])
  if k=='rotation':q[i]=R.from_quat(v[0] if len(ts)==1 else Slerp(ts,R.from_quat(v))([t2])[0].as_quat())
  elif k=='translation':p[i]=np.array([np.interp(t2,ts,v[:,z]) for z in range(3)])
 return q,p
def glob(q,p=None):
 p=p or {};m={}
 def f(i):
  if i in m:return m[i]
  t,_=rest(i);x=np.eye(4);x[:3,:3]=q[i].as_matrix();x[:3,3]=p.get(i,t);m[i]=f(par[i])@x if i in par else x;return m[i]
 for i in range(len(j['nodes'])):f(i)
 return m
RU,RL,RH,LU,LL,LH=[N[x] for x in ['RightUpperArm','RightLowerArm','RightHand','LeftUpperArm','LeftLowerArm','LeftHand']]
def solve(rt,lt):
 base,_=sample('Idle',0);B=[RU,RL,LU,LL]
 def F(x):
  q=base.copy()
  for k,i in enumerate(B):q[i]=base[i]*R.from_rotvec(x[3*k:3*k+3])
  g=glob(q);return np.r_[(g[RH][:3,3]-rt)*13,(g[LH][:3,3]-lt)*13,x*.045]
 s=least_squares(F,np.zeros(12),bounds=(-2.5,2.5),max_nfev=5000);q=base.copy()
 for k,i in enumerate(B):q[i]=base[i]*R.from_rotvec(s.x[3*k:3*k+3])
 return q
ri=solve(np.array([.18,1.23,-.18]),np.array([.13,1.19,-.45]));ra=solve(np.array([.16,1.40,-.22]),np.array([.11,1.37,-.50]));hi=solve(np.array([.20,1.15,-.16]),np.array([.13,1.10,-.46]));rr=solve(np.array([.16,1.40,-.14]),np.array([.11,1.37,-.42]));reloadq=solve(np.array([.23,1.27,-.10]),np.array([.13,1.19,-.45]))
hand=R.from_matrix(glob(ra)[RH][:3,:3])
def lock(q):g=glob(q);q[RH]=R.from_matrix(g[par[RH]][:3,:3]).inv()*hand
for q in [ri,ra,hi,rr,reloadq]:lock(q)
bones=[i for i in j['skins'][0]['joints'] if j['nodes'][i].get('name')!='WeaponMount'];upper={N[x] for x in ['Spine','Chest','UpperChest','Neck','Head','LeftShoulder','LeftUpperArm','LeftLowerArm','LeftHand','RightShoulder','RightUpperArm','RightLowerArm','RightHand']}
for side in ['Left','Right']:
 for f in ['ThumbMetacarpal','ThumbProximal','ThumbDistal','IndexProximal','IndexIntermediate','IndexDistal','MiddleProximal','MiddleIntermediate','MiddleDistal','RingProximal','RingIntermediate','RingDistal','LittleProximal','LittleIntermediate','LittleDistal']:upper.add(N[side+f])
def emit(name,times,Q,P):
 ia=add(times,'SCALAR');sam=[];ch=[]
 for i in bones:
  io=add([q[i].as_quat() for q in Q],'VEC4');sam.append({'input':ia,'output':io,'interpolation':'LINEAR'});ch.append({'sampler':len(sam)-1,'target':{'node':i,'path':'rotation'}})
 for i in [N['Root'],N['Hips']]:
  io=add([p.get(i,rest(i)[0]) for p in P],'VEC3');sam.append({'input':ia,'output':io,'interpolation':'LINEAR'});ch.append({'sampler':len(sam)-1,'target':{'node':i,'path':'translation'}})
 j['animations']=[a for a in j['animations'] if a.get('name')!=name];j['animations'].append({'name':name,'samplers':sam,'channels':ch})
def static(n,q):emit(n,np.array([0,1],dtype='f4'),[q,q],[{},{}])
def blend(q0,q1,u):return {i:Slerp([0,1],R.from_quat([q0[i].as_quat(),q1[i].as_quat()]))([u])[0] for i in q0}
for n,q in [('RifleIdle',ri),('RifleAim',ra),('HeavyIdle',hi)]:static(n,q)
def layer(n,lower,upr,hw):
 m=amap(lower);times=next(iter(m.values()))[0];Q=[];P=[]
 for t in times:
  q,p=sample(lower,float(t));q={i:(upr[i] if i in upper else q[i]) for i in q};g=glob(q,p);q[RH]=R.from_matrix(g[par[RH]][:3,:3]).inv()*hw;Q.append(q);P.append(p)
 emit(n,times,Q,P)
pi,_=sample('PistolIdle',.7);ph=R.from_matrix(glob(pi)[RH][:3,:3]);layer('PistolWalk','Walking',pi,ph);layer('PistolRun','Running',pi,ph);layer('RifleWalk','Walking',ri,hand);layer('RifleRun','Running',ri,hand);layer('HeavyWalk','Walking',hi,hand)
idle,_=sample('Idle',0);ig=glob(idle);rel_l=ig[LH][:3,3];gidle=solve(np.array([.22,1.22,-.14]),rel_l);gthrow=solve(np.array([.16,1.39,-.48]),rel_l);midle=solve(np.array([.23,1.15,-.18]),rel_l);mhit=solve(np.array([.10,1.27,-.55]),rel_l)
emit('GrenadeIdle',np.array([0,1],dtype='f4'),[gidle,gidle],[{},{}]);emit('GrenadeThrow',np.array([0,.18,.42],dtype='f4'),[gidle,gthrow,gidle],[{},{},{}]);emit('MeleeIdle',np.array([0,1],dtype='f4'),[midle,midle],[{},{}]);emit('MeleeAttack',np.array([0,.12,.38],dtype='f4'),[midle,mhit,midle],[{},{},{}])
emit('RifleEquip',np.array([0,.2,.5],dtype='f4'),[idle,blend(idle,ri,.5),ri],[{},{},{}]);emit('RifleHolster',np.array([0,.2,.5],dtype='f4'),[ri,blend(ri,idle,.5),idle],[{},{},{}]);emit('RifleFire',np.array([0,.07,.24],dtype='f4'),[ra,rr,ra],[{},{},{}]);emit('HeavyFire',np.array([0,.055,.20],dtype='f4'),[ra,rr,ra],[{},{},{}]);emit('RifleReload',np.array([0,.35,.85,1.25],dtype='f4'),[ri,rr,rr,ri],[{},{},{},{}]);emit('PistolEquip',np.array([0,.18,.42],dtype='f4'),[idle,blend(idle,pi,.5),pi],[{},{},{}]);emit('PistolHolster',np.array([0,.18,.42],dtype='f4'),[pi,blend(pi,idle,.5),idle],[{},{},{}]);pre=pi.copy();pre[RH]=pi[RH]*R.from_rotvec([0,0,.32]);pre[LH]=pi[LH]*R.from_rotvec([0,0,-.18]);emit('PistolReload',np.array([0,.28,.72,1.1],dtype='f4'),[pi,pre,pre,pi],[{},{},{},{}])
j['buffers'][0]['byteLength']=len(b);js=json.dumps(j,separators=(',',':')).encode();js+=b' '*((-len(js))%4);b+=b'\0'*((-len(b))%4);P.write_bytes(struct.pack('<4sII',b'glTF',2,12+8+len(js)+8+len(b))+struct.pack('<II',len(js),0x4e4f534a)+js+struct.pack('<II',len(b),0x004e4942)+b);print('WEAPON_SET',len(j['animations']),P.stat().st_size)
