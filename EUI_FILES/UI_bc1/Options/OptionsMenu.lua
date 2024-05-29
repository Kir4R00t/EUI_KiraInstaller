--==========================================================
-- Options Menu
-- Modified by bc1 from 1.0.3.276 code using Notepad++
-- add new options for EUI
--==========================================================

include "UserInterfaceSettings"
local UserInterfaceSettings = UserInterfaceSettings

--==========================================================
-- Minor lua optimizations
--==========================================================

local pairs = pairs
local floor = math.floor
local insert = table.insert
local os_date = os.date
local os_time = os.time
local tonumber = tonumber

local ContentManager = ContentManager
local ContentType = ContentType
local ContextPtr = ContextPtr
local Controls = Controls
local Events = Events
local Game = Game
local GetVolumeKnobIDFromName = GetVolumeKnobIDFromName
local GetVolumeKnobValue = GetVolumeKnobValue
local KeyEvents = KeyEvents
local Keys = Keys
local Locale = Locale
local L = Locale.ConvertTextKey
local Matchmaking = Matchmaking
local Mouse = Mouse
local Network = Network
local OptionsManager = OptionsManager
local PopupPriority = PopupPriority
local PreGame = PreGame
local SaveAudioOptions = SaveAudioOptions
local SetVolumeKnobValue = SetVolumeKnobValue
local SystemUpdateUIType = SystemUpdateUIType
local UI = UI
local UIManager = UIManager

local g_GraphicPullDowns = {}
local g_GamePullDowns = {}

local m_WindowResList = {
{ x=2560, y=2048, bWide=false },
{ x=2560, y=1600, bWide=true },
{ x=1920, y=1200, bWide=true },
{ x=1920, y=1080, bWide=true },
{ x=1680, y=1050, bWide=true },
{ x=1600, y=1200, bWide=false },
{ x=1440, y=900,  bWide=true  },
{ x=1400, y=1050, bWide=true  },
{ x=1366, y=768,  bWide=true },
{ x=1280, y=1024, bWide=false },
{ x=1280, y=960,  bWide=true  },
{ x=1280, y=800,  bWide=true  },
{ x=1024, y=768,  bWide=false },
}

-- Store array of supported languages.
local g_Languages = Locale.GetSupportedLanguages();
local g_SpokenLanguages = Locale.GetSupportedSpokenLanguages();
local g_clockFormat, g_alarmTime, g_fTimer, g_chosenLanguage, g_CountDownType

local g_EUI_CheckBoxes = {
	TechTreeAutoClose = Controls.AutoCloseTechTreeCheckbox,
	CityStatePopupAutoClose = Controls.AutoCloseCityStateCheckbox,
	PolicyScreenAutoClose = Controls.AutoClosePolicyScreenCheckbox,
	PolicyConfirm = Controls.PolicyConfirmCheckbox,
	CityScreenAutoClose = Controls.AutoCloseCityScreenCheckbox,
	NextCityProduction = Controls.NextCityProductionCheckbox,
	ResetCityPlotPurchase = Controls.ResetCityPlotPurchaseCheckbox,
	WorkerFocus = Controls.WorkerFocusCheckbox,
	CityAdvisor = Controls.CityAdvisorCheckbox,
	CityRibbon = Controls.CityRibbonCheckbox,
	UnitRibbon = Controls.UnitRibbonCheckbox,
	UnitTypes = Controls.UnitTypesCheckbox,
	FlagPromotions = Controls.FlagPromotionsCheckbox,
	CivilizationRibbon = Controls.CivRibbonCheckbox,
	PredictiveRange = Controls.PredictiveRangeCheckbox,
	ShowUnitMouseOverIcon = Controls.UnitIconCheckbox,
	ShowToolTipIcon = Controls.ToolTipCheckbox,
	CityStateLeaders = Controls.CSLCheckbox,
	ShowCityIcon = Controls.CityIconCheckbox,
}
local mp = not Game or PreGame.IsMultiplayerGame() or PreGame.IsHotSeatGame()
local sp = not Game or not mp
local g_QuickCombatCheckBox = sp and Controls.SPQuickCombatCheckBox or Controls.MPQuickCombatCheckbox
local g_QuickMovementCheckbox = sp and Controls.SPQuickMovementCheckBox or Controls.MPQuickMovementCheckbox

local g_GameCheckBoxes = {
	IsNoCitizenWarning_Cached = Controls.NoCitizenWarningCheckbox,
	IsAutoWorkersDontReplace_Cached = Controls.AutoWorkersDontReplaceCB,
	IsAutoWorkersDontRemoveFeatures_Cached = Controls.AutoWorkersDontRemoveFeaturesCB,
	IsNoRewardPopups_Cached = Controls.NoRewardPopupsCheckbox,
	IsNoBasicHelp_Cached = Controls.NoBasicHelpCheckbox,
	IsNoTileRecommendations_Cached = Controls.NoTileRecommendationsCheckbox,
	IsCivilianYields_Cached = Controls.CivilianYieldsCheckbox,
	GetSinglePlayerAutoEndTurnEnabled_Cached = Controls.SinglePlayerAutoEndTurnCheckBox,
	GetMultiplayerAutoEndTurnEnabled_Cached = Controls.MultiplayerAutoEndTurnCheckbox,
	GetQuickSelectionAdvanceEnabled_Cached = Controls.QuickSelectionAdvCheckbox,

	GetStraightZoom_Cached = Controls.ZoomCheck,
	GetPolicyInfo_Cached = Controls.PolicyInfo,
	GetAutoUnitCycle_Cached = Controls.AutoUnitCycleCheck,
	GetScoreList_Cached = Controls.ScoreListCheck,
	GetMPScoreList_Cached = Controls.MPScoreListCheck,
	GetEnableMapInertia_Cached = Controls.EnableMapInertiaCheck,
	GetSkipIntroVideo_Cached = Controls.SkipIntroVideoCheck,
	GetAutoUIAssets_Cached = Controls.AutoUIAssetsCheck,
	GetSmallUIAssets_Cached = Controls.SmallUIAssetsCheck,

	GetSinglePlayerQuickCombatEnabled_Cached = mp and Controls.SPQuickCombatCheckBox or nil,
	GetSinglePlayerQuickMovementEnabled_Cached = mp and Controls.SPQuickMovementCheckBox or nil,
	GetMultiplayerQuickCombatEnabled_Cached = sp and Controls.MPQuickCombatCheckbox or nil,
	GetMultiplayerQuickMovementEnabled_Cached = sp and Controls.MPQuickMovementCheckbox or nil,

	GetResourceOn_Cached = Controls.ShowResources,
	GetYieldOn_Cached = Controls.ShowYield,
	GetShowTradeOn_Cached = Controls.ShowTrade,
	GetGridOn_Cached = Controls.ShowGrid,
}
-------------------------------------------------
-- Volume control
-------------------------------------------------
local g_VolumeSliders = {
	[GetVolumeKnobIDFromName("USER_VOLUME_MUSIC")or -1] = {
		SliderControl = Controls.MusicVolumeSlider,
		ValueControl = Controls.MusicVolumeSliderValue,
		Text = "TXT_KEY_OPSCREEN_MUSIC_SLIDER",
	},
	[GetVolumeKnobIDFromName("USER_VOLUME_SFX")or -1] = {
		SliderControl = Controls.EffectsVolumeSlider,
		ValueControl = Controls.EffectsVolumeSliderValue,
		Text = "TXT_KEY_OPSCREEN_SF_SLIDER",
	},
	[GetVolumeKnobIDFromName("USER_VOLUME_SPEECH")or -1] = {
		SliderControl = Controls.SpeechVolumeSlider,
		ValueControl = Controls.SpeechVolumeSliderValue,
		Text = "TXT_KEY_OPSCREEN_SPEECH_SLIDER",
	},
	[GetVolumeKnobIDFromName("USER_VOLUME_AMBIENCE")or -1] = {
		SliderControl = Controls.AmbienceVolumeSlider,
		ValueControl = Controls.AmbienceVolumeSliderValue,
		Text = "TXT_KEY_OPSCREEN_AMBIANCE_SLIDER",
	},
	[-1] = nil
}

