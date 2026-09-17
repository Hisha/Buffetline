local function ExtractID(link)
	if not link then
		return nil
	end
	local itemID = link:match("item:(%d+)")
	if itemID then
		return tonumber(itemID)
	end
end

local function BagCountOf(itemID)
	local total = 0
	for bag = 0, 4 do
		for slot = 1, GetContainerNumSlots(bag) do
			if GetContainerItemID(bag, slot) == itemID then
				local count = select(2, GetContainerItemInfo(bag, slot))
				total = total + (count or 0)
			end
		end
	end
	return total
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

local function BestOfList(list)
	local best
	for _, entry in ipairs(list) do
		if not best
			or entry.meta.itemLevel > best.meta.itemLevel
			or (entry.meta.itemLevel == best.meta.itemLevel and entry.meta.name < best.meta.name)
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

local function TryRestock(kind, target, vendorList)
	if target <= 0 or #vendorList == 0 then
		return
	end
	local bagBest = BuffetLine.BestNormal(kind)
	local vendorBest = BestOfList(vendorList)
	local stock

	if bagBest and not BuffetLine.CONJURED[bagBest.itemID] then
		if EntryByID(vendorList, bagBest.itemID) then
			stock = EntryByID(vendorList, bagBest.itemID)
		else
			stock = vendorBest
		end
	else
		stock = vendorBest
	end

	local have = BagCountOf(stock.id)
	local deficit = target - have
	if deficit <= 0 then
		return
	end

	local space = FreeSlotCount() * (stock.meta.stackCount or 1)
	if space <= 0 then
		return
	end
	deficit = math.min(deficit, space)

	local price, priceType
	local ok = pcall(function()
		price, priceType = GetMerchantItemCostInfo(stock.index)
	end)
	if ok and type(price) == "number" and type(priceType) == "number" and priceType == 0 then
		if price > 0 then
			deficit = math.min(deficit, math.floor(GetMoney() / price))
		end
	end

	if deficit <= 0 then
		return
	end

	BuyMerchantItem(stock.index, deficit)
	BuffetLine.Print("Bought x" .. deficit .. " " .. stock.meta.name .. ".")
end

function BuffetLine.DoRestock()
	local db = BuffetLineDB
	local restock = db and db.restock
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
			if meta
				and not BuffetLine.CONJURED[itemID]
				and meta.minLevel <= level
				and (meta.subType == BuffetLine.SUB_FOOD or meta.subType == BuffetLine.SUB_DRINK)
			then
				local entry = { index = index, id = itemID, meta = meta }
				if meta.subType == BuffetLine.SUB_FOOD then
					tinsert(vendorFood, entry)
				else
					tinsert(vendorDrink, entry)
				end
			end
		end
	end

	TryRestock("food", restock.food or 0, vendorFood)
	TryRestock("drink", restock.drink or 0, vendorDrink)
end