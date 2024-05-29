-------------------------------------------------
-- Lobby Screen
-------------------------------------------------
include( "StackInstanceManager" )

local ContextPtr = ContextPtr
local Controls = Controls
local Events = Events
local GameInfo = GameInfo
local KeyDown = KeyEvents.KeyDown
local VK_ESCAPE = Keys.VK_ESCAPE
local Locale = Locale
local Matchmaking = Matchmaking
local Modding = Modding
local eLClick = Mouse.eLClick
local MultiplayerLobbyMode = MultiplayerLobbyMode
local Path = Path
local PreGame = PreGame
local SystemUpdateUIType = SystemUpdateUIType
local UI = UI
local UIManager = UIManager

print "Loading Lobby"

-------------------------------------------------
-- Globals
-------------------------------------------------

local g_ServerInstanceManager = StackInstanceManager( "ListingButtonInstance", "Button", Controls.ListingStack )
local g_InstanceList = {}



local g_ListTypes = {}
--[[
-- The list type system is currently disable but might be reused in the future.
local LIST_LOBBIES = 0;
local LIST_SERVERS = 1;
local LIST_INVITES = 2;
local SEARCH_INTERNET	= 0;	-- Internet Servers/Lobbies
local SEARCH_LAN		= 1;		-- LAN Servers/Lobbies
local SEARCH_FRIENDS	= 2;
local SEARCH_FAVORITES	= 3;
local SEARCH_HISTORY	= 4;
g_ListTypes[1] = { txtKey =	"TXT_KEY_LIST_LOBBIES_INTERNET"; ttKey = "TXT_KEY_LIST_LOBBIES_INTERNET_TT"; listType = LIST_LOBBIES; searchType = SEARCH_INTERNET; };
g_ListTypes[2] = { txtKey =	"TXT_KEY_LIST_SERVERS_INTERNET"; ttKey = "TXT_KEY_LIST_SERVERS_INTERNET_TT"; listType = LIST_SERVERS; searchType = SEARCH_INTERNET; };
g_ListTypes[3] = { txtKey =	"TXT_KEY_LIST_SERVERS_LAN"; ttKey = "TXT_KEY_LIST_SERVERS_LAN_TT"; listType = LIST_SERVERS; searchType = SEARCH_LAN; };
g_ListTypes[4] = { txtKey =	"TXT_KEY_LIST_SERVERS_FRIENDS"; ttKey = "TXT_KEY_LIST_SERVERS_FRIENDS_TT"; listType = LIST_SERVERS; searchType = SEARCH_FRIENDS; };
g_ListTypes[5] = { txtKey =	"TXT_KEY_LIST_SERVERS_FAVORITES"; ttKey = "TXT_KEY_LIST_SERVERS_FAVORITES_TT"; listType = LIST_SERVERS; searchType = SEARCH_FAVORITES; };
g_ListTypes[6] = { txtKey =	"TXT_KEY_LIST_SERVERS_HISTORY"; ttKey = "TXT_KEY_LIST_SERVERS_HISTORY_TT"; listType = LIST_SERVERS; searchType = SEARCH_HISTORY; };
--]]

local g_SelectedServerID
local g_ServerList = {}
local g_AllPackageIDs = {}
local g_ActivePackageCount = 0
local g_HideDLC = "8871E748-29A4-4910-8C57-8C99E32D0167"
local g_SortKey
local g_SortDirection

local g_SortOptions = { 
	{ Button = Controls.SortbyServer, Column = "ServerName" },
	{ Button = Controls.SortbyMapName, Column = "MapTypeCaption" },
	{ Button = Controls.SortbyMapSize, Column = "MapSizeCaption" },
	{ Button = Controls.SortbyMembers, Column = "MembersSort" },
	{ Button = Controls.SortbyDLCHosted, Column = "DLCSort" },
}

-------------------------------------------------
-- Helper Functions
-------------------------------------------------
local function ExitLobby()
    UIManager:DequeuePopup( ContextPtr )
