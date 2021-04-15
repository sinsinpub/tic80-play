-- title:  snippets
-- author: various
-- desc:   https://github.com/nesbox/TIC-80/wiki/code-examples-and-snippets
-- script: lua

-- Load palette string
function pals(hexs)
	for i=0,15 do
		local r=tonumber(string.sub(hexs,i*6+1,i*6+2),16)
		local g=tonumber(string.sub(hexs,i*6+3,i*6+4),16)
		local b=tonumber(string.sub(hexs,i*6+5,i*6+6),16)
		poke(0x3FC0+(i*3)+0,r)
		poke(0x3FC0+(i*3)+1,g)
		poke(0x3FC0+(i*3)+2,b)
	end
end

-- Swap c0 and c1 colors, no arg to reset
function swapPal(c0,c1)
	if c0==nil and c1==nil then
		for i=0,15 do poke4(0x3FF0*2+i,i) end
	else
		poke4(0x3FF0*2+c0,c1)
	end
end

-- Sets the palette index i to specified rgb
-- or return the colors if no rgb values
function pal(i,r,g,b)
	if i<0 then i=0 end
	if i>15 then i=15 end
	-- returning color r,g,b of the color
	if r==nil and g==nil and b==nil then
		return peek(0x3fc0+(i*3)),peek(0x3fc0+(i*3)+1),peek(0x3fc0+(i*3)+2)
	else
		if r==nil or r<0 then r=0 end
		if g==nil or g<0 then g=0 end
		if b==nil or b<0 then b=0 end
		if r>255 then r=255 end
		if g>255 then g=255 end
		if b>255 then b=255 end
		poke(0x3fc0+(i*3)+2,b)
		poke(0x3fc0+(i*3)+1,g)
		poke(0x3fc0+(i*3),r)
	end
end

function pad(s,l,c)
	s=tostring(s or "")
	c=c or "0"
	local right=l<0
	local el=math.abs(l)
	local sl=string.len(s)
	if sl<el then
		if right then
			s=s..string.rep(c,el-s)
		else
			s=string.rep(c,el-sl)..s
		end
	end
	return s
end

function inc(v,i)
	_G[v]=_G[v]+(i or 1)
end

function dec(v,i)
	_G[v]=_G[v]-(i or 1)
end

-- Set spritesheet pixel
function sset(x,y,c)
	local addr=0x4000+(x//8+y//8*16)*32
	poke4(addr*2+x%8+y%8*8,c)
end

-- Get spritesheet pixel
function sget(x,y)
	local addr=0x4000+(x//8+y//8*16)*32
	return peek4(addr*2+x%8+y%8*8)
end

local seen={}
function dump(t,i)
	seen[t]=true
	local s={}
	local n=0
	for k in pairs(t) do
		n=n+1 s[n]=k
	end
	table.sort(s)
	i=i or ""
	for k,v in ipairs(s) do
		trace(i..v)
		v=t[v]
		if type(v)=="table" and not seen[v] then
			dump(v,i.."\t")
		end
	end
end

cls()
trace("---------------------")
trace("All global variables:")
dump(_G,"\t")
trace("---------------------")

print("See all global variables in console!")

local t=0
local x,y=96,24
local shake,d=0,4
function TIC()

	if btn(0) then y=y-1 end
	if btn(1) then y=y+1 end
	if btn(2) then x=x-1 end
	if btn(3) then x=x+1 end
	if btnp(5) then shake=30 end
	if btnp(6) or btnp(7) then exit() end

	cls(13)
	rectb(0,0,240,136,14)
	line(1,1,238,134,12)
	line(1,134,238,1,12)
	
	spr(1+t%60//30*2,x,y,14,3,0,0,2,2)
	print("HELLO WORLD!",84,84)
	t=t+1

	if shake>0 then
		poke(0x3FF9,math.random(-d,d))
		poke(0x3FF9+1,math.random(-d,d))
		shake=shake-1		
		if shake==0 then memset(0x3FF9,0,2) end
	end

end
