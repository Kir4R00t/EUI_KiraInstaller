-------------------------------------------------
-- Multiplayer Game Setup Screen
-------------------------------------------------
include( "InstanceManager" );
include( "MPGameOptions" );

-------------------------------------------------
-- The common Game Options handler code is in
-- MPGameOptions, which is used by the StagingRoom
-- as well as this UI
-------------------------------------------------
local g_isModding

local function OnBack()
	if not Network.IsDedicatedServer() then
		if not PreGame.IsHotSeatGame() then
			if PreGame.IsInternetGame() then
				Matchmaking.RefreshInternetGameList()
			else
				Matchmaking.RefreshLANGameList()
			end
		end
	end
	UIManager:DequeuePopup( ContextPtr )
end

Controls.LaunchButton:RegisterCallback( Mouse.eLClick, function()
	PreGame.SetPersistSettings( false ) -- Do not save these settings out for the "Play Now" option.

	if g_isModding and IsWBMap( PreGame.GetMapScript() ) then
		PreGame.SetRandomMapScript( false )
		PreGame.SetLoadWBScenario( PreGame.GetLoadWBScenario() )
	else
		PreGame.SetLoadWBScenario( false )
	end

	PreGame.SetLoadFileName( "" )
	PreGame.ResetSlots()

	local strGameName = Controls.NameBox:GetText()

	local worldInfo = GameInfo.Worlds[ PreGame.GetWorldSize() ];
	if Network.IsDedicatedServer() then
		PreGame.SetGameOption( "GAMEOPTION_PITBOSS", true )
		print( "HostServerGame", Matchmaking.HostServerGame( strGameName, worldInfo.DefaultPlayers, false ) )
	elseif PreGame.IsInternetGame() then
		print( "HostInternetGame", Matchmaking.HostInternetGame( strGameName, worldInfo.DefaultPlayers ) )
	elseif PreGame.IsHotSeatGame() then
		print( "HostHotSeatGame", Matchmaking.HostHotSeatGame( strGameName, worldInfo.DefaultPlayers ) )
	else
		print( "HostLANGame", Matchmaking.HostLANGame( strGameName, worldInfo.DefaultPlayers ) )
	end
end)

Controls.DefaultButton:RegisterCallback( Mouse.eLClick, function()
	ResetMultiplayerOptions();
	-- Uncheck Everything
	RefreshGameOptions();
	RefreshDropDownOptions();
	UpdateGameOptionsDisplay();
end)

Controls.LoadGameButton:RegisterCallback( Mouse.eLClick, function()
	Events.SystemUpdateUI( SystemUpdateUIType.RestoreUI, "LoadGameMenu" )
end)

Controls.PrivateGameCheckbox:RegisterCallback( Mouse.eLClick, function( isChecked )
	PreGame.SetPrivateGame( isChecked )
end)

Controls.BackButton:RegisterCallback( Mouse.eLClick, OnBack )

Controls.ExitButton:RegisterCallback( Mouse.eLClick, Events.UserRequestClose.Call )

ContextPtr:SetShowHideHandler( function( isHide, isInit )
	-- Check to make sure we are not launching, this menu can briefly get unhidden as the game launches
	if not ( isHide or Matchmaking.IsLaunchingGame() ) then
		g_isModding = #Modding.GetActivatedMods() > 0
		Controls.TitleLabel:LocalizeAndSetText( g_isModding and "TXT_KEY_MOD_MP_GAME_SETUP_HEADER" or "TXT_KEY_MULTIPLAYER_GAME_SETUP_HEADER" )
		Controls.ModsButton:SetHide( not g_isModding );
		SetInLobby( false )

		if PreGame.GetLoadFileName() == "" then
			-- Default these to their state in the options manager
			PreGame.SetQuickCombat( OptionsManager.GetMultiplayerQuickCombatEnabled() );
			PreGame.SetQuickMovement( OptionsManager.GetMultiplayerQuickMovementEnabled() );
			if Network.IsDedicatedServer() then
				PreGame.SetGameOption( "GAMEOPTION_PITBOSS", true )
			end
		end

		PopulateMapSizePulldown();
		RefreshMapScripts();
		PreGame.SetRandomMapScript(false);	-- Random map scripts is not supported in multiplayer
		UpdateGameOptionsDisplay( true )
		Controls.ExitButton:SetHide( not Network.IsDedicatedServer() )
		Controls.BackButton:SetHide( Network.IsDedicatedServer() )
		Controls.PrivateGameCheckbox:SetHide( not PreGame.IsInternetGame() )
		Controls.PrivateGameCheckbox:SetCheck( PreGame.IsPrivateGame() )
		Controls.GameNameBox:SetHide( PreGame.IsHotSeatGame() )
		Controls.GameNameDivider:SetHide( PreGame.IsHotSeatGame() )
		Controls.LaunchButton:LocalizeAndSetText( PreGame.GetLoadWBScenario() and "TXT_KEY_HOST_SCENARIO" or "TXT_KEY_HOST_GAME" )
	end
end)

ContextPtr:SetInputHandler( function( uiMsg, wParam )
	if uiMsg == KeyEvents.KeyDown then
		if wParam == Keys.VK_ESCAPE then
			OnBack();
			return true
		end
	end
end)

local function AdjustScreenSize()
	local _, screenY = UIManager:GetScreenSizeVal();

	local TOP_COMPENSATION = 52 + ((screenY - 768) * 0.3 );
	local BOTTOM_COMPENSATION = 222;
	if (PreGame.IsHotSeatGame()) then
	    Controls.OptionsScrollPanel:SetOffsetVal( 40, 44 );
	    BOTTOM_COMPENSATION = 160;
	end
	local SIZE = screenY - (TOP_COMPENSATION + BOTTOM_COMPENSATION);

	Controls.MainGrid:SetSizeY( screenY - TOP_COMPENSATION );
	Controls.OptionsScrollPanel:SetSizeY( SIZE );
	Controls.OptionsScrollPanel:CalculateInternalSize();
end

Events.SystemUpdateUI.Add( function( type )
	if( type == SystemUpdateUIType.ScreenResize ) then
		AdjustScreenSize();
	end
end)

AdjustScreenSize()