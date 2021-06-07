-- title:  GALAGA-GB
-- author: sin_sin
-- desc:   Galaga clone GameBoy version style.
-- script: lua
-- pal: 000000525252acacac8b838b000000ff3152ffe65229de290000007b73e6b4c5ffa4a4a4101010bd20202929deffffff

-- global constants
local SW,SH=240,136
local HUDW=80
local VW,VH=SW-HUDW,SH
-- color names of current palette
local pal={
	black=0,white=15,space=12,
	red=13,blue=14,green=7,
	yellow=6,pink=5,water=9,
	cyan=10,gray=1,silver=2,
}
-- button/key names
local bkn={
	up=0,down=1,left=2,right=3,
	z=4,x=5,a=6,s=7,
}
-- music/sfx names
local msn={
	takeoff=0,
}
-- global variables
local var={}
-- entity components
local ec={}
-- function shortcuts
local int,rnd=math.floor,math.random
local format=string.format
local inst=table.insert

function clamp(v,min,max)
	v=v or min or 0
	if min and v<min then v=min end
	if max and v>max then v=max end
	return v
end

function warp(v,min,max)
	v=v or min or 0
	if min and v<min then
		v=v+(max or min)-(min or 0)
	end
	if max and v>max then
		v=v-(max or min)-(min or 0)
	end
	return v
end

function swpPal(sc,tc)
	if not sc then
		for i=0,15 do poke4(0x3FF0*2+i,i) end
	else
		sc=sc%16
		if not tc then tc=sc else tc=tc%16 end
		poke4(0x3FF0*2+sc,tc)
	end
end

function printf(t,x,y,c)
	-- replace 15 white with specified
	if c and c~=15 then swpPal(15,c) end
	local w=font(t,x,y,pal.space,8,8,true)
	swpPal(15)
	return w
end

function printc(t,y,c)
	local w=printf(t,0,-8)
	local x=(VW-w)//2
	return printf(t,x,y,c)
end

function toScene(state,initFn)
	local prevst=var.state
	var.state=state
	var.stime=time()
	if type(initFn)=="function" then
		initFn(prevst)
	end
end

function elapsed(ms,st)
	return time()-(st or var.stime)>=(ms or 0)
end

function init()
	var.debug=true
	var.tick=0
	var.flashDur=0
	var.flashFreq=4
	toScene("title",initTitle)
end

