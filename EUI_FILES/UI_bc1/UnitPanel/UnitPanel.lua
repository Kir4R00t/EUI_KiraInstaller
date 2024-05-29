--==========================================================
-- Unit Panel
-- Re-written by bc1 using Notepad++
-- code is common using gk_mode and bnw_mode switches
--==========================================================

Events.SequenceGameInitComplete.Add(function()

include "UserInterfaceSettings"
local UserInterfaceSettings = UserInterfaceSettings

include "GameInfoCache" -- warning! booleans are true, not 1, and use iterator ONLY with table field conditions, NOT string SQL query
local GameInfo = GameInfoCache

include "IconHookup"
local IconHookup = IconHookup
local Color = Color
local PrimaryColors = PrimaryColors
local BackgroundColors = BackgroundColors

include "GetUnitBuildProgressData"
local GetUnitBuildProgressData = GetUnitBuildProgressData

--==========================================================
-- Minor lua optimizations
--==========================================================

local gk_mode = Game.GetReligionName ~= nil
local bnw_mode = Game.GetActiveLeague ~= nil
--local debug_print = print

local ceil = math.ceil
local floor = math.floor
local min = math.min
local max = math.max
local pairs = pairs
--local print = print
local format = string.format
local insert = table.insert
local remove = table.remove
local tostring = tostring

local ActionSubTypes = ActionSubTypes
local ActivityTypes = ActivityTypes
local ContextPtr = ContextPtr
local Controls = Controls
local DomainTypes = DomainTypes
local Events = Events
local Game = Game
local GameDefines = GameDefines
local GameInfoActions = GameInfoActions
local GameInfo_Automates = GameInfo.Automates
local GameInfo_Builds = GameInfo.Builds
local GameInfo_Missions = GameInfo.Missions
local GameInfo_Units = GameInfo.Units
local L = Locale.ConvertTextKey
local ToUpper = Locale.ToUpper
--local PlotDistance = Map.PlotDistance
local Mouse = Mouse
local OrderTypes = OrderTypes
local Players = Players
local Teams = Teams
local ToHexFromGrid = ToHexFromGrid
local DoSelectCityAtPlot = UI.DoSelectCityAtPlot
local GetHeadSelectedCity = UI.GetHeadSelectedCity
local GetHeadSelectedUnit = UI.GetHeadSelectedUnit
--local GetSelectedUnitID = UI.GetSelectedUnitID
local GetUnitFlagIcon = UI.GetUnitFlagIcon
local GetUnitPortraitIcon = UI.GetUnitPortraitIcon
local LookAt = UI.LookAt
local SelectUnit = UI.SelectUnit

--==========================================================
-- Globals
--==========================================================

local g_activePlayerID, g_activePlayer, g_activeTeamID, g_activeTeam, g_activeTechs
local g_AllPlayerOptions = { UnitTypes = {}, UnitsInRibbon = {} }

local g_ActivePlayerUnitTypes
local g_ActivePlayerUnitsInRibbon = {}
local g_isHideCityList, g_isHideUnitList, g_isHideUnitTypes

--[[ 
 _   _       _ _          ___      ____ _ _   _             ____  _ _     _                 
| | | |_ __ (_) |_ ___   ( _ )    / ___(_) |_(_) ___  ___  |  _ \(_) |__ | |__   ___  _ __  
| | | | '_ \| | __/ __|  / _ \/\ | |   | | __| |/ _ \/ __| | |_) | | '_ \| '_ \ / _ \| '_ \ 
| |_| | | | | | |_\__ \ | (_>  < | |___| | |_| |  __/\__ \ |  _ <| | |_) | |_) | (_) | | | |
 \___/|_| |_|_|\__|___/  \___/\/  \____|_|\__|_|\___||___/ |_| \_\_|_.__/|_.__/ \___/|_| |_|
]]

-- NO_ACTIVITY, ACTIVITY_AWAKE, ACTIVITY_HOLD, ACTIVITY_SLEEP, ACTIVITY_HEAL, ACTIVITY_SENTRY, ACTIVITY_INTERCEPT, ACTIVITY_MISSION
local g_activityMissions = {
--[ActivityTypes.ACTIVITY_AWAKE or -1] = nil,
[ActivityTypes.ACTIVITY_HOLD or -1] = false, --GameInfo_Missions.MISSION_SKIP, -- only when moves left > 0
--[ActivityTypes.ACTIVITY_SLEEP or -1] = GameInfo_Missions.MISSION_SLEEP, -- can be sleep or fortify
[ActivityTypes.ACTIVITY_HEAL or -1] = GameInfo_Missions.MISSION_HEAL,
[ActivityTypes.ACTIVITY_SENTRY or -1] = GameInfo_Missions.MISSION_ALERT,
[ActivityTypes.ACTIVITY_INTERCEPT or -1] = GameInfo_Missions.MISSION_AIRPATROL,
--[ActivityTypes.ACTIVITY_MISSION or -1] = GameInfo_Missions.MISSION_MOVE_TO,
[-1] = nil }

local MAX_HIT_POINTS = GameDefines.MAX_HIT_POINTS or 100
local AIR_UNIT_REBASE_RANGE_MULTIPLIER = GameDefines.AIR_UNIT_REBASE_RANGE_MULTIPLIER
local RELIGION_MISSIONARY_PRESSURE_MULTIPLIER = GameDefines.RELIGION_MISSIONARY_PRESSURE_MULTIPLIER or 1
local MOVE_DENOMINATOR = GameDefines.MOVE_DENOMINATOR

local g_unitsIM, g_citiesIM, g_unitTypesIM, g_units, g_cities, g_unitTypes

local g_cityFocusIcons = {
--[CityAIFocusTypes.NO_CITY_AI_FOCUS_TYPE or -1] = "",
[CityAIFocusTypes.CITY_AI_FOCUS_TYPE_FOOD or -1] = "[ICON_FOOD]",
[CityAIFocusTypes.CITY_AI_FOCUS_TYPE_PRODUCTION or -1] = "[ICON_PRODUCTION]",
[CityAIFocusTypes.CITY_AI_FOCUS_TYPE_GOLD or -1] = "[ICON_GOLD]",
[CityAIFocusTypes.CITY_AI_FOCUS_TYPE_SCIENCE or -1] = "[ICON_RESEARCH]",
[CityAIFocusTypes.CITY_AI_FOCUS_TYPE_CULTURE or -1] = "[ICON_CULTURE]",
[CityAIFocusTypes.CITY_AI_FOCUS_TYPE_GREAT_PEOPLE or -1] = "[ICON_GREAT_PEOPLE]",
[CityAIFocusTypes.CITY_AI_FOCUS_TYPE_FAITH or -1] = "[ICON_PEACE]",
[-1] = nil }

local g_UnitTypeOrder = {}
do
	local i = 0
	for unit in GameInfo.Units() do
		i = i + 65536
		g_UnitTypeOrder[ unit.ID ] = i
	end
end

local function SortByVoid2( a, b )
	return a and b and a:GetVoid2() > b:GetVoid2()
end

--==========================================================
-- Tooltip Utilities
--==========================================================

local function lookAtPlot( plot )
	local hex = ToHexFromGrid{ x=plot:GetX(), y=plot:GetY() }
	Events.GameplayFX( hex.x, hex.y, -1 )
	return LookAt( plot )
end

local function lookAtUnit( unit )
	if unit then
		return lookAtPlot( unit:GetPlot() )
	end
end

--==========================================================
-- Ribbon Manager
--==========================================================

local function g_RibbonManager( name, stack, scrap, createAllItems, initItem, callbacks, tooltips, closure, toolTipCallback )
	local index = {}
	local spares = {}

	local function Create( item, itemID, itemOrder )
		if item then
			local instance = remove( spares )
			local button
			if instance then
