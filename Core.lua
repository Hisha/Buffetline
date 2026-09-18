local ADDON, BuffetLine = ...

BuffetLine.PREFIX = ADDON
BuffetLine.VERSION = GetAddOnMetadata(ADDON, "Version") or "1.0.0"

BuffetLine.CONJURED = {
	[1113] = true,
	[1114] = true,
	[1487] = true,
	[2136] = true,
	[2288] = true,
	[3772] = true,
	[5349] = true,
	[5350] = true,
	[8075] = true,
	[8076] = true,
	[8077] = true,
	[8078] = true,
	[8079] = true,
	[22018] = true,
	[22019] = true,
	[22895] = true,
	[30703] = true,
	[34062] = true,
	[43518] = true,
	[43523] = true,
}

BuffetLine.DEFAULTS = {
	locked = false,
	orientation = "horizontal",
	position = nil,
	restock = {
		enabled = false,
		food = 20,
		drink = 20,
	},
}

BuffetLine.SUB_FOOD = "Food"
BuffetLine.SUB_DRINK = "Drink"
BuffetLine.SUB_BOTH = "Food & Drink"

BuffetLine.FOOD_SPELL = nil
BuffetLine.DRINK_SPELL = nil

local function TryLocalize()
	local foodName = GetItemInfo(117)
	local drinkName = GetItemInfo(159)
	if foodName and drinkName then
		local foodSpell = GetItemSpell(foodName)
		local drinkSpell = GetItemSpell(drinkName)
		if foodSpell and drinkSpell and foodSpell ~= drinkSpell then
			BuffetLine.FOOD_SPELL = foodSpell
			BuffetLine.DRINK_SPELL = drinkSpell
			return true
		end
	end
	return false
end

local function IsDrink(item)
	local drinkSpell = BuffetLine.DRINK_SPELL
	if not (BuffetLine.FOOD_SPELL and drinkSpell) then
		return false
	end
	if BuffetLine.FOOD_SPELL == drinkSpell then
		return false
	end
	return GetItemSpell(item) == drinkSpell
end

BuffetLine.buckets = {
	mageFood = {},
	food = {},
	drink = {},
	conjFood = {},
	conjDrink = {},
}

local function ResetBuckets()
	for k in pairs(BuffetLine.buckets) do
		wipe(BuffetLine.buckets[k])
	end
end

local pendingTimers = {}
local timerFrame

local function After(delay, func)
	tinsert(pendingTimers, { time = GetTime() + delay, func = func })
	if not timerFrame then
		timerFrame = CreateFrame("Frame")
		timerFrame:SetScript("OnUpdate", function()
			local now = GetTime()
			for i = #pendingTimers, 1, -1 do
				local timer = pendingTimers[i]
				if now >= timer.time then
					tremove(pendingTimers, i)
					timer.func()
				end
			end
		end)
	end
end

local cache = {}

local function ItemMeta(itemID, link)
	if cache[itemID] then
		return cache[itemID]
	end
	local name, _, _, itemLevel, minLevel, _, subType, stackCount, _, texture = GetItemInfo(link or itemID)
	if not name or not itemLevel or not minLevel or not subType or not texture then
		return nil
	end
	local meta = {
		name = name,
		subType = subType,
		itemLevel = itemLevel,
		minLevel = minLevel,
		texture = texture,
		stack = stackCount or 20,
	}
	cache[itemID] = meta
	return meta
end

function BuffetLine.GetMeta(itemID, link)
	return ItemMeta(itemID, link)
end

local function BucketAdd(bucket, itemID, meta, bag, slot, link, count)
	local entry = bucket[itemID]
	if not entry then
		entry = {
			id = itemID,
			itemID = itemID,
			meta = meta,
			total = 0,
			bag = bag,
			slot = slot,
			link = link,
		}
		bucket[itemID] = entry
	end
	entry.total = entry.total + count
end

local function IsBetter(entry, best)
	if entry.meta.minLevel ~= best.meta.minLevel then
		return entry.meta.minLevel > best.meta.minLevel
	end
	if entry.meta.itemLevel ~= best.meta.itemLevel then
		return entry.meta.itemLevel > best.meta.itemLevel
	end
	return entry.meta.name < best.meta.name
end

local function BestOf(bucket)
	local best
	for _, entry in pairs(bucket) do
		if not best or IsBetter(entry, best) then
			best = entry
		end
	end
	return best
end

