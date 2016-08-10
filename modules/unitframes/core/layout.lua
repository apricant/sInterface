local name, ns = ...
local oUF = ns.oUF or oUF
local cfg = ns.cfg
local _, class = UnitClass('player')
local class_color = RAID_CLASS_COLORS[class]

local backdrop = {
	bgFile = [=[Interface\ChatFrame\ChatFrameBackground]=],
	insets = {top = -1, left = -1, bottom = -1, right = -1},
}

local OnEnter = function(self)
	UnitFrame_OnEnter(self)
	if self.lfd then
		if self.lfd:IsShown() and self.lfd.lfdHideAnim:IsPlaying() then
			self.lfd.lfdHideAnim:Stop()
		elseif self.lfd.lfdShowAnim and self.lfd.lfdHideAnim then
			self.lfd.lfdHideAnim:Stop()
			self.lfd.lfdShowAnim:Play()
		end
	end
	self.Highlight:Show()
end

local OnLeave = function(self)
	UnitFrame_OnLeave(self)
	if self.lfd then
		if self.lfd.lfdHideAnim then
			self.lfd.lfdShowAnim:Stop()
			self.lfd.lfdHideAnim:Play()
		end
	end
	self.Highlight:Hide()
end

local dropdown = CreateFrame('Frame', name .. 'DropDown', UIParent, 'UIDropDownMenuTemplate')

local function menu(self)
	dropdown:SetParent(self)
	return ToggleDropDownMenu(1, nil, dropdown, self:GetName(), -3, 0)
end

local init = function(self)
	local unit = self:GetParent().unit
	local menu, name, id

	if(not unit) then
		return
	end

	if(UnitIsUnit(unit, 'player')) then
		menu = 'SELF'
	elseif(UnitIsUnit(unit, 'vehicle')) then
		menu = 'VEHICLE'
	elseif(UnitIsUnit(unit, 'pet')) then
		menu = 'PET'
	elseif(UnitIsPlayer(unit)) then
		id = UnitInRaid(unit)
		if(id) then
			menu = 'RAID_PLAYER'
			name = GetRaidRosterInfo(id)
		elseif(UnitInParty(unit)) then
			menu = 'PARTY'
		else
			menu = 'PLAYER'
		end
	else
		menu = 'TARGET'
		name = RAID_TARGET_ICON
	end

	if (menu) then
		UnitPopup_ShowMenu(self, menu, unit, name, id)
	end
end

UIDropDownMenu_Initialize(dropdown, init, 'MENU')

local GetTime = GetTime
local floor, fmod = floor, math.fmod
local day, hour, minute = 86400, 3600, 60

local FormatTime = function(s)
	if s >= day then
		return format('%dd', floor(s/day + 0.5))
	elseif s >= hour then
		return format('%dh', floor(s/hour + 0.5))
	elseif s >= minute then
		return format('%dm', floor(s/minute + 0.5))
	end
	return format('%d', fmod(s, minute))
end

local CreateAuraTimer = function(self,elapsed)
	self.elapsed = (self.elapsed or 0) + elapsed
	if self.elapsed >= 0.1 then
		self.timeLeft = self.expires - GetTime()
		if self.timeLeft > 0 then
			local time = FormatTime(self.timeLeft)
				self.remaining:SetText(time)
			if self.timeLeft < 6 then
				self.remaining:SetTextColor(0.69, 0.31, 0.31)
			elseif self.timeLeft < 60 then
				self.remaining:SetTextColor(1, 0.85, 0)
			else
				self.remaining:SetTextColor(1, 1, 1)
			end
		else
			self.remaining:Hide()
			self:SetScript('OnUpdate', nil)
		end
		self.elapsed = 0
	end
end

local auraIcon = function(auras, button)
	local c = button.count
	c:ClearAllPoints()
	c:SetPoint('BOTTOMRIGHT', 3, -1)
	c:SetFontObject(nil)
	c:SetFont(cfg.aura.font, cfg.aura.fontsize, cfg.aura.fontflag)
	c:SetTextColor(1, 1, 1)

	auras.disableCooldown = cfg.aura.disableCooldown
	auras.showDebuffType = true

	button.overlay:SetTexture(nil)
	button.icon:SetTexCoord(.1, .9, .1, .9)
	button:SetBackdrop(backdrop)
	button:SetBackdropColor(0, 0, 0, 1)

	button.glow = CreateFrame('Frame', nil, button)
	button.glow:SetPoint('TOPLEFT', button, 'TOPLEFT', -4, 4)
	button.glow:SetPoint('BOTTOMRIGHT', button, 'BOTTOMRIGHT', 4, -4)
	button.glow:SetFrameLevel(button:GetFrameLevel()-1)
	button.glow:SetBackdrop({
		edgeFile = cfg.shadow, edgeSize = 5,
	})
	button.glow:SetBackdropBorderColor(0, 0, 0, 0.5)
	button.glow:SetAlpha(1)

	local remaining = fs(button, 'OVERLAY', cfg.aura.font, cfg.aura.fontsize, cfg.aura.fontflag, 1, 1, 1)
	remaining:SetPoint('TOPLEFT')
	button.remaining = remaining
end

local PostUpdateIcon = function(icons, unit, icon, index, offset)
	local name, _, _, _, dtype, duration, expirationTime, unitCaster = UnitAura(unit, index, icon.filter)
	local texture = icon.icon
	if icon.isPlayer or UnitIsFriend('player', unit) or not icon.isDebuff then
		texture:SetDesaturated(false)
	else
		texture:SetDesaturated(true)
	end
	if duration and duration > 0 and not cfg.aura.disableTime then
		icon.remaining:Show()
	else
		icon.remaining:Hide()
	end

	icon.duration = duration
	icon.expires = expirationTime
	icon:SetScript('OnUpdate', CreateAuraTimer)
end

