--==========================================================
-- CityBannerManager
-- Re-written by bc1 using Notepad++
-- code is common using gk_mode and bnw_mode switches
--==========================================================

Events.SequenceGameInitComplete.Add(function()

include "GameInfoCache" -- warning! booleans are true, not 1, and use iterator ONLY with table field conditions, NOT string SQL query
local GameInfo = GameInfoCache

include "IconHookup"
local IconHookup = IconHookup
local CivIconHookup = CivIconHookup
local PrimaryColors = PrimaryColors
local BackgroundColors = BackgroundColors
local ColorGreen = Color( 0, 1, 0, 1 )
local ColorYellow = Color( 1, 1, 0, 1 )
local ColorRed = Color( 1, 0, 0, 1 )
local ColorCulture = Color( 1, 0, 1, 1 )

include "CityStateStatusHelper"
local GetCityStateStatusRow = GetCityStateStatusRow
local GetActiveQuestText = GetActiveQuestText

--==========================================================
-- Minor lua optimizations
--==========================================================

local ipairs = ipairs
local floor = math.floor
local max = math.max
local min = math.min
local pairs = pairs
local print = print
local insert = table.insert
local remove = table.remove
local format = string.format

local ButtonPopupTypes = ButtonPopupTypes
local CityUpdateTypes = CityUpdateTypes
local ContextPtr = ContextPtr
local Controls = Controls
local Events = Events
local EventsClearHexHighlightStyle = Events.ClearHexHighlightStyle.Call
local EventsRequestYieldDisplay = Events.RequestYieldDisplay.Call
local EventsSerialEventHexHighlight = Events.SerialEventHexHighlight.Call
local Game = Game
local GridToWorld = GridToWorld
local InStrategicView = InStrategicView
local InterfaceModeTypes = InterfaceModeTypes
local L = Locale.ConvertTextKey
local ToUpper = Locale.ToUpper
local GetPlot = Map.GetPlot
local GetPlotByIndex = Map.GetPlotByIndex
local MinorCivQuestTypes = MinorCivQuestTypes
local Mouse = Mouse
local SendUpdateCityCitizens = Network.SendUpdateCityCitizens
local IsCivilianYields = OptionsManager.IsCivilianYields
local Players = Players
local Teams = Teams
local ToGridFromHex = ToGridFromHex
local ToHexFromGrid = ToHexFromGrid
local UI = UI
local GetUnitPortraitIcon = UI.GetUnitPortraitIcon
local UnitMoving = UnitMoving
local YieldDisplayTypes = YieldDisplayTypes
local MAX_CITY_HIT_POINTS = GameDefines.MAX_CITY_HIT_POINTS
local CITY_PLOTS_RADIUS = GameDefines.CITY_PLOTS_RADIUS

--==========================================================
-- Globals
--==========================================================

local RefreshCityBanner

local gk_mode = Game.GetReligionName ~= nil
local bnw_mode = Game.GetActiveLeague ~= nil

local g_activePlayerID = Game.GetActivePlayer()
local g_activePlayer = Players[ g_activePlayerID ]
local g_activeTeamID = Game.GetActiveTeam()
local g_activeTeam = Teams[ g_activeTeamID ]

local g_cityBanners = {}
--local g_outpostBanners = {}
--local g_stationBanners = {}
local g_svStrikeButtons = {}

local g_scrapTeamBanners = {}
local g_scrapOtherBanners = {}
local g_scrapSVStrikeButtons = {}

local g_WorldPositionOffsetZ = InStrategicView and 35 or 55


local g_cityHexHighlight

--local IsCivBE = Game.GetAvailableBeliefs ~= nil
--local g_CovertOpsBannerContainer = IsCivBE and ContextPtr:LookUpControl( "../CovertOpsBannerContainer" )
--local g_CovertOpsIntelReportContainer = IsCivBE and ContextPtr:LookUpControl( "../CovertOpsIntelReportContainer" )

local g_cityFocusIcons = {
--[CityAIFocusTypes.NO_CITY_AI_FOCUS_TYPE or -1] = "",
[CityAIFocusTypes.CITY_AI_FOCUS_TYPE_FOOD or -1] = "[ICON_FOOD]",
[CityAIFocusTypes.CITY_AI_FOCUS_TYPE_PRODUCTION or -1] = "[ICON_PRODUCTION]",
[CityAIFocusTypes.CITY_AI_FOCUS_TYPE_GOLD or -1] = "[ICON_GOLD]",
[CityAIFocusTypes.CITY_AI_FOCUS_TYPE_SCIENCE or -1] = "[ICON_RESEARCH]",
[CityAIFocusTypes.CITY_AI_FOCUS_TYPE_CULTURE or -1] = "[ICON_CULTURE]",
[CityAIFocusTypes.CITY_AI_FOCUS_TYPE_GREAT_PEOPLE or -1] = "[ICON_GREAT_PEOPLE]",
[CityAIFocusTypes.CITY_AI_FOCUS_TYPE_FAITH or -1] = "[ICON_PEACE]",
} g_cityFocusIcons[-1] = nil

local g_cityFocusTooltips = {
[CityAIFocusTypes.NO_CITY_AI_FOCUS_TYPE or -1] = L"TXT_KEY_CITYVIEW_FOCUS_BALANCED_TEXT",
[CityAIFocusTypes.CITY_AI_FOCUS_TYPE_FOOD or -1] = L"TXT_KEY_CITYVIEW_FOCUS_FOOD_TEXT",
[CityAIFocusTypes.CITY_AI_FOCUS_TYPE_PRODUCTION or -1] = L"TXT_KEY_CITYVIEW_FOCUS_PROD_TEXT",
[CityAIFocusTypes.CITY_AI_FOCUS_TYPE_GOLD or -1] = L"TXT_KEY_CITYVIEW_FOCUS_GOLD_TEXT",
[CityAIFocusTypes.CITY_AI_FOCUS_TYPE_SCIENCE or -1] = L"TXT_KEY_CITYVIEW_FOCUS_RESEARCH_TEXT",
[CityAIFocusTypes.CITY_AI_FOCUS_TYPE_CULTURE or -1] = L"TXT_KEY_CITYVIEW_FOCUS_CULTURE_TEXT",
[CityAIFocusTypes.CITY_AI_FOCUS_TYPE_GREAT_PEOPLE or -1] = L"TXT_KEY_CITYVIEW_FOCUS_GREAT_PERSON_TEXT",
[CityAIFocusTypes.CITY_AI_FOCUS_TYPE_FAITH or -1] = L"TXT_KEY_CITYVIEW_FOCUS_FAITH_TEXT",
} g_cityFocusTooltips[-1] = nil

local function IsTurnActive( player )
	return player and player:IsTurnActive() and not Game.IsProcessingMessages()
end

local function BannerError( where, arg )
	if Game.IsDebugMode() then
		local txt = ""
		if arg and arg.PlotIndex then
			txt = "city banner"
			arg = arg and GetPlotByIndex(arg.PlotIndex)
		end
		if arg and arg.GetPlotCity then
			txt = "plot " .. (arg:IsCity() and "with" or "without") .. " city"
			arg = arg:GetPlotCity()
		end
		if arg and arg.GetCityPlotIndex then
			txt = "city " .. arg:GetName()
		end
		print( "glitch", where, txt, debug and debug.traceback and debug.traceback() )
	end
end

--==========================================================
-- Clear Hex Highlighting
--==========================================================

local function ClearHexHighlights()
	EventsClearHexHighlightStyle( "HexContour" )
	EventsClearHexHighlightStyle( "WorkedFill" )
	EventsClearHexHighlightStyle( "WorkedOutline" )
	EventsClearHexHighlightStyle( "OwnedFill")
	EventsClearHexHighlightStyle( "OwnedOutline" )
	EventsClearHexHighlightStyle( "CityLimits" )
	EventsClearHexHighlightStyle( "EnemyFill" )
	EventsClearHexHighlightStyle( "EnemyOutline" )
	g_cityHexHighlight = false
end

--==========================================================
-- Show/hide the garrison frame icon
--==========================================================

local function HideGarrisonFrame( instance, isHide )
	-- Only the active team has a Garrison ring
	if instance and instance[1] then
		instance.GarrisonFrame:SetHide( isHide )
	end
end

--==========================================================
-- Show/hide the range strike icon
--==========================================================

local function UpdateRangeIcons( plotIndex, city, instance )

	if city and instance then

		local hideRangeStrikeButton = city:GetOwner() ~= g_activePlayerID or not city:CanRangeStrikeNow()
		if instance.CityRangeStrikeButton then
			instance.CityRangeStrikeButton:SetHide( hideRangeStrikeButton )
		end

		instance = g_svStrikeButtons[ plotIndex ]
		if instance then
			instance.CityRangeStrikeButton:SetHide( hideRangeStrikeButton )
		end
	end
end

--==========================================================
-- Refresh the City Damage bar
--==========================================================

local function RefreshCityDamage( city, instance, cityDamage )

	if instance then

		local maxCityHitPoints = gk_mode and city and city:GetMaxHitPoints() or MAX_CITY_HIT_POINTS
		local iHealthPercent = 1 - cityDamage / maxCityHitPoints

		instance.CityBannerHealthBar:SetPercent(iHealthPercent)
		instance.CityBannerHealthBar:SetToolTipString( format("%g / %g", maxCityHitPoints - cityDamage, maxCityHitPoints) )

		---- Health bar color based on amount of damage
		local barColor = {}

		if iHealthPercent > 0.66 then
			barColor = ColorGreen
		elseif iHealthPercent > 0.33 then
			barColor = ColorYellow
		else
			barColor = ColorRed
		end
		instance.CityBannerHealthBar:SetFGColor( barColor )

		-- Show or hide the Health Bar as necessary
		instance.CityBannerHealthBarBase:SetHide( cityDamage == 0 )
	end
end

--==========================================================
-- Click On City State Quest Info
--==========================================================

local questKillCamp = MinorCivQuestTypes.MINOR_CIV_QUEST_KILL_CAMP
local IsActiveQuestKillCamp
if bnw_mode then
	IsActiveQuestKillCamp = function( minorPlayer )
		return minorPlayer and minorPlayer:IsMinorCivDisplayedQuestForPlayer( g_activePlayerID, questKillCamp )
	end
elseif gk_mode then
	IsActiveQuestKillCamp = function( minorPlayer )
		return minorPlayer and minorPlayer:IsMinorCivActiveQuestForPlayer( g_activePlayerID, questKillCamp )
	end
else
	IsActiveQuestKillCamp = function( minorPlayer )
		return minorPlayer and minorPlayer:GetActiveQuestForPlayer( g_activePlayerID ) == questKillCamp
	end
end

local function OnQuestInfoClicked( plotIndex )
	local plot = GetPlotByIndex( plotIndex )
	local city = plot and plot:GetPlotCity()
	local cityOwner = city and Players[ city:GetOwner() ]
	if cityOwner and cityOwner:IsMinorCiv() and IsActiveQuestKillCamp( cityOwner ) then
		local questData1 = cityOwner:GetQuestData1( g_activePlayerID, questKillCamp )
		local questData2 = cityOwner:GetQuestData2( g_activePlayerID, questKillCamp )
		local plot = GetPlot( questData1, questData2 )
		if plot then
			UI.LookAt( plot )
			local hex = ToHexFromGrid{ x=plot:GetX(), y=plot:GetY() }
			Events.GameplayFX( hex.x, hex.y, -1 )
		end
	end
end

local function AnnexPopup( plotIndex )
	local plot = GetPlotByIndex( plotIndex )
	local city = plot and plot:GetPlotCity()
	if city and city:GetOwner() == g_activePlayerID and not( bnw_mode and g_activePlayer:MayNotAnnex() ) then
		Events.SerialEventGameMessagePopup{
			Type = ButtonPopupTypes.BUTTONPOPUP_ANNEX_CITY,
			Data1 = city:GetID(),
			Data2 = -1,
			Data3 = -1,
			Option1 = false,
			Option2 = false
		}
	end
end

local function EspionagePopup( plotIndex )
	local plot = GetPlotByIndex( plotIndex )
	local city = plot and plot:GetPlotCity()
	if city and not Players[city:GetOwner()]:IsMinorCiv() then
		ClearHexHighlights()
		UI.SetInterfaceMode( InterfaceModeTypes.INTERFACEMODE_SELECTION )
		UI.DoSelectCityAtPlot( plot )
	else
		Events.SerialEventGameMessagePopup{ Type = ButtonPopupTypes.BUTTONPOPUP_ESPIONAGE_OVERVIEW }
	end
end

--==========================================================
-- Click on City Range Strike Button
--==========================================================

local function OnCityRangeStrikeButtonClick( plotIndex )
	local plot = GetPlotByIndex( plotIndex )
	local city = plot and plot:GetPlotCity()

	if city and city:GetOwner() == g_activePlayerID then
		UI.ClearSelectionList()
		UI.SelectCity( city )
		UI.SetInterfaceMode( InterfaceModeTypes.INTERFACEMODE_CITY_RANGE_ATTACK )
--		Events.InitCityRangeStrike( city:GetOwner(), city:GetID() )
	end
end

--==========================================================
-- Left Click on city banner
--==========================================================

local function OnBannerClick( plotIndex )
	local plot = GetPlotByIndex( plotIndex )
	local city = plot and plot:GetPlotCity()
	if city then
		UI.SetInterfaceMode( InterfaceModeTypes.INTERFACEMODE_SELECTION )
		local cityOwnerID = city:GetOwner()
		local cityOwner = Players[ cityOwnerID ]

		-- Active player city
		if cityOwnerID == g_activePlayerID then

			-- always open city screen, puppets are not that special
			ClearHexHighlights()
			UI.DoSelectCityAtPlot( plot )

		-- Observers get to look at anything
		elseif Game.IsDebugMode() or g_activePlayer:IsObserver() then
			UI.SelectCity( city )
			UI.LookAt( plot )
			UI.SetCityScreenUp( true )

		-- Other player, which has been met
		elseif g_activeTeam:IsHasMet( city:GetTeam() ) then

			if cityOwner:IsMinorCiv() then
				UI.DoSelectCityAtPlot( plot )
			elseif IsTurnActive( g_activePlayer ) then
				if cityOwner:IsHuman() then
					Events.OpenPlayerDealScreenEvent( cityOwnerID )
				elseif not cityOwner:IsBarbarian() then
					UI.SetRepeatActionPlayer( cityOwnerID )
					UI.ChangeStartDiploRepeatCount(1)
					cityOwner:DoBeginDiploWithHuman()
				end
			end
		end
	else
		BannerError( "OnBannerClick", plot )
	end
end

--==========================================================
-- Destroy City Banner
--==========================================================

local function DestroyCityBanner( plotIndex, instance )

	-- Release city banner
	if instance then
		insert( instance[1] and g_scrapTeamBanners or g_scrapOtherBanners, instance )
		g_cityBanners[ plotIndex or -1 ] = nil
		instance.Anchor:ChangeParent( Controls.Scrap )
	end

	-- Release sv strike button
	instance = g_svStrikeButtons[ plotIndex ]
	if instance then
		instance.Anchor:ChangeParent( Controls.Scrap )
		insert( g_scrapSVStrikeButtons, instance )
		g_svStrikeButtons[ plotIndex ] = nil
	end
end

--==========================================================
-- City banner mouse over
--==========================================================

local function OnBannerMouseExit()
	if not UI.IsCityScreenUp() then

		ClearHexHighlights()
		-- duplicate code from InGame.lua function RequestYieldDisplay()

		local isDisplayCivilianYields = IsCivilianYields()
		local unit = UI.GetHeadSelectedUnit()

		if isDisplayCivilianYields and UI.CanSelectionListWork() and not( unit and (GameInfo.Units[unit:GetUnitType()] or {}).DontShowYields ) then
			EventsRequestYieldDisplay( YieldDisplayTypes.EMPIRE )

		elseif isDisplayCivilianYields and UI.CanSelectionListFound() and unit then
			EventsRequestYieldDisplay( YieldDisplayTypes.AREA, 2, unit:GetX(), unit:GetY() )
		else
			EventsRequestYieldDisplay( YieldDisplayTypes.AREA, 0 )
		end
	end
end

local function OnBannerMouseEnter( plotIndex )
	local plot = GetPlotByIndex( plotIndex )
	if plot then
		local city = plot:GetPlotCity()
		g_cityHexHighlight = plotIndex
		if city and city:GetOwner() == g_activePlayerID and not( Game.IsNetworkMultiPlayer() and g_activePlayer:HasReceivedNetTurnComplete() ) then -- required to prevent turn interrupt
			SendUpdateCityCitizens( city:GetID() )
		end
		return RefreshCityBanner( city )
	end
end

local CityTooltip = LuaEvents.CityToolTips.Call
local TeamCityTooltips = {
	CityBannerButton = "EUI_ItemTooltip",
	CityBannerRightBackground = "EUI_ItemTooltip",
	BuildGrowth = "EUI_ItemTooltip",
	CityGrowth = "EUI_ItemTooltip",
--	BorderGrowth = "EUI_ItemTooltip",
	CityReligion = "EUI_ItemTooltip",
	CityFocus = "EUI_ItemTooltip",
	CityQuests = "EUI_ItemTooltip",
	CityIsPuppet = "EUI_ItemTooltip",
	CityIsRazing = "EUI_ItemTooltip",
	CityIsResistance = "EUI_ItemTooltip",
	CityResistanceTurns = "EUI_ItemTooltip",
	CityIsConnected = "EUI_ItemTooltip",
	CityIsBlockaded = "EUI_ItemTooltip",
	CityIsOccupied = "EUI_ItemTooltip",
	CityIsCapital = "EUI_ItemTooltip",
	CityIsOriginalCapital = "EUI_ItemTooltip",
	CivIndicator = "EUI_ItemTooltip",
	CityProductionBG = "EUI_CityProductionTooltip",
	CityPopulation = "EUI_CityGrowthTooltip",
}
local OtherCityTooltips = {
	CityBannerButton = "EUI_ItemTooltip",
	CityBannerRightBackground = "EUI_ItemTooltip",
--	BuildGrowth = "EUI_ItemTooltip",
--	CityGrowth = "EUI_ItemTooltip",
--	BorderGrowth = "EUI_ItemTooltip",
	CityReligion = "EUI_ItemTooltip",
--	CityFocus = "EUI_ItemTooltip",
	CityQuests = "EUI_ItemTooltip",
	CityIsPuppet = "EUI_ItemTooltip",
	CityIsRazing = "EUI_ItemTooltip",
	CityIsResistance = "EUI_ItemTooltip",
--	CityIsConnected = "EUI_ItemTooltip",
	CityIsBlockaded = "EUI_ItemTooltip",
	CityIsOccupied = "EUI_ItemTooltip",
	CityIsCapital = "EUI_ItemTooltip",
	CityIsOriginalCapital = "EUI_ItemTooltip",
	CivIndicator = "EUI_ItemTooltip",
--	CityProductionBG = "EUI_CityProductionTooltip",
--	CityPopulation = "EUI_CityGrowthTooltip",
}
local function InitBannerCallbacks( instance, tooltips )
	local button = instance.CityBannerButton
	button:RegisterCallback( Mouse.eLClick, OnBannerClick )
	button:RegisterCallback( Mouse.eMouseEnter, OnBannerMouseEnter )
	button:RegisterCallback( Mouse.eMouseExit, OnBannerMouseExit )
--	instance.CityName:SetColor( Color( 0, 0, 0, 0.5 ), 1 )	-- #1 = shadow color
--	instance.CityName:SetColor( Color( 1, 1, 1, 0.5 ), 2 )	-- #2 = soft color
	instance.CityDiplomat:RegisterCallback( Mouse.eLClick, EspionagePopup )
	instance.CitySpy:RegisterCallback( Mouse.eLClick, EspionagePopup )
	-- Setup Tootip Callbacks
	for controlID, toolTipType in pairs( tooltips ) do
		instance[ controlID ]:SetToolTipCallback( function( control )
			control:SetToolTipCallback( function( control ) return CityTooltip( control, GetPlotByIndex( button:GetVoid1() ):GetPlotCity() ) end )
			control:SetToolTipType( toolTipType )
		end)
	end
end

--==========================================================
-- Update banners to reflect latest city info
--==========================================================

function RefreshCityBanner( city )

	if city then

		local isDebug = Game.IsDebugMode() or g_activePlayer:IsObserver()
		local plot = city:Plot()
		local plotIndex = plot:GetPlotIndex()
		local instance = g_cityBanners[ plotIndex ]
		local cityOwnerID = city:GetOwner()
		local cityOwner = Players[ cityOwnerID ]
		local isActiveType = isDebug or city:GetTeam() == g_activeTeamID
		local isActivePlayerCity = cityOwnerID == g_activePlayerID

		-- Incompatible banner type ? Destroy !
		if instance and isActiveType ~= instance[1] then
			DestroyCityBanner( plotIndex, instance )
			instance = nil
		end

		---------------------
		-- Create City Banner
		if not instance then
			local worldX, worldY, worldZ = GridToWorld( plot:GetX(), plot:GetY() )
			if isActiveType then
				-- create a strike button for stategic view
				instance = remove( g_scrapSVStrikeButtons )
				if instance then
					instance.Anchor:ChangeParent( Controls.StrategicViewStrikeButtons )
				else
					instance = {}
					ContextPtr:BuildInstanceForControl( "SVRangeStrikeButton", instance, Controls.StrategicViewStrikeButtons )
					instance.CityRangeStrikeButton:RegisterCallback( Mouse.eLClick, OnCityRangeStrikeButtonClick )
				end
				instance.Anchor:SetWorldPositionVal( worldX, worldY, worldZ )
				instance.CityRangeStrikeButton:SetVoid1( plotIndex )
				g_svStrikeButtons[ plotIndex ] = instance

				-- create a team type city banner
				instance = remove( g_scrapTeamBanners )
				if instance then
					instance.Anchor:ChangeParent( Controls.CityBanners )
				else
					instance = {}
					ContextPtr:BuildInstanceForControl( "TeamCityBanner", instance, Controls.CityBanners )
					instance.CityRangeStrikeButton:RegisterCallback( Mouse.eLClick, OnCityRangeStrikeButtonClick )
					instance.CityIsPuppet:RegisterCallback( Mouse.eLClick, AnnexPopup )
					InitBannerCallbacks( instance, TeamCityTooltips )
				end
				instance.CityIsPuppet:SetVoid1( plotIndex )
				instance.CityRangeStrikeButton:SetVoid1( plotIndex )
			else
				-- create a foreign type city banner
				instance = remove( g_scrapOtherBanners )
				if instance then
					instance.Anchor:ChangeParent( Controls.CityBanners )
				else
					instance = {}
					ContextPtr:BuildInstanceForControl( "OtherCityBanner", instance, Controls.CityBanners )
					instance.CityQuests:RegisterCallback( Mouse.eLClick, OnQuestInfoClicked )
					InitBannerCallbacks( instance, OtherCityTooltips )
				end
				instance.CityQuests:SetVoid1( plotIndex )
			end

			instance.CityBannerButton:SetVoid1( plotIndex )
			instance.Anchor:SetWorldPositionVal( worldX, worldY, worldZ + g_WorldPositionOffsetZ )

			instance[1] = isActiveType
			g_cityBanners[ plotIndex ] = instance
		end
		-- /Create City Banner
		---------------------

		-- Refresh the damage bar
		RefreshCityDamage( city, instance, city:GetDamage() )

		-- Colors
		local color = PrimaryColors[ cityOwnerID ]
		local backgroundColor = BackgroundColors[ cityOwnerID ]

		-- Update name
		local cityName = city:GetName()
		local upperCaseCityName = ToUpper( cityName )

		local originalCityOwnerID = city:GetOriginalOwner()
		local originalCityOwner = Players[ originalCityOwnerID ]
		local otherCivID, otherCivAlpha
		local isRazing = city:IsRazing()
		local isResistance = city:IsResistance()
		local isPuppet = city:IsPuppet()

		-- Update capital icon
		instance.CityIsCapital:SetHide( not city:IsCapital() or cityOwner:IsMinorCiv() )
		instance.CityIsOriginalCapital:SetHide( city:IsCapital() or not city:IsOriginalCapital() )

		instance.CityName:SetText( upperCaseCityName )
		instance.CityName:SetColor( color, 0 )			-- #0 = main color

		-- Update strength
		instance.CityStrength:SetText(floor(city:GetStrengthValue() / 100))

		-- Update population
		instance.CityPopulationValue:SetText( city:GetPopulation() )

		-- Being Razed ?
		instance.CityIsRazing:SetHide( not isRazing )

		-- In Resistance ?
		instance.CityIsResistance:SetHide( not isResistance or isRazing )

		-- Puppet ?
		instance.CityIsPuppet:SetHide( not isPuppet )

		-- Occupied ?
		instance.CityIsOccupied:SetHide( not city:IsOccupied() or city:IsNoOccupiedUnhappiness() )

		-- Blockaded ?
		instance.CityIsBlockaded:SetHide( not city:IsBlockaded() )

		-- Garrisoned ?
		instance.GarrisonFrame:SetHide( not ( plot:IsVisible( g_activeTeamID, true ) and city:GetGarrisonedUnit() ) )

		instance.CityBannerBackground:SetColor( backgroundColor )
		instance.CityBannerRightBackground:SetColor( backgroundColor )
		instance.CityBannerLeftBackground:SetColor( backgroundColor )

		if isActiveType then

			instance.CityBannerBGLeftHL:SetColor( backgroundColor )
			instance.CityBannerBGRightHL:SetColor( backgroundColor )
			instance.CityBannerBackgroundHL:SetColor( backgroundColor )

			-- Update Growth
			local foodStored100 = city:GetFoodTimes100()
			local foodPerTurn100 = city:FoodDifferenceTimes100( true )
			local foodStoredPercent = 0
			local foodStoredNextTurnPercent = 0

			if isRazing then
				foodPerTurn100 = -1
			else
				local foodThreshold100 = city:GrowthThreshold() * 100
				if foodThreshold100 > 0 then
					foodStoredPercent = foodStored100 / foodThreshold100
					foodStoredNextTurnPercent = ( foodStored100 + foodPerTurn100 ) / foodThreshold100
					if foodPerTurn100 < 0 then
						foodStoredPercent, foodStoredNextTurnPercent = foodStoredNextTurnPercent, foodStoredPercent
					end
				end
			end
			instance.CityResistanceTurns:SetText( isRazing and city:GetRazingTurns() or isResistance and city:GetResistanceTurns() )

			-- Update Growth Meter
			instance.GrowthBar:SetPercent( max(min( foodStoredPercent, 1),0))
			instance.GrowthBarShadow:SetPercent( max(min( foodStoredNextTurnPercent, 1),0))
			instance.GrowthBarStarve:SetHide( foodPerTurn100 >= 0 )

			-- Update Growth Time
			local growthText

			if foodPerTurn100 < 0 then
				growthText = "[COLOR_WARNING_TEXT]" .. min( floor( foodStored100 / -foodPerTurn100 ) + 1, 99 ) .. "[ENDCOLOR]"
			elseif city:IsForcedAvoidGrowth() then
				growthText = "[ICON_LOCKED]"
			elseif foodPerTurn100 == 0 then
				growthText = "-"
			else
				growthText = min( city:GetFoodTurnsLeft(),99 )
			end

			instance.CityGrowth:SetText( growthText )

			local productionPerTurn100 = city:GetCurrentProductionDifferenceTimes100(false, false)	-- food = false, overflow = false
			local productionStored100 = city:GetProductionTimes100() + city:GetCurrentProductionDifferenceTimes100(false, true) - productionPerTurn100
			local productionNeeded100 = city:GetProductionNeeded() * 100
			local productionStoredPercent = 0
			local productionStoredNextTurnPercent = 0

			if productionNeeded100 > 0 then
				productionStoredPercent = productionStored100 / productionNeeded100
				productionStoredNextTurnPercent = (productionStored100 + productionPerTurn100) / productionNeeded100
			end

			instance.ProductionBar:SetPercent( max(min( productionStoredPercent, 1),0))
			instance.ProductionBarShadow:SetPercent( max(min( productionStoredNextTurnPercent, 1),0))

			-- Update Production Time
			if city:IsProduction()
				and not city:IsProductionProcess()
				and productionPerTurn100 > 0
			then
				instance.BuildGrowth:SetText( city:GetProductionTurnsLeft() )
			else
				instance.BuildGrowth:SetText( "-" )
			end

			-- Update Production icon
			local unitProductionID = city:GetProductionUnit()
			local buildingProductionID = city:GetProductionBuilding()
			local projectProductionID = city:GetProductionProject()
			local processProductionID = city:GetProductionProcess()
			local portraitIndex, portraitAtlas
			local item

			if unitProductionID ~= -1 then
				item = GameInfo.Units[unitProductionID]
				portraitIndex, portraitAtlas = GetUnitPortraitIcon( (item or {}).ID or -1, cityOwnerID )
			elseif buildingProductionID ~= -1 then
				item = GameInfo.Buildings[buildingProductionID]
			elseif projectProductionID ~= -1 then
				item = GameInfo.Projects[projectProductionID]
			elseif processProductionID ~= -1 then
				item = GameInfo.Processes[processProductionID]
			end

			if item then
				instance.CityProduction:SetHide( not( item and IconHookup( portraitIndex or item.PortraitIndex, 45, portraitAtlas or item.IconAtlas, instance.CityProduction )))
			else
				instance.CityProduction:SetTexture( "CityBannerGrowthBackground.dds" )--"yieldproduction64.dds"  "CityBannerProductionImage.dds"
				instance.CityProduction:SetTextureOffsetVal( -6, 10 ) --9, 9 )
			end

			-- Focus?
			if isRazing or isResistance or isPuppet then
				instance.CityFocus:SetHide( true )
			else
				instance.CityFocus:SetText( g_cityFocusIcons[city:GetFocusType()] )
				instance.CityFocus:SetHide( false )
			end

			-- Connected to capital?
			instance.CityIsConnected:SetHide( city:IsCapital() or not cityOwner:IsCapitalConnectedToCity( city ) )

			-- Demand resource / King day ?
			local resource = GameInfo.Resources[ city:GetResourceDemanded() ]
			local weLoveTheKingDayCounter = city:GetWeLoveTheKingDayCounter()
			-- We love the king
			if weLoveTheKingDayCounter > 0 then
				instance.CityQuests:SetText( "[ICON_HAPPINESS_1]" )
				instance.CityQuests:SetHide( false )

			elseif resource then
				instance.CityQuests:SetText( resource.IconString )
				instance.CityQuests:SetHide( false )
			else
				instance.CityQuests:SetHide( true )
			end

			-- update range strike button (if it is the active player's city)

			UpdateRangeIcons( plotIndex, city, instance )

		-- not active team city
		else
			local isMinorCiv = cityOwner:IsMinorCiv()
			if isMinorCiv then
				-- Update Quests
				instance.CityQuests:SetText( GetActiveQuestText( g_activePlayerID, cityOwnerID ) )
				local info = GetCityStateStatusRow( g_activePlayerID, cityOwnerID )
				instance.StatusIconBG:SetTexture( info and info.StatusIcon )
				instance.StatusIcon:SetTexture( (GameInfo.MinorCivTraits[ (GameInfo.MinorCivilizations[ cityOwner:GetMinorCivType() ] or {}).MinorCivTrait ] or {}).TraitIcon )
				-- Update Pledge
				if gk_mode then
					local pledge = g_activePlayer:IsProtectingMinor( cityOwnerID )
					local free = pledge and cityOwner:CanMajorWithdrawProtection( g_activePlayerID )
					instance.Pledge1:SetHide( not pledge or free )
					instance.Pledge2:SetHide( not free )
				end
				-- Update Allies
				local allyID = cityOwner:GetAlly()
				local ally = Players[ allyID ]
				if ally then
				-- Set left banner icon to ally flag
					otherCivAlpha = 1
					otherCivID = g_activeTeam:IsHasMet( ally:GetTeam() ) and allyID or -1
				end
			else
				CivIconHookup( cityOwnerID, 45, instance.OwnerIcon, instance.OwnerIconBG, instance.OwnerIconShadow, false, true )
			end
			instance.CityQuests:SetHide( not isMinorCiv )
			instance.StatusIconBG:SetHide( not isMinorCiv )
			instance.OwnerIconBG:SetHide( isMinorCiv )
		end
		if not otherCivID and originalCityOwner and (originalCityOwnerID ~= cityOwnerID) then
		-- Set left banner icon to city state flag
			if originalCityOwner:IsMinorCiv() then
				otherCivAlpha = 4 --hack
				instance.MinorTraitIcon:SetTexture( (GameInfo.MinorCivTraits[ (GameInfo.MinorCivilizations[ originalCityOwner:GetMinorCivType() ] or {}).MinorCivTrait ] or {}).TraitIcon )
				instance.CityIsOriginalCapital:SetHide( true )
			else
				otherCivAlpha = 0.5
				otherCivID = originalCityOwnerID
			end
		end
		if otherCivID then
			CivIconHookup( otherCivID, 32, instance.CivIcon, instance.CivIconBG, instance.CivIconShadow, false, true )
			instance.CivIndicator:SetAlpha( otherCivAlpha )
		end
		instance.MinorCivIndicator:SetHide( otherCivAlpha ~= 4 ) -- hack
		instance.CivIndicator:SetHide( not otherCivID )

		-- Spy & Religion
		if gk_mode then
			local spy
			local x = city:GetX()
			local y = city:GetY()

			for _, s in ipairs( g_activePlayer:GetEspionageSpies() ) do
				if s.CityX == x and s.CityY == y then
					spy = s
					break
				end
			end

			if spy then
				if spy.IsDiplomat then
					instance.CityDiplomat:SetVoid1( spy.EstablishedSurveillance and plotIndex or -1 )
					instance.CityDiplomat:LocalizeAndSetToolTip( "TXT_KEY_CITY_DIPLOMAT_OTHER_CIV_TT", spy.Rank, spy.Name, cityName, spy.Rank, spy.Name, spy.Rank, spy.Name )
					instance.CityDiplomat:SetHide( false )
					instance.CitySpy:SetHide( true )
				else
					instance.CitySpy:SetHide( false )
					instance.CitySpy:SetVoid1( spy.EstablishedSurveillance and plotIndex or -1 )
					if isActivePlayerCity then
						instance.CitySpy:LocalizeAndSetToolTip( "TXT_KEY_CITY_SPY_YOUR_CITY_TT", spy.Rank, spy.Name, cityName, spy.Rank, spy.Name )
					elseif cityOwner:IsMinorCiv() then
						instance.CitySpy:LocalizeAndSetToolTip( "TXT_KEY_CITY_SPY_CITY_STATE_TT", spy.Rank, spy.Name, cityName, spy.Rank, spy.Name)
					else
						instance.CitySpy:LocalizeAndSetToolTip( "TXT_KEY_CITY_SPY_OTHER_CIV_TT", spy.Rank, spy.Name, cityName, spy.Rank, spy.Name, spy.Rank, spy.Name)
					end
					instance.CityDiplomat:SetHide( true )
				end
			else
				instance.CitySpy:SetHide( true )
				instance.CityDiplomat:SetHide( true )
			end

			local religion = GameInfo.Religions[city:GetReligiousMajority()]
			if religion then
				IconHookup( religion.PortraitIndex, 32, religion.IconAtlas, instance.CityReligion )
				IconHookup( religion.PortraitIndex, 32, religion.IconAtlas, instance.ReligiousIconShadow )
				instance.ReligiousIconContainer:SetHide( false )
			else
				instance.ReligiousIconContainer:SetHide( true )
			end
		end

		-- Change the width of the banner so it looks good with the length of the city name

		instance.NameStack:CalculateSize()
		local bannerWidth = instance.NameStack:GetSizeX() - 64
		instance.CityBannerButton:SetSizeX( bannerWidth + 64 )
		instance.CityBannerBackground:SetSizeX( bannerWidth )
		instance.CityBannerBackgroundHL:SetSizeX( bannerWidth )
		if isActiveType then
			instance.CityBannerBackgroundIcon:SetSizeX( bannerWidth )
			instance.CityBannerButtonGlow:SetSizeX( bannerWidth )
			instance.CityBannerButtonBase:SetSizeX( bannerWidth )
		else
			instance.CityBannerBaseFrame:SetSizeX( bannerWidth )
			instance.CityAtWar:SetSizeX( bannerWidth )
			instance.CityAtWar:SetHide( not g_activeTeam:IsAtWar( city:GetTeam() ) )
		end

		instance.CityBannerButton:ReprocessAnchoring()
		instance.NameStack:ReprocessAnchoring()
		instance.IconsStack:CalculateSize()
		instance.IconsStack:ReprocessAnchoring()

		if g_cityHexHighlight == plotIndex then

			if not (InStrategicView and InStrategicView()) then
				local cityID = city:GetID()
				local cityTeamID = cityOwner:GetTeam()
				local plot = GetPlot(0,0)
				local hexPos
				local checkFunc = plot.GetCityPurchaseID or plot.GetWorkingCity
				local checkVal = plot.GetCityPurchaseID and cityID or city
				for i = 0, city:GetNumCityPlots()-1 do
					plot = city:GetCityIndexPlot( i )
					if plot then
						hexPos = ToHexFromGrid{ x=plot:GetX(), y=plot:GetY() }
						-- Show city limits
						EventsSerialEventHexHighlight( hexPos, true, nil, "CityLimits" )
						if plot:GetOwner() == cityOwnerID then
							local isImproved = true
							if plot:GetImprovementType()>0 then
								isImproved  = not plot:IsImprovementPillaged() -- CanHaveImprovement, GetImprovementType, GetRevealedImprovementType, IsImprovementPillaged
							else
								for improvement in GameInfo.Improvements() do
									if plot:CanHaveImprovement( improvement.ID, cityTeamID ) then
										isImproved = false
										break
									end
								end
							end
							if isActiveType and city:IsWorkingPlot( plot ) then
								-- worked city plots
								if isImproved then
									EventsSerialEventHexHighlight( hexPos , true, nil, "WorkedFill" )
								end
								EventsSerialEventHexHighlight( hexPos , true, nil, "WorkedOutline" )
							elseif not city:CanWork( plot ) and ( plot:IsWater() and city:IsPlotBlockaded( plot ) or plot:IsVisibleEnemyUnit( cityOwnerID ) ) then
								-- Blockaded water plot or Enemy Unit standing here
								EventsSerialEventHexHighlight( hexPos , true, nil, "EnemyFill" )
								EventsSerialEventHexHighlight( hexPos , true, nil, "EnemyOutline" )
							elseif checkFunc( plot ) == checkVal then
								-- city plots that are owned but not worked
								if isImproved then
									EventsSerialEventHexHighlight( hexPos , true, nil, "OwnedFill" )
								end
								EventsSerialEventHexHighlight( hexPos , true, nil, "OwnedOutline" )
							end
						end
					end
				end
			end
			if isActiveType then
				-- Show plots that will be acquired by culture
				local purchasablePlots = {city:GetBuyablePlotList()}
				for i = 1, #purchasablePlots do
					local plot = purchasablePlots[i]
					EventsSerialEventHexHighlight( ToHexFromGrid{ x=plot:GetX(), y=plot:GetY() }, true, ColorCulture, "HexContour" )
				end
				EventsRequestYieldDisplay( YieldDisplayTypes.AREA, CITY_PLOTS_RADIUS, city:GetX(), city:GetY() )
			else
				EventsRequestYieldDisplay( YieldDisplayTypes.CITY_OWNED, city:GetX(), city:GetY() )
			end
		end
	end
end

local function RefreshCityBannerAtPlot( plot )
	return plot and RefreshCityBanner( plot:GetPlotCity() )
end

--==========================================================
-- Register Events
--==========================================================

------------------
-- On City Created
Events.SerialEventCityCreated.Add( function( hexPos, cityOwnerID, cityID, cultureType, eraType, continent, populationSize, size, fowState )
	-- fowState 0 is invisible
	if fowState ~= 0 then
		return RefreshCityBannerAtPlot( GetPlot( ToGridFromHex( hexPos.x, hexPos.y ) ) )
	end
end)

------------------
-- On City Updated
Events.SerialEventCityInfoDirty.Add( function()
	-- Don't know which city, so update all visible city banners
	for plotIndex in pairs( g_cityBanners ) do
		RefreshCityBannerAtPlot( GetPlotByIndex( plotIndex ) )
	end
end)

--------------------
-- On City Destroyed
Events.SerialEventCityDestroyed.Add(
function( hexPos ) --, cityOwnerID, cityID, newPlayerID )
	local plot = GetPlot( ToGridFromHex( hexPos.x, hexPos.y ) )
	if plot then
		local plotIndex = plot:GetPlotIndex()
		return DestroyCityBanner( plotIndex, g_cityBanners[ plotIndex ] )
	end
end)

