-------------------------------------------------
-- written by bc1 using Notepad++
-------------------------------------------------

include "PopulateUniques"

local AdjustArtOnButton= AdjustArtOnButton
local PopulateUniqueButtons  = PopulateUniqueButtons

questionOffset, questionTextureSheet = IconLookup( 23, 64, "CIV_COLOR_ATLAS" );
unknownString = Locale.ConvertTextKey( "TXT_KEY_MISC_UNKNOWN" );

function AdjustArtOnUniqueUnitButton( button, frame, row, size )
	return AdjustArtOnButton( button, row, size, GetHelpTextForUnit, true )
end

function AdjustArtOnUniqueBuildingButton( button, frame, row, size )
	return AdjustArtOnButton( button, row, size, GetHelpTextForBuilding, false, false, false )
end

function AdjustArtOnUniqueImprovementButton( button, frame, row, size )
	return AdjustArtOnButton( button, row, size, GetHelpTextForImprovement, false, false, false )
end

function PopulateUniqueBonuses( controls, civ )
	local buttonNum = 1
	local bonusText = {}
	local function staticButton( row, ... )
		local button = controls["B"..buttonNum]
		if button then
			AdjustArtOnButton( button, row, button:GetSizeX(), ... )
			bonusText[ buttonNum ] = row.Description
			buttonNum = buttonNum + 1
		end
	end
	PopulateUniqueButtons( staticButton, civ )
	for i = 1, 9 do
		local frame = controls["BF"..i]
		if frame then
			frame:SetHide( i >= buttonNum )
		else
			break
		end
	end
	return bonusText
end

function PopulateUniqueBonuses_CreateCached()
	return function( controls, civType )
		PopulateUniqueBonuses( controls, GameInfo.Civilizations[ civType ] )
	end
end
