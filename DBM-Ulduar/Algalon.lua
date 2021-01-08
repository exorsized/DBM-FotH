local mod	= DBM:NewMod("Algalon", "DBM-Ulduar")
local L		= mod:GetLocalizedStrings()

mod:SetRevision(("$Revision: 3804 $"):sub(12, -3))
mod:SetCreatureID(32871)

mod:RegisterCombat("yell", L.YellPull)
mod:RegisterKill("yell", L.YellKill)
mod:SetWipeTime(20)

mod:EnableModel()

mod:RegisterEvents(
	"SPELL_CAST_START",
	"SPELL_CAST_SUCCESS",
	"SPELL_AURA_APPLIED",
	"SPELL_AURA_APPLIED_DOSE",
	"SPELL_DAMAGE",
	"SWING_DAMAGE",
	"RANGE_DAMAGE",
	"SPELL_PERIODIC_DAMAGE",
	"UNIT_DIED",
	"CHAT_MSG_RAID_BOSS_EMOTE",
	"CHAT_MSG_MONSTER_YELL",
	"UNIT_HEALTH"
)

local announceBigBang			= mod:NewSpellAnnounce(64584, 4)
local warnPhase2				= mod:NewPhaseAnnounce(2)
local warnPhase2Soon			= mod:NewAnnounce("WarnPhase2Soon", 2)
local announcePreBigBang		= mod:NewPreWarnAnnounce(64584, 10, 3)
local announceBlackHole			= mod:NewSpellAnnounce(65108, 2)
local announceCosmicSmash		= mod:NewAnnounce("WarningCosmicSmash", 3, 62311)
local announcePhasePunch		= mod:NewAnnounce("WarningPhasePunch", 4, 65108, mod:IsHealer() or mod:IsTank())

local specwarnStarLow			= mod:NewSpecialWarning("warnStarLow", mod:IsHealer() or mod:IsTank())
local specWarnPhasePunch		= mod:NewSpecialWarningStack(64412, nil, 4)
local specWarnBigBang			= mod:NewSpecialWarningSpell(64584)
local specWarnCosmicSmash		= mod:NewSpecialWarningSpell(64598)
local specWarnBlackHole			= mod:NewSpecialWarning("WarningBlackHole")
local specWarnCollapsingHP		= mod:NewSpecialWarning("WarningCollapsingHP")

local timerCombatStart		    = mod:NewTimer(8, "TimerCombatStart", 2457)
local enrageTimer				= mod:NewBerserkTimer(360)
local timerNextBigBang			= mod:NewNextTimer(90.5, 64584)
local timerBigBangCast			= mod:NewCastTimer(8, 64584)
local timerNextCollapsingStar	= mod:NewTimer(60, "NextCollapsingStar")
local timerCDCosmicSmash		= mod:NewNextTimer(25.5, 62311) 
local timerCastCosmicSmash		= mod:NewCastTimer(4.5, 62311)
local timerPhasePunch			= mod:NewBuffActiveTimer(45, 64412)
local timerNextPhasePunch		= mod:NewNextTimer(15.5, 64412)
local timerDisappear			= mod:NewTimer(3600, "AlgalonDisappears")

local warned_preP2 = false
local warned_star = false
local pull_happened = false

local star_healths = {}
local star_max_healths = {}

local stars = {}
local star_guids = {}

local lastDiedStarGUID = 0
local lastDiedStarTime = 0

local star1warned = false
local star2warned = false
local star3warned = false
local star4warned = false

local numOfWarnedStars = 0

local starMaxHealth = 176400
local star_damage_1 = 0
local star_damage_2 = 0
local star_damage_3 = 0
local star_damage_4 = 0

local lastStar1Time = 0
local lastStar2Time = 0
local lastStar3Time = 0
local lastStar4Time = 0

local last1real = 176400
local last2real = 176400
local last3real = 176400
local last4real = 176400

local timersLoaded = false
local showCollapsingHealth = true

local starGUIDbyIteration = {}

local prevStarSpwawnIteration = 0
local lastStarSpawnIteration = 0
local star1SpawnIteration = 0
local star2SpawnIteration = 0
local star3SpawnIteration = 0
local star4SpawnIteration = 0

local lastStarDiedSpawnIteration = 0
local bh_explosion = 1

local pullTime = 0
local starToDieTimes = { 214, 169, 161, 146, 84, 64, 44, 36 }
local starNumToDie = 1
local starToDieTimers = {}
local starToDieWarnings = {}

