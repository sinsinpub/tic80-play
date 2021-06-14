-- title:  DEEP SCAN
-- author: sin_sin
-- desc:   SEGA Deep Scan arcade game clone.
-- script: lua

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
	sonar=0,explo=1,charge=2,mine=3,
}
-- names of keycodes
local keyn={
	a=1,z=26,n0=27,n1=28,n2=29,n9=36,
	space=48,enter=50,bspace=51,
}
-- global variables
local var={}
-- entity components
local ec={}
-- function shortcuts
local int,abs,rnd,min,max=math.floor,math.abs,math.random,math.min,math.max
local format,len,rep,chr=string.format,string.len,string.rep,string.char
local inst=table.insert

local scenes={
	title=function(t)
		updateTitle(t)
		clearSea()
		drawTitle(t)
	end,
	start=function(t)
		updateStart(t)
		cls(pal.black)
		drawStart(t)
	end,
	stage=function(t)
		updateStage(t)
		clearSea()
		drawStage(t)
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
	var.scoreMulti=10
	var.rank=99
	var.score=0
	var.life=5
	var.maxInt=9999
	var.maxScore=99990
	var.extendScore=3000
	var.extendStep=5000
	var.hiscore=var.hiscore or var.extendScore
	var.bonusSubMin=0
	var.bonusSubMax=32
	var.bonusSubRate=10
	var.maxCharges=6
	var.maxSubs=8
	var.maxMines=10
	var.advCharge=Y
	var.hitMine=Y
	var.stats={}
	toScene("title",initTitle)
end

function resetEntities()
	var.gamest=N
	var.bonusSubMin=0
	var.bonusSubRate=clamp((6-var.life)*20-10,10,90)
	var.stats.combo=0
	initPlayer()
	initSubs()
end

function initTitle(ps)
	music()
	resetEntities()
	var.delay=0
	ec.player.move=N
	if ps=="stage" then traceStats() end
end

function traceStats()
	trace("== DEEPSCAN ==")
	trace(" SCORE   "..var.score)
	trace(" HISCORE "..var.hiscore)
	trace("--------------")
	trace(" SHOOTS  "..var.stats.shot)
	trace(" HITS    "..var.stats.hit)
	trace(" RATIO   "..var.stats.rate.."%")
	trace(" COMBO   "..var.stats.maxCombo)
	trace("==============")
end

function updateTitle(t)
	var.delay=clamp(var.delay-1,0)
	if var.delay==1 then exit() end
	if keyp(keyn.space) then var.debug=not var.debug end
	if btnp(6) then var.mute=not var.mute end
	if btnp(7) then var.delay=31 end
	if btnp(4) or btnp(5) then
		if var.delay==0 then
			toScene("start",initStart)
		end
	end
	updateSubs(t)
end

function drawTitle(t)
	drawPlayer()
	drawSubs()
	if t%120<60 then printc("GAME OVER",-7) end
	printc("@ SEGA 1979",-11)
	drawHud()
end

function initStart(ps)
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

function initStage(ps)
	music()
	initGame()
end

function initGame()
	var.extendScore=min(var.hiscore,var.extendStep)
	var.rank=99
	var.score=0
	var.life=5
	var.stats={
		stime=0,shot=0,hit=0,rate=0,
		combo=0,maxCombo=0,
	}
	resetEntities()
	-- stage start time
	var.stats.stime=time()
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
	pl.stime=0
	pl.show=Y
	pl.move=Y
	pl.ani={
		state=0,
		cf=0,mf=5,ft=45,ti=0,
	}
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
			-- is show, is move, ticks per move
			sh=N,mv=N,mt=5,
			-- anime state, max frame, frame index, ticks per frame, start tick
			ani={
				st=0,mf=4,cf=0,ft=10,ti=0,
			},
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
	var.bonusSubMin=clamp(var.bonusSubMin+1,0,var.bonusSubMax)
	if var.bonusSubMin>=var.bonusSubMax
		and rnd(0,99)<var.bonusSubRate then
		s.lv=10
		var.bonusSubMin=0
	end
	s.ani={
		st=0,mf=3,cf=0,ft=30,ti=0,
	}
	-- mine launcher rate and cool down
	s.mineRate=7
	s.mineTick=0
	s.mineInterval=224
	s.sh=Y
	s.mv=Y
	s.mt=2
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
			ani={
				st=0,mf=2,cf=0,ft=20,ti=0,
			},
			x=0,y=0,vx=0,vy=0,
		})
	end
end

