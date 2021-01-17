local mod	= DBM:NewMod("Mimiron", "DBM-Ulduar")
local L		= mod:GetLocalizedStrings()

mod:SetRevision(("$Revision: 17100 $"):sub(12, -3))
mod:SetCreatureID(33432)
mod:SetUsedIcons(1, 2, 3, 4, 5, 6, 7, 8)
mod:SetMinSyncRevision(17100)

mod:RegisterCombat("yell", L.YellPull)
mod:RegisterCombat("yell", L.YellHardPull)
mod:RegisterKill("yell", L.YellKilled)

mod:RegisterEvents(
	"SPELL_DAMAGE",
	"SPELL_CAST_START",
	"SPELL_CAST_SUCCESS",
	"SPELL_AURA_APPLIED",
	"CHAT_MSG_MONSTER_YELL",
	"SPELL_AURA_REMOVED",
	"UNIT_SPELLCAST_CHANNEL_STOP",
	"CHAT_MSG_LOOT",
	"SPELL_SUMMON"
)

local isFlamesTimerStarted = false

local blastWarn					= mod:NewTargetAnnounce(64529, 4)
local shellWarn					= mod:NewTargetAnnounce(63666, 2)
local lootannounce				= mod:NewAnnounce("MagneticCore", 1)
local warnBombSpawn				= mod:NewAnnounce("WarnBombSpawn", 3)
local warnFrostBomb				= mod:NewSpellAnnounce(64623, 3)

local warnFlamesSoon			= mod:NewSoonAnnounce(64566, 1) 
local warnFlamesIn5Sec			= mod:NewSpecialWarning("WarningFlamesIn5Sec", 3)

local warnShockBlast			= mod:NewSpecialWarning("WarningShockBlast", nil, false)
mod:AddBoolOption("ShockBlastWarningInP1", mod:IsMelee(), "announce")
mod:AddBoolOption("ShockBlastWarningInP4", mod:IsMelee(), "announce")
local warnLaserBarrage				= mod:NewSpecialWarningSpell(63293)

local enrage 					= mod:NewBerserkTimer(900)
local timerHardmode				= mod:NewTimer(483, "TimerHardmode", 64582)
local timerP1toP2				= mod:NewTimer(48, "TimeToPhase2") 
local timerP2toP3				= mod:NewTimer(23, "TimeToPhase3")
local timerP3toP4				= mod:NewTimer(24.5, "TimeToPhase4")

local timerProximityMines		= mod:NewCDTimer(30, 63027)
local timerShockBlast			= mod:NewCastTimer(63631)
local timerSpinUp				= mod:NewCastTimer(4, 63414)
local timerLaserBarrageCast		= mod:NewCastTimer(10, 63274) --Laser Barrage
local timerLaserBarrageCD		= mod:NewCDTimer(63, 63274) -- seems LaserBarrage is coming in every 63 sec on PTR
local timerShockblastCD			= mod:NewCDTimer(35, 63631)
local timerPlasmaBlastCD		= mod:NewCDTimer(30, 64529)
local timerShell				= mod:NewBuffActiveTimer(6, 63666)
local timerFlameSuppressant		= mod:NewCastTimer(40, 64570)
local timerFlameSuppressantCD	= mod:NewCDTimer(10, 65192)
local timerNextFlames			= mod:NewNextTimer(27.6, 64566)
local timerNextFrostBomb        = mod:NewNextTimer(45, 64623)
local timerBombExplosion		= mod:NewCastTimer(15, 65333)
local timerBombBotSpawn			= mod:NewCDTimer(15, 63811)

mod:AddBoolOption("PlaySoundOnShockBlast", isMelee)
mod:AddBoolOption("PlaySoundOnLaserBarrage", true)
mod:AddBoolOption("HealthFramePhase4", true)
mod:AddBoolOption("AutoChangeLootToFFA", true)
mod:AddBoolOption("SetIconOnNapalm", true)
mod:AddBoolOption("SetIconOnPlasmaBlast", true)
mod:AddBoolOption("RangeFrame")
mod:AddBoolOption("WarnFlamesIn5Sec", true)
mod:AddBoolOption("SoundWarnCountingFlames", true)

local hardmode = false
local lootmethod, masterlooterRaidID

local spinningUp				= GetSpellInfo(63414)
local lastSpinUp				= 0
local is_spinningUp				= false
local napalmShellTargets = {}
local napalmShellIcon 	= 7

local function warnNapalmShellTargets()
	shellWarn:Show(table.concat(napalmShellTargets, "<, >"))
	table.wipe(napalmShellTargets)
	napalmShellIcon = 7