mod:RemoveOption("HealthFrame")
mod:AddBoolOption("StarHealthFrame", true)
mod:AddBoolOption("WarnStarDieIn5Sec", true)

function mod:OnCombatStart(delay)
	warned_preP2 = false
	warned_star = false
	pull_happened = false
end

function mod:OnCombatEnd()
	warned_preP2 = false
	warned_star = false
	pull_happened = false

	DBM.BossHealth:Hide()
	howCollapsingHealth = false
	
end

do	-- add the additional Rune Power Bar
	local last1 = 0
	local last2 = 0
	local last3 = 0
	local last4 = 0

	for i = 0, GetNumRaidMembers(), 1 do
		local unitId = ((i == 0) and "target") or "raid"..i.."target"
		local guid = UnitGUID(unitId)
		if lastStar1Time > 0 and guid == star_guids["star1"] then
			last1real = math.floor(UnitHealth(unitId)/UnitHealthMax(unitId) * 100)
		elseif lastStar2Time > 0 and guid == star_guids["star2"] then
			last2real = math.floor(UnitHealth(unitId)/UnitHealthMax(unitId) * 100)
		elseif lastStar3Time > 0 and guid == star_guids["star3"] then
			last3real = math.floor(UnitHealth(unitId)/UnitHealthMax(unitId) * 100)
		elseif lastStar4Time > 0 and guid == star_guids["star4"] then
			last4real = math.floor(UnitHealth(unitId)/UnitHealthMax(unitId) * 100)
		end
	end


	local function getHealthPercent1()
		if lastStar1Time == 0 or not showCollapsingHealth then
			return 0
		end

		local currentHealth = starMaxHealth - ((GetTime() - lastStar1Time) * starMaxHealth * 0.01) - star_damage_1

		if currentHealth < 0 then
			lastStar1Time = 0
			return 0
		end

		last1 = math.floor(currentHealth/starMaxHealth * 100)

		if last1real < last1 then
			star_damage_1 = star_damage_1 + (last1 - last1real)
			currentHealth = starMaxHealth - ((GetTime() - lastStar1Time) * starMaxHealth * 0.01) - star_damage_1

			last1 = math.floor(currentHealth/starMaxHealth * 100)
		end

		if last1 < 0 then
			last1 = 0
		end

		if last1 < 12 and not star1warned then
			local playerName = "-"
			if collapsingPlayerCD[numOfWarnedStars+1] ~= nil then
				playerName = collapsingPlayerCD[numOfWarnedStars+1]
			end

			star1warned = true
			numOfWarnedStars = numOfWarnedStars + 1

			specWarnCollapsingHP:Show(numOfWarnedStars, playerName)
		end

		return last1
	end

	local function getHealthPercent2()
		if lastStar2Time == 0 or not showCollapsingHealth then
			return 0
		end

		local currentHealth = starMaxHealth - ((GetTime() - lastStar2Time) * starMaxHealth * 0.01) - star_damage_2

		if currentHealth < 0 then
			lastStar2Time = 0
			return 0
		end

		last2 = math.floor(currentHealth/starMaxHealth * 100)

		if last2real < last2 then
			star_damage_2 = star_damage_2 + (last2 - last2real)
			currentHealth = starMaxHealth - ((GetTime() - lastStar2Time) * starMaxHealth * 0.01) - star_damage_2

			last2 = math.floor(currentHealth/starMaxHealth * 100)
		end

		if last2 < 0 then
			last2 = 0
		end

		if last2 < 12 and not star2warned then
			local playerName = "-"
			if collapsingPlayerCD[numOfWarnedStars+1] ~= nil then
				playerName = collapsingPlayerCD[numOfWarnedStars+1]
			end

			star2warned = true
			numOfWarnedStars = numOfWarnedStars + 1

			specWarnCollapsingHP:Show(numOfWarnedStars, playerName)
		end

		return last2
	end

	local function getHealthPercent3()
		if lastStar3Time == 0 or not showCollapsingHealth then
			return 0
		end

		local currentHealth = starMaxHealth - ((GetTime() - lastStar3Time) * starMaxHealth * 0.01) - star_damage_3

		if currentHealth < 0 then
			lastStar3Time = 0
			return 0
		end

		last3 = math.floor(currentHealth/starMaxHealth * 100)

		if last3real < last3 then
			star_damage_3 = star_damage_3 + (last3 - last3real)
			currentHealth = starMaxHealth - ((GetTime() - lastStar3Time) * starMaxHealth * 0.01) - star_damage_3

			last3 = math.floor(currentHealth/starMaxHealth * 100)
		end

		if last3 < 0 then
			last3 = 0
		end

		if last3 < 12 and not star3warned then
			local playerName = "-"
			if collapsingPlayerCD[numOfWarnedStars+1] ~= nil then
				playerName = collapsingPlayerCD[numOfWarnedStars+1]
			end

			star3warned = true
			numOfWarnedStars = numOfWarnedStars + 1

			specWarnCollapsingHP:Show(numOfWarnedStars, playerName)
		end

		return last3
	end

	local function getHealthPercent4()
		if lastStar4Time == 0 or not showCollapsingHealth then
			return 0
		end

		local currentHealth = starMaxHealth - ((GetTime() - lastStar4Time) * starMaxHealth * 0.01) - star_damage_4

		if currentHealth < 0 then
			lastStar4Time = 0
			return 0
		end

		last4 = math.floor(currentHealth/starMaxHealth * 100)

		if last4real < last4 then
			star_damage_4 = star_damage_4 + (last4 - last4real)
			currentHealth = starMaxHealth - ((GetTime() - lastStar4Time) * starMaxHealth * 0.01) - star_damage_4

			last4 = math.floor(currentHealth/starMaxHealth * 100)
		end

		if last4 < 0 then
			last4 = 0
		end

		if last4 < 12 and not star4warned then
			local playerName = "-"
			if collapsingPlayerCD[numOfWarnedStars+1] ~= nil then
				playerName = collapsingPlayerCD[numOfWarnedStars+1]
			end

			star4warned = true
			numOfWarnedStars = numOfWarnedStars + 1

			specWarnCollapsingHP:Show(numOfWarnedStars, playerName)
		end

		return last4
	end

	function mod:CreateStar1HPFrame()
		DBM.BossHealth:AddBoss(getHealthPercent1, "Collapsing Star")
	end
	function mod:CreateStar2HPFrame()
		DBM.BossHealth:AddBoss(getHealthPercent2, "Collapsing Star")
	end
	function mod:CreateStar3HPFrame()
		DBM.BossHealth:AddBoss(getHealthPercent3, "Collapsing Star")
	end
	function mod:CreateStar4HPFrame()
		DBM.BossHealth:AddBoss(getHealthPercent4, "Collapsing Star")
	end
