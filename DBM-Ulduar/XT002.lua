local mod	= DBM:NewMod("XT002", "DBM-Ulduar")
local L		= mod:GetLocalizedStrings()

mod:SetRevision(("$Revision: 4154 $"):sub(12, -3))
mod:SetCreatureID(33293)
mod:SetUsedIcons(7, 8)

mod:RegisterCombat("combat")

mod:RegisterEvents(
	"SPELL_CAST_START",
	"SPELL_AURA_APPLIED",
	"SPELL_AURA_REMOVED",
	"SPELL_DAMAGE"
)

local warnLightBomb					= mod:NewTargetAnnounce(65121, 3)
local warnGravityBomb				= mod:NewTargetAnnounce(64234, 3)

local specWarnLightBomb				= mod:NewSpecialWarningYou(65121)
local specWarnGravityBomb			= mod:NewSpecialWarningYou(64234)
local specWarnConsumption			= mod:NewSpecialWarningMove(64206)	--Hard mode void zone dropped by Gravity Bomb
local specWarnTTIn10Sec 			= mod:NewSpecialWarning("WarningTTIn10Sec", 3)
local enrageTimer					= mod:NewBerserkTimer(600)
local lastTantrum					= 0

local timerTympanicTantrumCast		= mod:NewCastTimer(62776)
local timerTympanicTantrum			= mod:NewBuffActiveTimer(8, 62776)
local timerTympanicTantrumCD		= mod:NewCDTimer(57, 62776)
local timerHeart					= mod:NewCastTimer(30, 63849)
local timerLightBomb				= mod:NewTargetTimer(9, 65121)
local timerGravityBomb				= mod:NewTargetTimer(9, 64234)
local timerAchieve					= mod:NewAchievementTimer(205, 2937, "TimerSpeedKill")

mod:AddBoolOption("SetIconOnLightBombTarget", true)
mod:AddBoolOption("SetIconOnGravityBombTarget", true)
mod:AddBoolOption("WarningTympanicTantrumIn10Sec", true)

function mod:OnCombatStart(delay)
	self.vb.phase = 1
	enrageTimer:Start(-delay)
	timerAchieve:Start()
	timerTympanicTantrumCD:Start(30-delay)
end

function mod:SPELL_CAST_START(args)
	if args:IsSpellID(62776) then					-- Tympanic Tantrum (aoe damge + daze)
		timerTympanicTantrumCast:Start()
		timerTympanicTantrumCD:Stop()
	end
end

function mod:SPELL_AURA_APPLIED(args)
	if args:IsSpellID(62775) and args.auraType == "DEBUFF" and GetTime() - lastTantrum > 14 then	-- Tympanic Tantrum
		lastTantrum = GetTime()
		timerTympanicTantrumCD:Start()
		if self.Options.WarningTympanicTantrumIn10Sec then
			specWarnTTIn10Sec:Schedule(49)
		end
		if mod:IsDifficulty("heroic10") then
			timerTympanicTantrum:Start(7)
		else
			timerTympanicTantrum:Start()
		end
	elseif args:IsSpellID(63018, 65121) then 	-- Light Bomb
		if args:IsPlayer() then
			specWarnLightBomb:Show()
		end
		if self.Options.SetIconOnLightBombTarget then
			self:SetIcon(args.destName, 7, 9)
		end
		warnLightBomb:Show(args.destName)
		timerLightBomb:Start(args.destName)
	elseif args:IsSpellID(63024, 64234) then		-- Gravity Bomb
		if args:IsPlayer() then
			specWarnGravityBomb:Show()
		end
		if self.Options.SetIconOnGravityBombTarget then
			self:SetIcon(args.destName, 8, 9)
		end
		warnGravityBomb:Show(args.destName)
		timerGravityBomb:Start(args.destName)
	elseif args:IsSpellID(63849) then
		timerTympanicTantrumCD:Stop()
		timerHeart:Start()
		self.vb.phase = 2	-- Heartphase = p2
	elseif args:IsSpellID(64193, 65737) then			
		timerHeart:Stop()
		self.vb.phase = 1	-- Normalphase = p1
		if self.Options.WarningTympanicTantrumIn10Sec then
			specWarnTTIn10Sec:Schedule(25)
		end
		timerTympanicTantrumCD:Start(35)
	end
end

function mod:SPELL_AURA_REMOVED(args)
	if args:IsSpellID(63018, 65121) then 	-- Light Bomb
		if self.Options.SetIconOnLightBombTarget then
			self:SetIcon(args.destName, 0)
		end
	elseif args:IsSpellID(63024, 64234) then		-- Gravity Bomb
		if self.Options.SetIconOnGravityBombTarget then
			self:SetIcon(args.destName, 0)
		end
	end
end

do 
	local lastConsumption = 0
	function mod:SPELL_DAMAGE(args)
		if args:IsSpellID(64208, 64206) and args:IsPlayer() and time() - lastConsumption > 2 then		-- Hard mode void zone
			specWarnConsumption:Show()
			lastConsumption = time()
		end
	end
end