---------------------
-- On City Set Damage
Events.SerialEventCitySetDamage.Add( function( cityOwnerID, cityID, cityDamage, previousDamage )
	local cityOwner = Players[ cityOwnerID ]
	if cityOwner then
		local city = cityOwner:GetCityByID( cityID )
		if city then
			return RefreshCityDamage( city, g_cityBanners[ city:Plot():GetPlotIndex() ], cityDamage )
		end
	end
end)

---------------------------
-- On Specific City changed
Events.SpecificCityInfoDirty.Add( function( cityOwnerID, cityID, updateType )
	local cityOwner = Players[ cityOwnerID ]
	if cityOwner then
		local city = cityOwner:GetCityByID( cityID )
		if city then
			local plotIndex = city:Plot():GetPlotIndex()
			local instance = g_cityBanners[ plotIndex ]
			if instance then
				if updateType == CityUpdateTypes.CITY_UPDATE_TYPE_ENEMY_IN_RANGE then
					return UpdateRangeIcons( plotIndex, city, instance )
				elseif updateType == CityUpdateTypes.CITY_UPDATE_TYPE_BANNER or updateType == CityUpdateTypes.CITY_UPDATE_TYPE_GARRISON then
					return RefreshCityBanner( city )
				end
			end
		end
	end
end)

