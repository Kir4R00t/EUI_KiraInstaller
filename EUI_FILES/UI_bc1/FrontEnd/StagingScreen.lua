-------------------------------------------------
-- Staging Room Screen
-------------------------------------------------
include "IconHookup"
local IconHookup = IconHookup
local CivIconHookup = CivIconHookup

include "InstanceManager"
include "MPGameOptions"
local SetInLobby = SetInLobby
local ValidateCivSelections = ValidateCivSelections
local GetMaxPlayersForCurrentMap = GetMaxPlayersForCurrentMap
local PopulateMapSizePulldown = PopulateMapSizePulldown
local RefreshMapScripts = RefreshMapScripts
local UpdateGameOptionsDisplay = UpdateGameOptionsDisplay
local GetTurnModeStr = GetTurnModeStr
local GetTurnModeToolTipStr = GetTurnModeToolTipStr

include "TurnStatusBehavior" -- for turn status button behavior
local UpdateTurnStatus = UpdateTurnStatus


local ipairs = ipairs
local math = math
local pairs = pairs
local print = print
local string = string
local table = table

print "Loading Staging Room"

local Controls = Controls
local ContextPtr = ContextPtr
local Network = Network
local PreGame = PreGame
local Matchmaking = Matchmaking
local UIManager = UIManager
local Modding = Modding
local Events = Events

local Players = Players
local Game = Game
local UI = UI
local GetFileName = Path.GetFileName
local NetKicked = NetKicked
local SystemUpdateUIType = SystemUpdateUIType
local OptionsManager = OptionsManager

local GameInfo = GameInfo
local eLClick = Mouse.eLClick
local L = Locale.ConvertTextKey
local SlotClaim = SlotClaim
local SlotStatus = SlotStatus
local GameViewTypes = GameViewTypes
local GameStateTypes = GameStateTypes
local MAX_MAJOR_CIVS_M1 = GameDefines.MAX_MAJOR_CIVS - 1

-------------------------------------------------
-- Globals
-------------------------------------------------

local m_PlayerInstances = {}
local m_PlayerInstanceInit = MAX_MAJOR_CIVS_M1
local m_ChatInstances = {}
local m_PlayerNames = {}

local g_AdvancedOptionIM = InstanceManager:new( "GameOption", "Text", Controls.AdvancedOptions );
local g_AdvancedOptionsList = {};

local m_bLaunchReady = false;
local m_bEditOptions = false;

local g_fCountdownTimer = -1;  --Start game countdown timer.  Set to -1 when not in use.

local hoursStr = L( "TXT_KEY_HOURS" );
local secondsStr = L( "TXT_KEY_SECONDS" );

local g_SlotIsActive = { [ SlotStatus.SS_COMPUTER or -1] = true, [ SlotStatus.SS_TAKEN or -1] = true, [-1] = nil }
local g_SlotTypeStrings = {
	[ SlotStatus.SS_COMPUTER or -1] = "TXT_KEY_SLOTTYPE_AI",
	[ SlotStatus.SS_OBSERVER or -1] = "TXT_KEY_SLOTTYPE_OBSERVER",
	[ SlotStatus.SS_CLOSED or -1] = "TXT_KEY_SLOTTYPE_CLOSED",
	[ SlotStatus.SS_TAKEN or -1] = "TXT_KEY_PLAYER_TYPE_HUMAN",
	[-1] = nil
}

-------------------------------------------------
-- Utilities
-------------------------------------------------
local g_strHuman = PreGame.IsHotSeatGame() and "TXT_KEY_PLAYER_TYPE_HUMAN" or "TXT_KEY_SLOTTYPE_HUMANREQ"
local function GetSlotTypeString( playerID )
	return g_SlotTypeStrings[ PreGame.GetSlotStatus( playerID ) ] or PreGame.GetSlotClaim( playerID ) == SlotClaim.SLOTCLAIM_RESERVED and g_strHuman or "TXT_KEY_SLOTTYPE_OPEN"
end

local function IsInGameScreen()
	return PreGame.GameStarted() and Matchmaking.IsHost() and PreGame.GetSlotStatus( Matchmaking.GetLocalID() ) == SlotStatus.SS_OBSERVER
end

local function ShowHideInviteButton()
	Controls.InviteButton:SetHide( not PreGame.IsInternetGame() or Network.IsDedicatedServer() )
end

local function ShowHideSaveButton()
	local bShow = Matchmaking.IsHost();
	Controls.SaveButton:SetHide(not bShow);
	if g_fCountdownTimer ~= -1 then -- Disable the save game button while the countdown is active.
		Controls.SaveButton:SetDisabled( true );
		Controls.SaveButton:SetAlpha( 0.5 );
	else
		Controls.SaveButton:SetDisabled( false );
		Controls.SaveButton:SetAlpha( 1.0 );
	end

	-- Only show the game configuration tooltip if we'd be saving the game configuration vs. an actual game save.
	if PreGame.GameStarted() then
		Controls.SaveButton:SetToolTipString()
	else
		Controls.SaveButton:LocalizeAndSetToolTip( "TXT_KEY_SAVE_GAME_CONFIGURATION_TT" );
	end
end

local function CheckTeams()
	local teamTest, j
	-- Find the team of the first valid player.  We can't simply use the host's team because they could be an observer.
	for i = 0, MAX_MAJOR_CIVS_M1 do
		j = i
		if g_SlotIsActive[ PreGame.GetSlotStatus( i ) ] then
			teamTest = PreGame.GetTeam( i )
			break
		end
	end
	for i = j, MAX_MAJOR_CIVS_M1 do
		if g_SlotIsActive[ PreGame.GetSlotStatus( i ) ] and PreGame.GetTeam( i ) ~= teamTest then
			return true
		end
	end
end

local function CountPlayers()
	local totalPlayers = 0;
	for i = 0, MAX_MAJOR_CIVS_M1 do
		if g_SlotIsActive[ PreGame.GetSlotStatus( i ) ] and PreGame.GetSlotClaim( i ) == SlotClaim.SLOTCLAIM_ASSIGNED then
			totalPlayers = totalPlayers + 1
		end
	end
	return totalPlayers
end

local function ResetCivDetails( playerID )
	PreGame.SetLeaderName( playerID, "" )
	PreGame.SetCivilizationDescription( playerID, "" )
	PreGame.SetCivilizationShortDescription( playerID, "" )
	PreGame.SetCivilizationAdjective( playerID, "" )
end

local function LaunchGame()
	print( "LaunchMultiplayerGame", Matchmaking.LaunchMultiplayerGame() )
	UIManager:SetUICursor( 1 )
end

-------------------------------------------------
-- Stop Game Launch Countdown
-------------------------------------------------
local function StopCountdown()
	Controls.CountdownButton:SetHide(true);
	ContextPtr:ClearUpdate();
end

-------------------------------------------------
-- Context OnUpdate
-------------------------------------------------
local function OnUpdate( fDTime )
	-- OnUpdate only runs when the game start countdown is ticking down.
	g_fCountdownTimer = g_fCountdownTimer - fDTime
	if not Network.IsEveryoneConnected() then
		-- not all players are connected anymore.  This is probably due to a player join in progress.
		StopCountdown();
	elseif g_fCountdownTimer <= 0 then
			-- Timer elapsed, launch the game if we're the host.
			if Matchmaking.IsHost() then
				LaunchGame()
			end

			StopCountdown()
	else
		Controls.CountdownButton:SetHide( false )
		Controls.CountdownButton:LocalizeAndSetText( "TXT_KEY_GAMESTART_COUNTDOWN_FORMAT", math.floor(g_fCountdownTimer) )
	end
end

local function InviteSelected( playerID, playerChoiceID )
	local instance = m_PlayerInstances[ playerID ]
	if instance then
		if playerChoiceID == -1 then -- AI
			instance.InvitePulldown:GetButton():LocalizeAndSetText( "TXT_KEY_AI_NICKNAME" )
		else -- TODO: Send Invite and Lock Slot
			instance.InvitePulldown:GetButton():LocalizeAndSetText( "TXT_KEY_WAITING_FOR_INVITE_RESPONSE", "TEMP" )