local Auras = function(self)
		local config
		if self.unit == 'player' then
			config = cfg.aura.player
		elseif self.unit == 'target' then
			config = cfg.aura.target
		elseif self.unit == 'party' then
			config = cfg.aura.party
		elseif self.unit == 'focus' then
			config = cfg.aura.focus
		elseif self.unit == 'tank' then
			config = cfg.aura.tank
		elseif self.unit == 'boss' then
			config = cfg.aura.boss
		else
			return
		end

		local b = CreateFrame('Frame', nil, self)
		b.spacing = floor((self:GetWidth() - config.size * config.num) / (config.num-1))
		b:SetSize(self:GetWidth(), config.size)
		b:SetPoint('BOTTOMLEFT', self.Experience or self.Reputation or self, 'TOPLEFT', 0, 9)
		b.initialAnchor = 'TOPLEFT'
		b['growth-y'] = 'UP'
		b.PostCreateIcon = auraIcon
		b.PostUpdateIcon = PostUpdateIcon
		if config.mode == 'aura' then
			b.gap = config.gap
			b.numBuffs = config.num
			b.numDebuffs = config.num
			self.Auras = b
		elseif config.mode == 'debuff' then
			self.Debuffs = b
		else
			self.Buffs = b
		end
end

local PostUpdateHealth = function(health, unit)
	if UnitIsDead(unit) or UnitIsGhost(unit) or not UnitIsConnected(unit) then
		health:SetValue(0)
	end
end

local PostUpdatePower = function(Power, unit, min, max)
	local parent = Power:GetParent()
	local h = parent.Health
	if max == 0 then
		Power:Hide()
		h:SetHeight(parent:GetHeight())
	else
		Power:Show()
		h:SetHeight(parent:GetHeight() - Power:GetHeight() - 1)
	end
end

local function UpdateClassIconTexture(element)
	local r, g, b = 1, 1, 2/5
	if not UnitHasVehicleUI('player') then
		if playerClass == 'MONK' then
			r, g, b = 0, 4/5, 3/5
		elseif playerClass == 'WARLOCK' then
			r, g, b = 2/3, 1/3, 2/3
		elseif playerClass == 'PRIEST' then
			r, g, b = 2/3, 1/4, 2/3
		elseif playerClass == 'PALADIN' then
			r, g, b = 1, 1, 2/5
		elseif playerClass == 'MAGE' then
			r, g, b = 5/6, 1/2, 5/6
		end
	end

	for index = 1, 8 do
		local ClassIcon = element[index]
		ClassIcon.Texture:SetColorTexture(r, g, b)
	end
end

local function PostUpdateClassIcon(element, cur, max, diff, powerType, event)
	if event == 'ClassPowerDisable' and class ~= 'DEATHKNIGHT' then
		local ClassIcon = element[1]
		ClassIcon:GetParent():Hide()
		return
	end
	if(diff or event == 'ClassPowerEnable') then
		element:UpdateTexture()

		local width 
		width = max == 8 and (cfg.uf.primary.width / 5) or (cfg.uf.primary.width / max)
		width = width - 1
			
		for index = 1, max do
			local ClassIcon = element[index]
			ClassIcon:SetWidth(width)

			if index == 1 then
				ClassIcon:GetParent():Show()
			end

			if max == 8 then
				if index == 6 then
					ClassIcon:ClearAllPoints()
					ClassIcon:SetPoint("LEFT", element[index-5])
				end

				if index > 5 then
					ClassIcon.Texture:SetColorTexture(0.8, 0.1, 0.1)
				end
			else
				if index > 1 then
					ClassIcon:ClearAllPoints()
					ClassIcon:SetPoint('LEFT', element[index-1], 'RIGHT', 1, 0)
				end
			end
		end
	end
end

local channelingTicks = {
	-- warlock
	[GetSpellInfo(689)] = 6, -- drain life
	[GetSpellInfo(193440)] = 3, -- demonwrath
	[GetSpellInfo(198590)] = 6, -- drain soul
	-- druid
	[GetSpellInfo(740)] = 4, -- tranquility
	-- priest
	[GetSpellInfo(64843)] = 4, -- divine hymn
	[GetSpellInfo(15407)] = 4, -- mind flay
	[GetSpellInfo(48045)] = 5, -- mind sear
	[GetSpellInfo(47540)] = 2, -- penance
	[GetSpellInfo(205065)] = 4, -- void torrent
	-- mage
	[GetSpellInfo(5143)] = 5, -- arcane missiles
	[GetSpellInfo(12051)] = 3, -- evocation
	[GetSpellInfo(205021)] = 10, -- ray of frost
	-- monk
	[GetSpellInfo(117952)] = 4, -- crackling jade lightning
	[GetSpellInfo(191837)] = 3, -- essence font
}

local ticks = {}

local setBarTicks = function(castBar, ticknum)
	if ticknum and ticknum > 0 then
		local delta = castBar:GetWidth() / ticknum
		for k = 1, ticknum do
			if not ticks[k] then
				ticks[k] = castBar:CreateTexture(nil, 'OVERLAY')
				ticks[k]:SetTexture(cfg.texture)
				ticks[k]:SetVertexColor(0.6, 0.6, 0.6)
				ticks[k]:SetWidth(2)
				ticks[k]:SetHeight(castBar:GetHeight())
			end
			ticks[k]:ClearAllPoints()
			ticks[k]:SetPoint('CENTER', castBar, 'LEFT', delta * k, 0 )
			ticks[k]:Show()
		end
	else
		for k, v in pairs(ticks) do
			v:Hide()
		end
	end
end

local OnCastbarUpdate = function(self, elapsed)
	local currentTime = GetTime()
	if self.casting or self.channeling then
		local parent = self:GetParent()
		local duration = self.casting and self.duration + elapsed or self.duration - elapsed
		if (self.casting and duration >= self.max) or (self.channeling and duration <= 0) then
			self.casting = nil
			self.channeling = nil
			return
		end
		if parent.unit == 'player' then
			if self.delay ~= 0 then
				self.Time:SetFormattedText('%.1f | %.1f |cffff0000|%.1f|r', duration, self.max, self.delay )
			elseif self.Lag then
				if self.SafeZone.timeDiff >= (self.max*.5) or self.SafeZone.timeDiff == 0 then
					self.Time:SetFormattedText('%.1f | %.1f', duration, self.max)
					self.Lag:SetFormattedText('')
				else
					self.Time:SetFormattedText('%.1f | %.1f', duration, self.max)
					self.Lag:SetFormattedText('%d ms', self.SafeZone.timeDiff * 1000)
				end
			else
				self.Time:SetFormattedText('%.1f | %.1f', duration, self.max)
			end
		else
			self.Time:SetFormattedText('%.1f | %.1f', duration, self.casting and self.max + self.delay or self.max - self.delay)
		end
		self.duration = duration
		self:SetValue(duration)
		self.Spark:SetPoint('CENTER', self, 'LEFT', (duration / self.max) * self:GetWidth(), 0)
	end