local function ScanBags()
	ResetBuckets()
	local b = BuffetLine.buckets
	local level = UnitLevel("player")
	BuffetLine.playerLevel = level
	local unresolved = 0
	for bag = 0, 4 do
		for slot = 1, GetContainerNumSlots(bag) do
			local itemID = GetContainerItemID(bag, slot)
			if itemID then
				local count = select(2, GetContainerItemInfo(bag, slot)) or 0
				local link = GetContainerItemLink(bag, slot)
				local meta = ItemMeta(itemID, link)
				if not meta then
					unresolved = unresolved + 1
				elseif meta.minLevel <= level then
					if BuffetLine.CONJURED[itemID] then
						BucketAdd(b.mageFood, itemID, meta, bag, slot, link, count)
					elseif IsDrink(meta.name) then
						BucketAdd(b.drink, itemID, meta, bag, slot, link, count)
					else
						BucketAdd(b.food, itemID, meta, bag, slot, link, count)
					end
				end
			end
		end
	end
	return unresolved
end

function BuffetLine.BestNormal(kind)
	local b = BuffetLine.buckets
	if kind == "food" then
		return BestOf(b.food)
	elseif kind == "drink" then
		return BestOf(b.drink) or BestOf(b.conjDrink)
	end
	return nil
end

function BuffetLine.BestFood()
	return BuffetLine.BestNormal("food")
end

function BuffetLine.BestDrink()
	return BuffetLine.BestNormal("drink")
end

function BuffetLine.BestMageFood()
	return BestOf(BuffetLine.buckets.mageFood)
end

BuffetLine.selection = {}

function BuffetLine.UpdateButtons()
	local sel = BuffetLine.selection
	sel.mageFood = BuffetLine.BestMageFood()
	sel.food = BuffetLine.BestFood()
	sel.drink = BuffetLine.BestDrink()

	if BuffetLine.ApplyWidget then
		BuffetLine.ApplyWidget()
	end
end

function BuffetLine.Scan()
	if not (BuffetLine.FOOD_SPELL and BuffetLine.DRINK_SPELL) then
		TryLocalize()
	end
	local unresolved = ScanBags()
	BuffetLine.UpdateButtons()
	return unresolved
end

function BuffetLine.Print(msg)
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99" .. BuffetLine.PREFIX .. "|r: " .. tostring(msg))
	end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("BAG_UPDATE")
events:RegisterEvent("PLAYER_LEVEL_UP")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("MERCHANT_SHOWED")
events:RegisterEvent("MERCHANT_CLOSED")

local dirty = false
local scanRetries = 0

local function ScheduleRescan()
	if scanRetries <= 12 then
		scanRetries = scanRetries + 1
		After(2, function()
			if not InCombatLockdown() then
				local leftover = BuffetLine.Scan()
				if leftover > 0 then
					ScheduleRescan()
				else
					scanRetries = 0
				end
			end
		end)
	end
end

local function SafeScan()
	if InCombatLockdown() then
		dirty = true
		return
	end
	dirty = false
	local unresolved = BuffetLine.Scan()
	if unresolved > 0 then
		ScheduleRescan()
	else
		scanRetries = 0
	end
end

events:SetScript("OnEvent", function(self, event, ...)
	if event == "ADDON_LOADED" then
		local addon = ...
		if addon == BuffetLine.PREFIX and BuffetLine.OnAddonLoaded then
			BuffetLine.OnAddonLoaded()
		end
	elseif event == "PLAYER_LOGIN" then
		SafeScan()
	elseif event == "BAG_UPDATE" or event == "PLAYER_LEVEL_UP" then
		SafeScan()
	elseif event == "PLAYER_REGEN_ENABLED" then
		if dirty then
			SafeScan()
		end
	elseif event == "MERCHANT_SHOWED" then
		SafeScan()
		if BuffetLine.DoRestock then
			BuffetLine.DoRestock()
		end
	end
end)

function BuffetLine.OnAddonLoaded()
	local db = BuffetLineDB
	if type(db) ~= "table" then
		db = {}
		BuffetLineDB = db
	end
	for key, value in pairs(BuffetLine.DEFAULTS) do
		if db[key] == nil then
			if type(value) == "table" then
				local t = {}
				for k, v in pairs(value) do
					t[k] = v
				end
				db[key] = t
			else
				db[key] = value
			end
		end
	end
	if type(db.restock) ~= "table" then
		db.restock = {}
	end
	for key, value in pairs(BuffetLine.DEFAULTS.restock) do
		if db.restock[key] == nil then
			db.restock[key] = value
		end
	end
	if BuffetLine.BuildWidget then
		BuffetLine.BuildWidget()
	end
	if BuffetLine.BuildOptions then
		BuffetLine.BuildOptions()
		BuffetLine.RefreshOptions()
	end
	local tries = 0
	local function LocalizeLater()
		if TryLocalize() or tries >= 15 then
			BuffetLine.Scan()
			return
		end
		tries = tries + 1
		After(2, LocalizeLater)
	end
	LocalizeLater()
end
