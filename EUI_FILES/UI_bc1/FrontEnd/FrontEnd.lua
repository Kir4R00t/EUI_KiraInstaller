-------------------------------------------------
-- FrontEnd
-- Re-written by bc1 using Notepad++
-------------------------------------------------

local ContextPtr = ContextPtr
local Controls = Controls
local textures
local history = ""

local screenX, screenY = UIManager:GetScreenSizeVal()

local function SetAtlasLogo( texture )
	Controls.AtlasLogo:SetTextureAndResize( texture )
	local x, y = Controls.AtlasLogo:GetSizeVal()
	local k = math.max( screenX/x, screenY/y )
	Controls.AtlasLogo:Resize( x*k, y*k )
end

local function SetRandomAtlasLogo()
	Controls.AtlasLogo:UnloadTexture()
	if ContextPtr:IsHidden() then
		Controls.Timer:Stop()
	else
		Controls.Timer:SetToBeginning()
		Controls.Timer:Play()
		Controls.FadeIn:SetToBeginning()
		Controls.FadeIn:Play()
		if not textures then
			textures = { "wonderconceptpanamacanal.dds", "wonderconceptthreegeorgesdam.dds" }
--[[
			local isBNW = ContentManager.IsActive( "6DA07636-4123-4018-B643-6575B4EC336B", ContentType.GAMEPLAY )
			local isGK = ContentManager.IsActive( "0E3751A1-F840-4e1b-9706-519BF484E59D", ContentType.GAMEPLAY )
			for i = 1, isBNW and 24 or isGK and 19 or 20 do
				if isBNW or not isGK or i~=12 then
					table.insert( textures, ((isBNW or isGK) and "loading_" or "loadingbasegame_")..i..".dds" )
				end
			end
--]]
			for row in DB.Query "SELECT WonderSplashImage from Buildings Where WonderSplashImage IS NOT NULL" do
				table.insert( textures, row.WonderSplashImage )
			end
		end
		local i, c
		repeat
			i = math.random(#textures)
			c = string.char( i )
		until not history:find( c, 1, true ) -- true = plain search, *not* pattern
		history = (c..history):sub(1,#textures/2)
		return SetAtlasLogo( textures[ i ] or "CivilzationVAtlas.dds" )
	end
end

Controls.Timer:RegisterAnimCallback( SetRandomAtlasLogo )
Controls.Button:RegisterCallback( Mouse.eLClick, SetRandomAtlasLogo )

ContextPtr:SetShowHideHandler( function( isHide, isInit )
--print( "SetShowHideHandler", "isHide", isHide, "isInit", isInit, "isHotLoad", ContextPtr:IsHotLoad(), "GameStarted:", PreGame.GameStarted() )
	if not isInit then
		Controls.AtlasLogo:UnloadTexture()
		Controls.Civ5Logo:UnloadTexture()
		Controls.Timer:Stop()
		if not ( isHide or Matchmaking.IsLaunchingGame() ) then
			Controls.FadeIn:SetToEnd()
			Controls.Civ5Logo:SetTextureAndResize( "CivilzationV_Logo.dds" )
			SetAtlasLogo( "CivilzationVAtlas.dds" )
			UIManager:QueuePopup( Controls.MainMenu, PopupPriority.MainMenu )
		end
	end
end)
