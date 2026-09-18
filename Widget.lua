local _, BuffetLine = ...

local widget
local buttons = {}
local lockIcon

local BUTTON_SIZE = 36
local GAP_BETWEEN = 4

local PLACEHOLDER = {
	mageFood = "Interface\\Icons\\INV_Misc_Food_100",
	food = "Interface\\Icons\\INV_Misc_Food_14",
	drink = "Interface\\Icons\\INV_Drink_06",
}

local EMPTY_COLOR = { r = 0.3, g = 0.3, b = 0.3 }

local isDragging = false

-- The Mage Refreshment button is not a permanent citizen: while the widget is
-- unlocked it is always shown as a positioning placeholder; while locked it is
-- shown only once the player can actually use refreshments. Food is the layout
-- anchor: the saved position is always the Food button's screen position and
-- Food stays pixel-fixed across visibility changes, orientation changes and
-- reloads. Mage and Drink are positioned relative to Food.
local foodOffset = { x = 0, y = 0 }
local lastMageVisible = true

local function IsMageVisible()
	if not BuffetLineDB.locked then
		return true
	end
	return (UnitLevel("player") or 0) >= BuffetLine.MageRefreshmentMinLevel()
end

local function SaveWidgetPosition()
	if not isDragging then
		return
	end
	isDragging = false
	widget:StopMovingOrSizing()
	local _, _, _, x, y = widget:GetPoint()
	local pos = {
		point = "TOPLEFT",
		relPoint = "TOPLEFT",
		x = x + foodOffset.x,
		y = y + foodOffset.y,
	}
	BuffetLineDB.position = pos
end

local function RestorePosition()
	local pos = BuffetLineDB.position
	widget:ClearAllPoints()
	if pos and pos.point and pos.x ~= nil then
		widget:SetPoint("TOPLEFT", UIParent, "TOPLEFT", pos.x - foodOffset.x, pos.y - foodOffset.y)
	else
		local width, height = GetScreenWidth(), GetScreenHeight()
		widget:SetPoint("TOPLEFT", UIParent, "TOPLEFT", width / 2 - foodOffset.x, height / 2 - foodOffset.y)
	end
end

-- Buttons are laid out with Food always anchored to the widget's TOPLEFT at a
-- fixed foodOffset so the widget anchor plus foodOffset reproduces Food's saved
-- screen position. The widget rect always covers the visible buttons.
local function LayoutButtons(mageVisible)
	local vertical = BuffetLineDB.orientation == "vertical"
	local b, g = BUTTON_SIZE, GAP_BETWEEN
	if mageVisible then
		widget:SetSize(
			vertical and b or (b * 3 + g * 2),
			vertical and (b * 3 + g * 2) or b
		)
		foodOffset.x = vertical and 0 or (b + g)
		foodOffset.y = vertical and (b + g) or 0
	else
		widget:SetSize(
			vertical and b or (b * 2 + g),
			vertical and (b * 2 + g) or b
		)
		foodOffset.x = 0
		foodOffset.y = 0
	end
	buttons[1]:ClearAllPoints()
	if mageVisible then
		buttons[1]:SetPoint("TOPLEFT", widget, "TOPLEFT", 0, 0)
		buttons[1]:Show()
	else
		buttons[1]:Hide()
	end
	buttons[2]:ClearAllPoints()
	buttons[2]:SetPoint("TOPLEFT", widget, "TOPLEFT", foodOffset.x, foodOffset.y)
	buttons[3]:ClearAllPoints()
	if vertical then
		buttons[3]:SetPoint("TOPLEFT", widget, "TOPLEFT", 0, mageVisible and 2 * (b + g) or (b + g))
	else
		buttons[3]:SetPoint("TOPLEFT", widget, "TOPLEFT", mageVisible and 2 * (b + g) or (b + g), 0)
	end
end

local function ApplyLayout()
	if not widget then
		return
	end
	local mageVisible = IsMageVisible()
	lastMageVisible = mageVisible
	LayoutButtons(mageVisible)
	RestorePosition()
end

function BuffetLine.ApplyWidgetLayout()
	ApplyLayout()
end

function BuffetLine.ApplyWidgetConfig()
	if not widget then
		return
	end
	local locked = BuffetLineDB.locked
	widget:SetMovable(not locked)
	widget:EnableMouse(true)
	if lockIcon then
		if locked then
			lockIcon:Show()
		else
			lockIcon:Hide()
		end
	end
	for _, button in ipairs(buttons) do
		button:EnableMouse(true)
	end
	BuffetLine.SaveWidget = SaveWidgetPosition
	BuffetLine.ApplyWidget()
end

