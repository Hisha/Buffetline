local _, BuffetLine = ...

local panel
local widgets
local refreshing = false

local function OpenOptionsPanel()
	if InterfaceOptionsFrame then
		InterfaceOptionsFrame:Show()
		if InterfaceOptionsFrame_OpenToCategory then
			InterfaceOptionsFrame_OpenToCategory(BuffetLine.OptionsPanel)
			InterfaceOptionsFrame_OpenToCategory(BuffetLine.OptionsPanel)
		end
	end
end

local function MakeCheck(parent, frameName, y, labelText, getter, setter)
	local check = CreateFrame("CheckButton", frameName, parent)
	check:SetSize(26, 26)
	check:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
	check:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
	check:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
	check:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
	check:SetDisabledCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check-Disabled")
	check:SetDisabledTexture("Interface\\Buttons\\UI-CheckBox-Disabled")
	check:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, y)
	check:SetChecked(getter())
	check:SetScript("OnClick", function(self)
		setter(self:GetChecked())
	end)
	local label = check:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	label:SetPoint("LEFT", check, "RIGHT", 2, 0)
	label:SetText(labelText)
	return check
end

local function DisplayNumber(value)
	local v = tonumber(value)
	if not v or v ~= v or v < 0 then
		v = 0
	end
	return tostring(math.floor(v))
end

-- Commit one target EditBox. Only a user edit (box.dirty) commits; a
-- programmatic refresh/repaint never does. Valid 0..1000 integers are stored;
-- anything else is rejected, the box is repainted from the stored value, and a
-- message is printed so invalid input never reaches SavedVariables.
local function CommitNumberBox(box, getter, setter)
	if not box.dirty then
		return
	end
	box.dirty = false
	local raw = box:GetText()
	local value = BuffetLine.SanitizeTarget(raw)
	if not value then
		box:SetText(DisplayNumber(getter()))
		BuffetLine.Print(string.format(
			"%s restock target must be an integer from 0 through 1000.",
			box.commitLabel))
		return
	end
	setter(value)
	BuffetLine.Print(string.format(
		"Commit %s raw=%s stored=%s",
		box.commitLabel, raw, tostring(BuffetLineDB.restock[box.kind])))
end

local function MakeNumberBox(parent, frameName, y, labelText, commitLabel, kind, getter, setter)
	local box = CreateFrame("EditBox", frameName, parent, "InputBoxTemplate")
	box:SetSize(52, 18)
	box:SetAutoFocus(false)
	box:SetMaxLetters(6)
	box:SetNumeric(true)
	local label = box:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	label:SetPoint("RIGHT", box, "LEFT", -4, 4)
	label:SetText(labelText)
	box:SetPoint("LEFT", parent, "LEFT", 230, y)
	box.kind = kind
	box.commitLabel = commitLabel
	box.dirty = false
	box:SetText(DisplayNumber(getter()))
	box:SetScript("OnTextChanged", function(self, userInput)
		if userInput and not refreshing then
			self.dirty = true
		end
	end)
	box:SetScript("OnEditFocusLost", function(self)
		CommitNumberBox(self, getter, setter)
	end)
	box:SetScript("OnEnterPressed", function(self)
		CommitNumberBox(self, getter, setter)
		self:ClearFocus()
	end)
	box:SetScript("OnEscapePressed", function(self)
		self.dirty = false
		self:SetText(DisplayNumber(getter()))
		self:ClearFocus()
	end)
	box.commit = function(self)
		CommitNumberBox(self, getter, setter)
	end
	return box
end