local function OnUIVolumeSliderValueChanged( volume, volumeKnobID )
	SetVolumeKnobValue( volumeKnobID, volume )
	local volumeSlider = g_VolumeSliders[ volumeKnobID ]
	if volumeSlider then
		volumeSlider.ValueControl:LocalizeAndSetText( volumeSlider.Text, Locale.ToPercent( volume ) )
	end
end

for volumeKnobID, volumeSlider in pairs( g_VolumeSliders ) do
	volumeSlider.SliderControl:RegisterSliderCallback( OnUIVolumeSliderValueChanged )
	volumeSlider.SliderControl:SetVoid1( volumeKnobID )
	local volume = GetVolumeKnobValue( volumeKnobID )
	volumeSlider.SliderControl:SetValue( volume )
	volumeSlider.ValueControl:LocalizeAndSetText( volumeSlider.Text, Locale.ToPercent( volume ) )
	volumeSlider.CachedVolume = volume
end

local function SavePreviousAudioVolumes()
	for volumeKnobID, volumeSlider in pairs( g_VolumeSliders ) do
		volumeSlider.CachedVolume = GetVolumeKnobValue( volumeKnobID )
	end
end

local function RestorePreviousAudioVolumes()
	for volumeKnobID, volumeSlider in pairs( g_VolumeSliders ) do
		SetVolumeKnobValue( volumeKnobID, volumeSlider.CachedVolume )
	end
end

local fullscreenRes, windowedResX, windowedResY, msaaSetting, bFullscreen

local function SavePreviousResolutionSettings()
	fullscreenRes = OptionsManager.GetResolution_Cached()
	windowedResX, windowedResY = OptionsManager.GetWindowResolution_Cached()
	msaaSetting = OptionsManager.GetAASamples_Cached()
	bFullscreen = OptionsManager.GetFullscreen_Cached()
end

local function RestorePreviousResolutionSettings()
	OptionsManager.SetResolution_Cached( fullscreenRes )
	OptionsManager.SetWindowResolution_Cached( windowedResX, windowedResY )
	OptionsManager.SetAASamples_Cached( msaaSetting )
	OptionsManager.SetFullscreen_Cached( bFullscreen )
	if OptionsManager.HasUserChangedResolution() then
		OptionsManager.CommitResolutionOptions()
	end
	UpdateGraphicsOptionsDisplay()
end

----------------------------------------------------------------
-- Pulldowns & controls
----------------------------------------------------------------

local function SetDisabled( control, b )
	control:SetDisabled( b )
	control:SetAlpha( b and 0.5 or 1 )
end

local function BuildPullDown( t, textTable, pulldown, set, get, init )
	local instance = {}
	local button = pulldown:GetButton()
	local function refresh( level )
		button:SetText( textTable[ level ] )
	end
	for level, text in pairs( textTable ) do
		pulldown:BuildEntry( "InstanceOne", instance )
		instance.Button:SetText( text )
		instance.Button:SetVoid1( level )
		if init then
			init( instance.Button, level )
		end
	end
	pulldown:CalculateInternals()
	pulldown:RegisterSelectionCallback( function( level )
		refresh( level )
		set( level-1 )
	end)
	if get then
		t[pulldown:GetID()] = function()-- refresh( get()+1 ) end
			local v = get()
			if v then
				refresh( v+1 )
			else
				print( "pulldown", pulldown:GetID(), "has a refresh problem" )
			end
		end
	end
end
local function BuildGraphicPullDown( ... )
	return BuildPullDown( g_GraphicPullDowns, ... )
end
local function BuildGamePullDown( ... )
	return BuildPullDown( g_GamePullDowns, ... )
end

-------------------------------------------------
-- Countdown handlers
-------------------------------------------------
local function OnCountdownYes()
	--turn off timer
	ContextPtr:ClearUpdate()
	Controls.Countdown:SetHide( true )
	if g_CountDownType==1 then
		SavePreviousResolutionSettings()
	elseif g_CountDownType==2 then
		--apply language, reload UI
		Locale.SetCurrentLanguage( g_chosenLanguage )
		Events.SystemUpdateUI( SystemUpdateUIType.ReloadUI )
	end
end
Controls.CountYes:RegisterCallback( Mouse.eLClick, OnCountdownYes )