end

local PostCastStart = function(self, unit)
	if self.hideAnim:IsPlaying() then
		self.hideAnim:Stop()
	end
	self.Spark:Show()
	self:SetStatusBarColor(unpack(self.casting and self.CastingColor or self.ChannelingColor))
	if self.casting then
		self.cast = true
	else
		self.cast = false
	end
	if unit == 'vehicle' then
		self.SafeZone:Hide()
		self.Lag:Hide()
	elseif unit == 'player' then
		local sf = self.SafeZone
		if not sf then return end
		if not sf.sendTime then sf.sendTime = GetTime() end
		sf.timeDiff = GetTime() - sf.sendTime
		sf.timeDiff = sf.timeDiff > self.max and self.max or sf.timeDiff
		if sf.timeDiff >= (self.max*.5) or sf.timeDiff == 0 then
			sf:SetWidth(0.01)
		else
			sf:SetWidth(self:GetWidth() * sf.timeDiff / self.max)
		end
		if not UnitInVehicle('player') then sf:Show() else sf:Hide() end
		if self.casting then
			setBarTicks(self, 0)
		else
			local spell = UnitChannelInfo(unit)
			self.channelingTicks = channelingTicks[spell] or 0
			setBarTicks(self, self.channelingTicks)
		end
	end
	if unit ~= 'player' and self.interrupt and UnitCanAttack('player', unit) then
		self:SetStatusBarColor(1, .9, .4)
	end
end

local PostCastStop = function(self, unit)
	self:Show()
	self:SetStatusBarColor(unpack(self.CompleteColor))
	self:SetValue(self.cast and self.max or 0)
	self.hideAnim:Play()
end

local PostCastFailed = function(self, event, unit)
	self:Show()
	self:SetStatusBarColor(unpack(self.FailColor))
	self:SetValue(self.max)
	self.hideAnim:Play()
end

local Castbar = function(self, unit)
	local cb = createStatusbar(self, cfg.texture, nil, nil, nil, 1, 1, 1, 1)
	local cbbg = cb:CreateTexture(nil, 'BACKGROUND')
	cbbg:SetAllPoints(cb)
	cbbg:SetTexture(cfg.texture)
	cbbg:SetVertexColor(1, 1, 1, .2)
	cb.Time = fs(cb, 'OVERLAY', cfg.font, cfg.fontsize, cfg.fontflag, 1, 1, 1, 'RIGHT')
	cb.Time:SetPoint('RIGHT', cb, -2, 4)
	cb.Text = fs(cb, 'OVERLAY', cfg.font, cfg.fontsize, cfg.fontflag, 1, 1, 1, 'LEFT')
	cb.Text:SetPoint('LEFT', cb, 2, 4)
	cb.Text:SetPoint('RIGHT', cb.Time, 'LEFT')
	cb.CastingColor = {cfg.Color.Castbar.r, cfg.Color.Castbar.g, cfg.Color.Castbar.b}
	cb.CompleteColor = {0.12, 0.86, 0.15}
	cb.FailColor = {1.0, 0.09, 0}
	cb.ChannelingColor = {0.32, 0.3, 1}
	cb.Icon = cb:CreateTexture(nil, 'ARTWORK')
	cb.Icon:SetPoint('BOTTOMRIGHT', cb, 'BOTTOMLEFT', -6, 0)
	cb.Icon:SetTexCoord(.1, .9, .1, .9)

	cb.Spark = cb:CreateTexture(nil,'OVERLAY')
	cb.Spark:SetTexture([=[Interface\Buttons\WHITE8x8]=])
	cb.Spark:SetBlendMode('Add')
	cb.Spark:SetHeight(cb:GetHeight())
	cb.Spark:SetWidth(1)
	cb.Spark:SetVertexColor(1, 1, 1)

	cb.OnUpdate = OnCastbarUpdate
	cb.PostCastStart = PostCastStart
	cb.PostChannelStart = PostCastStart
	cb.PostCastStop = PostCastStop
	cb.PostChannelStop = PostCastStop
	cb.PostCastFailed = PostCastFailed
	cb.PostCastInterrupted = PostCastFailed
	cb.bg = cbbg
	cb.Backdrop = framebd(cb, cb)
	cb.IBackdrop = framebd(cb, cb.Icon)

	cb.hideAnim = cb:CreateAnimationGroup()
	cb.hideAnim.fadeOut = cb.hideAnim:CreateAnimation("ALPHA")
	cb.hideAnim.fadeOut:SetStartDelay(0.1)
	cb.hideAnim.fadeOut:SetFromAlpha(cb:GetAlpha())
	cb.hideAnim.fadeOut:SetToAlpha(0)
	cb.hideAnim.fadeOut:SetDuration(0.2)
	cb.hideAnim.fadeOut:SetSmoothing("NONE")
	cb.hideAnim.fadeOut:HookScript("OnFinished", function()
		cb:Hide()
	end)

	local height = self.Health:GetHeight() - self.Power:GetHeight()
	cb:SetPoint("TOPRIGHT", self, "BOTTOMRIGHT", 0, -15)
	cb.Icon:SetSize(height*2, height*2)
	cb:SetSize(self:GetWidth()-(height*2)-6, height)
	self.Castbar = cb
end