-------------------------
-- On Improvement Created
Events.SerialEventImprovementCreated.Add( function( hexX, hexY, cultureID, continentID, playerID )--, improvementID, rawResourceID, improvementEra, improvementState )
	if playerID == g_activePlayerID then
		local plot = GetPlot( ToGridFromHex( hexX, hexY ) )
		if plot then
			return RefreshCityBanner( plot:GetWorkingCity() )
		end
	end
end)

---------------------------
-- On Road/Railroad Created
Events.SerialEventRoadCreated.Add( function( hexX, hexY, playerID, roadID )
	if playerID == g_activePlayerID then
		for city in g_activePlayer:Cities() do
			RefreshCityBanner( city )
		end
	end
end)

--[[
-----------------------
-- On city range strike
Events.InitCityRangeStrike.Add( function( cityOwnerID, cityID )
	if cityOwnerID == g_activePlayerID then
		local city = g_activePlayer:GetCityByID( cityID )
		if city and city == UI.GetHeadSelectedCity() then
			UI.SetInterfaceMode( InterfaceModeTypes.INTERFACEMODE_CITY_RANGE_ATTACK )
		end
	end
end)
--]]

-------------------
-- On Unit Garrison
Events.UnitGarrison.Add( function( unitOwnerID, unitID, isGarrisoned )
	if isGarrisoned then
		local unitOwner = Players[ unitOwnerID ]
		if unitOwner then
			local unit = unitOwner:GetUnitByID( unitID )
			if unit then
				local city = unit:GetGarrisonedCity()
				if city then
					return HideGarrisonFrame( g_cityBanners[ city:Plot():GetPlotIndex() ], UnitMoving( unitOwnerID, unitID ) )
				end
			end
		end
	end
end)

