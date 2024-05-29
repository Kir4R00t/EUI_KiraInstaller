-------------------------------------------------
-- Advanced Settings Screen
-------------------------------------------------

local ipairs = ipairs
local pairs = pairs
local print = print

local min = math.min
local floor = math.floor
local sort = table.sort
local insert = table.insert
local concat = table.concat
local format = string.format

local Controls = Controls
local SlotStatus = SlotStatus
local PreGame = PreGame
local Query = DB.Query
local Locale = Locale
local eLClick = Mouse.eLClick
local GameInfo = GameInfo
local GameDefines = GameDefines
local Path = Path
local UI = UI
local Modding = Modding
local UIManager = UIManager
local ContextPtr = ContextPtr
local Events = Events
local KeyDown = KeyEvents.KeyDown
local VK_ESCAPE = Keys.VK_ESCAPE
local SystemUpdateUITypeScreenResize = SystemUpdateUIType.ScreenResize

-------------------------------------------------
-- "Globals"
-------------------------------------------------
local g_SlotInstances = {}	-- Container for all player slots
local g_IsModding, g_IsHotSeat

local g_AIdefaultHandicapID = (GameInfo.HandicapInfos.HANDICAP_AI_DEFAULT or {}).ID

local g_SlotStatusInfo = {
	[ SlotStatus.SS_OPEN ] = { "TXT_KEY_SLOTTYPE_OPEN", "TXT_KEY_SLOTTYPE_OPEN_TT" },
	[ SlotStatus.SS_COMPUTER ] = { "TXT_KEY_SLOTTYPE_AI", "TXT_KEY_SLOTTYPE_AI_TT" },
	[ SlotStatus.SS_CLOSED ] = { "TXT_KEY_SLOTTYPE_CLOSED", "TXT_KEY_SLOTTYPE_CLOSED_TT" },
	[ SlotStatus.SS_TAKEN ] = { "TXT_KEY_PLAYER_TYPE_HUMAN", "TXT_KEY_SLOTTYPE_HUMAN_TT" },
	[ SlotStatus.SS_OBSERVER ] = { "TXT_KEY_SLOTTYPE_OBSERVER", "TXT_KEY_SLOTTYPE_OBSERVER_TT" },
}

local g_RandomMap = {
	Name = "TXT_KEY_RANDOM_MAP_SCRIPT",
	Description = "TXT_KEY_RANDOM_MAP_SCRIPT_HELP",
}

local g_RandomCiv = {
	ID = -1,
	Description = "TXT_KEY_RANDOM_CIV",
	ShortDescription = "TXT_KEY_POPUP_CIVILIZATION",
	PortraitIndex = 23,
	IconAtlas = "CIV_COLOR_ATLAS",
	LeaderID = -1,
	LeaderDescription = "TXT_KEY_RANDOM_LEADER",
	LeaderPortraitIndex = 22,
	LeaderIconAtlas = "LEADER_ATLAS",
}

local g_RequestInit = true
local g_GameCivs, g_GameCivList, g_MapCivList
local g_MaxMinorCivs = 41

local function LocalizeAndSetTextAndToolTip( control, textKey, tipKey )
	control:LocalizeAndSetText( textKey or "" )
	if tipKey and tipKey~="" then
		control:LocalizeAndSetToolTip( tipKey )
	else
		control:SetToolTipString()
	end
end

local function SortNames( a, b )
	return Locale.Compare( a.Name, b.Name ) == -1
end

local function SortSpeeds( a, b )
	return b.VictoryDelayPercent > a.VictoryDelayPercent
end

local function SortCivs( a, b )
	return Locale.Compare( a.LeaderDescription, b.LeaderDescription ) == -1
end

local function DisplayHandicap( control, handicap )
	return LocalizeAndSetTextAndToolTip( control, handicap.Description, handicap.ID == g_AIdefaultHandicapID and "TXT_KEY_SLOTTYPE_AI_TT" or handicap.Help )
end

local function CancelPlayerDetails( playerID )
	PreGame.SetLeaderName( playerID, "" )
	PreGame.SetCivilizationDescription( playerID, "" )
	PreGame.SetCivilizationShortDescription( playerID, "" )
	PreGame.SetCivilizationAdjective( playerID, "" )
	PreGame.SetNickName( playerID, "" )
end