end

local SortFunction = function( a, b )
	if g_SortDirection then
		return a[ g_SortKey ] > b[ g_SortKey ]
	else
		return b[ g_SortKey ] > a[ g_SortKey ]
	end
end

local function IsUsingInternetGameList()
	local lobbyMode = UI.GetMultiplayerLobbyMode()
	return lobbyMode == MultiplayerLobbyMode.LOBBYMODE_STANDARD_INTERNET or lobbyMode == MultiplayerLobbyMode.LOBBYMODE_PITBOSS_INTERNET
end

local function IsUsingPitbossGameList()
	local lobbyMode = UI.GetMultiplayerLobbyMode()
	return lobbyMode == MultiplayerLobbyMode.LOBBYMODE_PITBOSS_INTERNET or lobbyMode == MultiplayerLobbyMode.LOBBYMODE_PITBOSS_LAN
end

-------------------------------------------------
-- Server Listing Functions
-------------------------------------------------
local function UpdateRefreshButton()

--[[
	-- List type has been disabled but it might be used in the future.
	if (PreGame.IsInternetGame()) then
		local listType, searchType = Matchmaking.GetMultiplayerGameListType();

		for i, entry in ipairs(g_ListTypes) do
			if (entry.listType == listType and entry.searchType == searchType) then
				Controls.ListTypeLabel:LocalizeAndSetText(entry.txtKey);
			end
		end
	end
--]]

	if Matchmaking.IsRefreshingGameList() then
		Controls.RefreshButton:LocalizeAndSetText( "TXT_KEY_MULTIPLAYER_STOP_REFRESH_GAME_LIST" )
		Controls.RefreshButton:LocalizeAndSetToolTip( "TXT_KEY_MULTIPLAYER_STOP_REFRESH_GAME_LIST_TT" )
	else
		Controls.RefreshButton:LocalizeAndSetText( "TXT_KEY_MULTIPLAYER_REFRESH_GAME_LIST" )
		Controls.RefreshButton:LocalizeAndSetToolTip( "TXT_KEY_MULTIPLAYER_REFRESH_GAME_LIST_TT" )
	end
end

local function SelectServer( serverID )
	-- Reset the selection state of all the listings.
	for i, v in pairs( g_InstanceList ) do -- Iterating over the entire list solves some issues with stale information.
		v.JoinButton:SetHide( i~=serverID )
		v.SelectHighlight:SetHide( i~=serverID )
	end
    g_SelectedServerID = serverID
end

local function JoinServer( serverID )
	if serverID and serverID >= 0 then
		print( "JoinMultiplayerGame", serverID, Matchmaking.JoinMultiplayerGame( serverID ) )
	end
end

local function SortAndDisplayListings()

	if g_SortKey then
		table.sort( g_ServerList, SortFunction )
	end

	g_ServerInstanceManager:ResetInstances()
	g_InstanceList = {}

	for _, listing in ipairs( g_ServerList ) do
		local instance = g_ServerInstanceManager:GetInstance()
		local serverID = listing.ServerID
		g_InstanceList[ serverID ] = instance

		instance.ServerNameLabel:SetText( listing.ServerName )
		instance.MembersLabel:SetText( listing.MembersLabelCaption )
		instance.MembersLabel:SetToolTipString( listing.MembersLabelToolTip )

		instance.ServerMapTypeLabel:SetText( listing.MapTypeCaption )
		instance.ServerMapTypeLabel:SetToolTipString( listing.MapTypeToolTip )

		instance.ServerMapSizeLabel:SetText( listing.MapSizeCaption )
		instance.ServerMapSizeLabel:SetToolTipString( listing.MapSizeToolTip )

		instance.DLCHostedLabel:SetText( listing.DLCHostedCaption )
		instance.DLCHostedLabel:SetToolTipString( listing.DLCHostedToolTip )

		-- Enable the Button's Event Handler
		instance.Button:SetVoid1( serverID ); -- List ID
		instance.Button:RegisterCallback( eLClick, SelectServer )

		instance.JoinButton:SetVoid1( serverID ); -- Server ID
		instance.JoinButton:RegisterCallback( eLClick, JoinServer )

		local b = serverID ~= g_SelectedServerID
		instance.JoinButton:SetHide( b )
		instance.SelectHighlight:SetHide( b )
	end

	Controls.ListingStack:CalculateSize();
	Controls.ListingStack:ReprocessAnchoring();
	Controls.ListingScrollPanel:CalculateInternalSize();
	return UpdateRefreshButton()