end

function mod:OnCombatStart(delay)
    self.vb.phase = 0
    isFlamesTimerStarted = false
    hardmode = false
	is_spinningUp = false
	napalmShellIcon = 7
	table.wipe(napalmShellTargets)
	enrage:Start(-delay)
	self:NextPhase()
	timerPlasmaBlastCD:Start(20-delay) 
	if DBM:GetRaidRank() == 2 then
		lootmethod, _, masterlooterRaidID = GetLootMethod()
	end
	if self.Options.RangeFrame then
		DBM.RangeCheck:Show(6)
	end
end

function mod:OnCombatEnd()
	DBM.BossHealth:Hide()
	if self.Options.RangeFrame then
		DBM.RangeCheck:Hide()
	end
	if self.Options.AutoChangeLootToFFA and DBM:GetRaidRank() == 2 then
		if masterlooterRaidID then
			SetLootMethod(lootmethod, "raid"..masterlooterRaidID)
		else
			SetLootMethod(lootmethod)
		end
	end
end

function mod:Flames()	-- Flames 
	timerNextFlames:Start()
	isFlamesTimerStarted = true
	self:ScheduleMethod(27.6, "Flames")
	warnFlamesSoon:Schedule(17.6)
	if self.Options.WarnFlamesIn5Sec then
		warnFlamesIn5Sec:Schedule(22.6)
	end
	mod:CountdownFinalSeconds(self.Options.SoundWarnCountingFlames, 27.6)
end

function mod:SPELL_DAMAGE(args)
	if args:IsSpellID(64566) and isFlamesTimerStarted == false then -- Flames
		isFlamesTimerStarted = true
		timerNextFlames:Start(29)
		self:ScheduleMethod(29, "Flames")
		warnFlamesSoon:Schedule(19)
		if self.Options.WarnFlamesIn5Sec then
			warnFlamesIn5Sec:Schedule(24) 
		end
		mod:CountdownFinalSeconds(self.Options.SoundWarnCountingFlames, 29)
	end
end

function mod:BombBot()	-- Bomb Bot
	if self.vb.phase == 3 then
		timerBombBotSpawn:Start()
		self:ScheduleMethod(15, "BombBot")
	end
end

local function show_warning_for_spinup()
	if is_spinningUp then
		warnLaserBarrage:Show()
		if mod.Options.PlaySoundOnLaserBarrage then
			PlaySoundFile("Sound\\Creature\\HoodWolf\\HoodWolfTransformPlayer01.wav")
		end
	end
end

function mod:UNIT_SPELLCAST_CHANNEL_STOP(unit, spell)
	if spell == spinningUp and GetTime() - lastSpinUp < 3.9 then
		is_spinningUp = false
		self:SendSync("SpinUpFail")
	end
end

function mod:CHAT_MSG_LOOT(msg)
	local player, itemID = msg:match(L.LootMsg)
	if player and itemID and tonumber(itemID) == 46029 then
		lootannounce:Show(player)
	end
end

function mod:SPELL_CAST_START(args)
	if args:IsSpellID(63631) then -- Shock Blast
		--SendChatMessage("StartCast Shock Blast", "RAID")
		if self.vb.phase == 1 and self.Options.ShockBlastWarningInP1 or self.vb.phase == 4 and self.Options.ShockBlastWarningInP4 then
			warnShockBlast:Show()
		end
		timerShockBlast:Start()
		if self.Options.PlaySoundOnShockBlast then
			PlaySoundFile("Sound\\Creature\\HoodWolf\\HoodWolfTransformPlayer01.wav")
		end
		-- start next timer, if p1 then 40s else 35s
		if self.vb.phase == 1 then timerShockblastCD:Start(34)
		else timerShockblastCD:Start() end
	elseif args:IsSpellID(64529, 62997) then	-- Plasma Blast
		--SendChatMessage("StartCast Plasma Blast", "RAID")
		timerPlasmaBlastCD:Start()
	elseif args:IsSpellID(64570) then	-- Flame Suppressant (phase 1)
		--SendChatMessage("StartCast Flame Suppressant (phase 1)", "RAID")
		timerFlameSuppressant:Start()
	elseif args:IsSpellID(64623) then	-- Frost Bomb
		--SendChatMessage("StartCast Frost Bomb", "RAID")
		warnFrostBomb:Show()
		timerBombExplosion:Start()
		timerNextFrostBomb:Start()
	end
end

