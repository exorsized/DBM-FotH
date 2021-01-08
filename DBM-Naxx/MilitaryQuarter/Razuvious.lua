local mod	= DBM:NewMod("Razuvious", "DBM-Naxx", 4)
local L		= mod:GetLocalizedStrings()

mod:SetRevision(("$Revision: 4905 $"):sub(12, -3))
mod:SetCreatureID(16061)

mod:RegisterCombat("yell", L.Yell1, L.Yell2, L.Yell3, L.Yell4)

mod:RegisterEvents(
	"SPELL_CAST_SUCCESS",
	"SPELL_AURA_APPLIED",
	"SPELL_AURA_REMOVED"
)

local warnShoutNow		= mod:NewSpellAnnounce(55543, 1)
local warnShoutSoon		= mod:NewSoonAnnounce(55543, 3)
local warnShieldWall	= mod:NewAnnounce("WarningShieldWallSoon", 3, 29061)

mod:AddBoolOption("AnnounceMindControlMoves", false, "announce")

local timerShout		= mod:NewNextTimer(16, 55543)
local tauntTimers		= {}
local shieldWallTimers	= {}
local mindControlTimers	= {}

local mcOwners = {}

function getMindControlID(unitId)
end

function mod:OnCombatStart(delay)
	timerShout:Start(16 - delay)
	warnShoutSoon:Schedule(11 - delay)
end

function mod:SPELL_CAST_SUCCESS(args)
	if args:IsSpellID(55543, 29107) then  -- Disrupting Shout
		timerShout:Start()
		warnShoutNow:Show()
		warnShoutSoon:Schedule(11)
	elseif args:IsSpellID(29060) then -- Taunt
		if self.Options.AnnounceMindControlMoves and mod:IsDifficulty("heroic25") then
			SendChatMessage(mcOwners[args.sourceGUID].." casts TAUNT on "..args.destName, "RAID")
		end
		local timerTaunt = mod:NewCDTimer(20, 29060, "Taunt CD")
		if mod:IsDifficulty("heroic25") then
			timerTaunt = tauntTimers[args.sourceGUID]
		end
		timerTaunt:Start()
	elseif args:IsSpellID(29061) then -- ShieldWall
		if self.Options.AnnounceMindControlMoves and mod:IsDifficulty("heroic25") then
			SendChatMessage(mcOwners[args.sourceGUID].." casts Bone Barrier", "RAID")
		end
		local timerShieldWall = mod:NewCDTimer(20, 29061, "ShieldWall CD")
		if mod:IsDifficulty("heroic25") then
			timerShieldWall = shieldWallTimers[args.sourceGUID]
		end
		timerShieldWall:Start()
		warnShieldWall:Schedule(15)
	end
end

function mod:SPELL_AURA_APPLIED(args)
	if args:IsSpellID(605) and args.destName == "Death Knight Understudy" then -- Mind Control
		mcOwners[args.destGUID] = args.originalSourceName
		tauntTimers[args.destGUID] = mod:NewCDTimer(20, 29060, "Taunt CD - "..args.originalSourceName)
		shieldWallTimers[args.destGUID] = mod:NewCDTimer(20, 29061, "ShieldWall CD - "..args.originalSourceName)
		mindControlTimers[args.destGUID] = mod:NewTimer(60, args.originalSourceName.." Mind Control", 605)
		local timerMindControl = mindControlTimers[args.destGUID]
		timerMindControl:Start()
	end
end

function mod:SPELL_AURA_REMOVED(args)
	if args:IsSpellID(605) and args.destName == "Death Knight Understudy" then -- Mind Control
		local timerTaunt = tauntTimers[args.destGUID]
		local timerShieldWall = shieldWallTimers[args.destGUID]
		local timerMindControl = mindControlTimers[args.destGUID]
		timerMindControl:Stop()
		timerTaunt:Stop()
		timerShieldWall:Stop()
	end
end