--			instance.InvitePulldown:GetButton():SetText( "Waiting for Player..." );
		end
	end
end

local function OnKickPlayer( playerID )
	Controls.KickAcceptButton:SetVoid1( playerID )
	Controls.KickDialog:LocalizeAndSetText( "TXT_KEY_CONFIRM_KICK_PLAYER_DESC", "[COLOR_RED]"..m_PlayerNames[playerID].."[ENDCOLOR]" )
	Controls.KickPopup:SetHide( false )
end

local function OnEditPlayer( playerID )
	Controls.SetCivNames:DoDeferredLoad()
	UIManager:PushModal( Controls.SetCivNames )
	LuaEvents.SetCivNameEditSlot( playerID )
end

local function OnSwapPlayer( playerID )
	Network.SetPlayerDesiredSlot( playerID )
end

local function SelectCiv( playerID, civID )
	PreGame.SetCivilization( playerID, civID )
	Network.BroadcastPlayerInfo()
end

local function SelectLocalCiv( _, civID )
	return SelectCiv( Matchmaking.GetLocalID(), civID )
end

local function SelectTeam( playerID, teamID )
	PreGame.SetTeam( playerID, teamID )
	Network.BroadcastPlayerInfo()
end

local function SelectLocalTeam( _, teamID )
	return SelectTeam( Matchmaking.GetLocalID(), teamID )
end

local function SelectHandicap( playerID, handicapID )
	PreGame.SetHandicap( playerID, handicapID )
	Network.BroadcastPlayerInfo()
end

local function SelectLocalHandicap( _, handicapID )
	return SelectHandicap( Matchmaking.GetLocalID(), handicapID )
end

--[[
local function OnPlayerName( playerID, id )
	if (id == 0) then
		PreGame.SetSlotStatus( playerID, SlotStatus.SS_COMPUTER );
		PreGame.SetHandicap( playerID, 1 );
		PreGame.SetNickName( playerID, "" );
	else
		PreGame.SetSlotStatus( playerID, SlotStatus.SS_TAKEN );
		if (PreGame.GetNickName(playerID) == "") then
			PreGame.SetNickName( playerID, L( "TXT_KEY_MULTIPLAYER_DEFAULT_PLAYER_NAME", playerID + 1 ) );
		end
	end
	Network.BroadcastPlayerInfo();
end
]]

local function SetSlotToAI( playerID )
	PreGame.SetSlotStatus( playerID, SlotStatus.SS_COMPUTER )
	PreGame.SetHandicap( playerID, 1 )
	if PreGame.IsHotSeatGame() then
		-- Reset so the player can force a rebuild
		PreGame.SetNickName( playerID, "" )
		ResetCivDetails( playerID )
	end
end

local function SetSlotToHuman( playerID )
	-- Sets the given playerID slot to be human. Assumes that slot hasn't already been done so.
	PreGame.SetSlotStatus( playerID, SlotStatus.SS_TAKEN )
--	PreGame.SetHandicap( playerID, 3 )
	if PreGame.GetNickName( playerID ) == "" then
		PreGame.SetNickName( playerID, L( "TXT_KEY_MULTIPLAYER_DEFAULT_PLAYER_NAME", playerID + 1 ) )
	end
end

-- slot type pulldown options for the local player
local g_localSlotTypeOptions = { "TXT_KEY_SLOTTYPE_OPEN", "TXT_KEY_SLOTTYPE_OBSERVER" }
-- slot type pulldown options for non-local players
local g_slotTypeOptions = { "TXT_KEY_SLOTTYPE_OPEN", "TXT_KEY_SLOTTYPE_HUMANREQ", "TXT_KEY_SLOTTYPE_AI", "TXT_KEY_SLOTTYPE_OBSERVER", "TXT_KEY_SLOTTYPE_CLOSED" }

-- Associates an int value with our slotTypes so that we can index them in different pulldowns
local g_SlotVoids = { TXT_KEY_SLOTTYPE_OPEN = 1, TXT_KEY_SLOTTYPE_HUMANREQ = 2, TXT_KEY_PLAYER_TYPE_HUMAN = 3, TXT_KEY_SLOTTYPE_AI = 4, TXT_KEY_SLOTTYPE_OBSERVER = 5, TXT_KEY_SLOTTYPE_CLOSED = 6 }
local g_SlotToolTips = { L"TXT_KEY_SLOTTYPE_OPEN_TT", L"TXT_KEY_SLOTTYPE_HUMANREQ_TT", L"TXT_KEY_SLOTTYPE_HUMAN_TT", L"TXT_KEY_SLOTTYPE_AI_TT", L"TXT_KEY_SLOTTYPE_OBSERVER_TT", L"TXT_KEY_SLOTTYPE_CLOSED_TT" }
local g_SlotReady = {
	function( playerID ) -- TXT_KEY_SLOTTYPE_OPEN
		if not Network.IsPlayerConnected( playerID ) then
			-- Can't open a slot occupied by a human.
			PreGame.SetSlotStatus( playerID, SlotStatus.SS_OPEN )
			PreGame.SetSlotClaim( playerID, SlotClaim.SLOTCLAIM_ASSIGNED )
			return true
		end
	end,
	function( playerID ) -- TXT_KEY_SLOTTYPE_HUMANREQ
		PreGame.SetSlotClaim( playerID, SlotClaim.SLOTCLAIM_RESERVED );
		if not Network.IsPlayerConnected(playerID) then
			-- Don't open the slot if someone is already occupying it.
			PreGame.SetSlotStatus( playerID, SlotStatus.SS_OPEN )
			return true
		elseif(Network.IsPlayerConnected(playerID) and PreGame.GetSlotStatus( playerID ) == SlotStatus.SS_OBSERVER) then
			-- Setting human required on an human occupied observer slot switches them to normal player mode.
			SetSlotToHuman( playerID )
			return true
		end
	end,
	function( playerID ) -- TXT_KEY_PLAYER_TYPE_HUMAN
		if PreGame.GetSlotStatus( playerID ) ~= SlotStatus.SS_TAKEN then
			SetSlotToHuman( playerID )
			return true
		end
	end,
	function( playerID ) -- TXT_KEY_SLOTTYPE_AI
		if PreGame.GetMultiplayerAIEnabled() and not Network.IsPlayerConnected( playerID ) then
			-- only switch to AI if AI are enabled in multiplayer.
			SetSlotToAI( playerID )
			return true
		end
	end,
	function( playerID ) -- TXT_KEY_SLOTTYPE_OBSERVER
		PreGame.SetSlotStatus( playerID, SlotStatus.SS_OBSERVER );
		return true
	end,
	function( playerID ) -- TXT_KEY_SLOTTYPE_CLOSED
		if not Network.IsPlayerConnected( playerID ) then
			PreGame.SetSlotStatus( playerID, SlotStatus.SS_CLOSED );
			PreGame.SetSlotClaim( playerID, SlotClaim.SLOTCLAIM_ASSIGNED );
			return true
		end
	end,
}

local function OnSlotType( playerID, id )
	-- NOTE: Slot type pulldowns store the slot's playerID rather than the selection Index in their voids.
	--print("OnSlotType ID:", id, "Player ID:", playerID);
	-- In most cases, changing a slottype resets the player's ready status.
	local resetReadyStatus = g_SlotReady[id]
	if resetReadyStatus and resetReadyStatus( playerID ) then
		PreGame.SetReady( playerID, false )
	end
	Network.BroadcastPlayerInfo()
end

local function UpdateTurnStatusForPlayerID( playerID )
	local player = Players and Players[ playerID ]
	if player then
		local instance = playerID == Matchmaking.GetLocalID() and Controls or m_PlayerInstances[ playerID ]
		if instance then -- minor civs don't have slot instances.
			UpdateTurnStatus( player, instance.Icon, instance.ActiveTurnAnim, m_PlayerInstances )
		end
	end
end

local UpdateTurnStatusForAll = Players and function()
	UpdateTurnStatusForPlayerID( Matchmaking.GetLocalID() )
	for playerID, instance in pairs( m_PlayerInstances ) do
		UpdateTurnStatus( Players[ playerID ], instance.Icon, instance.ActiveTurnAnim, m_PlayerInstances )
	end