local function SetScenarioCivilization( playerID, civID )
	for i = 0, GameDefines.MAX_MAJOR_CIVS-1 do
		if PreGame.GetCivilization( i ) == civID then
			PreGame.SetCivilization( i, PreGame.GetCivilization( playerID ) )
			UI.MoveScenarioPlayerToSlot( i, playerID )
			break
		end
	end
	PreGame.SetCivilization( playerID, civID )
	return CancelPlayerDetails( playerID )
end

local g_MaxPlayerID = 0

local function PerformRefresh()
	local info, pullDown, button, team, isHuman, isPlaying, slotStatus
	local playerCount = 0
	local humanCount = 0

	for playerID, instance in ipairs( g_SlotInstances ) do
		slotStatus = PreGame.GetSlotStatus( playerID )
		isHuman = slotStatus == SlotStatus.SS_TAKEN
		isPlaying = isHuman or slotStatus == SlotStatus.SS_COMPUTER
--		instance.Root:SetHide( not isPlaying )
		if isPlaying then
			playerCount = playerCount + 1
			if isHuman then
				humanCount = humanCount + 1
				g_MaxPlayerID = playerID
			end
		end
		instance.CivNumberIndex:LocalizeAndSetText( "TXT_KEY_MULTIPLAYER_DEFAULT_PLAYER_NAME", playerID+1 )
		-- Games must always have at least 2 players
		instance.RemoveButton:SetHide( playerCount < 3 or g_MapCivList )

		-- Handicap
		pullDown = instance.HandicapPullDown
		DisplayHandicap( pullDown:GetButton(), GameInfo.HandicapInfos[ PreGame.GetHandicap( playerID ) ] )
		info = g_SlotStatusInfo[ slotStatus ] or {}
		LocalizeAndSetTextAndToolTip( instance.SlotStatus, info[1], info[2] )
	end
	Controls.CivCount:LocalizeAndSetText( "TXT_KEY_AD_SETUP_PLAYER_COUNT", humanCount )
	PreGame.SetGameType( humanCount > 1 and GameTypes.GAME_HOTSEAT_MULTIPLAYER or GameTypes.GAME_SINGLE_PLAYER )
	local s = humanCount > 1 and "{TXT_KEY_MULTIPLAYER_HOTSEAT_GAME:upper}" or "{TXT_KEY_SINGLE_PLAYER:upper}"
	Controls.SlotStack:CalculateSize()
	Controls.SlotStack:ReprocessAnchoring()
	Controls.ListingScrollPanel:CalculateInternalSize()
	Controls.TitleLabel:LocalizeAndSetText( "[COLOR_RED]{1} {TXT_KEY_SCENARIOS}", s )
end

----------------------------------------------------------------
-- Handlers
----------------------------------------------------------------
local function ClosePopup()
	UIManager:DequeuePopup( ContextPtr )
end

Controls.BackButton:RegisterCallback( eLClick, ClosePopup )

ContextPtr:SetInputHandler( function( uiMsg, wParam )
	if uiMsg == KeyDown then
		if wParam == VK_ESCAPE then
		    ClosePopup()
			return true
		end
	end
end)

local slotStatus = {} for k, v in pairs( SlotStatus ) do slotStatus[ v ] = k end
local gameTypes = {} for k, v in pairs( GameTypes ) do gameTypes[ v ] = k end

local function CivReport( n, s )
	local t = {}
	for playerID=0, n-1 do
		insert( t, format( "\n\tplayer %-4iteam %-4i%-22s%-14sciv %-4i%s",
						playerID, PreGame.GetTeam( playerID ), GameInfo.HandicapInfos[ PreGame.GetHandicap( playerID ) ].Type, slotStatus[ PreGame.GetSlotStatus( playerID ) ], PreGame.GetCivilization( playerID ), PreGame.GetNickName( playerID ) ) )
	end
	return format( "%s: %s with %i minor civs, and the following major civs:%s", s, gameTypes[ PreGame.GetGameType() ], PreGame.GetNumMinorCivs(), concat(t) )
end

local getset = { [PreGame.GetSlotStatus] = PreGame.SetSlotStatus, [PreGame.GetHandicap] = PreGame.SetHandicap, [PreGame.GetNickName] = PreGame.SetNickName } --, [PreGame.GetCivilization] = PreGame.SetCivilization, [PreGame.GetTeam] = PreGame.SetTeam }