end

function mod:startTimers()

	pullTime = GetTime()

	 warned_preP2 = false
	 warned_star = false
	 pull_happened = false

	 star_healths = {}
	 star_max_healths = {}

	 stars = {}
	 star_guids = {}

	 lastDiedStarGUID = 0
	 lastDiedStarTime = 0

	 last1real = 176400
	 last2real = 176400
	 last3real = 176400
	 last4real = 176400

	 prevStarSpwawnIteration = 0
	 lastStarSpawnIteration = 0
	 star1SpawnIteration = 0
	 star2SpawnIteration = 0
	 star3SpawnIteration = 0
	 star4SpawnIteration = 0

	 showCollapsingHealth = true

	 lastStarDiedSpawnIteration = 0

	 starGUIDbyIteration = {}

	 starToDieTimes = { 214, 169, 161, 146, 84, 64, 44, 36 }
	 starNumToDie = 1
	 starToDieTimers = {}
	 starToDieWarnings = {}

	 star_damage_1 = 0
	 star_damage_2 = 0
	 star_damage_3 = 0
	 star_damage_4 = 0

	 lastStar1Time = 0
	 lastStar2Time = 0
	 lastStar3Time = 0
	 lastStar4Time = 0

	 star1warned = false
	 star2warned = false
	 star3warned = false
	 star4warned = false

	 numOfWarnedStars = 0

	 star_guids["star1"] = nil
	 star_guids["star2"] = nil
	 star_guids["star3"] = nil
	 star_guids["star4"] = nil

	 timersLoaded = false
	 bh_explosion = 1

	enrageTimer:Start(360)
	timerNextBigBang:Start()
	announcePreBigBang:Schedule(80)
	timerCDCosmicSmash:Start(25)
	timerNextCollapsingStar:Start(15)
	timerNextPhasePunch:Start()

	if self.Options.StarHealthFrame then
		DBM.BossHealth:Show("Algalon")
		DBM.BossHealth:AddBoss(32871, L.name)
	end

	if DBM:GetRaidRank() == 2 then
		for var=1,12 do
   			if collapsingPlayerCD[var] then self:SendSync("CollapsingAssignment"..var, collapsingPlayerCD[var]) end
		end
	end
end