function mod:SPELL_AURA_APPLIED(args)
	if args:IsSpellID(63666, 65026) and args:IsDestTypePlayer() then	-- Napalm Shell
		--SendChatMessage("Applied Napalm Shell", "RAID")
		napalmShellTargets[#napalmShellTargets + 1] = args.destName
		timerShell:Start()
		if self.Options.SetIconOnNapalm then
			self:SetIcon(args.destName, napalmShellIcon, 6)
			napalmShellIcon = napalmShellIcon - 1
		end
		self:Unschedule(warnNapalmShellTargets)
		self:Schedule(0.3, warnNapalmShellTargets)
	elseif args:IsSpellID(64529, 62997) then	-- Plasma Blast
		--SendChatMessage("Applied Plasma Blast", "RAID")
		blastWarn:Show(args.destName)
		if self.Options.SetIconOnPlasmaBlast then
			self:SetIcon(args.destName, 8, 6)
		end
	end
end

function mod:SPELL_CAST_SUCCESS(args)
	if args:IsSpellID(63027) then				-- Proximity Mines
		--SendChatMessage("CastSuccess Proximity Mines", "RAID")
		if self.vb.phase == 4 then timerProximityMines:Start(50)
		else timerProximityMines:Start() end

	elseif args:IsSpellID(63414) then			-- Spinning UP (before Laser Barrage)
		--SendChatMessage("CastSuccess Spinning UP (before Laser Barrage)", "RAID")
		is_spinningUp = true
		timerSpinUp:Start()
		timerLaserBarrageCast:Schedule(4)
		if self.vb.phase == 4 then timerLaserBarrageCD:Start(60) else timerLaserBarrageCD:Start() end 
		DBM:Schedule(0.15, show_warning_for_spinup)	-- wait 0.15 and then announce it, otherwise it will sometimes fail
		lastSpinUp = GetTime()
	
	elseif args:IsSpellID(65192) then	-- Flame Suppressant CD (phase 2)
		--SendChatMessage("CastSuccess Flame Suppressant CD (phase 2)", "RAID")
		timerFlameSuppressantCD:Start()

	elseif args:IsSpellID(64570) then	-- Flame Suppressant Phase 1
		--SendChatMessage("CastSuccess Flame Suppressant Phase 1", "RAID")
		timerFlameSuppressant:Start()
	end
end

function mod:SPELL_AURA_REMOVED(args)
	if args:IsSpellID(63666, 65026) then -- Napalm Shell
		if self.Options.SetIconOnNapalm then
			self:SetIcon(args.destName, 0)
		end
	end
end


function mod:OnSync(event, args)
	if event == "SpinUpFail" then
		is_spinningUp = false
		timerSpinUp:Cancel()
		timerLaserBarrageCast:Cancel()
		timerLaserBarrageCD:Stop()
		warnLaserBarrage:Cancel()
	elseif event == "Phase2" and self.vb.phase == 1 then -- alternate localized-dependent detection
		self:NextPhase()
	elseif event == "Phase3" and self.vb.phase == 2 then
		self:NextPhase()
	elseif event == "Phase4" and self.vb.phase == 3 then
		self:NextPhase()
	end
end

function mod:NextPhase()
	self.vb.phase = self.vb.phase + 1
	if self.vb.phase == 1 then
		--SendChatMessage("NextPhase 1", "RAID")
		if self.Options.HealthFrame then
			DBM.BossHealth:Clear()
			DBM.BossHealth:AddBoss(33432, L.MobPhase1)
		end

	elseif self.vb.phase == 2 then
		--SendChatMessage("NextPhase 2", "RAID")
		timerShockblastCD:Stop()
		timerProximityMines:Stop()
		timerFlameSuppressant:Stop() -- stop p1 suppressant
		timerPlasmaBlastCD:Stop()
		timerP1toP2:Start()
		timerLaserBarrageCD:Start(83)
		if self.Options.HealthFrame then
			DBM.BossHealth:Clear()
			DBM.BossHealth:AddBoss(33651, L.MobPhase2)
		end
		if self.Options.RangeFrame then
			DBM.RangeCheck:Hide()
		end
		if hardmode then
            timerNextFrostBomb:Start(49)
        end

	elseif self.vb.phase == 3 then
		--SendChatMessage("NextPhase 3", "RAID")
		if self.Options.AutoChangeLootToFFA and DBM:GetRaidRank() == 2 then
			SetLootMethod("freeforall")
		end
		timerLaserBarrageCast:Cancel()
		timerLaserBarrageCD:Stop()
		timerNextFrostBomb:Cancel()
		timerFlameSuppressantCD:Cancel()
		timerP2toP3:Start()
		timerBombBotSpawn:Start(33.5)		-- P3 Start 14.7 left, 15-1.6 from orig timer | works until first drop
		self:ScheduleMethod(33.5, "BombBot")
		if self.Options.HealthFrame then
			DBM.BossHealth:Clear()
			DBM.BossHealth:AddBoss(33670, L.MobPhase3)
		end

	elseif self.vb.phase == 4 then
		--SendChatMessage("NextPhase 4", "RAID")
		if self.Options.AutoChangeLootToFFA and DBM:GetRaidRank() == 2 then
			if masterlooterRaidID then
				SetLootMethod(lootmethod, "raid"..masterlooterRaidID)
			else
				SetLootMethod(lootmethod)
			end
		end
		timerBombBotSpawn:Stop()
		self:UnscheduleMethod("BombBot")
		timerP3toP4:Start()
		timerProximityMines:Start(45)
		timerLaserBarrageCD:Start(60)	-- p3p4 28s + 33s (from vod) = 61
		timerShockblastCD:Start(90)		-- p3p4 28 + 60s (from vod) = 88
		if self.Options.HealthFramePhase4 or self.Options.HealthFrame then
			DBM.BossHealth:Show(L.name)
			DBM.BossHealth:AddBoss(33670, L.MobPhase3)
			DBM.BossHealth:AddBoss(33651, L.MobPhase2)
			DBM.BossHealth:AddBoss(33432, L.MobPhase1)
		end
		if hardmode then
            timerNextFrostBomb:Start(25.5)
        end
	end
end

function mod:CHAT_MSG_MONSTER_YELL(msg)
	if (msg == L.YellPhase2 or msg:find(L.YellPhase2)) then -- register Phase 2
		--SendChatMessage("Detect Phase2 Start", "RAID")
		self:SendSync("Phase2")

	elseif (msg == L.YellPhase3 or msg:find(L.YellPhase3) or msg:find(L.YellPhase3_2)) then -- register Phase 3
		--SendChatMessage("Detect Phase3 Start", "RAID")
		self:SendSync("Phase3")

	elseif (msg == L.YellPhase4 or msg:find(L.YellPhase4)) then -- register Phase 4
		--SendChatMessage("Detect Phase4 Start", "RAID")
		self:SendSync("Phase4")
	
	elseif (msg == L.YellHardPull or msg:find(L.YellHardPull)) then -- register HARDMODE
		--SendChatMessage("Detect HardMode pull", "RAID")
		enrage:Stop()
		hardmode = true
		timerHardmode:Start()
		timerShockblastCD:Start(35)
		timerPlasmaBlastCD:Start(27)
		timerProximityMines:Start(17)
		timerFlameSuppressant:Start(72)	-- from vod, if blast first its delayed by ~4-5sec
		timerShockblastCD:Start(45)	-- from vods
		timerNextFlames:Start(6.5)
		isFlamesTimerStarted = true
		self:ScheduleMethod(6.5, "Flames")
		if self.Options.WarnFlamesIn5Sec then
			warnFlamesIn5Sec:Schedule(1.5)
		end
		mod:CountdownFinalSeconds(self.Options.SoundWarnCountingFlames, 6.5)

	elseif (msg == L.YellKilled or msg:find(L.YellKilled)) then -- register kill
		enrage:Stop()
		timerHardmode:Stop()
		timerNextFlames:Stop()
		self:UnscheduleMethod("Flames")
		timerNextFrostBomb:Stop()
		timerLaserBarrageCD:Stop()
		timerProximityMines:Stop()
		warnFlamesSoon:Cancel()
		warnFlamesIn5Sec:Cancel()
	end
end

function mod:SPELL_SUMMON(args)
	if args:IsSpellID(63811, 63767, 63801) then
		--SendChatMessage("Spell Summon bomb bot", "RAID")
		timerBombBotSpawn:Start()
		warnBombSpawn:Show()
	end
end

function mod:SPELL_DAMAGE(args)
	if args:IsSpellID(64566) and isFlamesTimerStarted == false then -- Flames
		isFlamesTimerStarted = true
		timerNextFlames:Start(26.6)
		self:ScheduleMethod(26.6, "Flames")
		warnFlamesSoon:Schedule(16.6)
		if self.Options.WarnFlamesIn5Sec then
			warnFlamesIn5Sec:Schedule(21.6) 
		end
		mod:CountdownFinalSeconds(self.Options.SoundWarnCountingFlames, 26.6)
	end
end