end or nil

local function UpdatePingTimeLabel( kLabel, playerID )
	local pingTime = Network.GetPingTime( playerID )
	if pingTime <= 0 then
		kLabel:LocalizeAndSetText( "TXT_KEY_STAGING_ROOM_UNDER_1_MS" )
	elseif pingTime < 1000 then
		kLabel:LocalizeAndSetText( "{1: number #}{TXT_KEY_STAGING_ROOM_TIME_MS}", pingTime )
	else
		kLabel:LocalizeAndSetText( "{1: number #.##}{TXT_KEY_STAGING_ROOM_TIME_S}", pingTime/1000 )
	end
end

-------------------------------------------------
-- Refresh Player List
-------------------------------------------------
local function RefreshPlayerList()
	local hostID  = Matchmaking.GetHostID()
	local localPlayerID = Matchmaking.GetLocalID()
	local isLocalPlayerHost = Matchmaking.IsHost()
	local isLocalPlayerReady = PreGame.IsReady( localPlayerID )
	local isHotSeat = PreGame.IsHotSeatGame()
	local isHostReady = PreGame.IsReady( hostID )
	local isGameLoad = PreGame.GetLoadFileName() ~= ""
	local isGameStarted = PreGame.GameStarted()
	m_bLaunchReady = true

	for _, instance in pairs( m_PlayerInstances ) do
		instance.Root:SetHide( true )
	end

	-- Display Each Player from the Current Player List
	local playerTable = Matchmaking.GetPlayerList()
	if playerTable then
		for _, playerInfo in pairs( playerTable ) do
			local playerID = playerInfo.playerID
			local slotStatus = PreGame.GetSlotStatus( playerID )
			local isObserver = slotStatus == SlotStatus.SS_OBSERVER
			local instance = m_PlayerInstances[ playerID ]
			local isReady, isDisabled, cannotChangeSlotType, cannotChangeCiv, cannotChangeTeam, isHuman, slotTypeOptions
			local isConnected = Network.IsPlayerConnected( playerID )
			local playerName = playerInfo.playerName or L( "TXT_KEY_MULTIPLAYER_DEFAULT_PLAYER_NAME", playerID + 1 )
			m_PlayerNames[ playerID ] = playerName

			if playerID == localPlayerID then
				instance = Controls
				slotTypeOptions = g_localSlotTypeOptions
				instance.LocalEditButton:SetVoid1( localPlayerID )
				instance.RemoveButton:SetHide( true )
				isHuman = true
				isDisabled = false
				isReady = isLocalPlayerReady
				cannotChangeCiv = isReady or isGameLoad or isObserver or isGameStarted
				cannotChangeTeam = cannotChangeCiv
				cannotChangeSlotType = isReady or isGameLoad or isHotSeat or Network.IsDedicatedServer() or isGameStarted

				-- Ready Status
				local canReady = PreGame.CanReadyLocalPlayer()
				instance.LocalReadyCheck:LocalizeAndSetToolTip( canReady and "TXT_KEY_MP_READY_CHECK" or "TXT_KEY_MP_READY_CHECK_UNAVAILABLE_DATA_HELP" )
				instance.LocalReadyCheck:SetHide( false )
				instance.LocalReadyCheck:SetDisabled( not canReady )
				instance.LocalReadyCheck:SetCheck( isReady )

				instance.LocalEditButton:SetHide( not isHotSeat )

				instance.PlayerNameLabel:SetText( playerName )
				instance.HostIcon:SetHide( localPlayerID ~= hostID )
				instance.PlayerID:SetText( localPlayerID+1 )
			else
				instance.Root:SetHide( false )

				local isReserved = PreGame.GetSlotClaim( playerID ) == SlotClaim.SLOTCLAIM_RESERVED
				local isLocked = isReserved or PreGame.GetSlotClaim( playerID ) == SlotClaim.SLOTCLAIM_ASSIGNED
				local isOpen = slotStatus == SlotStatus.SS_OPEN
				local isClosed = slotStatus == SlotStatus.SS_CLOSED
				local isEmptyHumanRequiredSlot = isOpen and isReserved
				isHuman  = slotStatus == SlotStatus.SS_TAKEN
				isDisabled = isOpen and not isReserved or isClosed or isObserver
				slotTypeOptions = g_slotTypeOptions

				if isHuman then
					instance.PlayerNameLabel:SetText( playerName )
					instance.InvitePulldown:GetButton():SetText( playerName )

					-- You can only change the slot's civ/team if you're in hotseat mode.
					if isHotSeat then
						isReady = isHostReady; -- same ready status as host (local player)
						cannotChangeCiv = isReady
						cannotChangeTeam = isReady
					else
						isReady = PreGame.IsReady( playerID )
						cannotChangeCiv = true;
						cannotChangeTeam = not isLocalPlayerHost or isHostReady; -- The host can override human's team selection
					end

					cannotChangeSlotType = not isLocalPlayerHost or isHostReady; -- The host can override slot types
				else
					isReady = not isEmptyHumanRequiredSlot and -- Empty human required slots block game readiness.
											(isObserver and (PreGame.IsReady( playerID ) or (not isConnected and isHostReady)) or -- human observers manually ready up if occupied or ready up with the host if empty.
											(not isObserver and isHostReady) or -- non-observers share ready status with the host.
											(isGameLoad and isClosed)); -- prevent closed player slots from blocking game startup when loading save games -tsmith

					if isLocalPlayerHost then
						cannotChangeSlotType = isHostReady;

						-- Host can't change the team/civ of open/closed slots.
						cannotChangeCiv = isDisabled or isHostReady or isEmptyHumanRequiredSlot;
						cannotChangeTeam = isDisabled or isHostReady;
					else
						cannotChangeSlotType = true;
						cannotChangeCiv = true;
						cannotChangeTeam = true;
					end

					if isConnected then
								-- Use the player name if a player is network connected to the game (observers only)
						instance.PlayerNameLabel:SetText( playerName )
						instance.InvitePulldown:GetButton():SetText( playerName )
					else
						-- The default for non-humans is to display the slot type as the player name.
						local playerNameTextKey = GetSlotTypeString( playerID )
						instance.PlayerNameLabel:LocalizeAndSetText( playerNameTextKey )
						instance.InvitePulldown:GetButton():LocalizeAndSetText( playerNameTextKey )
					end
				end

				instance.EnableCheck:SetCheck( not isDisabled )
				instance.EnableCheck:LocalizeAndSetToolTip( isDisabled and "TXT_KEY_MP_ENABLE_SLOT" or "TXT_KEY_MP_DISABLE_SLOT" )
				instance.LockCheck:SetCheck( isLocked )
				instance.LockCheck:LocalizeAndSetToolTip( isLocked and "TXT_KEY_MP_UNLOCK_SLOT" or "TXT_KEY_MP_LOCK_SLOT" )
