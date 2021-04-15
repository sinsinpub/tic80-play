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

-- <TILES>
-- 001:5ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 002:7ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 003:eccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 004:2ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 005:6ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 006:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 007:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 008:ccccecccccccccccccccccdccccccccccccfccccccccccccccccccecccccdccc
-- 009:cccccccccccccccccccccccdcccfcccccccccccccdccccccccccccfccccccccc
-- 010:cccccccccccdcccccecccccfccccccccccccccccfccccceccccfcccccccccccc
-- 011:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 012:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 013:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 014:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 015:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 016:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 017:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 018:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 019:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 020:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 021:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 022:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 023:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 024:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 025:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 026:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 027:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 028:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 029:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 030:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 031:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 032:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 033:ccffccccccffccccccffccccccffccccccccccccccffccccccffcccccccccccc
-- 034:ccffcffcccffcffccccfccfcccfccfcccccccccccccccccccccccccccccccccc
-- 035:ccfccfccccfccfcccffffffcccfccfccccfccfcccffffffcccfccfcccccccccc
-- 036:cccffccccffffffccfcffccccffffffccccffcfccffffffccccffccccccccccc
-- 037:cccccccccffcccfccffccfccccccfccccccfccccccfccffccfcccffccccccccc
-- 038:ccffcccccfccfccccfccfcccccfffccccfcccfcfcfccccfcccffffcfcccccccc
-- 039:cccffccccccffcccccccfccccccfcccccccccccccccccccccccccccccccccccc
-- 040:ccccfccccccfcccccccfcccccccfcccccccfcccccccfccccccccfccccccccccc
-- 041:cccfccccccccfcccccccfcccccccfcccccccfcccccccfccccccfcccccccccccc
-- 042:ccccccccccccccccccccccccccccccccccccfccccccccfcdccccccfdcccccccf
-- 043:ccccccccccccccccccccccccccccccccfcccfcccfdcfccccfdfcccccffcccccc
-- 044:ccccccccccccccccccccccccccffccccccffcccccccfccccccfccccccccccccc
-- 045:cccccccccccccccccccccccccfffffffcccccccccccccccccccccccccccccccc
-- 046:cccccccccccccccccccccccccccccccccccccfceccccffcdccccffffccccfffe
-- 047:cccccccccccccccccccccccccccccccccecfccccfdcffcccfffffccceefffccc
-- 048:cccfffccccfccffccffcccffcffcccffcffcccffccffccfccccfffcccccccccc
-- 049:ccccffcccccfffccccccffccccccffccccccffccccccffccccffffffcccccccc
-- 050:ccfffffccffcccffcccccfffccccfffccccfffccccfffccccfffffffcccccccc
-- 051:ccffffffccccccffccccfffcccccccffccccccffcffcccffccfffffccccccccc
-- 052:ccccfffccccffffcccffcffccffccffccfffffffcccccffccccccffccccccccc
-- 053:cffffffccffccccccffffffcccccccffccccccffcffcccffccfffffccccccccc
-- 054:ccfffffccffccccfcffccccccffffffccffcccffcffcccffccfffffccccccccc
-- 055:cfffffffcffcccffcccccffcccccffcccccffccccccffccccccffccccccccccc
-- 056:ccffffcccffcccfccfffccfcccffffcccfcccfffcfccccffccfffffccccccccc
-- 057:ccfffffccffcccffcffcccffccffffffccccccffcccccffcccffffcccccccccc
-- 058:ccccccfdcccccfffccccfffdccccfffccccccccccccccccccccccccccccccccc
-- 059:ddfcccccffffccccddfffcccdcfffccccccccccccccccccccccccccccccccccc
-- 060:ccccccccccccccccccccccccccccccccccccccccccffccccccffcccccccccccc
-- 061:cccccccccfffffffcccccccccccccccccccccccccfffffffcccccccccccccccc
-- 062:ccccccffccccfffeccccfffccccccffccccccccccccccccccccccccccccccccc
-- 063:fffccccceefffcccecfffcccccffcccccccccccccccccccccccccccccccccccc
-- 064:ccfffccccfcccfccfccfccfcfccffffcfccfccfccfcccfccccfffccccccccccc
-- 065:cccfffccccffcffccffcccffcffcccffcfffffffcffcccffcffcccffcccccccc
-- 066:cffffffccffcccffcffcccffcffffffccffcccffcffcccffcffffffccccccccc
-- 067:cccffffcccffccffcffccccccffccccccffcccccccffccffcccffffccccccccc
-- 068:cfffffcccffccffccffcccffcffcccffcffcccffcffccffccfffffcccccccccc
-- 069:cfffffffcffccccccffccccccffffffccffccccccffccccccfffffffcccccccc
-- 070:cfffffffcffccccccffccccccffffffccffccccccffccccccffccccccccccccc
-- 071:cccfffffccffcccccffccccccffcffffcffcccffccffccffcccfffffcccccccc
-- 072:cffcccffcffcccffcffcccffcfffffffcffcccffcffcccffcffcccffcccccccc
-- 073:ccffffffccccffccccccffccccccffccccccffccccccffccccffffffcccccccc
-- 074:ccccccffccccccffccccccffccccccffcffcccffcfffccffccfffffccccccccc
-- 075:cffcccffcffccffccffcffcccffffccccfffffcccffcfffccffccfffcccccccc
-- 076:ccffccccccffccccccffccccccffccccccffccccccffccccccffffffcccccccc
-- 077:cffcccffcfffcfffcfffffffcfffffffcffcfcffcffcccffcffcccffcccccccc
-- 078:cffcccffcfffccffcffffcffcfffffffcffcffffcffccfffcffcccffcccccccc
-- 079:ccfffffccffcccffcffcccffcffcccffcffcccffcffcccffccfffffccccccccc
-- 080:cffffffccffcccffcffcccffcffcccffcffffffccffccccccffccccccccccccc
-- 081:ccfffffccffcccffcffcccffcffcccffcffcffffcfffccfcccffffcfcccccccc
-- 082:cffffffccffcccffcffcccffcffccfffcfffffcccffcfffccffccfffcccccccc
-- 083:ccffffcccffccffccffcccccccfffffcccccccffcffcccffccfffffccccccccc
-- 084:ccffffffccccffccccccffccccccffccccccffccccccffccccccffcccccccccc
-- 085:cffcccffcffcccffcffcccffcffcccffcffcccffcffcccffccfffffccccccccc
-- 086:cffcccffcffcccffcffcccffcfffcfffccfffffccccfffccccccfccccccccccc
-- 087:cffcccffcffcccffcffcfcffcfffffffcfffffffcfffcfffcffcccffcccccccc
-- 088:cffcccffcfffcfffccfffffccccfffccccfffffccfffcfffcffcccffcccccccc
-- 089:ccffccffccffccffccffffffcccffffcccccffccccccffccccccffcccccccccc
-- 090:cfffffffcccccfffccccfffccccfffccccfffccccfffcccccfffffffcccccccc
-- 091:cccfffcccccfcccccccfcccccccfcccccccfcccccccfcccccccfffcccccccccc
-- 092:cfcccccccfffcccccfffffcccfffffffcfffffcccfffcccccfcccccccccccccc
-- 093:ccfffcccccccfcccccccfcccccccfcccccccfcccccccfcccccfffccccccccccc
-- 094:cccccccccfffcccccfcccffccffccfcfcfcccfcfcfffcfcfcccccffccccccccc
-- 095:ccccccccccccccccccccccccccccccccccccccccccccccccccfffffccccccccc
-- 096:cccccccccccccccccccccccccccccccccccccccccccccccfcccccdcfcccccdcf
-- 097:ccccccccccccccccfcccccccfcccccccfcccccccffccccccffcdccccffcdcccc
-- 098:cccccccccccccccccccccccccccccccccccccccccccccdcdcccccdcdccccffff
-- 099:cccccccccccccccccccfccccccffccccccfccccccffcccccfffcccccfffcdccc
-- 100:cccccccccccccccccccccccccccccccccccccdccccccdccdcccfffffccffffff
-- 101:cccccccccccccccccccccccccccccfccdcccfcccccffcccccfffccccfffccccc
-- 102:ccccccccccccccccccccccccccccccddccccfffccfffffffcccddfffccccdfdd
-- 103:cccccccccccccccccccccccccccccccccdccccccdccccffcffffffccffffcccc
-- 104:cccccccccccccccccccccccccccffffdcccccfffcccccdffccccddffcccccffd
-- 105:ccccccccccccccccccccccccdcccccccccccccccfddcccccfcccccccdfffcccc
-- 106:ccccfcccccccfcccccccfcccccccdcccccccdccccccccccccccccccccccccccc
-- 107:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 108:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 109:cccccdcccccccdccccccccddccccfccccccccfffcccdccccccccddcccccccddd
-- 110:cccccccccccccccccccccccccccccccfccccccccccccccccccccccccccccccdd
-- 111:cccccccccccccccccccccccccccccccfccccccccccccccccccccccccccccccdd
-- 112:cccdcffdcccdfffdcccfffffcccffddfcccfccdccccfcccccccccccccccccccc
-- 113:ddffcdccfdfffdccffffffccffddffccfcdccfccfccccfcccccccccccccccccc
-- 114:ccccfffdcccffffdcccfdfffccfcddcfccccccffccccccfccccccccccccccccc
-- 115:dffdccccfdffcdccfdfffdccfffffccccddffcccccdfcccccccfcccccccfcccc
-- 116:cfccdfddcccddfffccccccffcccccfcfccccfccdcccccccdcccccccccccccccc
-- 117:dfccdcccdffdccccdffcccccfffcdcccdffdcccccffccccccfccccccfccccccc
-- 118:cccccfffccccfffdcccffcffcccccdffcccccddfccccccffcccccfcccccccccc
-- 119:dffcccccdfddccccffccccccffddccccffcccccccccccccccccccccccccccccc
-- 120:cccfffffcccccffdccccddffcccccdffcccccfffcccffffdcccccccccccccccc
-- 121:dffffffcdfffccccfcccccccfddcccccccccccccdccccccccccccccccccccccc
-- 122:ccccfcccccccfcccccccfccccccdcccccccdcccccccccccccccccccccccccccc
-- 123:cccffcccccffcccccddccccccccccccccccccccccccccccccccccccccccccccc
-- 124:cccccdcccccccdccccccccddccccfccccccccfffcccdccccccccddcccccccddd
-- 125:dcccffffcdccccccccdddcccccccddddffcccccccffffcccccccffffcccccccc
-- 126:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 127:cccccccccccccccccccccfffcccccccfccccccccccccdddcccccccddcccccccc
-- 128:cccccccccccccccccccccececccccececcceededccccceeeccccefefccecefff
-- 129:cccccccccccccccccccccccccccccccceeccccccccccccccecccccccececcccc
-- 130:cccccccccccccccccccccccccccccececcceededccccceeeccccefefccecefff
-- 131:cccccccccccccccccccccccccccccccceeccccccccccccccecccccccececcccc
-- 132:cccccccccccccccccccccdcdcccccdcdcccddfdfcccccdddccccddddccdcdddd
-- 133:ccccccccccccccccccccccccccccccccddccccccccccccccdcccccccdcdccccc
-- 134:cccccccccccccccccccccccccccccdcdcccddfdfcccccdddccccddddccdcdddd
-- 135:ccccccccccccccccccccccccccccccccddccccccccccccccdcccccccdcdccccc
-- 136:cccccccccccccdceccccddcdccccdddfccccccdeccccdddfccccdddecccccddc
-- 137:cccccccccecdccccfdcddcccffdddccceedcccccffdddccceedddcccecdccccc
-- 138:ccccccccccccccdecccccdddcccccddfccccccdecccccddfcccccddeccccccdc
-- 139:cccccccccedcccccfdddccccffddcccceedcccccffddcccceeddccccecdccccc
-- 140:cccfccccccccffccccdccfffccddcccccccddccccfcccdddcffcccccccfffccc
-- 141:ddddcccccccdddddccccccccffffcccccccfffffccccccccddcccccccddddddd
-- 142:cccccccccccccccccccccfffcccccccfcccccccccccccccccccccccccccccccc
-- 143:dcccffffcdccccccccdddcccccccddddffcccccccffffcccccccffffcccccccc
-- 144:ceeeefffccededcdceedcdcdcedeccccceddcccccceccccccccccccccccccccc
-- 145:eeeeccccedeccccccdeecccccedecccccddecccccceccccccccccccccccccccc
-- 146:ceeeefffcceeedcdcceeedcdccceeccccccceececccccececccccccccccccccc
-- 147:eeeecccceeeccccceeeccccceecccccceccccccccccccccccccccccccccccccc
-- 148:cdddddddccdfdfcfcddfcfcfcdfdcccccdffccccccdccccccccccccccccccccc
-- 149:ddddccccdfdccccccfddcccccdfdcccccffdccccccdccccccccccccccccccccc
-- 150:cdddddddccdddfcfccdddfcfcccddcccccccddcdcccccdcdcccccccccccccccc
-- 151:ddddccccdddcccccdddcccccddccccccdccccccccccccccccccccccccccccccc
-- 152:cccccccccccceccccccccecdccccccefccccccedccccceefcccceeedcccceeec
-- 153:ccccccccfcccecccfdceccccffecccccddecccccffeeccccddeeecccdceeeccc
-- 154:cccccccccccccecccccccecdccccccefccccccedccccccefccccceedccccceec
-- 155:ccccccccfcceccccfdceccccffecccccddecccccffecccccddeeccccdceecccc
-- 156:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 157:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 158:cccfccccccccffccccdccfffccddcccccccccccccccccccccccccccccccccccc
-- 159:ddddcccccccdddddccccccccffffcccccccccccccccccccccccccccccccccccc
-- 160:ccccfffcccffccffcffcfffccfcffffffcffcffffcfffcffffffffcfcfcffffc
-- 161:ccccccccccccccccccccccccccccccccccccfccccccccfccccccccfccccccccf
-- 162:ccccccccccccccccccccccccccccccccccccccccccffffccfffcccfcfccfffcf
-- 163:fccccccccfccccccccfccccccccfccffccccfffcccccffcccccffccfcccfccfc
-- 164:cccccccccccccccfcfffccfcfcccffcccffffffcffffffffffffffffffffffff
-- 165:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccd
-- 166:ccccccccccccccccccccccccccccccccccccdcccccecccdccccccccccccfcecf
-- 167:cccccccccccccccccccccccccccdcccccccccccccccccdcccccccccccccccccc
-- 168:ccccccccccccccdcccdcccccdcfceccccccccccceccccccdfccccdcccccdcfcc
-- 169:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 170:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 171:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 172:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 173:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 174:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 175:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 176:cfcffffcffffffcffcfffcfffcffcfffcfcfffffcffcfffcccffccffccccfffc
-- 177:ccccccffccccccfccccccffccccccfcfcccccfcfcccccfcfccccccfccccccccf
-- 178:cffffffffcffffccffcffcfffffccfccfffcccccffcfcfccfcfcccfcfcfccccf
-- 179:cccfcfffccfcffffccfcffffccfcffffcccfffffcccfffffccfcffffcfcccfff
-- 180:cfffffccffccfccffcfffcfffcfcffcfffffcffffccffcffccfcffcfcffffffc
-- 181:cccccccccccccccfccccccccccccccecccccecccccccccfccccccccccccccccc
-- 182:ceccccccccccdcccccecccdcdcccecccccccdcccecfccccccccdccfcdcccccce
-- 183:cccceccdcccccccccccfccccccccccdcccdcccccccccfecccccdcccecccccccc
-- 184:cecccccefcfccccfcccccfccccccccdceccfcccccfcccccecccdcccccccccfcc
-- 185:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 186:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 187:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 188:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 189:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 190:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 191:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 192:cccccdcccccfcccccccccccccecdccfcccccccccccccfcccccdccccccecccecd
-- 193:cccccccfccccccfccccccfcfcccccfcfcccccfcfcccccffcccccccfcccccccff
-- 194:fcfccccffcfcccfcffcfcfccfffcccccfffccfccffcffcfffcffffcccfffffff
-- 195:cfcccfffccfcffffcccfffffcccfffffccfcffffccfcffffccfcffffcccfcfff
-- 196:cffffffcccfcffcffccffcffffffcffffcfcffcffcfffcffffccfccfcfffffcc
-- 197:ccccccccccccccccccccccfccccceccccccccceccccccccccccccccfcccccccc
-- 198:dccccccecccdccfcecfcccccccccdcccdcccecccccecccdcccccdccccecccccc
-- 199:cccccccccccdccceccccfeccccdcccccccccccdccccfcccccccccccccccceccd
-- 200:cccccfcccccdcccccfccccceeccfccccccccccdccccccfccfcfccccfceccccce
-- 201:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 202:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 203:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 204:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 205:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 206:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 207:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 208:ccccdccccccccfccfccfccdccccccccccdccccccccccecfcccfccccecccccccc
-- 209:cccccccfccccccfccccccfccccccfccccccccccccccccccccccccccccccccccc
-- 210:fccfffcffffcccfcccffffcccccccccccccccccccccccccccccccccccccccccc
-- 211:cccfccfccccffccfccccffccccccfffccccfccffccfccccccfccccccfccccccc
-- 212:ffffffffffffffffffffffffcffffffcfcccffcccfffccfccccccccfcccccccc
-- 213:cccccccdcccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 214:cccfcecfccccccccccecccdcccccdccccccccccccccccccccccccccccccccccc
-- 215:cccccccccccccccccccccdcccccccccccccdcccccccccccccccccccccccccccc
-- 216:cccdcfccfccccdcceccccccdccccccccdcfcecccccdcccccccccccdccccccccc
-- 217:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 218:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 219:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 220:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 221:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 222:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 223:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 224:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 225:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 226:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 227:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 228:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 229:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 230:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 231:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 232:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 233:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 234:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 235:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 236:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 237:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 238:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 239:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 240:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 241:dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
-- 242:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
-- 243:ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
-- 244:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 245:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 246:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 247:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 248:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 249:ffffffffeddeeddefddffddfeddeeddeffddddffcffddffcccffffcccccffccc
-- 250:ffedeffffefeefefeeeeeeeeeeeeeeeeefeeeefecffeeffcccdffdcccccffccc
-- 251:ceffdffecfefffefcfefdfefcfeedeefcefefefeccefffecccceeecccccceccc
-- 252:ceeefeeecffefeffcfffffffcfffffffcefefefeccfefefccccefecccccceccc
-- 253:ccdddddcccdfffdcccdfdddcccdfffdcccdddfdcccdfffdccccdddccccccdccc
-- 254:ccccccccccfffffcccdddddcccfffffcccdddddcccfffffccccfffccccccfccc
-- 255:ccccfcccccccfccccccfffccccdfdfdccdfdddfdcfffffffcffdfdffcfccfccf
-- </TILES>

