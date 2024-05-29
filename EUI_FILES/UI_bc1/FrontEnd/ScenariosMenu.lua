include( "InstanceManager" )

----------------------------------------------------------------
-- "Global" Variables
----------------------------------------------------------------
local g_InstanceManager = InstanceManager:new( "LoadButton", "Button", Controls.LoadFileButtonStack )
local g_ScenarioList = {}
local g_iSelected

----------------------------------------------------------------
local function OnBack()
-- = Events.ExitToMainMenu.Call
	UIManager:DequeuePopup( ContextPtr )
end

----------------------------------------------------------------
-- Event Handlers
----------------------------------------------------------------
Controls.StartButton:RegisterCallback( Mouse.eLClick, function()
	local entry = g_ScenarioList[ g_iSelected ]
	if entry then
		UIManager:SetUICursor( 1 )
		Modding.ActivateSpecificMod( entry.ID, entry.Version )
		entry = entry.File and Modding.GetEvaluatedFilePath( entry.ID, entry.Version, entry.File )
		if entry then
			Events.SystemUpdateUI( SystemUpdateUIType.RestoreUI, "LoadScenario", entry.EvaluatedPath )
		else
			Events.SystemUpdateUI( SystemUpdateUIType.RestoreUI, "ModsMenu" )
		end
	end
end)
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

local ModdingTooltips = {
	nil, --"TXT_KEY_MODDING_MOD_BLOCKED_BY_OTHER_MOD",
	nil, --"TXT_KEY_MODDING_MOD_VERSION_ALREADY_ENABLED",
	"TXT_KEY_MODDING_MOD_MISSING_DEPENDENCIES",
	nil, --"TXT_KEY_MODDING_MOD_HAS_EXCLUSIVITY_CONFLICTS",
	"TXT_KEY_MODDING_MOD_BAD_GAMEVERSION",
}

local function SetSelected( index )
	local backgroundImage = "MapRandom512.dds"
	local foregroundImage
	local canEnableStatus = "TXT_KEY_SELECT_SCENARIO"

	local customMod = g_ScenarioList[ g_iSelected ]
	if customMod then
        customMod.SelectHighlight:SetHide( true )
    end

    g_iSelected = index
	customMod = g_ScenarioList[ index ]
    if customMod then
		customMod.SelectHighlight:SetHide( false )

		Controls.Title:SetText(customMod.DisplayName)
		Controls.MapDesc:SetText(customMod.DisplayDescription)
		if customMod.Name then
			local customImage = Modding.GetModProperty( customMod.ID, customMod.Version, "Custom_Background_" .. customMod.Name )
			local customImageFile = customImage and Modding.GetEvaluatedFilePath( customMod.ID, customMod.Version, customImage )
			backgroundImage = customImageFile and customImageFile.EvaluatedPath or customImage or backgroundImage

			customImage = Modding.GetModProperty( customMod.ID, customMod.Version, "Custom_Foreground_" .. customMod.Name )
			customImageFile = customImage and Modding.GetEvaluatedFilePath( customMod.ID, customMod.Version, customImage )
			foregroundImage = customImageFile and customImageFile.EvaluatedPath or customImage
		end

		--Test whether we can enable this mod.
		canEnableStatus = ModdingTooltips[ Modding.CanEnableMod(customMod.ID, customMod.Version) ]

	else
		-- Set All Info to nothing
		Controls.Title:LocalizeAndSetText( "TXT_KEY_SELECT_SCENARIO" )
		Controls.MapDesc:SetText()
    end
	Controls.DetailsForegroundImage:UnloadTexture()
	if foregroundImage then
		Controls.DetailsForegroundImage:SetTexture( foregroundImage )
	end
	Controls.DetailsForegroundImage:SetHide( not foregroundImage )
	Controls.DetailsBackgroundImage:UnloadTexture()
	Controls.DetailsBackgroundImage:SetTexture( backgroundImage )
	Controls.DetailsBackgroundImage:SetHide( false )
	Controls.StartButton:SetToolTipString( canEnableStatus and Locale.ConvertTextKey( canEnableStatus ) )
	Controls.StartButton:SetDisabled( canEnableStatus )
end
----------------------------------------------------------------

local function SortByDisplayName( a,b )
	return Locale.Compare( a.DisplayName, b.DisplayName ) == -1
end

ContextPtr:SetShowHideHandler(function(isHide)
    if isHide then
		Controls.DetailsForegroundImage:UnloadTexture()
		Controls.DetailsForegroundImage:SetHide( true )
		Controls.DetailsBackgroundImage:UnloadTexture()
		Controls.DetailsBackgroundImage:SetHide( true )
	else
		if not ContextPtr:IsHotLoad() then
			print( "Modding.ActivateDLC" )
			UIManager:SetUICursor( 1 )
			Modding.ActivateDLC()
			Events.SystemUpdateUI( SystemUpdateUIType.RestoreUI, "ScenariosScreen" )
		end

		SetSelected()
		g_InstanceManager:ResetInstances()
		g_ScenarioList = {}

		for _, mod in pairs( Modding.GetInstalledMods() ) do
			local instance
			for k in ("Custom Map"):gmatch("(%S*)%s*") do
				for entry in Modding.GetModEntryPoints( mod.ID, mod.Version, k ) do
					if instance then
						instance.File = nil
						instance.DisplayName = mod.Name.." (v"..instance.Version..")"
						instance.DisplayDescription = mod.Teaser
						break
					else
						instance = {
							Name = entry.Name,
							DisplayName = Locale.ConvertTextKey( Locale.HasTextKey(entry.Name) and entry.Name or (mod.Name.." (v"..entry.Version..")") ),
							DisplayDescription = mod.Teaser or entry.Description and Locale.ConvertTextKey(entry.Description),
							File = k=="Custom" and entry.File,
							ID = entry.ModID,
							Version = entry.Version,
						}
						table.insert( g_ScenarioList, instance )
					end
				end
				if instance then
					break
				end
			end
		end

		table.sort( g_ScenarioList, SortByDisplayName )
		Controls.NoGames:SetHide( #g_ScenarioList > 0 )

		for i, entry in ipairs(g_ScenarioList) do
			local controlTable = g_InstanceManager:GetInstance()
			entry.SelectHighlight = controlTable.SelectHighlight
			controlTable.Button:SetText( entry.DisplayName )
			controlTable.Button:SetVoid1( i )
			controlTable.Button:RegisterCallback( Mouse.eLClick, SetSelected )
		end

		Controls.LoadFileButtonStack:CalculateSize()
		Controls.ScrollPanel:CalculateInternalSize()
		Controls.LoadFileButtonStack:ReprocessAnchoring()
	end
end)
----------------------------------------------------------------
