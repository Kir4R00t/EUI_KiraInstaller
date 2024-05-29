
Events.UserRequestClose.Add( function() UIManager:PushModal( ContextPtr ) end )

Controls.ExitToWindows:RegisterCallback( Mouse.eLClick, UI.ExitGame )

Controls.ExitToMain:RegisterCallback( Mouse.eLClick, Events.ExitToMainMenu.Call )

local function returnToGame()
	UIManager:PopModal( ContextPtr );
end
Controls.ReturnToGame:RegisterCallback( Mouse.eLClick, returnToGame );

ContextPtr:SetInputHandler( function( uiMsg, wParam )
    if uiMsg == KeyEvents.KeyDown then
        if wParam == Keys.VK_ESCAPE then
            returnToGame()
        end
    end
    return true
end)

ContextPtr:SetShowHideHandler( function( isHide )
	if not isHide then
		Controls.Message:LocalizeAndSetText( PreGame.GameStarted() and "TXT_KEY_MENU_RETURN_EXIT_WARN" or "TXT_KEY_MENU_EXIT_WARN" )
	end	
end)
