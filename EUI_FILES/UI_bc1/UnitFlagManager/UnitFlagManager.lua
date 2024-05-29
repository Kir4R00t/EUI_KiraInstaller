--==========================================================
-- UnitFlagManager
-- Re-written by bc1 using Notepad++
--==========================================================

Events.SequenceGameInitComplete.Add(function()

include "UserInterfaceSettings"
local UserInterfaceSettings = UserInterfaceSettings

include "GameInfoCache" -- warning! booleans are true, not 1, and use iterator ONLY with table field conditions, NOT string SQL query
local GameInfoUnitPromotions = GameInfoCache.UnitPromotions
local GameInfoUnits = GameInfoCache.Units
local GameInfoUnit_FreePromotions = GameInfoCache.Unit_FreePromotions

include "IconHookup"
local IconLookup = IconLookup
local IconHookup = IconHookup
local PrimaryColors = PrimaryColors
local BackgroundColors = BackgroundColors
local ColorGreen = Color( 0, 1, 0, 1 )
local ColorYellow = Color( 1, 1, 0, 1 )
local ColorRed = Color( 1, 0, 0, 1 )
local ColorWhite = Color( 1, 1, 1, 1 )

--==========================================================
-- Minor lua optimizations
--==========================================================

local min = math.min
local pi = math.pi
local cos = math.cos
local sin = math.sin
local pairs = pairs
local pcall = pcall
local insert = table.insert
local remove = table.remove
local type = type

local ContextPtr = ContextPtr
local DOMAIN_AIR = DomainTypes.DOMAIN_AIR
local Events = Events
local GetActivePlayer = Game.GetActivePlayer
local GetActiveTeam = Game.GetActiveTeam
local MouseoverUnit = Game.MouseoverUnit
local GridToWorld = GridToWorld
local GameInfoTypes = GameInfoTypes
local InStrategicView = InStrategicView
local Locale = Locale
local GetPlot = Map.GetPlot
local GetPlotByIndex = Map.GetPlotByIndex
local Mouse = Mouse
local Players = Players
local ToGridFromHex = ToGridFromHex
local GetUnitFlagIcon = UI.GetUnitFlagIcon
local UnitMoving = UnitMoving
local Teams = Teams

local GetPlotNumUnits = GetPlot(0,0).GetNumLayerUnits or GetPlot(0,0).GetNumUnits
local GetPlotUnit = GetPlot(0,0).GetLayerUnit or GetPlot(0,0).GetUnit

local g_HiddenControls = Controls.AirCraftFlags --!!! TODO
local g_AirCraftFlags = Controls.AirCraftFlags
local g_CivilianFlags = Controls.CivilianFlags
local g_MilitaryFlags = Controls.MilitaryFlags
local g_GarrisonFlags = Controls.GarrisonFlags
local g_AirbaseControls = Controls.AirbaseFlags
local g_SelectedFlags = Controls.SelectedFlags
g_SelectedFlags:ChangeParent( ContextPtr:LookUpControl( "../SelectedUnitContainer" ) or ContextPtr )

local g_SelectedFlag
local g_SelectedCargo = {}
local g_AirbaseFlags = {}
local foreverEmptyTable = setmetatable( {}, { __newindex = function() end } )
local g_UnitFlags = setmetatable( {}, { __index = function( t, k )
		if Players[k] then
			local v = {}
			t[k] = v
			return v
		else
			return foreverEmptyTable
		end
	end } )
local g_spareNewUnitFlags = {}
local g_spareAirbaseFlags = {}

local g_activePlayerID = GetActivePlayer()
local g_activeTeamID = GetActiveTeam()
local g_activePlayer = Players[ g_activePlayerID ]
local g_activeTeam = Teams[ g_activeTeamID ]

local g_RibbonUnits = foreverEmptyTable
LuaEvents.EUI_UnitRibbonTable.Add( function( t ) g_RibbonUnits = t end )

--==========================================================
-- Debug routines
--==========================================================
local debug_print = print

local function debug_unit( playerID, unitID, ... )
	local player = Players[ playerID ]
	local unit = player and player:GetUnitByID( unitID )
	print( "Player#", playerID, "unit#", unitID, unit and Locale.Lookup(unit:GetNameKey()), "unitXY=", unit and unit:GetX(), unit and unit:GetY(), ... )
end
local function debug_flag( flag, ... )
	if type(flag)=="table" then
		debug_unit( flag.m_PlayerID, flag.m_UnitID, "flagXY=", flag.m_Plot and flag.m_Plot:GetX(), flag.m_Plot and flag.m_Plot:GetY(), ... )
	else
		print( "flag=", flag, ... )
	end
end

--==========================================================
-- Cache promotion data
--==========================================================
local g_sparePromotionIcons = {}
local g_isBasicPromotion = {}
local g_promotionOverrides = {}
local g_visiblePromotions = {}
local g_visiblePromotionsIfOptionIsActive = {}
local g_visiblePromotionsList = {}
do
	local isBlandPromotion = { [57]="ABILITY_ATLAS", [58]="ABILITY_ATLAS", [59]="ABILITY_ATLAS" } -- specifies "generic" icons
	local isHidePromotion = { PROMOTION_EMBARKATION = 1, PROMOTION_DEFENSIVE_EMBARKATION = 1 , PROMOTION_ALLWATER_EMBARKATION = 1, PROMOTION_HOMELAND_GUARDIAN_BOOGALOO = 1 }
	-- Promotion data pre-processing
	for promotionInfo in GameInfoUnitPromotions() do
		--debug_print("Candidate promotion", promotionInfo.ID, promotionInfo.Type, "ShowInUnitPanel", promotionInfo.ShowInUnitPanel, promotionInfo.PortraitIndex, promotionInfo.IconAtlas, isBlandPromotion[promotionInfo.PortraitIndex] or false )
		if promotionInfo.ShowInUnitPanel ~= false
			and isBlandPromotion[ promotionInfo.PortraitIndex ] ~= promotionInfo.IconAtlas
			and not isHidePromotion[ promotionInfo.Type ]
		then
			g_visiblePromotions[ promotionInfo.ID ] = promotionInfo
			insert( g_visiblePromotionsList, promotionInfo.ID )
			-- does this promotion have exactly one prerequisite ?
			if not promotionInfo.PromotionPrereqOr2 then
				g_promotionOverrides[ promotionInfo.ID ] = GameInfoTypes[ promotionInfo.PromotionPrereqOr1 or promotionInfo.PromotionPrereq ]
			end
			--debug_print("Visible promotion", promotionInfo.ID, promotionInfo.Type, promotionPrereq )
		end
	end
	-- Basic unit promotions
	for unitInfo in GameInfoUnits() do
		local t = {}
		g_isBasicPromotion[ unitInfo.ID ] = t
		for row in GameInfoUnit_FreePromotions{ UnitType=unitInfo.Type } do
			t[ GameInfoTypes[row.PromotionType] or false ] = true
			--debug_print("Unit", unitInfo.Type, row.PromotionType, GameInfoTypes[row.PromotionType] )
		end
	end
end

--==========================================================
-- Flag promotions
--==========================================================
local function UpdateFlagPromotions( flag )
	--debug_flag( flag, "UpdateFlagPromotions" )
	local sparePromotionIcons = g_sparePromotionIcons
	local hiddenControls = g_HiddenControls
	if flag.m_IsAtWar or flag.m_PlayerID == GetActivePlayer() then
		local unitID = flag.m_UnitID
		local unit = flag.m_Player:GetUnitByID( unitID )
		if unit then
			local flag2 = g_RibbonUnits[ unitID ]
			-- initialize unit promotion arrays: unitPromotions and unitPromotionsOverridden
			local unitPromotions = {}
			local unitPromotionsOverridden = {}

			local isBasicPromotion = g_isBasicPromotion[ unit:GetUnitType() ] or foreverEmptyTable
			local promotionOverrides = g_promotionOverrides
			local unitPromotionOverride
			for promotionID, promotionInfo in pairs( g_visiblePromotionsIfOptionIsActive ) do
				if not isBasicPromotion[ promotionID ] and unit:IsHasPromotion(promotionID) then
					unitPromotions[ promotionID ] = promotionInfo
					unitPromotionOverride = promotionOverrides[ promotionID ]
					if unitPromotionOverride then
						unitPromotionsOverridden[ unitPromotionOverride ] = true
					end
				end
			end

			-- update promotion icons
			local promotionIcon, promotionInfo
			while flag do
				local flagPromotionStack = flag.PromotionStack
				local flagPromotionIcons = flag.m_PromotionIcons
				for _, promotionID in ipairs( g_visiblePromotionsList ) do
					promotionInfo = unitPromotions[ promotionID ]
					promotionIcon = flagPromotionIcons[ promotionID ]
					if promotionInfo and not unitPromotionsOverridden[ promotionID ] then
--debug_print(promotionInfo.Type)
						if promotionIcon then
--debug_print("existing promotion icon")
							-- re-order promotion icon in the stack
							promotionIcon:ChangeParent( flagPromotionStack )
						else
							-- grab a spare promotion icon
							promotionIcon = remove( sparePromotionIcons )
							if promotionIcon then
--debug_print("recycled promotion icon")
								promotionIcon:ChangeParent( flagPromotionStack )
							else
--debug_print("new promotion icon")
								-- create a new promotion icon
								promotionIcon = {}
								ContextPtr:BuildInstanceForControl( "PromotionIcon", promotionIcon, flagPromotionStack )
								promotionIcon = promotionIcon.Image
								promotionIcon:SetTextureSizeVal( 64, 64 )
							end
							IconHookup( promotionInfo.PortraitIndex, 64, promotionInfo.IconAtlas, promotionIcon )
							promotionIcon:SetToolTipString( promotionInfo._Name )
							flagPromotionIcons[ promotionID ] = promotionIcon
						end
					elseif promotionIcon then
						-- recycle unused promotion icon
						flagPromotionIcons[ promotionID ] = nil
						insert( sparePromotionIcons, promotionIcon )
						promotionIcon:ChangeParent( hiddenControls )
					end
				end
				flag = flag2
				flag2 = nil
			end
		end
	else
		-- remove promotion icons
		local flagPromotionIcons = flag.m_PromotionIcons
		for promotionID, promotionIcon in pairs( flagPromotionIcons ) do
			flagPromotionIcons[ promotionID ] = nil
			insert( sparePromotionIcons, promotionIcon )
			promotionIcon:ChangeParent( hiddenControls )
		end
	end
end

LuaEvents.CallFlagManagerUpdateUnitPromotions.Add( function( unit )
	local flag = g_UnitFlags[ unit:GetOwner() ][ unit:GetID() ]
	if flag then
		return UpdateFlagPromotions( flag )
	end
end )

-- In some cases (e.g. natural wonder adjacency) promotions are given out without GameEvents.UnitPromoted
local function UpdatePlayerFlagPromotions( PlayerID )
	for _, flag in pairs(g_UnitFlags[ PlayerID ]) do
		UpdateFlagPromotions( flag )
	end
end
local function UpdateAllFlagPromotions()
	for PlayerID in pairs(g_UnitFlags) do
		UpdatePlayerFlagPromotions( PlayerID )
	end
end
--Events.ActivePlayerTurnStart.Add( UpdateAllFlagPromotions ) 
local function UnitPromoted( playerID, unitID )
	local flag = g_UnitFlags[ playerID ][ unitID ]
	if flag then
		return UpdateFlagPromotions( flag )
	end
end
-- !!! GameEvents is bugged and must go through pcall !!!
GameEvents.UnitPromoted.Add( function( playerID, unitID ) return pcall( UnitPromoted, playerID, unitID ) end )

--==========================================================
-- Manage flag interactions with user
--==========================================================
local function UnitFlagClicked( playerID, unitID )
	return Events.SerialEventUnitFlagSelected( playerID, unitID )
end

local function UnitFlagEnterExit( isEnter, playerID, unitID )
	local mouseOverUnit = Players[ playerID ]
	if mouseOverUnit then
		mouseOverUnit = mouseOverUnit:GetUnitByID( unitID )
		if mouseOverUnit then
			return MouseoverUnit( mouseOverUnit, isEnter )
		end
	end
end

local function UnitFlagEnter( ... )
	return UnitFlagEnterExit( true, ... )
end

local function UnitFlagExit( ... )
	return UnitFlagEnterExit( false, ... )
end

local function CargoFlagClicked( playerID, unitID )
	local player = Players[ playerID ]
	local unit = player and player:GetUnitByID( unitID )
	if unit then
		local plot = unit:GetPlot()
		if plot then
			for i = 0, GetPlotNumUnits( plot ) - 1 do
				local cargoUnit = GetPlotUnit( plot, i )
				if cargoUnit:GetTransportUnit() == unit then
					playerID, unitID = cargoUnit:GetOwner(), cargoUnit:GetID()
					if cargoUnit:CanMove() then break end
				end
			end
		end
	end
	return Events.SerialEventUnitFlagSelected( playerID, unitID )
end

local function AirbaseFlagClicked( plotIndex )
	local plot = GetPlotByIndex( plotIndex )
	if plot then
		local playerID, unitID
		for i = 0, GetPlotNumUnits( plot ) - 1 do
			local unit = GetPlotUnit( plot, i )
			if not unit:IsCargo() and unit:GetDomainType() == DOMAIN_AIR then
				playerID, unitID = unit:GetOwner(), unit:GetID()
				if unit:CanMove() then break end
			end
		end
		if playerID and unitID then
			return Events.SerialEventUnitFlagSelected( playerID, unitID )
		end
	end
end

--==========================================================
local function SetFlagParent( flag )
	--debug_flag( flag, "SetFlagParent" )
	if flag.m_IsSelected then
		flag.Anchor:ChangeParent( g_SelectedFlags )
	elseif flag.m_TransportUnitID or flag.m_IsAirCraft then
		flag.Anchor:ChangeParent( g_AirCraftFlags )
	elseif flag.m_IsCivilian then
		flag.Anchor:ChangeParent( g_CivilianFlags )
	elseif flag.m_IsGarrisoned then
		flag.Anchor:ChangeParent( g_GarrisonFlags )
	else
		flag.Anchor:ChangeParent( g_MilitaryFlags )
	end
end

--==========================================================
local function UpdatePlotFlags( plot )
	--debug_print( "UpdatePlotFlags at plot XY=", plot:GetX(), plot:GetY() )
	local flags = {}
	local aflags = {}
	local unit, flag, n
	local city = plot:GetPlotCity()
	if city then
		local l = -43
		local r = 43
		local y = GetActiveTeam() == city:GetTeam() and -39 or -36
		local gflags = {}
		for i = 0, GetPlotNumUnits( plot ) - 1 do
			unit = GetPlotUnit( plot, i )
			flag = g_UnitFlags[ unit:GetOwner() ][ unit:GetID() ]
			if flag and flag.m_Plot then
				if unit:IsCargo() then
				elseif flag.m_IsAirCraft then
					insert( aflags, unit )
				elseif unit:IsGarrisoned() then
					insert( gflags, flag )
				else
					insert( flags, flag )
				end
			end
		end
		n = #flags
		--debug_print( n,"flags found in city")
		if n == 1 then
			flags[1].Container:SetOffsetVal( r, y )
		elseif n > 1 then
			local a = -min(35/(n-1),20)
			local b = y-a
			for i=n, 1, -1 do
				--debug_flag( flags[i],"update offset at position", i )
				flags[i].Container:SetOffsetVal( r, a*i+b )
				SetFlagParent( flags[i] )
			end
		end
		n = #gflags
		--debug_print( n,"gflags found in city")
		if n == 1 then
			gflags[1].Container:SetOffsetVal( l, y )
		elseif n > 1 then
			local a = -min(35/(n-1),20)
			local b = y-a
			for i=n, 1, -1 do
				--debug_flag( flags[i],"update offset at position", i )
				gflags[i].Container:SetOffsetVal( l, a*i+b )
				SetFlagParent( gflags[i] )
			end
		end
	else
		for i = 0, GetPlotNumUnits( plot ) - 1 do
			unit = GetPlotUnit( plot, i )
			flag = g_UnitFlags[ unit:GetOwner() ][ unit:GetID() ]
			--debug_flag( flag,"candidate is aircraft?", flag and flag.m_IsAirCraft )
			if flag and flag.m_Plot then
				if unit:IsCargo() then
				elseif flag.m_IsAirCraft then
					insert( aflags, unit )
				else
					insert( flags, flag )
				end
			end
		end
		n = #flags
		--debug_print( n,"flags found outside city")
		if n == 1 then
			flags[1].Container:SetOffsetVal( 0, 0 )
		elseif n > 1 then
			local a = -min(35/(n-1),20)
			for i=n, 1, -1 do
				--debug_flag( flags[i],"update offset at position", i )
				flags[i].Container:SetOffsetVal( 0, (i-1)*a )
				SetFlagParent( flags[i] )
			end
		end
	end
	n = #aflags
	--debug_print( n,"airbase flags found")
	local plotIndex = plot:GetPlotIndex()
	flag = g_AirbaseFlags[ plotIndex ]
	if n > 0 then
		if not flag then
			flag = remove( g_spareAirbaseFlags )
			if flag then
				flag.Anchor:ChangeParent( g_AirbaseControls )
			else
				flag = {}
				ContextPtr:BuildInstanceForControl( "AirbaseFlag", flag, g_AirbaseControls )
				flag.Button:RegisterCallback( Mouse.eLClick, AirbaseFlagClicked )
			end
			g_AirbaseFlags[ plotIndex ] = flag
			local x, y, z = GridToWorld( plot:GetX(), plot:GetY() )
			flag.Anchor:SetWorldPositionVal( x, y, z + 35 ) -- World Position Offset
			flag.Button:SetVoid1( plotIndex )
		end
		flag.Anchor:SetHide( not plot:IsVisible( g_activeTeamID, true ) )
		flag.Button:SetText( n )
		flag.Button:LocalizeAndSetToolTip( "TXT_KEY_STATIONED_AIRCRAFT", n )
	elseif flag then
		g_AirbaseFlags[ plotIndex ] = nil
		flag.Anchor:ChangeParent( g_HiddenControls )
		insert( g_spareAirbaseFlags, flag )
	end
end--UpdatePlotFlags

--==========================================================
local function SetFlagSelected( flag, isSelected )
	--debug_flag( flag, "SetFlagSelected, isSelected=", isSelected )
	flag.m_IsSelected = isSelected
	flag.FlagHighlight:SetHide( not isSelected )
	-- RestoreCargoFlagParents
	for i = 1, #g_SelectedCargo do
		SetFlagParent( g_SelectedCargo[i] )
		g_SelectedCargo[i] = nil
	end
	if isSelected then
		local selectedUnit = flag.m_Player:GetUnitByID( flag.m_UnitID )
		local plot = selectedUnit and selectedUnit:GetPlot()
		if plot then
			local transportUnit = selectedUnit:GetTransportUnit()
			local cargoUnit, cargoFlag
			if transportUnit then
				--debug_flag( flag, "selected unit is carge" )
				local x, y
				local transportFlag = g_UnitFlags[ transportUnit:GetOwner() ][ transportUnit:GetID() ]
				if transportFlag then
					x, y = transportFlag.Container:GetOffsetVal()
				else
					x, y = 0, 0
				end
				local cargo = transportUnit:GetCargo()
				local a = min( pi / 3, 5.7 / cargo )
				local a0 = -a*(cargo-1)/2 - pi
				local j = 0
				--debug_flag( transportFlag, "transport identified, cargo#=", cargo )
				for i = 0, GetPlotNumUnits( plot ) - 1 do
					cargoUnit = GetPlotUnit( plot, i )
					if cargoUnit:GetTransportUnit() == transportUnit then
						cargoFlag = g_UnitFlags[ cargoUnit:GetOwner() ][ cargoUnit:GetID() ]
						if cargoFlag then
							--debug_flag( cargoFlag, "added to cargo at position", j )
							insert( g_SelectedCargo, cargoFlag )
							cargoFlag.Container:SetOffsetVal( cos( a*j + a0 )*38 + x, sin( a*j + a0 )*38 + y )
							cargoFlag.Anchor:ChangeParent( g_SelectedFlags )
						end
						j = j + 1
					end
				end
			elseif flag.m_IsAirCraft then
				local airbase = {}
				for i = 0, GetPlotNumUnits( plot ) - 1 do
					cargoUnit = GetPlotUnit( plot, i )
					cargoFlag = g_UnitFlags[ cargoUnit:GetOwner() ][ cargoUnit:GetID() ]
					if cargoFlag and cargoFlag.m_IsAirCraft and not cargoUnit:GetTransportUnit() then
						insert( airbase, cargoFlag )
					end
				end
				local n=#airbase
				--debug_print( n, "aircraft found")
				if n > 0 then
					local a = min( 0.5, 2.7 / n )
					local a0 = -a*(n+1)/2 - pi/2
					for i = 1, n do
						cargoFlag = airbase[i]
						--debug_flag( cargoFlag, "adding aircraft to airbase at position", i )
						insert( g_SelectedCargo, cargoFlag )
						cargoFlag.Anchor:ChangeParent( g_SelectedFlags )
						cargoFlag.Container:SetOffsetVal( cos( a*i + a0 )*80, sin( a*i + a0 )*80 )
					end
				end
			end
		end
		g_SelectedFlag = flag
	elseif g_SelectedFlag == flag then
		g_SelectedFlag = nil
	end
	return SetFlagParent( flag )
end--SetFlagSelected

--==========================================================
local function FinishMove( flag, unit )
	--debug_flag( flag, "FinishMove" )
	-- Have we changed carrier ?
	local transportUnit = unit:GetTransportUnit()
	local oldTransportUnitID = flag.m_TransportUnitID
	local oldTransportUnit = flag.m_Player:GetUnitByID( oldTransportUnitID ) -- assumes transport cannot have different owner !!!
	if oldTransportUnit ~= transportUnit then
		if oldTransportUnit then
			local oldCarrier = g_UnitFlags[ oldTransportUnit:GetOwner() ][ oldTransportUnitID ]
			if oldCarrier then
				local cargo = oldTransportUnit:GetCargo()
				oldCarrier.CargoBG:SetHide( cargo < 1 )
				oldCarrier.Cargo:SetText( cargo )
			end
		end
		if transportUnit then
			local transportUnitID = transportUnit:GetID()
			flag.m_TransportUnitID = transportUnitID
			local newCarrier = g_UnitFlags[ transportUnit:GetOwner() ][ transportUnitID ]
			if newCarrier then
				local cargo = transportUnit:GetCargo()
				newCarrier.CargoBG:SetHide( cargo < 1 )
				newCarrier.Cargo:SetText( cargo )
			end
		else
			flag.m_TransportUnitID = nil
		end
	end
	-- Have we changed location ?
	local oldPlot = flag.m_Plot
	local newPlot = unit:GetPlot()
	if oldPlot ~= newPlot then
		flag.m_Plot = newPlot
		if oldPlot then
			UpdatePlotFlags( oldPlot )
		end
		if newPlot then
			local x, y, z = GridToWorld( newPlot:GetX(), newPlot:GetY() )
			flag.Anchor:SetWorldPositionVal( x, y, z + 35 ) -- World Position Offset
			return UpdatePlotFlags( newPlot )
		end
	end
end

--==========================================================
local function UpdateFlagType( flag, unit )
	--debug_flag( flag, "UpdateFlagType" )

	local textureName, maskName

	if unit:IsEmbarked() then
		textureName = "UnitFlagEmbark.dds"
		maskName = "UnitFlagEmbarkMask.dds"
		flag.UnitIconShadow:SetOffsetVal( -1, -2 )

	elseif unit:IsGarrisoned() then
		textureName = "UnitFlagBase.dds"
		maskName = "UnitFlagMask.dds"
		flag.UnitIconShadow:SetOffsetVal( -1, 1 )

	elseif unit:GetFortifyTurns() > 0 then
		textureName = "UnitFlagFortify.dds"
		maskName = "UnitFlagFortifyMask.dds"
		flag.UnitIconShadow:SetOffsetVal( -1, 0 )

	elseif flag.m_IsTrade then
		textureName = "UnitFlagTrade.dds"
		maskName = "UnitFlagTradeMask.dds"
		flag.UnitIconShadow:SetOffsetVal( -1, 0 )

	elseif flag.m_IsCivilian then
		textureName = "UnitFlagCiv.dds"
		maskName = "UnitFlagCivMask.dds"
		flag.UnitIconShadow:SetOffsetVal( -1, -3 )
	else
		textureName = "UnitFlagBase.dds"
		maskName = "UnitFlagMask.dds"
		flag.UnitIconShadow:SetOffsetVal( -1, 0 )
	end

	flag.UnitIconShadow:ReprocessAnchoring()

	flag.FlagShadow:SetTexture( textureName )
	flag.FlagBase:SetTexture( textureName )
	flag.FlagBaseOutline:SetTexture( textureName )
	flag.LightEffect:SetTexture( textureName )
	flag.HealthBarBG:SetTexture( textureName )
	flag.AlphaAnim:SetTexture( textureName )
	flag.FlagHighlight:SetTexture( textureName )
	return flag.ScrollAnim:SetMask( maskName )
end--UpdateFlagType

--==========================================================
local function UpdateFlagHealth( flag, damage )
	--debug_flag( flag, "UpdateFlagHealth, damage=", damage )
	if damage > 0 then
		local healthPercent = 1 - damage / flag.m_MaxHitPoints
		if healthPercent > 0.66 then
			flag.HealthBar:SetFGColor( ColorGreen )
		elseif healthPercent > 0.33 then
			flag.HealthBar:SetFGColor( ColorYellow )
		elseif healthPercent > 0 then
			flag.HealthBar:SetFGColor( ColorRed )
		else --unit is dead...
			healthPercent = 0
		end
		-- show the health bar
		flag.HealthBar:SetPercent( healthPercent )
		flag.HealthBarBG:SetHide( false )
		flag.HealthBar:SetHide( false )
		flag.AlphaAnim:SetTextureOffsetVal( 64, 64 )
		flag.FlagHighlight:SetTextureOffsetVal( 64, 128 )
	else --full health
		-- hide the health bar
		flag.HealthBarBG:SetHide( true )
		flag.HealthBar:SetHide( true )
		flag.AlphaAnim:SetTextureOffsetVal( 0, 64 )
		flag.FlagHighlight:SetTextureOffsetVal( 0, 128 )
	end
--	return flag.CargoBG:SetOffsetX( 35 )
end--UpdateFlagHealth

--==========================================================
local UnitFlagToolTipCall = LuaEvents.UnitFlagToolTip.Call
local function UnitFlagToolTip( button )
	button:SetToolTipCallback( UnitFlagToolTipCall )
	button:SetToolTipType( "EUI_UnitTooltip" )
end

local function CreateNewFlag( playerID, unitID, isSelected, isHiddenByFog, isInvisibleToActiveTeam )

	--debug_unit( playerID, unitID, "CreateNewFlag, isSelected=", isSelected, "isHiddenByFog", isHiddenByFog, "isInvisibleToActiveTeam", isInvisibleToActiveTeam )
	local player = Players[ playerID ]
	local unit = player and player:GetUnitByID( unitID )
	if unit and not unit:IsDead() then

		local teamID = player:GetTeam()
		local isAircraft = false
		local isCivilian = false
		local parentContainer
		if unit:IsCombatUnit() and not unit:IsEmbarked() then
			parentContainer = g_MilitaryFlags
		elseif unit:GetDomainType() == DOMAIN_AIR then
			parentContainer = g_AirCraftFlags
			isAircraft = true
		else
			parentContainer = g_CivilianFlags
			isCivilian = true
		end

		local flag = remove( g_spareNewUnitFlags )
		if flag then
			flag.Anchor:ChangeParent( parentContainer )
			flag.FlagHighlight:SetColor( ColorWhite )
		else
			flag = { m_PromotionIcons = {} }
			ContextPtr:BuildInstanceForControl( "UnitFlag", flag, parentContainer )
			flag.Button:RegisterCallback( Mouse.eLClick, UnitFlagClicked )
			if MouseoverUnit then
	            flag.Button:RegisterCallback( Mouse.eMouseEnter, UnitFlagEnter )
	            flag.Button:RegisterCallback( Mouse.eMouseExit, UnitFlagExit )
			end
			flag.Cargo:RegisterCallback( Mouse.eLClick, CargoFlagClicked )
			flag.Button:SetToolTipCallback( UnitFlagToolTip )
		end
		---------------------------------------------------------
		-- Set up the buttons
		flag.Cargo:SetVoids( playerID, unitID )
		flag.Button:SetVoids( playerID, unitID )

		---------------------------------------------------------
		-- Store the flag and set up data
		g_UnitFlags[ playerID ][ unitID ] = flag
		flag.m_TransportUnitID = nil
		flag.m_IsAirCraft = isAircraft
		flag.m_IsCivilian = isCivilian
		flag.m_IsGarrisoned = unit:IsGarrisoned()
		flag.m_IsHiddenByFog = isHiddenByFog
		flag.m_IsInvisibleToActiveTeam = isInvisibleToActiveTeam
		flag.m_Plot = nil
		flag.m_IsSelected = isSelected
		flag.m_IsTrade = unit.IsTrade and unit:IsTrade()
		flag.m_MaxHitPoints = unit:GetMaxHitPoints()
		flag.m_Player = player
		flag.m_PlayerID = playerID
		flag.m_UnitID = unitID

		---------------------------------------------------------
		-- Set flag color
		flag.FlagBase:SetColor( BackgroundColors[ playerID ] )
		local color = PrimaryColors[  playerID ]
		flag.UnitIcon:SetColor( color )
		flag.FlagBaseOutline:SetColor( color )

		---------------------------------------------------------
		-- Set flag textures
		local flagOffset, flagAtlas = GetUnitFlagIcon( unit )
		local textureOffset, textureSheet = IconLookup( flagOffset, 32, flagAtlas )
		flag.UnitIcon:SetTexture( textureSheet )
		flag.UnitIconShadow:SetTexture( textureSheet )
		flag.UnitIcon:SetTextureOffset( textureOffset )
		flag.UnitIconShadow:SetTextureOffset( textureOffset )

		---------------------------------------------------------
		-- Is it carrying units (cargo)
		local cargo = unit:GetCargo()
		flag.CargoBG:SetHide( cargo < 1 )
		flag.Cargo:SetText( cargo )

		---------------------------------------------------------
		-- Set up other info
		flag.Anchor:SetHide( isHiddenByFog or isInvisibleToActiveTeam )
		flag.FlagShadow:SetAlpha( unit:CanMove() and 1 or 0.5 )
		flag.Button:SetDisabled( g_activeTeamID ~= teamID )
		flag.Button:SetConsumeMouseOver( g_activeTeamID == teamID )
		UpdateFlagType( flag, unit )
		UpdateFlagHealth( flag, unit:GetDamage() )
		SetFlagSelected( flag, isSelected )
		if g_activeTeam:IsAtWar( teamID ) then
			flag.m_IsAtWar = true
			flag.FlagHighlight:SetHide( false )
			flag.FlagHighlight:SetColor( ColorRed )
		else
			flag.m_IsAtWar = false
		end
		FinishMove( flag, unit )

--		return flag
--	else
		--debug_unit( playerID, unitID, "is nil or dead" )
	end

end--CreateNewFlag

--==========================================================
local function DestroyFlag( flag )
	--debug_flag( flag, "DestroyFlag" )
	flag.Anchor:ChangeParent( g_HiddenControls )
	insert( g_spareNewUnitFlags, flag )
	g_UnitFlags[ flag.m_PlayerID ][ flag.m_UnitID ] = nil
	if flag.m_Plot then
		return UpdatePlotFlags( flag.m_Plot )
	end
end--DestroyFlag

--==========================================================
local function ForceHide( playerID, unitID, isForceHide )
	--debug_unit( playerID, unitID, "ForceHide, isForceHide=", isForceHide )
	local flag = g_UnitFlags[ playerID ][ unitID ]
	if flag then
		return flag.Anchor:SetHide( isForceHide or flag.m_IsHiddenByFog or flag.m_IsInvisibleToActiveTeam )
	end
end--ForceHide

-- GameplayUnitDestroyed GameplayUnitEmbark GameplayUnitCreated GameplayUnitShouldDimFlag GameplayUnitSetDamage GameplayUnitVisibility GameplayUnitTeleported
-- GameplayUnitWork GameplayUnitGarrison GameplayUnitFortify GameplayUnitParadrop GameplayUnitRebased GameplayUnitActivate GameplayUnitMoved GameplayUnitMissionEnd

--==========================================================
-- GameplayUnitCreated fires upon unit creation
--==========================================================
Events.SerialEventUnitCreated.Add(
function( playerID, unitID, hexPos, unitType, cultureType, civID, primaryColor, secondaryColor, unitFlagIndex, fogState, isSelected, isMilitary, isVisible )
	--debug_unit( playerID, unitID, "SerialEventUnitCreated, fogState=", fogState, "isSelected=", isSelected, "isVisible=", isVisible, "XY=", ToGridFromHex( hexPos.x, hexPos.y ) )
	return CreateNewFlag( playerID, unitID, isSelected, fogState ~= 2, not isVisible ) -- fogState ~= eyes on
end)

--==========================================================
-- Update stuff while the game engine walks a unit around
--==========================================================
Events.LocalMachineUnitPositionChanged.Add(
function( playerID, unitID, unitPosition )
	--debug_unit( playerID, unitID, "LocalMachineUnitPositionChanged" )
	local flag = g_UnitFlags[ playerID ][ unitID ]
	local unit = flag and flag.m_Player:GetUnitByID( unitID )
	if unit then
		--debug_flag( flag, "Setting flag position while moving" )
		flag.Anchor:SetWorldPositionVal( unitPosition.x, unitPosition.y, unitPosition.z + 35 ) -- World Position Offset
		local plot = flag.m_Plot
		if plot then
			if UnitMoving( playerID, unitID ) then
				flag.m_Plot = nil
			end
			local targetPlot = unit:GetPlot()
			if targetPlot ~= plot then
				UpdatePlotFlags( plot )
				--debug_flag( flag, "starting to move: setting flag offset to", 0, 0 )
				return flag.Container:SetOffsetVal( 0, 0 )
			end
		end
	else
		--debug_unit( playerID, unitID, "not found for LocalMachineUnitPositionChanged" )
	end
end)

--==========================================================
-- Change flag type upon UnitActionChanged or GameplayUnitEmbark
--==========================================================
local function OnFlagTypeChange( playerID, unitID )
	--debug_unit( playerID, unitID, "OnFlagTypeChange" )
	local flag = g_UnitFlags[ playerID ][ unitID ]
	local unit = flag and flag.m_Player:GetUnitByID( unitID )
	if unit then
		return UpdateFlagType( flag, unit )
	end
end
Events.UnitActionChanged.Add( OnFlagTypeChange )
Events.UnitEmbark.Add( OnFlagTypeChange )

--==========================================================
-- Update stuff when game completes unit move or GameplayUnitTeleported
--==========================================================
local function OnUnitMoveQueueChanged( playerID, unitID )--, hasRemainingMoves )
	--debug_unit( playerID, unitID, "OnUnitMoveQueueChanged, hasRemainingMoves=", hasRemainingMoves )
	local flag = g_UnitFlags[ playerID ][ unitID ]
	local unit = flag and flag.m_Player:GetUnitByID( unitID )
	if unit then
		return FinishMove( flag, unit )
	end