local Healcomm = function(self)
	local myBar = createStatusbar(self.Health, cfg.texture, nil, nil, 200, 0.33, 0.59, 0.33, 0.6)
	myBar:SetPoint('TOP')
	myBar:SetPoint('BOTTOM')
	myBar:SetFrameStrata(self.Health:GetFrameStrata())
	myBar:SetFrameLevel(self.Health:GetFrameLevel())
	myBar:SetPoint('LEFT', self.Health:GetStatusBarTexture(), 'RIGHT')

	local otherBar = createStatusbar(self.Health, cfg.texture, nil, nil, 200, 0.33, 0.59, 0.33, 0.6)
	otherBar:SetPoint('TOP')
	otherBar:SetPoint('BOTTOM')
	otherBar:SetFrameStrata(self.Health:GetFrameStrata())
	otherBar:SetFrameLevel(self.Health:GetFrameLevel())
	otherBar:SetPoint('LEFT', self.Health:GetStatusBarTexture(), 'RIGHT')

	local absorbBar = createStatusbar(self.Health, cfg.texture, nil, nil, 200, 0.33, 0.59, 0.33, 0.6)
	absorbBar:SetPoint('TOP')
	absorbBar:SetPoint('BOTTOM')
	absorbBar:SetFrameStrata(self.Health:GetFrameStrata())
	absorbBar:SetFrameLevel(self.Health:GetFrameLevel())
	absorbBar:SetPoint('LEFT', self.Health:GetStatusBarTexture(), 'RIGHT')

	local healAbsorbBar = createStatusbar(self.Health, cfg.texture, nil, nil, 200, 0.33, 0.59, 0.33, 0.6)
	healAbsorbBar:SetPoint('TOP')
	healAbsorbBar:SetPoint('BOTTOM')
	healAbsorbBar:SetFrameStrata(self.Health:GetFrameStrata())
	healAbsorbBar:SetFrameLevel(self.Health:GetFrameLevel())
	healAbsorbBar:SetPoint('LEFT', self.Health:GetStatusBarTexture(), 'RIGHT')

   self.HealPrediction = {
	  myBar = myBar,
	  otherBar = otherBar,
	  absorbBar = absorbBar,
	  healAbsorbBar = healAbsorbBar,
	  maxOverflow = 1.1,
	  frequentUpdates = true,
   }
end

local Health = function(self)
	local h = createStatusbar(self, cfg.texture, nil, nil, nil, 1, 1, 1, 1)
	h:SetPoint'TOP'
	h:SetPoint'LEFT'
	h:SetPoint'RIGHT'
	h:SetHeight(cfg.uf[self.unitSize].health)

	local hbg = h:CreateTexture(nil, 'BACKGROUND')
	hbg:SetDrawLayer('BACKGROUND', 1)
	hbg:SetAllPoints(h)
	hbg:SetTexture(cfg.texture)

	h.colorClass = true
	h.colorReaction = true
	hbg.multiplier = .4

	h.frequentUpdates = false

	h.Smooth = true

	h.bg = hbg
	self.Health = h
	self.Health.PostUpdate = PostUpdateHealth
end

local LFD = function(self)
	local lfd = fs(self.Health, 'OVERLAY', cfg.symbol, 13, cfg.fontflag, 1, 1, 1)
	lfd:SetPoint('LEFT', self.Name, 'RIGHT', 0, 0)
	lfd:SetJustifyH'LEFT'

	lfd.lfdShowAnim = lfd:CreateAnimationGroup()
	lfd.lfdShowAnim.alpha = lfd.lfdShowAnim:CreateAnimation("ALPHA")
	lfd.lfdShowAnim.alpha:SetFromAlpha(0)
	lfd.lfdShowAnim.alpha:SetToAlpha(1)
	lfd.lfdShowAnim.alpha:SetDuration(0.2)
	lfd.lfdShowAnim.alpha:HookScript("OnPlay", function()
		lfd:Show()
	end)
		
	lfd.lfdHideAnim = lfd:CreateAnimationGroup()
	lfd.lfdHideAnim.alpha = lfd.lfdHideAnim:CreateAnimation("ALPHA")
	lfd.lfdHideAnim.alpha:SetStartDelay(2)
	lfd.lfdHideAnim.alpha:SetFromAlpha(lfd:GetAlpha())
	lfd.lfdHideAnim.alpha:SetToAlpha(0)
	lfd.lfdHideAnim.alpha:SetDuration(0.2)
	lfd.lfdHideAnim.alpha:HookScript("OnFinished", function()
		lfd:Hide()
	end)

	lfd:Hide()
	self.lfd = lfd
	self:Tag(lfd, '[LFD]')
end

local Power = function(self)
	local p = createStatusbar(self, cfg.texture, nil, nil, nil, 1, 1, 1, 1)
	p:SetPoint'LEFT'
	p:SetPoint'RIGHT'
	p:SetPoint('TOP', self.Health, 'BOTTOM', 0, -1)
	p:SetHeight(cfg.uf[self.unitSize].power)

	if self.unit == 'player' then p.frequentUpdates = true end

	p.Smooth = true

	local pbg = p:CreateTexture(nil, 'BACKGROUND')
	pbg:SetAllPoints(p)
	pbg:SetTexture(cfg.texture)

	p.colorPower = true
	pbg.multiplier = .4

	p.PostUpdate = PostUpdatePower

	p.bg = pbg
	self.Power = p
end

local PhaseIcon = function(self)
	local PhaseIcon = self:CreateTexture(nil, "OVERLAY")
	PhaseIcon:SetPoint("LEFT", -20, 0)
	PhaseIcon:SetSize(16, 16)
	self.PhaseIcon = PhaseIcon
end

local Size = function(self)
	local uf_cfg = cfg.uf[self.unitSize]
	local height
	if uf_cfg.power then
		height = uf_cfg.health + uf_cfg.power + 1
	else
		height = uf_cfg.health
	end
	self:SetSize(uf_cfg.width, height)
end

