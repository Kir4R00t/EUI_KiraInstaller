----------------------------------------------------------------
----------------------------------------------------------------
local IsBNW = Game.GetActiveLeague ~= nil
local IsGK = Game.GetReligionName ~= nil

--Controls.DiploDetails:SetHide( IsBNW )

local ipairs = ipairs
local min = math.min
local max = math.max
local floor = math.floor
local pairs = pairs
local insert = table.insert
local sort = table.sort

include "GameInfoCache" -- warning! booleans are true, not 1, and use iterator ONLY with table field conditions, NOT string SQL query
local GameInfo = GameInfoCache

include( "IconHookup" )
local CivIconHookup = CivIconHookup
local IconHookup = IconHookup

include( "StackInstanceManager" )
local StackInstanceManager = StackInstanceManager

local Controls = Controls
local Events = Events
local Game = Game
local GameInfoTypes = GameInfoTypes
local GameOptionTypes = GameOptionTypes
local L = Locale.ConvertTextKey
local Players = Players
local PreGame = PreGame
local Teams = Teams
local ContextPtr = ContextPtr
local UIManager = UIManager
local KeyDown = KeyEvents.KeyDown
local VK_RETURN = Keys.VK_RETURN
local VK_ESCAPE = Keys.VK_ESCAPE
local eLClick = Mouse.eLClick
local incTurnTimerSemaphore = UI.incTurnTimerSemaphore
local decTurnTimerSemaphore = UI.decTurnTimerSemaphore
local BUTTONPOPUP_VICTORY_INFO = ButtonPopupTypes.BUTTONPOPUP_VICTORY_INFO
local MAX_MAJOR_CIVS_M1 = GameDefines.MAX_MAJOR_CIVS-1
local MAX_CIV_TEAMS_M1 = GameDefines.MAX_CIV_TEAMS-1
local PopupPriorityInGameUtmost = PopupPriority.InGameUtmost
local PopupPriorityVictoryProgress = PopupPriority.VictoryProgress
local MajorCivApproachTypes = MajorCivApproachTypes
local InfluenceLevelTrend = InfluenceLevelTrend
local InfluenceLevelTypes = InfluenceLevelTypes

local g_DominationIM = StackInstanceManager( "DominationItem", "Item", Controls.DominationStack )
local g_ScoreCivIM = StackInstanceManager( "ScoreCiv", "Row", Controls.ScoreStack );
local g_TechCivIM = StackInstanceManager( "TechCiv", "Row", Controls.TechStack )
local g_MySpaceshipPartsIM = StackInstanceManager( "IconItem", "Item" )
local g_SpaceshipPartsIM = StackInstanceManager( "IconItem", "Item" )
local g_DiploCivIM = StackInstanceManager( "DiploCiv", "Row", Controls.DiploStack )
local g_CultureRivalsIM = StackInstanceManager( IsBNW and "CultureItem" or "IconItem", "Item" )
local g_MyCultureRivalsIM = StackInstanceManager( IsBNW and "CultureItem" or "IconItem", "Item" )
local g_CultureCivIM = StackInstanceManager( "CultureCiv", "Row", Controls.CultureCivs );
local g_white = Color( 1, 1, 1, 1 )
local g_dark = Color( 1, 1, 1, 0.25 )
local colorRed = Color( 1, 0, 0, 1 )
local colorMagenta = Color( 1, 0, 1, 1 )
local g_ApolloProject = GameInfo.Projects.PROJECT_APOLLO_PROGRAM
local g_ApolloTech = g_ApolloProject and GameInfo.Technologies[ g_ApolloProject.TechPrereq ]
local g_IsNetworkMultiPlayer = Game.IsNetworkMultiPlayer()

----------------------------------------------------------------
----------------------------------------------------------------
local function sortFunction( a, b )
	return a.Sort > b.Sort
end

local function GetPlayerName( player, isCiv )
	if not player then
		return "TXT_KEY_MISC_UNKNOWN"
	elseif player:GetID() == Game.GetActivePlayer() then
		return "TXT_KEY_POP_VOTE_RESULTS_YOU"
	elseif g_IsNetworkMultiPlayer then
		local name = player:GetNickName()
		if name ~= "" then
			return name
		end
	end
	if isCiv then
		return player:GetCivilizationShortDescription()
	else
		return player:GetName()
	end
end

local function SetLeaderIcon( player, size, control )
	local team = Teams[ player:GetTeam() ]
	local leader = ( team and team:IsHasMet(Game.GetActiveTeam()) or g_IsNetworkMultiPlayer ) and GameInfo.Leaders[ player:GetLeaderType() ]
	IconHookup( leader and leader.PortraitIndex or 22, size, leader and leader.IconAtlas or "LEADER_ATLAS", control )
end

local function SetTeamCivIcon( show, player, iconSize, iconControl, controlBG, controlShadow, controlDead, lostCondition )
	-- Set Civ Icon
	CivIconHookup( show and player:GetID(), iconSize, iconControl, controlBG, controlShadow )
	-- X out and gray any icons of civs who have lost capitals
	if controlDead then
		controlDead:SetHide( not lostCondition )
	elseif lostCondition then
		controlBG:SetColor( g_dark )
	end
	-- Set Civ name as tooltip
	controlBG:LocalizeAndSetToolTip( GetPlayerName( show and player, true ) )
end

local function SetCivIcon( player, ... )
	local team = Teams[ player:GetTeam() ]
	return SetTeamCivIcon( g_IsNetworkMultiPlayer or team and team:IsHasMet( Game.GetActiveTeam() ), player, ... )
end

local function SetCivNameAndIcon( player, number, label, ... )
	local team = Teams[ player:GetTeam() ]
	local show = g_IsNetworkMultiPlayer or team and team:IsHasMet( Game.GetActiveTeam() )
	label:SetText( L("TXT_KEY_NUMBERING_FORMAT", number) .. " " .. ( show and L( "TXT_KEY_RANDOM_LEADER_CIV", GetPlayerName( player ), player:GetCivilizationShortDescription() ) or L"TXT_KEY_MISC_UNKNOWN" ) )
	return SetTeamCivIcon( show, player, ... )
end