--				instance.InvitePulldown:SetHide( true )

				--instance.EnableCheck:SetHide( not isLocalPlayerHost or not isHotSeat and (isHuman or cannotChangeCiv) )
				--TEMP: S.S, hiding lock since it doesn't do anything and too many people believe it's the cause of MP probs.
				instance.LockCheck:SetHide( true or isHotSeat or not isLocalPlayerHost or isHuman or cannotChangeCiv )
				instance.KickButton:SetHide( isHotSeat or not isLocalPlayerHost or not isHuman ) --and not isConnected )
				instance.EditButton:SetHide( not isHotSeat or isDisabled )

				-- Handle swap button highlight: show if we want to switch to this slot or it wants to switch with us.
				instance.SwapButtonHighAlpha:SetHide( Network.GetPlayerDesiredSlot( localPlayerID ) ~= playerID and Network.GetPlayerDesiredSlot( playerID ) ~= localPlayerID )
				instance.SwapButton:SetHide( isHuman and isReady or isLocalPlayerReady or isClosed )
				instance.HostIcon:SetHide( playerID ~= hostID )

				-- Update player connection
				if isHuman or isObserver then
					instance.ConnectionStatus:SetHide(false);
					if Network.IsPlayerHotJoining( playerID ) then
						-- Player is hot joining.
						instance.ConnectionStatus:SetTextureOffsetVal( 0,32 )
						instance.ConnectionStatus:LocalizeAndSetToolTip( "TXT_KEY_MP_PLAYER_CONNECTING" )
					elseif isConnected then
						-- fully connected
						instance.ConnectionStatus:SetTextureOffsetVal( 0,0 )
						instance.ConnectionStatus:LocalizeAndSetToolTip( "TXT_KEY_MP_PLAYER_CONNECTED" )
					else
						-- Not connected
						instance.ConnectionStatus:SetTextureOffsetVal( 0,96 )
						instance.ConnectionStatus:LocalizeAndSetToolTip( "TXT_KEY_MP_PLAYER_NOTCONNECTED" )
					end
				else
					instance.ConnectionStatus:SetHide(true);
				end
				-- Update ping
				if isHuman and isConnected then
					UpdatePingTimeLabel( instance.PingTimeLabel, playerID )
					instance.PingTimeLabel:SetHide( false )
				else
					instance.PingTimeLabel:SetHide( true )
				end
			end

			-- Civ & Leader Info
			local activeCivSlot = g_SlotIsActive[ slotStatus ]
			local civ = activeCivSlot and GameInfo.Civilizations[ PreGame.GetCivilization( playerID ) ]
			local leader
			if civ then
				leader = GameInfo.Civilization_Leaders{ CivilizationType = civ.Type }()
				leader = leader and GameInfo.Leaders[ leader.LeaderheadType ]
				instance.CivLabel:LocalizeAndSetText( "TXT_KEY_RANDOM_LEADER_CIV", leader and leader.Description or "TXT_KEY_MISC_UNKNOWN", civ.ShortDescription or "TXT_KEY_MISC_UNKNOWN" )
				instance.CivLabel:SetToolTipString()

			elseif not activeCivSlot or PreGame.IsCivilizationKeyAvailable( playerID ) then
				-- Random Civ
				instance.CivLabel:LocalizeAndSetText( "TXT_KEY_RANDOM_LEADER" )
				instance.CivLabel:SetToolTipString()
			else
				-- A player has chosen a civilization we don't have access to
				instance.CivLabel:LocalizeAndSetText( "TXT_KEY_UNAVAILABLE_LEADER" )
				instance.CivLabel:LocalizeAndSetToolTip( "TXT_KEY_UNAVAILABLE_LEADER_HELP", PreGame.GetCivilizationPackageTextKey( playerID ) )
			end
			CivIconHookup( civ and playerID, 64, instance.CivIcon, instance.CivIconBG, instance.CivIconShadow )
			IconHookup( leader and leader.PortraitIndex or 22, 64, leader and leader.IconAtlas or "LEADER_ATLAS", instance.Portrait )

			-- You can't change slot types, civs, or teams after the game has started.
			local b = isGameLoad or isGameStarted
			-- Slot Type
			local slotTypeString = GetSlotTypeString( playerID )
			instance.SlotTypeLabel:LocalizeAndSetText( slotTypeString )
			instance.SlotTypeLabel:SetToolTipString( g_SlotToolTips[ g_SlotVoids[ slotTypeString ] ] )
			local pullDown = instance.SlotTypePulldown
			pullDown:ClearEntries();
			local controls = {}
			local createEntry
			for _, typeName in ipairs(slotTypeOptions) do
				createEntry = true
				if isHotSeat then
					if typeName == "TXT_KEY_SLOTTYPE_HUMANREQ" then
						-- "Human Required" slot type is the "Human" slot type in hotseat mode.
						typeName = "TXT_KEY_PLAYER_TYPE_HUMAN"
					elseif typeName == "TXT_KEY_SLOTTYPE_OBSERVER" or typeName == "TXT_KEY_SLOTTYPE_OPEN" then
						-- in hotseat mode, observer mode not allowed, and open mode is redundent
						createEntry = false
					end
				elseif isConnected then
					-- player is actively occupying this slot
					if typeName == "TXT_KEY_SLOTTYPE_OPEN" then
						-- transform open slottype position to human (for changing from an observer to normal human player)
						typeName = "TXT_KEY_PLAYER_TYPE_HUMAN"
					elseif typeName == "TXT_KEY_SLOTTYPE_CLOSED" or typeName == "TXT_KEY_SLOTTYPE_AI" then
						-- Don't allow those types on human occupied slots.
						createEntry = false
					end
				end
				if createEntry then
					local i = g_SlotVoids[ typeName ]
					if i then
						pullDown:BuildEntry( "InstanceOne", controls )
						controls.Button:LocalizeAndSetText( typeName )
						controls.Button:SetToolTipString( g_SlotToolTips[ typeName ] )
						controls.Button:SetVoids( playerID, i )
					end
				end
			end
			pullDown:CalculateInternals()
			pullDown:RegisterSelectionCallback( OnSlotType)
			pullDown:SetHide( b or cannotChangeSlotType )
			-- Handicap
			local info = GameInfo.HandicapInfos[ PreGame.GetHandicap( playerID ) ]
			instance.HandicapLabel:LocalizeAndSetText( info and info.Description or "TXT_KEY_MISC_UNKNOWN" )
			instance.HandicapPulldown:SetHide( b or cannotChangeCiv or not isHuman )
			instance.HandicapLabel:SetHide( not isHuman )
			if not isReady then
				-- You can't auto launch the game if someone isn't ready.
				m_bLaunchReady = false
			end
			-- Civ
			instance.CivPulldown:SetHide( b or cannotChangeCiv )
			instance.CivLabel:SetHide( isDisabled or isObserver )
			-- Team
			instance.TeamPulldown:SetHide( b or cannotChangeTeam )
			instance.TeamLabel:LocalizeAndSetText( "TXT_KEY_MULTIPLAYER_DEFAULT_TEAM_NAME", PreGame.GetTeam(playerID) + 1 )
			instance.TeamLabel:SetHide( isDisabled or isObserver )
			-- Status
			UpdateTurnStatusForPlayerID( playerID )
			instance.ReadyHighlight:SetHide( isDisabled or not isReady or not isHuman )
		end
	end

	Controls.BadTeams:SetHide( CheckTeams() or false )
	Controls.SlotStack:CalculateSize();
	Controls.SlotStack:ReprocessAnchoring();
	Controls.ListingScrollPanel:CalculateInternalSize();
end

-------------------------------------------------
-- Leave the Game
-------------------------------------------------
local function HandleExitRequest()

	StopCountdown() -- Make sure there is no countdown going.
	Matchmaking.LeaveMultiplayerGame()

--	if PreGame.GetLoadFileName() ~= "" then
	-- If there is a load file name, then we may have went in to the staging room with a loaded game
	-- This can set a lot of things we don't want on at this time.

	local isInternetGame = PreGame.IsInternetGame()
	local gameType = PreGame.GetGameType()
	PreGame.Reset()
	PreGame.SetInternetGame( isInternetGame )
	PreGame.SetGameType( gameType )
	PreGame.ResetSlots()
	UIManager:DequeuePopup( ContextPtr );
end

local function HandleExitReason( reason )
	Events.FrontEndPopup.CallImmediate( reason )
	return HandleExitRequest()
end

-------------------------------------------------
-- Button Callbacks
-------------------------------------------------

Controls.LaunchButton:RegisterCallback( eLClick, LaunchGame )
Controls.LocalEditButton:RegisterCallback( eLClick, OnEditPlayer )
Controls.ExitButton:RegisterCallback( eLClick, Events.UserRequestClose.Call )
Controls.InviteButton:RegisterCallback( eLClick, Steam.ActivateInviteOverlay )

Controls.SaveButton:RegisterCallback( eLClick, function()
	UIManager:QueuePopup( Controls.SaveMenu, PopupPriority.SaveMenu )
end)

