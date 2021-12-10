local PALETTES = {
{name="DB16",   data="140c1c44243430346d4e4a4e854c30346524d04648757161597dced27d2c8595a16daa2cd2aa996dc2cadad45edeeed6"},
{name="PICO-8", data="0000007e25531d2b535f574fab5236008751ff004d83769cff77a8ffa300c2c3c700e756ffccaa29adfffff024fff1e8"},
{name="ARNE16", data="0000001b2632005784493c2ba4642244891abe26332f484e31a2f2eb89319d9d9da3ce27e06f8bb2dceff7e26bffffff"},
{name="EDG16",  data="193d3f3f2832743f399e2835b86f50327345e53b444f67810484d1fb922bafbfd263c64de4a6722ce8f4ffe762ffffff"},
{name="A64",    data="0000004c3435313a9148545492562b509450b148638080787655a28385cf9cabb19ccc47cd93738fbfd5bbc840ede6c8"},
{name="C64",    data="00000057420040318d5050508b542955a0498839327878788b3f967869c49f9f9f94e089b8696267b6bdbfce72ffffff"},
{name="VIC20",  data="000000772d2642348ba85fb4b668627e70caa8734a559e4ae99df5e9b287bdcc7185d4dc92df87c5ffffffffb0ffffff"},
{name="CGA",    data="000000aa00000000aa555555aa550000aa00ff5555aaaaaa5555ffaa00aa00aaaa55ff55ff55ff55ffffffff55ffffff"},
{name="EGA",    data="0000000000aa00aa0000aaaaaa0000aa00aaaa5500aaaaaa5555555555ff55ff5555ffffff5555ff55ffffff55ffffff"},
{name="MSX",    data="0000000000aa00aa0000aaaaaa0000aa00aaaa5500aaaaaa5555550000ff00ff0000ffffff0000ff00ffffff00ffffff"},
{name="MSWIN",  data="0000007e7e7ebebebeffffff7e0000ff0000007e0000ff007e7e00ffff0000007e0000ff7e007eff00ff007e7e00ffff"},	
{name="GRAYS",  data="000000111111222222333333444444555555666666777777888888999999aaaaaabbbbbbccccccddddddeeeeeeffffff"},
{name="SGB",    data="000000525252acacac8b838b000000ff3152ffe652837b9c0000007b73e6b4c5ffa4a4a40000006a2929bd7352ffffff"},
{name="SLIFE",  data="0000001226153f28117a2222513155d13b27286fb85d853acc8218e07f8a9b8bff68c127c7b581b3e868a8e4d4ffffff"},
{name="JMP",    data="000000191028833129453e78216c4bdc534b7664fed365c846af45e18d79afaab9d6b97b9ec2e8a1d685e9d8a1f5f4eb"},
{name="CGARNE", data="0000002234d15c2e788a36225e606e0c7e45e23d69aa5c3d4c81fb44aacceb8a60b5b5b56cd9477be2f9ffd93fffffff"},
{name="PSYG",   data="0000001b1e29003308362747084a3c443f41a2324e52524c546a0073615064647c516cbf77785be08b799ea4a7cbe8f7"},
{name="EROGE",  data="0d080d2a23494f2b247d384032535f825b314180a0c16c5bc591547bb24e74adbbe89973bebbb2f0bd77fbdf9bfff9e4"},
{name="EISLAND",data="051625794765686086567864ca657e8686918184abcc8d867ea78839d4b98dbcd29dc085edc38de6d1d1f5e17af6f6bf"},
{name="SWEETIE-16",
                data="1a1c2c5d275db13e53ef7d57ffcd75a7f07038b76425717929366f3b5dc941a6f673eff7f4f4f494b0c2566c86333c57"},
}

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

function loadPalette(name)
	for i,v in ipairs(PALETTES) do
		if v.name==name then
			pals(v.data)
			return
		end
	end
end
