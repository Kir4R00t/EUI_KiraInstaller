-------------------------------------------------
-- Functions
-------------------------------------------------
local Controls = Controls
local ContextPtr = ContextPtr
local KeyDown = KeyEvents.KeyDown
local VK_ESCAPE = Keys.VK_ESCAPE
local Matchmaking = Matchmaking
local UIManager = UIManager
local FrontEndPopup = Events.FrontEndPopup.CallImmediate

print "Loading Joining Room"

local function JoinMultiplayerGame()
	-- ActivateAllowedDLC only knows what DLC are required at this stage
	print( "ActivateAllowedDLC", Modding.ActivateAllowedDLC() )
	-- Send out an event to continue to staging room; note the ActivateDLC may have swapped out the UI
	Events.SystemUpdateUI( SystemUpdateUIType.RestoreUI, "StagingRoom" )
	ContextPtr:SetHide( true )
end

local function LeaveMultiplayerGame()
	Matchmaking.LeaveMultiplayerGame()
	UIManager:DequeuePopup( ContextPtr )
end

local function JoinFailed( s )
	FrontEndPopup( s or "TXT_KEY_MP_JOIN_FAILED" )
	return LeaveMultiplayerGame()
end

local function ShowJoinState( s )
	Controls.JoiningLabel:LocalizeAndSetText( s )
	return print( s )
end

-------------------------------------------------
-- Event Handlers
-------------------------------------------------
local EventHandlers = {
	MultiplayerJoinRoomComplete = function()
		if Matchmaking.IsHost() then
			return JoinMultiplayerGame()
		else
			return ShowJoinState "TXT_KEY_MULTIPLAYER_JOINING_HOST"
		end
	end,
	MultiplayerJoinRoomFailed = function( iExtendedError, aExtendedErrorText )
		local szText
		if iExtendedError == NetErrors.MISSING_REQUIRED_DATA then
			szText = Locale.ConvertTextKey("TXT_KEY_MP_JOIN_FAILED_MISSING_RESOURCES")
			-- The aExtendedErrorText will contain an array of the IDs of the resources (DLC/Mods) needed by the game.
			for index, value in pairs(aExtendedErrorText) do
				szText = szText .. "[NEWLINE] [ICON_BULLET]" .. Locale.ConvertTextKey(value);
			end
		elseif iExtendedError == NetErrors.ROOM_FULL then
			szText = "TXT_KEY_MP_ROOM_FULL"
		end
		return JoinFailed( szText )
	end,
	MultiplayerConnectionFailed = function()
		-- We should only get this if we couldn't complete the connection to the host of the room
		return JoinFailed()
	end,
	MultiplayerGameAbandoned = function( eReason )
		return JoinFailed( eReason == NetKicked.BY_HOST and "TXT_KEY_MP_KICKED" or eReason == NetKicked.NO_ROOM and "TXT_KEY_MP_ROOM_FULL" )
	end,
	ConnectedToNetworkHost = function()
		return ShowJoinState "TXT_KEY_MULTIPLAYER_JOINING_PLAYERS"
	end,
	MultiplayerConnectionComplete = function()
		if not Matchmaking.IsHost() then
			return JoinMultiplayerGame()
		end
	end,
	MultiplayerNetRegistered = function()
		UIManager:SetUICursor( 1 )
		return ShowJoinState "TXT_KEY_MULTIPLAYER_JOINING_GAMESTATE"
	end,
	PlayerVersionMismatchEvent = function( playerID, playerName, isHost )
		if isHost then
			Matchmaking.KickPlayer( playerID )
			return FrontEndPopup( Locale.ConvertTextKey( "TXT_KEY_MP_VERSION_MISMATCH_FOR_HOST", playerName ) )
		else
			-- we mismatched with the host, exit the game.
			return JoinFailed( "TXT_KEY_MP_VERSION_MISMATCH_FOR_PLAYER" )
		end
	end,
}

-------------------------------------------------
-- Show / Hide Handler
-------------------------------------------------
ContextPtr:SetShowHideHandler( function( isHide )
print( isHide and "HandleHide" or "HandleShow", isInit and "isInit" )
	if isHide then
		for event, handler in pairs( EventHandlers ) do
			Events[ event ].Remove( handler )
		end
		UIManager:SetUICursor( 0 )
		Controls.JoinImage:UnloadTexture()
	elseif Matchmaking.IsLaunchingGame() then
		ContextPtr:SetHide( true )
	else
		UIManager:SetUICursor( 1 )
		ShowJoinState "TXT_KEY_MULTIPLAYER_JOINING_ROOM"
		for event, handler in pairs( EventHandlers ) do
			Events[ event ].Add( handler )
		end
		Controls.JoinImage:SetTextureAndResize( "MapRandom512.dds" )
		Controls.MainGrid:DoAutoSize()
		Controls.MainGrid:ReprocessAnchoring()
	end
end)

----------------------------------------------------------------
-- Input Handler
----------------------------------------------------------------
ContextPtr:SetInputHandler( function( uiMsg, wParam )
	if uiMsg == KeyDown then
		if wParam == VK_ESCAPE then
			LeaveMultiplayerGame()
		end
	end
	return true
end)

Controls.CancelButton:RegisterCallback( Mouse.eLClick, LeaveMultiplayerGame )