function mod:SPELL_CAST_START(args)
	if args:IsSpellID(64584, 64443) then 	-- Big Bang
		timerBigBangCast:Start()
		announceBigBang:Show()
		timerNextBigBang:Start()
		announcePreBigBang:Schedule(80)
		specWarnBigBang:Show()
	end
end

function mod:SPELL_CAST_SUCCESS(args)
	if args:IsSpellID(65108, 64122) then 	-- Black Hole Explosion -- doesnt work on warmeme, seems fixed?
		announceBlackHole:Show()
		specWarnBlackHole:Show(bh_explosion)
		bh_explosion = bh_explosion + 1
		warned_star = false
	elseif args:IsSpellID(64598, 62301) then	-- Cosmic Smash
		timerCastCosmicSmash:Start()
		timerCDCosmicSmash:Start()
		announceCosmicSmash:Show()
		specWarnCosmicSmash:Show()

		local elapsed_min = 0
		local elapsed_sec = abs(GetTime() - pullTime)

		if elapsed_sec > 300 then
			elapsed_min = 5
			elapsed_sec = elapsed_sec - 300
		elseif elapsed_sec > 240 then
			elapsed_min = 4
			elapsed_sec = elapsed_sec - 240
		elseif elapsed_sec > 180 then
			elapsed_min = 3
			elapsed_sec = elapsed_sec - 180
		elseif elapsed_sec > 120 then
			elapsed_min = 2
			elapsed_sec = elapsed_sec - 120
		elseif elapsed_sec > 60 then
			elapsed_min = 1
			elapsed_sec = elapsed_sec - 60
		end

		--SendChatMessage("Cosmic Smash Cast Start - "..elapsed_min..":"..elapsed_sec, "RAID")
	end
end

function mod:SPELL_DAMAGE(args)
	if args.destName == "Collapsing Star" then
		local prevStarSpawnGUID = false
		if starGUIDbyIteration[prevStarSpwawnIteration] ~= nil then
			prevStarSpawnGUID = abs(tonumber(strsub(args.destGUID,13,18), 16) - tonumber(strsub(starGUIDbyIteration[prevStarSpwawnIteration],13,18), 16)) < 5
		end
		if star_damage_1 == 0 and (((prevStarSpwawnIteration == star1SpawnIteration) and prevStarSpawnGUID) or ((prevStarSpawnGUID == false) and (lastStarSpawnIteration == star1SpawnIteration))) then
			star_guids["star1"] = args.destGUID
		elseif star_damage_2 == 0 and (((prevStarSpwawnIteration == star2SpawnIteration) and prevStarSpawnGUID) or ((prevStarSpawnGUID == false) and (lastStarSpawnIteration == star2SpawnIteration))) then
			star_guids["star2"] = args.destGUID
		elseif star_damage_3 == 0 and (((prevStarSpwawnIteration == star3SpawnIteration) and prevStarSpawnGUID) or ((prevStarSpawnGUID == false) and (lastStarSpawnIteration == star3SpawnIteration))) then
			star_guids["star3"] = args.destGUID
		elseif star_damage_4 == 0 and (((prevStarSpwawnIteration == star4SpawnIteration) and prevStarSpawnGUID) or ((prevStarSpawnGUID == false) and (lastStarSpawnIteration == star4SpawnIteration))) then
			star_guids["star4"] = args.destGUID
		end

		if star_guids["star1"] == args.destGUID then
			star_damage_1 = star_damage_1 + args.amount
		elseif star_guids["star2"] == args.destGUID then
			star_damage_2 = star_damage_2 + args.amount
		elseif star_guids["star3"] == args.destGUID then
			star_damage_3 = star_damage_3 + args.amount
		elseif star_guids["star4"] == args.destGUID then
			star_damage_4 = star_damage_4 + args.amount
		end
	end
end

