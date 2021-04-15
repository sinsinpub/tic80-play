-- title:  breakout clone
-- author: digitsensitive
-- desc:   a breakout clone in lua for TIC-80
-- script: lua

SW = 240
SH = 136

function init()
	music()
	bgColor = 0
	score = 0
	lives = 3

	-- our player
	player = {
		x = (SW//2)-12,
		y = 120,
		width = 24,
		height = 4,
		color = 6,
		speed = {
			x = 0,
			max = 4
		}
	}

	-- ball
	ball = {
		x = player.x+(player.width//2)-2,
		y = player.y-4,
		width = 4,
		height = 4,
		color = 14,
		deactive = true,
		speed = {
			x = 0,
			y = 0,
			max = 1.5
		}
	}

	-- bricks
	bricks = {}
	brickCountWidth = 12
	brickCountHeight = 8
	brickWidth = 17
	brickHeight = 7
f
	-- create bricks
	for i=0, brickCountHeight, 1 do
		for j=0, brickCountWidth, 1 do
			local brick = {
				x = 10+j * brickWidth,
				y = 10+i * brickHeight,
				width = brickWidth,
				height = brickHeight,
				color = i+4
			}
			table.insert(bricks, brick)
		end
	end
end

init()

function TIC()
	cls(backgroundColor)
	input()
	if lives>0 then
		update()
		collisions()
		draw()
	elseif lives<=0 then
		gameOver()
	end
end

function input()
	local sx = player.speed.x
	local smax = player.speed.max

	-- move to left
	if btn(2) then
		if sx>-smax then
			sx=sx-2
		else
			sx=-smax
		end
	end

	-- move to right
	if btn(3) then
		if sx<smax then
			sx=sx+2
		else
			sx=smax
		end
	end

	player.speed.x=sx
	player.speed.max=smax

	if ball.deactive then
		ball.x = player.x+(player.width//2)-ball.width//2
		ball.y = player.y-ball.height-ball.speed.y

		if btnp(0) or btnp(4) or btnp(5) then
			sfx(0,"E-7",3)
			ball.speed.x = math.random()*(ball.speed.max*2)-ball.speed.max
			ball.speed.y = -1.5
			ball.deactive = false
		end
		if btnp(6) then player.width = 36 end
		if btnp(7) then player.width = 24 end
	else
		if btnp(0) then
			ball.speed.x = ball.speed.x*2
			if ball.speed.x < 0 then
				ball.speed.x = math.max(ball.speed.x, -ball.speed.max)
			else
				ball.speed.x = math.min(ball.speed.x, ball.speed.max)
			end
			ball.speed.y = ball.speed.y*2
			if ball.speed.y < 0 then
				ball.speed.y = math.max(ball.speed.y, -ball.speed.max)
			else
				ball.speed.y = math.min(ball.speed.y, ball.speed.max)
			end
		end
		if btnp(1) then
			ball.speed.x = ball.speed.x/2
			ball.speed.y = ball.speed.y/2
		end
	end
end

function update()
	local px = player.x
	local psx = player.speed.x
	local smax = player.speed.max

	-- update player position
	px=px+psx

	-- reduce player speed
	if psx ~= 0 then
		if psx > 0 then
			psx=psx-1
		else
			psx=psx+1
		end
	end

	player.x=px
	player.speed.x=psx
	player.speed.max=smax

	-- update ball position
	ball.x = ball.x + ball.speed.x
	ball.y = ball.y + ball.speed.y

	-- check max ball speed
	if ball.speed.x > ball.speed.max then
		ball.speed.x = ball.speed.max
	end
end

function collisions()
	-- player <-> wall collision
	playerWallCollision()

	-- ball <-> wall collision
	ballWallCollision()

	-- ball <-> ground collision
	ballGroundCollision()

	-- player <-> ball collision
	playerBallCollision()

	-- ball <-> brick collision
	ballBrickCollision()
end

function playerWallCollision()
	if player.x < 0 then
		player.x = 0
	elseif player.x+player.width > SW then
		player.x = SW - player.width
	end
end

function ballWallCollision()
	if ball.y < 0 then
		-- top
		ball.y = 0
		ball.speed.y = -ball.speed.y
	elseif ball.x < 0 then
		-- left
		ball.x = 0
		ball.speed.x = -ball.speed.x
	elseif ball.x > SW - ball.width then
		-- right
		ball.x = SW - ball.width
		ball.speed.x = -ball.speed.x
	end
end

function ballGroundCollision()
	if ball.y > SH - ball.width then
		-- reset ball
		ball.deactive = true
		-- loss a life
		if lives > 0 then
			lives = lives - 1
		end
		if lives <= 0 then
			-- game over
			music(0,-1,-1,false)
			gameOver()
		end
	end
end

function playerBallCollision()
	if collide(player, ball) then
		sfx(0,"E-7",3)
		ball.y = ball.y - ball.speed.y
		ball.speed.y = -ball.speed.y
		if collide(player, ball) then
			if player.speed.x < 0 then
				ball.speed.x = -math.abs(ball.speed.x)
		 else
				ball.speed.x = math.abs(ball.speed.x)
			end
			if ball.x < player.x + player.width//2 then
				ball.x = player.x - ball.width
			else
				ball.x = player.x + player.width
			end
			ball.y = player.y - ball.height
		else
			ball.speed.x = ball.speed.x + 0.3*player.speed.x
		end
	end
end

function collide(a, b)
	-- get parameters from a and b
	local ax = a.x
	local ay = a.y
	local aw = a.width
	local ah = a.height
	local bx = b.x
	local by = b.y
	local bw = b.width
	local bh = b.height

	-- check collision
	if ax < bx+bw and
				ax+aw > bx and
				ay < by+bh and
				ah+ay > by then
					-- collision
					return true
	end
	-- no collision
	return false
end

function ballBrickCollision()
	for i,brick in pairs(bricks) do
		-- get parameters
		local x = bricks[i].x
		local y = bricks[i].y
		local w = bricks[i].width
		local h = bricks[i].height
	
		-- check collision
		if collide(ball, bricks[i]) then
			-- collide left or right side
			if y < ball.y and
				ball.y < y+h and
				ball.x <= x or
				x+w <= ball.x then
					ball.speed.x = -ball.speed.x
			end
			-- collide top or bottom side
			if ball.y < y or
				y < ball.y and
				x < ball.x and
				ball.x < x+w then
					ball.speed.y = -ball.speed.y
			end
			table.remove(bricks, i)
			score = score + 1
			sfx(0,"C-8",3)
		end
	end
end

function draw()
	drawEntities()
	drawHud()
end

function drawEntities()
	-- draw player
	rect(player.x,
		player.y,
		player.width,
		player.height,
		player.color)

	-- draw ball
	spr(2,ball.x,ball.y,0)
	--[[
	rect(ball.x,
		ball.y,
		ball.width,
		ball.height,
		ball.color)
	]]
	--[[
	circ(ball.x+ball.width//2,
		ball.y+ball.height//2,
		ball.width//2+1,
		ball.color)
	]]

	-- draw bricks
	for i,brick in pairs(bricks) do
		rectb(bricks[i].x,
								bricks[i].y,
								bricks[i].width,
								bricks[i].height,
								0)
		rect(bricks[i].x,
							bricks[i].y,
							bricks[i].width-1,
							bricks[i].height-1,
							bricks[i].color)
	end
end

function drawHud()
	print("SCORE ",5,1,3)
	print(score,40,1,7)
	print("SCORE ",5,0,6)
	print(score,40,0,15)
	print("LIVES ",190,1,3)
	print(lives,225,1,7)
	print("LIVES ",190,0,6)
	print(lives,225,0,15)
end

function gameOver()
	print("GAME OVER",(SW//2)-6*4.5,SH//2,15)
	if btn(4) or btn(5) then
		init()
	end
	if btn(6) or btn(7) then
		exit()
	end
end
