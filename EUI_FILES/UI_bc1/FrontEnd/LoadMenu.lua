--==========================================================
-- Modified by bc1 from 1.0.3.276 code using Notepad++
-- allow game load even when missing mod: by default "saved games" is checked but is actually rarely required
-- allow click to load game directly
--==========================================================

include "GameInfoCache" -- warning! booleans are true, not 1, and use iterator ONLY with table field conditions, NOT string SQL query
local GameInfo = GameInfoCache

include "StackInstanceManager"
include "UniqueBonuses" -- includes "IconHookup"
include "MapUtilities"

--==========================================================
-- Minor lua optimizations
--==========================================================

local ipairs = ipairs
local pairs = pairs
local print = print
local format = string.format
local insert = table.insert
local sort = table.sort

local ContextPtr = ContextPtr
local Controls = Controls
local Events = Events
local Game = Game
local CIV5_GS_MAINGAMEVIEW = GameStateTypes.CIV5_GS_MAINGAMEVIEW
local GameTypes = GameTypes
local IconHookup = IconHookup
local Compare = Locale.Compare
local L = Locale.ConvertTextKey
local MapUtilitiesGetBasicInfo = MapUtilities.GetBasicInfo
local Matchmaking = Matchmaking
local MultiplayerLobbyMode = MultiplayerLobbyMode
local Network = Network
local Modding = Modding
local Mouse = Mouse
local GetFileNameWithoutExtension = Path.GetFileNameWithoutExtension
local PreGame = PreGame
local Steam = Steam
local UI = UI
local UIManager = UIManager

local g_CloudSaves = {}
local g_FileList = {}
local g_InstanceManager = StackInstanceManager( "LoadButton", "Button", Controls.LoadFileButtonStack )

local g_Settings = { SortByPullDown=1, GameTypePulldown = PreGame.GetGameType() }
local g_StorageLocation = 0 -- 	STORAGE_LOCAL, STORAGE_STEAM_CLOUD, STORAGE_MEMORY
local g_SelectedID, g_IsAutoSave
local g_SavedGameModsRequired	-- The required mods for the currently selected save.
local g_SavedGameDLCRequired	-- The required DLC for the currently selected save.
local g_moddingErrorString = { nil,--1
		"TXT_KEY_MODDING_ERROR_SAVE_MISSING_DLC",--2
		"TXT_KEY_MODDING_ERROR_SAVE_DLC_NOT_PURCHASED",--3
		"TXT_KEY_MODDING_ERROR_SAVE_MISSING_MODS",--4
		"TXT_KEY_MODDING_ERROR_SAVE_INCOMPATIBLE_MODS",--5
				}
local g_GameTypeStrings = {
		[GameTypes.GAME_SINGLE_PLAYER] = L"TXT_KEY_SINGLE_PLAYER",
		[GameTypes.GAME_HOTSEAT_MULTIPLAYER] = L"TXT_KEY_MULTIPLAYER_HOTSEAT_GAME",
		[GameTypes.GAME_NETWORK_MULTIPLAYER] = L"TXT_KEY_MULTIPLAYER_STRING",
		[99] = L"TXT_KEY_STEAMCLOUD" }
local g_PulldownStrings = {
		SortByPullDown = { L"TXT_KEY_SORTBY_LASTMODIFIED" , L"TXT_KEY_SORTBY_NAME" },
		GameTypePulldown =  g_GameTypeStrings }
local g_gameTypeIsLocal = {
		[GameTypes.GAME_HOTSEAT_MULTIPLAYER] = true,
		[GameTypes.GAME_SINGLE_PLAYER] = true,
		}
local g_IconInfos = { MapType = false, PlayerCivilization = GameInfo.Civilizations, WorldSize = GameInfo.Worlds, Difficulty = GameInfo.HandicapInfos, GameSpeed = GameInfo.GameSpeeds }
local g_IconAtlas = { MapType = "WORLDTYPE_ATLAS", PlayerCivilization = "CIV_COLOR_ATLAS", WorldSize = "WORLDSIZE_ATLAS", Difficulty = "DIFFICULTY_ATLAS", GameSpeed = "GAMESPEED_ATLAS" }
local g_IconIndex = { MapType = 4, PlayerCivilization = 23, WorldSize = 6, Difficulty = 8, GameSpeed = 7 }

----------------------------------------------------------------
local function OnDelete()
	Controls.DeleteConfirm:SetHide(false)
end