-----------------------------
-- On Unit Move Queue Changed
Events.UnitMoveQueueChanged.Add( function( unitOwnerID, unitID, hasRemainingMoves )
	local unitOwner = Players[ unitOwnerID ]
	if unitOwner then
		local unit = unitOwner:GetUnitByID( unitID )
		if unit then
			local city = unit:GetGarrisonedCity()
			if city then
				return HideGarrisonFrame( g_cityBanners[ city:Plot():GetPlotIndex() ], not hasRemainingMoves )
			end
		end
	end
end)

--[[
---------------------------
-- On interface mode change
Events.InterfaceModeChanged.Add( function( oldInterfaceMode, newInterfaceMode )
	local disableBanners = newInterfaceMode ~= InterfaceModeTypes.INTERFACEMODE_SELECTION
	for _, instance in pairs( g_cityBanners ) do
		instance.CityBannerButton:SetDisabled( disableBanners )
		instance.CityBannerButton:EnableToolTip( not disableBanners )
	end
end)
--]]

---------------------------
-- On strategic view change
Events.StrategicViewStateChanged.Add( function(isStrategicView, showCityBanners)
	local showBanners = showCityBanners or not isStrategicView
	Controls.CityBanners:SetHide( not showBanners )
	return Controls.StrategicViewStrikeButtons:SetHide( showBanners )
end)

