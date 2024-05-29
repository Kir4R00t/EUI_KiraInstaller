--==========================================================
-- Re-written by bc1 using Notepad++
-- Caches stuff and defines AddSerialEventGameMessagePopup
--==========================================================

--print( "Lua memory in use: ", Locale.ToNumber( collectgarbage("count") * 1024, "#,###,###,###" ), "ContextID", ContextPtr:GetID(), "isHotLoad", ContextPtr:IsHotLoad() )
local GameInfo = GameInfoCache or GameInfo

include "FLuaVector"
local Color = Color
local ColorWhite = Color( 1, 1, 1, 1 )

--==========================================================
-- Minor lua optimizations
--==========================================================

local print = print

local IsCiv5 = InStrategicView ~= nil
local GameInfoIconTextureAtlases = GameInfo.IconTextureAtlases
local GameInfoCivilizations = GameInfo.Civilizations
local GameInfoPlayerColors = GameInfo.PlayerColors
local GameInfoColors = GameInfo.Colors
local GetCivilization = PreGame.GetCivilization
local GetCivilizationColor = PreGame.GetCivilizationColor

local IconTextureAtlasCache = setmetatable( {}, { __index = function( IconTextureAtlasCache, name )
	local atlas = {}
	if name then
		for row in GameInfoIconTextureAtlases{ Atlas=name } do
			atlas[ row.IconSize ] = { row.Filename, row.IconsPerRow, row.IconsPerColumn }
		end
		IconTextureAtlasCache[ name ] = atlas
	end
	return atlas
end})

-- cache only ingame, pregame player slots can change
local Cache = Game and function( value, table, key )
	table[ key or false ] = value or false
	return value
end or function( value )
	return value
end

local PlayerCivilizationInfo = setmetatable( {}, { __index = function( table, playerID )
	return Cache( GameInfoCivilizations[ GetCivilization( playerID or -1 ) ], table, playerID )
end})

local function GetPlayerColor( playerID, RGB )
	local playerCivilizationInfo = PlayerCivilizationInfo[ playerID ]
	local color = playerCivilizationInfo and ( GameInfoPlayerColors[ GetCivilizationColor( playerID ) ] or GameInfoPlayerColors[ playerCivilizationInfo.DefaultPlayerColor ] )
	color = color and GameInfoColors[ color[ (playerCivilizationInfo.Type ~= "CIVILIZATION_MINOR")==(RGB==1) and "PrimaryColor" or "SecondaryColor" ] ]
	return color and Color( color.Red, color.Green, color.Blue, color.Alpha ) or Color( RGB, RGB, RGB, 1 )
end

local IsPlayerUsingCustomColor = setmetatable( {}, { __index = function( table, playerID )
	local playerCivilizationInfo = PlayerCivilizationInfo[ playerID ]
	local defaultColorSet = playerCivilizationInfo and GameInfoPlayerColors[ playerCivilizationInfo.DefaultPlayerColor ]
	return Cache( not defaultColorSet or playerCivilizationInfo.Type == "CIVILIZATION_MINOR" or defaultColorSet.ID ~= GetCivilizationColor( playerID ), table, playerID )
end})

PrimaryColors = setmetatable( {}, { __index = function( table, playerID )
	return Cache( GetPlayerColor( playerID, 1 ), table, playerID )
end}) local PrimaryColors = PrimaryColors

BackgroundColors = setmetatable( {}, { __index = function( table, playerID )
	return Cache( GetPlayerColor( playerID, 0 ), table, playerID )
end}) local BackgroundColors = BackgroundColors

--==========================================================
-- AddSerialEventGameMessagePopup is a more efficient EUI
-- substitute for Events.SerialEventGameMessagePopup.Add
--==========================================================
function AddSerialEventGameMessagePopup( handler, ... )
	for _, popupType in pairs{...} do
		LuaEvents[popupType].Add( handler )
	end
	LuaEvents.AddSerialEventGameMessagePopup( ... )
end

--==========================================================
function IconLookup( index, size, atlas )
	local entry = index and IconTextureAtlasCache[ atlas ][ size ]
	if entry then
		local numCols = entry[2] or 1
		local x = index % numCols
		return { x = x * size, y = (index-x) * size / numCols }, entry[1]
	end