end

local function AddOrUpdateServers( serverEntries )
--[[
Players
hostedMods
serverID	0
MapName	Assets\Maps\Earth_Huge.Civ5Map
WorldSize	TXT_KEY_WORLD_HUGE
requiredDLCAvailable	1
requiredDLC
hostedDLC	{293C1EE3-1176-44F6-AC1F-59663826DE74}{B685D5DE-7CCA-4E75-81B4-2F60754E6330}{ECF7C605-BA11-4CAC-8D80-D71306AAC471}{B3030D39-C0D8-4BC7-91B1-7AD1CAF585AB}{112C22B2-5308-42B6-B734-171CCAB3037B}{BBB0D085-A0B1-4475-B007-3E549CF3ADC3}{EA67AED5-5859-4875-BF3A-360FE9E55D1B}{7459BA32-5764-44AE-8E95-01AD0E0EFD48}{3F49DF54-68B6-44D1-A930-A168628FAA59}{46EAEFFC-7B1D-443D-BFC8-F825DFEFB094}{4255F5F7-D3AB-4E55-ACEE-4670082040ED}{0E3751A1-F840-4E1B-9706-519BF484E59D}{6DA07636-4123-4018-B643-6575B4EC336B}{8871E748-29A4-4910-8C57-8C99E32D0167}
serverName	ezera
WorldSizeTranslated	Huge
numPlayers	1
maxPlayers	12
--]]
	for _, serverEntry in pairs( serverEntries or {} ) do
		local serverID = serverEntry.serverID
-- print( "Adding server", serverID )

		-- Map Name
		local serverMapFile = serverEntry.MapName
		local mapName, serverMapFileName, mapToolTip
		if serverMapFile and #serverMapFile > 0 then
			serverMapFileName = Path.GetFileNameWithoutExtension( serverMapFile )
			-- Check local map scripts
			for row in GameInfo.MapScripts() do
				local mapFileName = Path.GetFileNameWithoutExtension( row.FileName )
				if mapFileName == serverMapFileName then
					mapName = Locale.ConvertTextKey( row.Name or "TXT_KEY_MISC_UNKNOWN" )
					mapToolTip = Locale.ConvertTextKey( row.Description or "TXT_KEY_MISC_UNKNOWN" )
					break
				end
			end
			-- Check WB maps
			if not mapName then
				local mapData = UI.GetMapPreview( serverMapFile )
				if mapData then
					mapName = not Locale.IsNilOrWhitespace( mapData.Name ) and Locale.Lookup( mapData.Name ) or serverMapFileName
					mapToolTip = Locale.Lookup( mapData.Description or "TXT_KEY_MISC_UNKNOWN" )
				end
			end
		else
			serverMapFile = nil
		end
		-- World Size
		local serverWorldSize = serverEntry.WorldSize
		-- Required DLCs
		local dlcString = serverEntry.hostedDLC:upper()
		local DLCs = { Locale.Lookup"TXT_KEY_LOBBY_REQUIRED_DLC" }
		local BNW = ""
		local GK = ""
		local match = true
		for i = 1, #dlcString, 38 do
			local DLC_ID = dlcString:sub( i+1, i + 36 )
			-- Filter out any packages in DlcToIgnore
			if not g_HideDLC:find( DLC_ID, 1, true ) then
				local b = g_AllPackageIDs[ DLC_ID ]
				local color = b and "[ENDCOLOR]" or b==false and "[COLOR_YELLOW]" or "[COLOR_RED]"
				match = match and b or b==nil and nil