do
	local GetGameViewRenderType = GetGameViewRenderType
	local SetGameViewRenderType = SetGameViewRenderType
	local ToggleStrategicView = ToggleStrategicView
	Controls.StrategicViewButton:RegisterCallback( eLClick, function()
		if PreGame.GetSlotStatus( Game.GetActivePlayer() ) == SlotStatus.SS_OBSERVER then
			-- Observer gets to toggle the world view completely off.
			local eViewType = GetGameViewRenderType()
			if eViewType == GameViewTypes.GAMEVIEW_NONE then
				SetGameViewRenderType(GameViewTypes.GAMEVIEW_STANDARD)
			else
				if eViewType == GameViewTypes.GAMEVIEW_STANDARD then
					SetGameViewRenderType(GameViewTypes.GAMEVIEW_STRATEGIC)
				else
					SetGameViewRenderType(GameViewTypes.GAMEVIEW_NONE)
				end
			end
		else
			ToggleStrategicView()
		end
	end)
end

Controls.RemoveButton:RegisterCallback( eLClick, function()
	Controls.RemoveButton:SetHide( true )
	local localPlayerID = Matchmaking.GetLocalID()
	ResetCivDetails( localPlayerID )
	local civ = PreGame.GetCivilization( localPlayerID )
	if civ ~= -1 then
		civ = GameInfo.Civilizations[ civ ]
		local leader = civ and GameInfo.Civilization_Leaders{ CivilizationType = civ.Type }()
		leader = leader and GameInfo.Leaders[ leader.LeaderheadType ]
		Controls.Title:LocalizeAndSetText( "TXT_KEY_RANDOM_LEADER_CIV", leader and leader.Description or "TXT_KEY_MISC_UNKNOWN", civ and civ.ShortDescription or "TXT_KEY_MISC_UNKNOWN" )
	else
		Controls.Title:LocalizeAndSetText( "TXT_KEY_RANDOM_LEADER_CIV", "TXT_KEY_RANDOM_LEADER", "TXT_KEY_RANDOM_CIV" )
	end
end)

Controls.PlayersPageTab:RegisterCallback( eLClick, function()
	if m_bEditOptions then
		m_bEditOptions = false
		UpdatePageTabView(true)
	end
end)

Controls.OptionsPageTab:RegisterCallback( eLClick, function()
	if not m_bEditOptions then
		m_bEditOptions = true
		UpdatePageTabView(true)
	end
end)

local function BackButtonClick()
	-- Can't exit while launching game
	if not Matchmaking.IsLaunchingGame() then
		if Controls.KickPopup:IsHidden() and Controls.HotJoinPopup:IsHidden() and Controls.SmtpPopup:IsHidden() then
			return HandleExitRequest()
		end
		Controls.SmtpPopup:SetHide( true )
		Controls.HotJoinPopup:SetHide( true )
		Controls.KickPopup:SetHide( true )
	end
end
Controls.BackButton:RegisterCallback( eLClick, BackButtonClick )
Controls.HotJoinCancelButton:RegisterCallback( eLClick, BackButtonClick )

Controls.LocalReadyCheck:RegisterCheckHandler( function( isChecked )
	PreGame.SetReady( Matchmaking.GetLocalID(), isChecked )
	Network.BroadcastPlayerInfo()
end)

Controls.ChatEntry:RegisterCallback( function( text )
	if string.len( text ) > 0 then
		Network.SendChat( text )
	end
	Controls.ChatEntry:ClearString()
end)

local function ValidateSmtpPassword()
	-- Do password editboxes match ?
	local b = Controls.TurnNotifySmtpPassEdit:GetText() and Controls.TurnNotifySmtpPassRetypeEdit:GetText() and Controls.TurnNotifySmtpPassEdit:GetText() == Controls.TurnNotifySmtpPassRetypeEdit:GetText()
	if b then
		OptionsManager.SetTurnNotifySmtpPassword_Cached( Controls.TurnNotifySmtpPassEdit:GetText() )
	end
	Controls.StmpPasswordMatchLabel:LocalizeAndSetText( b and "TXT_KEY_OPSCREEN_TURN_NOTIFY_SMTP_PASSWORDS_MATCH" or "TXT_KEY_OPSCREEN_TURN_NOTIFY_SMTP_PASSWORDS_NOT_MATCH" )
	Controls.StmpPasswordMatchLabel:LocalizeAndSetToolTip( b and "TXT_KEY_OPSCREEN_TURN_NOTIFY_SMTP_PASSWORDS_MATCH_TT" or "TXT_KEY_OPSCREEN_TURN_NOTIFY_SMTP_PASSWORDS_NOT_MATCH_TT" )
	Controls.StmpPasswordMatchLabel:SetColorByName( b and "Green_Chat" or "Magenta_Chat" )
	Controls.SmptAcceptButton:SetDisabled( not b )
	return b
end
Controls.SmptCancelButton:RegisterCallback( eLClick, BackButtonClick )
Controls.SmptAcceptButton:RegisterCallback( eLClick, function()
	if ValidateSmtpPassword() then
		OptionsManager.CommitGameOptions()
		Controls.SmtpPopup:SetHide( true )
	end
end)
Controls.SmtpPasswordEdit:RegisterCallback( ValidateSmtpPassword )
Controls.SmtpPasswordRetypeEdit:RegisterCallback( ValidateSmtpPassword )

Controls.KickCancelButton:RegisterCallback( eLClick, BackButtonClick )
Controls.KickAcceptButton:RegisterCallback( eLClick, function( playerID )
	print( "KickPlayer", playerID )
	Matchmaking.KickPlayer( playerID )
	Controls.KickPopup:SetHide( true )
end)

----------------------------------------------------------------
-- UPDATE CURRENT SETTINGS
----------------------------------------------------------------
local function UpdateDisplay()
	if not ContextPtr:IsHidden() then
		UpdateOptions();
		RefreshPlayerList();

		-- Allow the host to manually start the game when loading a game.
		if Matchmaking.IsHost() and PreGame.GetLoadFileName() ~= "" and not IsInGameScreen() then
			local isEveryoneConnected = Network.IsEveryoneConnected()
			Controls.LaunchButton:SetHide( false )
			Controls.LaunchButton:SetDisabled( not isEveryoneConnected )
			if isEveryoneConnected then
				Controls.LaunchButton:SetToolTipString()
			else
				Controls.LaunchButton:LocalizeAndSetToolTip( "TXT_KEY_LAUNCH_GAME_BLOCKED_PLAYER_JOINING" )
			end
		else
			Controls.LaunchButton:SetHide( true )
		end
	end
end


-------------------------------------------------
-- CHECK FOR GAME AUTO START
-------------------------------------------------
local function CheckGameAutoStart()
	-- Check to see if we should start/stop the multiplayer game.
	-- Check to make sure we don't have too many players for this map.
	if m_bLaunchReady and CheckTeams() and CountPlayers() <= GetMaxPlayersForCurrentMap() and not PreGame.GameStarted() and Network.IsEveryoneConnected() and not Matchmaking.IsLaunchingGame() then
		-- Everyone has readied up and we can start.
		if PreGame.IsHotSeatGame() then
			-- Hotseat skips the countdown.
			LaunchGame()
		else
			g_fCountdownTimer = 10
			ContextPtr:SetUpdate( OnUpdate )
		end
	else
		-- We can't autostart now, stop the countdown in case we started it earlier.
		StopCountdown();
	end
end

