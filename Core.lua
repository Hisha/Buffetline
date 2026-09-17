BuffetLine = BuffetLine or {}
BuffetLine.PREFIX = "BuffetLine"
BuffetLine.VERSION = GetAddOnMetadata and (GetAddOnMetadata("BuffetLine", "Version") or "1.0.0") or "1.0.0"

BuffetLine.SUB_FOOD = "Food"
BuffetLine.SUB_DRINK = "Drink"
BuffetLine.SUB_BOTH = "Food & Drink"

BuffetLine.CONJURED = {
	[1113] = true,
	[1114] = true,
	[1487] = true,
	[2136] = true,
	[2288] = true,
	[3772] = true,
	[4540] = true,
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
	[28112] = true,
	[30703] = true,
	[34062] = true,
	[42999] = true,
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

BuffetLine.itemMeta = {}
BuffetLine.buckets = { mageFood = {}, food = {}, drink = {}, conjFood = {}, conjDrink = {} }

local localizeSamples = {
	{ id = 117, key = "SUB_FOOD" },
	{ id = 159, key = "SUB_DRINK" },
	{ id = 43523, key = "SUB_BOTH" },
}
local localizedSamples = {}
local localized = false

local function TryLocalize()
	if localized then
		return true
	end
	local ready = true
	for _, sample in ipairs(localizeSamples) do
		if not localizedSamples[sample.key] then
			local subType = select(7, GetItemInfo(sample.id))
			if subType and subType ~= "" then
				BuffetLine[sample.key] = subType
				localizedSamples[sample.key] = true
			else
				ready = false
			end
		end
	end
	if ready then
		localized = true
	end
	return ready
end

local function ResetBuckets()
	local b = BuffetLine.buckets
	for key in pairs(b) do
		wipe(b[key])
	end
end

local function BucketAdd(bucket, itemID, meta, bag, slot, link, count)
	count = count or 0
	local entry = bucket[itemID]
	if not entry then
		bucket[itemID] = {
			itemID = itemID,
			meta = meta,
			bag = bag,
			slot = slot,
			link = link or GetContainerItemLink(bag, slot),
			total = count,
		}
	else
		entry.total = entry.total + count
	end
end

local function ItemMeta(itemID, link)
	local meta = BuffetLine.itemMeta[itemID]
	if not meta then
		local name, _, _, itemLevel, minLevel, _, subType, stackCount, _, texture = GetItemInfo(link or itemID)
		if not name or not subType or not texture then
			return nil
		end
		meta = {
			name = name,
			itemLevel = itemLevel or 0,
			minLevel = minLevel or 0,
			subType = subType,
			stackCount = stackCount or 1,
			texture = texture,
		}
		BuffetLine.itemMeta[itemID] = meta
	end
	return meta
end

function BuffetLine.GetMeta(itemID, link)
	return ItemMeta(itemID, link)
end

local function BestOf(pool)
	local best
	for _, entry in pairs(pool) do
		if not best
			or entry.meta.itemLevel > best.meta.itemLevel
			or (entry.meta.itemLevel == best.meta.itemLevel and entry.total > best.total)
			or (entry.meta.itemLevel == best.meta.itemLevel and entry.total == best.total and entry.meta.name < best.meta.name)
		then
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
				local count = select(2, GetContainerItemInfo(bag, slot))
				local link = GetContainerItemLink(bag, slot)
				local meta = ItemMeta(itemID, link)
				if not meta then
					unresolved = unresolved + 1
				elseif meta.minLevel <= level then
					local subType = meta.subType
					if subType == BuffetLine.SUB_BOTH then
						BucketAdd(b.mageFood, itemID, meta, bag, slot, link, count)
					elseif subType == BuffetLine.SUB_FOOD then
						if BuffetLine.CONJURED[itemID] then
							BucketAdd(b.conjFood, itemID, meta, bag, slot, link, count)
						else
							BucketAdd(b.food, itemID, meta, bag, slot, link, count)
						end
					elseif subType == BuffetLine.SUB_DRINK then
						if BuffetLine.CONJURED[itemID] then
							BucketAdd(b.conjDrink, itemID, meta, bag, slot, link, count)
						else
							BucketAdd(b.drink, itemID, meta, bag, slot, link, count)
						end
					end
				end
			end
		end
	end
	return unresolved
end

function BuffetLine.BestNormal(kind)
	return BestOf(BuffetLine.buckets[kind])
end

function BuffetLine.BestMageFood()
	return BestOf(BuffetLine.buckets.mageFood)
end

function BuffetLine.BestFood()
	return BestOf(BuffetLine.buckets.food) or BestOf(BuffetLine.buckets.conjFood)
end

function BuffetLine.BestDrink()
	return BestOf(BuffetLine.buckets.drink) or BestOf(BuffetLine.buckets.conjDrink)
end

function BuffetLine.Scan()
	local unresolved = ScanBags()
	if BuffetLine.UpdateButtons then
		BuffetLine.UpdateButtons()
	end
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
		C_Timer.After(2, function()
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
		C_Timer.After(2, LocalizeLater)
	end
	LocalizeLater()
end