----------------------------------------------------------------
----------------------------------------------------------------
local function PopulateScoreBreakdown()
	local player = Players[Game.GetActivePlayer()];
	local b = PreGame.IsVictory( GameInfoTypes.VICTORY_TIME )
	Controls.ScoreDetails:SetHide( not b )
	Controls.TimeStack:SetHide( not b )
	Controls.TimeVictoryDisabledBox:SetHide( b )
	if b then
		Controls.Score:SetText( player:GetScore() )
		Controls.Cities:SetText( player:GetScoreFromCities() )
		Controls.Population:SetText( player:GetScoreFromPopulation() )
		Controls.Land:SetText( player:GetScoreFromLand() )
		Controls.Wonders:SetText( player:GetScoreFromWonders() )
		b = Game.IsOption( GameOptionTypes.GAMEOPTION_NO_SCIENCE )
		Controls.Tech:SetHide( b )
		Controls.FutureTech:SetHide( b )
		if not b then
			Controls.Tech:SetText(player:GetScoreFromTechs());
			Controls.FutureTech:SetText(player:GetScoreFromFutureTech());
		end
		b = not player.GetScoreFromPolicies or Game.IsOption(GameOptionTypes.GAMEOPTION_NO_POLICIES)
		Controls.Policies:SetHide( b )
		if not b then
			Controls.Policies:SetText( player:GetScoreFromPolicies() )
		end
		b = not player.GetScoreFromGreatWorks
		Controls.GreatWorks:SetHide( b )
		if not b then
			Controls.GreatWorks:SetText( player:GetScoreFromGreatWorks() )
		end
		b = not player.GetScoreFromReligion or Game.IsOption(GameOptionTypes.GAMEOPTION_NO_RELIGION)
		Controls.Religion:SetHide( b )
		if not b then
			Controls.Religion:SetText( player:GetScoreFromReligion() )
		end
		b = not( IsBNW and PreGame.GetLoadWBScenario() )
		Controls.Scenario1:SetHide( b )
		Controls.Scenario2:SetHide( b )
		Controls.Scenario3:SetHide( b )
		Controls.Scenario4:SetHide( b )
		if not b then
			Controls.Scenario1:SetText( player:GetScoreFromScenario1() )
			Controls.Scenario2:SetText( player:GetScoreFromScenario2() )
			Controls.Scenario3:SetText( player:GetScoreFromScenario3() )
			Controls.Scenario4:SetText( player:GetScoreFromScenario4() )
		end
		Controls.ScoreDetailsStack:CalculateSize()
		Controls.ScoreDetailsStack:ReprocessAnchoring()
	end
end

----------------------------------------------------------------
----------------------------------------------------------------
local function PopulateDomination()

	local b = PreGame.IsVictory( GameInfoTypes.VICTORY_DOMINATION )
	Controls.DominationVictoryProgress:SetHide( not b )
	Controls.DominationDisabledLabel:SetHide( b )
	if b then
		g_DominationIM:ResetInstances();

		local leadingTeamID, teamID, control, numCapitals
		local originalCapitals = {}
		local teamNumOriginalCapitals = {}
		for _, player in pairs(Players) do
			for city in player:Cities() do
				if city:IsOriginalMajorCapital() then
					originalCapitals[ city:GetOriginalOwner() ] = city
					teamID = city:GetTeam()
					teamNumOriginalCapitals[ teamID ] = (teamNumOriginalCapitals[ teamID ] or 0) + 1
				end
			end
		end

		local activeTeam = Teams[ Game.GetActiveTeam() ]
		local activePlayerID = Game.GetActivePlayer()
		local everyoneControlsTheirCapital = true
		-- Loop through all major civs
		for playerID = 0, MAX_MAJOR_CIVS_M1 do

			local player = Players[playerID]

			if player and player:IsEverAlive() then
				local instance = g_DominationIM:GetInstance()

				-- Set Civ Icon
				local hasMetActiveTeam = activeTeam:IsHasMet( player:GetTeam() )
				local hasMetOrMultiplayer = hasMetActiveTeam or g_IsNetworkMultiPlayer
				control = instance.CivIconBG
				CivIconHookup( hasMetOrMultiplayer and playerID, 64, instance.CivIcon, control, instance.CivIconShadow )
				instance.CivDead:SetHide( player:IsAlive() )

				local originalCapital = originalCapitals[playerID]

				if originalCapital then
					local dominatingPlayerID = originalCapital:GetOwner()

					if playerID == dominatingPlayerID then
						if playerID == activePlayerID then
							control:LocalizeAndSetToolTip( "TXT_KEY_VP_DIPLO_TT_YOU_CONTROL_YOUR_CAPITAL", originalCapital:GetName() )
						elseif hasMetActiveTeam then
							control:LocalizeAndSetToolTip( "TXT_KEY_VP_DIPLO_TT_SOMEONE_CONTROLS_THEIR_CAPITAL", GetPlayerName( player ), originalCapital:GetName() )
						else
							control:LocalizeAndSetToolTip( "TXT_KEY_VP_DIPLO_TT_UNMET_CONTROLS_THEIR_CAPITAL" )
						end
						originalCapital = nil -- to hide small dominator civ icon
					else
						everyoneControlsTheirCapital = false
						local dominatingPlayer = Players[ dominatingPlayerID ]
						local dominatorHasMetActiveTeam = activeTeam:IsHasMet( dominatingPlayer:GetTeam() )
						CivIconHookup( dominatorHasMetActiveTeam and dominatingPlayerID, 45, instance.ConqueredCivIcon, instance.ConqueredCivIconBG, instance.ConqueredCivIconShadow )
						if playerID == activePlayerID then
							control:LocalizeAndSetToolTip( "TXT_KEY_VP_DIPLO_TT_OTHER_PLAYER_CONTROLS_YOUR_CAPITAL", GetPlayerName( dominatingPlayer ), originalCapital:GetName() )
						elseif dominatingPlayerID == activePlayerID then
							control:LocalizeAndSetToolTip( "TXT_KEY_VP_DIPLO_TT_YOU_CONTROL_OTHER_PLAYER_CAPITAL", originalCapital:GetName(), player:GetCivilizationShortDescriptionKey() )
						elseif hasMetActiveTeam then
							if dominatorHasMetActiveTeam then
								control:LocalizeAndSetToolTip( "TXT_KEY_VP_DIPLO_TT_OTHER_PLAYER_CONTROLS_OTHER_PLAYER_CAPITAL", GetPlayerName( dominatingPlayer ), originalCapital:GetName(), player:GetCivilizationShortDescriptionKey() )
							else
								control:LocalizeAndSetToolTip( "TXT_KEY_VP_DIPLO_TT_UNMET_PLAYER_CONTROLS_OTHER_PLAYER_CAPITAL", originalCapital:GetName(), player:GetCivilizationShortDescriptionKey() )
							end
						elseif dominatorHasMetActiveTeam then
							control:LocalizeAndSetToolTip( "TXT_KEY_VP_DIPLO_TT_OTHER_PLAYER_CONTROLS_UNMET_PLAYER_CAPITAL", GetPlayerName( dominatingPlayer ) )
						else
							control:LocalizeAndSetToolTip( "TXT_KEY_VP_DIPLO_TT_UNMET_PLAYER_CONTROLS_UNMET_PLAYER_CAPITAL" )
						end
					end
				else
					everyoneControlsTheirCapital = false
					if playerID == activePlayerID then
						control:LocalizeAndSetToolTip( "TXT_KEY_VP_DIPLO_TT_YOU_NO_CAPITAL" )
					elseif hasMetOrMultiplayer then
						control:LocalizeAndSetToolTip( "TXT_KEY_VP_DIPLO_TT_KNOWN_NO_CAPITAL", GetPlayerName( player ) )
					else
						control:LocalizeAndSetToolTip( "TXT_KEY_VP_DIPLO_TT_UNKNOWN_NO_CAPITAL" )
					end
				end
				instance.ConqueredCivSmallFrame:SetHide( not originalCapital )

				local team = Teams[ player:GetTeam() ]
				if team:GetNumMembers() > 1 then
					instance.TeamID:LocalizeAndSetText( "TXT_KEY_MULTIPLAYER_DEFAULT_TEAM_NAME", team:GetID() + 1 )
				else
					instance.TeamID:SetText()
				end
			end
		end

		local leadingNumCapitals = 0
		for teamID = 0, MAX_CIV_TEAMS_M1 do
			numCapitals = teamNumOriginalCapitals[ teamID ] or 0
			if numCapitals > leadingNumCapitals then
				leadingTeamID = teamID
				leadingNumCapitals = numCapitals
			end
		end
		local leadingTeam = Teams[ leadingTeamID ]
		if everyoneControlsTheirCapital then
			--print("Everybody has their own capital.");
			Controls.DominationLabel:LocalizeAndSetText( "TXT_KEY_VP_DIPLO_NEW_CAPITALS_REMAINING" )
		elseif leadingTeam then
			if leadingTeam == activeTeam then
				--print("The current player's team is winning");
				Controls.DominationLabel:LocalizeAndSetText( "TXT_KEY_VP_DIPLO_CAPITALS_ACTIVE_PLAYER_LEADING", leadingNumCapitals )
			elseif leadingTeam:GetNumMembers() > 1 then
				--print("A team is winning");
				Controls.DominationLabel:LocalizeAndSetText( "TXT_KEY_VP_DIPLO_CAPITALS_TEAM_LEADING", leadingTeamID + 1, leadingNumCapitals )
			elseif activeTeam:IsHasMet(leadingTeamID) then
				--print("Some other player is winning");
				Controls.DominationLabel:LocalizeAndSetText( "TXT_KEY_VP_DIPLO_CAPITALS_PLAYER_LEADING", GetPlayerName( Players[leadingTeam:GetLeaderID()] ), leadingNumCapitals )
			else
				--print("Some unmet player is winning");
				Controls.DominationLabel:LocalizeAndSetText( "TXT_KEY_VP_DIPLO_CAPITALS_UNMET_PLAYER_LEADING", leadingNumCapitals )
			end
		else
			--print("Hiding string");
			Controls.DominationLabel:SetText()
		end

		Controls.DominationStack:CalculateSize();
		Controls.DominationStack:ReprocessAnchoring();
		Controls.DominationScrollPanel:CalculateInternalSize();
	end