-------------------------------------------------
-------------------------------------------------
function UpdatePageTabView(bUpdateOnly)
	Controls.Host:SetHide( m_bEditOptions );
	Controls.ListingScrollPanel:SetHide( m_bEditOptions );
	Controls.OptionsScrollPanel:SetHide( not m_bEditOptions );
	Controls.OptionsPageTabHighlight:SetHide( not m_bEditOptions );
	Controls.PlayersPageTabHighlight:SetHide( m_bEditOptions );
	Controls.GameOptionsSummary:SetHide( m_bEditOptions );
	Controls.GameOptionsSummaryTitle:SetHide( m_bEditOptions );
	Controls.VerticalTrim:SetHide( m_bEditOptions );

	-- Update Page Title
	if IsInGameScreen() then
		Controls.TitleLabel:LocalizeAndSetText( "{TXT_KEY_MULTIPLAYER_DEDICATED_SERVER_ROOM:upper}" )
	elseif m_bEditOptions then
		-- Modding ?
		if ContextPtr:LookUpControl("../.."):GetID() == "ModMultiplayerSelectScreen" then
			Controls.TitleLabel:LocalizeAndSetText( "TXT_KEY_MOD_MP_GAME_SETUP_HEADER" )
		else
			Controls.TitleLabel:LocalizeAndSetText( "TXT_KEY_MULTIPLAYER_GAME_SETUP_HEADER" )
		end
	else
		Controls.TitleLabel:LocalizeAndSetText( "{TXT_KEY_MULTIPLAYER_STAGING_ROOM:upper}" )
	end

	if m_bEditOptions then
		Controls.OptionsScrollPanel:SetSizeY( Controls.VerticalTrim:GetSizeY() - 2);
		Controls.OptionsScrollPanel:CalculateInternalSize();

		-- Modding ?
		Controls.ModsButton:SetHide( ContextPtr:LookUpControl("../.."):GetID() ~= "ModMultiplayerSelectScreen" )

		PopulateMapSizePulldown();

		RefreshMapScripts();
		PreGame.SetRandomMapScript(false);	-- Random map scripts is not supported in multiplayer
		UpdateGameOptionsDisplay(bUpdateOnly);
	elseif PreGame.IsHotSeatGame() then
		-- In case they changed the DLC
		local prevCursor = UIManager:SetUICursor( 1 )
		print( "ActivateAllowedDLC", Modding.ActivateAllowedDLC() )
		UIManager:SetUICursor( prevCursor )
		Events.SystemUpdateUI( SystemUpdateUIType.RestoreUI, "StagingRoom" )
	end
end

-------------------------------------------------
-------------------------------------------------
function UpdateOptions()

	Controls.NameLabel:SetText( Matchmaking.GetCurrentGameName() )

	-- Game State Indicator
	local isGameStarted = PreGame.GameStarted()
	Controls.HotJoinBox:SetHide( not isGameStarted )
	Controls.LoadingBox:SetHide( isGameStarted or PreGame.GetLoadFileName() == "" )

	-- Set Max Turns if set
	local maxTurns = PreGame.GetMaxTurns();
	Controls.MaxTurns:SetHide( maxTurns == 0 )
	Controls.MaxTurns:LocalizeAndSetText( "TXT_KEY_MAX_TURNS", maxTurns )

	-- Show turn timer value if set.
	if PreGame.GetGameOption("GAMEOPTION_END_TURN_TIMER_ENABLED") == 1 then
		Controls.TurnTimer:SetHide(false);
		local turnTimerStr = L("TXT_KEY_MP_OPTION_TURN_TIMER");
		local pitBossTurnTime = PreGame.GetPitbossTurnTime();
		if(pitBossTurnTime > 0) then
			turnTimerStr = turnTimerStr .. ": " .. pitBossTurnTime;
			if(PreGame.GetGameOption("GAMEOPTION_PITBOSS") == 1) then
				turnTimerStr = turnTimerStr .. " " .. hoursStr;
			else
				turnTimerStr = turnTimerStr .. " " .. secondsStr;
			end
		end
		Controls.TurnTimer:SetText(turnTimerStr);
	else
		Controls.TurnTimer:SetHide(true);
	end

	-- Set Start Era
	local eraInfo = GameInfo.Eras[ PreGame.GetEra() ]
--	Controls.StartEraLabel:LocalizeAndSetText( "TXT_KEY_START_ERA", eraInfo.Description )
	Controls.StartEraLabel:LocalizeAndSetText( eraInfo and eraInfo.Description or "TXT_KEY_MISC_UNKNOWN" )

	-- Set Turn Mode
	local turnModeStr = GetTurnModeStr();
	Controls.TurnModeLabel:LocalizeAndSetText( turnModeStr );
	Controls.TurnModeLabel:LocalizeAndSetToolTip( GetTurnModeToolTipStr(turnModeStr) );

	-- Set Game Map Type
	if PreGame.IsRandomMapScript() then
		Controls.MapTypeLabel:LocalizeAndSetText( "TXT_KEY_RANDOM_MAP_SCRIPT" );
		Controls.MapTypeLabel:LocalizeAndSetToolTip( "TXT_KEY_RANDOM_MAP_SCRIPT_HELP" );
	else
		local mapScriptFileName = Locale.ToLower(PreGame.GetMapScript())
		local mapScript

		for row in GameInfo.MapScripts{FileName = mapScriptFileName} do
			mapScript = row;
			break;
		end
		mapScript = mapScript or UI.GetMapPreview(mapScriptFileName)
		if mapScript then
			Controls.MapTypeLabel:LocalizeAndSetText( mapScript.Name );
			Controls.MapTypeLabel:LocalizeAndSetToolTip( mapScript.Description );
		else
			Controls.MapTypeLabel:LocalizeAndSetText( "[COLOR_RED]{1}[ENDCOLOR]", GetFileName( PreGame.GetMapScript() ) or "TXT_KEY_MISC_UNKNOWN" )
			Controls.MapTypeLabel:LocalizeAndSetToolTip( "TXT_KEY_FILE_INFO_NOT_FOUND" );
		end
	end

	-- Set Map Size
	if PreGame.IsRandomWorldSize() then
		Controls.MapSizeLabel:LocalizeAndSetText( "TXT_KEY_RANDOM_MAP_SIZE" );
		Controls.MapSizeLabel:LocalizeAndSetToolTip( "TXT_KEY_RANDOM_MAP_SIZE_HELP" );
	else
		local info = GameInfo.Worlds[ PreGame.GetWorldSize() ];
		Controls.MapSizeLabel:LocalizeAndSetText( info and info.Description or "TXT_KEY_MISC_UNKNOWN" );
		Controls.MapSizeLabel:LocalizeAndSetToolTip( info and info.Help or "TXT_KEY_MISC_UNKNOWN" );
	end

	-- Set Game Pace Slot
	local info = GameInfo.GameSpeeds[ PreGame.GetGameSpeed() ];
	Controls.GameSpeedLabel:LocalizeAndSetText( info and info.Description or "TXT_KEY_MISC_UNKNOWN" );
	Controls.GameSpeedLabel:LocalizeAndSetToolTip( info and info.Help or "TXT_KEY_MISC_UNKNOWN" );

	-- Game Options
	g_AdvancedOptionIM:ResetInstances();
	g_AdvancedOptionsList = {};

	local count = 1;
	-- When there's 8 or more players connected to us (9 player game), warn that it's an unsupported game.

	local totalPlayers = CountPlayers()

	-- Is it a private game?
	if PreGame.IsPrivateGame() then
		local controls = g_AdvancedOptionIM:GetInstance();
		g_AdvancedOptionsList[count] = controls;
		controls.Text:LocalizeAndSetText("TXT_KEY_MULTIPLAYER_PRIVATE_GAME");
		count = count + 1;
	end

	if totalPlayers > 8 then
		local controls = g_AdvancedOptionIM:GetInstance();
		g_AdvancedOptionsList[count] = controls;
		controls.Text:LocalizeAndSetText("TXT_KEY_MULTIPLAYER_UNSUPPORTED_NUMBER_OF_PLAYERS");
		count = count + 1;
	end

	for option in GameInfo.GameOptions{Visible = 1} do
		if( option.Type ~= "GAMEOPTION_END_TURN_TIMER_ENABLED"
				and option.Type ~= "GAMEOPTION_SIMULTANEOUS_TURNS"
				and option.Type ~= "GAMEOPTION_DYNAMIC_TURNS") then
			local savedValue = PreGame.GetGameOption(option.Type);
			if(savedValue ~= nil and savedValue == 1) then
				local controls = g_AdvancedOptionIM:GetInstance();
				g_AdvancedOptionsList[count] = controls;
				controls.Text:LocalizeAndSetText(option.Description);
				count = count + 1;
			end
		end
	end

	-- Update scrollable panel
	Controls.AdvancedOptions:CalculateSize();
	Controls.GameOptionsSummary:CalculateInternalSize();
end