function BuffetLine.RefreshOptions()
	if refreshing or not widgets then
		return
	end
	-- A programmatic refresh is NOT a user commit: discard any pending edits so
	-- a repaint can never save partial text. Explicit edit-completion paths
	-- (Enter, focus loss, panel hide) are the only ways a new value is stored.
	if widgets.food then
		widgets.food.dirty = false
	end
	if widgets.drink then
		widgets.drink.dirty = false
	end
	refreshing = true
	widgets.lock:SetChecked(BuffetLineDB.locked and true or false)
	widgets.vertical:SetChecked(BuffetLineDB.orientation == "vertical")
	widgets.restock:SetChecked(BuffetLineDB.restock and BuffetLineDB.restock.enabled and true or false)
	BuffetLine.Print(string.format(
		"Options refresh pre food=%s drink=%s foodShown=%s foodFocus=%s",
		tostring(widgets.food:GetText()),
		tostring(widgets.drink:GetText()),
		widgets.food:IsShown() and "true" or "false",
		widgets.food:HasFocus() and "true" or "false"))
	widgets.food:SetText(DisplayNumber(BuffetLineDB.restock and BuffetLineDB.restock.food))
	widgets.drink:SetText(DisplayNumber(BuffetLineDB.restock and BuffetLineDB.restock.drink))
	BuffetLine.Print(string.format(
		"Options refresh post food=%s drink=%s",
		tostring(widgets.food:GetText()),
		tostring(widgets.drink:GetText())))
	refreshing = false
end

function BuffetLine.SetLocked(value)
	BuffetLineDB.locked = value and true or false
	if BuffetLine.ApplyWidgetConfig then
		BuffetLine.ApplyWidgetConfig()
	end
	BuffetLine.RefreshOptions()
end

function BuffetLine.SetOrientation(value)
	if value == "vertical" then
		BuffetLineDB.orientation = "vertical"
	elseif value == "horizontal" then
		BuffetLineDB.orientation = "horizontal"
	else
		BuffetLineDB.orientation = value and "vertical" or "horizontal"
	end
	if BuffetLine.ApplyWidgetLayout then
		BuffetLine.ApplyWidgetLayout()
	end
	BuffetLine.RefreshOptions()
end

function BuffetLine.SetRestockEnabled(value)
	BuffetLineDB.restock.enabled = value and true or false
	BuffetLine.RefreshOptions()
	if BuffetLineDB.restock.enabled then
		BuffetLine.Print("Auto-restock enabled.")
	else
		BuffetLine.Print("Auto-restock disabled.")
	end
end

function BuffetLine.SetRestockTarget(kind, value)
	local target = BuffetLine.SanitizeTarget(value)
	if not target then
		return false
	end
	BuffetLineDB.restock[kind] = target
	BuffetLine.RefreshOptions()
	return true
end

function BuffetLine.BuildOptions()
	panel = CreateFrame("Frame", "BuffetLineOptionsPanel", UIParent)
	panel.name = "BuffetLine"
	panel.refresh = BuffetLine.RefreshOptions
	if InterfaceOptions_AddCategory then
		InterfaceOptions_AddCategory(panel)
	end
	BuffetLine.OptionsPanel = panel

	widgets = {}
	widgets.lock = MakeCheck(panel, "BuffetLineOptLock", -16, "Lock widget position", function()
		return BuffetLineDB.locked
	end, BuffetLine.SetLocked)

	widgets.vertical = MakeCheck(panel, "BuffetLineOptVertical", -42, "Vertical layout", function()
		return BuffetLineDB.orientation == "vertical"
	end, BuffetLine.SetOrientation)

	widgets.restock = MakeCheck(panel, "BuffetLineOptRestock", -68, "Auto-restock Food and Drink at vendors", function()
		return BuffetLineDB.restock.enabled
	end, BuffetLine.SetRestockEnabled)

	widgets.food = MakeNumberBox(panel, "BuffetLineOptFood", -102, "Food restock target:", "Food", "food", function()
		return BuffetLineDB.restock.food
	end, function(value)
		BuffetLine.SetRestockTarget("food", value)
	end)

	widgets.drink = MakeNumberBox(panel, "BuffetLineOptDrink", -128, "Drink restock target:", "Drink", "drink", function()
		return BuffetLineDB.restock.drink
	end, function(value)
		BuffetLine.SetRestockTarget("drink", value)
	end)

	panel:SetScript("OnHide", function()
		if not widgets then
			return
		end
		if widgets.food and widgets.food.commit then
			widgets.food:commit()
		end
		if widgets.drink and widgets.drink.commit then
			widgets.drink:commit()
		end
	end)

	local reset = CreateFrame("Button", "BuffetLineOptReset", panel, "UIPanelButtonTemplate")
	reset:SetSize(130, 22)
	reset:SetText("Reset position")
	reset:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -158)
	reset:SetScript("OnClick", function()
		BuffetLineDB.position = nil
		if BuffetLine.ApplyWidgetPosition then
			BuffetLine.ApplyWidgetPosition()
		end
		BuffetLine.RefreshOptions()
	end)

	local note1 = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	note1:SetPoint("TOPLEFT", panel, "TOPLEFT", 22, -196)
	note1:SetText("Restock only buys normal Food and Drink.")

	local note2 = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	note2:SetPoint("TOPLEFT", panel, "TOPLEFT", 22, -214)
	note2:SetText("Conjured mage food/water is never purchased.")

	local note3 = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	note3:SetPoint("TOPLEFT", panel, "TOPLEFT", 22, -240)
	note3:SetText("Also configurable with /buffetline commands.")

	panel:SetScript("OnShow", function()
		if not widgets then
			return
		end
		-- Match the known-good Poisonkeeper pattern (panel.refresh AND OnShow
		-- both repaint): always SetText while the panel is actually visible, so
		-- values that were written while hidden (BuildOptions at ADDON_LOADED)
		-- are re-rendered on screen instead of staying invisible until focus.
		BuffetLine.RefreshOptions()
		BuffetLine.Print(string.format(
			"Options shown food=%s drink=%s dbFood=%s dbDrink=%s enabled=%s locked=%s orientation=%s",
			widgets.food:GetText(), widgets.drink:GetText(),
			BuffetLineDB.restock.food, BuffetLineDB.restock.drink,
			BuffetLineDB.restock.enabled and "true" or "false",
			BuffetLineDB.locked and "true" or "false",
			BuffetLineDB.orientation))
	end)