end

----------------------------------------------------------------
----------------------------------------------------------------
local function PopulateSpaceProject( player, team, spaceshipPartsIM, stack, apolloIcon, bubblesAnim, techProgress, techPathLength )
	local apolloBuilt = team:GetProjectCount( g_ApolloProject.ID ) > 0
	local hasApolloTech = team:IsHasTech( g_ApolloTech.ID )
	apolloIcon:SetColor( apolloBuilt and g_white or g_dark )
	bubblesAnim:SetHide( apolloBuilt or hasApolloTech )
	techProgress:SetHide( apolloBuilt )
	if apolloBuilt then
		-- for row in GameInfo.Project_VictoryThresholds{ VictoryType="VICTORY_SPACE_RACE" } do
			-- local project = GameInfo.Projects[ row.ProjectType ]
			-- if project then
		for project in GameInfo.Projects{ Spaceship = true } do
			local row = GameInfo.Project_VictoryThresholds{ ProjectType = project.Type }()
			if row then
				local n = team:GetProjectCount( project.ID )
				for i = 1, row.Threshold do
					local instance = spaceshipPartsIM:GetInstance( stack )
					IconHookup( project.PortraitIndex, 80, project.IconAtlas, instance.Icon )
					instance.Icon:SetColor( i<=n and g_white or g_dark )
				end
			end
		end
	else
		local remainingTechs = techPathLength or player:FindPathLength( g_ApolloTech.ID )
		local p = remainingTechs / max( min( team:GetTeamTechs():GetNumTechsKnown(), 20 ) + remainingTechs, 1 )
		local y = techProgress:GetSizeX()
		techProgress:SetTextureOffsetVal( 0, p * 86 )
		techProgress:SetSizeY( (1-p) * y )
		techProgress:SetTextureSizeVal( 86, (1-p) * 86 )
		techProgress:NormalizeTexture()
	end
	stack:CalculateSize()
	stack:ReprocessAnchoring()
end

----------------------------------------------------------------
----------------------------------------------------------------
local function PopulateSpaceRace()
	local b = g_ApolloTech and PreGame.IsVictory( GameInfoTypes.VICTORY_SPACE_RACE )
	Controls.ScienceVictoryProgress:SetHide( not b )
	Controls.ScienceVictoryDisabled:SetHide( b )
	g_MySpaceshipPartsIM:ResetInstances()
	if b then
		local apolloProjectID = g_ApolloProject.ID

		PopulateSpaceProject( Players[ Game.GetActivePlayer() ], Teams[ Game.GetActiveTeam() ], g_MySpaceshipPartsIM, Controls.ApolloProject, Controls.ApolloIcon, Controls.BubblesAnim, Controls.TechProgress )

		local numApollo = 0
		for _, team in pairs(Teams) do
			if team:GetProjectCount( apolloProjectID ) > 0 then
				numApollo = numApollo + 1
			end
		end
		Controls.SpaceInfo:LocalizeAndSetText( "TXT_KEY_VP_DIPLO_PROJECT_PLAYERS_COMPLETE", numApollo, "TXT_KEY_PROJECT_APOLLO_PROGRAM" )
	end
end

----------------------------------------------------------------
----------------------------------------------------------------
local PopulateDiplomatic = IsBNW and function()

	local worldCongressTech = GameInfo.Technologies{ AllowsWorldCongress = true }()
	local victoryID = worldCongressTech and not Game.IsOption("GAMEOPTION_NO_LEAGUES") and PreGame.IsVictory( GameInfoTypes.VICTORY_DIPLOMATIC ) and GameInfoTypes.VICTORY_DIPLOMATIC
	Controls.DiploVictoryProgress:SetHide( not victoryID )
	Controls.DiploVictoryDisabled:SetHide( victoryID )
	local votesHave, votesNeeded, turnsUntilSession, sUNinfo, bUNicon

	if victoryID then
		if Game.GetVictory() == victoryID then
			local team = Teams[ Game.GetWinner() ]
			local player = team and Players[ team:GetLeaderID() ]
			sUNinfo = L( "TXT_KEY_VP_DIPLO_SOMEONE_WON", GetPlayerName( player ) )
		else
			bUNicon = Game.IsUnitedNationsActive()
			local activeLeague = Game.GetNumActiveLeagues() > 0 and Game.GetActiveLeague()
			if activeLeague then
				turnsUntilSession = activeLeague:GetTurnsUntilVictorySession()
				votesHave = activeLeague:CalculateStartingVotesForMember( Game.GetActivePlayer() )
				sUNinfo = bUNicon and L"TXT_KEY_VP_DIPLO_UN_ACTIVE" or L"TXT_KEY_VP_DIPLO_UN_INACTIVE"
				votesNeeded = Game.GetVotesNeededForDiploVictory()
			else
				sUNinfo = L( "TXT_KEY_LEAGUE_NOT_FOUNDED", worldCongressTech.Description )
			end
		end
	else
		sUNinfo = "TXT_KEY_LEAGUE_NOT_FOUNDED_GAME_SETTINGS"
	end
	Controls.UNIcon:SetHide( not bUNicon )
	Controls.UNInfo:SetText( sUNinfo )
	Controls.VotesHaveLabel:SetHide( not votesHave )
	Controls.VotesHave:SetText( votesHave )
	Controls.VotesNeededLabel:SetHide( not votesNeeded )
	Controls.VotesNeeded:SetText( votesNeeded )
	Controls.TurnsUntilSessionLabel:SetHide( not turnsUntilSession )
	Controls.TurnsUntilSession:SetText( turnsUntilSession )