function mod:SWING_DAMAGE(args)
	if args.destName == "Collapsing Star" then
		local prevStarSpawnGUID = false
		if starGUIDbyIteration[prevStarSpwawnIteration] ~= nil then
			prevStarSpawnGUID = abs(tonumber(strsub(args.destGUID,13,18), 16) - tonumber(strsub(starGUIDbyIteration[prevStarSpwawnIteration],13,18), 16)) < 5
		end
		if star_damage_1 == 0 and (((prevStarSpwawnIteration == star1SpawnIteration) and prevStarSpawnGUID) or ((prevStarSpawnGUID == false) and (lastStarSpawnIteration == star1SpawnIteration))) then
			star_guids["star1"] = args.destGUID
		elseif star_damage_2 == 0 and (((prevStarSpwawnIteration == star2SpawnIteration) and prevStarSpawnGUID) or ((prevStarSpawnGUID == false) and (lastStarSpawnIteration == star2SpawnIteration))) then
			star_guids["star2"] = args.destGUID
		elseif star_damage_3 == 0 and (((prevStarSpwawnIteration == star3SpawnIteration) and prevStarSpawnGUID) or ((prevStarSpawnGUID == false) and (lastStarSpawnIteration == star3SpawnIteration))) then
			star_guids["star3"] = args.destGUID
		elseif star_damage_4 == 0 and (((prevStarSpwawnIteration == star4SpawnIteration) and prevStarSpawnGUID) or ((prevStarSpawnGUID == false) and (lastStarSpawnIteration == star4SpawnIteration))) then
			star_guids["star4"] = args.destGUID
		end

		if star_guids["star1"] == args.destGUID then
			star_damage_1 = star_damage_1 + args.amount
		elseif star_guids["star2"] == args.destGUID then
			star_damage_2 = star_damage_2 + args.amount
		elseif star_guids["star3"] == args.destGUID then
			star_damage_3 = star_damage_3 + args.amount
		elseif star_guids["star4"] == args.destGUID then
			star_damage_4 = star_damage_4 + args.amount
		end
	end
end

function mod:RANGE_DAMAGE(args)
	if args.destName == "Collapsing Star" then
		local prevStarSpawnGUID = false
		if starGUIDbyIteration[prevStarSpwawnIteration] ~= nil then
			prevStarSpawnGUID = abs(tonumber(strsub(args.destGUID,13,18), 16) - tonumber(strsub(starGUIDbyIteration[prevStarSpwawnIteration],13,18), 16)) < 5
		end
		if star_damage_1 == 0 and (((prevStarSpwawnIteration == star1SpawnIteration) and prevStarSpawnGUID) or ((prevStarSpawnGUID == false) and (lastStarSpawnIteration == star1SpawnIteration))) then
			star_guids["star1"] = args.destGUID
		elseif star_damage_2 == 0 and (((prevStarSpwawnIteration == star2SpawnIteration) and prevStarSpawnGUID) or ((prevStarSpawnGUID == false) and (lastStarSpawnIteration == star2SpawnIteration))) then
			star_guids["star2"] = args.destGUID
		elseif star_damage_3 == 0 and (((prevStarSpwawnIteration == star3SpawnIteration) and prevStarSpawnGUID) or ((prevStarSpawnGUID == false) and (lastStarSpawnIteration == star3SpawnIteration))) then
			star_guids["star3"] = args.destGUID
		elseif star_damage_4 == 0 and (((prevStarSpwawnIteration == star4SpawnIteration) and prevStarSpawnGUID) or ((prevStarSpawnGUID == false) and (lastStarSpawnIteration == star4SpawnIteration))) then
			star_guids["star4"] = args.destGUID
		end

		if star_guids["star1"] == args.destGUID then
			star_damage_1 = star_damage_1 + args.amount
		elseif star_guids["star2"] == args.destGUID then
			star_damage_2 = star_damage_2 + args.amount
		elseif star_guids["star3"] == args.destGUID then
			star_damage_3 = star_damage_3 + args.amount
		elseif star_guids["star4"] == args.destGUID then
			star_damage_4 = star_damage_4 + args.amount
		end
	end
end

function mod:SPELL_PERIODIC_DAMAGE(args)
	if args.destName == "Collapsing Star" then
		local prevStarSpawnGUID = false
		if starGUIDbyIteration[prevStarSpwawnIteration] ~= nil then
			prevStarSpawnGUID = abs(tonumber(strsub(args.destGUID,13,18), 16) - tonumber(strsub(starGUIDbyIteration[prevStarSpwawnIteration],13,18), 16)) < 5
		end
		if star_damage_1 == 0 and (((prevStarSpwawnIteration == star1SpawnIteration) and prevStarSpawnGUID) or ((prevStarSpawnGUID == false) and (lastStarSpawnIteration == star1SpawnIteration))) then
			star_guids["star1"] = args.destGUID
		elseif star_damage_2 == 0 and (((prevStarSpwawnIteration == star2SpawnIteration) and prevStarSpawnGUID) or ((prevStarSpawnGUID == false) and (lastStarSpawnIteration == star2SpawnIteration))) then
			star_guids["star2"] = args.destGUID
		elseif star_damage_3 == 0 and (((prevStarSpwawnIteration == star3SpawnIteration) and prevStarSpawnGUID) or ((prevStarSpawnGUID == false) and (lastStarSpawnIteration == star3SpawnIteration))) then
			star_guids["star3"] = args.destGUID
		elseif star_damage_4 == 0 and (((prevStarSpwawnIteration == star4SpawnIteration) and prevStarSpawnGUID) or ((prevStarSpawnGUID == false) and (lastStarSpawnIteration == star4SpawnIteration))) then
			star_guids["star4"] = args.destGUID
		end

		if star_guids["star1"] == args.destGUID then
			star_damage_1 = star_damage_1 + args.amount
		elseif star_guids["star2"] == args.destGUID then
			star_damage_2 = star_damage_2 + args.amount
		elseif star_guids["star3"] == args.destGUID then
			star_damage_3 = star_damage_3 + args.amount
		elseif star_guids["star4"] == args.destGUID then
			star_damage_4 = star_damage_4 + args.amount
		end
	end
