local _, ns = ...
local E, C = ns.E, ns.C

-- Not sure if overwriting blizzard variables is a good idea?
BUFF_HORIZ_SPACING = -8

local function style(aura)
	if not aura or (aura and aura.styled) then return end

	local name = aura:GetName()
	local icon = _G[name.."Icon"]
	icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)

	local border = _G[name.."Border"]
	if border then border:SetAlpha(0) end

	aura:SetSize(C.auras.size, C.auras.size)

	local font, _ = aura.duration:GetFont()
	aura.duration:SetParent(aura)
	aura.duration:SetPoint("TOP", aura, "BOTTOM", 0, 5)
	aura.duration:SetJustifyH("CENTER")
	aura.duration:SetFont(font, C.auras.durationHeight, "OUTLINE")

	E:ShadowedBorder(aura)
	
	aura.styled = true
end

local function updateBuffAnchors()
	if BUFF_ACTUAL_DISPLAY == 0 then return end

	local buff = _G["BuffButton1"]
	if (Minimap:IsShown()) then
		buff:SetPoint("TOPRIGHT", Minimap, "TOPLEFT", BUFF_HORIZ_SPACING, 0);
	else
		buff:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -C.general.edgeSpacing, -C.general.edgeSpacing);
	end

	for i = 1, BUFF_ACTUAL_DISPLAY do
		local buff = _G["BuffButton"..i]
		style(buff)
	end
	
end

local function updateDebuffAnchors(buttonName, index)
	local button = _G[buttonName..index]
	if not button then return end

	if BUFF_ACTUAL_DISPLAY == 0 then
		if (Minimap:IsShown()) then
			button:SetPoint("TOPRIGHT", Minimap, "TOPLEFT", BUFF_HORIZ_SPACING, 0)
		else
			button:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", BUFF_HORIZ_SPACING, BUFF_HORIZ_SPACING)
		end
	else
		local anchorIndex, anchor, modulo, ab
		modulo = BUFF_ACTUAL_DISPLAY % BUFFS_PER_ROW
		ab = abs(modulo - 1)
		anchorIndex = modulo == 0 and (BUFF_ACTUAL_DISPLAY - (BUFFS_PER_ROW - 1)) or (BUFF_ACTUAL_DISPLAY - ab)
		anchor = _G["BuffButton"..anchorIndex]
		button:ClearAllPoints()
		button:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -ceil(anchor:GetHeight()*1.5))
	end

	for i = 1, DEBUFF_ACTUAL_DISPLAY do
		local debuff = _G["DebuffButton"..i]
		style(debuff)
	end
end


local function updateAllAnchors()
	updateBuffAnchors()
	updateDebuffAnchors("DebuffButton", 1)
end


hooksecurefunc("BuffFrame_UpdateAllBuffAnchors", updateAllAnchors)
hooksecurefunc("DebuffButton_UpdateAnchors", updateAllAnchors)
Minimap:HookScript("OnHide", updateAllAnchors)
Minimap:HookScript("OnShow", updateAllAnchors)