end or function()
	local b = PreGame.IsVictory( GameInfoTypes.VICTORY_DIPLOMATIC )
	Controls.DiploVictoryProgress:SetHide( not b )
	Controls.DiploVictoryDisabled:SetHide( b )
	if b then
		local UNHome
		local totalVotes = 0
		local activeTeam = Teams[ Game.GetActiveTeam() ]
		local player

		for _, team in pairs(Teams) do
			if team:IsHomeOfUnitedNations() then
				UNHome = team
				break
			end
		end
		Controls.UNIcon:SetHide( not UNHome )
--todo		Controls.UNCivFrame:SetHide( not UNHome )
		if UNHome then
			totalVotes = 1
			player = Players[UNHome:GetLeaderID()]
			SetCivIcon( player, 45, Controls.UNCiv, Controls.UNIconBG, Controls.UNIconShadow, Controls.UNCivOut, not player:IsAlive() or Teams[player:GetTeam()]:GetLiberatedByTeam() ~= -1 )
		end
		Controls.UNInfo:LocalizeAndSetText( "TXT_KEY_VP_DIPLO_PROJECT_BUILT_BY", player and GetPlayerName( player, true ) or "TXT_KEY_CITY_STATE_NOBODY", "TXT_KEY_BUILDING_UNITED_NATIONS" )

		-- Set Votes
		for _, team in pairs(Teams) do
			if team:IsAlive() and not team:IsBarbarian() then
				totalVotes = totalVotes + 1
			end
		end

		Controls.VotesHave:SetText( activeTeam:GetTotalSecuredVotes() )
--todo		Controls.VotesTotal:SetText( totalVotes )
		Controls.VotesNeeded:SetText( Game.GetVotesNeededForDiploVictory() )
	end
end

----------------------------------------------------------------
----------------------------------------------------------------
local influenceLevelStrings = { [ 0 ] = L"TXT_KEY_CO_EXOTIC", L"TXT_KEY_CO_FAMILIAR", L"TXT_KEY_CO_POPULAR", L"TXT_KEY_CO_INFLUENTIAL", L"TXT_KEY_CO_DOMINANT", }

local PopulateCivsCulture = IsBNW and function( thisPlayer, cultureCivsIM, stack, label )
	local activeTeam = Teams[ Game.GetActiveTeam() ]
	local hasMetThisPlayer = activeTeam:IsHasMet( thisPlayer:GetTeam() )
	-- Loop through all major civs
	for playerID = 0, MAX_MAJOR_CIVS_M1 do

		local player = Players[ playerID ]

		if player and player ~= thisPlayer and player:IsAlive() then

			local instance = cultureCivsIM:GetInstance( stack )
			local culture = player:GetJONSCultureEverGenerated()
			local influencePercent = culture > 0 and thisPlayer:GetInfluenceOn( playerID ) / culture or 0
			local hasMetPlayer = activeTeam:IsHasMet( player:GetTeam() )
			CivIconHookup( hasMetPlayer and playerID, 64, instance.CivIcon, instance.CivIconBG, instance.CivIconShadow )

			-- Display percentage using a texture segment 42x42
			local h = floor( min(influencePercent,1) * 42 + .5 )
			instance.CultureProgress:SetOffsetVal( 11, 53-h )
			instance.CultureProgress:SetTextureOffsetVal( 89, 54-h )
			instance.CivGlow:SetHide( influencePercent < 1 )
			instance.CivIconBG:SetAlpha( influencePercent + .5 )

			local influenceTrend = thisPlayer:GetInfluenceTrend( playerID )		
			local influenceLevel = thisPlayer:GetInfluenceLevel( playerID )
			local trendTip
			instance.InfluenceTrendIcon:SetTextureSizeVal(36,36)
			instance.InfluenceTrendIcon:NormalizeTexture()
			if influenceTrend == InfluenceLevelTrend.INFLUENCE_TREND_FALLING then
				trendTip = L"TXT_KEY_CO_FALLING"
				instance.InfluenceTrendIcon:SetTextureOffsetVal(0,0)
				instance.InfluenceTrendIcon:SetColor( colorRed )
			elseif influenceTrend == InfluenceLevelTrend.INFLUENCE_TREND_RISING then
				local turnsToInfluential = thisPlayer:GetTurnsToInfluential( playerID )
				instance.InfluenceTrendIcon:SetColor( colorMagenta )
				if turnsToInfluential > 500 then
					trendTip = L"TXT_KEY_CO_RISING_SLOWLY"
					instance.InfluenceTrendIcon:SetTextureOffsetVal(36,0)
				else
					instance.InfluenceTrendIcon:SetTextureOffsetVal(36,36)
					if influenceLevel < InfluenceLevelTypes.INFLUENCE_LEVEL_DOMINANT then
						trendTip = L"TXT_KEY_CO_RISING"
					elseif influenceLevel < InfluenceLevelTypes.INFLUENCE_LEVEL_INFLUENTIAL then
						trendTip = L( "TXT_KEY_CO_INFLUENTIAL_TURNS_TT", turnsToInfluential )
					end
				end
			else  --if influenceTrend == InfluenceLevelTrend.INFLUENCE_TREND_STATIC then
				trendTip = L"TXT_KEY_CO_STATIC"
				instance.InfluenceTrendIcon:SetTextureOffsetVal(99,99)
			end
			if influenceLevelStrings[ influenceLevel ] then
				trendTip = "[NEWLINE]" .. influenceLevelStrings[ influenceLevel ] .."  ".. trendTip
			else
				trendTip = ""
			end
			instance.CivIconBG:SetToolTipString( L( hasMetPlayer and "TXT_KEY_CO_THIRD_PARTY_CULTURE_INFLUENCE" or "TXT_KEY_CO_THIRD_PARTY_CULTURE_INFLUENCE_UNMET",
														hasMetThisPlayer and thisPlayer:GetCivilizationShortDescriptionKey() or "TXT_KEY_RO_WR_UNKNOWN_CIV",
														influencePercent * 100, player:GetCivilizationShortDescriptionKey() ) .. trendTip )
		end
	end
	label:SetText( L"TXT_KEY_CO_INFLUENTIAL" .. ": " .. L( "TXT_KEY_CO_VICTORY_INFLUENTIAL_OF", thisPlayer:GetNumCivsInfluentialOn(), thisPlayer:GetNumCivsToBeInfluentialOn() ) )
	stack:CalculateSize()
	stack:ReprocessAnchoring()