end

function mod:SPELL_AURA_APPLIED(args)
	if args:IsSpellID(64412) then
		timerNextPhasePunch:Start()
		local amount = args.amount or 1
		if args:IsPlayer() and amount >= 4 then
			specWarnPhasePunch:Show(args.amount)
		end
		timerPhasePunch:Start(args.destName)
		announcePhasePunch:Show(args.destName, amount)
	end
end
mod.SPELL_AURA_APPLIED_DOSE = mod.SPELL_AURA_APPLIED


function mod:CHAT_MSG_RAID_BOSS_EMOTE(msg)
	if msg == L.Emote_CollapsingStar or msg:find(L.Emote_CollapsingStar) then
		timerNextCollapsingStar:Start()

		if timersLoaded == false then
			self:ScheduleMethod(0.1, "CreateStar1HPFrame")
			self:ScheduleMethod(0.1, "CreateStar2HPFrame")
			self:ScheduleMethod(0.1, "CreateStar3HPFrame")
			self:ScheduleMethod(0.1, "CreateStar4HPFrame")
			timersLoaded = true
		end

		local isNewStarSpawned = false

		if lastStar1Time == 0 or lastStar2Time == 0 or lastStar3Time == 0 or lastStar4Time == 0 then
			prevStarSpwawnIteration = lastStarSpawnIteration
			lastStarSpawnIteration = lastStarSpawnIteration + 1
		end

		if lastStar1Time == 0 then
			--self:ScheduleMethod(0.1, "CreateStar1HPFrame")
			star1SpawnIteration = lastStarSpawnIteration
			lastStar1Time = GetTime() + 1
			star_guids["star1"] = nil
			star_damage_1 = 0
			last1real = 176400
			next_star_to_die = table.remove(starToDieTimes)
			if next_star_to_die then
				starToDieTimers[starNumToDie] = mod:NewTimer(next_star_to_die - abs(GetTime() - pullTime), "Collapsing Star #"..starNumToDie.." Death")
				starToDieWarnings[starNumToDie] = mod:NewSpecialWarning("WarningStarDieIn5Sec")
				local specwarnStarDieIn5Sec	= starToDieWarnings[starNumToDie]
				local starDeathTimer = starToDieTimers[starNumToDie]
				if self.Options.WarnStarDieIn5Sec then
					specwarnStarDieIn5Sec:Schedule((next_star_to_die - abs(GetTime() - pullTime)) - 5 , starNumToDie)
				end
				mod:CountdownFinalSeconds(self.Options.WarnStarDieIn5Sec, next_star_to_die - abs(GetTime() - pullTime))
				starDeathTimer:Start()
			end
			starNumToDie = starNumToDie + 1
			isNewStarSpawned = true
			star1warned = false
		end
		if lastStar2Time == 0 then
			--self:ScheduleMethod(0.1, "CreateStar2HPFrame")
			star2SpawnIteration = lastStarSpawnIteration
			lastStar2Time = GetTime() + 1
			star_guids["star2"] = nil
			star_damage_2 = 0
			last2real = 176400
			next_star_to_die = table.remove(starToDieTimes)
			if next_star_to_die then
				starToDieTimers[starNumToDie] = mod:NewTimer(next_star_to_die - abs(GetTime() - pullTime), "Collapsing Star #"..starNumToDie.." Death")
				starToDieWarnings[starNumToDie] = mod:NewSpecialWarning("WarningStarDieIn5Sec")
				local specwarnStarDieIn5Sec	= starToDieWarnings[starNumToDie]
				local starDeathTimer = starToDieTimers[starNumToDie]
				if self.Options.WarnStarDieIn5Sec then
					specwarnStarDieIn5Sec:Schedule((next_star_to_die - abs(GetTime() - pullTime)) - 5 , starNumToDie)
				end
				mod:CountdownFinalSeconds(self.Options.WarnStarDieIn5Sec, next_star_to_die - abs(GetTime() - pullTime))
				starDeathTimer:Start()
			end
			starNumToDie = starNumToDie + 1
			isNewStarSpawned = true
			star2warned = false
		end
		if lastStar3Time == 0 then
			--self:ScheduleMethod(0.1, "CreateStar3HPFrame")
			star3SpawnIteration = lastStarSpawnIteration
			lastStar3Time = GetTime() + 1
			star_guids["star3"] = nil
			star_damage_3 = 0
			last3real = 176400
			next_star_to_die = table.remove(starToDieTimes)
			if next_star_to_die then
				starToDieTimers[starNumToDie] = mod:NewTimer(next_star_to_die - abs(GetTime() - pullTime), "Collapsing Star #"..starNumToDie.." Death")
				starToDieWarnings[starNumToDie] = mod:NewSpecialWarning("WarningStarDieIn5Sec")
				local specwarnStarDieIn5Sec	= starToDieWarnings[starNumToDie]
				local starDeathTimer = starToDieTimers[starNumToDie]
				if self.Options.WarnStarDieIn5Sec then
					specwarnStarDieIn5Sec:Schedule((next_star_to_die - abs(GetTime() - pullTime)) - 5 , starNumToDie)
				end
				mod:CountdownFinalSeconds(self.Options.WarnStarDieIn5Sec, next_star_to_die - abs(GetTime() - pullTime))
				starDeathTimer:Start()
			end
			starNumToDie = starNumToDie + 1
			isNewStarSpawned = true
			star3warned = false
		end
		if lastStar4Time == 0 then
			--self:ScheduleMethod(0.1, "CreateStar4HPFrame")
			star4SpawnIteration = lastStarSpawnIteration
			lastStar4Time = GetTime() + 1
			star_guids["star4"] = nil
			star_damage_4 = 0
			last4real = 176400
			next_star_to_die = table.remove(starToDieTimes)
			if next_star_to_die then
				starToDieTimers[starNumToDie] = mod:NewTimer(next_star_to_die - abs(GetTime() - pullTime), "Collapsing Star #"..starNumToDie.." Death")
				starToDieWarnings[starNumToDie] = mod:NewSpecialWarning("WarningStarDieIn5Sec")
				local specwarnStarDieIn5Sec	= starToDieWarnings[starNumToDie]
				local starDeathTimer = starToDieTimers[starNumToDie]
				if self.Options.WarnStarDieIn5Sec then
					specwarnStarDieIn5Sec:Schedule((next_star_to_die - abs(GetTime() - pullTime)) - 5 , starNumToDie)
				end
				mod:CountdownFinalSeconds(self.Options.WarnStarDieIn5Sec, next_star_to_die - abs(GetTime() - pullTime))
				starDeathTimer:Start()
			end
			starNumToDie = starNumToDie + 1
			isNewStarSpawned = true
			star4warned = false
		end
	end
