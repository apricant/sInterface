local addon, ns = ...
local E, C = ns.E, ns.C

if not C.np.enabled then return end;

local colours = {
	secure = { 0, 255, 0 },
	insecure = { 255, 124, 0 },
	na = { 255, 0, 0 }
}

local sPlates, events = CreateFrame("FRAME"), {};

function sPlates:NAME_PLATE_UNIT_ADDED(...)
	local namePlateUnitToken = ...
	local namePlateFrameBase = C_NamePlate.GetNamePlateForUnit(namePlateUnitToken, issecure());

	if not namePlateFrameBase then return end

	local namePlate = namePlateFrameBase.UnitFrame

	local castBar = namePlate.castBar
	castBar:SetStatusBarTexture(C.general.texture)
	castBar:SetHeight(3)

	local healthBar = namePlate.healthBar
	healthBar:SetPoint("BOTTOMLEFT", castBar, "TOPLEFT", 0, 3)
	healthBar:SetPoint("BOTTOMRIGHT", castBar, "TOPRIGHT", 0, 3)
end

hooksecurefunc("CompactUnitFrame_UpdateHealthColor", function(frame)
	if UnitIsPlayer(frame.unit) or not UnitAffectingCombat("player") then return end
	if not (C.np.tankMode and E:PlayerIsTank())  then return end

	local status = UnitThreatSituation("player", frame.unit)
	if status == nil then return end
	if status == 3 then
		r, g, b = unpack(colours.secure)
	elseif status == 2 then
		r, g, b = unpack(colours.insecure)
	else
		r, g, b = unpack(colours.na)
	end
	frame.healthBar.barTexture:SetVertexColor (r, g, b)
end)

hooksecurefunc("CompactUnitFrame_UpdateName", function(frame)
	if frame:IsForbidden() then return end
	if UnitIsPlayer(frame.unit) then
		frame.name:SetText(UnitName(frame.unit))
	end
	frame.name:SetTextColor(1, 1, 1, 1)
	frame.name:SetFont(C.general.font, C.general.fontSize-4, "OUTLINE")
end)

hooksecurefunc("DefaultCompactNamePlateFrameSetupInternal", function(namePlate)
	if namePlate.styled or namePlate:IsForbidden() then return end
	namePlate.healthBar:SetStatusBarTexture(C.general.texture)
	namePlate.healthBar.border:Hide()
	E:ShadowedBorder(namePlate.healthBar)

	namePlate.castBar.Flash:SetTexture(nil)
	namePlate.castBar.background:SetAlpha(0.3)
	E:ShadowedBorder(namePlate.castBar)

	namePlate.name:SetParent(namePlate.healthBar)
	namePlate.name:SetPoint("BOTTOM", namePlate.healthBar, "TOP", 0, -3)

	namePlate.styled = true
end)
--end

sPlates:SetScript("OnEvent", function(self, event, ...)
	self[event](self, ...); -- call one of the functions above
end);
for k, v in pairs(sPlates) do
	sPlates:RegisterEvent(k); -- Register all events for which handlers have been defined
end
