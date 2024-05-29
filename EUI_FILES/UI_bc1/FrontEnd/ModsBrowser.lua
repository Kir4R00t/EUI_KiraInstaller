---------------------------------------------------
-- Mods Browser Screen
-- Modified by bc1 from 1.0.3.276 code using Notepad++
---------------------------------------------------

include "StackInstanceManager"

-------------------------------
-- Global constants
-------------------------------
-- Listings box default color.
ListingBoxDefaultColor = {
	x = 200/255,
	y = 200/255,
	z = 200/255,
	w = 128/255,
}

-- Listings box highlight color.
ListingBoxHighlightColor = {
	x = 225/255,
	y = 225/255,
	z = 225/255,
	w = 225/255,
}


EnableText = Locale.ConvertTextKey("TXT_KEY_MODDING_ENABLEMOD");
DisableText = Locale.ConvertTextKey("TXT_KEY_MODDING_DISABLEMOD");
local isDirty

SortOptions = {
	Name = {
		ImageControl = Controls.SortbyNameImage,
		SortAscending = function(a,b)
			if(a.DisplayName == nil) then
				return false;
			elseif(b.DisplayName == nil) then
				return true;
			else
				return (Locale.Compare(a.DisplayName, b.DisplayName) == -1);
			end
		end,

		SortDescending = function(a,b)
			if(a.DisplayName == nil) then
				return false;
			elseif(b.DisplayName == nil) then
				return true;
			else
				return (Locale.Compare(a.DisplayName, b.DisplayName) == 1);
			end
		end,
	},

	Enabled = {
		ImageControl = Controls.SortbyEnabledImage,
		SortAscending = function(a,b)
			return a.Enabled and not b.Enabled;
		end,

		SortDescending = function(a,b)
			return b.Enabled and not a.Enabled;
		end,
	}
}

-------------------------------
-- Global variables
-------------------------------
g_InstanceManager = StackInstanceManager("ListingButtonInstance", "Button", Controls.ListingStack);
g_DetailLabels = StackInstanceManager("DetailLabelInstance", "Label", Controls.DetailLabelsStack);
g_DetailValues = StackInstanceManager("DetailValueInstance", "Label", Controls.DetailValuesStack);
g_DependentMods = StackInstanceManager("DependentModInstance", "Label", Controls.DependentModStack);
g_DetailsDependentMods = StackInstanceManager("DetailsDependentModInstance", "Label", Controls.DetailsDependentModStack);

g_SortedMods = {};		-- A sorted array of installed mods.
g_CurrentListingsState = "empty";	-- The current state of listings.
g_CurrentSortOption = "Name";		-- The currently selected sort option.
g_CurrentSortDirection = "asc";		-- The currently selection sort direction.
g_DownloadingFiles = {};			-- Files currently downloading.
g_ListingUpdateTasks = {};			-- A table functions to call every frame to refresh the status of certain mod entries.

function SetListingsState( state )
	if state ~= g_CurrentListingsState then
		Controls.ListingsPanel:SetHide( state == "details" )
		Controls.ListingsResults:SetHide( state == "empty" )
		Controls.ListingsEmpty:SetHide( state ~= "empty" )
		Controls.DetailsResults:SetHide( state ~= "details" )
		g_CurrentListingsState = state;
	end
end

-- Enumerate all installed mod info.
function RefreshMods()

--	print("Refreshing Mods");

	ClearListingUpdateTasks();

	local currentlySelectedModID;
	if(g_SelectedModInfo ~= nil) then
		currentlySelectedModID = g_SelectedModInfo.ModId;
	end

	g_SortedMods = {};
	g_SelectedModInfo = {};

