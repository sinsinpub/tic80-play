-- title:  DEEP SCAN
-- author: sin_sin
-- desc:   SEGA Deep Scan arcade game clone.
-- script: lua
-- pal: 0000000000aa00aa0000aaaaaa0000aa00aaaa5500aaaaaa5555550000ff00ff0000ffffff0000ff00ffffff00ffffff

-- global constants
local SW,SH=240,136
local AIRH,HUDH,RADW=24,32,80
local VW,VH=SW,SH-HUDH
local Y,N=true,false
-- color names of palette
local pal={
	black=0,white=15,gray=8,silver=7,
	red=12,green=10,blue=9,
	pink=13,yellow=14,cyan=11,
	air=11,sea=9,land=15,
	friend=12,enemy=15,
	radar=10,symbol=14,
}
-- names and channels of sfx
local sfn={
	sonar=0,mine=1,charge=2,
}
-- global variables
local var={}
-- entity components
local ec={}
-- function shortcuts
local int,abs,rnd,min,max=math.floor,math.abs,math.random,math.min,math.max
local format,len,rep,chr=string.format,string.len,string.rep,string.char
local inst,delt=table.insert,table.remove

local scenes={
	title=function(t)
		updateTitle(t)
		clearSea()
		drawTitle(t)
		drawHud()
	end,
	start=function(t)
		updateStart(t)
		cls(pal.black)
		drawStart(t)
	end,
	stage=function(t)
		updateEntities(t)
		clearSea()
		drawEntities(t)
		drawHud(t)
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

function init()
	var.debug=N
	var.mute=N
	var.tick=0
	var.flashDur=0
	var.flashFreq=4
	var.seaFric=0.2
	var.maxInt=9999
	var.maxScore=99990
	var.hiscore=var.hiscore or 3000
	toScene("title",initTitle)
end

function initTitle(fs)
	music()
	var.delay=0
	var.rank=99
	var.score=0
	var.life=5
	var.maxCharges=6
	var.maxSubs=8
	var.maxMines=10
	var.advCharge=Y
	var.hitMine=Y
	initPlayer()
end

function updateTitle(t)
	var.delay=clamp(var.delay-1,0)
	if var.delay==1 then exit() end
	if btnp(6) then var.debug=not var.debug end
	if btnp(7) then var.delay=31 end
	if btnp(4) or btnp(5) then
		if var.delay==0 then
			toScene("start",initStart)
		end
	end
end

function drawTitle(t)
	drawPlayer()
	if t%120<60 then printc("GAME OVER",-7) end
	printc("@ SEGA 1979",-11)
end

function initStart(fs)
	music()
end

function updateStart(t)
	if btnp(7) then
		toScene("title",initTitle)
	end
	if btnp(4) or btnp(5) or elapsed(5000) then
		toScene("stage",initStage)
	end
end

function drawStart(t)
	local c=pal.cyan
	printc("DEEP SCAN",-1,c)
	printc("HIT SUBS TO SCORE POINTS",- 3,c)
	printc("AND ADVANCE BONUS.      ",- 4,c)
	printc("AVOID MINES LAUNCHED BY ",- 6,c)
	printc("SUBS.                   ",- 7,c)
	printc("SCORE BONUS BY HITTING  ",- 9,c)
	printc("RED BONUS SUB.          ",-10,c)
	printc("GAME ENDS WHEN ALL SHIPS",-12,c)
	printc("HAVE BEEN SUNK.         ",-13,c)
	printc("PRESS BUTTON TO START!",-15,c)
end

function initStage(fs)
	music()
	initGame()
end

function initPlayer()
	ec.player={}
	local pl=ec.player
	-- sprite definitions
	pl.spd={
		-- sprite index, scale, flip, rotate,
		-- sprite width & height
		id=96,sc=1,fl=0,ro=0,sw=4,sh=2,
		-- offset x & y, pixel width & height
		ox=0,oy=0,w=32,h=16,
	}
	pl.x=VW//2-pl.spd.w//2
	pl.y=AIRH-pl.spd.h
	pl.vx,pl.vy=0,0
	pl.ax,pl.ay=0.5,0.3
	pl.maxv=1
	pl.shot=0
	-- 2-side DCP cool down timer
	pl.shotInterval=52
	pl.shotTickL=0
	pl.shotTickR=0
	-- depth charges
	ec.charges={}
	for i=1,var.maxCharges do
		inst(ec.charges,{
			spd={
				id=160,sc=1,fl=0,ro=0,sw=1,sh=1,
				ox=2,oy=3,w=4,h=3,
			},
			-- is show, is move, move per tick
			sh=N,mv=N,mt=5,
			-- anime state, anime index, anime per tick, max anime frame
			st=0,af=0,at=10,mf=4,
			x=0,y=0,vx=0,vy=0,
		})
	end
end

function initNewSub(s)
	local d=rnd(0,1)
	s.spd={
		id=144,sc=1,fl=d,ro=0,sw=2,sh=1,
		ox=0,oy=0,w=16,h=8,
	}
	s.d=d
	s.x=-VW//2+d*(VW*2-s.spd.w)
	s.y=rnd(8,VH-AIRH-8)+AIRH
	s.vx=(-d)^d*rnd(4,11)/10
	s.vy=0
	s.lv=int(((s.y-AIRH)/(VH-AIRH))*9)+1
	s.st,s.af,s.at,s.mf=0,0,30,3
	-- mine launcher rate and cool down
	s.mineRate=7
	s.mineTick=0
	s.mineInterval=112
	s.sh=Y
	s.mv=Y
	return s
end

function initSubs()
	ec.subs={}
	for i=1,var.maxSubs do
		inst(ec.subs,initNewSub({}))
	end
	-- naval mines
	ec.mines={}
	for i=1,var.maxMines do
		inst(ec.mines,{
			spd={
				id=168,sc=1,fl=0,ro=0,sw=1,sh=1,
				ox=2,oy=2,w=4,h=4,
			},
			sh=N,mv=N,mt=8,
			st=0,af=0,at=20,mf=2,
			x=0,y=0,vx=0,vy=0,
		})
	end
end

function initGame()
	initPlayer()
	initSubs()
	var.gamest=N
	var.stats={
		stime=0,shot=0,hit=0,rate=0,
	}
	-- stage start time
	var.stats.stime=time()
end

function updatePlayer(t)
	local p=ec.player
	local dy,dx=0,0
	if btnp(7) and var.debug then reset() end
	if btnp(6) and var.debug then var.flashDur=30 end
	if btn(0) and var.advCharge then dy=-p.ay end
	if btn(1) and var.advCharge then dy=p.ay end
	if btn(2) then dx=-p.ax end
	if btn(3) then dx=p.ax end
	p.vx=clamp(p.vx+dx,-p.maxv,p.maxv)
	p.vy=dy
	p.shot=0
	if btn(4) then p.shot=1 end
	if btn(5) then p.shot=2 end
	p.x=clamp(p.x+p.vx,8,VW-p.spd.w-8)
	-- slow DD down by friction
	if p.vx>0 then
		p.vx=clamp(p.vx-var.seaFric,0,1)
	elseif p.vx<0 then
		p.vx=clamp(p.vx+var.seaFric,-1,0)
	end
	p.shotTickL=clamp(p.shotTickL-1,0)
	p.shotTickR=clamp(p.shotTickR-1,0)
end

function colliDepthChargeMines(c)
	for i,m in ipairs(ec.mines) do
		if m.mv and c.y>=AIRH
			and m.x+m.spd.w-1>c.x
			and m.x<c.x+c.spd.w-1
			and m.y+m.spd.h-1>c.y
			and m.y<c.y+c.spd.h-1 then
			m.sh,m.mv=N,N
			return Y
		end
	end
	return N
end

function updateDepthCharges(t)
	local p=ec.player
	local sts=var.stats
	for i,c in ipairs(ec.charges) do
		if c.mv then
			if var.hitMine and colliDepthChargeMines(c) then
				c.st=1
				c.af,c.mf=0,4
				if not var.mute then
					sfx(sfn.charge,"C-2",c.mf*c.at,sfn.charge,7)
				end
			end
			if t%c.mt==0 and c.st==0 then
				c.x=clamp(c.x+c.vx,0,VW-c.spd.w)
				c.y=clamp(c.y+c.vy,0,VH-c.spd.h)
			end
			if c.x<0 or c.y<=0 or c.x>VW-c.spd.w then
				c.mv,c.sh=N,N
			end
			-- hit sea floor
			if c.y>=VH-c.spd.h or c.st==1 then
				if c.st==1 then
					if c.af>=c.mf-1 then
						c.mv,c.sh=N,N
					end
				else
					c.st=1
					c.af,c.mf=0,4
					if not var.mute then
						sfx(sfn.charge,"C-2",c.mf*c.at,sfn.charge,7)
					end
				end
			end
			-- into water
			if c.y>=AIRH and t%c.at==0 then
				c.af=(c.af+1)%c.mf
			end
		else
			-- project to left
			if p.shot==1 and p.shotTickL<1 then
				c.x=p.x-8
				c.mv,c.sh=Y,Y
				p.shotTickL=p.shotInterval
				sts.shot=clamp(sts.shot+1,var.maxInt)
			end
			-- project to right
			if p.shot==2 and p.shotTickR<1 then
				c.x=p.x+4+p.spd.w
				c.mv,c.sh=Y,Y
				p.shotTickR=p.shotInterval
				sts.shot=clamp(sts.shot+1,var.maxInt)
			end
			if c.mv then
				c.y=p.y+8
				c.vx,c.vy=0,1+p.vy
				c.af,c.mf=0,4
				c.st=0
			end
		end
	end
end

function colliSubCharges(s)
	for i,c in ipairs(ec.charges) do
		if c.mv and c.x+c.spd.w-1>s.x
			and c.x<s.x+s.spd.w-1
			and c.y+c.spd.h-1>s.y+1
			and c.y<s.y+s.spd.h-1 then
			s.st,s.af=1,0
			s.mv=N
			c.sh,c.mv=N,N
			if not var.mute then
				sfx(sfn.charge,"G-2",c.mf*c.at,sfn.charge)
			end
			return Y
		end
	end
	return N
end

function updateSubs(t)
	if t%2~=0 then return end
	local findFreeMine=function()
		for i,m in ipairs(ec.mines) do
			if not m.sh then return m end
		end
	end
	local borderL=-VW//2
	local borderR=VW+VW//2
	for i,s in ipairs(ec.subs) do
		if s.mv and not colliSubCharges(s) then
			s.x=clamp(s.x+s.vx,borderL,borderR-s.spd.w)
			s.y=clamp(s.y+s.vy,AIRH,VH-s.spd.h)
			if s.x<=borderL or s.x>=borderR-s.spd.w then
				s.mv=N
				s.sh=N
			end
			s.mineTick=clamp(s.mineTick-1,0)
			-- launch random mine on screen
			if s.x>0 and s.x<VW-s.spd.w then
				if rnd(0,99)<s.mineRate and s.mineTick<1 then
					local fm=findFreeMine()
					if fm then
						fm.x=s.x+s.spd.w//2
						fm.y,fm.vy=s.y,-1
						fm.af,fm.st=0,0
						fm.mf=2
						fm.sh,fm.mv=Y,Y
						s.mineTick=s.mineInterval
					end
				end
			end
		elseif s.sh then
			if t%s.at==0 then
				s.af=clamp(s.af+1)%s.mf
			end
			if s.st==1 and s.af>=s.mf-1 then
				var.score=clamp(var.score+s.lv*10,0,var.maxScore)
				var.hiscore=max(var.hiscore,var.score)
				s.sh=N
			end
		else
			initNewSub(s)
		end
	end
end

function updateNavalMines(t)
	for i,m in ipairs(ec.mines) do
		if m.mv then
			if t%m.mt==0 then
				m.x=clamp(m.x+m.vx,0,VW-m.spd.w)
				m.y=clamp(m.y+m.vy,0,VH-m.spd.h)
			end
			if m.x<0 or m.y>=VH or m.x>VW-m.spd.w then
				m.mv,m.sh=N,N
			end
			if t%m.at==0 then
				m.af=(m.af+1)%m.mf
			end
			-- hit sea surface
			if m.y<=AIRH then
				m.y=AIRH
				if m.st==1 then
					if m.af>=m.mf-1 then
						m.mv,m.sh=N,N
					end
				else
					m.af,m.st=0,1
					m.mf=3
					if not var.mute then
						sfx(sfn.mine,"C-3",m.mf*m.at,sfn.mine)
					end
				end
			end
		end
	end
end

function updateEntities(t)
	if elapsed(500) and not var.gamest then
		var.gamest=Y
		if not var.mute then music(0,-1,-1,Y) end
	end
	if var.gamest then
		updatePlayer(t)
		updateDepthCharges(t)
		updateSubs(t)
		updateNavalMines(t)
	end
end

function drawPlayer()
	local p=ec.player
	local sp=p.spd
	spr(sp.id,
		p.x-sp.ox,p.y-sp.oy,pal.sea,
		sp.sc,sp.fl,sp.ro,sp.sw,sp.sh)
end

function drawDepthCharges()
	local iac,tcc=0,#ec.charges
	local anyc
	for i,c in ipairs(ec.charges) do
		anyc=c
		if c.sh then
			local sp=c.spd
			spr(sp.id+c.af+c.st*4,
				c.x-sp.ox,c.y-sp.oy-c.st*2,
				pal.sea,sp.sc,sp.fl,sp.ro,
				sp.sw,sp.sh)
		else
			iac=iac+1
		end
	end
	-- remaining DC indicator
	for i=0,iac-1 do
		local sp=anyc.spd
		local w=sp.w*sp.sc+3
		spr(sp.id,
			(VW-w*tcc)//2+i*w,2,pal.sea,
			sp.sc,0,0,sp.sw,sp.sh)
	end
end

function drawSubs()
	for i,s in ipairs(ec.subs) do
		if s.sh then
			local sp=s.spd
			if s.st==1 then
				-- explosion anime
				spr(sp.id+s.st*2+s.af*2,
					s.x-sp.ox,s.y-sp.oy,pal.sea,
					sp.sc,sp.fl,sp.ro,sp.sw,sp.sh)
			else
				spr(sp.id,
					s.x-sp.ox,s.y-sp.oy,pal.sea,
					sp.sc,sp.fl,sp.ro,sp.sw,sp.sh)
				-- level number
				swpPal(15,pal.sea)
				spr(128+s.lv,
					s.x-sp.ox+8*sp.sc-3*s.d*sp.sc,
					s.y-sp.oy,pal.sea,
					sp.sc,0,sp.ro,1,1)
				swpPal(15)
			end
		end
	end
end

function drawNavalMines()
	for i,m in ipairs(ec.mines) do
		if m.sh then
			local sp=m.spd
			if m.st==1 and m.af>0 then
				-- different size on explosion
				spr(sp.id+m.af+m.st*2-16,
				m.x-sp.ox,m.y-sp.oy-m.st*10,
				pal.sea,sp.sc,sp.fl,sp.ro,
				sp.sw,sp.sh+1)
			else
				spr(sp.id+m.af+m.st*2,
					m.x-sp.ox,m.y-sp.oy-m.st*2,
					pal.sea,sp.sc,sp.fl,sp.ro,
					sp.sw,sp.sh)
			end
		end
	end
end

function drawEntities(t)
	drawDepthCharges(t)
	drawPlayer(t)
	drawNavalMines(t)
	drawSubs(t)
end

function drawRadarDots(t)
	local radx=(VW-RADW)//2
	local triw=(RADW-8)//3-1
	if ec.player then
		local p=ec.player
		local x=p.x/VW*(RADW-triw*2)
		spr(177,radx+triw+x,VH+5,
			pal.sea,1,0,0,1,1)
	end
	if ec.subs then
		for i,s in ipairs(ec.subs) do
			local x=(s.x+VW//2)/(VW*2)*(RADW-8)
			local y=(s.y-AIRH)/(VH-AIRH)*(HUDH-12)
			spr(178,radx+4+x,VH+8+y,
				pal.sea,1,0,0,1,1)
		end
	end
end

function drawRadar()
	local radx=(VW-RADW)//2
	rect(radx,VH,RADW,HUDH,pal.red)
	rect(radx+2,VH+2,RADW-4,HUDH-4,pal.yellow)
	rect(radx+4,VH+4,RADW-8,HUDH-8,pal.black)
	line(radx+4,VH+8,radx+RADW-5,VH+8,pal.radar)
	local triw=(RADW-8)//3-2
	for y=VH+4,VH+HUDH-5,2 do
		pix(radx+triw,y,pal.radar)
		pix(radx+RADW-triw,y,pal.radar)
	end
end

function drawHud(t)
	rect(0,VH+2,VW,HUDH,pal.blue)
	drawRadar()
	drawRadarDots(t)
	-- show texts
	if t==nil or t%120<60 then
		printf("SCORE 1",8,VH+4)
	end
	printf(format("%05d",var.score),16,VH+12)
	printf("HISCORE",176,VH+4)
	printf(format("%05d",var.hiscore),184,VH+12)
	printf("RANK",176,VH+22)
	printf(var.rank,216,VH+22)
	if var.life>8 then
		printf(chr(127)..format("x%02d",var.life),8,VH+22)
	else
		font(rep(chr(127),var.life),8,VH+22,pal.blue,8,8,N)
	end
	if var.debug then
		print(var.state,0,0,pal.silver)
	end
end

function clearSea(c)
	-- clear screen with sea color
	cls(c or pal.sea)
	rect(0,0,VW,AIRH,pal.air)
	rect(0,VH,VW,2,pal.land)
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

function sgn(v)
	return v==0 and 0 or v>0 and 1 or -1
end

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
	local w=font(t,x,y,pal.blue,8,8,Y)
	swpPal(15)
	return w
end

function printc(t,y,c)
	local w=printf(t,0,-8)
	local x=(VW-w)//2
	if y<0 then y=csrlin(-y) end
	return printf(t,x,y,c)
end

function csrlin(r)
	return 8*r
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

init()
