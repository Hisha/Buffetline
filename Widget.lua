local SIZE = 36
local GAP = 4

local defs = {
	{ role = "mageFood", label = "Mage Food", placeholder = "Interface\\Icons\\INV_Misc_Food_100", empty = "No conjured mage food available." },
	{ role = "food", label = "Food", placeholder = "Interface\\Icons\\INV_Misc_Food_14", empty = "No food available." },
	{ role = "drink", label = "Drink", placeholder = "Interface\\Icons\\INV_Drink_06", empty = "No drink available." },
}

local widget
local buttons = {}
local lockIcon

local function Layout()
	local db = BuffetLineDB
	local horizontal = db.orientation ~= "vertical"
	if horizontal then
		widget:SetSize(SIZE * 3 + GAP * 2, SIZE)
	else
		widget:SetSize(SIZE, SIZE * 3 + GAP * 2)
	end
	for i, button in ipairs(buttons) do
		button:ClearAllPoints()
		local offset = (i - 1) * (SIZE + GAP)
		if horizontal then
			button:SetPoint("TOPLEFT", widget, "TOPLEFT", offset, 0)
		else
			button:SetPoint("TOPLEFT", widget, "TOPLEFT", 0, -offset)
		end
	end
end

function BuffetLine.SaveWidgetPosition()
	local point, relativeTo, relPoint, x, y = widget:GetPoint()
	local db = BuffetLineDB
	if not point then
		db.position = nil
		return
	end
	local relativeName
	if relativeTo then
		relativeName = relativeTo:GetName()
	end
	if not relativeName then
		relativeTo = UIParent
		relativeName = "UIParent"
		relPoint = relPoint or point
	end
	db.position = {
		point = point,
		relativeTo = relativeName,
		relPoint = relPoint or point,
		x = x or 0,
		y = y or 0,
	}
end

local function RestorePosition()
	local db = BuffetLineDB
	local pos = db and db.position
	if pos and pos.point then
		local relativeTo = (pos.relativeTo and _G[pos.relativeTo]) or UIParent
		widget:ClearAllPoints()
		widget:SetPoint(pos.point, relativeTo, pos.relPoint, pos.x, pos.y)
	else
		widget:ClearAllPoints()
		widget:SetPoint("RIGHT", UIParent, "RIGHT", -150, 60)
	end
end

function BuffetLine.WidgetStartDrag()
	if BuffetLineDB.locked or InCombatLockdown() then
		return
	end
	widget:StartMoving()
end

function BuffetLine.WidgetStopDrag()
	if widget:IsMoving() then
		widget:StopMovingOrSizing()
		widget:SetUserPlaced(true)
		BuffetLine.SaveWidgetPosition()
	end
end

local function ApplyButtonState(button, def, stock)
	if stock and stock.meta and stock.meta.texture then
		button.icon:SetTexture(stock.meta.texture)
		button.icon:SetVertexColor(1, 1, 1, 1)
		button.count:SetText(stock.total >= 1 and stock.total or "")
		button.count:SetTextColor(1, 1, 1)
		button:SetBackdropBorderColor(0, 0, 0, 0)
		button:SetAttribute("type", "item")
		button:SetAttribute("item", stock.link)
		button:SetAttribute("bag", stock.bag)
		button:SetAttribute("slot", stock.slot)
		button:SetAttribute("button", "LeftButton")
	else
		button.icon:SetTexture(def.placeholder)
		button.icon:SetVertexColor(0.3, 0.3, 0.3, 0.9)
		button.count:SetText("0")
		button.count:SetTextColor(1, 0.25, 0.25)
		button:SetBackdropBorderColor(1, 0.15, 0.15, 0.9)
		button:SetAttribute("type", nil)
		button:SetAttribute("item", nil)
		button:SetAttribute("bag", nil)
		button:SetAttribute("slot", nil)
	end
end