end or function( player, cultureIM, stack, label, project, instance )
	if not instance then
		instance = cultureIM:GetInstance( stack )
		instance = instance.Icon
		IconHookup( project.PortraitIndex, 80, project.IconAtlas, instance )
	end
	-- Utopia icon
	instance:SetColor( Teams[player:GetTeam()]:GetProjectCount( project.ID ) > 0 and g_white or g_dark )
	-- Finished policy branches
	for row in GameInfo.PolicyBranchTypes() do
		if player:IsPolicyBranchFinished( row.ID ) then
			instance = cultureIM:GetInstance( stack )
			instance.Item:LocalizeAndSetToolTip( row.Description )
			instance.Icon:SetTexture( "SocialPolicyActive80.dds" )
			instance.Icon:SetColor( g_white )
		end
	end
	-- Remaining policy branches
	for _ = player:GetNumPolicyBranchesFinished()+1, project.CultureBranchesRequired or 0 do
		instance = cultureIM:GetInstance( stack )
		instance.Item:SetToolTipString()
		instance.Icon:SetTexture( "SocialPolicy80.dds" )
		instance.Icon:SetColor( g_dark )
	end
	stack:CalculateSize()
	stack:ReprocessAnchoring()
end

----------------------------------------------------------------
----------------------------------------------------------------
local PopulateCultural = IsBNW and function()

	local isVictoryCultural = PreGame.IsVictory( GameInfoTypes.VICTORY_CULTURAL )
	Controls.CultureVictoryProgress:SetHide( not isVictoryCultural )
	Controls.CultureVictoryDisabled:SetHide( isVictoryCultural )
	g_MyCultureRivalsIM:ResetInstances()

	if isVictoryCultural then
		PopulateCivsCulture( Players[ Game.GetActivePlayer() ], g_MyCultureRivalsIM, Controls.CultureStack, Controls.CultureLabel )
		Controls.CultureScrollPanel:CalculateInternalSize()
	end

end or function()

	local utopiaProjectInfo = PreGame.IsVictory( GameInfoTypes.VICTORY_CULTURAL ) and GameInfo.Projects.PROJECT_UTOPIA_PROJECT
	Controls.CultureVictoryProgress:SetHide( not utopiaProjectInfo )
	Controls.CultureVictoryDisabled:SetHide( utopiaProjectInfo )
	g_MyCultureRivalsIM:ResetInstances()

	if utopiaProjectInfo then

		local activePlayerID = Game.GetActivePlayer()

		PopulateCivsCulture( Players[ activePlayerID ], g_MyCultureRivalsIM, Controls.CultureStack, Controls.CultureLabel, utopiaProjectInfo, Controls.Utopia )

		local numPolicyBranches = -1
		local leadingPlayer
		for i, player in pairs( Players ) do
			if i ~= activePlayerID and player:IsAlive() and not player:IsMinorCiv() and player:GetNumPolicyBranchesFinished() > numPolicyBranches then
				leadingPlayer = player
				numPolicyBranches = player:GetNumPolicyBranchesFinished()
			end
		end

		local strCiv
		if leadingPlayer and ( g_IsNetworkMultiPlayer or Teams[ Game.GetActiveTeam() ]:IsHasMet( leadingPlayer:GetTeam() ) ) then
			strCiv = leadingPlayer:GetNickName()
			if not g_IsNetworkMultiPlayer or strCiv == "" then
				strCiv = leadingPlayer:GetCivilizationShortDescription()
			end
		end

		Controls.CultureLabel:LocalizeAndSetText( "TXT_KEY_VP_DIPLO_SOCIAL_POLICIES", strCiv or "TXT_KEY_MISC_UNKNOWN", numPolicyBranches, utopiaProjectInfo.CultureBranchesRequired )
	end
end

----------------------------------------------------------------
----------------------------------------------------------------
local function PopulateScoreScreen()
	g_ScoreCivIM:ResetInstances()

	-- Sort players by score
	local sortedPlayerList = {}
	for playerID = 0, MAX_MAJOR_CIVS_M1 do
		local player = Players[ playerID ]
		if player and player:IsEverAlive() then
			insert( sortedPlayerList, { Player = player, Sort = player:GetScore() } )
		end
	end
	sort( sortedPlayerList, sortFunction )

	for i, v in ipairs(sortedPlayerList) do
		local player = v.Player
		local instance = g_ScoreCivIM:GetInstance()
		SetLeaderIcon( player, 64, instance.Portrait )
		SetCivNameAndIcon( player, i, instance.Name, 64, instance.CivIcon, instance.CivIconBG, instance.CivIconShadow, instance.CivDead, not player:IsAlive() )
		instance.Score:SetText( player:GetScore() )
	end

	Controls.ScoreStack:CalculateSize();
	Controls.ScoreStack:ReprocessAnchoring();
	Controls.ScoreScrollPanel:CalculateInternalSize();
end

----------------------------------------------------------------
----------------------------------------------------------------
local function PopulateSpaceRaceScreen()
	g_TechCivIM:ResetInstances()

	if g_ApolloTech then
		-- Sort players by space parts
		local apolloProjectID = g_ApolloProject.ID
		local activeTeam = Teams[ Game.GetActiveTeam() ]
		local sortedPlayerList = {}
		for playerID = 0, MAX_MAJOR_CIVS_M1 do
			local player = Players[playerID]
			if player and player:IsEverAlive() and activeTeam:IsHasMet( player:GetTeam() ) then
				local teamID = player:GetTeam()
				local team = Teams[ teamID ]
				local techPathLength = player:FindPathLength( g_ApolloTech.ID )
				local parts = -techPathLength / 100000
				if team:GetProjectCount(apolloProjectID) > 0 then
					parts = parts+1
					for project in GameInfo.Projects{ Spaceship = true } do
						parts = parts + team:GetProjectCount( project.ID )
					end
				end
				insert( sortedPlayerList, { Sort = parts, Player = player, Team = team, TechPathLength = techPathLength } )
			end
		end
		sort( sortedPlayerList, sortFunction )

		g_SpaceshipPartsIM:ResetInstances()
		for i, v in ipairs(sortedPlayerList) do
			local player = v.Player
			local team = v.Team
			local instance = g_TechCivIM:GetInstance()
			SetCivNameAndIcon( player, i, instance.Name, 45, instance.CivIcon, instance.CivIconBG, instance.CivIconShadow, instance.CivDead, not player:IsAlive() )
			PopulateSpaceProject( player, team, g_SpaceshipPartsIM, instance.ApolloProject, instance.ApolloIcon, instance.BubblesAnim, instance.TechProgress, v.TechPathLength )
			instance.Row:SetSizeY( instance.ApolloProject:GetSizeY()+30 )
		end
	end

	Controls.TechStack:CalculateSize()
	Controls.TechStack:ReprocessAnchoring()
	Controls.TechScrollPanel:CalculateInternalSize()
end