-------------------------------------------------
-------------------------------------------------
local function PopulateCivPulldown( pullDown, handler, playerID )

	pullDown:ClearEntries()
	-- set up the random slot
	local controls = {}
	pullDown:BuildEntry( "InstanceOne", controls )
	controls.Button:SetVoids( playerID, -1 )
	controls.Button:LocalizeAndSetText( "TXT_KEY_RANDOM_LEADER" )
	controls.Button:LocalizeAndSetToolTip( "TXT_KEY_RANDOM_LEADER_HELP" )
	local civEntries = {}
	for civ in GameInfo.Civilizations{ Playable = 1 } do
		local leader = civ and GameInfo.Civilization_Leaders{ CivilizationType = civ.Type }()
		leader = leader and GameInfo.Leaders[ leader.LeaderheadType ]
		table.insert( civEntries,	{ 	ID = civ.ID,
										Title = L("TXT_KEY_RANDOM_LEADER_CIV", leader and leader.Description or "TXT_KEY_MISC_UNKNOWN", civ.ShortDescription),
										Description = L(civ.Description),
									} )
	end
	table.sort( civEntries, function(a,b) return Locale.Compare(a.Title, b.Title) == -1; end )

	for _,v in ipairs( civEntries ) do
		local controls = {};
		pullDown:BuildEntry( "InstanceOne", controls );
		controls.Button:SetVoids( playerID, v.ID )
		controls.Button:SetText( v.Title )
		controls.Button:GetTextControl():SetTruncateWidth( controls.Button:GetSizeX() - 20 )
		controls.Button:SetToolTipString( v.Description )
	end

	pullDown:CalculateInternals()
	pullDown:RegisterSelectionCallback( handler )
end

-------------------------------------------------
-------------------------------------------------
local function PopulateTeamPulldown( pullDown, handler, playerID )
	local playerTable = Matchmaking.GetPlayerList()
	local controls = {}
	pullDown:ClearEntries()
	-- Display Each Player
	if playerTable then
		for i = 1, #playerTable do
			pullDown:BuildEntry( "InstanceOne", controls );
			controls.Button:LocalizeAndSetText( "TXT_KEY_MULTIPLAYER_DEFAULT_TEAM_NAME", i )
			controls.Button:SetVoids( playerID, i-1 ); -- TODO: playerID is really more like the slot position.
		end
	end
	pullDown:CalculateInternals()
	pullDown:RegisterSelectionCallback( handler )
end

-------------------------------------------------
-------------------------------------------------
local function PopulateHandicapPulldown( pullDown, handler, playerID )
	local controls = {};
	pullDown:ClearEntries();
	for info in GameInfo.HandicapInfos() do
		if info.Type ~= "HANDICAP_AI_DEFAULT" then
			pullDown:BuildEntry( "InstanceOne", controls );
			controls.Button:LocalizeAndSetText( info.Description )
			controls.Button:LocalizeAndSetToolTip( info.Help );
			controls.Button:SetVoids( playerID, info.ID );
		end
	end
	pullDown:CalculateInternals();
	pullDown:RegisterSelectionCallback( handler )
end

-------------------------------------------------
-- TODO: This only gets called once.  We need something more dynamic.
-------------------------------------------------
local function PopulateInvitePulldown( pullDown, playerID )

	local controls = {};
	pullDown:ClearEntries();
	pullDown:BuildEntry( "InstanceOne", controls );
	controls.Button:LocalizeAndSetText( "TXT_KEY_AI_NICKNAME" )
	controls.Button:SetVoids( playerID, -1 )

	local friendList = Matchmaking.GetFriendList();

	if friendList then
		-- Populate with Steam friends.
		for i = 1, #friendList do
			local controls = {};
			pullDown:BuildEntry( "InstanceOne", controls );
			controls.Button:SetText( "Invite " .. friendList[i].playerName );
			controls.Button:SetVoids( playerID, friendList[i].steamID );
		end
	end

	pullDown:CalculateInternals();
	pullDown:RegisterSelectionCallback( InviteSelected );

end

--------------------------------------------------------------------------------------------------------------------------------
-- Chat
--------------------------------------------------------------------------------------------------------------------------------
local function OnChat( fromPlayer, toPlayer, text, eTargetType )
	local name = m_PlayerNames[ fromPlayer ]
	if name and not ContextPtr:IsHidden() then
		local controls = {}
		ContextPtr:BuildInstanceForControl( "ChatEntry", controls, Controls.ChatStack )
		table.insert( m_ChatInstances, controls )
		if #m_ChatInstances > 100 then
			Controls.ChatStack:ReleaseChild( m_ChatInstances[ 1 ].String )
			table.remove( m_ChatInstances, 1 )
		end
		controls.String:SetText( name .. ": " .. text )
		Events.AudioPlay2DSound( "AS2D_IF_MP_CHAT_DING" )
		Controls.ChatStack:CalculateSize()
		Controls.ChatScroll:CalculateInternalSize()
		Controls.ChatScroll:SetScrollValue( 1 )
	end
end

----------------------------------------------------------------
----------------------------------------------------------------
local function OnEnable( isChecked, playerID )
	if PreGame.GetMultiplayerAIEnabled() then
		if isChecked then
			SetSlotToAI( playerID )
		else
			PreGame.SetSlotStatus( playerID, SlotStatus.SS_CLOSED )
		end
	end
	Network.BroadcastPlayerInfo()
end

local function OnLock( isChecked, playerID )
	PreGame.SetSlotClaim( playerID, isChecked and SlotClaim.SLOTCLAIM_RESERVED or SlotClaim.SLOTCLAIM_UNASSIGNED )
	UpdateDisplay();
end

-----------------------------------------------------------------
-- Adjust for resolution
-----------------------------------------------------------------
local function AdjustScreenSize()

	local _, screenY = UIManager:GetScreenSizeVal()
	local TOP_COMPENSATION = (screenY - 768) * 0.3 + 52
	local height = screenY - 108 - TOP_COMPENSATION - (Controls.ChatBox:IsHidden() and 80 or 240)
			--		TOP_FRAME							BOTTOM_COMPENSATION
	Controls.MainGrid:SetSizeY( screenY - TOP_COMPENSATION )
	Controls.ListingScrollPanel:SetSizeY( height - 113 ) -- LOCAL_SLOT_COMPENSATION
	Controls.ListingScrollPanel:CalculateInternalSize()
	Controls.GameOptionsSummary:SetSizeY( height - 8 )
	Controls.GameOptionsSummary:CalculateInternalSize()
	Controls.VerticalTrim:SetSizeY( height )
end


