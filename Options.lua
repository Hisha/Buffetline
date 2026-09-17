local _, BuffetLine = ...

local panel
local widgets
local menu

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

local function MakeNumberBox(parent, frameName, y, labelText, getter, setter)
	local box = CreateFrame("EditBox", frameName, parent, "InputBoxTemplate")
	box:SetSize(52, 18)
	box:SetAutoFocus(false)
	box:SetMaxLetters(6)
	box:SetNumeric(true)
	local label = box:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	label:SetPoint("RIGHT", box, "LEFT", -4, 4)
	label:SetText(labelText)
	box:SetPoint("LEFT", parent, "LEFT", 230, y)
	box:SetText(getter())
	box:SetScript("OnEnterPressed", function(self)
		local value = tonumber(self:GetText())
		if value and value >= 0 then
			setter(value)
		else
			self:SetText(getter())
		end
		self:ClearFocus()
	end)
	box:SetScript("OnEscapePressed", function(self)
		self:SetText(getter())
		self:ClearFocus()
	end)
	return box
end

function BuffetLine.RefreshOptions()
	if not widgets then
		return
	end
	widgets.lock:SetChecked(BuffetLineDB.locked)
	widgets.vertical:SetChecked(BuffetLineDB.orientation == "vertical")
	widgets.restock:SetChecked(BuffetLineDB.restock.enabled)
	widgets.food:SetText(BuffetLineDB.restock.food)
	widgets.drink:SetText(BuffetLineDB.restock.drink)
end

function BuffetLine.SetLocked(value)
	BuffetLineDB.locked = value and true or false
	if BuffetLine.ApplyWidgetConfig then
		BuffetLine.ApplyWidgetConfig()
	end
	BuffetLine.RefreshOptions()
end

function BuffetLine.SetOrientation(value)
	BuffetLineDB.orientation = (value == "vertical") and "vertical" or "horizontal"
	if BuffetLine.ApplyWidgetConfig then
		BuffetLine.ApplyWidgetConfig()
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
	BuffetLineDB.restock[kind] = (value and value >= 0 and value) or 0
	BuffetLine.RefreshOptions()
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

	widgets.food = MakeNumberBox(panel, "BuffetLineOptFood", -102, "Food restock target:", function()
		return BuffetLineDB.restock.food
	end, function(value)
		BuffetLine.SetRestockTarget("food", value)
	end)

	widgets.drink = MakeNumberBox(panel, "BuffetLineOptDrink", -128, "Drink restock target:", function()
		return BuffetLineDB.restock.drink
	end, function(value)
		BuffetLine.SetRestockTarget("drink", value)
	end)

	local reset = CreateFrame("Button", "BuffetLineOptReset", panel, "UIPanelButtonTemplate")
	reset:SetSize(130, 22)
	reset:SetText("Reset position")
	reset:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -158)
	reset:SetScript("OnClick", function()
		BuffetLineDB.position = nil
		if BuffetLine.ApplyWidgetConfig then
			BuffetLine.ApplyWidgetConfig()
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

	menu = CreateFrame("Frame", "BuffetLineContextMenu", UIParent, "UIDropDownMenuTemplate")
	UIDropDownMenu_Initialize(menu, function(self, level)
		local info = UIDropDownMenu_CreateInfo()

		info.text = "Lock widget"
		info.checked = BuffetLineDB.locked
		info.func = function()
			BuffetLine.SetLocked(not BuffetLineDB.locked)
			CloseDropDownMenus()
		end
		UIDropDownMenu_AddButton(info, level)

		info.text = "Vertical layout"
		info.checked = BuffetLineDB.orientation == "vertical"
		info.func = function()
			BuffetLine.SetOrientation((BuffetLineDB.orientation == "vertical") and "horizontal" or "vertical")
			CloseDropDownMenus()
		end
		UIDropDownMenu_AddButton(info, level)

		info.text = "Auto-restock Food and Drink"
		info.checked = BuffetLineDB.restock.enabled
		info.func = function()
			BuffetLine.SetRestockEnabled(not BuffetLineDB.restock.enabled)
			CloseDropDownMenus()
		end
		UIDropDownMenu_AddButton(info, level)

		info.text = "Options..."
		info.checked = nil
		info.func = function()
			CloseDropDownMenus()
			OpenOptionsPanel()
		end
		UIDropDownMenu_AddButton(info, level)

		info.text = "Reset position"
		info.checked = nil
		info.func = function()
			BuffetLineDB.position = nil
			if BuffetLine.ApplyWidgetConfig then
				BuffetLine.ApplyWidgetConfig()
			end
			CloseDropDownMenus()
		end
		UIDropDownMenu_AddButton(info, level)
	end, "MENU")
end

function BuffetLine.ToggleMenu()
	local x, y = GetCursorPosition()
	ToggleDropDownMenu(1, nil, menu, x, y)
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
		if BuffetLine.ApplyWidgetConfig then
			BuffetLine.ApplyWidgetConfig()
		end
		BuffetLine.Print("Position reset.")
	elseif arg == "restock" then
		BuffetLine.SetRestockEnabled(not db.restock.enabled)
	elseif strmatch(arg, "^restock%s+[01]$") then
		BuffetLine.SetRestockEnabled(tonumber(strmatch(arg, "%d+")) == 1)
	elseif strmatch(arg, "^food%s+%d+$") then
		BuffetLine.SetRestockTarget("food", tonumber(strmatch(arg, "%d+")))
		BuffetLine.Print("Food restock target set to " .. db.restock.food .. ".")
	elseif strmatch(arg, "^drink%s+%d+$") then
		BuffetLine.SetRestockTarget("drink", tonumber(strmatch(arg, "%d+")))
		BuffetLine.Print("Drink restock target set to " .. db.restock.drink .. ".")
	else
		BuffetLine.Print("Usage: /buffetline [lock|unlock|horizontal|vertical|restock [0|1]|food N|drink N|reset]")
	end
end