--print( "DLC_ID", DLC_ID, b, match )
				table.insert( DLCs, color..Locale.Lookup( Modding.GetDlcNameDescriptionKeys( dlcString:sub( i, i + 37 ) ) ) )
				if DLC_ID == "6DA07636-4123-4018-B643-6575B4EC336B" then BNW = color.." BNW" end
				if DLC_ID == "0E3751A1-F840-4E1B-9706-519BF484E59D" then GK = color.." GK" end
			end
		end
		local n = #DLCs-1
		if n ~= g_ActivePackageCount then
			match = false
		end

		local listing = {
			ServerID = serverID,
			ServerName = serverEntry.serverName,
			MembersLabelCaption = serverEntry.numPlayers .. "/" .. serverEntry.maxPlayers,
			-- replace comma separation with new lines and remove the unique network id that is post-script to each player's name. Example : "razorace@5868795"
			MembersLabelToolTip = serverEntry.Players:gsub( "@.-, ", "[NEWLINE]" ),
			MembersSort = tonumber( serverEntry.numPlayers ) or 0,
			MapTypeCaption = mapName or serverMapFileName or Locale.Lookup"TXT_KEY_MISC_UNKNOWN",
			MapTypeToolTip = mapToolTip or serverMapFile or Locale.Lookup"TXT_KEY_MISC_UNKNOWN",
			MapSizeCaption = serverWorldSize and Locale.HasTextKey( serverWorldSize ) and Locale.Lookup( serverWorldSize ) or serverEntry.WorldSizeTranslated or Locale.Lookup( "TXT_KEY_MISC_UNKNOWN" ),
			DLCSort = match and 2 or match==false and 1 or 0,
		}

		local color = match and "[ENDCOLOR]" or match==false and "[COLOR_YELLOW]" or "[COLOR_RED]"
		if n > 0 then
			listing.DLCHostedCaption = color .. n .. Locale.Lookup"TXT_KEY_MULTIPLAYER_DLCHOSTED" .. GK .. BNW
			listing.DLCHostedToolTip = table.concat( DLCs, "[NEWLINE][ICON_BULLET]" )
		else
			listing.DLCHostedCaption = color..Locale.Lookup"TXT_KEY_MULTIPLAYER_LOBBY_NO"
		end
		-- Check if server is already in the listings.
		for i, v in pairs( g_ServerList ) do
			if serverID == v.ServerID then
				-- Overwrite previous entry
				g_ServerList[ i ] = listing
				return SortAndDisplayListings()
			end
		end
		-- Make new entry
		table.insert( g_ServerList, listing )
		return SortAndDisplayListings()
	end
end

local function ClearGameList()
--print "ClearGameList"
	g_ServerList = {}
	g_SelectedServerID = nil
	return SortAndDisplayListings()
end

local function UpdateGameList()
--print "UpdateGameList"
	g_ServerList = {}
	g_SelectedServerID = nil
	return AddOrUpdateServers( Matchmaking.GetMultiplayerGameList() )
end

local function RefreshButtonClick()
	if Matchmaking.IsRefreshingGameList() then
		Matchmaking.StopRefreshingGameList()
	elseif IsUsingInternetGameList() then
		Matchmaking.RefreshInternetGameList() -- Async
	else
		Matchmaking.RefreshLANGameList() -- Async
	end
	return UpdateRefreshButton()
end