function updatePlayer(t)
	local p=ec.player
	local pa=p.ani
	local dy,dx=0,0
	local toSinkState=function()
		p.move,pa.state=N,1
		pa.ti=t-1
		var.flashDur=pa.ft//2
		playBgm(0)
		playSe(sfn.explo,pa.ft)
	end
	local decreaseLife=function()
		var.life=clamp(var.life-1,0)
		if var.life<=0 then
			toScene("title",initTitle)
		else
			resetEntities()
		end
	end
	if keyp(keyn.space) then var.debug=not var.debug end
	if var.debug then
		if keyp(keyn.bspace) then reset() end
		if keyp(keyn.n1) then var.flashDur=pa.ft//2 end
		if keyp(keyn.n2) then var.advCharge=not var.advCharge end
		if keyp(keyn.n3) then var.hitMine=not var.hitMine end
		if keyp(keyn.enter) then var.life=5 end
		if btnp(7) then var.life=1 end
	end
	p.shot=0
	if p.move then
		if btn(0) and var.advCharge then dy=-p.ay end
		if btn(1) and var.advCharge then dy=p.ay end
		if btn(2) then dx=-p.ax end
		if btn(3) then dx=p.ax end
		if btn(4) then p.shot=p.shot|1 end
		if btn(5) then p.shot=p.shot|2 end
		if btnp(6) then
			var.mute=not var.mute
			if p.move then playBgm(1) end
		end
		if btnp(7) then toSinkState() end
	end
	p.vx=clamp(p.vx+dx,-p.maxv,p.maxv)
	p.vy=dy
	p.x=clamp(p.x+p.vx,8,VW-p.spd.w-8)
	-- slow DD down by friction
	if p.vx>0 then
		p.vx=clamp(p.vx-var.seaFric,0,1)
	elseif p.vx<0 then
		p.vx=clamp(p.vx+var.seaFric,-1,0)
	end
	p.shotTickL=clamp(p.shotTickL-1,0)
	p.shotTickR=clamp(p.shotTickR-1,0)
	if p.move and colliPlayerMines(p,t) then
		toSinkState()
	end
	if pa.state>0 and (t-pa.ti)%pa.ft==0 then
		pa.cf=clamp(pa.cf+1,0,pa.mf)
		if p.show and pa.cf>=pa.mf then
			p.show=N
			p.stime=time()
		end
		if elapsed(3000,p.stime)
			and not p.show then decreaseLife() end
	end
end

function colliPlayerMines(p,t)
	for i,m in ipairs(ec.mines) do
		local ma=m.ani
		if m.mv and ma.st==1
			and m.x+m.spd.w-1>p.x+8
			and m.x<p.x+p.spd.w-8 then
			ma.st=2
			ma.cf,ma.mf=0,2
			ma.ti=t-1
			ma.ft=p.ani.mf//2*p.ani.ft
			if m.x+m.spd.w//2>=p.x+p.spd.w//2 then
				p.spd.fl=1
			end
			return Y
		end
	end
	return N
end

function colliDepthChargeMines(c)
	if not var.hitMine then return N end
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
		local ca=c.ani
		if c.mv then
			if colliDepthChargeMines(c) then
				ca.st=1
				ca.cf,ca.mf=0,4
				ca.ti=t-1
				playSe(sfn.charge,ca.mf*ca.ft,12)
			end
			if t%c.mt==0 and ca.st==0 then
				c.x=clamp(c.x+c.vx,0,VW-c.spd.w)
				c.y=clamp(c.y+c.vy,0,VH-c.spd.h)
			end
			if c.x<0 or c.y<=0 or c.x>VW-c.spd.w then
				c.mv,c.sh=N,N
			end
			-- hit sea floor
			if c.y>=VH-c.spd.h or ca.st==1 then
				if ca.st==1 then
					if ca.cf>=ca.mf-1 then
						c.mv,c.sh=N,N
					end
				else
					ca.st=1
					ca.cf,ca.mf=0,4
					ca.ti=t-1
					playSe(sfn.charge,ca.mf*ca.ft)
				end
			end
			-- into water
			if c.y>=AIRH and (t-ca.ti)%ca.ft==0 then
				ca.cf=(ca.cf+1)%ca.mf
			end
		else
			-- project to left
			if (p.shot&1)>0 and p.shotTickL<1 then
				c.x=p.x-8
				c.mv,c.sh=Y,Y
				p.shotTickL=p.shotInterval
				sts.shot=clamp(sts.shot+1,1,var.maxInt)
			end
			-- project to right
			if (p.shot&2)>0 and p.shotTickR<1 then
				c.x=p.x+4+p.spd.w
				c.mv,c.sh=Y,Y
				p.shotTickR=p.shotInterval
				sts.shot=clamp(sts.shot+1,1,var.maxInt)
			end
			if c.mv then
				c.y=p.y+8
				c.vx,c.vy=0,1+p.vy
				ca.cf,ca.mf=0,4
				ca.st=0
				ca.ti=t-1
			end
		end
	end