--debug_print("Recycle from scrap", name, instance, "item", itemID, item and item:GetName() )
				button = instance.Button
				button:ChangeParent( stack )
			else
				instance = { m_PromotionIcons={} }
--debug_print("Create new ", name, instance, "item", itemID, item and item:GetName() )
				ContextPtr:BuildInstanceForControl( name, instance, stack )
				-- Setup Tootip Callbacks
				for controlID, toolTipType in pairs( tooltips ) do
					instance[ controlID ]:SetToolTipCallback( function( control )
						control:SetToolTipCallback( function( control ) return toolTipCallback( control, closure( button ) ) end )
						control:SetToolTipType( toolTipType )
					end)
				end
				-- Setup action Callbacks
				button = instance.Button
				for event, callback in pairs( callbacks ) do
					button:RegisterCallback( event, callback )
				end
			end
			index[ itemID ] = instance
			button:SetVoids( itemID, itemOrder )
			return initItem( item, instance )
--else print( "Failed attempt to add an item to the list", itemID )
		end
	end

return{
	Create = Create,

	Destroy = function( itemID )
		local instance = index[ itemID ]
--debug_print( "Remove item from list", name, "item", itemID, instance )
		if instance then
			index[ itemID ] = nil
			insert( spares, instance )
			instance.Button:ChangeParent( scrap )
		end
	end,

	Initialize = function( isHidden )
--debug_print("Initializing ", name, " stack", "hidden ?", isHidden )
		for itemID, instance in pairs( index ) do
			insert( spares, instance )
			instance.Button:ChangeParent( scrap )
			index[ itemID ] = nil
		end
		if not isHidden then
--debug_print("Initializing ", name, " stack contents" )
			createAllItems( Create )
		end
	end,

	}, index
end

--==========================================================
-- Item Functions
--==========================================================

local function UpdateCity( city, instance )
	if city and instance then
		local isNotPuppet = not city:IsPuppet()
		local isRazing = city:IsRazing()
		local isResistance = city:IsResistance()
		local isCapital = city:IsCapital()

		local itemInfo, portraitOffset, portraitAtlas, buildPercent
		local turnsRemaining = city:GetProductionTurnsLeft()
		local productionNeeded = city:GetProductionNeeded()
		local storedProduction = city:GetProduction() + city:GetOverflowProduction() + city:GetFeatureProduction()
		local orderID, itemID = city:GetOrderFromQueue()
		if orderID == OrderTypes.ORDER_TRAIN then
			itemInfo = GameInfo.Units
			portraitOffset, portraitAtlas = GetUnitPortraitIcon( itemID, g_activePlayerID )
		elseif orderID == OrderTypes.ORDER_CONSTRUCT then
			itemInfo = GameInfo.Buildings
		elseif orderID == OrderTypes.ORDER_CREATE then
			itemInfo = GameInfo.Projects
		elseif orderID == OrderTypes.ORDER_MAINTAIN then
			itemInfo = GameInfo.Processes
			turnsRemaining = nil
			productionNeeded = 0
		end
		if itemInfo then
			itemInfo = itemInfo[ itemID ]or{}
			itemInfo = IconHookup( portraitOffset or itemInfo.PortraitIndex, 64, portraitAtlas or itemInfo.IconAtlas, instance.CityProduction )
			if productionNeeded > 0 then
				buildPercent = 1 - max( 0, storedProduction/productionNeeded )
			end
			instance.BuildMeter:SetPercents( 0, buildPercent or 0 )
		end
		instance.CityProduction:SetHide( not itemInfo )
		instance.BuildGrowth:SetString( itemInfo and not isResistance and not isRazing and turnsRemaining )
		instance.CityPopulation:SetString( city:GetPopulation() )
		local foodPerTurnTimes100 = city:FoodDifferenceTimes100()
		if isRazing or foodPerTurnTimes100 < 0 then
			instance.CityGrowth:SetString( "[COLOR_RED]" .. (isRazing and 1 or min( floor( ( city:GetFoodTimes100() ) / -foodPerTurnTimes100 ) + 1, 99 ) ) .. "[ENDCOLOR]" )
		elseif city:IsForcedAvoidGrowth() then
			instance.CityGrowth:SetString( "[ICON_LOCKED]" )
		elseif city:IsFoodProduction() or foodPerTurnTimes100 == 0 then
			instance.CityGrowth:SetString()
		else
			instance.CityGrowth:SetString( min( city:GetFoodTurnsLeft(), 99 ) )
		end

		instance.CityIsCapital:SetHide( not isCapital )
		instance.CityIsPuppet:SetHide( isNotPuppet )
		instance.CityFocus:SetText( not isRazing and isNotPuppet and g_cityFocusIcons[city:GetFocusType()] )
		instance.CityQuests:SetText( city:GetWeLoveTheKingDayCounter() > 0 and "[ICON_HAPPINESS_1]" or (GameInfo.Resources[city:GetResourceDemanded()] or {}).IconString )
		instance.CityIsRazing:SetHide( not isRazing )
		instance.CityIsResistance:SetHide( not isResistance )
		instance.CityResistanceTurns:SetText( isRazing and city:GetRazingTurns() or isResistance and city:GetResistanceTurns() )
		instance.CityIsConnected:SetHide( isCapital or not g_activePlayer:IsCapitalConnectedToCity( city ) )
		instance.CityIsBlockaded:SetHide( not city:IsBlockaded() )
		instance.CityIsOccupied:SetHide( not city:IsOccupied() or city:IsNoOccupiedUnhappiness() )
		instance.CityName:SetString( city:GetName() )
		local religion = city.GetReligiousMajority and GameInfo.Religions[city:GetReligiousMajority()]
		instance.CityReligion:SetString( religion and religion.IconString )
		local culturePerTurn = city:GetJONSCulturePerTurn()
		instance.BorderGrowth:SetString( culturePerTurn > 0 and ceil( (city:GetJONSCultureThreshold() - city:GetJONSCultureStored()) / culturePerTurn ) )

		local percent = 1 - city:GetDamage() / ( city.GetMaxHitPoints and city:GetMaxHitPoints() or GameDefines.MAX_CITY_HIT_POINTS )
		instance.Button:SetColor( Color( 1, percent, percent, 1 ) )
	end
end

local function UpdateUnit( unit, instance, nextInstance )
	if unit and instance then
		local unitMovesLeft = unit:MovesLeft()
		local pip
		if unitMovesLeft >= unit:MaxMoves() then
			pip = 0 -- cyan (green)
		elseif unitMovesLeft > 0 then
			if unit:IsCombatUnit() and unit:IsOutOfAttacks() then
				pip = 96 -- orange (gray)
			else
				pip = 32 -- green (yellow)
			end
		else
			pip = 64 -- red
		end
		local damage = unit:GetDamage()
		local percent
		if damage <= 0 then
			percent = 1
		elseif instance == Controls then
			percent = 1 - damage / MAX_HIT_POINTS / 3
		else
			percent = 1 - damage / MAX_HIT_POINTS
		end

		local info
		local text
		local buildID = unit:GetBuildType()

		if buildID ~= -1 then -- unit is actively building something
			info = GameInfo_Builds[buildID]
			text = GetUnitBuildProgressData( unit:GetPlot(), buildID, unit )
			if text > 99 then text = nil end

		elseif unit:IsEmbarked() then
			info = GameInfo_Missions.MISSION_EMBARK

		elseif unit:IsReadyToMove() then

		elseif unit:IsAutomated() then
			if unit:IsWork() then
				info = GameInfo_Automates.AUTOMATE_BUILD
			elseif bnw_mode and unit:IsTrade() then
				info = GameInfo_Missions.MISSION_ESTABLISH_TRADE_ROUTE
			else
				info = GameInfo_Automates.AUTOMATE_EXPLORE
			end

		elseif unit:LastMissionPlot() ~= unit:GetPlot() then
			info = GameInfo_Missions.MISSION_MOVE_TO

		elseif unit:IsWaiting() then
			local activityType = unit:GetActivityType()
			info = g_activityMissions[ activityType ]
			if not info and unitMovesLeft > 0 then