--[[
-- The list type system is currently disable but might be reused in the future.
-------------------------------------------------
-------------------------------------------------
function PopulateListTypePulldown()
	local b = PreGame.IsInternetGame()
	Controls.ListTypePulldown:SetHide( not b )
	Controls.ListTypeLabel:SetHide( not b )
	if b then
		Controls.ListTypePulldown:ClearEntries()
		for i, entry in ipairs(g_ListTypes) do
			local instance = {};
			Controls.ListTypePulldown:BuildEntry( "InstanceOne", instance );
			instance.Button:LocalizeAndSetText(entry.txtKey);
			instance.Button:LocalizeAndSetToolTip(entry.ttKey);
			instance.Button:SetVoid1( i );
		end
		Controls.ListTypePulldown:CalculateInternals();
	end
	Controls.BottomStack:CalculateSize()
	Controls.BottomStack:ReprocessAnchoring()
end

Controls.ListTypePulldown:RegisterSelectionCallback( function( id )
	Matchmaking.SetMultiplayerGameListType( g_ListTypes[id].listType, g_ListTypes[id].searchType );
	if PreGame.IsInternetGame() then
		if Matchmaking.GetMultiplayerGameCount() == 0 then
			-- If no games are listed, then refresh, else just show them the current list and they can refresh on their own.
			Matchmaking.RefreshInternetGameList(); -- Async
		end
	else
		Matchmaking.RefreshLANGameList(); -- Async
	end
	return UpdateGameList();
end)
--]]

local ServerListUpdateHandlers = {
	function( ... )
		print( "GAMELISTUPDATE_CLEAR", ... )
		return ClearGameList()
	end,
	function( ... )
		print( "GAMELISTUPDATE_COMPLETE", ... )
		return UpdateRefreshButton()
	end,
	function( serverID )--, ... ) print( "GAMELISTUPDATE_ADD", serverID, ... )
		return AddOrUpdateServers( Matchmaking.GetMultiplayerServerEntry( serverID ) )
	end,
	function( serverID )--, ... ) print( "GAMELISTUPDATE_UPDATE", serverID, ... )
		return AddOrUpdateServers( Matchmaking.GetMultiplayerServerEntry( serverID ) )
	end,
	function( serverID, ... )
		print( "GAMELISTUPDATE_REMOVE", serverID, ... )
		for i, v in pairs( g_ServerList ) do
			if v.ServerID == serverID then
				table.remove( g_ServerList, i )
				break
			end
		end
		if g_SelectedServerID == serverID then
			g_SelectedServerID = nil
		end
		return SortAndDisplayListings()
	end,
	function( ... )
		return print( "GAMELISTUPDATE_ERROR", ... )
	end,
}

local EventHandlers = {
--	MultiplayerGameLaunched = ExitLobby,
	MultiplayerGameListClear = ClearGameList,
	MultiplayerGameListComplete = UpdateRefreshButton,
	MultiplayerGameListUpdated = function( eAction, ... )
--print( "MultiplayerGameListUpdated", eAction, ... )
		local handler = ServerListUpdateHandlers[ eAction ]
		if handler then
			handler( ... )
		end
	end,
}

-------------------------------------------------
-------------------------------------------------
function AdjustScreenSize()
    local _, screenY = UIManager:GetScreenSizeVal();

    local TOP_COMPENSATION = 52 + ((screenY - 768) * 0.3 );
    local BOTTOM_COMPENSATION = 192;
    local SIZE = screenY - (TOP_COMPENSATION + BOTTOM_COMPENSATION);

    Controls.ListingStack:SetSizeY( SIZE );
    Controls.ListingScrollPanel:SetSizeY( SIZE );
    Controls.ListingScrollPanel:CalculateInternalSize();
    Controls.MainGrid:SetSizeY( screenY - TOP_COMPENSATION );

end


-------------------------------------------------
-------------------------------------------------
Events.SystemUpdateUI.Add( function( type )
    if type == SystemUpdateUIType.ScreenResize then
        AdjustScreenSize();
    end
end)

AdjustScreenSize();

