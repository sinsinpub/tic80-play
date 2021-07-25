-- game title here
-- game author here

-- global vars
scene=0
score=0
screenwidth = 240
screenheight = 136
player = {}
player.x = screenwidth/2
player.y = screenheight/2
player.width = 7
player.height = 7

-- game loop

function TIC()
 _update()
	_draw()
end

function _init()
-- This function runs as soon as the game loads
end

function _update()
	if scene==0 then
		titleupdate()
	elseif scene==1 then
		gameupdate()
	end
end

function _draw()
	if scene==0 then
		titledraw()
	elseif scene==1 then
		gamedraw()
	end
end
-- update functions
function titleupdate()
	if btnp(4) then
		scene=1
	end
end

function gameupdate()
	score = score + 1
	playercontrol()
end

-- draw functions
function titledraw()
	local titletxt = "title screen"
	local starttxt = "press z to start"
	rect(0,0,screenwidth, screenheight, 3)
	print(titletxt, hcenter(titletxt), screenheight/4, 10)
	print(starttxt, hcenter(starttxt), (screenheight/4)+(screenheight/2),7)			
end

function gamedraw()
	local gametxt = "game screen"
	rect(0,0,screenwidth, screenheight, 12)
	rect(0,0,screenwidth, 10, 0)
	print("score: " .. score, 10, 4, 7)
	print(gametxt, hcenter(gametxt), hcenter(gametxt), 10)

	playerdraw()
end

-- handle button inputs
function playercontrol()
	if (btn(2)) then player.x=player.x-1 end
	if (btn(3)) then player.x=player.x+1 end
	if (btn(0)) then player.y=player.y-1 end
	if (btn(1)) then player.y=player.y+1 end

	-- check if the player is still onscreen
	if (player.x <= 0) then player.x = 0 end
	if (player.x >= screenwidth - player.width) then player.x = screenwidth - player.height end
	if (player.y <= 0) then player.y = 0 end
	if (player.y >= screenheight - player.height) then player.y = screenheight - player.height end

end

-- draw player sprite
function playerdraw()
	spr(1, player.x-4, player.y)
	spr(2, player.x+4, player.y)
	spr(17, player.x-4, player.y+8)
	spr(18, player.x+4, player.y+8)
end

-- library functions
--- center align from: pico-8.wikia.com/wiki/centering_text
function hcenter(s)
	-- string length time			s the 
	-- pixels in a char's width
	-- cut in half and rounded down
	return (screenwidth / 2)-((#s*4)//2)
end

function vcenter(s)
	-- string char's height
	-- cut in half and rounded down
	return (screenheight /2)-(5//2)
end

--- collision check
function iscolliding(obj1, obj2)
	local x1 = obj1.x
	local y1 = obj1.y
	local w1 = obj1.w
	local h1 = obj1.h
	
	local x2 = obj2.x
	local y2 = obj2.y
	local w2 = obj2.w
	local h2 = obj2.h

	if(x1 < (x2 + w2)  and (x1 + w1)  > x2 and y1 < (y2 + h2) and (y1 + h1) > y2) then
		return true
	else
		return false
	end
end
-- <TILES>
-- 001:efffffffff222222f8888888f8222222f8fffffff8ff0ffff8ff0ffff8ff0fff
-- 002:fffffeee2222ffee88880fee22280feefff80fff0ff80f0f0ff80f0f0ff80f0f
-- 003:efffffffff222222f8888888f8222222f8fffffff8fffffff8ff0ffff8ff0fff
-- 004:fffffeee2222ffee88880fee22280feefff80ffffff80f0f0ff80f0f0ff80f0f
-- 017:f8fffffff8888888f888f888f8888ffff8888888f2222222ff000fffefffffef
-- 018:fff800ff88880ffef8880fee88880fee88880fee2222ffee000ffeeeffffeeee
-- 019:f8fffffff8888888f888f888f8888ffff8888888f2222222ff000fffefffffef
-- 020:fff800ff88880ffef8880fee88880fee88880fee2222ffee000ffeeeffffeeee
-- </TILES>

-- <WAVES>
-- 000:00000000ffffffff00000000ffffffff
-- 001:0123456789abcdeffedcba9876543210
-- 002:0123456789abcdef0123456789abcdef
-- </WAVES>

-- <SFX>
-- 000:000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000304000000000
-- </SFX>

-- <PALETTE>
-- 000:140c1c44243430346d4e4a4e854c30346524d04648757161597dced27d2c8595a16daa2cd2aa996dc2cadad45edeeed6
-- </PALETTE>

