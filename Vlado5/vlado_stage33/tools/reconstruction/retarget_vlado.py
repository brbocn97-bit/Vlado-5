#!/usr/bin/env python3
import json,struct
from pathlib import Path
import numpy as np
from scipy.spatial.transform import Rotation as R,Slerp
T=Path('/tmp/vlado_rebuild/Vlado5/vlado_stage33/assets/characters/vlado/Vlado_Sipcic_Final.glb');S=Path('/tmp/vlado_rebuild/cc0/UAL1.glb');O=T.with_name('Vlado_Sipcic_ReRigged.glb')
CL={'A_TPose':'RESET','Idle_Loop':'Idle','Idle_LookAround_Loop':'IdleLook','Walk_Loop':'Walking','Jog_Fwd_Loop':'Running','Sprint_Loop':'Sprinting','Crouch_Idle_Loop':'CrouchIdle','Crouch_Fwd_Loop':'Crouching','Crawl_Enter':'CrawlEnter','Crawl_Exit':'CrawlExit','Crawl_Idle_Loop':'CrawlIdle','Crawl_Fwd_Loop':'Crawling','Jump_Start':'JumpStart','Jump_Loop':'Jumping','Jump_Land':'Landing','Pistol_Idle_Loop':'PistolIdle','Pistol_Aim_Neutral':'PistolAim','Pistol_Shoot':'PistolFire','Pistol_Reload':'PistolReload','Interact':'Interact','PickUp_Kneeling':'Pickup','Hit_Chest':'HitChest','Hit_Head':'HitHead','Death01':'DeathFront','Death02':'DeathBack','Turn90_L':'TurnLeft','Turn90_R':'TurnRight','Roll':'Roll'}
M={'root':'Root','pelvis':'Hips','spine_01':'Spine','spine_02':'Chest','spine_03':'UpperChest','neck_01':'Neck','Head':'Head','clavicle_l':'LeftShoulder','upperarm_l':'LeftUpperArm','lowerarm_l':'LeftLowerArm','hand_l':'LeftHand','clavicle_r':'RightShoulder','upperarm_r':'RightUpperArm','lowerarm_r':'RightLowerArm','hand_r':'RightHand','thigh_l':'LeftUpperLeg','calf_l':'LeftLowerLeg','foot_l':'LeftFoot','ball_l':'LeftToes','thigh_r':'RightUpperLeg','calf_r':'RightLowerLeg','foot_r':'RightFoot','ball_r':'RightToes'}
for s,t in [('index','Index'),('middle','Middle'),('pinky','Little'),('ring','Ring')]:
 for side,Side in [('l','Left'),('r','Right')]:
  for n,N in [('01','Proximal'),('02','Intermediate'),('03','Distal')]:M[f'{s}_{n}_{side}']=f'{Side}{t}{N}'
for side,Side in [('l','Left'),('r','Right')]:
 for n,N in [('01','Metacarpal'),('02','Proximal'),('03','Distal')]:M[f'thumb_{n}_{side}']=f'{Side}Thumb{N}'
def load(p):
 b=p.read_bytes();o=12;j=None;bn=b''
 while o<len(b):
  n,t=struct.unpack_from('<II',b,o);o+=8;c=b[o:o+n];o+=n
  if t==0x4e4f534a:j=json.loads(c.decode().rstrip('\0 \t\r\n'))
  elif t==0x004e4942:bn=c
 return j,bytearray(bn)