end

function mod:CHAT_MSG_MONSTER_YELL(msg)
	if msg == L.Phase2 or msg:find(L.Phase2) then
		timerNextCollapsingStar:Cancel()
		warnPhase2:Show()
	elseif (msg == L.YellPull or msg:find(L.YellPull)) then
		warned_preP2 = false
		warned_star = false
		pull_happened = true
		timerCombatStart:Start(25)
		self:UnscheduleMethod("startTimers")	-- reschedule timers if intro rp happens
		self:ScheduleMethod(25, "startTimers")
	elseif (pull_happened == false and (msg == L.YellPullFast or msg:find(L.YellPullFast))) then
		warned_preP2 = false
		warned_star = false
		timerCombatStart:Start()
		self:UnscheduleMethod("startTimers")	-- reschedule timers if intro rp happens
		self:ScheduleMethod(8, "startTimers")
	elseif (pull_happened == true and (msg == L.YellPullFast or msg:find(L.YellPullFast))) then
		pull_happened = false
		timerDisappear:Start()
	end

end

function mod:UNIT_HEALTH(uId)
	if not warned_preP2 and self:GetUnitCreatureId(uId) == 32871 and UnitHealth(uId) / UnitHealthMax(uId) <= 0.23 then
		warned_preP2 = true
		warnPhase2Soon:Show()
	elseif not warned_star and self:GetUnitCreatureId(uId) == 32955 and UnitHealth(uId) / UnitHealthMax(uId) <= 0.25 then
		warned_star = true
		specwarnStarLow:Show()
	end
	if showCollapsingHealth and self:GetUnitCreatureId(uId) == 32871 and UnitHealth(uId) / UnitHealthMax(uId) <= 0.20 then
		showCollapsingHealth = false
	end