local function OnNoDelete()
	Controls.DeleteConfirm:SetHide(true)
end

local function OnBack()
	UIManager:DequeuePopup( ContextPtr )
end

----------------------------------------------------------------
local function SortByName( a, b )
	if not a then
		return false
	else
		return not b or Compare( GetFileNameWithoutExtension( a ), GetFileNameWithoutExtension( b ) ) == -1
	end
end

local function SortByLastModified( a, b )
	if not a then
		return false
	else
		local high, low = UI.GetSavedGameModificationTimeRaw( a )
		return not b or UI.CompareFileTime( high, low, UI.GetSavedGameModificationTimeRaw( b ) ) == 1
	end
end

local g_SortFunctions = { SortByLastModified, SortByName } -- !!! order has to match g_PulldownStrings.SortByPullDown

----------------------------------------------------------------
local function StartSelected()
	local fileName, fileHeader
	if g_StorageLocation==1 then
		-- cloud save
		fileName = Steam.GetCloudSaveFileName( g_SelectedID )
		fileHeader = g_CloudSaves[ g_SelectedID ]
	else
		-- local save
		fileName = g_FileList[ g_SelectedID ]
		fileHeader = fileName and PreGame.GetFileHeader( fileName )
	end
--print( "StartSelected", g_GameTypeStrings[ PreGame.GetGameType() ], fileName, g_StorageLocation, fileHeader )
	if fileHeader then
-- CurrentEra, StartEra, LeaderName, MapScript, WorldSize, Difficulty, ActivatedMods {}, CivilizationName, TurnNumber, GameType, GameSpeed, PlayerColor, PlayerCivilization

		if PreGame.GetGameType() ~= fileHeader.GameType then
			PreGame.SetGameType( fileHeader.GameType )
			if PreGame.IsMultiplayerGame() then
				return Controls.MultiplayerChoice:SetHide( false )
			end
		end
		if PreGame.IsMultiplayerGame() then
			-- Multiplayer
			local worldInfo = GameInfo.Worlds[ fileHeader.WorldSize ]
			if worldInfo then
				PreGame.SetLoadFileName( fileName, g_StorageLocation==1 )
				PreGame.SetWorldSize( worldInfo.ID )
				local matchType = "HostLANGame" -- by default
				if Network.IsDedicatedServer() then
					PreGame.SetGameOption( "GAMEOPTION_PITBOSS", true )
					matchType = "HostServerGame"
				elseif PreGame.IsInternetGame() then
					matchType = "HostInternetGame"
				end
				UIManager:SetUICursor( 1 )
				-- Goto lobby
				print( matchType, fileName, Matchmaking[matchType]( fileHeader.MapScript:gsub(".*\\",""):gsub("%..*",""), PreGame.ReadActiveSlotCountFromSaveGame() ) )
			end
		else
			-- Single player or hotseat
			UIManager:SetUICursor( 1 )
			Events.PlayerChoseToLoadGame( fileName, g_StorageLocation==1 )
			print( "loading saved game", fileName, g_GameTypeStrings[ PreGame.GetGameType() ] )
		end
	end
end

----------------------------------------------------------------
local function SetSelected( index )
	Controls.LargeMapImage:UnloadTexture()
	local isInvalid
	local instance = g_InstanceManager[ g_SelectedID ]
	if instance then
		instance.SelectHighlight:SetHide( true )
	end
	g_SelectedID = index
	instance = g_InstanceManager[ index ]
	if instance then
		instance.SelectHighlight:SetHide( false )
		local fileHeader, fileName
		local isCloudSave = g_StorageLocation==1
		if isCloudSave then
			fileHeader = g_CloudSaves[ index ]
		else
			fileName = g_FileList[ index ]
			fileHeader = PreGame.GetFileHeader( fileName )
		end
		if fileHeader then