end
Events.UnitMoveQueueChanged.Add( OnUnitMoveQueueChanged )

Events.SerialEventUnitTeleportedToHex.Add(
function( hexX, hexY, playerID, unitID )
	--debug_unit( playerID, unitID, "SerialEventUnitTeleportedToHex, XY=", ToGridFromHex( hexX, hexY ) )
	-- nukes teleport instead of moving
	-- spoof out the move queue changed logic.
	return OnUnitMoveQueueChanged( playerID, unitID )
end)

--==========================================================
-- GameplayUnitVisibility fires when unit visibility changes
--==========================================================
Events.UnitVisibilityChanged.Add(
function( playerID, unitID, isVisible, checkFlag )--, blendTime )
	--debug_unit( playerID, unitID, "UnitVisibilityChanged, isVisible=", isVisible, "checkFlag=", checkFlag )
	if checkFlag then
		local flag = g_UnitFlags[ playerID ][ unitID ]
		if flag then
			flag.m_IsInvisibleToActiveTeam = not isVisible
			return flag.Anchor:SetHide( not isVisible or flag.m_IsHiddenByFog )
		end
	end
end)

--==========================================================
-- GameplayUnitDestroyed fires when unit is destroyed
--==========================================================
Events.SerialEventUnitDestroyed.Add(
function( playerID, unitID )
	--debug_unit( playerID, unitID, "SerialEventUnitDestroyed" )
	local flag = g_UnitFlags[ playerID ][ unitID ]
	if flag then
		return DestroyFlag( flag )
	else
		--debug_unit( playerID, unitID, "flag not found for SerialEventUnitDestroyed" )
	end
end)