Controls.StartButton:RegisterCallback( eLClick, function()
	PreGame.SetPersistSettings( not g_IsModding and not g_IsHotSeat )
	local gameType = PreGame.GetGameType()
	local tt = {}
	local n = g_MaxPlayerID+2
	-- if PreGame.GetLoadWBScenario() then
		-- local wb = PreGame.GetMapScript()
		-- wb = wb and UI.GetMapPreview( wb )
		-- if wb then
			-- n = wb.PlayerCount
		-- end
	-- end
	print( CivReport( n, "Advanced settings set by user") )
	for playerID=0, n-1 do
		local t = {}
		for get, set in pairs( getset ) do
			t[ set ] = get( playerID )
		end
		tt[ playerID ] = t
	end
		
	Events.SerialEventStartGame.Add( function()
		Events.SerialEventStartGame.RemoveAll()
		print( CivReport( n, "Settings modified by game engine") )
		for playerID, t in pairs( tt ) do
			for set, v in pairs( t ) do
				set( playerID, v )
			end
		end
		PreGame.SetGameType( gameType )
		print( CivReport( n, "Revert to user settings") )
	end)
	ClosePopup()
end)

----------------------------------------------------------------
-- Visibility Handler
----------------------------------------------------------------
ContextPtr:SetShowHideHandler( function( bIsHide )
	if not bIsHide then
		Events.SerialEventStartGame.RemoveAll()
		g_IsModding = #Modding.GetActivatedMods() > 0
		g_IsHotSeat = PreGame.IsHotSeatGame()
print"PerformInit Difficulty"
		-- Difficulty
		for playerID, instance in pairs( g_SlotInstances ) do
			pullDown = instance.HandicapPullDown
			pullDown:ClearEntries()
			for handicap in GameInfo.HandicapInfos() do
				pullDown:BuildEntry( "InstanceOne", instance )
				DisplayHandicap( instance.Button, handicap )
				instance.Button:SetVoids( playerID, handicap.ID )
			end
			pullDown:CalculateInternals()
		end
		return PerformRefresh()
	end
end)

-----------------------------------------------------------------
-- Create slot instances
-----------------------------------------------------------------
local function RemovePlayer( playerID )
	PreGame.SetSlotStatus( playerID, SlotStatus.SS_CLOSED )
	return PerformRefresh()
end

local function SelectPlayerTeam( playerID, teamID )
	PreGame.SetTeam( playerID, teamID )
	return PerformRefresh()
end

local function SelectHandicap( playerID, handicapID )
	PreGame.SetSlotStatus( playerID, handicapID == g_AIdefaultHandicapID and SlotStatus.SS_COMPUTER or SlotStatus.SS_TAKEN )
	PreGame.SetHandicap( playerID, handicapID )
	return PerformRefresh()
end

local function SelectCivilization( playerID, civID )
	if g_MapCivList then
		SetScenarioCivilization( playerID, civID )
	else
		PreGame.SetCivilization( playerID, civID )
		CancelPlayerDetails( playerID )
	end
	return PerformRefresh()
end

local function SetCivName( playerID )
	UIManager:PushModal( Controls.SetCivNames )
	LuaEvents.SetCivNameEditSlot( playerID )
end

local function CancelCivName( playerID )
	CancelPlayerDetails( playerID )
	return PerformRefresh()
end

local instance, pullDown
for playerID = 0, GameDefines.MAX_MAJOR_CIVS-1, 1 do
	instance = {}
	g_SlotInstances[ playerID ] = instance
	ContextPtr:BuildInstanceForControl( "PlayerSlot", instance, playerID == 0 and Controls.HumanPlayer or Controls.SlotStack )
	instance.RemoveButton:RegisterCallback( eLClick, RemovePlayer )
	instance.RemoveButton:SetVoid1( playerID )
	pullDown = instance.TeamPullDown
	pullDown:ClearEntries()
	for teamID = 1, GameDefines.MAX_MAJOR_CIVS do
		pullDown:BuildEntry( "InstanceOne", instance )
		instance.Button:LocalizeAndSetText( "TXT_KEY_MULTIPLAYER_DEFAULT_TEAM_NAME", teamID )
		instance.Button:SetVoids( playerID, teamID-1 )
	end
	pullDown:CalculateInternals()
	pullDown:RegisterSelectionCallback( SelectPlayerTeam )
	instance.HandicapPullDown:RegisterSelectionCallback( SelectHandicap )
	instance.CivPullDown:RegisterSelectionCallback( SelectCivilization )
	instance.EditButton:SetVoid1( playerID )
	instance.EditButton:RegisterCallback( eLClick, SetCivName )
	instance.CancelButton:SetVoid1( playerID )
	instance.CancelButton:RegisterCallback( eLClick, CancelCivName )
end