--[[
CurrentEra	ERA_MEDIEVAL
StartEra	ERA_ANCIENT
LeaderName	
MapScript	Assets\Maps\Continents.lua
WorldSize	WORLDSIZE_STANDARD
Difficulty	HANDICAP_EMPEROR
ActivatedMods	table: 1577E980
CivilizationName	
TurnNumber	140
GameType	0
GameSpeed	GAMESPEED_STANDARD
PlayerColor	PLAYERCOLOR_AUSTRIA
PlayerCivilization	CIVILIZATION_AUSTRIA
--]]
			--Set Save File Text
			Controls.SaveFileName:SetText( fileName and GetFileNameWithoutExtension( fileName ) )

			local currentEra = GameInfo.Eras[ fileHeader.CurrentEra ]
			Controls.EraTurn:LocalizeAndSetText( "TXT_KEY_CUR_ERA_TURNS_FORMAT", currentEra and currentEra.Description or "TXT_KEY_MISC_UNKNOWN", fileHeader.TurnNumber )

			local startEra = GameInfo.Eras[ fileHeader.StartEra ]
			Controls.StartEra:LocalizeAndSetText( "TXT_KEY_START_ERA", startEra and startEra.Description or "TXT_KEY_MISC_UNKNOWN" )

			Controls.GameType:SetText( g_GameTypeStrings[ fileHeader.GameType ] )

			Controls.TimeSaved:SetText( fileName and UI.GetSavedGameModificationTime( fileName ) )

			for k, info in pairs( g_IconInfos ) do
				info = info and info[ fileHeader[k] ] or MapUtilitiesGetBasicInfo( fileHeader.MapScript )
				local control = Controls[k]
				if info then
					IconHookup( info.PortraitIndex or info.IconIndex, 64, info.IconAtlas, control )
					control:LocalizeAndSetToolTip( info.Description )
				else
					IconHookup( g_IconIndex[k], 64, g_IconAtlas[k], control )
					control:LocalizeAndSetToolTip( "TXT_KEY_MISC_UNKNOWN" )
				end
			end

			local civ = GameInfo.Civilizations[ fileHeader.PlayerCivilization ]
			local civName = L"TXT_KEY_MISC_UNKNOWN"
			local leaderName = civName
			local leader

			if civ then
				civName = L( civ.Description )
				-- Set Selected Civ Map
				Controls.LargeMapImage:SetTexture( civ.MapImage )
				local row = GameInfo.Civilization_Leaders{ CivilizationType = civ.Type }()
				leader = row and GameInfo.Leaders[ row.LeaderheadType ]
			end

			if leader then
				leaderName = L( leader.Description )
				IconHookup( leader.PortraitIndex, 128, leader.IconAtlas, Controls.Portrait )
			else
				-- ? leader icon
				IconHookup( 22, 128, "LEADER_ATLAS", Controls.Portrait )
			end

			if (fileHeader.LeaderName or "") ~= "" then
				leaderName = fileHeader.LeaderName
			end

			if (fileHeader.CivilizationName or "") ~= "" then
				civName = fileHeader.CivilizationName
			end
			Controls.Title:LocalizeAndSetText( "TXT_KEY_RANDOM_LEADER_CIV", leaderName, civName )

			-- Obtain all of the required mods for the save
			local canLoadSaveResult
			if isCloudSave then
				canLoadSaveResult = Modding.CanLoadCloudSave( index )
				g_SavedGameDLCRequired, g_SavedGameModsRequired = Modding.GetCloudSaveRequirements( index )
			else
				canLoadSaveResult = Modding.CanLoadSavedGame( fileName )
				g_SavedGameDLCRequired, g_SavedGameModsRequired = Modding.GetSavedGameRequirements( fileName )
			end
			local control = Controls.ShowModsButton
			local t = g_SavedGameModsRequired
			local text = L"TXT_KEY_LOAD_MENU_REQUIRED_MODS"
			local pattern = "{1}[NEWLINE][ICON_BULLET] {2} (v.{3})"
--				local pattern2 = "%s[NEWLINE][ICON_BULLET] [COLOR_RED]%s (v. %i)[/COLOR]"
--				local isInstalled = Modding.IsModInstalled
			for _ = 0, 1 do
				if t and #t>0 then
					for _,v in ipairs(t) do
--[[
g_SavedGameDLCRequired:
DescriptionKey	TXT_KEY_293C1EE3117644F6AC1F59663826DE74_DESCRIPTION
Version	1
Title	Mongolia
g_SavedGameModsRequired:
ID	65793c73-65eb-47d1-822b-0d1ff3eeff3e
Version	8
Title	Acken's Minimalistic Balance
--]]
						text = L( pattern, text, v.DescriptionKey or v.Title or "???", v.Version or "?" )
						-- isInstalled(v.ID or "???", v.Version) and pattern or pattern2
					end
					control:SetToolTipString( text )
					control:SetHide( false )
				else
					control:SetHide( true )
				end
				control = Controls.ShowDLCButton
				t = g_SavedGameDLCRequired
				text = L"TXT_KEY_LOAD_MENU_REQUIRED_DLC"
				pattern = "{1}[NEWLINE][ICON_BULLET] {2}"