--print( "ACTIVITY_MISSION", unit:GetName(), unit:GetX(), unit:GetY(), unit:GetPlot() ~= unit:LastMissionPlot() )
				if info == false then
					info = GameInfo_Missions.MISSION_SKIP
				elseif unit:IsGarrisoned() then
					info = GameInfo_Missions.MISSION_GARRISON
				elseif unit:IsEverFortifyable() then
					info = GameInfo_Missions.MISSION_FORTIFY
				else
					info = GameInfo_Missions.MISSION_SLEEP
				end
			end

		elseif unitMovesLeft > 0 then
			info = GameInfo_Missions.MISSION_MOVE_TO
		end

		repeat
			instance.Button:SetColor( Color( 1, percent, percent, 1 ) )
			instance.MovementPip:SetTextureOffsetVal( 0, pip )
			instance.Mission:SetHide( not( info and IconHookup( info.IconIndex, 45, info.IconAtlas, instance.Mission ) ) )
			instance.MissionText:SetText( text )
			if nextInstance then
				instance, nextInstance = nextInstance
				instance.MovementPip:Play()
			else
				break
			end
		until false
	end
end

local function FilterUnit( unit )
	return unit and g_ActivePlayerUnitsInRibbon[ unit:GetUnitType() ]
end

--==========================================================
-- Unit Ribbon "Object"
--==========================================================
local CallFlagManagerUpdateUnitPromotions = LuaEvents.CallFlagManagerUpdateUnitPromotions.Call

g_unitsIM, g_units = g_RibbonManager( "UnitInstance", Controls.UnitStack, Controls.Scrap,
	function( Create ) -- createAllItems( Create )
		local unitID
		for unit in g_activePlayer:Units() do
			if FilterUnit( unit ) then
				unitID = unit:GetID()
				Create( unit, unitID, g_UnitTypeOrder[unit:GetUnitType()] + unitID % 65536 )
			end
		end
		Controls.UnitStack:SortChildren( SortByVoid2 )
	end,
	function( unit, instance ) -- initItem( item, instance )
		local portraitOffset, portraitAtlas = GetUnitPortraitIcon( unit )
		IconHookup( portraitOffset, 64, portraitAtlas, instance.Portrait )
		if unit == GetHeadSelectedUnit() then
			instance.MovementPip:Play()
		else
			instance.MovementPip:SetToBeginning()
		end
		UpdateUnit( unit, instance )
		return CallFlagManagerUpdateUnitPromotions( unit )
	end,
	{-- the callback function table names need to match associated instance control ID defined in xml
		[Mouse.eLClick] = function( unitID )
			local unit = g_activePlayer:GetUnitByID( unitID )
			SelectUnit( unit )
			lookAtUnit( unit )
		end,
		[Mouse.eRClick] = function( unitID )
			lookAtUnit( g_activePlayer:GetUnitByID( unitID ) )
		end,
	},--/unit callbacks
	{
		Button = "EUI_UnitTooltip",
		MovementPip = "EUI_ItemTooltip",
		Mission = "EUI_ItemTooltip",
	},
	function( button )
		return g_activePlayer:GetUnitByID( button:GetVoid1() )
	end,
	LuaEvents.UnitToolTips.Call
)--/unit ribbon object
--==========================================================

LuaEvents.EUI_UnitRibbonTable( g_units )

--==========================================================
-- City Ribbon "Object"
--==========================================================
g_citiesIM, g_cities = g_RibbonManager( "CityInstance", Controls.CityStack, Controls.Scrap,
	function( Create ) -- createAllItems( Create )
		for city in g_activePlayer:Cities() do
			Create( city, city:GetID() )
		end
	end,
	UpdateCity, -- initItem( item, instance )
	{-- the callback function table names need to match associated instance control ID defined in xml
		[Mouse.eLClick] = function( cityID )
			local city = g_activePlayer:GetCityByID( cityID )
			if city then
				DoSelectCityAtPlot( city:Plot() )
			end
		end,
		[Mouse.eRClick] = function( cityID )
			local city = g_activePlayer:GetCityByID( cityID )
			if city then
				lookAtPlot( city:Plot() )
			end
		end,
	},--/city callbacks
	{
		Button = "EUI_CityProductionTooltip",
		CityPopulation = "EUI_CityGrowthTooltip",
--		CityProduction = "EUI_CityProductionTooltip",
--		BuildMeter = "EUI_ItemTooltip",
--		GrowthMeter = "EUI_ItemTooltip",
		CityIsCapital = "EUI_ItemTooltip",
		CityIsPuppet = "EUI_ItemTooltip",
		CityIsOccupied = "EUI_ItemTooltip",
		CityIsResistance = "EUI_ItemTooltip",
		CityIsRazing = "EUI_ItemTooltip",
		CityIsConnected = "EUI_ItemTooltip",
		CityIsBlockaded = "EUI_ItemTooltip",
		CityReligion = "EUI_ItemTooltip",
		CityFocus = "EUI_ItemTooltip",
		CityGrowth = "EUI_ItemTooltip",
		CityQuests = "EUI_ItemTooltip",
		BuildGrowth = "EUI_ItemTooltip",
		BorderGrowth = "EUI_ItemTooltip",
	},
	function( button )
		return g_activePlayer:GetCityByID( button:GetVoid1() )
	end,
	LuaEvents.CityToolTips.Call
)--/city ribbon object
--==========================================================

