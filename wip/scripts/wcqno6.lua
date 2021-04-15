-- title:  WCQ No.6
-- author: mieki256
-- desc:   Worst Cheap Quality Shoot 'em up exapmle No.6
-- script: lua

scrw,scrh=240,136

-- --------------------
-- sprite class

Sprite={}
Sprite.new=function(_x,_y,_spd,_ang,_hitr,_sprid,_colkey,_cw,_ch)
 local ra = math.rad(_ang)
 local o={
  alive=true,
  x=_x,y=_y, spd=_spd, ang=_ang,
  dx=_spd * math.cos(ra),
  dy=_spd * math.sin(ra),
  colli={_x,_y,_hitr},
  sprid=_sprid,colkey=_colkey,
  flip=0,rot=0,visible=true,t=0
 }
 o.cw=_cw or 1
 o.ch=_ch or 1
 o.ox=-(8 * o.cw / 2)
 o.oy=-(8 * o.ch / 2)
 return setmetatable(o,{__index=Sprite})
end

Sprite.move=function(self)
 self.x=self.x+self.dx
 self.y=self.y+self.dy
 self.colli[1]=self.x
 self.colli[2]=self.y
end

Sprite.scrchk=function(self,_w,_h)
 local w = _w or (self.cw * 8 / 2)
 local h = _h or (self.ch * 8 / 2)
 if self.x < -w or scrw + w < self.x or
    self.y < -h or scrh + h < self.y then
  self.alive=false
 end
end

Sprite.update=function(self)
 self:move()
 self:scrchk()
end

Sprite.draw=function(self)
 if not self.visible then return end
 spr(self.sprid,
     self.x + self.ox, self.y + self.oy,
     self.colkey,1,self.flip,self.rot,
     self.cw,self.ch)
end

Sprite.hit=function(self,o)
end

Sprite.shot=function(self,o)
end

-- --------------------
-- Player class

Player={}
Player.new=function()
 local o={alive=true}
 return setmetatable(o,{__index=Player})
end

Player.init=function(self)
 self.step = 0
 self.x = scrw / 5
 self.y = scrh / 2
 self.life = 3
 self.sprid = 5
 self.t = 0
 self.dead = false
 self.nodamage = 0
 self.shott = 0
 self.colli={self.x,self.y,1}
end