-- <SPRITES>
-- 001:5ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 002:7ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 003:eccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 004:2ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 005:6ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 006:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 007:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 008:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 009:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 010:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 011:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 012:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 013:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 014:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 015:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 016:cccccccccccccccccccccccccccccccfcccccccfcccccccfcccccccccccccccc
-- 017:ccccccccccccccccfffcccfccccfccfccfffccfccccfccfcfffcccfccccccccc
-- 018:ccccccccccccccccfffcfffcfcfcfcfcfffcfffcccfcfcfcfffcfffccccccccc
-- 019:ccccccccccccccccfcccfccffcccffcffcccfcfffcccfccffcccfccfcccccccc
-- 020:ccccccccccccccccccffccfccfccfcffcffffcfccfccfcfccfccfcfccccccccc
-- 021:ccccccccccccccccccfccfffcffcfcccfcfcfcccccfcfcccccfccfffcccccccc
-- 022:ccccccccccccccccccfffccccfcccfcccfcccfcccfcccfccccfffccccccccccc
-- 023:cccccccccccccccccccccccccccccccfcccccccfcccccccfcccccccccccccccc
-- 024:ccccccccccccccccfffccfffcccfcccfcfffcfffcccfcfccfffccfffcccccccc
-- 025:cccccccccccccccccfffcfcfcfcfcfcfcfcfcfcfcfcfcfcccfffcfcfcccccccc
-- 026:ccccccccccccccccffcccffccfccfcccffcccfcccfccccfcffccffcccccccccc
-- 027:ccccccccccccccccfcfccfccfcffcfccfcfcffccfcfccfccfcfccfcfcccccccc
-- 028:cccccccccccccccccccccffcccccfccccccccfccccccccfcfffcffcccccccccc
-- 029:ccccccccccccccccfcfccfccfcffcfccfcfcffccfcfccfccfcfccfcccccccccc
-- 030:ccccccccccccccccccfccfffccfcccfcccfcccfcccfcccfcccfffcfccccccccc
-- 031:cccccccccccccccccfffcccccfccfccccfccfccccfccfccccfffcccfcccccccc
-- 032:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 033:ccffccccccffccccccffccccccffccccccccccccccffccccccffcccccccccccc
-- 034:ccffcffcccffcffccccfccfcccfccfcccccccccccccccccccccccccccccccccc
-- 035:ccfccfccccfccfcccffffffcccfccfccccfccfcccffffffcccfccfcccccccccc
-- 036:cccffccccffffffccfcffccccffffffccccffcfccffffffccccffccccccccccc
-- 037:cccccccccffcccfccffccfccccccfccccccfccccccfccffccfcccffccccccccc
-- 038:ccffcccccfccfccccfccfcccccfffccccfcccfcfcfccccfcccffffcfcccccccc
-- 039:cccffccccccffcccccccfccccccfcccccccccccccccccccccccccccccccccccc
-- 040:ccccfccccccfcccccccfcccccccfcccccccfcccccccfccccccccfccccccccccc
-- 041:cccfccccccccfcccccccfcccccccfcccccccfcccccccfccccccfcccccccccccc
-- 042:ccccfcccccfcfcfccccfffccccccfccccccfffccccfcfcfcccccfccccccccccc
-- 043:ccccfcccccccfcccccccfccccfffffffccccfcccccccfcccccccfccccccccccc
-- 044:ccccccccccccccccccccccccccffccccccffcccccccfccccccfccccccccccccc
-- 045:cccccccccccccccccccccccccfffffffcccccccccccccccccccccccccccccccc
-- 046:ccccccccccccccccccccccccccccccccccccccccccffccccccffcccccccccccc
-- 047:ccccccccccccccfccccccfccccccfccccccfccccccfccccccfcccccccccccccc
-- 048:cccfffccccfccffccffcccffcffcccffcffcccffccffccfccccfffcccccccccc
-- 049:ccccffcccccfffccccccffccccccffccccccffccccccffccccffffffcccccccc
-- 050:ccfffffccffcccffcccccfffccccfffccccfffccccfffccccfffffffcccccccc
-- 051:ccffffffccccccffccccfffcccccccffccccccffcffcccffccfffffccccccccc
-- 052:ccccfffccccffffcccffcffccffccffccfffffffcccccffccccccffccccccccc
-- 053:cffffffccffccccccffffffcccccccffccccccffcffcccffccfffffccccccccc
-- 054:ccfffffccffccccfcffccccccffffffccffcccffcffcccffccfffffccccccccc
-- 055:cfffffffcffcccffcccccffcccccffcccccffccccccffccccccffccccccccccc
-- 056:ccffffcccffcccfccfffccfcccffffcccfcccfffcfccccffccfffffccccccccc
-- 057:ccfffffccffcccffcffcccffccffffffccccccffcccccffcccffffcccccccccc
-- 058:cccccccccccffccccccffccccccccccccccffccccccffccccccccccccccccccc
-- 059:cccccccccccfccccccfccccccffffffcccfccccccccfcccccccccccccccccccc
-- 060:ccccffcccccffcccccffccccccffccccccffcccccccffcccccccffcccccccccc
-- 061:cccccccccfffffffcccccccccccccccccccccccccfffffffcccccccccccccccc
-- 062:ccffcccccccffcccccccffccccccffccccccffcccccffcccccffcccccccccccc
-- 063:ccffffcccffccffccfcccffcccccffcccccffccccccccccccccffccccccccccc
-- 064:ccfffccccfcccfccfccfccfcfccffffcfccfccfccfcccfccccfffccccccccccc
-- 065:cccfffccccffcffccffcccffcffcccffcfffffffcffcccffcffcccffcccccccc
-- 066:cffffffccffcccffcffcccffcffffffccffcccffcffcccffcffffffccccccccc
-- 067:cccffffcccffccffcffccccccffccccccffcccccccffccffcccffffccccccccc
-- 068:cfffffcccffccffccffcccffcffcccffcffcccffcffccffccfffffcccccccccc
-- 069:cfffffffcffccccccffccccccffffffccffccccccffccccccfffffffcccccccc
-- 070:cfffffffcffccccccffccccccffffffccffccccccffccccccffccccccccccccc
-- 071:cccfffffccffcccccffccccccffcffffcffcccffccffccffcccfffffcccccccc
-- 072:cffcccffcffcccffcffcccffcfffffffcffcccffcffcccffcffcccffcccccccc
-- 073:ccffffffccccffccccccffccccccffccccccffccccccffccccffffffcccccccc
-- 074:ccccccffccccccffccccccffccccccffcffcccffcfffccffccfffffccccccccc
-- 075:cffcccffcffccffccffcffcccffffccccfffffcccffcfffccffccfffcccccccc
-- 076:ccffccccccffccccccffccccccffccccccffccccccffccccccffffffcccccccc
-- 077:cffcccffcfffcfffcfffffffcfffffffcffcfcffcffcccffcffcccffcccccccc
-- 078:cffcccffcfffccffcffffcffcfffffffcffcffffcffccfffcffcccffcccccccc
-- 079:ccfffffccffcccffcffcccffcffcccffcffcccffcffcccffccfffffccccccccc
-- 080:cffffffccffcccffcffcccffcffcccffcffffffccffccccccffccccccccccccc
-- 081:ccfffffccffcccffcffcccffcffcccffcffcffffcfffccfcccffffcfcccccccc
-- 082:cffffffccffcccffcffcccffcffccfffcfffffcccffcfffccffccfffcccccccc
-- 083:ccffffcccffccffccffcccccccfffffcccccccffcffcccffccfffffccccccccc
-- 084:ccffffffccccffccccccffccccccffccccccffccccccffccccccffcccccccccc
-- 085:cffcccffcffcccffcffcccffcffcccffcffcccffcffcccffccfffffccccccccc
-- 086:cffcccffcffcccffcffcccffcfffcfffccfffffccccfffccccccfccccccccccc
-- 087:cffcccffcffcccffcffcfcffcfffffffcfffffffcfffcfffcffcccffcccccccc
-- 088:cffcccffcfffcfffccfffffccccfffccccfffffccfffcfffcffcccffcccccccc
-- 089:ccffccffccffccffccffffffcccffffcccccffccccccffccccccffcccccccccc
-- 090:cfffffffcccccfffccccfffccccfffccccfffccccfffcccccfffffffcccccccc
-- 091:cccfffcccccfcccccccfcccccccfcccccccfcccccccfcccccccfffcccccccccc
-- 092:cfcccccccfffcccccfffffcccfffffffcfffffcccfffcccccfcccccccccccccc
-- 093:ccfffcccccccfcccccccfcccccccfcccccccfcccccccfcccccfffccccccccccc
-- 094:cccccccccfffcccccfcccffccffccfcfcfcccfcfcfffcfcfcccccffccccccccc
-- 095:ccccccccccccccccccccccccccccccccccccccccccccccccccfffffccccccccc
-- 096:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 097:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 098:cccccccccccccccfccccccfcccccccffccccccfcccccccfccccccccccccccccc
-- 099:ccccccccfccfcccfcfcfcccfffcfcccfcfcfcccfcfcfffcfcccccccccccccccc
-- 100:cccccccccccccfffcccccfcccccccfffcccccfccffcccfcccccccccccccccccc
-- 101:ccccccccccfffccffccfccfccccfccfcfccfccfcfcfffccfcccccccccccccccc
-- 102:ccccccccffcfccfccccfccfcffcffffccfcfccfcffcfccfccccccccccccccccc
-- 103:ccccccccfffccfffcfccfccccfcccffccfcccccfcfccfffccccccccccccccccc
-- 104:cccccccccccfffcccccfccfccccfffcccccfccfccccfccfccccccccccccccccc
-- 105:ccccccccfffccffffcccfcccfffccffcfccccccffffcfffccccccccccccccccc
-- 106:cccccccccfffcfffcfcccfcccfffcfffcfcccfcccfffcfcccccccccccccccccc
-- 107:ccccccccccfccfcffcfccfcfccfccfcffcfccfcffccffccfcccccccccccccccc
-- 108:ccccccccffcfffcccccfccfcffcfccfccccfccfcffcfffcccccccccccccccccc
-- 109:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 110:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 111:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 112:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 113:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 114:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 115:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 116:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 117:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 118:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 119:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 120:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 121:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 122:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 123:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 124:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 125:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 126:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 127:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 128:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 129:cccccccccccccccccccccccccccccccccccccccccccccccccccccceeccccceee
-- 130:cccccccccccccccccccccccccccccccccceeeeeceeeeeeeeeeeeccceeeccccce
-- 131:cccccccccccccccccccccceeccceeeeeceeeeeeeeeeeeeeeeeeeeccceeeccccc
-- 132:cccccccccceeeeeeeeeeeeeeeeeeeeeceeeccccccccccccccccccccecccccccc
-- 133:eeeeeeeeeeeeeeeeeeeeecccccccccccceeecccceeeeeccceeeeecccceeeeccc
-- 134:eeeeeeeeeeeeeeeecccccccccccccccccccccccccccccccccccccccccccccccc
-- 135:eeeeeeeceeeeeeeecccceeeecccccccccccccccccccccccccccccccccccccccc
-- 136:cccccccceeeecccceeeeeeeecceeeeeecccccccecccccccccccccccccccccccc
-- 137:cccccccccccccccccccccccceeeccccceeeeeceecceeeeeecccceeeeccccccee
-- 138:cccccccccccccccccceeeecceeeeeeeceeeeeeeceeccceececccceeccccccecc
-- 139:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 140:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 141:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 142:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 143:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 144:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 145:cccceeeeccceeeeeccceeeeccceeeeeccceeeeccceeeeeccceeeeeccceeeeecc
-- 146:eccccceecccccceeccccceecccccceccccccccccccccceeecceeeeeecccceeee
-- 147:eccccccccccccccccccccccecccecceeeeecceeeeecccecceeccccccecccccce
-- 148:cccccccccccccccceeeeeccceeeeeecceeeeeeccccceeeeccccceeeceeeeeeec
-- 149:ceeeecccceeeecccceeeecccceeeecceceeeeceeceeeececceeeecccceeeeccc
-- 150:cccccccccccccccceeeeeecceeeeeeeceeeeeeeccccceeeeccccceeeeeeeeeee
-- 151:cccccccccccccccccccccccccccccceecccceeeeccceeeeeccceeeeecceeeeec
-- 152:ccccccccccceeeeceeeeeecceeeeeccceeeeeecceeeeeecccceeeecccceeeecc
-- 153:cccccccecccccccccccceeeeccceeeeecceeeeeecceccccccccccccccccceeee
-- 154:eccceecceeceeccceeeecccceeeccccceeeecccceeeeccccceeecccceeeecccc
-- 155:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 156:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 157:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 158:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 159:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 160:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 161:ceeeeeccceeeeeccceeeeeecceeeeeeecceeeeeecceeeeeeccceeeeeccccceee
-- 162:ccccceeecccccceecccccceeecccceeeeeeeeeeeeeeeeeeeeeeeeeeeeeecceee
-- 163:eecccceeeeccceeeeeecceeeeeeceeeeeeeeeeeeeeeeeeeeeeecceeeecccccee
-- 164:eeeeeeececceeeecccceeeecccceeeeecceeeeeeeeeeeeeeeeeeeeeeeeeceeec
-- 165:ceeeecceceeeeceeeeeeeceeeeeeeeeeeeeeeeeeeeeeeeeeceeeeceecceeccce
-- 166:eeeeeeeeeecceeeeeccceeeeeccceeeeecceeeeeeeeeeeeeeeeeeeeeeeeeceee
-- 167:cceeeecccceeeeccceeeeecceeeeeeeeeeceeeeeeecceeececccccccccccccce
-- 168:cceeeeccceeeeecceeeeeccceeeccccceeeeeeecceeeeeeeeeecceeeecccccee
-- 169:ccceeeeecceeeecccceeecccceeeecccceeeecceeeeeeeeeeeeeeeeeeeceeeee
-- 170:eeeecccceeeecccceeeececceeeeeecceeeeeecceeeeeecceeeeecccceeecccc
-- 171:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 172:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 173:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 174:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 175:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 176:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 177:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 178:cccceeecccceeccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 179:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 180:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 181:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 182:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 183:cccccceccccccccccccccccccccccccccccccccccccccceecccceeeeccccceee
-- 184:cccccccecccecccecccecccecceecceeeeeccceeeeecceeeeeeceeeeeeeeeeee
-- 185:eeeccccceeeccccceeeccccceeeccccceeeccccceecccccceecccccceccccccc
-- 186:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 187:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 188:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 189:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 190:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 191:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 192:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 193:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 194:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 195:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 196:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 197:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 198:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 199:cccccceecccccceecccccceeccccceeeccccceeecccceeeeccceeeeeceeeeecc
-- 200:eeeeeeeeeeeeeeeeeeeeeeeceeeeeecceeeeeccceeeccccceccccccccccccccc
-- 201:eccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 202:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 203:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 204:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 205:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 206:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 207:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 208:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 209:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 210:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 211:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 212:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 213:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 214:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 215:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 216:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 217:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 218:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 219:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 220:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 221:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 222:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 223:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 224:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 225:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 226:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 227:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 228:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 229:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 230:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccf
-- 231:ccccccccccccccccccccccccccccccccccccccccccccccccffffccccccccfccc
-- 232:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 233:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 234:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 235:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 236:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 237:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 238:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 239:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 240:ccffffffccffffffccffccccccffccccccffccccccffccccccffccccccffcccc
-- 241:fccccfffffcccfffffccccccffcccfffffccffffffccffccffccffffffcccfff
-- 242:fffcccffffffccffccffccffffffccffffffccffccffccffffffccffffffccff
-- 243:fffffffcffffffffccffccffccffccffccffccffccffccffccffccffccffccff
-- 244:cccfffffccffffffccffccccccffccccccffccccccffccccccffffffcccfffff
-- 245:ffcccfffffccffffccccffccccccffccccccffccccccffccffccffffffcccfff
-- 246:ffffccfcfffffcfccccffcfccccffcfccccffccfcccffcccfffffcccffffcccc
-- 247:fffccfccfccfcfccfffccfccfccfcfccccccfcccffffcccccccccccccccccccc
-- 248:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 249:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 250:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 251:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 252:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 253:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 254:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 255:cccccccccccfccccccdfdcccccfdfcccdfdddfdcfffffffcfccfccfccccccccc
-- </SPRITES>