----------------------------------------------------------------
----------------------------------------------------------------
local PopulateDiploScreen = IsBNW and function()

	g_DiploCivIM:ResetInstances()

	local totalVotes = 0

	-- Sort players by votes
	-- local activeLeague = Game.GetNumActiveLeagues() > 0 and Game.GetActiveLeague()
	-- if activeLeague then
		-- turnsUntilSession = activeLeague:GetTurnsUntilVictorySession()
		-- votesHave = activeLeague:CalculateStartingVotesForMember( Game.GetActivePlayer() )
	-- end
	local sortedPlayerList = {}
	local activeTeam = Teams[ Game.GetActiveTeam() ]
	for playerID = 0, MAX_MAJOR_CIVS_M1 do
		local player = Players[ playerID ]
		if player and player:IsEverAlive() and activeTeam:IsHasMet( player:GetTeam() ) then
			local team = Teams[ player:GetTeam() ]
			insert( sortedPlayerList, { PlayerID = playerID, Player = player, Team = team, Sort = team:GetTotalSecuredVotes() } )  -- common vanilla GK and same as GetTotalProjectedVotes()
		end
	end
	sort( sortedPlayerList, sortFunction )

	for numDiplo, v in ipairs(sortedPlayerList) do
		local player = v.Player
		local playerTeam = v.Team
		local playerID = v.PlayerID

		-- Create Instance
		local instance = g_DiploCivIM:GetInstance()

		-- Set Civ Number
		instance.Name:LocalizeAndSetText( "TXT_KEY_NUMBERING_FORMAT", numDiplo )

		-- Set Civ Icon
		SetCivIcon( player, 45, instance.CivIcon, instance.CivIconBG, instance.CivIconShadow, instance.CivDead, not player:IsAlive() or playerTeam:GetLiberatedByTeam() ~= -1 )

		-- Alternate Colors
		instance.Row:SetColor( numDiplo % 2 == 0 and g_dark or g_white )

		-- Set Votes
		local selfVote = 0;
		local csVotes = 0;
		local libCityState = 0;
		local libCiv = 0;
		for i, team in pairs(Teams) do
		    if team:GetLeaderID() ~= -1 then
				local curPlayer = Players[team:GetLeaderID()];
				if team:IsAlive() then
					totalVotes = totalVotes + 1
				end
				if team:IsHomeOfUnitedNations() then
					totalVotes = totalVotes + 1
				end
				if curPlayer:IsAlive() then
					if team:GetTeamVotingForInDiplo() == playerTeam then
						if i == playerTeam then
							if team:IsHomeOfUnitedNations() then
								selfVote = 2;
							else
								selfVote = 1;
							end
						elseif team:IsMinorCiv() then
							if playerTeam == team:GetLiberatedByTeam() then
								libCityState = libCityState + 1;
							elseif playerID == curPlayer:GetAlly() then
								csVotes = csVotes + 1;
							end
						else
							if playerTeam == team:GetLiberatedByTeam() then
								libCiv = libCiv + 1;
							end
						end
					end
				end
			end
		end

		instance.TotalVotes:SetText( v.Sort )
		instance.SelfVotes:SetText( selfVote )
		instance.CityStateVotes:SetText( csVotes )
		instance.LiberatedCityStateVotes:SetText( libCityState )
		instance.LiberatedCivVotes:SetText( libCiv )

	end
	Controls.TotalDiploVotes:SetText(L("TXT_KEY_VP_DIPLO_VOTES").." "..totalVotes)
	Controls.NeededVotes:SetText(L("TXT_KEY_VP_DIPLO_VOTES_NEEDED").." "..Game.GetVotesNeededForDiploVictory())
	Controls.DiploScrollPanel:CalculateInternalSize()