-----------------------
-- On fog of war change
Events.HexFOWStateChanged.Add( function( hexPos, fowType, isWholeMap )
	if isWholeMap then
		 -- fowState 0 is invisible
		if fowType == 0 then
			for plotIndex, instance in pairs( g_cityBanners ) do
				DestroyCityBanner( plotIndex, instance )
			end
		else
			for playerID = 0, #Players do
				local player = Players[ playerID ]
				if player and player:IsAlive() then
					for city in player:Cities() do
						RefreshCityBanner( city )
					end
				end
			end
		end
	else
		local plot = GetPlot( ToGridFromHex( hexPos.x, hexPos.y ) )
		if plot then
			-- fowType 0 is invisible
			if fowType == 0 then
				local plotIndex = plot:GetPlotIndex()
				return DestroyCityBanner( plotIndex, g_cityBanners[ plotIndex ] )
			else
				return RefreshCityBannerAtPlot( plot )
			end
		end
	end
end)

---------------------------
-- On War Declared
Events.WarStateChanged.Add(
function( teamID1, teamID2, isAtWar )
	if teamID1 == g_activeTeamID then
		teamID1 = teamID2
	elseif teamID2 ~= g_activeTeamID then
		return
	end
	for playerID = 0, #Players do
		local player = Players[playerID]
		if player and player:IsAlive() and player:GetTeam() == teamID1 then
			for city in player:Cities() do
				if city:Plot():IsRevealed( g_activeTeamID, true ) then
					RefreshCityBanner( city )
				end
			end
		end
	end
end)