--[[ 
 _   _       _ _     ____                  _ 
| | | |_ __ (_) |_  |  _ \ __ _ _ __   ___| |
| | | | '_ \| | __| | |_) / _` | '_ \ / _ \ |
| |_| | | | | | |_  |  __/ (_| | | | |  __/ |
 \___/|_| |_|_|\__| |_|   \__,_|_| |_|\___|_|
]]

local g_screenWidth , g_screenHeight = UIManager:GetScreenSizeVal()
local g_topOffset0 = Controls.CityPanel:GetOffsetY()
local g_topOffset = g_topOffset0
local g_bottomOffset0 = Controls.UnitPanel:GetOffsetY()
local g_bottomOffset = g_bottomOffset0

local g_Actions = {}
local g_Promotions = {}
local g_UnusedControls = Controls.Scrap

local g_lastUnit		-- Used to determine if a different unit has been selected.
local g_isWorkerActionPanelOpen = false

local g_unitPortraitSize = Controls.UnitPortrait:GetSizeX()

local g_actionButtonSpacing = OptionsManager.GetSmallUIAssets() and 42 or 58

--[[
local g_actionIconSize = OptionsManager.GetSmallUIAssets() and 36 or 50
local g_recommendedActionButton = {}
ContextPtr:BuildInstanceForControlAtIndex( "UnitAction", g_recommendedActionButton, Controls.WorkerActionStack, 1 )
--Controls.RecommendedActionLabel:ChangeParent( g_recommendedActionButton.UnitActionButton )
local g_existingBuild = {}
ContextPtr:BuildInstanceForControl( "UnitAction", g_existingBuild, Controls.WorkerActionStack )
g_existingBuild.WorkerProgressBar:SetPercent( 1 )
g_existingBuild.UnitActionButton:SetDisabled( true )
g_existingBuild.UnitActionButton:SetAlpha( 0.8 )
--]]

--==========================================================
-- Event Handlers
--==========================================================

local function OnUnitActionClicked( actionID )
	local action = GameInfoActions[actionID]
	if action and g_activePlayer:IsTurnActive() then
		Game.HandleAction( actionID )
		if action.SubType == ActionSubTypes.ACTIONSUBTYPE_PROMOTION then
			Events.AudioPlay2DSound("AS2D_INTERFACE_UNIT_PROMOTION")
		end
	end
end

Controls.CycleLeft:RegisterCallback( Mouse.eLClick,
function()
	-- Cycle to next selection.
	Game.CycleUnits(true, true, false)
end)

Controls.CycleRight:RegisterCallback( Mouse.eLClick,
function()
	-- Cycle to previous selection.
	Game.CycleUnits(true, false, false)
end)

local function OnUnitNameClicked()
	-- go to this unit
	lookAtUnit( GetHeadSelectedUnit() )
end
Controls.UnitNameButton:RegisterCallback( Mouse.eLClick, OnUnitNameClicked )

do
	local UnitToolTipCall = LuaEvents.UnitToolTip.Call
	Controls.UnitPortraitButton:SetToolTipCallback( function( control )
		control:SetToolTipCallback( function() return UnitToolTipCall( GetHeadSelectedUnit(), L"TXT_KEY_CURRENTLY_SELECTED_UNIT", "----------------" ) end )
		control:SetToolTipType( "EUI_UnitTooltip" )
	end)
end
Controls.UnitPortraitButton:RegisterCallback( Mouse.eLClick, OnUnitNameClicked )

Controls.UnitPortraitButton:RegisterCallback( Mouse.eRClick,
function()
	local unit = GetHeadSelectedUnit()
	Events.SearchForPediaEntry( unit and unit:GetNameKey() )
end)

local function OnEditNameClick()

	if GetHeadSelectedUnit() then
		Events.SerialEventGameMessagePopup{
				Type = ButtonPopupTypes.BUTTONPOPUP_RENAME_UNIT,
				Data1 = GetHeadSelectedUnit():GetID(),
				Data2 = -1,
				Data3 = -1,
				Option1 = false,
				Option2 = false
			}
	end
end
Controls.EditButton:RegisterCallback( Mouse.eLClick, OnEditNameClick )
Controls.UnitNameButton:RegisterCallback( Mouse.eRClick, OnEditNameClick )

--==========================================================
-- Utilities
--==========================================================
local function ResizeCityUnitRibbons()
--debug_print("ResizeCityUnitRibbons" )
	local maxTotalStackHeight = g_screenHeight - g_topOffset - g_bottomOffset
	local halfTotalStackHeight = floor(maxTotalStackHeight / 2)

	Controls.CityStack:CalculateSize()
	local cityStackHeight = Controls.CityStack:GetSizeY()
	Controls.UnitStack:CalculateSize()
	local unitStackHeight = Controls.UnitStack:GetSizeY()

	if unitStackHeight + cityStackHeight <= maxTotalStackHeight then
		unitStackHeight = false
		halfTotalStackHeight = false
	elseif cityStackHeight <= halfTotalStackHeight then
		unitStackHeight = maxTotalStackHeight - cityStackHeight
		halfTotalStackHeight = false
	elseif unitStackHeight <= halfTotalStackHeight then
		cityStackHeight = maxTotalStackHeight - unitStackHeight
		unitStackHeight = false
	else
		cityStackHeight = halfTotalStackHeight
		unitStackHeight = halfTotalStackHeight
	end

	Controls.CityScrollPanel:SetHide( not halfTotalStackHeight )
	if halfTotalStackHeight then
		Controls.CityStack:ChangeParent( Controls.CityScrollPanel )
		Controls.CityScrollPanel:SetSizeY( cityStackHeight )
		Controls.CityScrollPanel:CalculateInternalSize()
	else
		Controls.CityStack:ChangeParent( Controls.CityPanel )
	end
	Controls.CityPanel:ReprocessAnchoring()
	Controls.DarkBorders:SetSizeY( cityStackHeight+g_topOffset )
--		Controls.CityPanel:SetSizeY( cityStackHeight )

	Controls.UnitScrollPanel:SetHide( not unitStackHeight )
	if unitStackHeight then
		Controls.UnitStack:ChangeParent( Controls.UnitScrollPanel )
		Controls.UnitScrollPanel:SetSizeY( unitStackHeight )
		Controls.UnitScrollPanel:CalculateInternalSize()
	else
		Controls.UnitStack:ChangeParent( Controls.UnitPanel )
	end
	Controls.UnitPanel:ReprocessAnchoring()
end

local function UpdateUnits()
	local activePlayer = g_activePlayer
	for unitID, instance in pairs( g_units ) do
		UpdateUnit( activePlayer:GetUnitByID( unitID ), instance )
	end
end

local function UpdateCities()
	local activePlayer = g_activePlayer
	for cityID, instance in pairs( g_cities ) do
		UpdateCity( activePlayer:GetCityByID( cityID ), instance )
	end
end

local function UpdateSpecificCity( playerID, cityID )
	if playerID == g_activePlayerID then
		UpdateCity( g_activePlayer:GetCityByID( cityID ), g_cities[cityID] )
	end
end

local function SelectUnitType( isChecked, unitTypeID ) -- Void2, control )
	g_ActivePlayerUnitsInRibbon[ unitTypeID ] = isChecked
	g_unitsIM.Initialize( g_isHideUnitList )
	ResizeCityUnitRibbons()
	-- only save player 0 preferences, not other hotseat player's
	if g_activePlayerID == 0 then
		UserInterfaceSettings[ "RIBBON_"..GameInfo_Units[ unitTypeID ].Type] = isChecked and 1 or 0
	end
end
local function ResizeUnitTypesPanel()
--		if not g_isHideUnitTypes then
	local n = Controls.UnitTypesStack:GetNumChildren()
	Controls.UnitTypesStack:SetWrapWidth( ceil( n / ceil( n / 5 ) ) * 64 )
	Controls.UnitTypesStack:CalculateSize()
	local x, y = Controls.UnitTypesStack:GetSizeVal()
	if y<64 then y=64 elseif y>320 then y=320 end
	Controls.UnitTypesPanel:SetSizeVal( x+40, y+85 )
	Controls.UnitTypesScrollPanel:SetSizeVal( x, y )
	Controls.UnitTypesScrollPanel:CalculateInternalSize()
	Controls.UnitTypesScrollPanel:ReprocessAnchoring()
end
local function AddUnitType( unit, unitID )
	local unitTypeID = unit:GetUnitType()
	g_ActivePlayerUnitTypes[ unitID or unit:GetID() ] = unitTypeID
	local instance = g_unitTypes[ unitTypeID ]
	if instance then
--debug_print( "Add unit:", unit:GetID(), unit:GetName(), "type:", instance, unitTypeID, "count:", n )
		return instance.Count:SetText( instance.Count:GetText()+1 )
	else
--debug_print( "Add unit:", unit:GetID(), unit:GetName(), "new type:", unitTypeID )
		g_unitTypesIM.Create( unit, unitTypeID, -g_UnitTypeOrder[unitTypeID] )
		if unitID then
			Controls.UnitTypesStack:SortChildren( SortByVoid2 )
			return ResizeUnitTypesPanel()
		end
	end