--print("GetModBrowserListings()");
	local unsortedInstalledMods = Modding.GetModBrowserInstalledListings();	-- Get the installed mods.
	for k, v in pairs(unsortedInstalledMods) do

		-- This is used often later on for sorting and for the name column in the table.
		if(v.Title ~= nil) then
			v.Name = v.Title;
		end
		local titleLength = 60;
		v.DisplayName = v.Name;
		if(#v.Name > titleLength) then
			v.DisplayName = string.format("%s...", string.sub(v.Name, 1, titleLength));
		end

		if(v.Version ~= nil) then
			v.DisplayName = string.format("%s (v. %i)", v.DisplayName, v.Version);
		end
	end

	g_SortedMods = unsortedInstalledMods;

	SortListings();

	-- Downloading Files come ABOVE Installed Mods no matter what.
	local downloadingFiles = Modding.GetModBrowserDownloadingListings();
	for i,v in ipairs(downloadingFiles) do
		v.Teaser = Locale.Lookup("TXT_KEY_MODDING_DOWNLOADSTATUS_2");	-- Set teaser to transferring.
		table.insert(g_SortedMods, 1, v);
	end

	function CreateInstallingEntry(progress)
		local stateMsg = {
			[1] = "TXT_KEY_MODDING_INSTALLER_EXTRACTING",
			[2] = "TXT_KEY_MODDING_INSTALLER_VERIFYING",
			[3] = "TXT_KEY_MODDING_INSTALLER_COPYING",
			[4] = "TXT_KEY_MODDING_INSTALLER_FINISHED",
			[5] = "TXT_KEY_MODDING_INSTALLER_ERROR",
		};

		return {
			DisplayName = Locale.Lookup("TXT_KEY_MODDING_INSTALLER_INSTALLING"),
			Teaser = (stateMsg[progress.Status]) and Locale.Lookup(stateMsg[progress.Status]) or "",
			State = "Installing"
		}
	end

	-- Installing Files come ABOVE Everything else no matter what.
	local progress = Modding.GetInstallProgress();
	if(progress ~= nil) then
		table.insert(g_SortedMods, 1, CreateInstallingEntry(progress));
	end

	if(#g_SortedMods == 0)  then
		SetListingsState("empty");
		return;
	else
		SetListingsState("results");
	end

	g_InstanceManager:ResetInstances();

	local modsToTestCanEnable = {};

	for i,modinfo in ipairs(g_SortedMods) do

		local listing = g_InstanceManager:GetInstance();

		listing.Title:SetText(modinfo.DisplayName);

		if(modinfo.Teaser ~= nil) then
			listing.Teaser:SetText(modinfo.Teaser);
			listing.Teaser:SetHide(false);
		else
			listing.Teaser:SetHide(true);
		end

		local enableBtn = listing.EnableButton;
		local disableBtn = listing.DisableButton;
		local updateBtn = listing.UpdateButton;

		if(modinfo.State == "Installed" or modinfo.State == "NeedsUpdate") then

			listing.ProgressBarGrid:SetHide(true);
			enableBtn:SetHide(modinfo.Enabled);
			disableBtn:SetHide(not modinfo.Enabled);
			updateBtn:SetHide(not (modinfo.State == "NeedsUpdate"));

			if(not modinfo.Enabled) then
				--Add this to the list of mods that need to be tested
				table.insert(modsToTestCanEnable, {modinfo.ModId, modinfo.Version, enableBtn});
			end

			if(modinfo.State == "NeedsUpdate") then
				updateBtn:RegisterCallback(Mouse.eLClick, function() Modding.UpdateMod(modinfo.ModId, modinfo.Version); end);
			end

			if(modinfo.Enabled) then
				disableBtn:RegisterCallback(Mouse.eLClick, function() DisableMod(modinfo.ModId, modinfo.Version); end);
			else
				enableBtn:RegisterCallback(Mouse.eLClick, function() EnableMod(modinfo.ModId, modinfo.Version); end);
			end

			listing.Button:RegisterCallback(Mouse.eLClick, function() OnListingClicked(i); end);


		else
			enableBtn:SetHide(true);
			disableBtn:SetHide(true);
			updateBtn:SetHide(true);

			-- This is not a true mod entry so prevent the user from clicking it!
			listing.Button:ClearCallback(Mouse.eLClick);

			if(modinfo.State == "Downloading") then
				listing.ProgressBarGrid:SetHide(false);
				AddListingUpdateTask( function()
					local downloadedBytes, totalBytes = Modding.GetDownloadProgress(modinfo.DownloadHandle);
										listing.StatusLabel:LocalizeAndSetText("TXT_KEY_MODDING_DOWNLOADSTATUS_2");

					if(totalBytes ~= nil and totalBytes > 0) then
						local pct = downloadedBytes/totalBytes;

						local ph = listing.ProgressBar:GetSizeY();
						listing.ProgressBar:SetSizeVal(pct * 390, ph);
						listing.ProgressBar:SetHide(false);
						listing.StatusLabel:LocalizeAndSetText("TXT_KEY_MODDING_INSTALL_PROGRESS", FileSizeAsString(downloadedBytes), FileSizeAsString(totalBytes));

					else
						listing.ProgressBar:SetHide(true);
					end
				end);
			end

			if(modinfo.State == "Installing") then
				listing.ProgressBarGrid:SetHide(false);
				AddListingUpdateTask (function ()
					listing.StatusLabel:SetText("Installing!");

					local stateMsg = {
						[0] = "TXT_KEY_MODDING_INSTALLER_FINISHED",
						[1] = "TXT_KEY_MODDING_INSTALLER_EXTRACTING",
						[2] = "TXT_KEY_MODDING_INSTALLER_VERIFYING",
						[3] = "TXT_KEY_MODDING_INSTALLER_COPYING",
						[4] = "TXT_KEY_MODDING_INSTALLER_FINISHED",
						[5] = "TXT_KEY_MODDING_INSTALLER_ERROR",
					};

					local progress = Modding.GetInstallProgress();
					if(progress == nil) then
						-- We're probably finished installing.
						RefreshMods();
					else
						listing.Teaser:LocalizeAndSetText(stateMsg[progress.Status]);
						listing.StatusLabel:LocalizeAndSetText("TXT_KEY_MODDING_INSTALL_PROGRESS", progress.FilesProcessed, progress.TotalFiles);

						if(progress.TotalFiles > 0) then
							local pct = progress.FilesProcessed/progress.TotalFiles;
							local ph = listing.ProgressBar:GetSizeY();
							listing.ProgressBar:SetSizeVal(pct * 390, ph);
							listing.ProgressBar:SetHide(false);
						else
							listing.ProgressBar:SetHide(true);
						end
					end
				end);
			end
		end

		listing.Button:RegisterCallback(Mouse.eMouseEnter, OnListingMouseEnter);
		listing.Button:RegisterCallback(Mouse.eMouseExit, OnListingMouseExit);

	end

	local tooltips = {
		[0] = "TXT_KEY_MODDING_ENABLEMOD",
		[1] = "TXT_KEY_MODDING_MOD_BLOCKED_BY_OTHER_MOD",
		[2] = "TXT_KEY_MODDING_MOD_VERSION_ALREADY_ENABLED",
		[3] = "TXT_KEY_MODDING_MOD_MISSING_DEPENDENCIES",
		[4] = "TXT_KEY_MODDING_MOD_HAS_EXCLUSIVITY_CONFLICTS",
		[5] = "TXT_KEY_MODDING_MOD_BAD_GAMEVERSION",
	};

	--The second argument expects an array of arrays in which the first item is the modid and the second item is the version.
	--In this snippet, we have a 3rd unused item which is the enable button that we use further down.
	local canEnableStatus = Modding.CanEnableMod(modsToTestCanEnable);
	for i,v in ipairs(canEnableStatus) do

		local enableBtn = modsToTestCanEnable[i][3];
		enableBtn:SetDisabled(v > 0);

		local tooltip = tooltips[v];
		if(tooltip ~= nil) then
			tooltip = Locale.ConvertTextKey(tooltip);
		end

		enableBtn:SetToolTipString(tooltip);

	end


	Controls.ListingStack:CalculateSize();
	Controls.ListingStack:ReprocessAnchoring();

	Controls.ListingScrollPanel:CalculateInternalSize();
end

function EnableMod(modID, version)
	isDirty = true
	Modding.EnableMod( modID, version )
	RefreshMods()
end

function DisableMod(modID, version)
	isDirty = true
	local mods = Modding.GetModsRequiredToDisableMod(modID, version);

	if mods and #mods > 1 then
		-- More than one mod is required to disable this mod!
		-- Prompt user and check if this is ok to continue.


		-- Populate basic info on dialog.
		Controls.ConfirmText:LocalizeAndSetText("TXT_KEY_CONFIRM_DISABLE_MOD");
		Controls.EffectedModsLabel:LocalizeAndSetText("TXT_KEY_WILL_ALSO_DISABLE_MODS");
		Controls.EffectedModsElements:SetHide(false);
		Controls.DeleteUserData:SetHide(true);

		g_DependentMods:ResetInstances()

		for i,v in ipairs(mods) do
			if v.ModID ~= modID then
				g_DependentMods:GetInstance().Label:SetText( string.format("[ICON_BULLET] %s (v. %i)", Modding.GetModProperty(v.ModID, v.Version, "Name"), v.Version) )
			end
		end

		UIManager:PushModal(Controls.DeleteConfirm);

		Controls.Yes:RegisterCallback(Mouse.eLClick, function()
			UIManager:PopModal(Controls.DeleteConfirm);
			for i,v in ipairs(mods) do
				Modding.DisableMod(v.ModID, v.Version);
			end
			RefreshMods();
		end);

	else
		-- Just disable the mod.
		Modding.DisableMod( modID, version )
		RefreshMods()
	end
end

--------------------------------------------------------
-- Listings sorting functionality
--------------------------------------------------------
function SortListings()
	if(g_CurrentSortOption ~= nil) then
		local sortOption = SortOptions[g_CurrentSortOption];
		if(sortOption) then
			local sortMethod;
			if(g_CurrentSortDirection == "asc") then
				sortMethod = sortOption.SortAscending;
			else
				sortMethod = sortOption.SortDescending;
			end

			table.sort(g_SortedMods, sortMethod);
		end
	end
end

function SortListingsBy(option)
	local sortOption = SortOptions[option];
	if(option == g_CurrentSortOption) then
		if(g_CurrentSortDirection == "asc") then
			g_CurrentSortDirection = "desc";
		else
			g_CurrentSortDirection = "asc";
		end
	else
		g_CurrentSortDirection = "asc";
		g_CurrentSortOption = option;
	end

	for n,v in pairs(SortOptions) do
		if(v.ImageControl) then
			v.ImageControl:SetHide(n ~= g_CurrentSortOption);

			if(g_CurrentSortDirection == "asc") then
				v.ImageControl:SetTexture("SelectedUp.dds");
			else
				v.ImageControl:SetTexture("SelectedDown.dds");
			end
		end
	end

	RefreshMods();
end

---------------------------------------------------------
-- Update Handling
---------------------------------------------------------
function OnUpdate(deltaTime)

	Modding.UpdateModdingSystem();

	if g_CurrentListingsState == "results" or g_CurrentListingsState == "empty" then
		local currentState = Modding.GetModsBrowserInstalledListingsState();
		if(g_CurrentBrowserListingsState ~= currentState) then
			g_CurrentBrowserListingsState = currentState;
			RefreshMods();
		else
			local downloadingFiles = Modding.GetModBrowserDownloadingListings();
			if #downloadingFiles == #g_DownloadingFiles then
				for i,v in ipairs(g_DownloadingFiles) do
					if not Modding.PublishedFileIdsMatch(v.PublishedFileId, downloadingFiles[i].PublishedFileId) then
						g_DownloadingFiles = downloadingFiles;
						RefreshMods();
						break;
					end
				end
			else
				local progress = Modding.GetInstallProgress() ~= nil
				if g_InstallingMods ~= progress then
					g_InstallingMods = progress
					RefreshMods()
				end
			end
		end

	end

	if Modding.HasPendingInstalls() then
		Modding.InstallMods()
	end

	for i,v in ipairs(m_ListingUpdateTasks) do
		v(deltaTime)
	end
end
ContextPtr:SetUpdate(OnUpdate);

function AddListingUpdateTask(task)
	table.insert(m_ListingUpdateTasks, task);
end

function ClearListingUpdateTasks()
	m_ListingUpdateTasks = {};
end

--Register Sorting
Controls.SortbyName:RegisterCallback(Mouse.eLClick, function() SortListingsBy("Name"); end);
Controls.SortByEnabled:RegisterCallback(Mouse.eLClick, function() SortListingsBy("Enabled"); end);

--------------------------------------------------------
-- Listing Item Event Handlers
--------------------------------------------------------
function OnListingClicked(index)

	g_SelectedModInfo = g_SortedMods[index];
	local modinfo = g_SelectedModInfo;

	ShowInstalledModDetails(modinfo.ModId, modinfo.Version);
end

-- Updates the details data given a certain modDetails structure
function ShowInstalledModDetails(modId, modVersion)

	local modDetails = Modding.GetInstalledModDetails(modId, modVersion)
	Controls.SelectedModName:SetText(modDetails.Name);
	Controls.SelectedModID:SetText(modId);

	Controls.SelectedModDescription:SetText(modDetails.Description);

	-- Refresh Details
	g_DetailLabels:ResetInstances();
	g_DetailValues:ResetInstances();
	g_DetailsDependentMods:ResetInstances();

	local max_detail_label_width = 0;
	local max_detail_value_width = 0;
	local details = {};

	function AddDetail(tag, value)
		if(value ~= nil) then
			local detail = g_DetailLabels:GetInstance();
			local detailValue = g_DetailValues:GetInstance();

			--We always want to at least supply 1 argument.
			local text = Locale.ConvertTextKey(tag);
			detail.Label:SetText(text);

			local size = detail.Label:GetSize();
			local width = size.x;
			if(width > max_detail_label_width) then
				max_detail_label_width = width;
			end

			detailValue.Label:SetText(value or "");
			detailValue.Label:SetToolTipString(nil);

			size = detailValue.Label:GetSize();

			width = size.x;
			if(width > max_detail_value_width) then
				max_detail_value_width = width;
			end

			table.insert(details, {Label = detail, Value = detailValue});
		end
	end

	local numDependencyMessages = 0;

	function AddDependencyMessage(message, ...)
		if(message ~= nil) then
			local detail = g_DetailsDependentMods:GetInstance();

			--We always want to at least supply 1 argument.
			local text = Locale.ConvertTextKey(message, ...);
			detail.Label:SetText("[ICON_BULLET] " .. tostring(text));

			numDependencyMessages = numDependencyMessages + 1;
		end
	end

	function AddYesNoDetail(tag, value)
		if(value == "1") then
			return AddDetail(tag, Locale.ConvertTextKey("TXT_KEY_MODDING_LABELYES"));
		else
			return AddDetail(tag, Locale.ConvertTextKey("TXT_KEY_MODDING_LABELNO"));
		end
	end

	local version = tostring(modVersion);
	if(modDetails.Stability and modDetails.Stability) then
		version = version .. " - " .. modDetails.Stability;
	end

	AddDetail("TXT_KEY_MODDING_LABELVERSION", version);
	AddDetail("TXT_KEY_MODDING_LABELAUTHOR", modDetails.Authors);
	if(modDetails.SpecialThanks ~= nil) then
		AddDetail("TXT_KEY_MODDING_LABELSPECIALTHANKS", modDetails.SpecialThanks);
	end

	AddYesNoDetail("TXT_KEY_MODDING_LABELSUPPORTSSINGLEPLAYER", modDetails.SupportsSinglePlayer);
	AddYesNoDetail("TXT_KEY_MODDING_LABELSUPPORTSMULTIPLAYER", modDetails.SupportsMultiplayer);
	AddYesNoDetail("TXT_KEY_MODDING_LABELAFFECTSSAVEDGAMES", modDetails.AffectsSavedGames);

	AddDetail("TXT_KEY_MODDING_LABELUPDATED", modDetails.Updated);

	local details_size = Controls.DetailsBox:GetSize();
	local spacer = 10; --margin between labels and values.

	-- Attempt to center items
	local center_width = math.floor((details_size.x * 0.5) - (spacer * 0.5));
	max_detail_value_width = math.max(center_width, max_detail_value_width);

	local detail_value_truncate;
	if(max_detail_value_width + spacer + max_detail_label_width > details_size.x) then
		detail_value_truncate = true;
		max_detail_value_width = details_size.x - max_detail_label_width - spacer;
	end

	if(detail_value_truncate) then
		for i,v in ipairs(details) do
			local tooltip = v.Value.Label:GetText();
			v.Value.Label:SetToolTipString(tooltip);
			v.Value.Label:SetTruncateWidth(max_detail_value_width);

		end
	end

	if(modDetails.Exclusivity == "1") then
		AddDependencyMessage("TXT_KEY_MODDING_MOD_PARTIALLY_EXCLUSIVE");
	elseif(modDetails.Exclusivity == "2") then
		AddDependencyMessage("TXT_KEY_MODDING_MOD_EXCLUSIVE");
	end

	local modAssociations = Modding.GetModAssociations(modId, modVersion);
	local dlcAssociations = Modding.GetDlcAssociations(modId, modVersion);
	local gameVersionAssociations = Modding.GetGameVersionAssociations(modId, modVersion);

	for i = #dlcAssociations, 1, -1 do
		local dlc = dlcAssociations[i];
		if(dlc.PackageID == "8871E748-29A4-4910-8C57-8C99E32D0167") then
			table.remove(dlcAssociations, i);
		end
	end

	-- Show dependencies FIRST
	for i,v in ipairs(modAssociations) do
		if(v.Type == 2) then
			local modTitle = string.format("%s (v. %i - %i)", v.ModTitle, v.MinVersion, v.MaxVersion);
			AddDependencyMessage("TXT_KEY_MODDING_DEPENDSON", modTitle);
		end
	end

	for i,v in ipairs(dlcAssociations) do
		if(v.Type == 2) then
			local dlcTitle;
			if(v.PackageID == "*") then
				dlcTitle = Locale.Lookup("TXT_KEY_MODDING_BLOCKS_ALL_OTHER_DLC");
			else
				local packageID = string.gsub(v.PackageID, "-", "");
				packageID = Locale.ToUpper(packageID);
				dlcTitle = Locale.Lookup("TXT_KEY_" .. packageID .. "_DESCRIPTION");
			end

			AddDependencyMessage("TXT_KEY_MODDING_DEPENDSON", dlcTitle);
		end
	end

	for i,v in ipairs(gameVersionAssociations) do
		if(v.Type == 2) then
			local gameVersionTitle = Locale.Lookup("TXT_KEY_MODDING_GAMEVERSION", v.MinVersion, v.MaxVersion);
			AddDependencyMessage("TXT_KEY_MODDING_DEPENDSON", gameVersionTitle);
		end
	end


	-- References SECOND
		for i,v in ipairs(modAssociations) do
		if(v.Type == 1) then
			local modTitle = string.format("%s (v. %i - %i)", v.ModTitle, v.MinVersion, v.MaxVersion);
			AddDependencyMessage("TXT_KEY_MODDING_REFERENCES", modTitle);
		end
	end

	for i,v in ipairs(dlcAssociations) do
		if(v.Type == 1) then
			local dlcTitle;
			if(v.PackageID == "*") then
				dlcTitle = Locale.Lookup("TXT_KEY_MODDING_BLOCKS_ALL_OTHER_DLC");
			else
				local packageID = string.gsub(v.PackageID, "-", "");
				packageID = Locale.ToUpper(packageID);
				dlcTitle = Locale.Lookup("TXT_KEY_" .. packageID .. "_DESCRIPTION");
			end

			AddDependencyMessage("TXT_KEY_MODDING_REFERENCES", dlcTitle);
		end
	end

	for i,v in ipairs(gameVersionAssociations) do
		if(v.Type == 1) then
			local gameVersionTitle = Locale.Lookup("TXT_KEY_MODDING_GAMEVERSION", v.MinVersion, v.MaxVersion);
			AddDependencyMessage("TXT_KEY_MODDING_REFERENCES", gameVersionTitle);
		end
	end

	-- End with Blockers
	for i,v in ipairs(modAssociations) do
		if(v.Type == -1) then
			local modTitle = string.format("%s (v. %i - %i)", v.ModTitle, v.MinVersion, v.MaxVersion);
			AddDependencyMessage("TXT_KEY_MODDING_BLOCKS", modTitle);
		end
	end

	for i,v in ipairs(dlcAssociations) do
		if(v.Type == -1) then
			local dlcTitle;
			if(v.PackageID == "*") then
				dlcTitle = Locale.Lookup("TXT_KEY_MODDING_BLOCKS_ALL_OTHER_DLC");
			else
				local packageID = string.gsub(v.PackageID, "-", "");
				packageID = Locale.ToUpper(packageID);
				dlcTitle = Locale.Lookup("TXT_KEY_" .. packageID .. "_DESCRIPTION");
			end

			AddDependencyMessage("TXT_KEY_MODDING_BLOCKS", dlcTitle);
		end
	end

	for i,v in ipairs(gameVersionAssociations) do
		if(v.Type == -1) then
			local gameVersionTitle = Locale.Lookup("TXT_KEY_MODDING_GAMEVERSION", v.MinVersion, v.MaxVersion);
			AddDependencyMessage("TXT_KEY_MODDING_BLOCKS", gameVersionTitle);
		end
	end

	if(numDependencyMessages == 0) then
		AddDependencyMessage("TXT_KEY_MODDING_NOASSOCIATIONS");
	end

	Controls.DetailValuesStack:SetSize{x = max_detail_value_width, y =  details_size.y};
	Controls.DetailValuesStack:SetOffsetVal(details_size.x - max_detail_value_width, 0);

	Controls.DetailLabelsStack:SetOffsetVal(details_size.x - max_detail_value_width - spacer -  max_detail_label_width, 0);
	Controls.DetailLabelsStack:ReprocessAnchoring();

	Controls.UnsubscribeButton:SetHide( not Modding.CanUnsubscribeMod(modId, modVersion) )
	Controls.DeleteButton:SetHide( not Modding.CanDeleteMod(modId, modVersion) )

	Controls.DetailsDependentModStack:ReprocessAnchoring();
	Controls.DetailsDependentModStack:CalculateSize();
	Controls.DescriptionScrollPanel:CalculateInternalSize();
	Controls.DescriptionScrollPanel:SetScrollValue(0);

	SetListingsState("details");
end

----------------------------------------------------------------
----------------------------------------------------------------
Controls.No:RegisterCallback(Mouse.eLClick, function()
	UIManager:PopModal( Controls.DeleteConfirm )
end)

Controls.DeleteButton:RegisterCallback( Mouse.eLClick, function()
	--
	-- Populate effected mods list here!!!!!!
	--
	g_DependentMods:ResetInstances();

	-- For number of dependent mods, add modes to local table
	local mods = {};

	Controls.EffectedModsElements:SetHide( #mods <= 0 )

	local modId = g_SelectedModInfo.ModId
	local modVersion = g_SelectedModInfo.Version
	local hasUserData = Modding.HasUserData( modId, modVersion )
	Controls.DeleteUserData:SetHide(not hasUserData);
	Controls.ConfirmText:LocalizeAndSetText("TXT_KEY_DELETE_MOD_TXT");

	UIManager:PushModal(Controls.DeleteConfirm);

	Controls.Yes:RegisterCallback(Mouse.eLClick, function()
		UIManager:PopModal( Controls.DeleteConfirm )
		Modding.DeleteMod( modId, modVersion )
		if Controls.DeleteUserData:IsChecked() then
			Modding.DeleteUserData( modId, modVersion )
		end
	end)
end)

----------------------------------------------------------------
----------------------------------------------------------------
Controls.UnsubscribeButton:RegisterCallback( Mouse.eLClick, function()
	--
	-- Populate effected mods list here!!!!!!
	--
	g_DependentMods:ResetInstances();

	Controls.EffectedModsElements:SetHide(true);
	Controls.DeleteUserData:SetHide(true);

	Controls.ConfirmText:LocalizeAndSetText( "TXT_KEY_MODDING_UNSUBSCRIBE_CONFIRM" )

	UIManager:PushModal( Controls.DeleteConfirm )

	Controls.Yes:RegisterCallback(Mouse.eLClick, function()
		UIManager:PopModal( Controls.DeleteConfirm )
		Modding.UnsubscribeMod( g_SelectedModInfo.ModId, g_SelectedModInfo.Version )
	end);

end)

----------------------------------------------------------------
----------------------------------------------------------------
-- BoxButtons currently do not support highlight colors via XML.
-- In these mouse events, we fake the highlight colors.
function OnListingMouseEnter(_, _, listing)
	listing:SetColor(ListingBoxHighlightColor);
end

function OnListingMouseExit(_, _, listing)
	listing:SetColor(ListingBoxDefaultColor);
end

local gbString = Locale.ConvertTextKey("TXT_KEY_MODDING_FILESIZE_GB");
local mbString = Locale.ConvertTextKey("TXT_KEY_MODDING_FILESIZE_MB");
local kbString = Locale.ConvertTextKey("TXT_KEY_MODDING_FILESIZE_KB");
local byteString = Locale.ConvertTextKey("TXT_KEY_MODDING_FILESIZE_B");

function FileSizeAsString(size)
	if(size > 1073741824) then
		return string.format("%.2f %s", size / 1073741824, gbString);
	elseif(size > 1048576) then
		return string.format("%.2f %s", size / 1048576, mbString);
	elseif(size > 1024) then
		return string.format("%d %s", size / 1024, kbString);
	else
		return string.format("%d %s", size, byteString);
	end
end

Controls.ShowDLCMods:RegisterCheckHandler( function(bCheck)
	Modding.SetSystemProperty( "ShowDLCMods", bCheck and "1" or "0" )
	RefreshMods()
end)


--------------------------------------------------
-- Event Handlers

do
	local function NavigateBack()
		if g_CurrentListingsState == "details" then
			SetListingsState( "results" )
		else
			Events.ExitToMainMenu()
		end
	end

	local VK_ESCAPE = Keys.VK_ESCAPE
	local KeyDown = KeyEvents.KeyDown
	ContextPtr:SetInputHandler( function( uiMsg, wParam )
		if uiMsg == KeyDown then
			if wParam == VK_ESCAPE then
				NavigateBack()
			end
			return true
		end
	end)
	Controls.BackButton:RegisterCallback( Mouse.eLClick, NavigateBack )
end

ContextPtr:SetShowHideHandler( function( isHide )
	if not isHide then
		SetListingsState( "results" )
		Controls.ShowDLCMods:SetCheck( Modding.GetSystemProperty("ShowDLCMods") == "1" )
		Controls.WorkshopButton:SetHide( not Steam.IsOverlayEnabled() )
		RefreshMods()
	end
end)

Controls.WorkshopButton:RegisterCallback(Mouse.eLClick, function()
	Steam.ActivateGameOverlayToWebPage("http://steamcommunity.com/workshop/browse?appid=8930")
end)

local function activateEnabledMods( command, gameType )
	UIManager:SetUICursor( 1 )
	if isDirty then
		isDirty = false
		Modding.DeactivateMods()
	end
	Modding.ActivateEnabledMods()
	if gameType then
		PreGame.SetInternetGame( false )
		PreGame.SetGameType( gameType )
		local map = Modding.GetActivatedModEntryPoints("Map")() or Modding.GetActivatedModEntryPoints("MapScript")()
		if map then
			print( "Found MOD map for", Modding.GetModProperty( map.ModID, map.Version, "Name" ), map.File )
			map = Modding.GetEvaluatedFilePath( map.ModID, map.Version, map.File ).EvaluatedPath
			PreGame.SetMapScript( map )
			PreGame.SetLoadWBScenario( UI.IsMapScenario( map ) )
		end
	end
	-- Send out an event to continue on to the command popup.  We will send this whether or not the mod switched the UIs
	Events.SystemUpdateUI( SystemUpdateUIType.RestoreUI, command )
end

Controls.CivilopediaButton:RegisterCallback( Mouse.eLClick, function()
	activateEnabledMods "Civilopedia"
end)

Controls.LoadGameButton:RegisterCallback(Mouse.eLClick, function()
	activateEnabledMods "LoadGameMenu"
end)

Controls.SinglePlayerButton:RegisterCallback(Mouse.eLClick, function()
	activateEnabledMods( "ModsMenu", GameTypes.GAME_SINGLE_PLAYER )
end)

Controls.HotSeatButton:RegisterCallback(Mouse.eLClick, function()
	activateEnabledMods( "HotSeatSetup", GameTypes.GAME_HOTSEAT_MULTIPLAYER )
end)
