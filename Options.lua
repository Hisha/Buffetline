local _, BuffetLine = ...

local panel
local widgets
local targets = {}
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

-- Commit one target EditBox. Only a user edit (box.dirty) commits; a
-- programmatic refresh/repaint never does. Valid 0..1000 integers are stored;
-- anything else is rejected, the box is repainted from the stored value, and a
-- message is printed so invalid input never reaches SavedVariables.
local function CommitNumberBox(box, getter, setter)
	if refreshing or not BuffetLineCharDB or not box.dirty then
		return
	end
	box.dirty = false
	local value = BuffetLine.SanitizeTarget(box:GetText())
	if not value then
		box:SetText(tostring(getter()))
		BuffetLine.Print(string.format(
			"%s restock target must be an integer from 0 through 1000.",
			box.commitLabel))
		return
	end
	setter(value)
end

local function MakeNumberBox(parent, frameName, y, labelText, commitLabel, kind, getter, setter)
	local label = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	label:SetPoint("TOPLEFT", parent, "TOPLEFT", 22, y - 5)
	label:SetText(labelText)
	local box = CreateFrame("EditBox", frameName, parent, "InputBoxTemplate")
	box.kind = kind
	box.commitLabel = commitLabel
	box:SetPoint("TOPLEFT", parent, "TOPLEFT", 230, y)
	box:SetWidth(44)
	box:SetHeight(22)
	box:SetAutoFocus(false)
	box:SetScript("OnTextChanged", function(self, userInput)
		if userInput and not refreshing then self.dirty = true end
	end)
	box:SetScript("OnEnterPressed", function(self)
		CommitNumberBox(self, getter, setter)
		self:ClearFocus()
	end)
	box:SetScript("OnEditFocusLost", function(self)
		CommitNumberBox(self, getter, setter)
		self:HighlightText(0, 0)
	end)
	box:SetScript("OnEscapePressed", function(self)
		self.dirty = false
		if BuffetLineCharDB then self:SetText(tostring(getter())) end
		self:ClearFocus()
	end)
	box.commit = function(self)
		CommitNumberBox(self, getter, setter)
	end
	targets[#targets + 1] = box
	return box
end

function BuffetLine.RefreshOptions()
    if refreshing or not widgets or not BuffetLineDB or not BuffetLineCharDB then return end
    refreshing = true

    widgets.lock:SetChecked(BuffetLineDB.locked and true or false)
    widgets.vertical:SetChecked(BuffetLineDB.orientation == "vertical")
    widgets.restock:SetChecked(BuffetLineCharDB.restock.enabled and true or false)

    for _, box in ipairs(targets) do
        box.dirty = false
        box:SetText(tostring(BuffetLineCharDB.restock[box.kind]))
        box:ClearFocus()
    end

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
	BuffetLineCharDB.restock.enabled = value and true or false
	BuffetLine.RefreshOptions()
	if BuffetLineCharDB.restock.enabled then
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
	BuffetLineCharDB.restock[kind] = target
	BuffetLine.RefreshOptions()
	return true
end

function BuffetLine.BuildOptions()
	panel = CreateFrame("Frame", "BuffetLineOptionsPanel", UIParent)
	panel.name = "BuffetLine"
	panel:Hide()
	panel.refresh = BuffetLine.RefreshOptions
	if InterfaceOptions_AddCategory then
		InterfaceOptions_AddCategory(panel)
	end
	BuffetLine.OptionsPanel = panel

	widgets = {}
	targets = {}
	widgets.lock = MakeCheck(panel, "BuffetLineOptLock", -16, "Lock widget position", function()
		return BuffetLineDB.locked
	end, BuffetLine.SetLocked)

	widgets.vertical = MakeCheck(panel, "BuffetLineOptVertical", -42, "Vertical layout", function()
		return BuffetLineDB.orientation == "vertical"
	end, BuffetLine.SetOrientation)

	widgets.restock = MakeCheck(panel, "BuffetLineOptRestock", -68, "Auto-restock Food and Drink at vendors", function()
		return BuffetLineCharDB.restock.enabled
	end, BuffetLine.SetRestockEnabled)

	widgets.food = MakeNumberBox(panel, "BuffetLineOptFood", -102, "Food restock target:", "Food", "food", function()
		return BuffetLineCharDB.restock.food
	end, function(value)
		BuffetLine.SetRestockTarget("food", value)
	end)

	widgets.drink = MakeNumberBox(panel, "BuffetLineOptDrink", -128, "Drink restock target:", "Drink", "drink", function()
		return BuffetLineCharDB.restock.drink
	end, function(value)
		BuffetLine.SetRestockTarget("drink", value)
	end)

	panel:SetScript("OnHide", function()
		for _, box in ipairs(targets) do
			box:commit()
			box:ClearFocus()
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

	panel:SetScript("OnShow", BuffetLine.RefreshOptions)
end

SLASH_BUFFETLINE1 = "/buffetline"
SLASH_BUFFETLINE2 = "/bf"
SlashCmdList.BUFFETLINE = function(msg)
	local arg = strlower(strtrim(msg or ""))
	local db = BuffetLineDB
	local charDB = BuffetLineCharDB

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
		BuffetLine.SetRestockEnabled(not charDB.restock.enabled)
	elseif strmatch(arg, "^restock%s+[01]$") then
		BuffetLine.SetRestockEnabled(tonumber(strmatch(arg, "%d+")) == 1)
	elseif strmatch(arg, "^food%s+%d+$") then
		local ok = BuffetLine.SetRestockTarget("food", tonumber(strmatch(arg, "%d+")))
		if ok then
			BuffetLine.Print("Food restock target set to " .. charDB.restock.food .. ".")
		else
			BuffetLine.Print("Food restock target must be an integer from 0 through 1000.")
		end
	elseif strmatch(arg, "^drink%s+%d+$") then
		local ok = BuffetLine.SetRestockTarget("drink", tonumber(strmatch(arg, "%d+")))
		if ok then
			BuffetLine.Print("Drink restock target set to " .. charDB.restock.drink .. ".")
		else
			BuffetLine.Print("Drink restock target must be an integer from 0 through 1000.")
		end
	else
		BuffetLine.Print("Usage: /buffetline [lock|unlock|horizontal|vertical|restock [0|1]|food N|drink N|reset]")
	end
end