end
--==========================================================
-- Unit Options "Object"
--==========================================================
g_unitTypesIM, g_unitTypes = g_RibbonManager( "UnitTypeInstance", Controls.UnitTypesStack, Controls.Scrap,
	function() -- createAllItems
		g_ActivePlayerUnitTypes = {}
		for unit in g_activePlayer:Units() do
			AddUnitType( unit )
		end
		Controls.UnitTypesStack:SortChildren( SortByVoid2 )
		return ResizeUnitTypesPanel()
	end,
	function( unit, instance ) -- initItem( item, instance )
		local portrait = instance.Portrait
		local portraitOffset, portraitAtlas = GetUnitPortraitIcon( unit )
		portrait:SetHide(not ( portraitOffset and portraitAtlas and IconHookup( portraitOffset, portrait:GetSizeX(), portraitAtlas, portrait ) ) )
		instance.CheckBox:RegisterCheckHandler( SelectUnitType )
		local unitTypeID = unit:GetUnitType()
		instance.CheckBox:SetCheck( g_ActivePlayerUnitsInRibbon[ unitTypeID ] )
		instance.CheckBox:SetVoid1( unitTypeID )
		instance.Count:SetText("1")
	end,
	{-- the callback function table names need to match associated instance control ID defined in xml
		[Mouse.eRClick] = function( unitTypeID )
			local unit = GameInfo.Units[ unitTypeID ]
			if unit then
				Events.SearchForPediaEntry( unit.Description )
			end
		end,
	},--/unit options callbacks
	{-- the tooltip function names need to match associated instance control ID defined in xml
		Button = "EUI_ItemTooltip",
	},--/units options tooltips
	function( button )
		return button:GetVoid1()
	end,
	LuaEvents.UnitPanelItemTooltip.Call
)--/unit options object

local function CreateUnit( playerID, unitID ) --hexVec, unitType, cultureType, civID, primaryColor, secondaryColor, unitFlagIndex, fogState, selected, military, notInvisible )
	if playerID == g_activePlayerID then
		local unit = g_activePlayer:GetUnitByID( unitID )
--debug_print("Create unit", unitID, unit and unit:GetName() )
		if unit then
			AddUnitType( unit, unitID )
			if FilterUnit( unit ) then
				g_unitsIM.Create( unit, unitID, g_UnitTypeOrder[unit:GetUnitType()] + unitID % 65536 )
				Controls.UnitStack:SortChildren( SortByVoid2 )
				return ResizeCityUnitRibbons()
			end
		end
	end
end

local function CreateCity( hexPos, playerID, cityID ) --, cultureType, eraType, continent, populationSize, size, fowState )
	if playerID == g_activePlayerID then
		g_citiesIM.Create( g_activePlayer:GetCityByID( cityID ), cityID )
		return ResizeCityUnitRibbons()
	end
end

local function DestroyUnit( playerID, unitID )
	if playerID == g_activePlayerID then
		g_unitsIM.Destroy( unitID )
		local unitTypeID = g_ActivePlayerUnitTypes[ unitID ]
		local instance = g_unitTypes[ unitTypeID ]
--debug_print( "Destroy unit", unitID, "type:", g_ActivePlayerUnitTypes[ unitID ], instance, "previous count:", instance.Count )
		g_ActivePlayerUnitTypes[ unitID ] = nil
		if instance then
			local n = instance.Count:GetText() - 1
			if n <= 0 then
				g_unitTypesIM.Destroy( unitTypeID )
				ResizeUnitTypesPanel()
			else
				instance.Count:SetText( n )
			end
		end
		return ResizeCityUnitRibbons()
	end
end

local function DestroyCity( hexPos, playerID, cityID )
	if playerID == g_activePlayerID then
		g_citiesIM.Destroy( cityID )
		return ResizeCityUnitRibbons()
	end
end


local function SetHide( ... )
	for _, control in pairs{...} do
		control:SetHide( true )
	end
end

local function SetShow( ... )
	for _, control in pairs{...} do
		control:SetHide( false )
	end
end

local function SetTextAndFontSize( control, text, x )
	control:SetText( text )
	for i = 24, 14, -2 do
		control:SetFontByName( "TwCenMT"..i )
		if control:GetSizeVal() <= x then
			break
		end
	end
end

local function DeselectLastUnit( unit )
	if g_lastUnit then
		local lastUnitID = g_lastUnit:GetID()
		Events.UnitSelectionChanged( g_lastUnit:GetOwner(), lastUnitID, 0, 0, 0, false, false )
		local instance = g_units[ lastUnitID ]
		if instance then
			instance.MovementPip:SetToBeginning()
			UpdateUnit( g_lastUnit, instance )
		end
	end
	g_lastUnit = unit
end

local g_infoSource = {
		[ ActionSubTypes.ACTIONSUBTYPE_PROMOTION or -1 ] = GameInfo.UnitPromotions,
		[ ActionSubTypes.ACTIONSUBTYPE_INTERFACEMODE or -1 ] = GameInfo.InterfaceModes,
		[ ActionSubTypes.ACTIONSUBTYPE_MISSION or -1 ] = GameInfo.Missions,
		[ ActionSubTypes.ACTIONSUBTYPE_COMMAND or -1 ] = GameInfo.Commands,
		[ ActionSubTypes.ACTIONSUBTYPE_AUTOMATE or -1 ] = GameInfo.Automates,
		[ ActionSubTypes.ACTIONSUBTYPE_BUILD or -1 ] = GameInfo.Builds,
		[ ActionSubTypes.ACTIONSUBTYPE_CONTROL or -1 ] = GameInfo.Controls,
		[-1] = nil
}

local UnitActionToolTipCall = LuaEvents.UnitActionToolTip.Call
local function UnitActionToolTip( button )
	button:SetToolTipCallback( UnitActionToolTipCall )
	button:SetToolTipType( "EUI_UnitAction" )
end

local function UpdateUnitPanel()
	-- Retrieve the currently selected unit.
	local unit = GetHeadSelectedUnit()