--==========================================================
-- 'Active' (local human) player has changed:
-- Check for City Banner Active Type change
--==========================================================
Events.GameplaySetActivePlayer.Add( function( activePlayerID, previousActivePlayerID )
	-- update globals

	g_activePlayerID = Game.GetActivePlayer()
	g_activePlayer = Players[ g_activePlayerID ]
	g_activeTeamID = Game.GetActiveTeam()
	g_activeTeam = Teams[ g_activeTeamID ]
	ClearHexHighlights()
	local isDebug = Game.IsDebugMode() or g_activePlayer:IsObserver()
	-- Update all city banners
	for playerID = 0, #Players do
		local player = Players[ playerID ]
		if player and player:IsAlive() then
			for city in player:Cities() do
				local plot = city:Plot()
				local plotIndex = plot:GetPlotIndex()
				local instance = g_cityBanners[ plotIndex ]

				if plot:IsRevealed( g_activeTeamID, isDebug ) then
					RefreshCityBanner( city )
				-- If city banner is hidden, destroy the banner
				elseif instance then
					DestroyCityBanner( plotIndex, instance )
				end
			end
		end
	end
end)

--==========================================================
-- Hide Garrisson Ring during Animated Combat
--==========================================================
if gk_mode then

	local function HideGarrisonRing( x, y, hideGarrisonRing )

		local plot = GetPlot( x, y )
		local city = plot and plot:GetPlotCity()
		local instance = city and g_cityBanners[ plot:GetPlotIndex() ]
		return instance and HideGarrisonFrame( instance, hideGarrisonRing or not city:GetGarrisonedUnit() )
	end

	Events.RunCombatSim.Add( function(
				attackerPlayerID,
				attackerUnitID,
				attackerUnitDamage,
				attackerFinalUnitDamage,
				attackerMaxHitPoints,
				defenderPlayerID,
				defenderUnitID,
				defenderUnitDamage,
				defenderFinalUnitDamage,
				defenderMaxHitPoints,
				attackerX,
				attackerY,
				defenderX,
				defenderY,
				bContinuation)
--print( "CityBanner CombatBegin", attackerX, attackerY, defenderX, defenderY )

		HideGarrisonRing(attackerX, attackerY, true)
		HideGarrisonRing(defenderX, defenderY, true)
	end)

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
				defenderMaxHitPoints,
				attackerX,
				attackerY,
				defenderX,
				defenderY )