end

function colliSubCharges(s,t)
	local sts=var.stats
	for i,c in ipairs(ec.charges) do
		if c.mv and c.x+c.spd.w-1>s.x
			and c.x<s.x+s.spd.w-1
			and c.y+c.spd.h-1>s.y+1
			and c.y<s.y+s.spd.h-1 then
			s.ani.st,s.ani.cf=1,0
			s.ani.mf=3
			s.ani.ti=t-1
			s.mv=N
			c.sh,c.mv=N,N
			playSe(sfn.explo,c.ani.mf*c.ani.ft,12)
			sts.hit=clamp(sts.hit+1,0,var.maxInt)
			sts.rate=int(sts.hit/(sts.shot or sts.hit)*100)
			sts.combo=clamp(sts.combo+1,0,var.maxInt)
			sts.maxCombo=max(sts.maxCombo,sts.combo)
			return Y
		end
	end
	return N
end

function updateScoreRank(lv)
	local sts=var.stats
	local gsc=lv*var.scoreMulti
	-- bonus sub hit, bonus score by combo
	if lv>9 then
		gsc=gsc+sts.combo*10*var.scoreMulti
	end
	var.score=clamp(var.score+gsc,0,var.maxScore)
	var.hiscore=max(var.hiscore,var.score)
	-- ranking list not implemented yet
	var.rank=clamp(101-int(var.score/var.hiscore*100),1,99)
	-- life extend on high score
	if var.score>=var.extendScore then
		var.life=clamp(var.life+1,0,99)
		var.extendScore=clamp(var.extendScore+var.extendStep,0,var.maxScore+1)
	end
end

function updateSubs(t)
	local findFreeMine=function()
		for i,m in ipairs(ec.mines) do
			if not m.sh then return m end
		end
	end
	local borderL=-VW//2
	local borderR=VW+VW//2
	for i,s in ipairs(ec.subs) do
		local sa=s.ani
		if s.mv and not colliSubCharges(s,t) then
			if t%s.mt==0 then
				s.x=clamp(s.x+s.vx,borderL,borderR-s.spd.w)
				s.y=clamp(s.y+s.vy,AIRH,VH-s.spd.h)
				if s.x<=borderL or s.x>=borderR-s.spd.w then
					s.mv=N
					s.sh=N
					if s.lv>9 then var.stats.combo=0 end
				end
			end
			s.mineTick=clamp(s.mineTick-1,0)
			-- launch random mine on screen
			if s.x>s.spd.w and s.x<VW-s.spd.w*2 then
				if ec.player.move and s.mineTick<1
					and rnd(0,99)<s.mineRate then
					local fm=findFreeMine()
					if fm then
						fm.x=s.x+s.spd.w//2
						fm.y,fm.vy=s.y,-1
						fm.ani.cf,fm.ani.st=0,0
						fm.ani.mf=2
						fm.ani.ft=20
						fm.ani.ti=t-1
						fm.sh,fm.mv=Y,Y
						s.mineTick=s.mineInterval
					end
				end
			end
		elseif s.sh then
			if (t-sa.ti)%sa.ft==0 then
				sa.cf=(sa.cf+1)%sa.mf
			end
			if sa.st==1 and sa.cf>=sa.mf-1 then
				updateScoreRank(s.lv)
				s.sh=N
			end
		else
			initNewSub(s)
		end
	end
end

function updateNavalMines(t)
	for i,m in ipairs(ec.mines) do
		local ma=m.ani
		if m.mv then
			if t%m.mt==0 then
				m.x=clamp(m.x+m.vx,0,VW-m.spd.w)
				m.y=clamp(m.y+m.vy,0,VH-m.spd.h)
			end
			if m.x<0 or m.y>=VH or m.x>VW-m.spd.w then
				m.mv,m.sh=N,N
			end
			if (t-ma.ti)%ma.ft==0 then
				ma.cf=(ma.cf+1)%ma.mf
			end
			-- hit sea surface
			if m.y<=AIRH then
				m.y=AIRH
				if ma.st>=1 then
					if ma.cf>=ma.mf-1 then
						m.mv,m.sh=N,N
					end
				else
					ma.cf,ma.st=0,1
					ma.mf=3
					ma.ti=t-1
					playSe(sfn.mine,ma.mf*ma.ft)
				end
			end
		end
	end
end

function updateStage(t)
	if elapsed(500) and not var.gamest then
		var.gamest=Y
		playBgm(1)
	end
	if var.gamest then
		updatePlayer(t)
		updateDepthCharges(t)
		updateSubs(t)
		updateNavalMines(t)
	end
end