--					pattern2 = "%s[NEWLINE][ICON_BULLET] [COLOR_RED]%s[/COLOR]"
--					isInstalled = ContentManager.IsInstalled
			end

			local warning -- = "[COLOR_POSITIVE_TEXT]Save OK[ENDCOLOR]"
			if canLoadSaveResult > 0 or (not isCloudSave and fileHeader.GameType ~= g_Settings.GameTypePulldown) then
				warning = "[COLOR_RED]"..L(g_moddingErrorString[canLoadSaveResult] or "TXT_KEY_MODDING_ERROR_GENERIC")
			end
			return Controls.Warning:SetText( warning )
		else
			-- invalid save is selected
			isInvalid = true
		end
	else
		-- No saves are selected
		isInvalid = false
	end

	Controls.ShowDLCButton:SetHide(true)
	Controls.ShowModsButton:SetHide(true)

	if isCloudSave then
		Controls.Title:LocalizeAndSetText("TXT_KEY_STEAM_EMPTY_SAVE")
	elseif isInvalid then
		Controls.Title:LocalizeAndSetText("TXT_KEY_INVALID_SAVE_GAME")
	else
		Controls.Title:LocalizeAndSetText("TXT_KEY_SELECT_SAVE_GAME")
	end
	-- Empty all text fields
	Controls.NoGames:SetHide( isInvalid )
	Controls.SaveFileName:SetText()
	Controls.EraTurn:SetText()
	Controls.StartEra:SetText()
	Controls.GameType:SetText()
	Controls.TimeSaved:SetText()
	-- Default all icons
	IconHookup( 22, 128, "LEADER_ATLAS", Controls.Portrait )
	for k in pairs( g_IconInfos ) do
		IconHookup( g_IconIndex[k], 64, g_IconAtlas[k], Controls[k] )
		Controls[k]:LocalizeAndSetToolTip( "TXT_KEY_MISC_UNKNOWN" )
	end
	Controls.LargeMapImage:SetTexture( "MapRandom512.dds" )
end

----------------------------------------------------------------
local function SetupFileButtonList()
	g_InstanceManager:ResetInstances()
	for name, setting in pairs( g_Settings ) do
		Controls[name]:GetButton():SetText( g_PulldownStrings[ name ][ setting ] )
	end
	local gameType = g_Settings.GameTypePulldown
	local isCloudSave = gameType == 99
	g_StorageLocation = isCloudSave and 1 or 0
	g_IsAutoSave = Controls.AutoCheck:IsChecked()
	Controls.AutoCheck:SetHide( isCloudSave )
	Controls.SortByPullDown:SetHide( isCloudSave )
	Controls.BGBlock:SetHide( UI.GetCurrentGameState() ~= CIV5_GS_MAINGAMEVIEW )

	SetSelected()

	-- build a table of all save file names that we found
	local instance, new, instanceCount, fileHeader, saveName, civName, leaderName, civ
	local stack = Controls.LoadFileButtonStack

	if isCloudSave then
		g_CloudSaves = Steam.GetCloudSaves()
		instanceCount = Steam.GetMaxCloudSaves()
	else
		g_FileList = {}
		UI.SaveFileList( g_FileList, gameType, g_IsAutoSave, true )
		insert( g_FileList, 1, g_FileList[0] )
		instanceCount = #g_FileList
		sort( g_FileList, g_SortFunctions[g_Settings.SortByPullDown] )
	end

	for index = 1, instanceCount do
		instance, new = g_InstanceManager:GetInstance()
		if new then
			instance.Button:RegisterCallback( Mouse.eMouseEnter, SetSelected )
			instance.Button:RegisterCallback( Mouse.eLClick, StartSelected )
			instance.Delete:RegisterCallback( Mouse.eLClick, OnDelete )
		end
		if isCloudSave then
			fileHeader = g_CloudSaves[index]
			if fileHeader then
				civName = L"TXT_KEY_MISC_UNKNOWN"
				leaderName = civName
				civ = GameInfo.Civilizations[ fileHeader.PlayerCivilization ]
				if civ then
					civName = L(civ.Description)
					local row = GameInfo.Civilization_Leaders{ CivilizationType = civ.Type }()
					row = row and GameInfo.Leaders[ row.LeaderheadType ]
					leaderName = row and row.Description
				end
				if (fileHeader.CivilizationName or "") ~= "" then
					civName = fileHeader.CivilizationName
				end
				if (fileHeader.LeaderName or "") ~= "" then
					leaderName = fileHeader.LeaderName
				end
				saveName = L( "TXT_KEY_RANDOM_LEADER_CIV", leaderName, civName )
			else
				saveName = L"TXT_KEY_STEAM_EMPTY_SAVE"
			end
			saveName = L( "TXT_KEY_STEAMCLOUD_SAVE", index, saveName )
		else
			saveName = GetFileNameWithoutExtension( g_FileList[index] )
		end
		instance.ButtonText:SetText( saveName )
		instance.Button:SetVoid1( index )
		instance.Delete:SetHide( isCloudSave )
	end

	Controls.NoGames:SetHide( instanceCount > 0 )

	stack:CalculateSize()
	Controls.ScrollPanel:CalculateInternalSize()
	stack:ReprocessAnchoring()