end or function()

	g_DiploCivIM:ResetInstances()

	local activePlayerID = Game.GetActivePlayer()
	local activeTeam = Teams[ Game.GetActiveTeam() ]

	-- Sort players by votes
	local sortedPlayerList = {}
	for playerID = 0, MAX_MAJOR_CIVS_M1 do
		local player = Players[ playerID ]
		if player and player:IsEverAlive() and activeTeam:IsHasMet( player:GetTeam() ) then
			local teamID = player:GetTeam()
			local team = Teams[ teamID ]
			insert( sortedPlayerList, { PlayerID = playerID, Player = player, Team = team, TeamID = teamID, Sort = team:GetTotalSecuredVotes() } )  -- common vanilla GK and same as GetTotalProjectedVotes()
		end
	end
	sort( sortedPlayerList, sortFunction )

	for numDiplo, v in ipairs( sortedPlayerList ) do
		local player = v.Player
		local thisTeamID = v.TeamID
		local thisTeam = v.Team
		local thisTeamLeaderID = thisTeam:GetLeaderID()
		local thisTeamLeader = Players[thisTeamLeaderID]

		-- Create Instance
		local instance = g_DiploCivIM:GetInstance()

		-- Set Civ Number
		instance.Name:LocalizeAndSetText( "TXT_KEY_NUMBERING_FORMAT", numDiplo )

		-- Set Civ Icon
		SetCivIcon( player, 45, instance.CivIcon, instance.CivIconBG, instance.CivIconShadow, instance.CivDead, not player:IsAlive() or thisTeam:GetLiberatedByTeam() ~= -1 )

		-- Alternate Colors
		if numDiplo % 2 == 0 then
			instance.Row:SetColor( g_dark )
		end

		-- UN Icon
		instance.UNIcon:SetHide(not thisTeam:IsHomeOfUnitedNations())

		-- Show the team leader's name instead of this player's name to make the voting more clear.
		-- Usually the leader will be the same anyways.
		local strLeaderShortDesc = thisTeamLeader:GetCivilizationShortDescriptionKey();

		-- Populate name lists for tooltips for the active player
		local strCivVotesList = " ";
		local strMinorVotesList = " ";
		local strLibCityStateVotesList = " ";
		for iTeamLoop = 0, MAX_CIV_TEAMS_M1 do
			local pTeamLoop = Teams[iTeamLoop];
			if (iTeamLoop ~= thisTeamID and pTeamLoop:IsAlive() and not pTeamLoop:IsBarbarian()) then
				-- Only include the names of players which the active player has met
				if activeTeam:IsHasMet(iTeamLoop) then
					local iLeaderLoop = pTeamLoop:GetLeaderID();
					if (Players[iLeaderLoop] ~= nil) then
						local pLeaderLoop = Players[iLeaderLoop];
						local strLeaderLoopShortDesc = L( pLeaderLoop:GetCivilizationShortDescriptionKey() )

						-- Minor that will vote for us
						if (pLeaderLoop:IsMinorCiv() and pTeamLoop:GetTeamVotingForInDiplo() == thisTeamID) then
							-- Liberated
							if (pTeamLoop:GetLiberatedByTeam() == thisTeamID) then
								if (strLibCityStateVotesList ~= " ") then
									strLibCityStateVotesList = strLibCityStateVotesList .. ", ";
								end
								strLibCityStateVotesList = strLibCityStateVotesList .. strLeaderLoopShortDesc;
							-- Ally
							else
								if (strMinorVotesList ~= " ") then
									strMinorVotesList = strMinorVotesList .. ", ";
								end
								strMinorVotesList = strMinorVotesList .. strLeaderLoopShortDesc;
							end
						-- Major civ that voted for us last time
						elseif (not pLeaderLoop:IsMinorCiv() and Game.GetPreviousVoteCast(iTeamLoop) == thisTeamID) then
							if (strCivVotesList ~= " ") then
								strCivVotesList = strCivVotesList .. ", ";
							end
							strCivVotesList = strCivVotesList .. strLeaderLoopShortDesc;
						end
					end
				end
			end
		end

		local bShowToolTips = activeTeam:IsHasMet(thisTeamID) and thisTeam:IsAlive()

		if IsGK then
			-- Other Civ Votes
			local iCivVotes = thisTeam:GetProjectedVotesFromCivs();
			instance.SelfVotes:SetText(iCivVotes);
			instance.SelfVotes:EnableToolTip(false);
			if (iCivVotes > 0 and strCivVotesList ~= " " and bShowToolTips) then
				instance.SelfVotes:EnableToolTip(true);
				instance.SelfVotes:SetToolTipString( L( "TXT_KEY_VP_DIPLO_SELF_VOTES_TT_ALT", strLeaderShortDesc ) .. strCivVotesList )
			end

			-- CS Ally Votes
			local iMinorVotes = thisTeam:GetProjectedVotesFromMinorAllies();
			instance.CityStateVotes:SetText(iMinorVotes);
			instance.CityStateVotes:EnableToolTip(false);
			if (iMinorVotes > 0 and strMinorVotesList ~= " " and bShowToolTips) then
				instance.CityStateVotes:EnableToolTip(true);
				instance.CityStateVotes:SetToolTipString( L( "TXT_KEY_VP_DIPLO_CS_VOTES_TT_ALT", strLeaderShortDesc ) .. strMinorVotesList )
			end

			-- Liberated CS Votes
			local iLibCityStateVotes = thisTeam:GetProjectedVotesFromLiberatedMinors();
			instance.LiberatedCityStateVotes:SetText(iLibCityStateVotes);
			instance.LiberatedCityStateVotes:EnableToolTip(false);
			if (iLibCityStateVotes > 0 and strLibCityStateVotesList ~= " " and bShowToolTips) then
				local strTT = L("TXT_KEY_VP_DIPLO_LIBERATED_VOTES_TT_ALT", strLeaderShortDesc) .. strLibCityStateVotesList;
				instance.LiberatedCityStateVotes:EnableToolTip(true);
				instance.LiberatedCityStateVotes:SetToolTipString(strTT);
			end

			-- Last Vote
			local kiNoTeam = -1;
			local kiNoPlayer = -1;
			local iPreviousVoteCast = Game.GetPreviousVoteCast(thisTeamID);
			instance.LastVoteCiv:SetHide(true);
			if (iPreviousVoteCast ~= kiNoTeam and Teams[iPreviousVoteCast] ~= nil) then
				local iLastVoteLeader = Teams[iPreviousVoteCast]:GetLeaderID();
				if (iLastVoteLeader ~= kiNoPlayer) then
					instance.LastVoteCiv:SetHide(false);
					CivIconHookup(iLastVoteLeader, 32, instance.LastVoteCivIcon, instance.LastVoteCivIconBG, instance.LastVoteCivIconShadow, false, true);
					local pLastVoteLeader = Players[iLastVoteLeader];
					local strLastVoteLeader = pLastVoteLeader:GetCivilizationShortDescriptionKey();

					-- Tooltip
					instance.LastVoteCivIcon:EnableToolTip(false);
					instance.LastVoteCivIconBG:EnableToolTip(false);
					instance.LastVoteCivIconShadow:EnableToolTip(false);
					if (not thisTeam:IsHuman() and bShowToolTips) then
						local iApproach = Players[activePlayerID]:GetApproachTowardsUsGuess(thisTeamLeaderID);
						local strMoodText = "TXT_KEY_EMOTIONLESS";
						if activeTeam:IsAtWar(thisTeamID) then
							strMoodText = "TXT_KEY_DIPLO_MAJOR_CIV_DIPLO_STATE_WAR";
						elseif thisTeamLeader:IsDenouncingPlayer(activePlayerID) then
							strMoodText = "TXT_KEY_DIPLO_MAJOR_CIV_DIPLO_STATE_DENOUNCING";
						else
							if( iApproach == MajorCivApproachTypes.MAJOR_CIV_APPROACH_WAR ) then
								strMoodText = "TXT_KEY_WAR_CAPS";
							elseif( iApproach == MajorCivApproachTypes.MAJOR_CIV_APPROACH_HOSTILE ) then
								strMoodText = "TXT_KEY_DIPLO_MAJOR_CIV_DIPLO_STATE_HOSTILE";
							elseif( iApproach == MajorCivApproachTypes.MAJOR_CIV_APPROACH_GUARDED ) then
								strMoodText = "TXT_KEY_DIPLO_MAJOR_CIV_DIPLO_STATE_GUARDED";
							elseif( iApproach == MajorCivApproachTypes.MAJOR_CIV_APPROACH_AFRAID ) then
								strMoodText = "TXT_KEY_DIPLO_MAJOR_CIV_DIPLO_STATE_AFRAID";
							elseif( iApproach == MajorCivApproachTypes.MAJOR_CIV_APPROACH_FRIENDLY ) then
								strMoodText = "TXT_KEY_DIPLO_MAJOR_CIV_DIPLO_STATE_FRIENDLY";
							elseif( iApproach == MajorCivApproachTypes.MAJOR_CIV_APPROACH_NEUTRAL ) then
								strMoodText = "TXT_KEY_DIPLO_MAJOR_CIV_DIPLO_STATE_NEUTRAL";
							end
						end

						instance.LastVoteCivIcon:EnableToolTip(true);
						instance.LastVoteCivIconBG:EnableToolTip(true);
						instance.LastVoteCivIconShadow:EnableToolTip(true);
						instance.LastVoteCivIcon:LocalizeAndSetToolTip("TXT_KEY_VP_DIPLO_LIBERATED_CIV_TT_ALT", strLeaderShortDesc, strLastVoteLeader, strMoodText);
						instance.LastVoteCivIconBG:LocalizeAndSetToolTip("TXT_KEY_VP_DIPLO_LIBERATED_CIV_TT_ALT", strLeaderShortDesc, strLastVoteLeader, strMoodText);
						instance.LastVoteCivIconShadow:LocalizeAndSetToolTip("TXT_KEY_VP_DIPLO_LIBERATED_CIV_TT_ALT", strLeaderShortDesc, strLastVoteLeader, strMoodText);
					end
				end
			end
			if bShowToolTips then
				local tip = L("TXT_KEY_VP_DIPLO_MY_VOTES_TT_SUMMARY_ALT", strLeaderShortDesc, v.Sort)
						.. "[NEWLINE][NEWLINE]" .. L("TXT_KEY_VP_DIPLO_MY_VOTES_TT_CIVS_ALT", strLeaderShortDesc, iCivVotes)
						.. "[NEWLINE][NEWLINE]" .. L("TXT_KEY_VP_DIPLO_MY_VOTES_TT_CITYSTATES_ALT", strLeaderShortDesc, iMinorVotes + iLibCityStateVotes)
				if thisTeam:IsHomeOfUnitedNations() then
					tip = tip .. "[NEWLINE][NEWLINE]" .. L("TXT_KEY_VP_DIPLO_MY_VOTES_TT_UN_ALT", strLeaderShortDesc)
				end
				instance.TotalVotes:SetToolTipString( tip )
			end
			instance.TotalVotes:EnableToolTip( bShowToolTips )
		end

		-- Total Projected Votes
		instance.TotalVotes:SetText( v.Sort )
	end

	local totalVotes = 0;
	for _, team in pairs(Teams) do
		if team:IsAlive() and not team:IsBarbarian() and team:GetLeaderID()~=-1 then
			totalVotes = totalVotes + 1
			if team:IsHomeOfUnitedNations() then
				totalVotes = totalVotes + 1
			end
		end
	end

	Controls.TotalDiploVotes:SetText(L("TXT_KEY_VP_DIPLO_VOTES").." "..totalVotes)
	Controls.NeededVotes:SetText(L("TXT_KEY_VP_DIPLO_VOTES_NEEDED").." "..Game.GetVotesNeededForDiploVictory())
	Controls.DiploScrollPanel:CalculateInternalSize()