--print( "CityBanner CombatEnd", attackerX, attackerY, defenderX, defenderY )

		HideGarrisonRing(attackerX, attackerY, false)
		HideGarrisonRing(defenderX, defenderY, false)
	end)

end -- gk_mode

--==========================================================
-- The active player's turn has begun, make sure their range strike icons are correct
--==========================================================
Events.ActivePlayerTurnStart.Add( function()
	for plotIndex, instance in pairs( g_cityBanners ) do
		UpdateRangeIcons( plotIndex, GetPlotByIndex( plotIndex ):GetPlotCity(), instance )
	end
end)

Events.SerialEventUnitDestroyed.Add( function( unitOwnerID, unitID )
	local unitOwner = Players[ unitOwnerID ]
	if unitOwner and g_activeTeam:IsAtWar( unitOwner:GetTeam() ) then
		for city in g_activePlayer:Cities() do
			local plotIndex = city:Plot():GetPlotIndex()
			UpdateRangeIcons( plotIndex, city, g_cityBanners[ plotIndex ] )
		end
	end
end)

--==========================================================
-- Initialize all Visible City Banners
--==========================================================
for playerID = 0, #Players do
	local player = Players[ playerID ]
	if player and player:IsEverAlive() then
		for city in player:Cities() do
			if city:Plot():IsRevealed( g_activeTeamID, true ) then
				RefreshCityBanner( city )
			end
		end
	end
end

end)