-- Events.GameplayAlertMessage( "SerialEventUnitInfoDirty, GetHeadSelectedUnit=".. tostring(unit and unit:GetName())..", last unit="..tostring(g_lastUnit and g_lastUnit:GetName()) )
--debug_print( "UpdateUnitPanel", "GetHeadSelectedCity", GetHeadSelectedCity() and  GetHeadSelectedCity():GetName(), "GetHeadSelectedUnit", GetHeadSelectedUnit()and GetHeadSelectedUnit():GetName(), "Last unit", g_lastUnit and g_lastUnit:GetName() )
	if unit then
		local unitID = unit:GetID()
		-- Selected Unit
		if unit ~= g_lastUnit then
			DeselectLastUnit( unit )
			local hexPosition = ToHexFromGrid{ x = unit:GetX(), y = unit:GetY() }
			Events.UnitSelectionChanged( unit:GetOwner(), unitID, hexPosition.x, hexPosition.y, 0, true, false )
		end
		local unitMovesLeft = unit:MovesLeft() / MOVE_DENOMINATOR
		local unitPlot = unit:GetPlot()

		-- Unit Name
		SetTextAndFontSize( Controls.UnitName, ToUpper( L( unit:IsGreatPerson() and unit:HasName() and unit:GetNameNoDesc() or unit:GetName() ) ), Controls.UnitNameButton:GetSizeVal()-50 )

		-- Unit Actions
		local canPromote = unit:IsPromotionReady()
		local GameCanHandleAction = Game.CanHandleAction
		local numBuildActions = 0
		local action, instance, button, buildTurnsLeft, buildProgress, buildTime, canBuild, isBuildRecommended

		for actionID = 0, #GameInfoActions do
			action = GameInfoActions[ actionID ]
			if action and action.Visible ~= false then
				instance = g_Actions[ actionID ]
				if GameCanHandleAction( actionID, unitPlot, true ) then
					if instance then
						button = instance.UnitActionButton
					else
						instance = {}
						instance.isBuild = action.SubType == ActionSubTypes.ACTIONSUBTYPE_BUILD
						instance.isBuildType = instance.isBuild or action.Type == "INTERFACEMODE_ROUTE_TO" or action.Type == "AUTOMATE_BUILD"
						instance.isPromotion = action.SubType == ActionSubTypes.ACTIONSUBTYPE_PROMOTION
						instance.isException = instance.isPromotion or action.Type == "COMMAND_CANCEL" or action.Type == "COMMAND_STOP_AUTOMATION"
						instance.recommendation = (bnw_mode and (L"TXT_KEY_UPANEL_RECOMMENDED" .. "[NEWLINE]") or "") .. L( tostring( action.TextKey or action.Type ) )
						if action.Type == "MISSION_FOUND" then
							instance.UnitActionButton = Controls.BuildCityButton
						else
							ContextPtr:BuildInstanceForControl( "UnitAction", instance, g_UnusedControls )
							instance.WorkerProgressBar:SetHide( not instance.isBuild )
							local info = ( g_infoSource[ action.SubType ] or {} )[ action.Type ]
							if info then
								instance.IconIndex = info.IconIndex or info.PortraitIndex
								instance.IconAtlas = info.IconAtlas
								IconHookup( instance.IconIndex, instance.UnitActionIcon:GetSizeX(), instance.IconAtlas, instance.UnitActionIcon )
							end
						end
						button = instance.UnitActionButton
						button:RegisterCallback( Mouse.eLClick, OnUnitActionClicked )
						button:SetVoid1( actionID )
						button:SetToolTipCallback( UnitActionToolTip )
						instance.ID = actionID
						g_Actions[ actionID ] = instance
					end
					if unitMovesLeft > 0 or instance.isException then
						if instance.isPromotion then
							numBuildActions = numBuildActions + 1
							button:ChangeParent( Controls.WorkerActionStack )

						elseif instance.isBuildType and not canPromote then
							numBuildActions = numBuildActions + 1
							if unitMovesLeft > 0 and not isBuildRecommended and unit:IsActionRecommended( actionID ) then
								isBuildRecommended = true
								button:ChangeParent( Controls.RecommendedActionIcon )
								Controls.RecommendedActionLabel:SetText( instance.recommendation )
							else
								button:ChangeParent( Controls.WorkerActionStack )
							end
							if instance.isBuild then
								canBuild = true
								buildTurnsLeft, buildProgress, buildTime = GetUnitBuildProgressData( unitPlot, action.MissionData, unit )
								instance.WorkerProgressBar:SetPercent( buildProgress / buildTime )
								instance.UnitActionText:SetText( buildTurnsLeft > 0 and buildTurnsLeft or nil )
							end
						else
							button:ChangeParent( Controls.ActionStack )
						end
						-- test w/o visible flag (ie can train right now)
						if GameCanHandleAction( actionID, unitPlot, false ) then
							button:SetAlpha( 1.0 )
							button:SetDisabled( false )
						else
							button:SetAlpha( 0.6 )
							button:SetDisabled( true )
						end
						instance.isVisible = true
					elseif instance.isVisible then
						button:ChangeParent( g_UnusedControls )
						instance.isVisible = false
					end
				elseif instance and instance.isVisible then
					instance.UnitActionButton:ChangeParent( g_UnusedControls )
					instance.isVisible = false
				end
			end -- action.Visible
		end -- GameInfoActions loop

		if numBuildActions > 0 or canPromote then
			Controls.WorkerActionPanel:SetHide( false )
			g_isWorkerActionPanelOpen = true
			Controls.RecommendedAction:SetHide( not isBuildRecommended )
--[[
			local improvement = canBuild and not canPromote and GameInfo.Improvements[ unitPlot:GetImprovementType() ]
			local build = improvement and GameInfo_Builds{ ImprovementType = improvement.Type }()
			if build then
				numBuildActions = numBuildActions + 1
				IconHookup( build.IconIndex, g_actionIconSize, build.IconAtlas, g_existingBuild.UnitActionIcon )
			end
			g_existingBuild.UnitActionButton:SetHide( not build )
--]]
			Controls.WorkerText:SetHide( canPromote )
			Controls.PromotionText:SetHide( not canPromote )
			Controls.PromotionAnimation:SetHide( not canPromote )
			Controls.EditButton:SetHide( not canPromote )
			Controls.WorkerActionStack:SetWrapWidth( isBuildRecommended and 232 or ceil( numBuildActions / ceil( numBuildActions / 5 ) ) * g_actionButtonSpacing )
			Controls.WorkerActionStack:CalculateSize()
			local x, y = Controls.WorkerActionStack:GetSizeVal()
			Controls.WorkerActionPanel:SetSizeVal( max( x, 200 ) + 50, y + 96 )
			Controls.WorkerActionStack:ReprocessAnchoring()
		else
			Controls.WorkerActionPanel:SetHide( true )
			g_isWorkerActionPanelOpen = false
		end

		-- Unit XP
		if unit:IsCombatUnit() or unit:CanAirAttack() then
			local iLevel = unit:GetLevel()
			local iExperience = unit:GetExperience()
			local iExperienceNeeded = unit:ExperienceNeeded()
			Controls.XPMeter:LocalizeAndSetToolTip( "TXT_KEY_UNIT_EXPERIENCE_INFO", iLevel, iExperience, iExperienceNeeded )
			Controls.XPMeter:SetPercent( iExperience / iExperienceNeeded )
			Controls.XPFrame:SetHide( false )
		else
			Controls.XPFrame:SetHide( true )
		end

		-- Unit Flag
		local flagOffset, flagAtlas = GetUnitFlagIcon( unit )
		IconHookup( flagOffset, 32, flagAtlas, Controls.UnitIcon )
		IconHookup( flagOffset, 32, flagAtlas, Controls.UnitIconShadow )

		-- Unit Portrait
		local portraitOffset, portraitAtlas = GetUnitPortraitIcon( unit )
		IconHookup( portraitOffset, g_unitPortraitSize, portraitAtlas, Controls.UnitPortrait )

		-- Unit Promotions
		for promotion in GameInfo.UnitPromotions() do
			if promotion.ShowInUnitPanel ~= false then
				instance = g_Promotions[ promotion.ID ]
				if unit:IsHasPromotion( promotion.ID ) then
					if instance then
						instance.EarnedPromotion:ChangeParent( Controls.EarnedPromotionStack )
					else
						instance = {}
						ContextPtr:BuildInstanceForControl( "EarnedPromotionInstance", instance, Controls.EarnedPromotionStack )
						IconHookup( promotion.PortraitIndex, 32, promotion.IconAtlas, instance.UnitPromotionImage )
						instance.EarnedPromotion:SetToolTipString( ( promotion._Name or "???" ) .. "[NEWLINE][NEWLINE]" .. L(promotion.Help or "???") )
						g_Promotions[ promotion.ID ] = instance
					end
					instance.isVisible = true
				elseif instance and instance.isVisible then
					instance.EarnedPromotion:ChangeParent( g_UnusedControls )
					instance.isVisible = false
				end
			end
		end

		-- Unit Movement
		if unit:GetDomainType() == DomainTypes.DOMAIN_AIR then
			local unitRange = unit:Range()
			Controls.UnitStatMovement:SetText( unitRange .. "[ICON_MOVES]" )
			Controls.UnitStatMovement:LocalizeAndSetToolTip( "TXT_KEY_UPANEL_UNIT_MAY_STRIKE_REBASE", unitRange, unitRange * AIR_UNIT_REBASE_RANGE_MULTIPLIER / 100 )
		else
			local text = format(" %.3g/%g[ICON_MOVES]", unitMovesLeft, unit:MaxMoves() / MOVE_DENOMINATOR )
			Controls.UnitStatMovement:SetText( text )
			Controls.UnitStatMovement:LocalizeAndSetToolTip( "TXT_KEY_UPANEL_UNIT_MAY_MOVE", text )
		end

		-- Unit Strength
		local strength = ( unit:GetDomainType() == DomainTypes.DOMAIN_AIR and unit:GetBaseRangedCombatStrength() )
						or ( not unit:IsEmbarked() and unit:GetBaseCombatStrength() ) or 0
		if strength > 0 then
			Controls.UnitStatStrength:SetText( strength .. "[ICON_STRENGTH]" )
			Controls.UnitStatStrength:LocalizeAndSetToolTip( "TXT_KEY_UPANEL_STRENGTH_TT" )
		elseif gk_mode and unit:GetSpreadsLeft() > 0 then
			-- Religious units
			Controls.UnitStatStrength:SetText( floor(unit:GetConversionStrength()/RELIGION_MISSIONARY_PRESSURE_MULTIPLIER) .. "[ICON_PEACE]" )
			Controls.UnitStatStrength:LocalizeAndSetToolTip( "TXT_KEY_UPANEL_RELIGIOUS_STRENGTH_TT" )
		elseif bnw_mode and unit:GetTourismBlastStrength() > 0 then
			Controls.UnitStatStrength:SetText( unit:GetTourismBlastStrength() .. "[ICON_TOURISM]" )
			Controls.UnitStatStrength:LocalizeAndSetToolTip( "TXT_KEY_UPANEL_TOURISM_STRENGTH_TT" )
		else
			Controls.UnitStatStrength:SetText()
		end

		-- Ranged Strength
		local rangedStrength = unit:GetDomainType() ~= DomainTypes.DOMAIN_AIR and unit:GetBaseRangedCombatStrength() or 0
		if rangedStrength > 0 then
			Controls.UnitStatRangedAttack:SetText( rangedStrength .. "[ICON_RANGE_STRENGTH]" .. unit:Range() )
			Controls.UnitStatRangedAttack:LocalizeAndSetToolTip( "TXT_KEY_UPANEL_RANGED_ATTACK_TT" )
		elseif gk_mode and unit:GetSpreadsLeft() > 0 then
			-- Religious units
			local unitReligion = unit:GetReligion()
			local icon = (GameInfo.Religions[unitReligion] or {}).IconString
			Controls.UnitStatRangedAttack:SetText( icon and (unit:GetSpreadsLeft()..icon) )
			Controls.UnitStatRangedAttack:SetToolTipString( L(Game.GetReligionName(unitReligion))..": "..L"TXT_KEY_UPANEL_SPREAD_RELIGION_USES_TT" )