end

SLASH_BUFFETLINE1 = "/buffetline"
SLASH_BUFFETLINE2 = "/bf"
SlashCmdList.BUFFETLINE = function(msg)
	local arg = strlower(strtrim(msg or ""))
	local db = BuffetLineDB

	if arg == "" then
		OpenOptionsPanel()
	elseif arg == "lock" or arg == "locked" then
		BuffetLine.SetLocked(true)
		BuffetLine.Print("Widget locked.")
	elseif arg == "unlock" then
		BuffetLine.SetLocked(false)
		BuffetLine.Print("Widget unlocked.")
	elseif arg == "horizontal" or arg == "h" then
		BuffetLine.SetOrientation("horizontal")
		BuffetLine.Print("Layout set to horizontal.")
	elseif arg == "vertical" or arg == "v" then
		BuffetLine.SetOrientation("vertical")
		BuffetLine.Print("Layout set to vertical.")
	elseif arg == "reset" then
		db.position = nil
		if BuffetLine.ApplyWidgetPosition then
			BuffetLine.ApplyWidgetPosition()
		end
		BuffetLine.Print("Position reset.")
	elseif arg == "restock" then
		BuffetLine.SetRestockEnabled(not db.restock.enabled)
	elseif strmatch(arg, "^restock%s+[01]$") then
		BuffetLine.SetRestockEnabled(tonumber(strmatch(arg, "%d+")) == 1)
	elseif strmatch(arg, "^food%s+%d+$") then
		local ok = BuffetLine.SetRestockTarget("food", tonumber(strmatch(arg, "%d+")))
		if ok then
			BuffetLine.Print("Food restock target set to " .. db.restock.food .. ".")
		else
			BuffetLine.Print("Food restock target must be an integer from 0 through 1000.")
		end
	elseif strmatch(arg, "^drink%s+%d+$") then
		local ok = BuffetLine.SetRestockTarget("drink", tonumber(strmatch(arg, "%d+")))
		if ok then
			BuffetLine.Print("Drink restock target set to " .. db.restock.drink .. ".")
		else
			BuffetLine.Print("Drink restock target must be an integer from 0 through 1000.")
		end
	else
		BuffetLine.Print("Usage: /buffetline [lock|unlock|horizontal|vertical|restock [0|1]|food N|drink N|reset]")
	end
end