Player.update=function(self)
 if self.step ==0 then
  if self.nodamage > 0 then
   self.nodamage=self.nodamage-1
  end
  if self.dead then
   -- start dead
   self.step=1
   self.t=0
   self.sprid=32
   if self.life > 0 then
    self.life=self.life-1
   end
   sfx(2,"G-2")
   -- music(1,-1,-1,false)
  else
   -- normal
   local spd=2.0
   local dx,dy=0,0
   if btn(0) then dy=-spd end
   if btn(1) then dy=spd end
   if btn(2) then dx=-spd end
   if btn(3) then dx=spd end
   if dx~=0 and dy~=0 then
    local d=math.cos(math.rad(45))
    dx=dx*d
    dy=dy*d
   end
   self.x=self.x+dx
   self.y=self.y+dy
   self.x=math.min(math.max(self.x,8),scrw-8)
   self.y=math.min(math.max(self.y,8),scrh-8)
   self.colli[1]=self.x
   self.colli[2]=self.y

   -- shot
   if btnp(4) then self.shott=0 end
   if btn(4) and self.shott%7==0 then
    local x,y=self.x,self.y
    spd=6
    table.insert(bullets,Bullet.new(x+10,y,spd,0))
    -- table.insert(bullets,Bullet.new(x,y,spd,12))
    -- table.insert(bullets,Bullet.new(x,y,spd,-12))
    -- table.insert(bullets,Bullet.new(x,y,spd,180))
   end
  end
 elseif self.step==1 then
  -- dead effect
  self.sprid=32+2*(self.t % 16 // 8)
  if self.t>=90 then
   self.dead=false
   self.step=0
   self.nodamage=180
   self.sprid=5
  end
 end
 self.shott=self.shott+1
 self.t=self.t+1
end

Player.draw=function(self)
 if self.step==0 then
  if self.nodamage>0 and
     (self.nodamage>>2)%2==0 then
   return
  end
 end
 spr(self.sprid,self.x-8,self.y-8,
     14,1,0,0,2,2)
end

Player.hit=function(self,o)
 if self.nodamage<=0 then
  self.dead=true
 end
end

Player.shot=function(self,o)
end

-- --------------------
-- Bullet class, super class : Sprite

Bullet={}
setmetatable(Bullet,{__index=Sprite})
Bullet.new=function(_x,_y,_spd,_ang)
 local o=Sprite.new(_x,_y,_spd,_ang,5,7,0,1,1)
 return setmetatable(o,{__index=Bullet})
end

Bullet.update=function(self)
 self:move()
 self:scrchk()
end

Bullet.shot=function(self,o)
 self.alive=false
end

-- --------------------
-- Enemy Bullet class, super class : Sprite

Ebullet={}
setmetatable(Ebullet,{__index=Sprite})
Ebullet.new=function(_x,_y,_spd,_ang,_sprid)
 local o=Sprite.new(_x,_y,_spd,_ang,1,14,0,1,1)
 o.bsprid=_sprid
 return setmetatable(o,{__index=Ebullet})
end

Ebullet.update=function(self)
 self:move()
 self:scrchk()
 self.sprid=self.bsprid+(self.t%10//5)
 self.t=self.t+1
end

Ebullet.shot=function(self,o)
 self.alive=false
end

function bornEBulletToPlayer(x,y,spd,d)
 local dx, dy = player.x - x, player.y - y
 local ang=math.deg(math.atan2(dy,dx))
 if dx*dx+dy*dy>d*d then
  local o = Ebullet.new(x,y,spd,ang,14)
  table.insert(ebullets,o)
 end
 return ang
end

function bornEBullet(x,y,spd,ang)
 local o = Ebullet.new(x,y,spd,ang,14)
 table.insert(ebullets,o)
end

function bornEBulletLaser(x,y,spd,ang)
 local o = Ebullet.new(x,y,spd,ang,144)
 table.insert(ebullets,o)
end

function bornDeathBullet(x,y)
 if stgpass==0 then return end
 local dx, dy = player.x - x, player.y - y
 local d=48
 if dx*dx+dy*dy<d*d then return end
 local spd, ang
 spd = 1.2 + 0.2 * stgpass
 ang = bornEBulletToPlayer(x,y,spd,48)
 if stgpass>=2 then
  for i=1,stgpass-1 do
   local a=ang+math.random(-20,20)
   if a~=ang then bornEBullet(x,y,spd,a) end
  end
 end
end

-- --------------------
-- Mob enemy class, super class : Sprite

Mob={}
setmetatable(Mob,{__index=Sprite})
Mob.new=function(_x,_y,_spd,_ang)
 local o=Sprite.new(_x,_y,_spd,_ang,6,36,14,2,2)
 o.shotwait=math.random(30,90)
 o.shotwaitnext=90
 return setmetatable(o,{__index=Mob})
end

Mob.shot=function(self)
 if not self.alive then return end
 if self.shotwait <= 0 then
  self.shotwait=self.shotwaitnext
  bornEBulletToPlayer(self.x,self.y,1.6,80)
 end
 self.shotwait=self.shotwait-1
end

Mob.update=function(self)
 if not self.alive then return end
 self:move()
 self:scrchk(32,32)
 self:shot()
 self.t=self.t+1
end

Mob.hit=function(self,o)
 self.alive=false
 addScore(10)
 bornExplo(self.x,self.y)
 bornDeathBullet(self.x,self.y)
end

-- --------------------
-- MobA enemy class, super class : Mob

MobA={}
setmetatable(MobA,{__index=Mob})
MobA.new=function(_x,_y,_spd,_ang,_r)
 local o=Mob.new(_x,_y,_spd,180)
 o.sprid=1
 o.by=_y
 o.ang=_ang
 o.r=_r
 o.shotwaitnext=180
 return setmetatable(o,{__index=MobA})
end

MobA.update=function(self)
 if not self.alive then return end
 self.x=self.x+self.dx
 self.y=self.by+self.r*math.sin(math.rad(self.ang))
 self.colli[1]=self.x
 self.colli[2]=self.y
 self.ang=(self.ang+3.5)%360
 if self.x<-32 then self.alive=false end
 self:shot()
 self.t=self.t+1
end

-- --------------------
-- MobB enemy class, super class : Mob

MobB={}
setmetatable(MobB,{__index=Mob})
MobB.new=function(_x,_y,_spd,_ang)
 local o=Mob.new(_x,_y,_spd,_ang)
 o.sprid=38
 return setmetatable(o,{__index=MobB})
end

MobB.update=function(self)
 if not self.alive then return end
 local tx,ty,d,dd
 tx = player.x  - self.x
 ty = player.y  - self.y
 d = self.dx * ty - self.dy * tx
 dd = 0
 if d > 0 then dd = 2
 elseif d < 0 then dd = -2 end
 if dd ~= 0 then
  self.ang = (self.ang + dd) % 360
 end
 local ra = math.rad(self.ang)
 self.dx = self.spd * math.cos(ra)
 self.dy = self.spd * math.sin(ra)
 self:move()
 self:scrchk(32,32)
 self:shot()
 self.t=self.t+1
end

-- --------------------
-- MobC enemy class, super class : Mob

MobC={}
setmetatable(MobC,{__index=Mob})
MobC.new=function(_x,_y)
 local o=Mob.new(_x,_y,0,0)
 o.sprid=40
 o.dx=8.0
 o.ax=0.135
 local tt=o.dx/o.ax
 local yd=(scrh/2)+((scrh/2)-o.y)
 o.dy = (yd - o.y) / (tt * 2)
 o.shotwait = tt - 30
 return setmetatable(o,{__index=MobC})
end

MobC.update=function(self)
 if not self.alive then return end
 self.dx=self.dx-self.ax
 self.flip = (self.dx >= 2.5) and 0 or 1
 self:move()
 self:scrchk(32,32)
 self:shot()
 self.t=self.t+1
end

-- --------------------
-- Middle boss class

Midboss={}
Midboss.new=function(_x,_y,_tx,_ty)
 local o={
  alive=true,x=_x,y=_y,dx=0,dy=0,
  tx=_tx,ty=_ty,
  step=0,t=0,shott=0,
  colli={_x,_y,15},
  sprid=64,hp=15,
  dmgeff=0,dmgox=0,dmgoy=0
 }
 return setmetatable(o,{__index=Midboss})
end

Midboss.update=function(self)
 if self.step==0 then
  -- enter the stage
  local xd,yd
  xd=self.tx-self.x
  yd=self.ty-self.y
  self.dx=xd*0.05
  self.dy=yd*0.05
  if self.t >= 60 then
   self.step=1
   self.t=0
   self.shott=0
  end
 elseif self.step==1 then
  -- shot
  local tt = self.shott % 60
  if tt<20 then
   if tt%4==0 then
    bornEBullet(self.x-4*8,self.y,4,180)
   end
  elseif tt==30 then
   for i=0,6 do
    bornEBullet(self.x-4*8,self.y,2,180+12*(-3+i))
   end
  end
  self.shott = self.shott + 1
  if self.t>=60*4 then
   self.step=2
  end
 elseif self.step==2 then
  -- exit move
  self.dx=math.max(self.dx-0.02, -3)
  if self.x<-4*8 then self.alive=false end
 end
 self.x=self.x+self.dx
 self.y=self.y+self.dy
 self.colli[1]=self.x
 self.colli[2]=self.y
 self.t=self.t+1
 
 if self.dmgeff>0 then
  self.dmgox=math.random(-2,2)
  self.dmgoy=math.random(-2,2)
  self.dmgeff=self.dmgeff-1
 else
  self.dmgox=0
  self.dmgoy=0
 end
end

Midboss.draw=function(self)
 local x,y
 x = self.x-32 + self.dmgox
 y = self.y + self.dmgoy
 spr(self.sprid,x,y-16,14,1,0,0,8,2)
 spr(self.sprid,x,y,14,1,2,0,8,2)
end

Midboss.hit=function(self,o)
 self.hp=self.hp-1
 self.dmgeff=5
 if self.hp<=0 then
  self.alive=false
  addScore(200)
  bornExplo(self.x, self.y, 48)
  bornExplo(self.x, self.y, 32)
  bornDeathBullet(self.x,self.y)
 end
end

Midboss.shot=function(self,o)
end

-- --------------------
-- Stage1 Boss class

Stg1boss={}
Stg1boss.new=function(_x,_y)
 local o={
  alive=true,step=0,t=0,
  x=_x,y=_y,dx=-1,dy=0,bx=0,by=0,
  sprid=102,visible=true,
  colli={_x,_y,28},
  dmgox=0,dmgoy=0,dmgeff=0,
  hpmax=100
 }
 o.hp=o.hpmax
 
 -- arms init
 o.armsr={}
 o.armsl={}
 local n=12
 for i=1,n do
  local col, cor
  if i==n then
   cor={sprid=96,w=4,h=2,x=0,y=0,ang=270,r=8,ox=-24,oy=-8}
   col={sprid=96,w=4,h=2,x=0,y=0,ang= 90,r=8,ox=-24,oy=-8}
  elseif i==1 then
   cor={sprid=149,w=1,h=1,x=0,y=0,ang=270,r=8,ox=-4,oy=-4}
   col={sprid=149,w=1,h=1,x=0,y=0,ang= 90,r=8,ox=-4,oy=-4}
  else
   cor={sprid=149,w=1,h=1,x=0,y=0,ang=270,r=5,ox=-4,oy=-4}
   col={sprid=149,w=1,h=1,x=0,y=0,ang= 90,r=5,ox=-4,oy=-4}
  end
  table.insert(o.armsr,cor)
  table.insert(o.armsl,col)
 end
 return setmetatable(o,{__index=Stg1boss})
end

Stg1boss.armsUpdate=function(self,arms,px,py,v,ba)
 if self.step<=1 then
  local a=(t * 2) % 360
  local d = v * math.sin(math.rad(a))
  arms[1].ang = ba + d * 1.5
  local pa=arms[1].ang
  for i,o in ipairs(arms) do
   o.ang = pa - (v/5) * math.sin(math.rad((a+30) % 360))
   pa = o.ang
  end
  if self.step==1 and self.t % 13 == 0 then
   local x,y
   x=arms[#arms].x-24
   y=arms[#arms].y
   bornEBulletLaser(x,y,2,180)
  end
 end
 
 for i,o in ipairs(arms) do
  local x,y,ra
  ra = math.rad(o.ang)
  x = px + o.r * math.cos(ra)
  y = py + o.r * math.sin(ra)
  o.x, o.y = x, y
  px, py = x, y
 end
end

Stg1boss.bornShot=function(self)
 local x,y,a,d
 x = self.x - 20
 y = self.y
 d = 90 / 6
 for i=0,6 do
  a = 180 - d * 3 + d * i
  bornEBullet(x,y,2.5,a)
 end
end

Stg1boss.update=function(self)
 if self.step==0 then
  self.x=self.x+self.dx
  self.y=self.y+self.dy
  if self.x<=scrw-4-32 then
   self.dx=0
   self.dy=0
   self.bx=self.x
   self.by=self.y
   self.t=0
   self.step=1
  end
 elseif self.step==1 then
  -- attack
  self.x = math.floor(self.bx - 24*math.sin(math.rad((self.t*3)%360)))
  self.y = math.floor(self.by + (scrh/2-8)*math.sin(math.rad((self.t*2)%360)))
  
  if self.t % 110 == 0 then
   self:bornShot()
  end
  
  if self.dmgeff > 0 then  
   local r=2
   self.dmgox=math.random(-r,r)
   self.dmgoy=math.random(-r,r)
   self.dmgeff=self.dmgeff-1
  else
   self.dmgox=0
   self.dmgoy=0
  end
 elseif self.step==2 then
  -- dead demo
  local r=5
  self.dmgox=math.random(-r,r)
  self.dmgoy=math.random(-r,r)
  if self.t%2==0 then
   local x,y
   r=32
   x=self.x+math.random(-r,r)
   y=self.y+math.random(-r,r)
   bornExploFg(x,y,16)
   if self.t%10==0 then
    local sfxpat={"G-1","B-2","C-3"}
    sfx(1,sfxpat[math.random(1,3)])
   end
  end
  if self.t>=60*3 then
   self.alive=false
   bornExploFg(self.x, self.y, 128)
   music(4,0,-1,false)
   stgclrfg=true
  end
 end
 self.colli[1]=self.x
 self.colli[2]=self.y
 
 local px,py
 px,py = self.x-22, self.y-23
 self:armsUpdate(self.armsr,px,py,90,180)
 px,py = self.x-22, self.y+23-1
 self:armsUpdate(self.armsl,px,py,-90,180)
 
 self.t=self.t+1
end

Stg1boss.armsDraw=function(self,_arms,_ox,_oy)
 local x,y
 for i,o in ipairs(_arms) do
  x = o.x + o.ox + _ox
  y = o.y + o.oy + _oy
  spr(o.sprid,x,y,14,1,0,0,o.w,o.h)
 end
end

Stg1boss.draw=function(self)
 if self.visible then
  -- draw body
  local x,y
  x=self.x-4*8+self.dmgox
  y=self.y+self.dmgoy
  spr(self.sprid,x,y-4*8,14,1,0,0,8,4)
  spr(self.sprid,x,y,14,1,2,0,8,4)
  -- draw arm
  self:armsDraw(self.armsr,self.dmgox,self.dmgoy)
  self:armsDraw(self.armsl,self.dmgox,self.dmgoy)
 end
 
 if self.hp > 0 then
  local x,y,w,c
  y = 8
  w = print("BOSS:",2,y)
  x = w + 4
  w = (scrw / 2) - w - 4
  rect(x,y,w,5,2)
  w = (w-2) * self.hp / self.hpmax
  c=(self.hp > self.hpmax * 0.2) and 15 or 6
  rect(x+1,y+1,w,3,c)
 end
end

Stg1boss.hit=function(self,o)
 if self.step~=1 then return end
 if self.hp<=0 then return end
 self.hp=self.hp-1
 self.dmgeff=5
 if self.hp<=0 then
  addScore(1000)
  self.dy=0
  self.t=0
  self.step=2
  music()
  clearEBullets()
 end
end

Stg1boss.shot=function(self,o)
end

-- --------------------
-- Explosion effect class

Explosion={}
Explosion.new=function(_x,_y,_r)
 local o={
  alive=true,x=_x,y=_y,t=0,
  cols={15,15,9,6,0},
  sfxpat={"G-3","B-3","C-3"}
 }
 o.r = _r or 20
 o.br = o.r
 o.pos={}
 return setmetatable(o,{__index=Explosion})
end

Explosion.update=function(self)
 local x,y,r,c,rr
 self.r=self.r-1
 c = self.cols[self.t % (#self.cols) + 1]
 rr = math.floor(math.max(self.br*0.4, 6))
 self.pos={}
 for i=1,3 do
  x = self.x + math.random(-rr,rr)
  y = self.y + math.random(-rr,rr)
  r = math.max(2, self.r / i)
  -- c = self.cols[(self.t + i - 1) % (#self.cols) + 1]
  table.insert(self.pos,{x,y,r,c})
 end
 if self.r<3 then self.alive=false end
 self.t=self.t+1
end

Explosion.draw=function(self)
 local x,y,r,c
 for i=1,3 do
  x=self.pos[i][1]
  y=self.pos[i][2]
  r=self.pos[i][3]
  c=self.pos[i][4]
  circ(x,y,r,c)
 end
end

function bornExplo(_x,_y,_r)
 local sfxpat={"C-4","E-3","C-5"}
 sfx(1,sfxpat[math.random(1,#sfxpat)])
 local o=Explosion.new(_x,_y,_r)
 table.insert(effects,o)
end

function bornExploFg(_x,_y,_r)
 local o=Explosion.new(_x,_y,_r)
 table.insert(effects_fg,o)
end

-- --------------------
-- star

Star={}
Star.new=function(_x,_y,_spd,_id)
 local o={x=_x,y=_y,spd=_spd,sprid=1}
 o.sprid = 44 + _id
 return setmetatable(o,{__index=Star})
end

Star.update=function(self)
 self.x = self.x - self.spd
 if self.x <= -8 then self.x = self.x + scrw end
end

Star.draw=function(self)
 spr(self.sprid,self.x,self.y,0,1,0,0,1,1)
end

function initStar()
 local tbl={1.6, 0.8, 0.4, 0.2}
 for y=8,scrh-1,1 do
  local x,id,spd
  x = math.random(0,scrw)
  id = math.random(1,#tbl)
  spd = tbl[id]
  -- id = (id - 1) % 4
  id = math.random(0,3)
  table.insert(stars,Star.new(x,y,spd,id))
 end
end

-- --------------------

function objsUpdate(objs)
 for i,o in ipairs(objs) do
  o:update()
 end
end

function objsDraw(objs)
 for i,o in ipairs(objs) do
  o:draw()
 end
end

function objsRemove(objs)
 local l=#objs
 for i=l,1,-1 do
  if not objs[i].alive then
   table.remove(objs,i)
  end
 end
end

-- --------------------
-- Enemy generator

EnemyGenerator={}
EnemyGenerator.new=function()
 local o={}
 o.pnt=1
 o.cbx=0
 o.bx=o.cbx
 return setmetatable(o,{__index=EnemyGenerator})
end

EnemyGenerator.init=function(self)
 self.pnt = 1
 self.bx = self.cbx
end

EnemyGenerator.update=function(self)
 local e, tt
 e=enemytbl[self.pnt]
 tt=e[1]
 while tt <= self.bx do
  local kind=e[2]
  if kind==-2 then break end
  if kind==-1 then
   self:init()
   break
  end
  if tt > self.cbx then
   if kind==0 then
    local x,y,spd,ang
    x,y,spd,ang=e[3],e[4],e[5],e[6]
    local o=Mob.new(x,y,spd,ang)
    table.insert(enemys,o)
   elseif kind==1 then
    local o=MobA.new(e[3],e[4],e[5],e[6],e[7])
    table.insert(enemys,o)
   elseif kind==2 then
    local o=MobB.new(e[3],e[4],e[5],e[6])
    table.insert(enemys,o)
   elseif kind==3 then
    local o=MobC.new(e[3],e[4])
    table.insert(enemys,o)
   elseif kind==4 then
    local o=Midboss.new(e[3],e[4],e[5],e[6])
    table.insert(enemys,o)
   elseif kind==5 then
    local o=Stg1boss.new(e[3],e[4])
    table.insert(enemys,o)
   end
  end
  self.pnt=self.pnt+1
  if self.pnt>#enemytbl then
   self:init()
   break
  end
  e=enemytbl[self.pnt]
  tt=e[1]
 end
 self.bx=self.bx+1
end

enemytbl_dev={
 {20,5,scrw+32+64,scrh/2},
 {40,-2}
}

enemytbl={
 -- Mob
 {20+0*20,0,256,8,1.5,157},
 {20+1*20,0,256,128,1.5,-157},
 {20+2*20,0,256,28,1.8,164},
 {20+3*20,0,256,108,1.8,-164},
 {20+4*20,0,256,48,2.0,172},
 {20+5*20,0,256,88,2.0,-172},
 {20+6*20,0,256,68,2.0,180},
 -- MobA
 {260+0*12,1,252,68,0.9,0,45},
 {260+1*12,1,252,68,0.9,0,45},
 {260+2*12,1,252,68,0.9,0,45},
 {260+3*12,1,252,68,0.9,0,45},
 {260+4*12,1,252,68,0.9,0,45},
 {260+5*12,1,252,68,0.9,0,45},
 -- MobA
 {420+0*12,1,252,98,0.9,0,45},
 {420+1*12,1,252,98,0.9,0,45},
 {420+2*12,1,252,98,0.9,0,45},
 {420+3*12,1,252,98,0.9,0,45},
 {420+4*12,1,252,98,0.9,0,45},
 {420+5*12,1,252,98,0.9,0,45},
 -- MobB
 {550+0*20,2,248,16,1.3,180},
 {550+0*20,2,248,120,1.3,180},
 {550+2*20,2,248,16,1.3,180},
 {550+2*20,2,248,120,1.3,180},
 -- MobC
 {730+0*30,3,-8,8},
 {730+1*30,3,-8,20},
 {730+2*30,3,-8,32},
 -- MobC
 {900+0*30,3,-8,scrh-8},
 {900+1*30,3,-8,scrh-20},
 {900+2*30,3,-8,scrh-32},
 -- Midboss
 {1100+0*180,4,scrw-32-64,-16,scrw-32-8,(scrh/2)-16},
 {1100+1*180,4,scrw-32-64,scrh+16,scrw-32-8,(scrh/2)+16},
 -- Mob
 {1500+0*8,0,8+5*40,144,1.2,270},
 {1500+1*8,0,8+4*40,144,1.2,270},
 {1500+2*8,0,8+3*40,144,1.2,270},
 {1500+3*8,0,8+2*40,144,1.2,270},
 {1500+4*8,0,8+1*40,144,1.2,270},
 -- Mob
 {1500+6*8,0,20+5*40,-8,1.5,90},
 {1500+7*8,0,20+4*40,-8,1.5,90},
 {1500+8*8,0,20+3*40,-8,1.5,90},
 {1500+9*8,0,20+2*40,-8,1.5,90},
 {1500+10*8,0,20+1*40,-8,1.5,90},
 {1500+11*8,0,20+0*40,-8,1.5,90},
 -- MobA
 {1700+0*12,1,252, 30,1.1, 90,30},
 {1700+0*12,1,252,106,1.1,270,30},
 {1700+1*12,1,252, 30,1.1, 90,30},
 {1700+1*12,1,252,106,1.1,270,30},
 {1700+2*12,1,252, 30,1.1, 90,30},
 {1700+2*12,1,252,106,1.1,270,30},
 {1700+3*12,1,252, 30,1.1, 90,30},
 {1700+3*12,1,252,106,1.1,270,30},
 {1700+4*12,1,252, 30,1.1, 90,30},
 {1700+4*12,1,252,106,1.1,270,30},
 {1700+5*12,1,252, 30,1.1, 90,30},
 {1700+5*12,1,252,106,1.1,270,30},
 -- MobB
 {1960+0*60,2,-8,16,1.4,0},
 {1960+1*60,2,-8,120,1.6,0},
 -- Midboss
 {2100,    4,scrw-32-64,scrh+16,scrw-32-8,(scrh/2)+16},
 {2100+120,2,scrw+8,16,1.2,180},
 {2300,    4,scrw-32-64,-16,scrw-32-8,(scrh/2)-16},
 {2300+120,2,scrw+8,120,1.2,180},

 -- boss
 {2600,5,scrw+32+64,scrh/2},

 -- stop
 {2800,-2}
}

-- --------------------
-- hit check

function hitchkCirc(e,b)
 if not next(e.colli) then return false end
 if not next(b.colli) then return false end
 local x,y,r
 x=e.colli[1]-b.colli[1]
 y=e.colli[2]-b.colli[2]
 r=e.colli[3]+b.colli[3]
 if x*x+y*y <= r*r then return true end
 return false
end

function hitCheck()
 -- enemys with bullet
 for i,e in ipairs(enemys) do
  if e.alive and next(e.colli) then
   for j,b in ipairs(bullets) do
    if b.alive and hitchkCirc(e,b) then
     e:hit(b)
     b:shot(e)
     break
    end
   end
  end
 end

 if player.alive==false or
    not next(player.colli) then
  return
 end

 -- enemys with player
 for i,e in ipairs(enemys) do
  if e.alive and hitchkCirc(player,e) then
   player:hit(e)
   return
  end
 end

 -- enemy bullets with player
 for i,b in ipairs(ebullets) do
  if b.alive and hitchkCirc(player,b) then
   player:hit(b)
   break
  end
 end
end

-- --------------------

function initObjsWork()
 bullets={}
 enemys={}
 ebullets={}
 effects={}
 effects_fg={}
 stars={}
 eg=EnemyGenerator.new()
 initStar()
 stgclrfg=false
end

function clearEBullets()
 ebullets={}
end

function startGame()
  t=0
  bx=0
  music(2)
end

function addScore(a)
 score = score + a
 if score > hiscore then
  hiscore = score
 end
end

function printc(s,y)
 local w=print(s,0,-8)
 local x=(scrw-w)/2
 local sc=0
 print(s,x-1,y,sc)
 print(s,x+1,y,sc)
 print(s,x,y-1,sc)
 print(s,x,y+1,sc)
 print(s,x,y,15)
end

function title_update()
 objsUpdate(stars)
 if btnp(5) then
  score=0
  stgpass=0
  startGame()
  gamestep=1
 end
end

function title_draw()
 printc("WCQ No.6",30)
 printc("MOVE : CURSOR KEY", 90)
 printc("SHOT : Z KEY", 100)
 printc("PUSH X KEY TO START", 120)
end

function gamemain_update()
 objsUpdate(stars)
 eg:update()
 hitCheck()
 objsUpdate(bullets)
 objsUpdate(enemys)
 objsUpdate(ebullets)
 objsUpdate(effects)
 objsUpdate(effects_fg)
 player:update()

 objsRemove(bullets)
 objsRemove(enemys)
 objsRemove(ebullets)
 objsRemove(effects)
 objsRemove(effects_fg)

 if stgclrfg then
  t=0
  gamestep=3
  sstep=0
 elseif player.life <= 0 then
  t=0
  music()
  gamestep=2
 end
 bx=bx+1
end

function gamemain_draw()
 objsDraw(effects)
 objsDraw(bullets)
 objsDraw(enemys)
 objsDraw(effects_fg)
 objsDraw(ebullets)
 player:draw()

 local s="LIFE: "..player.life
 s=s.."  SCORE: "..score
 s=s.."  HI-SCORE: "..hiscore
 -- s=s.."  e:"..#enemys
 -- s=s.."  eb:"..#ebullets
 print(s,2,2)
end

function gameover_update()
 if t >= 150 then
  player:init()
  initObjsWork()
  gamestep=0
 end
end

function gameover_draw()
 printc("GAME OVER",(scrh / 2 - 8))
end

function stageclear_update()
 objsUpdate(stars)
 objsUpdate(bullets)
 objsUpdate(enemys)
 objsUpdate(ebullets)
 objsUpdate(effects)
 objsUpdate(effects_fg)
 player:update()

 objsRemove(bullets)
 objsRemove(enemys)
 objsRemove(ebullets)
 objsRemove(effects)
 objsRemove(effects_fg)

 if sstep==0 then 
  if #enemys==0 and #effects==0 and #effects_fg==0 then
   sstep=1
   t=0
  end
 elseif sstep==1 then
  if t>=150 then
   stgpass=stgpass+1
   initObjsWork()
   startGame()
   gamestep=1
  end
 end
end

function stageclear_draw()
 if sstep==1 then
  printc("STAGE CLEAR",(scrh / 2 - 8))
 end
end

-- init

score=0
hiscore=0
t=0
bx=0
gamestep=0
sstep=0
stgclrfg=false
stgpass=0
player=Player.new()
player:init()
initObjsWork()

-- main loop

function TIC()
 -- update
 if gamestep==0 then title_update()
 elseif gamestep==1 then gamemain_update()
 elseif gamestep==2 then gameover_update()
 elseif gamestep==3 then stageclear_update()
 end

 -- draw
 cls(0)
 objsDraw(stars)
 gamemain_draw()
 if gamestep==0 then title_draw()
 elseif gamestep==2 then gameover_draw()
 elseif gamestep==3 then stageclear_draw()
 end

 t=t+1
end