--		elseif gk_mode and GameInfo_Units[unit:GetUnitType()].RemoveHeresy then
--			Controls.UnitStatRangedAttack:LocalizeAndSetText( "TXT_KEY_UPANEL_REMOVE_HERESY_USES" )
--			Controls.UnitStatRangedAttack:LocalizeAndSetToolTip( "TXT_KEY_UPANEL_REMOVE_HERESY_USES_TT" )
		elseif bnw_mode and unit:CargoSpace() > 0 then
			Controls.UnitStatRangedAttack:SetText( L"TXT_KEY_UPANEL_CARGO_CAPACITY" .. " " .. unit:CargoSpace() )
			Controls.UnitStatRangedAttack:LocalizeAndSetToolTip( "TXT_KEY_UPANEL_CARGO_CAPACITY_TT", unit:GetName() )
		else
			Controls.UnitStatRangedAttack:SetText()
		end
		Controls.UnitStats:CalculateSize()
		Controls.UnitStats:ReprocessAnchoring()

		-- Unit Health Bar
		local damage = unit:GetDamage()
		if damage ~= 0 then
			local healthPercent = 1.0 - (damage / MAX_HIT_POINTS)
			local barSize = 123 * healthPercent
			if healthPercent <= .33 then
				Controls.RedBar:SetSizeY(barSize)
				Controls.RedAnim:SetSizeY(barSize)
				Controls.GreenBar:SetHide(true)
				Controls.YellowBar:SetHide(true)
				Controls.RedBar:SetHide(false)
			elseif healthPercent <= .66 then
				Controls.YellowBar:SetSizeY(barSize)
				Controls.GreenBar:SetHide(true)
				Controls.YellowBar:SetHide(false)
				Controls.RedBar:SetHide(true)
			else
				Controls.GreenBar:SetSizeY(barSize)
				Controls.GreenBar:SetHide(false)
				Controls.YellowBar:SetHide(true)
				Controls.RedBar:SetHide(true)
			end
			Controls.HealthBar:LocalizeAndSetToolTip( "TXT_KEY_UPANEL_SET_HITPOINTS_TT", MAX_HIT_POINTS-damage, MAX_HIT_POINTS )
			Controls.HealthBar:SetHide(false)
		else
			Controls.HealthBar:SetHide(true)
		end

		-- Unit Stats
		UpdateUnit( unit, Controls, g_units[ unitID ] )

		Controls.UnitStatBox:SetHide( bnw_mode and unit:IsTrade() )

		-- These controls need to be shown since potentially hidden depending on previous selection
		SetShow( Controls.EarnedPromotionStack, Controls.UnitTypeFrame, Controls.CycleLeft, Controls.CycleRight, Controls.ActionStack )
		Controls.ActionStack:CalculateSize()
		Controls.ActionStack:ReprocessAnchoring()

	else
		-- Deselect last unit, if any
		DeselectLastUnit()
		-- Attempt to show currently selected city
		unit = GetHeadSelectedCity()
		if unit then
			-- City Name
			SetTextAndFontSize( Controls.UnitName, ToUpper( L(unit:GetName()) ), Controls.UnitNameButton:GetSizeVal()-50 )

			-- City Portrait
			IconHookup( 0, g_unitPortraitSize, "CITY_ATLAS", Controls.UnitPortrait )

			-- Hide various aspects of Unit Panel since they don't apply to the city.
			SetHide( Controls.EarnedPromotionStack, Controls.UnitTypeFrame, Controls.CycleLeft, Controls.CycleRight, Controls.XPFrame, Controls.UnitStatBox, Controls.WorkerActionPanel, Controls.ActionStack )
			g_isWorkerActionPanelOpen = false
		end
	end
	if (not unit) ~= Controls.Panel:IsHidden() then
		if unit then
			g_bottomOffset = g_bottomOffset0
			Controls.UnitTypesPanel:SetOffsetVal( g_unitPortraitSize * 0.625, 120 )
		else
			g_bottomOffset = 35
			Controls.UnitTypesPanel:SetOffsetVal( 80, -40 )
		end
		Controls.Panel:SetHide( not unit )
		Controls.Actions:SetHide( not unit )
		Controls.UnitPanel:SetOffsetY( g_bottomOffset )
		ResizeCityUnitRibbons()
	end
end