local Shared = function(self, unit)
	self.menu = menu

	self:SetScript('OnEnter', OnEnter)
	self:SetScript('OnLeave', OnLeave)

	self:RegisterForClicks'AnyUp'

	self:SetBackdrop({
	bgFile = [=[Interface\ChatFrame\ChatFrameBackground]=],
		insets = {top = 0, left = 0, bottom = 0, right = 0},
	})
	self:SetBackdropColor(0, 0, 0)

	Size(self)
	Health(self)
	Healcomm(self)

	framebd(self, self)

	local ricon = self.Health:CreateTexture(nil, 'OVERLAY')
	ricon:SetTexture(cfg.raidicons)
	ricon:SetSize(20, 20)
	ricon:SetPoint('TOP', 0, 10)
	self.RaidIcon = ricon

	local hl = self.Health:CreateTexture(nil, 'OVERLAY')
	hl:SetAllPoints(self)
	hl:SetTexture([=[Interface\Buttons\WHITE8x8]=])
	hl:SetVertexColor(1,1,1,.1)
	hl:SetBlendMode('ADD')
	hl:Hide()
	self.Highlight = hl
end

local UnitSpecific = {
	player = function(self, ...)
		self.unit = 'player'
		self.unitSize = 'primary'

		Shared(self, ...)

		Power(self)
		Castbar(self)

		local fcf = CreateFrame("Frame", nil, self.Health)
		fcf:SetSize(32, 32)
		fcf:SetPoint("CENTER")
		fcf.mode = "Fountain"
		for i = 1, 6 do
			fcf[i] = fcf:CreateFontString(nil, "OVERLAY", "CombatTextFont")
		end
		self.FloatingCombatFeedback = fcf

		PetCastingBarFrame:UnregisterAllEvents()
		PetCastingBarFrame.Show = function() end
		PetCastingBarFrame:Hide()

		local htext = fs(self.Health, 'OVERLAY', cfg.font, cfg.fontsize, cfg.fontflag, 1, 1, 1)
		htext:SetPoint('TOPRIGHT', -2, 4)
		htext.frequentUpdates = .1
		self:Tag(htext, '[primary:health]')

		local ptext = fs(self.Health, 'OVERLAY', cfg.font, cfg.fontsize, cfg.fontflag, 1, 1, 1)
		ptext:SetPoint('TOPLEFT', 2, 4)
		ptext.frequentUpdates = .1
		self:Tag(ptext, '[player:power]')

		local ClassIconBar = CreateFrame('Frame', nil, self)
		ClassIconBar:SetWidth(self:GetWidth())
		ClassIconBar:SetHeight(self.Power:GetHeight())
		ClassIconBar:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -4)
		framebd(ClassIconBar, ClassIconBar)

		local ClassIcons = {}
		ClassIcons.UpdateTexture = UpdateClassIconTexture
		ClassIcons.PostUpdate = PostUpdateClassIcon
		for index = 1, 8 do
			local ClassIcon = CreateFrame('Frame', nil, ClassIconBar)
			ClassIcon:SetBackdrop(backdrop)
			ClassIcon:SetBackdropColor(0, 0, 0)
			ClassIcon:SetHeight(self.Power:GetHeight())

			if index > 1 then
				ClassIcon:SetPoint('LEFT', ClassIcons[index-1], 'RIGHT', 1, 0)
			else
				ClassIcon:SetPoint('LEFT', ClassIconBar, 'LEFT', 0, 0)
			end

			local Texture = ClassIcon:CreateTexture(nil, 'BORDER', nil, index > 5 and 1 or 0)
			Texture:SetAllPoints()
			ClassIcon.Texture = Texture

			ClassIcons[index] = ClassIcon
		end
		self.ClassIcons = ClassIcons

		if(class == 'DEATHKNIGHT') then
			local Runes = {}
			for index = 1, 6 do
				local Rune = CreateFrame('StatusBar', nil, ClassIconBar)
				local width = (self:GetWidth()/6)-1
				Rune:SetSize(width, cfg.uf.primary.power)
				Rune:SetStatusBarTexture(cfg.texture)
				Rune:SetStatusBarColor(0.9, 0, 0.7)

				if index > 1 then
					Rune:SetPoint('LEFT', Runes[index - 1], 'RIGHT', 1, 0)
				else
					Rune:SetPoint('LEFT', ClassIconBar, 'LEFT', 0, 0)
				end

				if index == 6 then
					Rune:SetWidth(width+1)
				end

				local RuneBG = Rune:CreateTexture(nil, 'BORDER')
				RuneBG:SetAllPoints()
				RuneBG:SetColorTexture(1/6, 1/9, 1/3)

				Runes[index] = Rune
			end
			self.Runes = Runes
		end

		self.GCD = CreateFrame('Frame', nil, self.Health)
		self.GCD:SetPoint('LEFT', self.Health, 'LEFT')
		self.GCD:SetPoint('RIGHT', self.Health, 'RIGHT')
		self.GCD:SetHeight(cfg.uf.primary.health+4)

		self.GCD.Spark = self.GCD:CreateTexture(nil, "OVERLAY")
		self.GCD.Spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
		self.GCD.Spark:SetBlendMode("ADD")
		self.GCD.Spark:SetHeight((cfg.uf.primary.health*2)+4)
		self.GCD.Spark:SetWidth(9)
		self.GCD.Spark:SetPoint('LEFT', self.Health, 'LEFT', 0, 0)

		local exp_rep_bar = createStatusbar(self, cfg.texture, nil, cfg.exp_rep.height, cfg.uf.primary.width, 1, 0, 1, 1)
		exp_rep_bar:SetPoint(unpack(cfg.exp_rep.pos))
		exp_rep_bar.bg = exp_rep_bar:CreateTexture(nil, 'BORDER')
		exp_rep_bar.bg:SetAllPoints(exp_rep_bar)
		exp_rep_bar.bg:SetTexture(cfg.texture)
		exp_rep_bar.text = fs(exp_rep_bar, 'OVERLAY', cfg.aura.font, cfg.aura.fontsize, cfg.aura.fontflag, 1, 1, 1)
		exp_rep_bar.text:SetPoint("CENTER", 0, 10)
		exp_rep_bar.text:Hide()
		exp_rep_bar:SetScript('OnEnter', function(self)UIFrameFadeIn(exp_rep_bar.text, 0.3, 0, 1)end)
		exp_rep_bar:SetScript('OnLeave', function(self)UIFrameFadeOut(exp_rep_bar.text, 0.3, 1, 0)end)
		exp_rep_bar.bd = framebd(exp_rep_bar, exp_rep_bar)

		if UnitLevel('player') < MAX_PLAYER_LEVEL and not IsXPUserDisabled() then
			self.OverrideUpdateColor = function(element, honor)
				element:SetStatusBarColor(1, 0, 1, 1)
			end
			exp_rep_bar.bg:SetVertexColor(1, 0.3, 1, 0.3)
			exp_rep_bar.Rested = createStatusbar(exp_rep_bar, cfg.texture, nil, nil, nil, 0, .4, 1, .6)
			exp_rep_bar.Rested:SetAllPoints(exp_rep_bar)
			self:Tag(exp_rep_bar.text, '[curxp] / [maxxp] ([perxp]%)')
			self.Experience = exp_rep_bar
		else
			exp_rep_bar.bg:SetVertexColor(0, 1, 0.4, 0.2)
			exp_rep_bar.colorStanding = cfg.exp_rep.colour_standing
			self:Tag(exp_rep_bar.text, '[reputation] [currep] / [maxrep] ([perrep]%)')
			self.Reputation = exp_rep_bar
		end

		local altp = createStatusbar(self, cfg.texture, nil, self.Power:GetHeight(), self:GetWidth(), 1, 1, 1, 1)
		altp:SetPoint("BOTTOM", exp_rep_bar, "TOP", 0, 5)
		altp.bd = framebd(altp, altp)
		altp.bg = altp:CreateTexture(nil, 'BORDER')
		altp.bg:SetAllPoints(altp)
		altp.bg:SetTexture(cfg.texture)
		altp.bg:SetVertexColor(1, 1, 1, 0.3)
		altp.Text = fs(altp, 'OVERLAY', cfg.aura.font, cfg.aura.fontsize, cfg.aura.fontflag, 1, 1, 1)
		altp.Text:SetPoint("BOTTOM", 0, 5)
		self:Tag(altp.Text, '[altpower]')
		altp:EnableMouse(true)
		altp.colorTexture = true
		self.AltPowerBar = altp
	end,

	target = function(self, ...)
		self.unit = 'target'
		self.unitSize = 'primary'

		Shared(self, ...)

		Power(self)
		Castbar(self)
		PhaseIcon(self)

		if cfg.aura.target.enable then Auras(self) end

		local name = fs(self.Health, 'OVERLAY', cfg.font, cfg.fontsize, cfg.fontflag, 1, 1, 1)
		name:SetPoint('TOPLEFT', 2, 4)
		self:Tag(name, '[lvl][color][long:name]')

		local htext = fs(self.Health, 'OVERLAY', cfg.font, cfg.fontsize, cfg.fontflag, 1, 1, 1)
		htext:SetPoint('TOPRIGHT', -2, 4)
		htext.frequentUpdates = .1
		self:Tag(htext, '[primary:health]')
	end,

	focus = function(self, ...)
		self.unit = 'focus'
		self.unitSize = 'primary'

		Shared(self, ...)

		Power(self)
		Castbar(self)
		PhaseIcon(self)

		if cfg.aura.focus.enable then Auras(self) end

		local name = fs(self.Health, 'OVERLAY', cfg.font, cfg.fontsize, cfg.fontflag, 1, 1, 1)
		name:SetPoint('LEFT', 2, 4)
		name:SetJustifyH'LEFT'
		self:Tag(name, '[lvl][color][long:name]')
		self.Name = name

		local htext = fs(self.Health, 'OVERLAY', cfg.font, cfg.fontsize, cfg.fontflag, 1, 1, 1)
		htext:SetPoint('RIGHT', -2, 4)
		self:Tag(htext, '[primary:health]')
	end,

	boss = function(self, ...)
		self.unit = 'boss'
		self.unitSize = 'secondary'

		Shared(self, ...)

		Power(self)
		Castbar(self)
		PhaseIcon(self)

		local name = fs(self.Health, 'OVERLAY', cfg.font, cfg.fontsize, cfg.fontflag, 1, 1, 1)
		name:SetPoint('TOPLEFT', 2, 4)
		name:SetJustifyH'LEFT'
		self:Tag(name, '[color][long:name]')

		local htext = fs(self.Health, 'OVERLAY', cfg.font, cfg.fontsize, cfg.fontflag, 1, 1, 1)
		htext:SetPoint('TOPRIGHT', -2, 4)
		self:Tag(htext, '[percent:health]')

		if cfg.AltPowerBar.boss.enable then
		   local altp = createStatusbar(self, cfg.texture, nil, cfg.AltPowerBar.boss.height, cfg.AltPowerBar.boss.width, 1, 1, 1, 1)
		   altp:SetPoint(unpack(cfg.AltPowerBar.boss.pos))
		   altp.bd = framebd(altp, altp)
		   altp.bg = altp:CreateTexture(nil, 'BORDER')
		   altp.bg:SetAllPoints(altp)
		   altp.bg:SetTexture(cfg.texture)
		   altp.bg:SetVertexColor(1, 1, 1, 0.3)
		   altp.Text = fs(altp, 'OVERLAY', cfg.aura.font, cfg.aura.fontsize, cfg.aura.fontflag, 1, 1, 1)
		   altp.Text:SetPoint('CENTER')
		   self:Tag(altp.Text, '[altpower]')
		   altp:EnableMouse(true)
		   altp.colorTexture = true
		   self.AltPowerBar = altp
		end
	end,

	pet = function(self, ...)
		self.unitSize = 'tertiary'

		Shared(self, ...)

		PhaseIcon(self)

		local name = fs(self.Health, 'OVERLAY', cfg.font, cfg.fontsize, cfg.fontflag, 1, 1, 1)
		name:SetPoint('CENTER', self.Health, 0, 3)
		self:Tag(name, '[color][long:name]')
		self.Name = name;
		self.Name:Hide();

		self:SetScript('OnEnter', function(self)UIFrameFadeIn(self.Name, 0.3, 0, 1)end)
		self:SetScript('OnLeave', function(self)UIFrameFadeOut(self.Name, 0.3, 1, 0)end)
	end,

	partytarget = function(self, ...)
		self.unitSize = 'tertiary'

		Shared(self, ...)

		local name = fs(self.Health, 'OVERLAY', cfg.font, cfg.fontsize, cfg.fontflag, 1, 1, 1)
		name:SetPoint('CENTER', self.Health)
		self:Tag(name, '[color][long:name]')
	end,

	targettarget = function(self, ...)
		self.unitSize = 'tertiary'

		Shared(self, ...)
		
		local name = fs(self.Health, 'OVERLAY', cfg.font, cfg.fontsize, cfg.fontflag, 1, 1, 1)
		name:SetPoint('CENTER', 0, 3)
		self:Tag(name, '[color][short:name]')
	end,

	party = function(self, ...)
		self.unit = 'party'
		self.unitSize = 'secondary'

		Shared(self, ...)

		Power(self)
		Castbar(self)
		PhaseIcon(self)
		LFD(self)

		if cfg.aura.party.enable then Auras(self) end
		local name = fs(self.Health, 'OVERLAY', cfg.font, cfg.fontsize, cfg.fontflag, 1, 1, 1)
		name:SetPoint('LEFT', 2, 4)
		name:SetJustifyH'LEFT'
		self:Tag(name, '[lvl][color][threat][limit:name]')
		self.Name = name

		local htext = fs(self.Health, 'OVERLAY', cfg.font, cfg.fontsize, cfg.fontflag, 1, 1, 1)
		htext:SetPoint('RIGHT', -2, 4)
		self:Tag(htext, '[percent:health]')

		local rc = self.Health:CreateTexture(nil, 'OVERLAY')
		rc:SetPoint('CENTER')
		rc:SetSize(12, 12)
		self.ReadyCheck = rc
	end,

	tank = function(self, ...)
		self.unit = 'tank'
		self.unitSize = 'secondary'

		Shared(self, ...)

		Power(self)
		PhaseIcon(self)
		LFD(self)

		if cfg.aura.tank.enable then Auras(self) end

		local name = fs(self.Health, 'OVERLAY', cfg.font, cfg.fontsize, cfg.fontflag, 1, 1, 1)
		name:SetPoint('LEFT', 2, 4)
		name:SetJustifyH'LEFT'
		self:Tag(name, '[lvl][color][limit:name]')
		self.Name = name

		local htext = fs(self.Health, 'OVERLAY', cfg.font, cfg.fontsize, cfg.fontflag, 1, 1, 1)
		htext:SetPoint('RIGHT', -2, 4)
		self:Tag(htext, '[primary:health]')

		local rc = self.Health:CreateTexture(nil, 'OVERLAY')
		rc:SetPoint('CENTER')
		rc:SetSize(12, 12)
		self.ReadyCheck = rc
	end,

	arena = function(self, ...)
		self.unit = 'arena'
		self.unitSize = 'secondary'

		Shared(self, ...)

		Power(self)
		Castbar(self)
		PhaseIcon(self)

		local name = fs(self.Health, 'OVERLAY', cfg.font, cfg.fontsize, cfg.fontflag, 1, 1, 1)
		name:SetPoint('LEFT', 2, 4)
		name:SetJustifyH'LEFT'
		self:Tag(name, '[color][limit:name]')
		self.Name = name

		local htext = fs(self.Health, 'OVERLAY', cfg.font, cfg.fontsize, cfg.fontflag, 1, 1, 1)
		htext:SetPoint('RIGHT', -2, 4)
		self:Tag(htext, '[primary:health]')

		local t = CreateFrame('Frame', nil, self)
		t:SetSize(cfg.uf.secondary.health+cfg.uf.secondary.power+1, cfg.uf.secondary.health+cfg.uf.secondary.power+1)
		t:SetPoint('TOPRIGHT', self, 'TOPLEFT', -4, 0)
		t.framebd = framebd(t, t)
		t.trinketUseAnnounce = true
		t.trinketAnnounce = "SAY"
		self.Trinket = t
	end,

	raid = function(self, ...)
		self.unitSize = 'raid'

		Shared(self, ...)

		LFD(self)

		local name = fs(self.Health, 'OVERLAY', cfg.font, cfg.fontsize, cfg.fontflag, 1, 1, 1)
		name:SetPoint('LEFT', 2, 4)
		name:SetJustifyH'LEFT'
		self:Tag(name, '[color][threat][short:name]')
		self.Name = name

		local rc = self.Health:CreateTexture(nil, 'OVERLAY')
		rc:SetPoint('CENTER')
		rc:SetSize(12, 12)
		self.ReadyCheck = rc
	end,
}

