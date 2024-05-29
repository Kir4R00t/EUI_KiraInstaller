-------------------------------------------------
-- Written by bc1 using Notepad++
-------------------------------------------------
--AdjustArtOnButton( button, row, size, toolTipFunction, ... )
--PopulateUniqueButtons( function( row, toolTipFunction, ...), civ )
--PopulateCivilizationUniques( parentControl, civ )
--PopulateCivilizationIcons( controls, civ )
-------------------------------------------------
include "GameInfoCache"
local GameInfo = GameInfoCache -- warning! booleans are true, not 1, and use iterator ONLY with table field conditions, NOT string SQL query

include "IconHookup"
local IconHookup = IconHookup

if not Game then
	include "InfoTooltipInclude"
end
local GetHelpTextForUnit = GetHelpTextForUnit
local GetHelpTextForBuilding = GetHelpTextForBuilding
local GetHelpTextForImprovement = GetHelpTextForImprovement

local pcall = pcall
local format = string.format
local max = math.max
local ceil = math.ceil
local insert = table.insert
local concat = table.concat

local ContextPtr = ContextPtr
local eRClick = Mouse.eRClick
local L = Locale.ConvertTextKey

local g_random_civ = { ID=-1, PortraitIndex = 23, IconAtlas = "CIV_COLOR_ATLAS", Description = "TXT_KEY_MISC_RANDOMIZE", ShortDescription = "TXT_KEY_RANDOM_CIV" }
local g_random_leader = { ID=-1, PortraitIndex = 22, IconAtlas = "LEADER_ATLAS", Description = "TXT_KEY_RANDOM_LEADER", ShortDescription = "TXT_KEY_RANDOM_LEADER" }

-----------------
-- Pedia Callback
local getPedia getPedia = not Game and function( ... )
	UIManager:QueuePopup( LookUpControl( "/FrontEnd/MainMenu/Civilopedia" ), PopupPriority.eUtmost )
	getPedia = Events.SearchForPediaEntry.Call
	getPedia( ... )
end

-----------------
-- Icon Management
local function adjustArtOnButton( button, row, size, toolTipFunction, ... )
	if button and row then
		local ok, tip = pcall( toolTipFunction, row.ID, ... )
		if ok then
			button:SetToolTipString( tip )
		else
			button:LocalizeAndSetToolTip( row.Description )
		end
		if getPedia and button.RegisterCallback then
			local pedia = row.ShortDescription or row.Description
			button:RegisterCallback( eRClick, function() getPedia( pedia ) end )
		end
		button:SetHide( not IconHookup( row.PortraitIndex, size, row.IconAtlas, button ) )
	end
end

local function populateUniqueButtons( setButton, civ )
	if civ then
		local condition = { CivilizationType = civ.Type }

		-- UU icons
		for unit in GameInfo.Civilization_UnitClassOverrides( condition ) do
			unit = GameInfo.Units[unit.UnitType]
			if unit then
				setButton( unit, GetHelpTextForUnit, true )
			end
		end

		-- UB icons
		for building in GameInfo.Civilization_BuildingClassOverrides( condition ) do
			building = GameInfo.Buildings[building.BuildingType]
			if building then
				setButton( building, GetHelpTextForBuilding )
			end
		end

		-- UI icons
		for improvement in GameInfo.Improvements( condition ) do
			setButton( improvement, GetHelpTextForImprovement )
		end
	else
		setButton( g_random_civ )
		setButton( g_random_civ )
	end
end

local function newItemIcon( parentControl, row, ... )
	if parentControl and row then
		local controls = {}
		ContextPtr:BuildInstanceForControl( "IconInstance", controls, parentControl )
		adjustArtOnButton( controls.Portrait, row, controls.Portrait:GetSizeX(), ... )
		if controls.Text then
			controls.Text:LocalizeAndSetText( row.Description )
		end
	end
end

local function populateCivilizationUniques( parentControl, civ )
	local function newButton( ... )
		newItemIcon( parentControl, ... )
	end
	return populateUniqueButtons( newButton, civ )
end

function PopulateCivilizationIcons( controls, civ )

	local leader
	local traitDescriptions = {}
	local traitNames = {}
	local iconParentControl = controls.Icons
	-- UU, UB, UI icons
	populateCivilizationUniques( iconParentControl, civ )
	if civ then
		-- Leader
		leader = GameInfo.Civilization_Leaders{ CivilizationType = civ.Type }()
		leader = leader and GameInfo.Leaders[leader.LeaderheadType]
		if leader then
			if getPedia then
				local pedia = leader.Description
				controls.Button:RegisterCallback( eRClick, function() getPedia( pedia ) end )
			end
			for trait in GameInfo.Leader_Traits{ LeaderType = leader.Type } do
				trait = GameInfo.Traits[ trait.TraitType ]
				if trait then
					insert( traitDescriptions, L(trait.Description) )
					insert( traitNames, trait._Name )
				end
			end
		end
	else
		traitDescriptions = { L"TXT_KEY_RANDOM_LEADER_HELP" }
		traitNames = { L"TXT_KEY_MISC_RANDOMIZE" }
		civ = g_random_civ
		leader = g_random_leader
	end
	-- Civ icon
	newItemIcon( iconParentControl, civ )
	local n = iconParentControl:GetNumChildren()
	iconParentControl:SetWrapWidth( ceil( n / ceil( n / 4 ) ) * 56 )
	iconParentControl:CalculateSize()
	iconParentControl:ReprocessAnchoring()
	controls.Button:SetVoid1( civ.ID )
	controls.Description:SetText( concat( traitDescriptions, "[NEWLINE]" ) )
	controls.Title:SetText( format("%s (%s)", L( "TXT_KEY_RANDOM_LEADER_CIV", leader.Description, civ.ShortDescription ), concat( traitNames, ", " ) ) )
	IconHookup( leader.PortraitIndex, controls.Portrait:GetSizeX(), leader.IconAtlas, controls.Portrait )
	local height = max( 100, iconParentControl:GetSizeY() + 8 )
	controls.Button:SetSizeY( height )
	controls.Anim:SetSizeY( height + 4 )
	controls.Button:ReprocessAnchoring()
end

PopulateCivilizationUniques = populateCivilizationUniques
-- exports for UniqueBonuses
AdjustArtOnButton = adjustArtOnButton
PopulateUniqueButtons = populateUniqueButtons