-------------------------------------------------
-- Event Handlers
-------------------------------------------------
local EventHandlers = {

	AIProcessingStartedForPlayer = Players and UpdateTurnStatusForPlayerID or nil,
	AIProcessingEndedForPlayer = Players and UpdateTurnStatusForPlayerID or nil,
	NewGameTurn = UpdateTurnStatusForAll,
	RemotePlayerTurnEnd = UpdateTurnStatusForAll,
	GameMessageChat = OnChat,

	MultiplayerHotJoinStarted = function()
		-- Display hot joining popup if we're a hot joiner.
		if Network.IsPlayerHotJoining( Matchmaking.GetLocalID() ) then
			Controls.HotJoinPopup:SetHide( false )
		end
	end,

	MultiplayerHotJoinCompleted = function()
		-- Remove hot join popup on completion.
		Controls.HotJoinPopup:SetHide( true )
		-- The hot joiner's network connection status needs to be updated.
		return RefreshPlayerList()
	end,

--	MultiplayerGameLaunched = function()
--		UIManager:DequeuePopup( ContextPtr )
--	end,

	ConnectedToNetworkHost = function( playerID )
		UpdateDisplay()
		return OnChat( playerID, -1, L"TXT_KEY_CONNECTED" )
	end,

	MultiplayerGamePlayerUpdated = function()
		UpdateDisplay()
		UpdatePageTabView(true);
		ShowHideInviteButton();
		ShowHideSaveButton();
		return CheckGameAutoStart(); -- Player disconnects can affect the game start countdown.
	end,

	MultiplayerGamePlayerDisconnected = function( playerID )
		OnChat( playerID, -1, L( Network.IsPlayerKicked(playerID) and "TXT_KEY_KICKED" or "TXT_KEY_DISCONNECTED" ) )
		RefreshPlayerList()
		ShowHideInviteButton()
		return CheckGameAutoStart(); -- Player disconnects can affect the game start countdown.
	end,

	MultiplayerGameHostMigration = function( playerID )
		OnChat( playerID, -1, L"TXT_KEY_HOST_MIGRATION" )
		return RefreshPlayerList()
	end,

	PreGameDirty = function()
		UpdateDisplay()
		UpdatePageTabView( true )
		return CheckGameAutoStart()  -- Check for autostart because this event could to due to a ready status changing.
	end,

	MultiplayerPingTimesChanged = function()
		for playerID, instance in pairs( m_PlayerInstances ) do
			local s = playerID ~= Matchmaking.GetLocalID() and PreGame.GetSlotStatus( playerID )
			if s == SlotStatus.SS_TAKEN or s == SlotStatus.SS_OPEN then
				UpdatePingTimeLabel( instance.PingTimeLabel, playerID )
			end
		end
	end,

	PlayerVersionMismatchEvent = function( playerID, playerName, isHost )
		if isHost then
			Events.FrontEndPopup.CallImmediate( L( "TXT_KEY_MP_VERSION_MISMATCH_FOR_HOST", playerName ) )
			return Matchmaking.KickPlayer( playerID )
		else
			return HandleExitReason "TXT_KEY_MP_VERSION_MISMATCH_FOR_PLAYER"
		end
	end,

	MultiplayerGameAbandoned = function( eReason )
		if UI.GetCurrentGameState() == GameStateTypes.CIV5_GS_MAIN_MENU then
			-- Still in the front end
			if eReason == NetKicked.BY_HOST then
				return HandleExitReason "TXT_KEY_MP_KICKED"
			elseif eReason == NetKicked.NO_HOST then
				return HandleExitReason "TXT_KEY_MP_HOST_LOST"
			else
				return HandleExitReason "TXT_KEY_MP_NETWORK_CONNECTION_LOST"
			end
		end
	end,

	SystemUpdateUI = function( type )--, tag, iData1, iData2, strData1 )
		if type == SystemUpdateUIType.ScreenResize then
			return AdjustScreenSize();
		end
	end,
}

ContextPtr:SetShowHideHandler( function( isHide )
print( isHide and "HandleHide" or "HandleShow" )
	StopCountdown() -- Make sure the countdown is stopped if we're toggling the hide status of the screen.
	Controls.MainGrid:SetHide( true )
	Controls.HotJoinPopup:SetHide( true )
	Controls.SmtpPopup:SetHide( true )
	Controls.KickPopup:SetHide( true )
	Controls.AtlasLogo:SetHide( true )
	Controls.AtlasLogo:UnloadTexture()
	if isHide then
		for event, handler in pairs( EventHandlers ) do
			Events[ event ].Remove( handler )
		end
		Controls.ChatStack:DestroyAllChildren()
	elseif Matchmaking.IsLaunchingGame() then
		ContextPtr:SetHide( true )
	else
		--[[ Activate only the DLC allowed for this MP game.  Mods will also (de)ativate too.
		if not ContextPtr:IsHotLoad() then
			local prevCursor = UIManager:SetUICursor( 1 )
			print( "ActivateAllowedDLC", Modding.ActivateAllowedDLC() )
			UIManager:SetUICursor( prevCursor )
			-- Send out an event to continue on, as the ActivateDLC may have swapped out the UI
			Events.SystemUpdateUI( SystemUpdateUIType.RestoreUI, "StagingRoom" )
		end
		--]]
		-- Create slot instances
		for i = 0, m_PlayerInstanceInit do
			local instance = {}
			ContextPtr:BuildInstanceForControl( "PlayerSlot", instance, Controls.SlotStack )
			instance.LockCheck:RegisterCheckHandler( OnLock )
			instance.EnableCheck:RegisterCheckHandler( OnEnable )
			instance.EnableCheck:SetVoid1( i )
			instance.KickButton:RegisterCallback( eLClick, OnKickPlayer )
			instance.KickButton:SetVoid1( i )
			instance.EditButton:RegisterCallback( eLClick, OnEditPlayer )
			instance.EditButton:SetVoid1( i )
			instance.SwapButton:RegisterCallback( eLClick, OnSwapPlayer )
			instance.SwapButton:SetVoid1( i )
			instance.PlayerID:SetText( i+1 )
			m_PlayerInstances[i] = instance
		end
		m_PlayerInstanceInit = -1
		-- Show background image if this is the ingame dedicated server screen.
		if Network.IsDedicatedServer() then
			Controls.AtlasLogo:SetTextureAndResize( "CivilzationVAtlas.dds" )
			Controls.AtlasLogo:SetHide( false )
		end
		AdjustScreenSize()

		local isInGameScreen = IsInGameScreen()
		if not isInGameScreen and
			Matchmaking.IsHost() and
			PreGame.GetGameOption("GAMEOPTION_PITBOSS") == 1 and
			OptionsManager.GetTurnNotifySmtpHost_Cached() ~= "" and
			OptionsManager.GetTurnNotifySmtpPassword_Cached() == ""
		then
			-- Display email smtp password prompt if we're hosting a pitboss game and the password is blank.
			Controls.SmtpPasswordEdit:SetText( OptionsManager.GetTurnNotifySmtpPassword_Cached() )
			Controls.SmtpPasswordRetypeEdit:SetText( OptionsManager.GetTurnNotifySmtpPassword_Cached() )
			ValidateSmtpPassword()
			Controls.SmtpPopup:SetHide( false )
			Controls.SmtpPasswordEdit:TakeFocus()
		end

		local isHotSeat = PreGame.IsHotSeatGame()
		if isHotSeat then
			-- If Hot Seat, just 'ready' the host
			PreGame.SetReady( Matchmaking.GetLocalID(), true )
		end
		Controls.LocalReadyCheck:SetHide( isHotSeat )
		Controls.ChatBox:SetHide( isHotSeat )

		SetInLobby( true )
		m_bEditOptions = false
		Controls.ExitButton:SetHide( not isInGameScreen )
		Controls.BackButton:SetHide( isInGameScreen )
		Controls.StrategicViewButton:SetHide( not isInGameScreen )

		ShowHideInviteButton()
		UpdatePageTabView( true )

		ValidateCivSelections();

		-- Populate the civs for the slots.  This can change so it must be done every time.
		for i = 0, MAX_MAJOR_CIVS_M1 do
			local instance = m_PlayerInstances[i];
			instance.Root:SetHide( true );
			PopulateInvitePulldown( instance.InvitePulldown, i )
			PopulateCivPulldown( instance.CivPulldown, SelectCiv, i )
			PopulateTeamPulldown( instance.TeamPulldown, SelectTeam, i )
			PopulateHandicapPulldown( instance.HandicapPulldown, SelectHandicap, i )
		end
		-- Setup Local Slot
		PopulateCivPulldown( Controls.CivPulldown, SelectLocalCiv, -1 )
		PopulateTeamPulldown( Controls.TeamPulldown, SelectLocalTeam, -1 )
		PopulateHandicapPulldown( Controls.HandicapPulldown, SelectLocalHandicap, -1 )

		UpdateDisplay()
		ShowHideSaveButton()
		for event, handler in pairs( EventHandlers ) do
			Events[ event ].Add( handler )
		end
		UIManager:SetUICursor( 0 )
		Controls.MainGrid:SetHide( false )
	end
end)

----------------------------------------------------------------
-- Input Handler
----------------------------------------------------------------
do
	local KeyDown = KeyEvents.KeyDown
	local KeyUp = KeyEvents.KeyUp
	local VK_ESCAPE = Keys.VK_ESCAPE
	local VK_TAB = Keys.VK_TAB
	local VK_RETURN = Keys.VK_RETURN
	ContextPtr:SetInputHandler( function( uiMsg, wParam )
		if uiMsg == KeyDown and wParam == VK_ESCAPE then
			BackButtonClick()
			return true
		elseif uiMsg == KeyUp and (wParam == VK_TAB or wParam == VK_RETURN) then
			Controls.ChatEntry:TakeFocus()
			return true
		end
	end)
end