--==========================================================
-- On Unit Selection Change
--==========================================================
Events.UnitSelectionChanged.Add(
function( playerID, unitID, _, _, _, isSelected )
	--debug_unit( playerID, unitID, "UnitSelectionChanged, isSelected=", isSelected )
	local flag = g_UnitFlags[ playerID ][ unitID ]
	if flag then
		return SetFlagSelected( flag, isSelected )
	else
		--debug_unit( playerID, unitID, "flag not found for UnitSelectionChanged", isSelected )
	end
end)

--==========================================================
-- GameplayUnitSetDamage fires when damage actually changes
--==========================================================
Events.SerialEventUnitSetDamage.Add(
function( playerID, unitID, damage )--, previousDamage )
	-- !!! can be called for dead unit !!!
	--debug_unit( playerID, unitID, "SerialEventUnitSetDamage, damage=", damage )
	local flag = g_UnitFlags[ playerID ][ unitID ]
	if flag then
		return UpdateFlagHealth( flag, damage )
	else
		--debug_unit( playerID, unitID, "flag not found for SerialEventUnitSetDamage" )
	end
end)

--==========================================================
-- This fires when a hex is seen or unseen
--==========================================================
Events.HexFOWStateChanged.Add(
function( hexPos, fogState, isWholeMap )
	--debug_print( "HexFOWStateChanged, fogState=", fogState, "isWholeMap=", isWholeMap, "XY=", ToGridFromHex( hexPos.x, hexPos.y ) )
	local isInvisible = fogState ~= 2 -- eyes on
	if isWholeMap then
		-- unit flags
		for _, flags in pairs( g_UnitFlags ) do
			for _, flag in pairs( flags ) do
				flag.m_IsHiddenByFog = isInvisible
				flag.Anchor:SetHide( isInvisible or flag.m_IsInvisibleToActiveTeam )
			end
		end
		-- city flags
		for _, flag in pairs( g_AirbaseFlags ) do
			flag.Anchor:SetHide( isInvisible )
		end
	else
		local plot = GetPlot( ToGridFromHex( hexPos.x, hexPos.y ) )
		if plot then
			-- unit flags
			for i = 0, GetPlotNumUnits( plot ) - 1 do
				local unit = GetPlotUnit( plot, i )
				local flag = unit and g_UnitFlags[ unit:GetOwner() ][ unit:GetID() ]
				if flag then
					flag.m_IsHiddenByFog = isInvisible
					flag.Anchor:SetHide( isInvisible or flag.m_IsInvisibleToActiveTeam )
				end
			end
			-- city flag
			local flag = g_AirbaseFlags[ plot:GetPlotIndex() ]
			if flag then
				flag.Anchor:SetHide( isInvisible )
			end
		end
	end
end)