-- <WAVES>
-- 000:00000000ffffffff00000000ffffffff
-- 001:0123456789abcdeffedcba9876543210
-- 002:0123456789abcdef0123456789abcdef
-- </WAVES>

-- <SFX>
-- 000:000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000307000000000
-- 001:010001000100010001000100010001000100010001000100010001000100010001000100010001000100010001000100010001000100010001000100300000000000
-- 002:020002000200020002000200020002000200020002000200020002000200020002000200020002000200020002000200020002000200020002000200305000000000
-- </SFX>

-- <PATTERNS>
-- 000:0000008ff1180000004ff1186ff1180000009ff1188ff1180000004ff1186ff118000000dff118bff1180000004ff1186ff1180000009ff1188ff1180000004ff118bff118000000fff1184ff11a000000eff118cff118000000bff1189ff1180000007ff1186ff118000000eff116eff1180000004ff11aeff118000000bff118dff1189ff1186ff118bff1188ff1186ff118100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 001:0000008cc1080000004cc1086cc1080000009cc1088cc1080000004cc1086cc108000000dcc108bcc1080000004cc1086cc1080000009cc1088cc1080000004cc108bcc108000000fcc1084cc10a000000ecc108ccc108000000bcc1089cc1080000007cc1086cc108000000ecc106ecc1080000004cc10aecc108000000bcc108dcc1089cc1086cc108bcc1088cc1086cc108100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- </PATTERNS>

-- <TRACKS>
-- 000:1800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008de000
-- </TRACKS>

-- <PALETTE>
-- 000:000000525252acacac8b838b000000ff3152ffe65229de290000007b73e6b4c5ffa4a4a4101010bd20202929deffffff
-- </PALETTE>