local function ApplyButton(button, stock, placeholder)
	if stock then
		button.icon:SetTexture(stock.meta.texture)
		button.icon:SetVertexColor(1.0, 1.0, 1.0)
		if button.emptyBorder then
			button.emptyBorder:Hide()
		end
		button.count:SetText(stock.total)
		button.count:Show()
		button:SetAttribute("type1", "item")
		button:SetAttribute("item1", stock.link)
		button:SetAttribute("bag1", stock.bag)
		button:SetAttribute("slot1", stock.slot)
		button:SetAttribute("type2", "item")
		button:SetAttribute("item2", stock.link)
		button:SetAttribute("bag2", stock.bag)
		button:SetAttribute("slot2", stock.slot)
		button:SetScript("OnEnter", function(self)
			if not stock.link then
				return
			end
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetHyperlink(stock.link)
			local kind = self.kind
			if kind == "mageFood" then
				GameTooltip:AddLine("Mage Refreshment (health and mana)", 1, 0.8, 0.2)
			elseif kind == "food" then
				GameTooltip:AddLine("Food", 1, 0.8, 0.2)
			elseif kind == "drink" then
				GameTooltip:AddLine("Restores mana", 1, 0.8, 0.2)
			end
			GameTooltip:Show()
		end)
		button:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
	else
		button.icon:SetTexture(placeholder)
		button.icon:SetVertexColor(EMPTY_COLOR.r, EMPTY_COLOR.g, EMPTY_COLOR.b)
		if button.emptyBorder then
			button.emptyBorder:Show()
		end
		button.count:SetText("0")
		button.count:Show()
		button:SetAttribute("type1", nil)
		button:SetAttribute("item1", nil)
		button:SetAttribute("bag1", nil)
		button:SetAttribute("slot1", nil)
		button:SetAttribute("type2", nil)
		button:SetAttribute("item2", nil)
		button:SetAttribute("bag2", nil)
		button:SetAttribute("slot2", nil)
		button:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			if self.kind == "mageFood" then
				GameTooltip:AddLine("No Mage Refreshment available", 1, 1, 1)
				GameTooltip:AddLine("Conjure refreshments or get some from a mage.", 0.8, 0.8, 0.8)
			elseif self.kind == "food" then
				GameTooltip:AddLine("No food available", 1, 1, 1)
			elseif self.kind == "drink" then
				GameTooltip:AddLine("No drink available", 1, 1, 1)
			end
			GameTooltip:Show()
		end)
		button:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
	end
end

function BuffetLine.ApplyWidget()
	if not widget then
		return
	end
	local sel = BuffetLine.selection
	local mageVisible = IsMageVisible()
	if mageVisible ~= lastMageVisible then
		ApplyLayout()
	end
	if mageVisible then
		if BuffetLineDB.locked then
			ApplyButton(buttons[1], sel.mageFood, PLACEHOLDER.mageFood)
		else
			ApplyButton(buttons[1], nil, PLACEHOLDER.mageFood)
		end
	end
	ApplyButton(buttons[2], sel.food, PLACEHOLDER.food)
	ApplyButton(buttons[3], sel.drink, PLACEHOLDER.drink)
end

local function MakeButton(index)
	local button = CreateFrame("Button", "BuffetLineActionButton" .. index, widget, "SecureActionButtonTemplate")
	button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
	button:SetNormalTexture("Interface\\Buttons\\UI-Quickslot2")
	button:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
	button:SetHighlightTexture("Interface\\Buttons\\UI-Quickslot2", "ADD")
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:RegisterForDrag("LeftButton");
	button:SetClampedToScreen(true)
	button:SetMovable(true)

	button.icon = button:CreateTexture(nil, "ARTWORK")
	button.icon:SetAllPoints()
	button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

	button.emptyBorder = button:CreateTexture(nil, "OVERLAY")
	button.emptyBorder:SetAllPoints()
	button.emptyBorder:SetTexture("Interface\\Buttons\\UI-Button-Border")
	button.emptyBorder:SetTexCoord(0, 1, 0, 1)
	button.emptyBorder:SetVertexColor(1.0, 0.2, 0.2, 0.9)
	button.emptyBorder:Hide()

	button.count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
	button.count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
	button.count:SetText("")

	button:SetScript("OnDragStart", function(self)
		if BuffetLineDB.locked then
			return
		end
		if InCombatLockdown() then
			return
		end
		widget:StartMoving()
		isDragging = true
	end)
	button:SetScript("OnDragStop", function(self)
		SaveWidgetPosition()
	end)
	buttons[index] = button
	return button
end

function BuffetLine.BuildWidget()
	if widget then
		return
	end
	widget = CreateFrame("Frame", "BuffetLineWidgetFrame", UIParent)
	widget:SetSize(BUTTON_SIZE * 3 + GAP_BETWEEN * 2, BUTTON_SIZE)
	widget:EnableMouse(true)
	widget:SetMovable(true)
	widget:SetClampedToScreen(true)
	widget:SetFrameStrata("MEDIUM")
	widget:SetFrameLevel(2)

	MakeButton(1)
	MakeButton(2)
	MakeButton(3)
	buttons[1].kind = "mageFood"
	buttons[2].kind = "food"
	buttons[3].kind = "drink"

	lockIcon = widget:CreateTexture(nil, "OVERLAY")
	lockIcon:SetTexture("Interface\\ChatFrame\\ChatFrameLockIcon")
	lockIcon:SetSize(16, 16)
	lockIcon:SetPoint("TOPRIGHT", widget, "TOPRIGHT", 2, 2)
	lockIcon:SetVertexColor(1.0, 1.0, 1.0, 0.6)
	lockIcon:Hide()

	ApplyLayout()
	BuffetLine.ApplyWidgetConfig()
	BuffetLine.ApplyWidget()
end

-- Read-only handles for the test harness.
function BuffetLine.GetWidget()
	return widget
end

function BuffetLine.GetButtons()
	return buttons
end