function initStars(f)
	if not f and ec.stars~=nil then
		return
	end
	ec.stars={}
	local spd={1,0.6,0.3}
	for i=0,VW//3 do
		local s={
			x=rnd(0,VW),
			y=rnd(0,VH),
			mt=rnd(1,1),     -- move ticks
			bt=rnd(0,30),    -- blink ticks
			si=rnd(1,5)+256, -- sprite index
			vy=spd[rnd(1,#spd)],
			sh=true,         -- show or not
		}
		inst(ec.stars,s)
	end
end

function initGame()
	ec.player={}
	local pl=ec.player
	-- sprite definitions
	pl.spd={
		-- sprite index, scale, flip, rotate,
		-- sprite width & height
		id=96,sc=1,fl=0,ro=0,sw=2,sh=2,
		-- offset x & y, pixel width & height
		ox=3,oy=2,w=11,h=12,
	}
	pl.x=VW//2-pl.spd.w//2
	pl.y=VH-pl.spd.h-8
	pl.vx,pl.vy=1,1
	pl.shot=false
	pl.shotInterval=15
	pl.shotTick=0

	ec.missiles={}
	for i=1,2 do
		inst(ec.missiles,{
			spd={
				id=106,sc=1,fl=0,ro=0,sw=1,sh=1,
				ox=4,oy=0,w=1,h=5,
			},
			sh=false,mv=false,
			x=0,y=0,vx=0,vy=0,
			mvx=3,mvy=3,
		})
	end

	var.stats={
		stage=1,life=3,score=0,
		shot=0,hit=0,rate=0,
	}
	var.gamest=true
end

function initStage(fs)
	music()
	initStars()
	initGame()
end

function updateStars(t,mod)
	for i,s in ipairs(ec.stars) do
		if t%s.mt==0 then
			s.y=warp(s.y+(s.vy*(mod or 1)),0,VH)
		end
	end
end

function updatePlayer(t)
	local p=ec.player
	local dvy,dx=0,0
	if btnp(bkn.s) then reset() end
	if btnp(bkn.a) then var.flashDur=30 end
	if btnp(bkn.up) then dvy=1 end
	if btnp(bkn.down) then dvy=-1 end
	if btn(bkn.left) then dx=-p.vx end
	if btn(bkn.right) then dx=p.vx end
	p.vy=clamp(p.vy+dvy,-3,3)
	p.x=clamp(p.x+dx,0,VW-p.spd.w)
	p.shot=false
	p.shotTick=clamp(p.shotTick-1,0)
	if btn(bkn.z) or btn(bkn.x) then p.shot=true end
end

function updateMissiles(t)
	local p=ec.player
	for i,m in ipairs(ec.missiles) do
		if m.mv then
			m.x=clamp(m.x+m.vx,0,VW-m.spd.w)
			m.y=clamp(m.y+m.vy,0,VH-m.spd.h)
			if m.x<=0 or m.y<=0 or
				m.x>=VW-m.spd.w or m.y>=VH-m.spd.h then
				m.mv,m.sh=false,false
			end
		elseif p.shot and p.shotTick<1 then
			m.x,m.y=p.x+p.spd.w//2,p.y
			m.vx,m.vy=0,-m.mvy
			m.mv,m.sh=true,true
			p.shotTick=p.shotInterval
		end
	end
end

function updateEntities(t)
	updateStars(t,ec.player.vy)
	updatePlayer(t)
	updateMissiles(t)
end

function clearSpace(c)
	-- clear screen with space color
	cls(c or pal.space)
	-- screen border flash effect
	local d,f=var.flashDur,var.flashFreq
	if d and d>0 then
		local c=(d%f==0) and pal.red or pal.black
		poke(0x3FF8,c)
		var.flashDur=clamp(d-1,0)
	else 
		-- default border pure black
		poke(0x3FF8,pal.black)
	end
end

function drawStars(t)
	for i,s in ipairs(ec.stars) do
		if s.bt>9 and t%s.bt==0 then
			s.sh=not s.sh
		end
		if s.sh then
			spr(s.si,s.x,s.y,pal.space)
		end
	end
end

function drawPlayer()
	local p=ec.player
	local sp=p.spd
	spr(sp.id,
		p.x-sp.ox,p.y-sp.oy,pal.space,
		sp.sc,sp.fl,sp.ro,sp.sw,sp.sh)
end

function drawMissiles()
	for i,m in ipairs(ec.missiles) do
		if m.sh then
			local sp=m.spd
			spr(sp.id,
				m.x-sp.ox,m.y-sp.oy,pal.space,
				sp.sc,sp.fl,sp.ro,sp.sw,sp.sh)
		end
	end
end

function drawEntities(t)
	drawStars(t)
	drawMissiles()
	drawPlayer()

	local spc=pal.space
	swpPal(14,pal.green)
	spr(128,35,32,spc,1,0,0,2,2)
	swpPal(14)
	spr(136,32,48,spc,1,0,0,2,1)
	spr(152,32,58,spc,1,0,0,2,1)

	spr(160,64,96,spc,1,0,0,1,2)
	spr(160,72,96,spc,1,1,0,1,2)
end

function drawHud()
	rect(VW,0,SW-VW,VH,pal.black)
	print("TIC-80 version",VW+2,0,pal.yellow)

	printf("GALAGA",VW+8,8,pal.red)
	if var.state=="title" then
		printf("+ PAD:MOVE",VW,24)
		printf("A KEY:GO",VW,40)
		printf("S KEY:END",VW,56)
	else
		printf("S KEY:",VW+8,24)
		printf(" TO TITLE",VW+8,32)
	end

	if var.debug then
		print(var.state,VW+2,VH-6,pal.silver)
	end
end

function initTitle(fs)
	music()
	var.hiscore=var.hiscore or 3000
	var.gameMode=0
end

function updateTitle(t)
	local dm=0
	if btnp(bkn.up) then dm=-1	end
	if btnp(bkn.down) then dm=1 end
	var.gameMode=clamp(var.gameMode+dm,0,1)
	if btnp(bkn.s) then exit() end
	if btnp(bkn.z) or btnp(bkn.x) or btnp(bkn.a) then
		if var.gameMode==0 then
			toScene("start",initStart)
		else
			exit()
		end
	end
end

function drawTitle(t)
	printf("HI-SCORE",24,1,pal.red)
	printf(var.hiscore,104,1)
	swpPal(14,pal.green)
	spr(385,40,24,pal.space,1,0,0,10,5)
	swpPal(14)
	swpPal(15,pal.red)
	spr(480,48,100,pal.space,1,0,0,8,2)
	swpPal(15)
	spr(272,24,120,pal.space,1,0,0,14,1)
	spr(354,36,128,pal.space,1,0,0,11,1)
	printf("GAME START",48,72)
	printf("END GAME",48,88)
	printf("\\",32,72+16*var.gameMode)
end

function initStart(fs)
	initStars()
	music(msn.takeoff,-1,-1,false)
end

function updateStart(t)
	updateStars(t,0)
	if btnp(bkn.s) then
		toScene("title",initTitle)
	end
	if btnp(bkn.a) or elapsed(7000) then
		toScene("stage",initStage)
	end
end

function drawStart(t)
	drawStars(t)
	printc("START",VH//2-4,pal.red)
end

local scenes={
	title=function(t)
		updateTitle(t)
		clearSpace()
		drawTitle(t)
		drawHud()
	end,
	start=function(t)
		updateStart(t)
		clearSpace()
		drawStart(t)
		drawHud()
	end,
	stage=function(t)
		updateEntities(t)
		clearSpace()
		drawEntities(t)
		drawHud()
	end,
	bonus=function(t)
	end,
	over=function(t)
	end,
}

function TIC()
	var.tick=warp(var.tick+1,0,0xFFFF)
	scenes[var.state](var.tick)
end

init()