end

--==========================================================
function IconHookup( index, size, atlas, control )
	local entry = control and index and IconTextureAtlasCache[ atlas ][ size ]
	if entry then
		control:SetTexture( entry[1] or "blank.dds" )
		local numCols = entry[2] or 1
		local x = index % numCols
		control:SetTextureOffsetVal( x * size, (index-x) * size / numCols )
		return true
	end
	print( "Could not hookup icon index:", index, "size:", size, "atlas:", atlas, "to control:", control, control and control:GetID() )
end
local IconHookup = IconHookup

--==========================================================
-- Civilization icon hookup takes into account the fact
-- that player colors are dynamically handed out
-- and ensures a glossy icon look whenever possible
--==========================================================
local downSizes = { [80] = 64, [64] = 48, [57] = 45, [45] = 32, [32] = 24 }
local textureOffsetX = IsCiv5 and { [80] = 141, [64] = 78, [45] = 32, [32] = 0 } or { [80] = 200, [64] = 137, [57] = 80, [45] = 32, [32] = 0 }
local textureOffsetY = { [80] = 9, [64] = 9, [57] = 7, [45] = 7, [32] = 4 }
local unknownCiv = { PortraitIndex = IsCiv5 and 23 or 24, IconAtlas = "CIV_COLOR_ATLAS" }
function CivIconHookup( playerID, size, alphaIcon, colorIcon, glossIcon, _, _, _ )
-- eg colorIcon 32, glossIcon 24, alphaIcon 24, [unused highlightControl 32]
	-- not using the Firaxis highlighting control
	if _ then
		_:SetHide( true )
	end
	local playerCivilizationInfo = PlayerCivilizationInfo[ playerID ]
	if playerCivilizationInfo then
		if IsPlayerUsingCustomColor[ playerID ] then
			-- Foreground primary color alpha icon
			if alphaIcon then
				IconHookup( playerCivilizationInfo.PortraitIndex, downSizes[ size ] or size, playerCivilizationInfo.AlphaIconAtlas, alphaIcon )
				alphaIcon:SetColor( PrimaryColors[ playerID ] )
				alphaIcon:SetHide( false )
			end

			if playerCivilizationInfo.Type ~= "CIVILIZATION_MINOR" then

				local x = textureOffsetX[ size ] or 0
				-- Background color circle
				if colorIcon then
					colorIcon:SetTexture( "CivIconBGSizes.dds" )
					colorIcon:SetTextureOffsetVal( x, 0 )
					colorIcon:SetColor( BackgroundColors[ playerID ] )
				end
				-- Firaxis shadowing is repurposed to highlight for prettiness: texture & color must be tweaked
				if glossIcon then
					local y = textureOffsetY[ size ] or 0
					glossIcon:SetTexture( "CivIconBGSizes_Highlight.dds" )
					glossIcon:SetTextureOffsetVal( x + y, y )
					glossIcon:SetColor( ColorWhite )
					glossIcon:SetHide( false )
				end

				return
			end
		elseif alphaIcon then
			alphaIcon:SetHide( true )
		end
	else
		if alphaIcon then
			alphaIcon:SetHide( true )
		end
		playerCivilizationInfo = unknownCiv
	end
	-- use the pretty pre-defined color icon with built-in highlight
	if glossIcon then
		glossIcon:SetHide( true )
	end
	if colorIcon then
		colorIcon:SetColor( ColorWhite )
		return IconHookup( playerCivilizationInfo.PortraitIndex, size, playerCivilizationInfo.IconAtlas, colorIcon )
	end
end

--==========================================================
-- Simple civilization icon hookup ignores the fact
-- that player colors are dynamically handed out
-- and uses the pretty pre-defined color icon
--==========================================================
function SimpleCivIconHookup( playerID, size, control )
	local playerCivilizationInfo = PlayerCivilizationInfo[ playerID ] or unknownCiv
	return IconHookup( playerCivilizationInfo.PortraitIndex, size, playerCivilizationInfo.IconAtlas, control )
end