function drawStage(t)
	drawEntities(t)
	drawHud(t)
end

function drawEntities(t)
	drawDepthCharges(t)
	drawPlayer(t)
	drawNavalMines(t)
	drawSubs(t)
end

function drawPlayer()
	local p=ec.player
	local sp=p.spd
	local ani=p.ani
	local f=ani.cf*4
	if p.show and ani.cf<5 then
		-- sinking animation
		if ani.cf==4 then
			spr(sp.id+f+28,
				p.x-sp.ox,p.y-sp.oy+sp.h//2,pal.sea,
				sp.sc,sp.fl,sp.ro,sp.sw,sp.sh//2)
		else
			spr(sp.id+f,
				p.x-sp.ox,p.y-sp.oy,pal.sea,
				sp.sc,sp.fl,sp.ro,sp.sw,sp.sh)
		end
	end
end

function drawDepthCharges()
	local iac,tcc=0,#ec.charges
	local anyc
	for i,c in ipairs(ec.charges) do
		anyc=c
		if c.sh then
			local sp=c.spd
			spr(sp.id+c.ani.cf+c.ani.st*4,
				c.x-sp.ox,c.y-sp.oy-c.ani.st*2,
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
			local ani=s.ani
			if ani.st>=1 then
				-- explosion animation
				spr(sp.id+ani.st*2+ani.cf*2,
					round(s.x)-sp.ox,s.y-sp.oy,pal.sea,
					sp.sc,sp.fl,sp.ro,sp.sw,sp.sh)
			else
				if s.lv>9 then swpPal(pal.enemy,pal.red) end
				spr(sp.id,
					round(s.x)-sp.ox,s.y-sp.oy,pal.sea,
					sp.sc,sp.fl,sp.ro,sp.sw,sp.sh)
				-- level number
				swpPal(pal.enemy,pal.sea)
				spr(128+s.lv,
					round(s.x)-sp.ox+8*sp.sc-3*sp.fl*sp.sc,
					s.y-sp.oy,pal.sea,
					sp.sc,0,sp.ro,1,1)
				swpPal(pal.enemy)
			end
		end
	end
end

function drawNavalMines()
	for i,m in ipairs(ec.mines) do
		if m.sh then
			local sp=m.spd
			local ma=m.ani
			-- different size on explosion
			if ma.st>=2 then
				spr(sp.id+ma.cf+5-16,
				m.x-sp.ox,m.y-sp.oy-10,
				pal.sea,sp.sc,sp.fl,sp.ro,
				sp.sw,sp.sh+1)
			elseif ma.st==1 and ma.cf>0 then
				spr(sp.id+ma.cf+ma.st*2-16,
				m.x-sp.ox,m.y-sp.oy-10,
				pal.sea,sp.sc,sp.fl,sp.ro,
				sp.sw,sp.sh+1)
			else
				spr(sp.id+ma.cf+ma.st*2,
					m.x-sp.ox,m.y-sp.oy-ma.st*2,
					pal.sea,sp.sc,sp.fl,sp.ro,
					sp.sw,sp.sh)
			end
		end
	end
end

function drawRadarSymbols(t)
	local radx=(VW-RADW)//2
	local triw=(RADW-8)//3-1
	if ec.player and ec.player.show then
		local p=ec.player
		local x=p.x/VW*(RADW-triw*2)
		spr(177,radx+triw+x,VH+5,
			pal.sea,1,0,0,1,1)
	end
	if ec.subs then
		for i,s in ipairs(ec.subs) do
			local x=(s.x+VW//2)/(VW*2)*(RADW-8)
			local y=(s.y-AIRH)/(VH-AIRH)*(HUDH-12)
			if s.lv>9 then swpPal(pal.radar,pal.symbol) else swpPal(pal.radar) end
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
	drawRadarSymbols(t)
	if t==nil or t%120<60 then
		printf("SCORE",8,VH+4)
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

function playBgm(n)
	if not var.mute and n>0 then
		music(n-1,-1,-1,Y)
	else
		music()
	end
end

function playSe(n,t,v)
	local sfxlib={
		[sfn.explo] =function() sfx(sfn.explo,"G-3",t or 40,sfn.explo,v or 15)  end,
		[sfn.charge]=function() sfx(sfn.charge,"C-2",t or 40,sfn.charge,v or 8) end,
		[sfn.mine]  =function() sfx(sfn.mine,"C-8",t or 60,sfn.mine,v or 15) end,
	}
	local se=sfxlib[n]
	if not var.mute and se then se() end
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

function sgn(v)
	return v==0 and 0 or v>0 and 1 or -1
end

function round(v,m)
	m=m or 1
	return int(v/m+0.5*sgn(v))*m
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