--==========================================================
-- This fires when a unit moves into or out of the fog
--==========================================================
Events.UnitStateChangeDetected.Add(
function( playerID, unitID, fogState )
	--debug_unit( playerID, unitID, "UnitStateChangeDetected, fogState=", fogState )
	local flag = g_UnitFlags[ playerID ][ unitID ]
	if flag then
		flag.m_IsHiddenByFog = fogState ~= 2 -- eyes on
		return flag.Anchor:SetHide( fogState ~=2 or flag.m_IsInvisibleToActiveTeam )
	else
		--debug_unit( playerID, unitID, "flag not found for UnitStateChangeDetected", fogState )
	end
end)

--==========================================================
-- GameplayUnitShouldDimFlag fires right after GameplayUnitCreated
-- or when a unit wakes up or when setMoves is called
--==========================================================
Events.UnitShouldDimFlag.Add(
function( playerID, unitID, isDimmed )
	--debug_unit( playerID, unitID, "UnitShouldDimFlag, isDimmed=", isDimmed )
	local flag = g_UnitFlags[ playerID ][ unitID ]
	local unit = flag and flag.m_Player:GetUnitByID( unitID )
	if unit then
		flag.FlagShadow:SetAlpha( isDimmed and 0.5 or 1.0 )
		-- Update movement pip
		if isDimmed or not unit:HasMoved() then
			flag.MovementPip:SetHide( true )
		else
			-- 0 is cyan (green), 32 is green (yellow), 64 is red, and 96 is orange (gray)
			flag.MovementPip:SetTextureOffsetVal( 0, unit:IsCombatUnit() and unit:IsOutOfAttacks() and 96 or 32 )
			flag.MovementPip:SetHide( false )
		end
		-- Update promotions
		return UpdateFlagPromotions( flag )
	else
		--debug_unit( playerID, unitID, "flag not found for UnitShouldDimFlag" )
	end
end)

