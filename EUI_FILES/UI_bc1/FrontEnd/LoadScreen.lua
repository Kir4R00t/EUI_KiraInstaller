--==========================================================
-- Game Loading Screen
-- Modified by bc1 from 1.0.3.276 code using Notepad++
--==========================================================

include "PopulateUniques" -- includes "IconHookup" & "GameInfoCache"
--local IconHookup = IconHookup
local CivIconHookup = CivIconHookup
local PopulateCivilizationUniques = PopulateCivilizationUniques
local GameInfo = GameInfoCache -- warning! booleans are true, not 1, and use iterator ONLY with table field conditions, NOT string SQL query
local VK_RETURN = Keys.VK_RETURN
local VK_ESCAPE = Keys.VK_ESCAPE
local KeyDown = KeyEvents.KeyDown

local Controls = Controls
local ToNumber = Locale.ToNumber
local PreGame = PreGame
local UI = UI
local UIManager = UIManager
local Game = Game
local Events = Events

local min = math.min
local max = math.max

local g_civID
local g_isLoadComplete = false
local g_startClock = os.clock()
print( "Lua memory in use:", ToNumber( collectgarbage("count") * 1024, "#,###,###,###" ), "Starting game...\n", ("-"):rep(100) )

Controls.ProgressBar:SetPercent( 1 )

ContextPtr:SetShowHideHandler( 
function( isHide, isInit )
	Controls.Image:UnloadTexture()
	Controls.ProgressBarTrim:UnloadTexture()
	if not isHide then
		UI.SetDontShowPopups(true)
		if not isInit then
			UIManager:SetUICursor( 1 )
			g_isLoadComplete = false

			Controls.AlphaAnim:SetToBeginning()
--			Controls.SlideAnim:SetToBeginning()
			Controls.ActivateButton:SetHide(true)
			Controls.ProgressBarTrim:SetTexture( "LoadingMeterTrim.dds" )

			-- Force some settings off when loading a HotSeat game.
			if not PreGame.IsMultiplayerGame() then
				PreGame.SetGameOption( "GAMEOPTION_DYNAMIC_TURNS", false )
				PreGame.SetGameOption( "GAMEOPTION_SIMULTANEOUS_TURNS", false )
				PreGame.SetGameOption( "GAMEOPTION_PITBOSS", false )
			end

			-- Sets up Selected Civ Slot
			local civ = GameInfo.Civilizations[ PreGame.GetCivilization( Game:GetActivePlayer() ) ]
			if civ then
				g_civID = civ.ID
				-- Use the Civilization_Leaders table to cross reference from this civ to the Leaders table
				local leader = GameInfo.Leaders[ GameInfo.Civilization_Leaders{ CivilizationType = civ.Type }().LeaderheadType ]

				-- Set Leader & Civ Text
				Controls.Civilization:LocalizeAndSetText( civ.Description )
				Controls.Leader:LocalizeAndSetText( leader.Description )
				-- Set Civ Leader Icon
-- there is no Portrait!!!	IconHookup( leader.PortraitIndex, 128, leader.IconAtlas, Controls.Portrait )

				-- Set Civ Icon
				CivIconHookup( Game.GetActivePlayer(), 80, Controls.CivIcon, Controls.CivIconBG, Controls.CivIconShadow )

				-- Sets Trait bonus Text
				local trait = GameInfo.Traits[ GameInfo.Leader_Traits{ LeaderType = leader.Type }().TraitType ]
				Controls.BonusTitle:LocalizeAndSetText( trait.ShortDescription )
				Controls.BonusDescription:LocalizeAndSetText( trait.Description )

				-- Sets Dawn of Man Quote
				Controls.Quote:LocalizeAndSetText( civ.DawnOfManQuote )

				-- Sets Dawn of Man Image
				Controls.Image:SetTextureAndResize( civ.DawnOfManImage )
				local x, y = UIManager:GetScreenSizeVal()
				local a = min( x-500, y/0.75 )
				local b = max( 500, x-a )
				Controls.Image:Resize( a, 0.75*a )
				Controls.Details:SetSizeX( b )
--				Controls.BonusDescription:SetWrapWidth( b*0.9 )
--				Controls.Quote:SetWrapWidth( b*0.9 )
				-- Sets Bonus Icons
				PopulateCivilizationUniques( Controls.SubStack, civ )
				Controls.SubStack:CalculateSize()
				Controls.MainStack:ReprocessAnchoring()
			end
			if g_civID then
				Events.SerialEventDawnOfManShow( g_civID )
			end
		end
	elseif not isInit then
		UIManager:SetUICursor( 0 )
		--print("Textures are unloaded")
		if g_civID then
			Events.SerialEventDawnOfManHide( g_civID )
		end
	end
end )
-------------
-- Start Game
-------------
local function OnActivateButtonClicked ()
	--print("Activate button clicked!")
	Events.LoadScreenClose()
	if not PreGame.IsMultiplayerGame() and not PreGame.IsHotSeatGame() then
		Game.SetPausePlayer( -1 )
	end

	UI.SetDontShowPopups( false )

	--UI.SetNextGameState( GameStates.MainGameView, g_iAIPlayer )
end
Controls.ActivateButton:RegisterCallback( Mouse.eLClick, OnActivateButtonClicked )


----------------------
-- Key Down Processing
ContextPtr:SetInputHandler(	function( uiMsg, wParam )
	if uiMsg == KeyDown then
		if g_isLoadComplete and ( wParam == VK_ESCAPE or wParam == VK_RETURN ) then
			OnActivateButtonClicked()
		end
		return true
	end
end)

---------------------
-- Game Init complete
---------------------
Events.SequenceGameInitComplete.Add(
function()
	print( "Lua memory in use: "..ToNumber( collectgarbage("count") * 1024, "#,###,###,###" ), "SequenceGameInitComplete in "..ToNumber( os.clock() - g_startClock, "#.###" ).." seconds.\n", ("-"):rep(100) )

	g_isLoadComplete = true
	-- zoom out
	Events.SerialEventCameraOut{ x=0, y=0 }
	Events.SerialEventCameraOut{ x=0, y=0 }
	Events.SerialEventCameraOut{ x=0, y=0 }

	if PreGame.IsMultiplayerGame() or PreGame.IsHotSeatGame() then
		OnActivateButtonClicked()
	else
		Game.SetPausePlayer( Game.GetActivePlayer() )
		Controls.ActivateButton:LocalizeAndSetText( UI.IsLoadedGame() and "TXT_KEY_BEGIN_GAME_BUTTON_CONTINUE" or "TXT_KEY_BEGIN_GAME_BUTTON" )
		Controls.ActivateButton:SetHide(false)
		Controls.AlphaAnim:Play()
		UIManager:SetUICursor( 0 )
	end
end )