local function OnCountdownNo()
	--turn off timer
	ContextPtr:ClearUpdate()
	Controls.Countdown:SetHide( true )
	if g_CountDownType==1 then
		--here we revert resolution options to some old options
		RestorePreviousResolutionSettings()
	elseif g_CountDownType==2 then
		--revert language to current setting
		Controls.LanguagePull:GetButton():SetText(Locale.GetCurrentLanguage().DisplayName)
	end
end
Controls.CountNo:RegisterCallback( Mouse.eLClick, OnCountdownNo );

-------------------------------------------------
-------------------------------------------------
local function OnBack()
	if Controls.GraphicsChangedPopup:IsHidden() and Controls.Countdown:IsHidden() then
		UIManager:DequeuePopup( ContextPtr )
	end
	Controls.GraphicsChangedPopup:SetHide( true )
	OnCountdownNo()
end

local function SynchCache()
	OptionsManager.SyncGameOptionsCache()
	OptionsManager.SyncGraphicsOptionsCache()
	OptionsManager.SyncResolutionOptionsCache()
	for k, checkBox in pairs( g_EUI_CheckBoxes ) do
		checkBox:SetCheck( UserInterfaceSettings[ k ] ~= 0 )
	end
	Controls.AlarmCheckBox:SetCheck( UserInterfaceSettings.AlarmIsOff == 0 ) -- reversed since off by default !
	g_alarmTime = UserInterfaceSettings.AlarmTime
	g_clockFormat = UserInterfaceSettings.ClockMode
	if Game then
		g_QuickCombatCheckBox:SetCheck( PreGame.GetQuickCombat() )
		g_QuickMovementCheckbox:SetCheck( PreGame.GetQuickMovement() )
	end
end

local function OnCancel()
	SynchCache()
	RestorePreviousAudioVolumes()
	return OnBack()
end
Controls.CancelButton:RegisterCallback( Mouse.eLClick, OnCancel )

local function OnUpdate( fDTime )
	g_fTimer = g_fTimer - fDTime
	if g_fTimer <= 0 then
		OnCountdownNo()
	else
		Controls.CountdownTimer:SetText( floor( g_fTimer + 1 ) )
	end
end

local function StartCountDown( countDownType, timer, countdownMessage, countYes, countNo )
	g_fTimer = timer
	g_CountDownType = countDownType
	ContextPtr:SetUpdate( OnUpdate )
	Controls.Countdown:SetHide( false )
	Controls.CountdownMessage:LocalizeAndSetText( countdownMessage )
	Controls.CountYes:LocalizeAndSetText( countYes )
	Controls.CountNo:LocalizeAndSetText( countNo )
	Controls.CountdownTimer:SetText( timer )
	Controls.LabelStack:CalculateSize()
	Controls.LabelStack:ReprocessAnchoring()
end

function OnApplyRes()
	if OptionsManager.HasUserChangedResolution() then
		StartCountDown( 1, 20, L"TXT_KEY_OPSCREEN_RESOLUTION_TIMER", L"TXT_KEY_YES_BUTTON", L"TXT_KEY_NO_BUTTON" )
		OptionsManager.CommitResolutionOptions();
		UpdateGraphicsOptionsDisplay();
	end
end
Controls.ApplyResButton:RegisterCallback( Mouse.eLClick, OnApplyRes );

-------------------------------------------------
-------------------------------------------------

local function UpdateAlarmTime()
	Controls.AlarmTimeDate:SetText( os_date( "%x  %H:%M ", g_alarmTime ) )
end

----------------------------------------------------------------
-- Display updating
----------------------------------------------------------------

local function UpdateGameOptionsDisplay()
	local t = os_date( "*t", g_alarmTime )
	Controls.AlarmHours:SetText( t and t.hour )
	Controls.AlarmMinutes:SetText( t and t.min )
	UpdateAlarmTime()

	Controls.AutosaveTurnsEdit:SetText( OptionsManager.GetTurnsBetweenAutosave_Cached() )
	Controls.AutosaveMaxEdit:SetText( OptionsManager.GetNumAutosavesKept_Cached() )

	Controls.LanguagePull:GetButton():SetText(Locale.GetCurrentLanguage().DisplayName);
	Controls.SpokenLanguagePull:GetButton():SetText(Locale.GetCurrentSpokenLanguage().DisplayName); --TODO: make this work like its friends -KS

	for volumeKnobID, volumeSlider in pairs( g_VolumeSliders ) do
		local volume = GetVolumeKnobValue( volumeKnobID )
		volumeSlider.SliderControl:SetValue( volume )
		volumeSlider.ValueControl:LocalizeAndSetText( volumeSlider.Text, Locale.ToPercent( volume ) )
	end

	Controls.DragSpeedSlider:SetValue( OptionsManager.GetDragSpeed_Cached() / 2 )
	Controls.DragSpeedValue:LocalizeAndSetText( "TXT_KEY_DRAG_SPEED", OptionsManager.GetDragSpeed_Cached() )
	Controls.PinchSpeedSlider:SetValue( OptionsManager.GetPinchSpeed_Cached() / 2 )
	Controls.PinchSpeedValue:LocalizeAndSetText( "TXT_KEY_PINCH_SPEED", OptionsManager.GetPinchSpeed_Cached() )

	Controls.Tooltip1TimerSlider:SetValue( OptionsManager.GetTooltip1Seconds_Cached()/1000 )
	Controls.Tooltip1TimerLength:LocalizeAndSetText( "TXT_KEY_OPSCREEN_TOOLTIP_1_TIMER_LENGTH", OptionsManager.GetTooltip1Seconds_Cached() / 100 )
	Controls.Tooltip2TimerSlider:SetValue( OptionsManager.GetTooltip2Seconds_Cached()/1000 )
	Controls.Tooltip2TimerLength:LocalizeAndSetText( "TXT_KEY_OPSCREEN_TOOLTIP_2_TIMER_LENGTH", OptionsManager.GetTooltip2Seconds_Cached() / 100 )

	-- Only MP host can change quick combat & movement
	local isHost = Game and PreGame.IsMultiplayerGame() and not Matchmaking.IsHost()
	SetDisabled( Controls.MPQuickCombatCheckbox, isHost )
	SetDisabled( Controls.MPQuickMovementCheckbox, isHost )
	SetDisabled( Controls.SmallUIAssetsCheck, OptionsManager.GetAutoUIAssets_Cached() )

	for k, chekBox in pairs( g_GameCheckBoxes ) do
		chekBox:SetCheck( OptionsManager[k]() )
	end
	for _, f in pairs( g_GamePullDowns ) do
		f()
	end