end

----------------------------------------------------------------
-- Initialization
do
	-- Setup events
	local KeyDown = KeyEvents.KeyDown
	local VK_ESCAPE = Keys.VK_ESCAPE
	ContextPtr:SetInputHandler( function( uiMsg, wParam )
		if uiMsg == KeyDown then
			if wParam == VK_ESCAPE then
				if Controls.DeleteConfirm:IsHidden() then
					OnBack()
				else
					OnNoDelete()
				end
			end
			return true
		end
	end)
	ContextPtr:SetShowHideHandler( function( isHide )
		if isHide then
			Controls.LargeMapImage:UnloadTexture()
		else
			Controls.MultiplayerChoice:SetHide( true )
			g_Settings.GameTypePulldown = PreGame.GetGameType()
			SetupFileButtonList()
		end
	end)

	-- Setup controls
	Controls.AutoCheck:RegisterCheckHandler( SetupFileButtonList )
	Controls.BackButton:RegisterCallback( Mouse.eLClick, OnBack )
	Controls.No:RegisterCallback( Mouse.eLClick, OnNoDelete )
	Controls.Yes:RegisterCallback( Mouse.eLClick, function()
		Controls.DeleteConfirm:SetHide(true)
		UI.DeleteSavedGame( g_FileList[ g_SelectedID ] )
		SetupFileButtonList()
	end)

	local function MP( multiplayerLobbyMode )
		UI.SetMultiplayerLobbyMode( multiplayerLobbyMode )
		PreGame.SetInternetGame( multiplayerLobbyMode % 2 == 0 ) --LOBBYMODE_STANDARD_INTERNET = 0, LOBBYMODE_STANDARD_LAN = 1, LOBBYMODE_PITBOSS_INTERNET = 2, LOBBYMODE_PITBOSS_LAN = 3
		return StartSelected()
	end

	Controls.InternetMP:RegisterCallback( Mouse.eLClick, function() MP( MultiplayerLobbyMode.LOBBYMODE_STANDARD_INTERNET ) end )
	Controls.LanMultiplayer:RegisterCallback( Mouse.eLClick, function() MP( MultiplayerLobbyMode.LOBBYMODE_STANDARD_LAN ) end )
	Controls.InternetPitboss:RegisterCallback( Mouse.eLClick, function() MP( MultiplayerLobbyMode.LOBBYMODE_PITBOSS_INTERNET ) end )
	Controls.LanPitboss:RegisterCallback( Mouse.eLClick, function() MP( MultiplayerLobbyMode.LOBBYMODE_PITBOSS_LAN ) end )
	if not Network.IsConnectedToSteam() then
		Controls.InternetMP:SetDisabled( true )
		Controls.InternetPitboss:SetDisabled( true )
		Controls.InternetMP:LocalizeAndSetToolTip( "TXT_KEY_STEAM_CONNECTED_NO" )
		Controls.InternetPitboss:LocalizeAndSetToolTip( "TXT_KEY_STEAM_CONNECTED_NO" )
	end

	local instance
	for name, strings in pairs( g_PulldownStrings ) do
		local control = Controls[name]
		for k, v in pairs( strings ) do
			instance = {}
			control:BuildEntry( "InstanceOne", instance )
			instance.Button:SetText( v )
			instance.Button:SetVoid1( k )
			instance.Button:RegisterCallback( Mouse.eLClick, function( setting )
				g_Settings[ name ] = setting
				return SetupFileButtonList()
			end)
		end
		control:CalculateInternals()
	end
end