def A(j,b,i):
 a=j['accessors'][i];v=j['bufferViews'][a['bufferView']];dt=np.dtype({5121:'u1',5123:'<u2',5125:'<u4',5126:'<f4'}[a['componentType']]);nn={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']];st=v.get('byteStride',dt.itemsize*nn);q=v.get('byteOffset',0)+a.get('byteOffset',0);return np.ndarray((a['count'],nn),dtype=dt,buffer=b,offset=q,strides=(st,dt.itemsize)).copy()
def parents(j):return {c:i for i,n in enumerate(j['nodes']) for c in n.get('children',[])}
def loc(n):return np.array(n.get('translation',[0,0,0]),float),R.from_quat(n.get('rotation',[0,0,0,1])),np.array(n.get('scale',[1,1,1]),float)
def rests(j):
 p=parents(j);m={}
 def f(i):
  if i in m:return m[i]
  t,r,s=loc(j['nodes'][i]);x=np.eye(4);x[:3,:3]=r.as_matrix()@np.diag(s);x[:3,3]=t;m[i]=f(p[i])@x if i in p else x;return m[i]
 return {i:f(i) for i in range(len(j['nodes']))}
def mr(x):return R.from_matrix(x[:3,:3]/np.linalg.norm(x[:3,:3],axis=0))
def ip(ts,v,t,rot=False):
 t=np.clip(t,ts[0],ts[-1]);return Slerp(ts,R.from_quat(v))([t])[0].as_quat() if rot and len(ts)>1 else (v[0] if rot else np.array([np.interp(t,ts,v[:,k]) for k in range(v.shape[1])]))
def add(j,b,a,typ):
 a=np.asarray(a,dtype='<f4');b.extend(b'\0'*((-len(b))%4));o=len(b);z=a.tobytes();b.extend(z);vi=len(j['bufferViews']);j['bufferViews'].append({'buffer':0,'byteOffset':o,'byteLength':len(z)});ai=len(j['accessors']);d={'bufferView':vi,'componentType':5126,'count':len(a),'type':typ};
 if typ=='SCALAR':d.update(min=[float(a.min())],max=[float(a.max())])
 j['accessors'].append(d);return ai
tj,tb=load(T);sj,sb=load(S);tn={n.get('name'):i for i,n in enumerate(tj['nodes'])};sn={n.get('name'):i for i,n in enumerate(sj['nodes'])};tp=parents(tj);sp=parents(sj);tr=rests(tj);sr=rests(sj);pairs={sn[s]:tn[t] for s,t in M.items()};rev={v:k for k,v in pairs.items()};bones=[i for i in tj['skins'][0]['joints'] if tj['nodes'][i].get('name')!='WeaponMount'];scale=.7485044519620341;an=[]
for sa in sj['animations']:
 old=sa.get('name');
 if old not in CL:continue
 tracks={};dur=0
 for c in sa['channels']:
  sm=sa['samplers'][c['sampler']];ts=A(sj,sb,sm['input']).reshape(-1);tracks[(c['target']['node'],c['target']['path'])]=(ts,A(sj,sb,sm['output']));dur=max(dur,float(ts[-1]))
 times=np.linspace(0,dur,max(2,round(dur*30)+1),dtype=np.float32);qo={i:[] for i in bones};po={tn['Root']:[],tn['Hips']:[]}
 for tm in times:
  sl={}
  for i,n in enumerate(sj['nodes']):
   t,r,s=loc(n)
   if (i,'translation') in tracks:t=ip(*tracks[(i,'translation')],tm)
   if (i,'rotation') in tracks:r=R.from_quat(ip(*tracks[(i,'rotation')],tm,True))
   sl[i]=(t,r,s)
  sg={}
  def F(i):
   if i in sg:return sg[i]
   t,r,s=sl[i];x=np.eye(4);x[:3,:3]=r.as_matrix()@np.diag(s);x[:3,3]=t;sg[i]=F(sp[i])@x if i in sp else x;return sg[i]
  dg={}
  def G(i):
   if i in dg:return dg[i]
   x=tr[i].copy()
   if i in rev:
    si=rev[i];rs=mr(sr[si]);rt=mr(tr[i]);ra=mr(F(si));al=rt*rs.inv();ds=ra*rs.inv();x[:3,:3]=(al*ds*al.inv()*rt).as_matrix()
    if tj['nodes'][i].get('name') in ('Root','Hips'):
     ar=mr(tr[tn['Root']])*mr(sr[sn['root']]).inv();x[:3,3]=tr[i][:3,3]+ar.apply(F(si)[:3,3]-sr[si][:3,3])*scale
   dg[i]=x;return x
  for i in bones:
   L=np.linalg.inv(G(tp[i]))@G(i) if i in tp else G(i);qo[i].append(mr(L).as_quat())
  for i in po:
   L=np.linalg.inv(G(tp[i]))@G(i) if i in tp else G(i);po[i].append(L[:3,3])
 ia=add(tj,tb,times,'SCALAR');sam=[];ch=[]
 for i in bones:
  io=add(tj,tb,qo[i],'VEC4');sam.append({'input':ia,'output':io,'interpolation':'LINEAR'});ch.append({'sampler':len(sam)-1,'target':{'node':i,'path':'rotation'}})
 for i in po:
  io=add(tj,tb,po[i],'VEC3');sam.append({'input':ia,'output':io,'interpolation':'LINEAR'});ch.append({'sampler':len(sam)-1,'target':{'node':i,'path':'translation'}})
 an.append({'name':CL[old],'samplers':sam,'channels':ch});print(old,'->',CL[old])
tj['animations']=an;tj['buffers'][0]['byteLength']=len(tb);js=json.dumps(tj,separators=(',',':')).encode();js+=b' '*((-len(js))%4);tb+=b'\0'*((-len(tb))%4);O.write_bytes(struct.pack('<4sII',b'glTF',2,12+8+len(js)+8+len(tb))+struct.pack('<II',len(js),0x4e4f534a)+js+struct.pack('<II',len(tb),0x004e4942)+tb);print('WROTE',O,len(an))