end

----------------------------------------------------------------
--graphics options
----------------------------------------------------------------
function UpdateGraphicsOptionsDisplay()

	local isFullscreen = OptionsManager.GetFullscreen_Cached()
	Controls.FSResolutionPull:SetHide( not isFullscreen )
	Controls.FullscreenCheck:SetCheck( isFullscreen )
	Controls.WResolutionPull:SetHide( isFullscreen )
	local x, y = OptionsManager.GetWindowResolution_Cached()
	Controls.WResolutionPull:GetButton():SetText( x .. "x" .. y )

	SetDisabled( Controls.GPUDecodeCheck, not OptionsManager.IsGPUTextureDecodeSupported() )
	Controls.VSyncCheck:SetCheck( OptionsManager.GetVSync_Cached() )
	Controls.HDStratCheck:SetCheck( OptionsManager.GetHDStrategicView_Cached() )
	Controls.GPUDecodeCheck:SetCheck( OptionsManager.GetGPUTextureDecode_Cached() )
	Controls.MinimizeGrayTilesCheck:SetCheck( OptionsManager.GetMinimizeGrayTiles_Cached() )
	Controls.FadeShadowsCheck:SetCheck( OptionsManager.GetFadeShadows_Cached() )

	for _, f in pairs( g_GraphicPullDowns ) do
		f()
	end
end

----------------------------------------------------------------
----------------------------------------------------------------
local function ValidateSmtpPassword()
	local pw = Controls.TurnNotifySmtpPassEdit:GetText()
	if pw and pw == Controls.TurnNotifySmtpPassRetypeEdit:GetText() then
		-- password editboxes match.
		OptionsManager.SetTurnNotifySmtpPassword_Cached( pw );
		Controls.StmpPasswordMatchLabel:LocalizeAndSetText( "TXT_KEY_OPSCREEN_TURN_NOTIFY_SMTP_PASSWORDS_MATCH" )
		Controls.StmpPasswordMatchLabel:LocalizeAndSetToolTip( "TXT_KEY_OPSCREEN_TURN_NOTIFY_SMTP_PASSWORDS_MATCH_TT" )
		Controls.StmpPasswordMatchLabel:SetColorByName( "Green_Chat" );
	else
		-- password editboxes do not match.
		Controls.StmpPasswordMatchLabel:LocalizeAndSetText( "TXT_KEY_OPSCREEN_TURN_NOTIFY_SMTP_PASSWORDS_NOT_MATCH" )
		Controls.StmpPasswordMatchLabel:LocalizeAndSetToolTip( "TXT_KEY_OPSCREEN_TURN_NOTIFY_SMTP_PASSWORDS_NOT_MATCH_TT" )
		Controls.StmpPasswordMatchLabel:SetColorByName( "Magenta_Chat" );
	end
end

local function UpdateMultiplayerOptionsDisplay()
	Controls.TurnNotifySteamInviteCheckbox:SetCheck(OptionsManager.GetTurnNotifySteamInvite_Cached());
	Controls.TurnNotifyEmailCheckbox:SetCheck(OptionsManager.GetTurnNotifyEmail_Cached());
	Controls.TurnNotifyEmailAddressEdit:SetText(OptionsManager.GetTurnNotifyEmailAddress_Cached());
	Controls.TurnNotifySmtpEmailEdit:SetText(OptionsManager.GetTurnNotifySmtpEmailAddress_Cached());
	Controls.TurnNotifySmtpHostEdit:SetText(OptionsManager.GetTurnNotifySmtpHost_Cached());
	Controls.TurnNotifySmtpPortEdit:SetText(OptionsManager.GetTurnNotifySmtpPort_Cached());
	Controls.TurnNotifySmtpUserEdit:SetText(OptionsManager.GetTurnNotifySmtpUsername_Cached());
	Controls.TurnNotifySmtpPassEdit:SetText(OptionsManager.GetTurnNotifySmtpPassword_Cached());
	Controls.TurnNotifySmtpPassRetypeEdit:SetText(OptionsManager.GetTurnNotifySmtpPassword_Cached());
	Controls.TurnNotifySmtpTLS:SetCheck(OptionsManager.GetTurnNotifySmtpTLS_Cached());
	Controls.LANNickNameEdit:SetText(OptionsManager.GetLANNickName_Cached());
	return ValidateSmtpPassword(); -- Update passwords match label
end

----------------------------------------------------------------
----------------------------------------------------------------
function OnTutorialPull( level )
	local level = level;

	local bExpansion2Active = ContentManager.IsActive("6DA07636-4123-4018-B643-6575B4EC336B", ContentType.GAMEPLAY);
	local bExpansion1Active = ContentManager.IsActive("0E3751A1-F840-4e1b-9706-519BF484E59D", ContentType.GAMEPLAY);
	if bExpansion1Active and not bExpansion2Active then
		if level == 4 then
			level = -1;
		end
	elseif bExpansion2Active then
		if level == 5 then
			level = -1;
		end
	else
		if level == 3 then
			level = -1;
		end
	end
	OptionsManager.SetTutorialLevel_Cached(level);
end


----------------------------------------------------------------
function RefreshTutorialLevelOptions()
	local TutorialLevels = { [0]=L"TXT_KEY_OPSCREEN_TUTORIAL_OFF", L"TXT_KEY_OPSCREEN_TUTORIAL_LOW", L"TXT_KEY_OPSCREEN_TUTORIAL_MEDIUM" }
	local bExpansion1Active = ContentManager.IsActive("0E3751A1-F840-4e1b-9706-519BF484E59D", ContentType.GAMEPLAY);
	local bExpansion2Active = ContentManager.IsActive("6DA07636-4123-4018-B643-6575B4EC336B", ContentType.GAMEPLAY);

	if bExpansion1Active or bExpansion2Active then
		insert(TutorialLevels, L"TXT_KEY_OPSCREEN_TUTORIAL_NEW_TO_XP")
	end

	if bExpansion2Active then
		insert(TutorialLevels, L"TXT_KEY_OPSCREEN_TUTORIAL_NEW_TO_XP2")
	end
	insert(TutorialLevels, L"TXT_KEY_OPSCREEN_TUTORIAL_HIGH")

	Controls.TutorialPull:ClearEntries()
	BuildGamePullDown( TutorialLevels, Controls.TutorialPull, OptionsManager.SetTutorialLevel_Cached, OptionsManager.GetTutorialLevel_Cached ) -- todo