--[[
--==========================================================
-- GameplayUnitGarrison fires when unit is (un)garrisonned
--==========================================================
Events.UnitGarrison.Add(
function( playerID, unitID, isGarrisoned )
	--debug_unit( playerID, unitID, "UnitGarrison, isGarrisoned=", isGarrisoned )
	local flag = g_UnitFlags[ playerID ][ unitID ]
	local unit = flag and flag.m_Player:GetUnitByID( unitID )
	if unit then
		flag.m_IsGarrisoned = isGarrisoned
		SetFlagParent( flag )
		return UpdateFlagType( flag, unit )
	end
end)
--]]
--==========================================================
-- Update plot flags when a city is created, destroyed, or captured
--==========================================================
local function OnCity( hexPos )
	--debug_print( "SerialEventCityDestroyed or SerialEventCityCaptured, XY=", ToGridFromHex( hexPos.x, hexPos.y ) )
	local plot = GetPlot( ToGridFromHex( hexPos.x, hexPos.y ) )
	if plot then
		return UpdatePlotFlags( plot )
	end
end
Events.SerialEventCityDestroyed.Add( OnCity )
Events.SerialEventCityCaptured.Add( OnCity )
Events.SerialEventCityCreated.Add( OnCity )

Events.SerialEventEnterCityScreen.Add(
function()
	return g_SelectedFlags:SetHide( true )
end)
Events.SerialEventExitCityScreen.Add(
function()
	return g_SelectedFlags:SetHide( InStrategicView() )
end)