local function UpdateOptions()

	local option = UserInterfaceSettings.UnitTypes == 0
	if g_isHideUnitTypes ~= option then
		g_unitTypesIM.Initialize( option )
		ResizeUnitTypesPanel()
		g_isHideUnitTypes = option
		Controls.UnitTypesOpen:SetHide( option )
		Controls.UnitTypesClose:SetHide( not option )
	end

	option = UserInterfaceSettings.UnitRibbon == 0
	if g_isHideUnitList ~= option then
		g_isHideUnitList = option
		local AddOrRemove = option and "Remove" or "Add"
		Events.SerialEventUnitCreated[ AddOrRemove ]( CreateUnit )
		Events.SerialEventUnitDestroyed[ AddOrRemove ]( DestroyUnit )
		Events.ActivePlayerTurnStart[ AddOrRemove ]( UpdateUnits )
	end
	g_unitsIM.Initialize( option )
	Controls.UnitPanel:SetHide( option )
	Controls.UnitTypesPanel:SetHide( option or g_isHideUnitTypes )

	option = UserInterfaceSettings.CityRibbon == 0
	if g_isHideCityList ~= option then
		g_isHideCityList = option
		local AddOrRemove = option and "Remove" or "Add"
		Events.SerialEventCityCreated[ AddOrRemove ]( CreateCity )
		Events.SerialEventCityDestroyed[ AddOrRemove ]( DestroyCity )
		Events.SerialEventCityCaptured[ AddOrRemove ]( DestroyCity )
		Events.SerialEventCityInfoDirty[ AddOrRemove ]( UpdateCities )
		Events.SerialEventCitySetDamage[ AddOrRemove ]( UpdateSpecificCity )
		Events.SpecificCityInfoDirty[ AddOrRemove ]( UpdateSpecificCity )
	end
	g_citiesIM.Initialize( option )
	Controls.CityPanel:SetHide( option )
	Controls.DarkBorders:SetHide( option )

	UpdateUnitPanel()
	ResizeCityUnitRibbons()
end

Controls.UnitTypesButton:RegisterCallback( Mouse.eLClick,
function()
	UserInterfaceSettings.UnitTypes = g_isHideUnitTypes and 1 or 0
	return UpdateOptions()
end)

local function SetActivePlayer()-- activePlayerID, prevActivePlayerID )
	-- initialize globals
	if g_activePlayerID then
		g_AllPlayerOptions.UnitTypes[ g_activePlayerID ] = g_ActivePlayerUnitTypes
		g_AllPlayerOptions.UnitsInRibbon[ g_activePlayerID ] = g_ActivePlayerUnitsInRibbon
	end
	g_activePlayerID = Game.GetActivePlayer()
	g_activePlayer = Players[ g_activePlayerID ]
	g_activeTeamID = g_activePlayer:GetTeam()
	g_activeTeam = Teams[ g_activeTeamID ]
	g_activeTechs = g_activeTeam:GetTeamTechs()
	g_ActivePlayerUnitTypes = g_AllPlayerOptions.UnitTypes[ g_activePlayerID ] or {}
	g_ActivePlayerUnitsInRibbon = g_AllPlayerOptions.UnitsInRibbon[ g_activePlayerID ]
	if not g_ActivePlayerUnitsInRibbon then
		g_ActivePlayerUnitsInRibbon = {}
		for row in GameInfo.Units() do
			g_ActivePlayerUnitsInRibbon[ row.ID ] = UserInterfaceSettings[ "RIBBON_"..row.Type ] ~= 0
		end
	end

	-- set civilization icon and color
	local civInfo = GameInfo.Civilizations[ g_activePlayer:GetCivilizationType() ] or {}
	IconHookup( civInfo.PortraitIndex, 128, civInfo.IconAtlas, Controls.BackgroundCivSymbol )
	Controls.UnitIcon:SetColor( PrimaryColors[ g_activePlayerID ] )
	Controls.UnitIconBackground:SetColor( BackgroundColors[ g_activePlayerID ] )

	return UpdateOptions()
end

SetActivePlayer()
Events.GameplaySetActivePlayer.Add( SetActivePlayer )
Events.GameOptionsChanged.Add( UpdateOptions )
Events.SerialEventUnitInfoDirty.Add( UpdateUnitPanel )
--[[
Events.UnitActionChanged.Add(
function( playerID, unitID )
	if playerID == g_activePlayerID then
		local instance = g_units[ unitID ]
		if instance then
			return UpdateUnit( g_activePlayer:GetUnitByID( unitID ), instance )
		end
	end
end)
--]]
Events.SerialEventEnterCityScreen.Add(
function()
	DeselectLastUnit()
end)

local g_infoCornerYmax = {
[InfoCornerID.None or -1] = g_topOffset0,
[InfoCornerID.Tech or -1] = OptionsManager.GetSmallUIAssets() and 150 or 225,
[-1] = nil }

Events.OpenInfoCorner.Add( function( infoCornerID )
	g_topOffset = g_infoCornerYmax[infoCornerID] or 380
	Controls.CityPanel:SetOffsetY( g_topOffset )
	return UpdateOptions()
end)

--[[
Events.EndCombatSim.Add( function(
			attackerPlayerID,
			attackerUnitID,
			attackerUnitDamage,
			attackerFinalUnitDamage,
			attackerMaxHitPoints,
			defenderPlayerID,
			defenderUnitID,
			defenderUnitDamage,
			defenderFinalUnitDamage,
			defenderMaxHitPoints )
	if attackerPlayerID == g_activePlayerID then
		local instance = g_units[ attackerUnitID ]
		if instance then
			local toolTip = instance.Button:GetToolTipString()
			if toolTip then
				toolTip = toolTip .. "[NEWLINE]"
			else
				toolTip = ""
			end
			toolTip = toolTip
				.."Attack: "
				.. " / " .. tostring( attackerPlayerID )
				.. " / " .. tostring( attackerUnitID )
				.. " / " .. tostring( attackerUnitDamage )
				.. " / " .. tostring( attackerFinalUnitDamage )
				.. " / " .. tostring( attackerMaxHitPoints )
				.. " / " .. tostring( defenderPlayerID )
				.. " / " .. tostring( defenderUnitID )
				.. " / " .. tostring( defenderUnitDamage )
				.. " / " .. tostring( defenderFinalUnitDamage )
				.. " / " .. tostring( defenderMaxHitPoints )
			instance.Button:SetToolTipString( toolTip )
		end
	elseif defenderPlayerID == g_activePlayerID then
		local instance = g_units[ defenderUnitID ]
		if instance then
			local toolTip = instance.Button:GetToolTipString()
			if toolTip then
				toolTip = toolTip .. "[NEWLINE]"
			else
				toolTip = ""
			end
			toolTip = toolTip
				.."Defense: "
				.. " / " .. tostring( attackerPlayerID )
				.. " / " .. tostring( attackerUnitID )
				.. " / " .. tostring( attackerUnitDamage )
				.. " / " .. tostring( attackerFinalUnitDamage )
				.. " / " .. tostring( attackerMaxHitPoints )
				.. " / " .. tostring( defenderPlayerID )
				.. " / " .. tostring( defenderUnitID )
				.. " / " .. tostring( defenderUnitDamage )
				.. " / " .. tostring( defenderFinalUnitDamage )
				.. " / " .. tostring( defenderMaxHitPoints )
			instance.Button:SetToolTipString( toolTip )
		end
	end
end)
--]]
-- Process request to hide enemy panel
LuaEvents.EnemyPanelHide.Add(
	function( isEnemyPanelHide )
		if g_isWorkerActionPanelOpen then
			Controls.WorkerActionPanel:SetHide( not isEnemyPanelHide )
		end
		if not g_isHideUnitTypes and not g_isHideUnitList then
			Controls.UnitTypesPanel:SetHide( not isEnemyPanelHide )
		end
	end)
local EnemyUnitPanel = LookUpControl( "/InGame/WorldView/EnemyUnitPanel" )
local isHidden = ContextPtr:IsHidden()
ContextPtr:SetShowHideHandler(
	function( isHide, isInit )
		if not isInit and isHidden ~= isHide then
			isHidden = isHide
			if isHide and EnemyUnitPanel then
				EnemyUnitPanel:SetHide( true )
			end
		end
	end)
ContextPtr:SetHide( false )
Controls.DarkBorders:ChangeParent( LookUpControl( "/Ingame/WorldViewControls" ) )

end)
