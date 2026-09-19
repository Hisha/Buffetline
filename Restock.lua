local _, BuffetLine = ...

local floor = math.floor
local ceil = math.ceil

-- HARD DEFENSIVE CAP: one merchant operation may never request more than this
-- many purchase units, no matter how corrupt the input state is. Per server
-- semantics (item_template.BuyCount per unit, 1 for normal food/drink) this
-- bounds the granted item count to the same value. A configured target is
-- honored in the sense that the cap is high enough for any normal target;
-- absurd values are impossible by construction.
local MAX_ITEMS_PER_BUY = 200

local function ExtractID(link)
	if not link then
		return nil
	end
	local itemID = link:match("item:(%d+)")
	if itemID then
		return tonumber(itemID)
	end
end

-- Live inventory of a restock role: the total count of the player's normal
-- (non-conjured) stock for that role, plus the best such in-bag item. Conjured
-- mage food/water/refreshments are always excluded so they can never satisfy a
-- vendor restock target. Items classified by both FOOD_IDS and DRINK_IDS count
-- toward both roles, matching Core's dual-role bucket behavior.
local function NormalStock(kind, level)
	local total = 0
	local best
	local set = BuffetLine.FOOD_IDS
	if kind == "drink" then
		set = BuffetLine.DRINK_IDS
	end
	for bag = 0, 4 do
		for slot = 1, GetContainerNumSlots(bag) do
			local itemID = GetContainerItemID(bag, slot)
			if itemID and not BuffetLine.CONJURED[itemID] and set[itemID] then
				local meta = BuffetLine.GetMeta(itemID, GetContainerItemLink(bag, slot))
				if meta and meta.minLevel <= level then
					local count = select(2, GetContainerItemInfo(bag, slot)) or 0
					total = total + count
					if not best
						or meta.minLevel > best.meta.minLevel
						or (meta.minLevel == best.meta.minLevel and meta.itemLevel > best.meta.itemLevel)
						or (meta.minLevel == best.meta.minLevel and meta.itemLevel == best.meta.itemLevel and meta.name < best.meta.name)
					then
						best = { itemID = itemID, meta = meta }
					end
				end
			end
		end
	end
	return total, best
end

local function FreeSlotCount()
	local free = 0
	for bag = 0, 4 do
		for slot = 1, GetContainerNumSlots(bag) do
			if not GetContainerItemID(bag, slot) then
				free = free + 1
			end
		end
	end
	return free
end

-- Best usable vendor item for a role, ranked exactly like Core ranks the bag
-- item list (higher required level, then higher item level, then name). Bundle
-- size and the player's current inventory are deliberately ignored here.
local function BestOfList(list)
	local best
	for _, entry in ipairs(list) do
		if not best
			or entry.meta.minLevel > best.meta.minLevel
			or (entry.meta.minLevel == best.meta.minLevel and entry.meta.itemLevel > best.meta.itemLevel)
			or (entry.meta.minLevel == best.meta.minLevel and entry.meta.itemLevel == best.meta.itemLevel and entry.meta.name < best.meta.name)
		then
			best = entry
		end
	end
	return best
end

local function EntryByID(list, itemID)
	for _, entry in ipairs(list) do
		if entry.id == itemID then
			return entry
		end
	end
end

local function TryRestock(kind, target, vendorList, level)
	-- Configuration is already sanitized to a valid 0..1000 integer by the
	-- shared Core validator (initialization, options, slash). This is only a
	-- last-line defense so a purchase never runs on unsanitized configuration.
	target = BuffetLine.SanitizeTarget(target) or 0
	if #vendorList == 0 then
		return
	end

	local have, bagBest = NormalStock(kind, level)
	local vendorBest = BestOfList(vendorList)
	if not vendorBest then
		return
	end

	-- Prefer to top up the player's current best normal item when this merchant
	-- stocks it; otherwise use this merchant's best usable item of the role.
	local stock = (bagBest and EntryByID(vendorList, bagBest.itemID)) or vendorBest

	-- stock 3.3.5a merchant API returning
	-- name, texture, price, quantity, numAvailable, isUsable, extendedCost:
	-- quantity is that item's purchase unit size (the item_template.BuyCount
	-- fed to the vendor icon; 1 for normal food/drink). VERIFIED against the
	-- server (AzerothCore Player::BuyItemFromVendorSlot -> _StoreOrEquipNewItem):
	-- BuyMerchantItem(index, N) charges BuyPrice*N and grants BuyCount*N items.
	-- The argument is therefore a count of units, not a batch multiplier, and
	-- has no hidden relationship with the returned quantity except the grant.
	local name, _, price, bundle, numAvailable, _, extendedCost = GetMerchantItemInfo(stock.index)

	local deficit = target - have
	local planned = 0
	if target > 0 and name and not extendedCost and numAvailable ~= 0 and deficit > 0 then
		local space = FreeSlotCount() * (stock.meta.stack or 1)
		if space > 0 then
			deficit = math.min(deficit, space)
			bundle = bundle or 1
			if bundle < 1 then
				bundle = 1
			end
			-- Minimum number of units to grant to reach or exceed the target.
			planned = ceil(deficit / bundle)
			if price and price > 0 then
				local affordable = floor((GetMoney() or 0) / price)
				if planned > affordable then
					planned = affordable
				end
			end
			if planned < 1 then
				planned = 0
			end
		end
	end
	-- Hard defensive ceiling applied at the last possible gate, so corrupt
	-- state can never result in an absurd quantity in ONE merchant operation.
	if planned > MAX_ITEMS_PER_BUY then
		planned = MAX_ITEMS_PER_BUY
	end

	if planned < 1 then
		return
	end

	BuyMerchantItem(stock.index, planned)
	BuffetLine.Print("Bought x" .. (planned * bundle) .. " " .. name .. ".")
end

function BuffetLine.DoRestock()
    local charDB = BuffetLineCharDB
    local restock = charDB and charDB.restock
    if not (restock and restock.enabled) then
        return
    end
	if not (MerchantFrame and MerchantFrame:IsShown()) then
		return
	end

	local level = UnitLevel("player")
	local vendorFood = {}
	local vendorDrink = {}
	for index = 1, GetMerchantNumItems() do
		local link = GetMerchantItemLink(index)
		local itemID = ExtractID(link)
		if itemID then
			local meta = BuffetLine.GetMeta(itemID, link)
			if meta and not BuffetLine.CONJURED[itemID] and meta.minLevel <= level then
				local entry = { index = index, id = itemID, meta = meta }
				if BuffetLine.FOOD_IDS[itemID] then
					tinsert(vendorFood, entry)
				end
				if BuffetLine.DRINK_IDS[itemID] then
					tinsert(vendorDrink, entry)
				end
			end
		end
	end

	TryRestock("food", restock.food, vendorFood, level)
	TryRestock("drink", restock.drink, vendorDrink, level)
end