-------------------------------------------------
-- Show Hide Handler
-------------------------------------------------
ContextPtr:SetShowHideHandler( function( isHide, isInit )
print( isHide and "HandleHide" or "HandleShow", isInit and "isInit" )
	if isHide then
		Matchmaking.StopRefreshingGameList()
		for event, handler in pairs( EventHandlers ) do
			Events[ event ].Remove( handler )
		end
		g_ServerInstanceManager:ResetInstances()
		g_InstanceList = {}
		g_ServerList = {}
	else
		g_SortKey = nil
		g_AllPackageIDs = {}
		g_ActivePackageCount = 0
		for _, v in pairs( ContentManager.GetAllPackageIDs() ) do
			if not g_HideDLC:find( v, 1, true ) then
				local b = ContentManager.IsActive( v, ContentType.GAMEPLAY )
				g_AllPackageIDs[ v ] = b
				if b then g_ActivePackageCount = g_ActivePackageCount+1 end
			end
		end
		local isInternet = IsUsingInternetGameList()
		local isPitboss = IsUsingPitbossGameList()
		local isModding = #Modding.GetActivatedMods() > 0
		local l = isPitboss and 1 or 0 -- 1 = LIST_SERVERS or 0 = LIST_LOBBIES
		if isInternet then
			Matchmaking.InitInternetLobby()
			Matchmaking.SetMultiplayerGameListType( l, 0 ) -- 0 = SEARCH_INTERNET
		else
			Matchmaking.InitLanLobby()
			Matchmaking.SetMultiplayerGameListType( l, 1 ) -- 1 = SEARCH_LAN
		end

		-- list type selection is currently disabled but might be used in the future.
		-- PopulateListTypePulldown();

		if isPitboss then
			Controls.TitleLabel:LocalizeAndSetText( "TXT_KEY_MULTIPLAYER_PITBOSS_LOBBY" )
		elseif isModding then
			Controls.TitleLabel:LocalizeAndSetText( isInternet and "TXT_KEY_MOD_INTERNET_LOBBY" or "TXT_KEY_MOD_LAN_LOBBY" )
		else
			Controls.TitleLabel:LocalizeAndSetText( isInternet and "TXT_KEY_MULTIPLAYER_INTERNET_LOBBY" or "TXT_KEY_MULTIPLAYER_LAN_LOBBY" )
		end

		-- Setup Connect to IP
		Controls.ConnectIPBox:SetHide( not isPitboss )
		RefreshButtonClick() -- update refresh button and start a game list refresh.
		for event, handler in pairs( EventHandlers ) do
			Events[ event ].Add( handler )
		end
	end
end)

----------------------------------------------------------------
-- Input Handler
----------------------------------------------------------------
ContextPtr:SetInputHandler( function( uiMsg, wParam )--, lParam )
	if uiMsg == KeyDown then
		if wParam == VK_ESCAPE then
			ExitLobby()
		end
	end

	-- TODO: Is this needed?
	return true;
end)

-------------------------------------------------
-- Button Handlers
-------------------------------------------------
Controls.HostButton:RegisterCallback( eLClick, function()
	Events.SystemUpdateUI( SystemUpdateUIType.RestoreUI, "MultiplayerSetup" )
end)

Controls.LoadButton:RegisterCallback( eLClick, function()
	Events.SystemUpdateUI( SystemUpdateUIType.RestoreUI, "LoadGameMenu" )
end)
Controls.ConnectIPEdit:RegisterCallback( function()
	print( "JoinIPAddress", Matchmaking.JoinIPAddress( Controls.ConnectIPEdit:GetText() ) )
end)
Controls.BackButton:RegisterCallback( eLClick, ExitLobby );
Controls.RefreshButton:RegisterCallback( eLClick, RefreshButtonClick );

-- Registers the sort option controls click events
function SortOptionSelected( option )
	local sortOptions = g_SortOptions[ option ]
	if g_SortKey == sortOptions.Column then
		sortOptions.Direction = not sortOptions.Direction
	else
		g_SortKey = sortOptions.Column
	end
	g_SortDirection = sortOptions.Direction
	return SortAndDisplayListings()
end

for i,v in pairs(g_SortOptions) do
	local b = v.Button
	if b then
		b:RegisterCallback( eLClick, SortOptionSelected )
		b:SetVoid1( i )
	end
end

