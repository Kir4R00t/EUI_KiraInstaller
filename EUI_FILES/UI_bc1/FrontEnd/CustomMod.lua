include( "StackInstanceManager" )

g_InstanceManager = StackInstanceManager( "LoadButton", "InstanceRoot", Controls.LoadFileButtonStack )
g_ModList = nil
g_DynamicContexts = {}

----------------------------------------------------------------
function OnBack()
	g_ModList = nil
	Controls.DetailsBackgroundImage:UnloadTexture()
	UIManager:DequeuePopup( ContextPtr )
end

----------------------------------------------------------------
-- Event Handlers
----------------------------------------------------------------
function StartMod( i )
	local entry = g_ModList and g_ModList[ i ]
	if entry then
		entry = entry.File and Modding.GetEvaluatedFilePath( entry.ModID, entry.Version, entry.File )
		if entry then
			Events.SystemUpdateUI( SystemUpdateUIType.RestoreUI, "LoadScenario", entry.EvaluatedPath )
		end
	end
end
Controls.StartButton:RegisterCallback( Mouse.eLClick, StartMod )

----------------------------------------------------------------
Controls.BackButton:RegisterCallback( Mouse.eLClick, OnBack)
----------------------------------------------------------------
ContextPtr:SetInputHandler( function(uiMsg, wParam)
	if uiMsg == KeyEvents.KeyDown then
		if wParam == Keys.VK_ESCAPE then
			OnBack()
		end
	end
	return true
end)
----------------------------------------------------------------
function SetSelected( index )
	local instance = g_ModList[ Controls.StartButton:GetVoid1() ]
	if instance then
		instance.SelectHighlight:SetHide( true )
	end
	instance = g_ModList[ index ]
	Controls.DetailsBackgroundImage:UnloadTexture()
	Controls.StartButton:SetDisabled( not instance )
	if instance then
		Controls.StartButton:SetVoid1( index )
		instance.SelectHighlight:SetHide( false )
		Controls.Title:LocalizeAndSetText( instance.Name )
		Controls.MapDesc:LocalizeAndSetText( instance.Description )
		local customImage = Modding.GetModProperty( instance.ModID, instance.Version, "Custom_Background_" .. instance.Name )
		local customImageFile = customImage and Modding.GetEvaluatedFilePath( instance.ModID, instance.Version, customImage )
		Controls.DetailsBackgroundImage:SetTexture( customImageFile and customImageFile.EvaluatedPath or customImage or "MapRandom512.dds" )
	else
		Controls.MapDesc:SetText()
		Controls.Title:LocalizeAndSetText( "TXT_KEY_SELECT_CUSTOM_GAME" )
		Controls.DetailsBackgroundImage:SetTexture( "MapRandom512.dds" )
	end
end

ContextPtr:SetShowHideHandler( function( isHide )
	if isHide then
	elseif g_ModList and #g_ModList==1 then
		OnBack()
	else
		g_InstanceManager:ResetInstances()

		-- build a table of all save file names that we found
		g_ModList = {}

		-- build a table of all save file names that we found
		for row in Modding.GetActivatedModEntryPoints("Custom") do
			table.insert( g_ModList, row )
		end
		if #g_ModList==1 then
			StartMod( 1 )
		else
			table.sort( g_ModList, function(a,b) return a.Name < b.Name end )
			Controls.NoGames:SetHide(#g_ModList > 0)
			for i, row in ipairs( g_ModList ) do
				local instance = g_InstanceManager:GetInstance()
				for k, v in pairs(row) do
					instance[k]=v
				end
				instance.SelectHighlight:SetHide( true )
				instance.Button:LocalizeAndSetText( instance.Name )
				instance.Button:SetVoid1( i )
				instance.Button:RegisterCallback( Mouse.eLClick, SetSelected )
				g_ModList[i] = instance
			end
			Controls.LoadFileButtonStack:CalculateSize()
			Controls.ScrollPanel:CalculateInternalSize()
			Controls.LoadFileButtonStack:ReprocessAnchoring()
			SetSelected( -1 )
		end
	end
end)
----------------------------------------------------------------