end

----------------------------------------------------------------
----------------------------------------------------------------
local function PopulateCultureScreen()
	g_CultureCivIM:ResetInstances()
	g_CultureRivalsIM:ResetInstances()
	local utopiaProjectInfo = IsBNW or GameInfo.Projects.PROJECT_UTOPIA_PROJECT
	local activeTeam = Teams[ Game.GetActiveTeam() ]
	if utopiaProjectInfo then
		-- Sort players by policy branches finished
		local sortedPlayerList = {}
		for playerID = 0, MAX_MAJOR_CIVS_M1 do
			local player = Players[ playerID ]
			if player and player:IsEverAlive() and activeTeam:IsHasMet( player:GetTeam() ) then
				insert( sortedPlayerList, { Player = player, Sort = IsBNW and player:GetNumCivsInfluentialOn()*10000 + player:GetTourism() or player:GetNumPolicyBranchesFinished() } )
			end
		end
		sort( sortedPlayerList, sortFunction )

		for i, v in ipairs(sortedPlayerList) do
			local player = v.Player
			local instance = g_CultureCivIM:GetInstance()
			SetCivNameAndIcon( player, i, instance.Name, 45, instance.CivIcon, instance.CivIconBG, instance.CivIconShadow, instance.CivDead, not player:IsAlive() )
			PopulateCivsCulture( player, g_CultureRivalsIM, instance.CultureStack, instance.CultureLabel, utopiaProjectInfo )
			instance.Row:SetSizeY( instance.CultureStack:GetSizeY()+30 )
		end
	end
	Controls.CultureCivs:CalculateSize();
	Controls.CultureCivs:ReprocessAnchoring();
	Controls.CultureCivScrollPanel:CalculateInternalSize()
end

----------------------------------------------------------------
----------------------------------------------------------------
local VictoryAttributes = {
	Score = {
		Info = GameInfo.Victories.VICTORY_TIME,
		Screen = Controls.ScoreScreen,
		CheckBox = Controls.ScoreCheckBox,
		Populate = PopulateScoreBreakdown,
		PopulateDetails = PopulateScoreScreen,
	},
	Domination = {
		Info = GameInfo.Victories.VICTORY_DOMINATION,
		Screen = Controls.YourDetails,
		CheckBox = Controls.DominationCheckBox,
		Populate = PopulateDomination,
	},
	Space = {
		Info = GameInfo.Victories.VICTORY_SPACE_RACE,
		Screen = Controls.SpaceRaceScreen,
		CheckBox = Controls.SpaceCheckBox,
		Populate = PopulateSpaceRace,
		PopulateDetails = PopulateSpaceRaceScreen,
	},
	Diplo = {
		Info = GameInfo.Victories.VICTORY_DIPLOMATIC,
		Screen = Controls.DiploScreen,
		CheckBox = Controls.DiploCheckBox,
		Populate = PopulateDiplomatic,
		PopulateDetails = PopulateDiploScreen,
	},
	Culture = {
		Info = GameInfo.Victories.VICTORY_CULTURAL,
		Screen = Controls.CultureScreen,
		CheckBox = Controls.CultureCheckBox,
		Populate = PopulateCultural,
		PopulateDetails = PopulateCultureScreen,
	},
}

local function SetupScreen()
	-- Title Icon
	CivIconHookup( Game.GetActivePlayer(), 64, Controls.CivIcon, Controls.CivIconBG, Controls.CivIconShadow )

	-- Set Remaining Turns
	local remainingTurns = Game.GetMaxTurns() - Game.GetElapsedGameTurns();
	if remainingTurns < 0 then
		remainingTurns = 0;
	end
	Controls.RemainingTurns:SetText(remainingTurns);
	for _, v in pairs( VictoryAttributes ) do
		if v.CheckBox and v.Info then
			v.CheckBox:SetCheck( PreGame.IsVictory(v.Info.ID) )
		end
		v.Screen:SetHide( v.PopulateDetails )
		v.Populate()
	end
end

local function Exit()
	UIManager:DequeuePopup( ContextPtr )
end

local function OnBack()
	Controls.YourDetails:SetHide( false )
	for _, v in pairs( VictoryAttributes ) do
		if v.PopulateDetails and not v.Screen:IsHidden() then
			return v.Screen:SetHide( true )
		end
	end
	return Exit()
end

local function OpenDetails( x )
	for k, v in pairs( VictoryAttributes ) do
		k = k ~= x
		v.Screen:SetHide( k )
		if not k then
			v.PopulateDetails()
		end
	end
end

-------------------------------------------------
-- Event handlers
-------------------------------------------------
local m_PopupInfo

Events.GameplaySetActivePlayer.Add( Exit )
Controls.BackButton:RegisterCallback( eLClick, OnBack )
Controls.SpaceRaceDetails:RegisterCallback( eLClick, function() OpenDetails( "Space" ) end )
Controls.DiploDetails:RegisterCallback( eLClick, IsBNW and function() Events.SerialEventGameMessagePopup{ Type = ButtonPopupTypes.BUTTONPOPUP_LEAGUE_OVERVIEW } end or function() OpenDetails( "Diplo" ) end )
Controls.CultureDetails:RegisterCallback( eLClick, function() OpenDetails( "Culture" ) end )
Controls.ScoreDetails:RegisterCallback( eLClick, function() OpenDetails( "Score" ) end )

for _, v in pairs( VictoryAttributes ) do
	local victoryID = v.Info and v.Info.ID
	if v.CheckBox then
		if not victoryID or g_IsNetworkMultiPlayer then
			v.CheckBox:SetDisabled( true )
		else
			v.CheckBox:RegisterCheckHandler( function(isChecked) PreGame.SetVictory(victoryID, isChecked) SetupScreen() end )
		end
	end
end

AddSerialEventGameMessagePopup( function( popupInfo )
	m_PopupInfo = popupInfo
	if popupInfo.Data1 ~= 1 then
		UIManager:QueuePopup( ContextPtr, PopupPriorityVictoryProgress )
	elseif ContextPtr:IsHidden() then
		UIManager:QueuePopup( ContextPtr, PopupPriorityInGameUtmost )
	else
		OnBack()
	end
end, BUTTONPOPUP_VICTORY_INFO )

ContextPtr:SetInputHandler( function( uiMsg, wParam )
	if uiMsg == KeyDown then
		if wParam == VK_RETURN or wParam == VK_ESCAPE then
			OnBack()
			return true
		end
	end
end)

ContextPtr:SetShowHideHandler( function( bIsHide, bIsInit )
	if not bIsInit then
		if bIsHide then
			Events.SerialEventGameMessagePopupProcessed.CallImmediate(BUTTONPOPUP_VICTORY_INFO, 0);
			decTurnTimerSemaphore();
		else
			SetupScreen();
			incTurnTimerSemaphore();
			Events.SerialEventGameMessagePopupShown(m_PopupInfo);
		end
	end
end)