end

function mod:UNIT_DIED(args)

	if args.destName == "Collapsing Star" then
		if star_damage_1 == 0 and star1SpawnIteration == prevStarSpwawnIteration and lastStar1Time ~= 0 then
			star_guids["star1"] = args.destGUID
		elseif star_damage_2 == 0 and star2SpawnIteration == prevStarSpwawnIteration and lastStar2Time ~= 0 then
			star_guids["star2"] = args.destGUID
		elseif star_damage_3 == 0 and star3SpawnIteration == prevStarSpwawnIteration and lastStar3Time ~= 0 then
			star_guids["star3"] = args.destGUID
		elseif star_damage_4 == 0 and star4SpawnIteration == prevStarSpwawnIteration and lastStar4Time ~= 0 then
			star_guids["star4"] = args.destGUID
		end

		lastDiedStarGUID = tonumber(strsub(args.destGUID,13,18), 16)

		if args.destGUID == star_guids["star1"] then
			if starGUIDbyIteration[star1SpawnIteration] == nil then
				starGUIDbyIteration[star1SpawnIteration] = args.destGUID
			end
			lastDiedStarTime = lastStar1Time
			lastStar1Time = 0
			self:SendSync("Star1DiedGUID", args.destGUID)
			--DBM.BossHealth:RemoveBoss(getHealthPercent1)
		elseif args.destGUID == star_guids["star2"] then
			if starGUIDbyIteration[star2SpawnIteration] == nil then
				starGUIDbyIteration[star2SpawnIteration] = args.destGUID
			end
			lastDiedStarTime = lastStar2Time
			lastStar2Time = 0
			self:SendSync("Star2DiedGUID", args.destGUID)
			--DBM.BossHealth:RemoveBoss(getHealthPercent2)
		elseif args.destGUID == star_guids["star3"] then
			if starGUIDbyIteration[star3SpawnIteration] == nil then
				starGUIDbyIteration[star3SpawnIteration] = args.destGUID
			end
			lastDiedStarTime = lastStar3Time
			lastStar3Time = 0
			self:SendSync("Star3DiedGUID", args.destGUID)
			--DBM.BossHealth:RemoveBoss(getHealthPercent3)
		elseif args.destGUID == star_guids["star4"] then
			if starGUIDbyIteration[star4SpawnIteration] == nil then
				starGUIDbyIteration[star4SpawnIteration] = args.destGUID
			end
			lastDiedStarTime = lastStar4Time
			lastStar4Time = 0
			self:SendSync("Star4DiedGUID", args.destGUID)
			--DBM.BossHealth:RemoveBoss(getHealthPercent4)
		end

		self:SendSync("LastStarDiedTime", lastDiedStarTime)

	end
end

function mod:OnSync(event, arg)
	if event == "Star1DiedGUID" then
		if starGUIDbyIteration[star1SpawnIteration] == nil then
				starGUIDbyIteration[star1SpawnIteration] = arg
		end
		star_guids["star1"] = arg
		lastDiedStarGUID = tonumber(strsub(arg,13,18), 16)
		lastStar1Time = 0
	elseif event == "Star2DiedGUID" then
		if starGUIDbyIteration[star2SpawnIteration] == nil then
				starGUIDbyIteration[star2SpawnIteration] = arg
		end
		star_guids["star2"] = arg
		lastDiedStarGUID = tonumber(strsub(arg,13,18), 16)
		lastStar2Time = 0
	elseif event == "Star3DiedGUID" then
		if starGUIDbyIteration[star3SpawnIteration] == nil then
				starGUIDbyIteration[star3SpawnIteration] = arg
		end
		star_guids["star3"] = arg
		lastDiedStarGUID = tonumber(strsub(arg,13,18), 16)
		lastStar3Time = 0
	elseif event == "Star4DiedGUID" then
		if starGUIDbyIteration[star4SpawnIteration] == nil then
				starGUIDbyIteration[star4SpawnIteration] = arg
		end
		star_guids["star4"] = arg
		lastDiedStarGUID = tonumber(strsub(arg,13,18), 16)
		lastStar4Time = 0
	elseif event == "LastStarDiedTime" then
		lastDiedStarTime = tonumber(arg)
	else
		for var=1,12 do
   			if event == "CollapsingAssignment"..var then collapsingPlayerCD[var] = arg end
		end
	end
end