function BuffetLine.UpdateButtons()
	if InCombatLockdown() then
		return
	end
	BuffetLine.selection = {
		mageFood = BuffetLine.BestMageFood(),
		food = BuffetLine.BestFood(),
		drink = BuffetLine.BestDrink(),
	}
	for i, def in ipairs(defs) do
		ApplyButtonState(buttons[i], def, BuffetLine.selection[def.role])
	end
end

function BuffetLine.Selected(role)
	local selection = BuffetLine.selection
	return selection and selection[role]
end

function BuffetLine.ApplyWidgetConfig()
	Layout()
	RestorePosition()
	if lockIcon then
		lockIcon:SetShown(BuffetLineDB.locked)
	end
end

function BuffetLine.BuildWidget()
	widget = CreateFrame("Frame", "BuffetLineWidgetFrame", UIParent)
	widget:SetMovable(true)
	widget:SetClampedToScreen(true)
	widget:EnableMouse(true)
	widget:RegisterForDrag("LeftButton")
	widget:SetScript("OnDragStart", BuffetLine.WidgetStartDrag)
	widget:SetScript("OnDragStop", BuffetLine.WidgetStopDrag)
	widget:SetScript("OnMouseUp", function(self, button)
		if button == "RightButton" and BuffetLine.ToggleMenu then
			BuffetLine.ToggleMenu()
		end
	end)

	lockIcon = widget:CreateTexture(nil, "TOOLTIP")
	lockIcon:SetTexture("Interface\\ChatFrame\\ChatFrameLockIcon")
	lockIcon:SetSize(13, 13)
	lockIcon:SetPoint("TOPRIGHT", widget, "TOPRIGHT", -1, -1)
	lockIcon:SetAlpha(0.8)
	lockIcon:Hide()

	for i, def in ipairs(defs) do
		local button = CreateFrame("Button", "BuffetLineActionButton" .. i, widget, "SecureActionButtonTemplate")
		button:SetSize(SIZE, SIZE)
		button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		button:RegisterForDrag("LeftButton")
		button:SetScript("OnDragStart", BuffetLine.WidgetStartDrag)
		button:SetScript("OnDragStop", BuffetLine.WidgetStopDrag)
		button:SetScript("OnMouseUp", function(self, mouseButton)
			if mouseButton == "RightButton" and BuffetLine.ToggleMenu then
				BuffetLine.ToggleMenu()
			end
		end)

		button:SetBackdrop({
			bgFile = "Interface\\Buttons\\WHITE8X8",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = false,
			tileSize = 0,
			edgeSize = 12,
			insets = { left = 3, right = 3, top = 3, bottom = 3 },
		})
		button:SetBackdropColor(0, 0, 0, 0.45)
		button:SetBackdropBorderColor(0, 0, 0, 0)

		local icon = button:CreateTexture(nil, "ARTWORK")
		icon:SetPoint("TOPLEFT", button, "TOPLEFT", 3, -3)
		icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 3)
		icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		button.icon = icon

		local count = button:CreateFontString(nil, "OVERLAY")
		count:SetFontObject(GameFontNormalSmall)
		count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 1)
		count:SetJustifyH("RIGHT")
		button.count = count

		button:SetScript("OnEnter", function(self)
			local stock = BuffetLine.Selected(def.role)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			if stock then
				GameTooltip:SetBagItem(stock.bag, stock.slot)
				GameTooltip:AddLine("Quantity: " .. stock.total, 1, 1, 1)
				if BuffetLine.CONJURED[stock.itemID] then
					GameTooltip:AddLine("Conjured item", 1, 1, 0.5)
				end
			else
				GameTooltip:AddLine(def.label, 1, 1, 1)
				GameTooltip:AddLine(def.empty, 1, 0.3, 0.3)
			end
			GameTooltip:Show()
		end)
		button:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)

		buttons[i] = button
	end

	BuffetLine.ApplyWidgetConfig()
end