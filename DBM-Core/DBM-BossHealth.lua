---------------
--  Globals  --
---------------
DBM.BossHealth = {}


-------------
--  Locals --
-------------
local bossHealth = DBM.BossHealth
local bars = {}
local barCache = {}
local updateFrame
local getBarId
local updateBar
local anchor
local header
local dropdownFrame
--local sortingEnabled

do
	local id = 0
	function getBarId()
		id = id + 1
		return id
	end
end

------------
--  Menu  --
------------
local menu
menu = {
	{
		text = DBM_CORE_RANGECHECK_LOCK,
		checked = false, -- requires DBM.Options which is not available yet
		func = function()
			menu[1].checked = not menu[1].checked
			DBM.Options.HealthFrameLocked = menu[1].checked
		end
	},
	{
		text = DBM_CORE_BOSSHEALTH_HIDE_FRAME,
		notCheckable = true,
		func = function() bossHealth:Hide() end
	}
}


-----------------------
--  Script Handlers  --
-----------------------
local function onMouseDown(self, button)
	if button == "LeftButton" and not DBM.Options.HealthFrameLocked then
		anchor.moving = true
		anchor:StartMoving()
	end
end

local function onMouseUp(self, button)
	anchor.moving = nil
	anchor:StopMovingOrSizing()
	local point, _, _, x, y = anchor:GetPoint(1)
	DBM.Options.HPFramePoint = point
	DBM.Options.HPFrameX = x
	DBM.Options.HPFrameY = y
	if button == "RightButton" then
		EasyMenu(menu, dropdownFrame, "cursor", nil, nil, "MENU")
	end
end

local onHide = onMouseUp