UnitSpecific.focustarget = UnitSpecific.targettarget

oUF:RegisterStyle('Skaarj', Shared)

for unit,layout in next, UnitSpecific do
	oUF:RegisterStyle('Skaarj - ' .. unit:gsub('^%l', string.upper), layout)
end

local spawnHelper = function(self, unit, pos)
	if(UnitSpecific[unit]) then
		self:SetActiveStyle('Skaarj - ' .. unit:gsub('^%l', string.upper))
	elseif(UnitSpecific[unit:match('[^%d]+')]) then
		self:SetActiveStyle('Skaarj - ' .. unit:match('[^%d]+'):gsub('^%l', string.upper))
	else
		self:SetActiveStyle'Skaarj'
	end
	local object = self:Spawn(unit)
	object:SetPoint(unpack(pos))
	return object
end

oUF:Factory(function(self)
	spawnHelper(self, 'player', cfg.unit_positions.Player)
	spawnHelper(self, 'target', cfg.unit_positions.Target)
	spawnHelper(self, 'targettarget', cfg.unit_positions.Targettarget)
	spawnHelper(self, 'focus', cfg.unit_positions.Focus)
	spawnHelper(self, 'focustarget', cfg.unit_positions.Focustarget)
	spawnHelper(self, 'pet', cfg.unit_positions.Pet)

	if cfg.uf.boss then
		spawnHelper(self, 'boss1', cfg.unit_positions.Boss)
		for i = 2, MAX_BOSS_FRAMES do
			local pos = { 'BOTTOMLEFT', 'oUF_SkaarjBoss'..i-1, 'TOPLEFT', 0, 20 }
			spawnHelper(self, 'boss' .. i, pos)
		end
	end

	if cfg.uf.arena then
		spawnHelper(self, 'arena1', cfg.unit_positions.Arena)
		for i = 2, 5 do
			local pos = { 'BOTTOMLEFT', 'oUF_SkaarjArena'..i-1, 'TOPLEFT', 0, 40 }
			spawnHelper(self, 'arena' .. i, pos)
		end

		local arenaprep = {}
		for i = 1, 5 do
			arenaprep[i] = CreateFrame('Frame', 'oUF_ArenaPrep'..i, UIParent)
			arenaprep[i]:SetAllPoints(_G['oUF_Arena'..i])
			arenaprep[i]:SetFrameStrata('BACKGROUND')
			arenaprep[i].framebd = framebd(arenaprep[i], arenaprep[i])

			arenaprep[i].Health = CreateFrame('StatusBar', nil, arenaprep[i])
			arenaprep[i].Health:SetStatusBarTexture(cfg.texture)

			arenaprep[i].Spec = fs(arenaprep[i].Health, 'OVERLAY', cfg.font, cfg.fontsize, cfg.fontflag, 1, 1, 1)
			arenaprep[i].Spec:SetPoint('CENTER')
			arenaprep[i].Spec:SetJustifyH'CENTER'

			arenaprep[i]:Hide()
		end

		local arenaprepupdate = CreateFrame('Frame')
		arenaprepupdate:RegisterEvent('PLAYER_LOGIN')
		arenaprepupdate:RegisterEvent('PLAYER_ENTERING_WORLD')
		arenaprepupdate:RegisterEvent('ARENA_OPPONENT_UPDATE')
		arenaprepupdate:RegisterEvent('ARENA_PREP_OPPONENT_SPECIALIZATIONS')
		arenaprepupdate:SetScript('OnEvent', function(self, event)
			if event == 'PLAYER_LOGIN' then
				for i = 1, 5 do
					arenaprep[i]:SetAllPoints(_G['oUF_Arena'..i])
				end
			elseif event == 'ARENA_OPPONENT_UPDATE' then
				for i = 1, 5 do
					arenaprep[i]:Hide()
				end
			else
				local numOpps = GetNumArenaOpponentSpecs()

				if numOpps > 0 then
					for i = 1, 5 do
						local f = arenaprep[i]

						if i <= numOpps then
							local s = GetArenaOpponentSpec(i)
							local _, spec, class = nil, 'UNKNOWN', 'UNKNOWN'

							if s and s > 0 then
								_, spec, _, _, _, _, class = GetSpecializationInfoByID(s)
							end

							if class and spec then
								local color = RAID_CLASS_COLORS[class]
								f.Health:SetStatusBarColor(color.r, color.g, color.b)
								f.Spec:SetText(spec..'  -  '..LOCALIZED_CLASS_NAMES_MALE[class])
								f:Show()
							end
						else
							f:Hide()
						end
					end
				else
					for i = 1, 5 do
						arenaprep[i]:Hide()
					end
				end
			end
		end)
	end

	if cfg.uf.party then
		for i = 1, MAX_PARTY_MEMBERS do
			local pet = 'PartyMemberFrame'..i..'PetFrame'
			_G[pet]:SetParent(Hider)
			_G[pet..'HealthBar']:UnregisterAllEvents()
		end
		self:SetActiveStyle'Skaarj - Party'
		local party = self:SpawnHeader('oUF_Party', nil, 'custom [group:party,nogroup:raid] show; hide',
		'showPlayer', false,
		'showSolo', false,
		'showParty', true,
		'yOffset', -23,
		'oUF-initialConfigFunction',
			([[
				self:SetHeight(%d)
				self:SetWidth(%d)
			]]):format(cfg.uf.secondary.health+cfg.uf.secondary.power+1,cfg.uf.secondary.width)
		)
		party:SetPoint(unpack(cfg.unit_positions.Party))
	end

	if cfg.uf.tank then
		self:SetActiveStyle'Skaarj - Tank'
		local maintank = self:SpawnHeader('oUF_MainTank', nil, 'raid',
		'showRaid', true,
		'showSolo', false,
		'groupFilter', 'MAINTANK',
		'yOffset', -23,
		'oUF-initialConfigFunction',
			([[
				self:SetHeight(%d)
				self:SetWidth(%d)
			]]):format(cfg.uf.secondary.health+cfg.uf.secondary.power+1,cfg.uf.secondary.width)
		)
		maintank:SetPoint(unpack(cfg.unit_positions.Tank))
	end

	if IsAddOnLoaded('Blizzard_CompactRaidFrames') then
		CompactRaidFrameManager:SetParent(Hider)
		CompactUnitFrameProfiles:UnregisterAllEvents()
	end

	if cfg.uf.raid then
		self:SetActiveStyle'Skaarj - Raid'
		local raid = oUF:SpawnHeader(nil, nil, 'raid', 
		'showPlayer', true,
		'showSolo', false,
		'showParty', false,
		'showRaid', true,
		'xoffset', 8,
		'yOffset', -8,
		'point', 'TOP',
		'groupFilter', '1,2,3,4,5,6,7,8',
		'groupingOrder', '1,2,3,4,5,6,7,8',
		'groupBy', 'GROUP',
		'maxColumns', 8,
		'unitsPerColumn', 5,
		'columnSpacing', 8,
		'columnAnchorPoint', 'LEFT',
		'oUF-initialConfigFunction', ([[
			self:SetHeight(%d)
			self:SetWidth(%d)
		]]):format(cfg.uf.raid.health, cfg.uf.raid.width)
		)
		raid:SetPoint(unpack(cfg.unit_positions.Raid))
	end
end)