--==========================================================
Events.StrategicViewStateChanged.Add( function( isStrategicView, isCityBanners )
	--debug_print( "StrategicViewStateChanged, isStrategicView=", isStrategicView, "isCityBanners=", isCityBanners )
	g_CivilianFlags:SetHide( isStrategicView )
	g_MilitaryFlags:SetHide( isStrategicView )
	g_GarrisonFlags:SetHide( isStrategicView and not isCityBanners )
	g_AirbaseControls:SetHide( isStrategicView )
	return g_SelectedFlags:SetHide( isStrategicView ) -- todo iscityscreenup
end)

--==========================================================
-- Hide flag during combat
--==========================================================
Events.RunCombatSim.Add(
function( attackerPlayerID,
		attackerUnitID,
		attackerUnitDamage,
		attackerFinalUnitDamage,
		attackerMaxHitPoints,
		defenderPlayerID,
		defenderUnitID,
		defenderUnitDamage,
		defenderFinalUnitDamage,
		defenderMaxHitPoints,
		bContinuation )
	--debug_unit( attackerPlayerID, attackerUnitID, "RunCombatSim", attackerUnitDamage, attackerFinalUnitDamage, attackerMaxHitPoints, defenderPlayerID, defenderUnitID, defenderUnitDamage, defenderFinalUnitDamage, defenderMaxHitPoints, bContinuation )
	ForceHide( attackerPlayerID, attackerUnitID, true )
	return ForceHide( defenderPlayerID, defenderUnitID, true )
end)