end

RefreshTutorialLevelOptions()

-------------------------------------------------
-- Initialize stuff
-------------------------------------------------

do
	local screenResolutionList = {}
	local screenResolutionText = {}
	local screenResolutionMap = {}
	local screenResolutionInvMap = {}
	local j = 0
	for i = UIManager:GetResCount()-1, 0, -1 do
		local x, y, refresh, scale, display, adapter = UIManager:GetResInfo( i )
		if x >= 768 and adapter == 0 then
			screenResolutionMap[i] = j
			screenResolutionInvMap[j] = i
			j = j+1
			screenResolutionList[j] = { x = x, y = y, refresh = refresh, display = display, adapter = adapter }
			screenResolutionText[j] = x .. "x" .. y .. "   " .. refresh .. " Hz"
		end
	end
	BuildGraphicPullDown( screenResolutionText, Controls.FSResolutionPull,
		function( i )
			OptionsManager.SetResolution_Cached( screenResolutionMap[i] )
			local t = screenResolutionList[ i+1 ]
			if t then
				OptionsManager.SetWindowResolution_Cached( t.x, t.y )
				Controls.WResolutionPull:GetButton():SetText( t.x .. "x" .. t.y )
			end
		end,
		function()
			return screenResolutionInvMap[ OptionsManager.GetResolution_Cached() ]
		end)

	local maxX, maxY = OptionsManager.GetMaxResolution()
	local windowResolutionList = {}
	local windowResolutionText = {}
	for i, v in pairs{
		{ x=maxX, y=maxY }, -- add the machine's desktop resolution in case they're running something else
		{ x=2560, y=2048, bWide=false },
		{ x=2560, y=1600, bWide=true },
		{ x=1920, y=1200, bWide=true },
		{ x=1920, y=1080, bWide=true },
		{ x=1680, y=1050, bWide=true },
		{ x=1600, y=1200, bWide=false },
		{ x=1440, y=900,  bWide=true  },
		{ x=1400, y=1050, bWide=true  },
		{ x=1366, y=768,  bWide=true },
		{ x=1280, y=1024, bWide=false },
		{ x=1280, y=960,  bWide=true  },
		{ x=1280, y=800,  bWide=true  },
		{ x=1024, y=768,  bWide=false },
	} do
		if v.x <= maxX and v.y <= maxY then
			if i==1 or v.x ~= maxX or v.y ~= maxY then
				insert( windowResolutionList, v )
				insert( windowResolutionText, v.x .. "x" .. v.y )
			end
		end
	end
	BuildGraphicPullDown( windowResolutionText, Controls.WResolutionPull,
		function( i )
			local t = windowResolutionList[ i + 1 ]
			if t then
				OptionsManager.SetWindowResolution_Cached( t.x, t.y )
			end
		end)

	local m_MSAAMap = { [0] = 1, 2, 4, 8 }
	local m_MSAAInvMap = { [0]=0, 0, 1, [4]=2, [8]=3 }
	BuildGraphicPullDown( { L"TXT_KEY_OPSCREEN_MSAA_OFF", L"TXT_KEY_OPSCREEN_MSAA_2X", L"TXT_KEY_OPSCREEN_MSAA_4X", L"TXT_KEY_OPSCREEN_MSAA_8X" },
		Controls.MSAAPull,
		function( i )
			OptionsManager.SetAASamples_Cached( m_MSAAMap[i] )
		end,
		function()
			return m_MSAAInvMap[ OptionsManager.GetAASamples_Cached() ]
		end,
		function( button, i )
			SetDisabled( button, not OptionsManager.IsAALevelSupported( m_MSAAInvMap[i-1] ) )
		end)
	BuildGraphicPullDown( { L"TXT_KEY_OPSCREEN_SETTINGS_LOW", L"TXT_KEY_OPSCREEN_SETTINGS_MEDIUM", L"TXT_KEY_OPSCREEN_SETTINGS_HIGH" },
		Controls.OverlayPull, OptionsManager.SetOverlayLevel_Cached, OptionsManager.GetOverlayLevel_Cached )
	BuildGraphicPullDown( { L"TXT_KEY_OPSCREEN_SETTINGS_OFF", L"TXT_KEY_OPSCREEN_SETTINGS_LOW", L"TXT_KEY_OPSCREEN_SETTINGS_MEDIUM", L"TXT_KEY_OPSCREEN_SETTINGS_HIGH" },
		Controls.ShadowPull, OptionsManager.SetShadowLevel_Cached, OptionsManager.GetShadowLevel_Cached )
	BuildGraphicPullDown( { L"TXT_KEY_OPSCREEN_SETTINGS_MINIMUM", L"TXT_KEY_OPSCREEN_SETTINGS_LOW", L"TXT_KEY_OPSCREEN_SETTINGS_MEDIUM", L"TXT_KEY_OPSCREEN_SETTINGS_HIGH" },
		Controls.FOWPull, OptionsManager.SetFOWLevel_Cached, OptionsManager.GetFOWLevel_Cached )
	BuildGraphicPullDown( { L"TXT_KEY_OPSCREEN_SETTINGS_MINIMUM", L"TXT_KEY_OPSCREEN_SETTINGS_LOW", L"TXT_KEY_OPSCREEN_SETTINGS_MEDIUM", L"TXT_KEY_OPSCREEN_SETTINGS_HIGH" },
		Controls.TerrainDetailPull, OptionsManager.SetTerrainDetailLevel_Cached, OptionsManager.GetTerrainDetailLevel_Cached )
	BuildGraphicPullDown( { L"TXT_KEY_OPSCREEN_SETTINGS_LOW", L"TXT_KEY_OPSCREEN_SETTINGS_MEDIUM", L"TXT_KEY_OPSCREEN_SETTINGS_HIGH" },
		Controls.TerrainTessPull, OptionsManager.SetTerrainTessLevel_Cached, OptionsManager.GetTerrainTessLevel_Cached )
	BuildGraphicPullDown( { L"TXT_KEY_OPSCREEN_SETTINGS_OFF", L"TXT_KEY_OPSCREEN_SETTINGS_LOW", L"TXT_KEY_OPSCREEN_SETTINGS_MEDIUM", L"TXT_KEY_OPSCREEN_SETTINGS_HIGH" },
		Controls.TerrainShadowPull, OptionsManager.SetTerrainShadowQuality_Cached, OptionsManager.GetTerrainShadowQuality_Cached )
	BuildGraphicPullDown( { L"TXT_KEY_OPSCREEN_SETTINGS_LOW", L"TXT_KEY_OPSCREEN_SETTINGS_MEDIUM", L"TXT_KEY_OPSCREEN_SETTINGS_HIGH" },
		Controls.WaterPull, OptionsManager.SetWaterQuality_Cached, OptionsManager.GetWaterQuality_Cached )
	BuildGraphicPullDown( { L"TXT_KEY_OPSCREEN_SETTINGS_LOW", L"TXT_KEY_OPSCREEN_SETTINGS_HIGH" },
		Controls.TextureQualityPull, OptionsManager.SetTextureQuality_Cached, OptionsManager.GetTextureQuality_Cached )
	BuildGamePullDown( { L"TXT_KEY_NEVER", L"TXT_KEY_FULLSCREEN_ONLY", L"TXT_KEY_ALWAYS" },
		Controls.BindMousePull, OptionsManager.SetBindMouseMode_Cached, OptionsManager.GetBindMouseMode_Cached )
	BuildGamePullDown( { L"TXT_KEY_MODDING_DISABLEMOD", os_date"%H:%M", os_date"%I:%M %p", os_date"%X", os_date"%c" }, -- must match Top Panel !
		Controls.ClockPull, function( i ) g_clockFormat = i end, function() return g_clockFormat end )
	BuildGraphicPullDown( { L"TXT_KEY_OPSCREEN_SETTINGS_MINIMUM", L"TXT_KEY_OPSCREEN_SETTINGS_LOW", L"TXT_KEY_OPSCREEN_SETTINGS_MEDIUM", L"TXT_KEY_OPSCREEN_SETTINGS_HIGH" },
		Controls.LeaderPull, OptionsManager.SetLeaderQuality_Cached, OptionsManager.GetLeaderQuality_Cached,
		function( button, i )
			SetDisabled( button, i == 3 and not UI.AreMediumLeadersAllowed() or i==4 and UI.IsDX9() )
		end)

	local languageTable = {};
	for i,v in pairs(g_Languages) do
		languageTable[i] = v.DisplayName
	end
	BuildGamePullDown( languageTable, Controls.LanguagePull, function( level )
		g_chosenLanguage = g_Languages[ level ].Type
		StartCountDown( 2, 20, Locale.LookupLanguage( g_chosenLanguage, "TXT_KEY_OPSCREEN_LANGUAGE_TIMER" ),
						L( "{1} ({TXT_KEY_YES_BUTTON})", Locale.LookupLanguage( g_chosenLanguage, "TXT_KEY_YES_BUTTON") ),
						L( "{1} ({TXT_KEY_NO_BUTTON})", Locale.LookupLanguage( g_chosenLanguage, "TXT_KEY_NO_BUTTON") ) )
	end)

	local spokenLanguageTable = {};
	for i,v in pairs(g_SpokenLanguages) do
		spokenLanguageTable[i] = v.DisplayName
	end
	BuildGamePullDown( spokenLanguageTable, Controls.SpokenLanguagePull, function( level ) --TODO: hook this up too! -KS
		Locale.SetCurrentSpokenLanguage( g_SpokenLanguages[ level ].Type )
	end)

	-- Cannot change some settings ingame
	Controls.BGBlock:SetHide( not Game )
	Controls.VideoPanelBlock:SetHide( not Game )
	SetDisabled( Controls.LanguagePull, Game )
	SetDisabled( Controls.SpokenLanguagePull, Game )
	SetDisabled( Controls.TutorialPull, Game and mp )
	SetDisabled( Controls.ResetTutorialButton, Game and mp )

	local panels = { Controls.GamePanel, Controls.IFacePanel, Controls.VideoPanel, Controls.AudioPanel, Controls.MultiplayerPanel }
	local highlights = { Controls.GameHighlight, Controls.IFaceHighlight, Controls.VideoHighlight, Controls.AudioHighlight, Controls.MultiplayerHighlight }
	local buttons = { Controls.GameButton, Controls.IFaceButton, Controls.VideoButton, Controls.AudioButton, Controls.MultiplayerButton }
	local function OnCategory( which )
		for i, panel in pairs( panels ) do
			panel:SetHide( which ~= i )
		end
		for i, highlight in pairs( highlights ) do
			highlight:SetHide( which ~= i )
		end
		Controls.TitleLabel:SetText( buttons[ which ]:GetText() )
	end
	for i, button in pairs(buttons) do
		button:SetVoid1( i )
		button:RegisterCallback( Mouse.eLClick, OnCategory )
	end
	OnCategory( Game and 2 or 3 )

	-- If we hear a multiplayer game invite was sent, exit so we don't interfere with the transition
	local function OnMultiplayerGameInvite()
		if not ContextPtr:IsHidden() then
			OnCancel()
		end
	end
	local EventHandlers = {
		MultiplayerGameLobbyInvite = OnMultiplayerGameInvite,
		MultiplayerGameServerInvite = OnMultiplayerGameInvite,
		GameOptionsChanged = UpdateGameOptionsDisplay,
		GraphicsOptionsChanged = UpdateGraphicsOptionsDisplay,
	}
	Events.EventOpenOptionsScreen.Add( function()
		UIManager:QueuePopup( ContextPtr, PopupPriority.OptionsMenu )
	end)

	----------------------------------------------------------------
	-- Show / hide handler
	ContextPtr:SetShowHideHandler( function( isHide )
		if isHide then
			--options menu is being hidden
			for event, handler in pairs( EventHandlers ) do
				Events[ event ].Remove( handler )
			end
			RestorePreviousAudioVolumes()
		else
			--options menu is being shown
			RefreshTutorialLevelOptions()
			SynchCache()
			SavePreviousAudioVolumes()
			SavePreviousResolutionSettings()
			UpdateGameOptionsDisplay()
			UpdateGraphicsOptionsDisplay()
			UpdateMultiplayerOptionsDisplay()
			for event, handler in pairs( EventHandlers ) do
				Events[ event ].Add( handler )
			end
		end
	end)

	----------------------------------------------------------------
	-- Key Down Processing
	local VK_RETURN = Keys.VK_RETURN
	local VK_ESCAPE = Keys.VK_ESCAPE
	local KeyDown = KeyEvents.KeyDown
	ContextPtr:SetInputHandler( function( uiMsg, wParam )
		if uiMsg == KeyDown then
			if wParam == VK_ESCAPE or wParam == VK_RETURN then
				OnBack()
			end
			return true
		end
	end)

	----------------------------------------------------------------
	-- Game Options Handlers
	local function SetAlarmOptions()
		local t = os_date("*t")
		t.hour = tonumber( Controls.AlarmHours:GetText() ) or 0
		t.min = tonumber( Controls.AlarmMinutes:GetText() ) or 0
		t.sec = 0
		g_alarmTime = os_time(t)
		if g_alarmTime <= os_time() then
			g_alarmTime = g_alarmTime + 86400	-- 1 day in seconds
		end
		return UpdateAlarmTime()
	end
	Controls.AlarmHours:RegisterCallback( SetAlarmOptions )
	Controls.AlarmMinutes:RegisterCallback( SetAlarmOptions )
	Controls.AlarmCheckBox:RegisterCheckHandler( SetAlarmOptions )

	Controls.Tooltip1TimerSlider:RegisterSliderCallback( function( i )
		i = floor(i * 100) * 10
		Controls.Tooltip1TimerLength:LocalizeAndSetText( "TXT_KEY_OPSCREEN_TOOLTIP_1_TIMER_LENGTH", i / 100 )
		OptionsManager.SetTooltip1Seconds_Cached(i)
	end)
	Controls.Tooltip2TimerSlider:RegisterSliderCallback( function( i )
		i = floor(i * 100) * 10
		Controls.Tooltip2TimerLength:LocalizeAndSetText( "TXT_KEY_OPSCREEN_TOOLTIP_2_TIMER_LENGTH", i / 100 )
		OptionsManager.SetTooltip2Seconds_Cached(i)
	end)
	Controls.DragSpeedSlider:RegisterSliderCallback( function( i )
		i = floor(i*20 + 2) / 10
		OptionsManager.SetDragSpeed_Cached( i )
		Controls.DragSpeedValue:LocalizeAndSetText( "TXT_KEY_DRAG_SPEED", i )
	end)
	Controls.PinchSpeedSlider:RegisterSliderCallback( function( i )
		i = floor(i*20 + 2) / 10
		OptionsManager.SetPinchSpeed_Cached( i )
		Controls.PinchSpeedValue:LocalizeAndSetText( "TXT_KEY_PINCH_SPEED", i )
	end)
	Controls.ResetTutorialButton:RegisterCallback( Mouse.eLClick, OptionsManager.ResetTutorial )
	Controls.NoCitizenWarningCheckbox:RegisterCheckHandler( OptionsManager.SetNoCitizenWarning_Cached )
	Controls.AutoWorkersDontReplaceCB:RegisterCheckHandler( OptionsManager.SetAutoWorkersDontReplace_Cached )
	Controls.AutoWorkersDontRemoveFeaturesCB:RegisterCheckHandler( OptionsManager.SetAutoWorkersDontRemoveFeatures_Cached )
	Controls.NoRewardPopupsCheckbox:RegisterCheckHandler( OptionsManager.SetNoRewardPopups_Cached )
	Controls.NoTileRecommendationsCheckbox:RegisterCheckHandler( OptionsManager.SetNoTileRecommendations_Cached )
	Controls.CivilianYieldsCheckbox:RegisterCheckHandler( OptionsManager.SetCivilianYields_Cached )
	Controls.NoBasicHelpCheckbox:RegisterCheckHandler( OptionsManager.SetNoBasicHelp_Cached )
	Controls.QuickSelectionAdvCheckbox:RegisterCheckHandler( OptionsManager.SetQuickSelectionAdvanceEnabled_Cached )
	Controls.AutosaveTurnsEdit:RegisterCallback( OptionsManager.SetTurnsBetweenAutosave_Cached )
	Controls.AutosaveMaxEdit:RegisterCallback( OptionsManager.SetNumAutosavesKept_Cached )
	Controls.ZoomCheck:RegisterCheckHandler( OptionsManager.SetStraightZoom_Cached )
	Controls.SinglePlayerAutoEndTurnCheckBox:RegisterCheckHandler( OptionsManager.SetSinglePlayerAutoEndTurnEnabled_Cached )
	Controls.MultiplayerAutoEndTurnCheckbox:RegisterCheckHandler( OptionsManager.SetMultiplayerAutoEndTurnEnabled_Cached )
	Controls.PolicyInfo:RegisterCheckHandler( OptionsManager.SetPolicyInfo_Cached )
	Controls.AutoUnitCycleCheck:RegisterCheckHandler( OptionsManager.SetAutoUnitCycle_Cached )
	Controls.ScoreListCheck:RegisterCheckHandler( OptionsManager.SetScoreList_Cached )
	Controls.MPScoreListCheck:RegisterCheckHandler( OptionsManager.SetMPScoreList_Cached )
	Controls.EnableMapInertiaCheck:RegisterCheckHandler( OptionsManager.SetEnableMapInertia_Cached )
	Controls.SkipIntroVideoCheck:RegisterCheckHandler( OptionsManager.SetSkipIntroVideo_Cached )

	Controls.ShowResources:RegisterCheckHandler( OptionsManager.SetResourceOn_Cached )
	Controls.ShowYield:RegisterCheckHandler( OptionsManager.SetYieldOn_Cached )
	Controls.ShowTrade:RegisterCheckHandler( OptionsManager.SetShowTradeOn_Cached )
	Controls.ShowGrid:RegisterCheckHandler( OptionsManager.SetGridOn_Cached )

	Controls.SPQuickCombatCheckBox:RegisterCheckHandler( OptionsManager.SetSinglePlayerQuickCombatEnabled_Cached )
	Controls.SPQuickMovementCheckBox:RegisterCheckHandler( OptionsManager.SetSinglePlayerQuickMovementEnabled_Cached )
	Controls.MPQuickCombatCheckbox:RegisterCheckHandler( OptionsManager.SetMultiplayerQuickCombatEnabled_Cached )
	Controls.MPQuickMovementCheckbox:RegisterCheckHandler( OptionsManager.SetMultiplayerQuickMovementEnabled_Cached )

	Controls.AutoUIAssetsCheck:RegisterCheckHandler( function( isChecked )
		OptionsManager.SetAutoUIAssets_Cached( isChecked )
		SetDisabled( Controls.SmallUIAssetsCheck, isChecked )
	end)

	----------------------------------------------------------------
	-- Multiplayer Options Handlers
	Controls.TurnNotifySteamInviteCheckbox:RegisterCheckHandler( OptionsManager.SetTurnNotifySteamInvite_Cached )
	Controls.TurnNotifyEmailCheckbox:RegisterCheckHandler( OptionsManager.SetTurnNotifyEmail_Cached )
	Controls.TurnNotifyEmailAddressEdit:RegisterCallback( OptionsManager.SetTurnNotifyEmailAddress_Cached )
	Controls.TurnNotifySmtpEmailEdit:RegisterCallback( OptionsManager.SetTurnNotifySmtpEmailAddress_Cached )
	Controls.TurnNotifySmtpHostEdit:RegisterCallback( OptionsManager.SetTurnNotifySmtpHost_Cached )
	Controls.TurnNotifySmtpPortEdit:RegisterCallback( OptionsManager.SetTurnNotifySmtpPort_Cached )
	Controls.TurnNotifySmtpUserEdit:RegisterCallback( OptionsManager.SetTurnNotifySmtpUsername_Cached )
	Controls.LANNickNameEdit:RegisterCallback( OptionsManager.SetLANNickName_Cached )
	Controls.TurnNotifySmtpTLS:RegisterCheckHandler( OptionsManager.SetTurnNotifySmtpTLS_Cached )
	Controls.TurnNotifySmtpPassEdit:RegisterCallback( ValidateSmtpPassword );
	Controls.TurnNotifySmtpPassRetypeEdit:RegisterCallback( ValidateSmtpPassword );
	----------------------------------------------------------------
	-- Graphics Options Handlers
	Controls.SmallUIAssetsCheck:RegisterCheckHandler( OptionsManager.SetSmallUIAssets_Cached )
	Controls.HDStratCheck:RegisterCheckHandler( OptionsManager.SetHDStrategicView_Cached )
	Controls.GPUDecodeCheck:RegisterCheckHandler( OptionsManager.SetGPUTextureDecode_Cached )
	Controls.MinimizeGrayTilesCheck:RegisterCheckHandler( OptionsManager.SetMinimizeGrayTiles_Cached )
	Controls.FadeShadowsCheck:RegisterCheckHandler( OptionsManager.SetFadeShadows_Cached )
	Controls.VSyncCheck:RegisterCheckHandler( OptionsManager.SetVSync_Cached )
	Controls.FullscreenCheck:RegisterCheckHandler( function( isChecked )
		OptionsManager.SetFullscreen_Cached( isChecked )
		Controls.FSResolutionPull:SetHide( not isChecked )
		Controls.WResolutionPull:SetHide( isChecked )
	end)
	Controls.GraphicsChangedOK:RegisterCallback( Mouse.eLClick, function()
		Controls.GraphicsChangedPopup:SetHide( true )
		return OnBack()
	end)

	Controls.AudioNextSong:RegisterCallback( Mouse.eLClick, function() Events.AudioDebugChangeMusic(true,false,false) end ) -- Play Next Song

	Controls.AcceptButton:RegisterCallback( Mouse.eLClick, function()
		for k, checkBox in pairs( g_EUI_CheckBoxes ) do
			UserInterfaceSettings[ k ] = checkBox:IsChecked() and 1 or 0
		end
		UserInterfaceSettings.ClockMode = g_clockFormat
		UserInterfaceSettings.AlarmTime = g_alarmTime
		UserInterfaceSettings.AlarmIsOff = Controls.AlarmCheckBox:IsChecked() and 0 or 1 -- reversed since off by default !
		OptionsManager.CommitGameOptions()
		OptionsManager.CommitGraphicsOptions()

		--update local caches because the hide handler will set values back to cached versions
		SaveAudioOptions()
		SavePreviousAudioVolumes()

		-- If we are ingame in SP or an MP host, we can change the quick states
		if Game and ( not PreGame.IsMultiplayerGame() or Matchmaking.IsHost() ) then
			local options = {}
			local b = g_QuickCombatCheckBox:IsChecked()
			if b ~= PreGame.GetQuickCombat() then
				insert( options, { "GAMEOPTION_QUICK_COMBAT", b } )
			end
			b = g_QuickMovementCheckbox:IsChecked()
			if b ~= PreGame.GetQuickMovement() then
				insert( options, { "GAMEOPTION_QUICK_MOVEMENT", b } )
			end
			if #options > 0 then
				Network.SendGameOptions( options )
			end
		end

		local hasUserChangedResolution = OptionsManager.HasUserChangedResolution()
		if hasUserChangedResolution then
			OnApplyRes()
		end
		if OptionsManager.HasUserChangedGraphicsOptions() then
			Controls.GraphicsChangedPopup:SetHide(false)
		elseif not hasUserChangedResolution then
			OnBack()
		end
	end)

	Controls.DefaultButton:RegisterCallback( Mouse.eLClick,	function()
		OptionsManager.ResetDefaultGameOptions()
		OptionsManager.ResetDefaultGraphicsOptions()
		-- SetDefaultAudioVolumes
		for volumeKnobID in pairs( g_VolumeSliders ) do
			SetVolumeKnobValue( volumeKnobID, 1 )
		end
		UpdateGameOptionsDisplay()
		UpdateGraphicsOptionsDisplay()
		UpdateMultiplayerOptionsDisplay()
	end)
end
