local ContextPtr = ContextPtr
local Controls = Controls
local UIManager = UIManager
local KeyDown = KeyEvents.KeyDown
local VK_ESCAPE = Keys.VK_ESCAPE

local function OnBack()
    UIManager:PopModal( ContextPtr )
end
--Controls.BackButton:RegisterCallback( Mouse.eLClick, OnBack )
Controls.CloseButton:RegisterCallback( Mouse.eLClick, OnBack )

Events.FrontEndPopup.Add( function( message )
    UIManager:PushModal( ContextPtr )
    Controls.PopupText:LocalizeAndSetText( message )
	print( message )
end)

ContextPtr:SetInputHandler( function( uiMsg, wParam )
    if uiMsg == KeyDown then
        if wParam == VK_ESCAPE then
            OnBack()
            return true
        end
    end
end)