--==========================================================
-- Show flag after combat
--==========================================================
Events.EndCombatSim.Add(
function( attackerPlayerID,
		attackerUnitID,
		attackerUnitDamage,
		attackerFinalUnitDamage,
		attackerMaxHitPoints,
		defenderPlayerID,
		defenderUnitID,
		defenderUnitDamage,
		defenderFinalUnitDamage,
		defenderMaxHitPoints )
	--debug_unit( attackerPlayerID, attackerUnitID, "EndCombatSim", attackerUnitDamage, attackerFinalUnitDamage, attackerMaxHitPoints, defenderPlayerID, defenderUnitID, defenderUnitDamage, defenderFinalUnitDamage, defenderMaxHitPoints )
	ForceHide( attackerPlayerID, attackerUnitID, false )
	return ForceHide( defenderPlayerID, defenderUnitID, false )
end)

--==========================================================
-- War Declared
--==========================================================
Events.WarStateChanged.Add(
function( teamID1, teamID2, isAtWar )
	if teamID1 == g_activeTeamID then
		teamID1 = teamID2
	elseif teamID2 ~= g_activeTeamID then
		return
	end
	for playerID, player in pairs( Players ) do
		if player and player:IsAlive() and player:GetTeam() == teamID1 then
			for _, flag in pairs( g_UnitFlags[ playerID ] ) do
				flag.m_IsAtWar = isAtWar
				flag.FlagHighlight:SetHide( not isAtWar )
				flag.FlagHighlight:SetColor( isAtWar and ColorRed or ColorWhite )
				UpdateFlagPromotions( flag )
			end
		end
	end
end)