-----------------
-- Apply Style --
-----------------
local function updateBarStyle(bar, id)
	bar:ClearAllPoints()
	if DBM.Options.HealthFrameGrowUp then
		bar:SetPoint("BOTTOM", bars[id - 1] or anchor, "TOP", 0, 0)
	else
		bar:SetPoint("TOP", bars[id - 1] or anchor, "BOTTOM", 0, 0)
	end
	local barborder = _G[bar:GetName().."BarBorder"]
	local barbar = _G[bar:GetName().."Bar"]
	local width = DBM.Options.HealthFrameWidth
	local bgtable
	if width < 175 then -- these health frames really suck :(
		barbar:ClearAllPoints()
		barbar:SetPoint("CENTER", barbar:GetParent(), "CENTER", -6, 0)
		bar:SetWidth(DBM.Options.HealthFrameWidth)
		barborder:SetWidth(DBM.Options.HealthFrameWidth * 0.99)
		barbar:SetWidth(DBM.Options.HealthFrameWidth * 0.95)
		barbar:SetStatusBarTexture(DBM.Options.HealthFrameBarTexture)
		
		if DBM.Options.HealthFrameBarBorder == DBM.DefaultOptions.HealthFrameBarBorder then
			barborder:SetHeight(DBM.DefaultOptions.HealthFrameHeight)
			barborder:SetNormalTexture(DBM.DefaultOptions.HealthFrameBarBorder)
			bgtable=barborder:GetBackdrop()
			bgtable.edgeFile = nil
			barborder:SetBackdrop(bgtable)
		else
			barborder:SetHeight(18)
			barborder:SetNormalTexture(nil)
			bgtable=barborder:GetBackdrop()
			bgtable.edgeFile = DBM.Options.HealthFrameBarBorder
			barborder:SetBackdrop(bgtable)
		end
		
	elseif width >= 225 then
		barbar:ClearAllPoints()
		barbar:SetPoint("CENTER", barbar:GetParent(), "CENTER", 5, 0)
		bar:SetWidth(DBM.Options.HealthFrameWidth)
		barborder:SetWidth(DBM.Options.HealthFrameWidth * 0.995)
		barbar:SetWidth(DBM.Options.HealthFrameWidth * 0.965)
		barbar:SetStatusBarTexture(DBM.Options.HealthFrameBarTexture)
		
		if DBM.Options.HealthFrameBarBorder == DBM.DefaultOptions.HealthFrameBarBorder then
			barborder:SetHeight(DBM.DefaultOptions.HealthFrameHeight)
			barborder:SetNormalTexture(DBM.DefaultOptions.HealthFrameBarBorder)
			bgtable=barborder:GetBackdrop()
			bgtable.edgeFile = nil
			barborder:SetBackdrop(bgtable)
		else
			barborder:SetHeight(18)
			barborder:SetNormalTexture(nil)
			bgtable=barborder:GetBackdrop()
			bgtable.edgeFile = DBM.Options.HealthFrameBarBorder
			barborder:SetBackdrop(bgtable)
		end
		
	else
		bar:SetWidth(DBM.Options.HealthFrameWidth)
		barborder:SetWidth(DBM.Options.HealthFrameWidth * 0.99)
		barbar:SetWidth(DBM.Options.HealthFrameWidth * 0.95)
		barbar:SetStatusBarTexture(DBM.Options.HealthFrameBarTexture)
		
		if DBM.Options.HealthFrameBarBorder == DBM.DefaultOptions.HealthFrameBarBorder then
			barborder:SetHeight(DBM.DefaultOptions.HealthFrameHeight)
			barborder:SetNormalTexture(DBM.DefaultOptions.HealthFrameBarBorder)
			bgtable=barborder:GetBackdrop()
			bgtable.edgeFile = nil
			barborder:SetBackdrop(bgtable)
		else
			barborder:SetHeight(18)
			barborder:SetNormalTexture(nil)
			bgtable=barborder:GetBackdrop()
			bgtable.edgeFile = DBM.Options.HealthFrameBarBorder
			barborder:SetBackdrop(bgtable)
		end
	end
end

-----------------------
-- Create the Frame  --
-----------------------
local function createFrame(self)
	anchor = CreateFrame("Frame", nil, UIParent)
	anchor:SetWidth(60)
	anchor:SetHeight(10)
	anchor:SetMovable(1)
	anchor:EnableMouse(1)
	anchor:SetPoint(DBM.Options.HPFramePoint, UIParent, DBM.Options.HPFramePoint, DBM.Options.HPFrameX, DBM.Options.HPFrameY)
	header = anchor:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	header:SetPoint("BOTTOM", anchor, "BOTTOM")
	anchor:SetScript("OnUpdate", updateFrame)
	anchor:SetScript("OnMouseDown", onMouseDown)
	anchor:SetScript("OnMouseUp", onMouseUp)
	anchor:SetScript("OnHide", onHide)
	dropdownFrame = CreateFrame("Frame", "DBMBossHealthDropdown", anchor, "UIDropDownMenuTemplate")
	menu[1].checked = DBM.Options.HealthFrameLocked
end

local function createBar(self, cId, name)
	local bar = table.remove(barCache, #barCache) or CreateFrame("Frame", "DBM_BossHealth_Bar_"..getBarId(), anchor, "DBMBossHealthBarTemplate")
	bar:Show()
	local bartext = _G[bar:GetName().."BarName"]
	local barborder = _G[bar:GetName().."BarBorder"]
	local barbar = _G[bar:GetName().."Bar"]
	barborder:SetScript("OnMouseDown", onMouseDown)
	barborder:SetScript("OnMouseUp", onMouseUp)
	barborder:SetScript("OnHide", onHide)
	bar.id = cId
	bar.hidden = false
	bar:ClearAllPoints()
	bartext:SetText(name)
	updateBar(bar, 100)
	return bar
end



------------------
--  Bar Update  --
------------------
-- from sam_lie
-- Compatible with Lua 5.0 and 5.1.
-- Disclaimer : use at own risk especially for hedge fund reports :-)

---============================================================
-- add comma to separate thousands
-- 
function comma_value(amount)
  local formatted = amount
  while true do  
    formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
    if (k==0) then
      break
    end
  end
  return formatted
end

---============================================================
-- rounds a number to the nearest decimal places
--
function round(val, decimal)
  if (decimal) then
    return math.floor( (val * 10^decimal) + 0.5) / (10^decimal)
  else
    return math.floor(val+0.5)
  end
end

--===================================================================
-- given a numeric value formats output with comma to separate thousands
-- and rounded to given decimal places
--
--
function format_num(amount, decimal, prefix, neg_prefix)
  local str_amount,  formatted, famount, remain

  decimal = decimal or 2  -- default 2 decimal places
  neg_prefix = neg_prefix or "-" -- default negative sign

  famount = math.abs(round(amount,decimal))
  famount = math.floor(famount)

  remain = round(math.abs(amount) - famount, decimal)

        -- comma to separate the thousands
  formatted = comma_value(famount)

        -- attach the decimal portion
  if (decimal > 0) then
    remain = string.sub(tostring(remain),3)
    formatted = formatted .. "." .. remain ..
                string.rep("0", decimal - string.len(remain))
  end

        -- attach prefix string e.g '$' 
  formatted = (prefix or "") .. formatted 

        -- if value is negative then format accordingly
  if (amount<0) then
    if (neg_prefix=="()") then
      formatted = "("..formatted ..")"
    else
      formatted = neg_prefix .. formatted 
    end
  end

  return formatted
end

function updateBar(bar, percent, dontShowDead, realHealth)
	local bartimer = _G[bar:GetName().."BarTimer"]
	local barbar = _G[bar:GetName().."Bar"]
	if realHealth then
	 	bartimer:SetText((percent > 0 or dontShowDead) and format_num(realHealth, 0).." ("..math.floor(percent).."%) " or DBM_CORE_DEAD)
	else
		bartimer:SetText((percent > 0 or dontShowDead) and math.floor(percent).."%" or DBM_CORE_DEAD)
	end
	barbar:SetValue(percent)
	barbar:SetStatusBarColor((100 - percent) / 100, percent/100, 0)
	bar.value = percent
	local bossAlive = false
	for i = 1, #bars do
		if bars[i].value > 0 then
			bossAlive = true
			break
		end
	end
	if not bossAlive and #bars > 0 then
		bossHealth:Hide()
	end
end

do
	local t = 0
	local targetCache = {}
	local function getCIDfromGUID(guid)
		if not guid then
			return -1
		end
		local cType = bit.band(guid:sub(0, 5), 0x00F)
		return (cType == 3 or cType == 5) and tonumber(guid:sub(9, 12), 16) or -1
	end
	
--	local function compareBars(b1, b2)
--		return b1.value > b2.value
--	end
	
	function updateFrame(self, e)
		t = t + e
		if t >= 0.5 then
			t = 0
--			if #bars > DBM.Options.HPFrameMaxEntries then
--				sortingEnabled = true
--			end
--			if sortingEnabled then
--				table.sort(bars, compareBars)
--			end
			for i, v in ipairs(bars) do
--				if i > DBM.Options.HPFrameMaxEntries then
--					v:Hide()
--				else
--					v:Show()
--				end
				if type(v.id) == "number" then
					local id = targetCache[v.id] -- ask the cache if we already know where the mob is
					if getCIDfromGUID(UnitGUID(id or "")) ~= v.id then -- the cache doesn't know it, update the cache
						targetCache[v.id] = nil
						-- check focus target
						if getCIDfromGUID(UnitGUID("focus")) == v.id then
							targetCache[v.id] = "focus"
						else
							-- check target and raid/party targets
							local uId = ((GetNumRaidMembers() == 0) and "party") or "raid"
							for i = 0, math.max(GetNumRaidMembers(), GetNumPartyMembers()) do
								id = (i == 0 and "target") or uId..i.."target"
								if getCIDfromGUID(UnitGUID(id or "")) == v.id then
									targetCache[v.id] = id
									break
								end
							end
						end
					end
					if getCIDfromGUID(UnitGUID(id or "")) == v.id then -- did we find the mob? if yes: update the health bar
						updateBar(v, ((UnitHealth(id)) / (UnitHealthMax(id)) * 100 or 100), false, UnitHealth(id))
					end
				elseif type(v.id) == "function" then -- generic bars
					updateBar(v, v.id(), true)
				end
			end
		end
	end
end

-----------------------
--  General Methods  --
-----------------------
function bossHealth:Show(name)
	if not anchor then createFrame(bossHealth) end
	header:SetText(name)
	anchor:Show()
	bossHealth:Clear()
end

function bossHealth:Clear()
	if not anchor or not anchor:IsShown() then return end
	for i = #bars, 1, -1 do
		local bar = bars[i]
		bar:Hide()
		bar:ClearAllPoints()
		barCache[#barCache + 1] = bar
		bars[i] = nil
	end
--	sortingEnabled = false
end

function bossHealth:Hide()
	if anchor then anchor:Hide() end
end

function bossHealth:AddBoss(cId, name)
	if not anchor or not anchor:IsShown() then return end
	table.insert(bars, createBar(self, cId, name))
	updateBarStyle(bars[#bars], #bars)
end

function bossHealth:RemoveBoss(cId)
	if not anchor or not anchor:IsShown() then return end
	for i = #bars, 1, -1 do
		local bar = bars[i]
		if bar.id == cId then
			if bars[i + 1] then
				local next = bars[i + 1]
				next:SetPoint("TOP", bars[i - 1] or anchor, "BOTTOM", 0, 0)
			end
			bar:Hide()
			bar:ClearAllPoints()
			barCache[#barCache + 1] = bar
			table.remove(bars, i)
		end
	end
end

function bossHealth:UpdateSettings()
	if not anchor then createFrame(bossHealth) end
	anchor:SetPoint(DBM.Options.HPFramePoint, UIParent, DBM.Options.HPFramePoint, DBM.Options.HPFrameX, DBM.Options.HPFrameY)
	for i, v in ipairs(bars) do
		updateBarStyle(v, i)
	end
end


