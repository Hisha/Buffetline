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

-- Slice 5: the conjured set splits by role. Classic conjured mage food restores
-- health only and belongs to the Food role; classic conjured mage water restores
-- mana only and belongs to the Drink role. Both are preferred over purchased
-- normal items once the player level makes them usable.
--
-- Slice 6: the combined health+mana Mage refreshments (34062, 43518, 43523) get
-- their own dedicated button. They remain in CONJURED so restock never buys
-- them, but live in CONJ_REFRESH and route to the mageFood bucket, never to
-- Food or Drink.  Buffet's conjfood/conjwater lists put all three in both,
-- which is what separates them from the role-specific items below.
BuffetLine.CONJ_FOOD = {
	[1113] = true,
	[1114] = true,
	[1487] = true,
	[5349] = true,
	[8075] = true,
	[8076] = true,
	[22895] = true,
	[22019] = true,
}

BuffetLine.CONJ_WATER = {
	[5350] = true,
	[2288] = true,
	[2136] = true,
	[3772] = true,
	[8077] = true,
	[8078] = true,
	[8079] = true,
	[30703] = true,
	[22018] = true,
}

-- Combined health+mana Mage refreshments (Slice 6 dedicated button). Values are
-- the required levels from the 3.3.5 item database: 34062 Conjured Mana Biscuit
-- (lv65), 43518 Conjured Mana Pie (lv74), 43523 Conjured Mana Strudel (lv80).
BuffetLine.CONJ_REFRESH = {
	[34062] = 65,
	[43518] = 74,
	[43523] = 80,
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

-- Schema version of the saved widget position. Bump this whenever the stored
-- coordinate representation changes so load-time validation can tell a
-- compatible saved position from legacy or incompatible data.
BuffetLine.POSITION_FORMAT = 1

-- ONE shared restock-target validator, used by initialization, the options
-- panel, slash commands, and restock. Returns the whole number when value is a
-- valid target (integer 0..1000), or nil for empty, nonnumeric, fractional,
-- negative, or out-of-range input so callers can reject it instead of storing
-- junk in SavedVariables.
function BuffetLine.SanitizeTarget(value)
	local target = tonumber(value)
	if type(target) ~= "number" or target ~= target then
		return nil
	end
	if target < 0 or target > 1000 or math.floor(target) ~= target then
		return nil
	end
	return target
end

-- True when a UIParent TOPLEFT offset pair could reasonably place the widget
-- on screen. Load-time validation uses this so corrupt or foreign coordinates
-- reset to the normal default instead of stranding the widget off-screen.
function BuffetLine.IsValidPosition(x, y)
	local screenWidth, screenHeight = GetScreenWidth(), GetScreenHeight()
	if not (screenWidth and screenWidth > 0 and screenHeight and screenHeight > 0) then
		return true
	end
	local margin = 50
	if x < -margin or x > screenWidth + margin then
		return false
	end
	if y > margin or y < -(screenHeight + margin) then
		return false
	end
	return true
end

-- Food and drink both use the "Food & Drink" item subclass in 3.3.5, and the
-- on-use spell returned by GetItemSpell is not reliably available for items in
-- the bags, so neither can separate them. The proven approach of the Buffet
-- 3.3.5 addon is a curated item-ID database: every known health food maps to
-- the Food slot, every known mana drink to the Drink slot, and conjured mage
-- items are kept separate. IDs below are taken from the Buffet 3.3.5 database.
BuffetLine.FOOD_IDS = {
	[117] = true, [414] = true, [422] = true, [733] = true, [787] = true, [961] = true, [1326] = true, [1707] = true, [2070] = true, [2287] = true, [2679] = true, [2681] = true, [2682] = true, [2685] = true,
	[3448] = true, [3770] = true, [3771] = true, [3927] = true, [4536] = true, [4537] = true, [4538] = true, [4539] = true, [4540] = true, [4541] = true, [4542] = true, [4544] = true, [4592] = true, [4593] = true,
	[4594] = true, [4599] = true, [4601] = true, [4602] = true, [4604] = true, [4605] = true, [4606] = true, [4607] = true, [4608] = true, [4656] = true, [5057] = true, [5066] = true, [5095] = true, [5473] = true,
	[5478] = true, [5526] = true, [6290] = true, [6299] = true, [6316] = true, [6807] = true, [6887] = true, [6890] = true, [7097] = true, [7228] = true, [8364] = true, [8932] = true, [8948] = true, [8950] = true,
	[8952] = true, [8953] = true, [8957] = true, [9681] = true, [11109] = true, [11415] = true, [11444] = true, [12238] = true, [13546] = true, [13724] = true, [13755] = true, [13893] = true, [13930] = true, [13933] = true,
	[13935] = true, [16166] = true, [16167] = true, [16168] = true, [16169] = true, [16170] = true, [16171] = true, [16766] = true, [17119] = true, [17344] = true, [17406] = true, [17407] = true, [17408] = true, [18255] = true,
	[18632] = true, [18633] = true, [18635] = true, [19223] = true, [19224] = true, [19225] = true, [19301] = true, [19304] = true, [19305] = true, [19306] = true, [19696] = true, [19994] = true, [19995] = true, [19996] = true,
	[20031] = true, [20857] = true, [21030] = true, [21031] = true, [21033] = true, [21071] = true, [21153] = true, [21235] = true, [21552] = true, [22324] = true, [23160] = true, [23495] = true, [24072] = true, [24338] = true,
	[24408] = true, [27661] = true, [27854] = true, [27855] = true, [27856] = true, [27857] = true, [27858] = true, [27859] = true, [28486] = true, [29393] = true, [29394] = true, [29412] = true, [29448] = true, [29449] = true,
	[29450] = true, [29451] = true, [29452] = true, [29453] = true, [30355] = true, [30458] = true, [30610] = true, [30816] = true, [32685] = true, [32686] = true, [32722] = true, [33048] = true, [33053] = true, [33443] = true,
	[33449] = true, [33451] = true, [33452] = true, [33454] = true, [34747] = true, [34759] = true, [34760] = true, [34761] = true, [34780] = true, [35947] = true, [35948] = true, [35949] = true, [35950] = true, [35951] = true,
	[35952] = true, [35953] = true, [37252] = true, [38427] = true, [38428] = true, [38706] = true, [40202] = true, [40356] = true, [40358] = true, [40359] = true, [41729] = true, [41751] = true, [42428] = true, [42429] = true,
	[42430] = true, [42431] = true, [42432] = true, [42433] = true, [42434] = true, [42778] = true, [43087] = true, [44049] = true, [44071] = true, [44072] = true, [44607] = true, [44608] = true, [44609] = true, [44722] = true,
	[44749] = true, [45932] = true,
}

BuffetLine.DRINK_IDS = {
	[159] = true, [1179] = true, [1205] = true, [1401] = true, [1645] = true, [1708] = true, [2682] = true, [3448] = true, [4791] = true, [8766] = true, [9451] = true, [10841] = true, [13724] = true, [17404] = true,
	[17405] = true, [18300] = true, [19299] = true, [19300] = true, [19301] = true, [20031] = true, [21071] = true, [21153] = true, [23161] = true, [23585] = true, [24006] = true, [24007] = true, [27860] = true, [28399] = true,
	[29395] = true, [29401] = true, [29454] = true, [30457] = true, [32453] = true, [32455] = true, [32668] = true, [32722] = true, [33042] = true, [33053] = true, [33444] = true, [33445] = true, [34759] = true, [34760] = true,
	[34761] = true, [34780] = true, [35954] = true, [37253] = true, [38429] = true, [38430] = true, [38431] = true, [38698] = true, [39520] = true, [40357] = true, [41731] = true, [42777] = true, [43086] = true, [43236] = true,
	[44750] = true, [45932] = true,
}

local function UseClass(itemID)
	local food = BuffetLine.FOOD_IDS[itemID]
	local drink = BuffetLine.DRINK_IDS[itemID]
	if food and drink then
		return "both"
	elseif food then
		return "food"
	elseif drink then
		return "drink"
	end
	return nil
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
					if BuffetLine.CONJ_FOOD[itemID] then
						BucketAdd(b.conjFood, itemID, meta, bag, slot, link, count)
					elseif BuffetLine.CONJ_WATER[itemID] then
						BucketAdd(b.conjDrink, itemID, meta, bag, slot, link, count)
					elseif BuffetLine.CONJ_REFRESH[itemID] then
						BucketAdd(b.mageFood, itemID, meta, bag, slot, link, count)
					elseif BuffetLine.CONJURED[itemID] then
						BucketAdd(b.mageFood, itemID, meta, bag, slot, link, count)
					else
						local kind = UseClass(itemID)
						if kind == "food" or kind == "both" then
							BucketAdd(b.food, itemID, meta, bag, slot, link, count)
						end
						if kind == "drink" or kind == "both" then
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
	local b = BuffetLine.buckets
	if kind == "food" then
		return BestOf(b.conjFood) or BestOf(b.food)
	elseif kind == "drink" then
		return BestOf(b.conjDrink) or BestOf(b.drink)
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

-- The packaged Mage refreshments require at least this level to be usable. The
-- dedicated button hides below it while the widget is locked.
function BuffetLine.MageRefreshmentMinLevel()
	local minLevel = 0
	for _, required in pairs(BuffetLine.CONJ_REFRESH) do
		if minLevel == 0 or required < minLevel then
			minLevel = required
		end
	end
	return minLevel
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
events:RegisterEvent("MERCHANT_SHOW")
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
	elseif event == "MERCHANT_SHOW" then
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
	db.locked = db.locked and true or false
	if db.orientation ~= "vertical" then
		db.orientation = "horizontal"
	end
	db.restock.enabled = db.restock.enabled and true or false
	-- Invalid or legacy restock targets reset to the normal default; only valid
	-- 0..1000 integer targets survive.
	db.restock.food = BuffetLine.SanitizeTarget(db.restock.food)
		or BuffetLine.DEFAULTS.restock.food
	db.restock.drink = BuffetLine.SanitizeTarget(db.restock.drink)
		or BuffetLine.DEFAULTS.restock.drink
	-- A saved position is usable only when it matches this schema version, the
	-- Food-authoritative TOPLEFT representation, and plausible coordinates that
	-- could actually place the widget on screen.
	local rawPos = type(db.position) == "table" and db.position or nil
	BuffetLine.Print(string.format(
		"Position LOAD raw format=%s x=%s y=%s",
		tostring(rawPos and rawPos.format),
		tostring(rawPos and rawPos.x),
		tostring(rawPos and rawPos.y)))
	if not rawPos
		or rawPos.format ~= BuffetLine.POSITION_FORMAT
		or rawPos.point ~= "TOPLEFT"
		or type(rawPos.x) ~= "number"
		or rawPos.x ~= rawPos.x
		or type(rawPos.y) ~= "number"
		or rawPos.y ~= rawPos.y
		or not BuffetLine.IsValidPosition(rawPos.x, rawPos.y)
	then
		BuffetLine.Print(string.format(
			"Position VALID result=rejected x=%s y=%s",
			tostring(rawPos and rawPos.x),
			tostring(rawPos and rawPos.y)))
		db.position = nil
	else
		BuffetLine.Print(string.format(
			"Position VALID result=accepted x=%s y=%s",
			tostring(rawPos.x), tostring(rawPos.y)))
	end
	BuffetLine.Print(string.format(
		"AddonLoaded saved food=%s drink=%s enabled=%s locked=%s orientation=%s",
		db.restock.food, db.restock.drink,
		db.restock.enabled and "true" or "false",
		db.locked and "true" or "false",
		db.orientation))
	if BuffetLine.BuildWidget then
		BuffetLine.BuildWidget()
	end
	if BuffetLine.BuildOptions then
		BuffetLine.BuildOptions()
		BuffetLine.RefreshOptions()
	end
	BuffetLine.Scan()
end