--==========================================================
-- 'Active' (local human) player has changed TODO
--==========================================================
Events.GameplaySetActivePlayer.Add( function( activePlayerID )--, iPrevActivePlayerID )
	--debug_print( "GameplaySetActivePlayer, activePlayerID=", activePlayerID )
	g_activePlayerID = activePlayerID
	g_activeTeamID = GetActiveTeam()
	g_activePlayer = Players[ activePlayerID ]
	g_activeTeam = Teams[ g_activeTeamID ]
	if g_SelectedFlag then
		SetFlagSelected( g_SelectedFlag, false )
	end
	for playerID, player in pairs( Players ) do
		if player and player:IsAlive() then
			local teamID = player:GetTeam()
			local isActiveTeam = teamID == g_activeTeamID
			local isAtWar = g_activeTeam:IsAtWar( teamID )
			for _, flag in pairs( g_UnitFlags[ playerID ] ) do
				flag.m_IsAtWar = isAtWar
				flag.Button:SetDisabled( not isActiveTeam )
				flag.Button:SetConsumeMouseOver( isActiveTeam )
				flag.FlagHighlight:SetHide( not isAtWar )
				flag.FlagHighlight:SetColor( isAtWar and ColorRed or ColorWhite )
				UpdateFlagPromotions( flag )
			end
		end
	end
end)

--==========================================================
-- On shutdown, we need to get our children back,
-- or they will get duplicted on future hotload
-- and we'll assert clearing the registered button handler
--==========================================================
ContextPtr:SetShutdown( function()
	--debug_print( "SetShutdown" )
--[[
	local flagPromotionIcons
	for unitID, flag in pairs( g_RibbonUnits ) do
		flagPromotionIcons = flag.m_PromotionIcons
		for promotionID, promotionIcon in pairs( flagPromotionIcons ) do
			flagPromotionIcons[ promotionID ] = nil
			promotionIcon:ChangeParent( ContextPtr )
		end
	end
--]]
	return g_SelectedFlags:ChangeParent( ContextPtr )
end)

do
--==========================================================
-- Initilize flags for all units 
-- during initial load or subsequent hotload
--==========================================================
	local plot
	for playerID, player in pairs( Players ) do
		-- DestroyFlag any existing unit flags
		for _, flag in pairs( g_UnitFlags[ playerID ] ) do
			DestroyFlag( flag )
		end
		-- Create unit flags for that player
		if player and player:IsEverAlive() then
			for unit in player:Units() do
				plot = unit:GetPlot()
				CreateNewFlag( playerID, unit:GetID(), unit:IsSelected(), plot and not plot:IsVisible( g_activeTeamID, true ), unit:IsInvisible( g_activeTeamID, true ) )
			end
		end
	end

--==========================================================
-- Handle flag promotions option change
--==========================================================
	local function UpdateOptions()
		g_visiblePromotionsIfOptionIsActive = UserInterfaceSettings.FlagPromotions ~= 0 and g_visiblePromotions or foreverEmptyTable
		UpdateAllFlagPromotions()
	end
	Events.GameOptionsChanged.Add( UpdateOptions )
	UpdateOptions()
end
end)