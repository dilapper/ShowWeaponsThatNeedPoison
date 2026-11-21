-- ShowWeaponsThatNeedPoison: shows your main-hand / off-hand weapon icons;
-- whichever has no poison (temporary weapon enchant) applied glows until you
-- reapply.

local ADDON = ...

local SLOTS = { MH = 16, OH = 17 }
local BASE_SIZE = 48 -- icon size in pixels at 100% scale
local DEFAULTS = {
    locked = false,
    scale = 100, -- percent, 0-200
    onlyRogue = true,
    layoutVersion = 3,
    points = {
        MH = { "CENTER", "CENTER", -40, -150 },
        OH = { "CENTER", "CENTER", 40, -150 },
    },
}

-- Session-only (not saved): force both icons to show, glowing, regardless of
-- equipped weapons or poisons. Handy for testing on a low-level character.
local testMode = false

local GetItemInfoInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant

local db
local icons = {}
local lockButton
local optionsRefresh, createOptionsPanel, openOptions -- defined in the options section

local function copyDefaults(src, dst)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            copyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

local function say(msg) print("|cff33ff99ShowWeaponsThatNeedPoison:|r " .. msg) end

---------------------------------------------------------------------------
-- Icon frames
---------------------------------------------------------------------------

local function pulseAnim(region, lowAlpha)
    local ag = region:CreateAnimationGroup()
    ag:SetLooping("BOUNCE")
    local a = ag:CreateAnimation("Alpha")
    a:SetFromAlpha(1)
    a:SetToAlpha(lowAlpha)
    a:SetDuration(0.5)
    return ag
end

local function createIcon(key, label)
    local f = CreateFrame("Frame", "ShowWeaponsThatNeedPoison" .. key, UIParent)
    f.key = key
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")

    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetAllPoints()
    f.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    -- Glow: pulsing additive border around the icon.
    f.glow = f:CreateTexture(nil, "OVERLAY")
    f.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    f.glow:SetBlendMode("ADD")
    f.glow:SetPoint("CENTER")
    f.glow:SetVertexColor(0.4, 1, 0.2)
    f.glow:Hide()
    f.glowAnim = pulseAnim(f.glow, 0.25)

    -- Shine: soft inner flash pulsing with the border.
    f.shine = f:CreateTexture(nil, "OVERLAY")
    f.shine:SetAllPoints()
    f.shine:SetColorTexture(0.5, 1, 0.3, 0.3)
    f.shine:SetBlendMode("ADD")
    f.shine:Hide()
    f.shineAnim = pulseAnim(f.shine, 0.1)

    -- Remaining time of the current poison.
    f.time = f:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    f.time:SetPoint("BOTTOM", 0, 2)

    -- Label shown while unlocked.
    f.label = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.label:SetPoint("BOTTOM", f, "TOP", 0, 2)
    f.label:SetText(label)
    f.label:Hide()

    f:SetScript("OnDragStart", function(self)
        if not db.locked then self:StartMoving() end
    end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint(1)
        db.points[self.key] = { point, relPoint, x, y }
    end)

    return f
end

local function setGlow(f, on)
    if on then
        if not f.glow:IsShown() then
            f.glow:Show() f.shine:Show()
            f.glowAnim:Play() f.shineAnim:Play()
        end
    elseif f.glow:IsShown() then
        f.glowAnim:Stop() f.shineAnim:Stop()
        f.glow:Hide() f.shine:Hide()
    end
end

-- Slider says 0-200%; the game rejects a scale of exactly 0, so 0% is clamped
-- to 1% (effectively invisible).
local function effectiveScale()
    return math.max(db.scale, 1) / 100
end

local function layout()
    for _, f in pairs(icons) do
        f:SetSize(BASE_SIZE, BASE_SIZE)
        f.glow:SetSize(BASE_SIZE * 1.9, BASE_SIZE * 1.9)
        f:SetScale(effectiveScale())
        local p = db.points[f.key]
        f:ClearAllPoints()
        f:SetPoint(p[1], UIParent, p[2], p[3], p[4])
        f:EnableMouse(not db.locked)
    end
    if lockButton then lockButton:SetShown(not db.locked) end
end

-- Changes scale while keeping each icon's centre where it is on screen.
local function setScale(pct)
    pct = math.max(0, math.min(200, math.floor(pct + 0.5)))
    if db.scale == pct then return end
    for _, f in pairs(icons) do
        local x, y = f:GetCenter()
        if x then
            local oldScale = f:GetScale()
            f:SetScale(math.max(pct, 1) / 100)
            local newScale = f:GetScale()
            x, y = x * oldScale / newScale, y * oldScale / newScale
            db.points[f.key] = { "CENTER", "BOTTOMLEFT", x, y }
        end
    end
    db.scale = pct
    layout()
end

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------

local function isWeapon(slot)
    local id = GetInventoryItemID("player", slot)
    if not id then return false end
    if not GetItemInfoInstant then return true end
    local _, _, _, _, _, classID = GetItemInfoInstant(id)
    return classID == 2 -- weapon (not shield / held-in-off-hand)
end

local function update()
    if not db then return end
    if db.onlyRogue and select(2, UnitClass("player")) ~= "ROGUE" then
        for _, f in pairs(icons) do f:Hide() end
        if lockButton then lockButton:Hide() end
        return
    end

    local hasMH, mhExp, _, _, hasOH, ohExp = GetWeaponEnchantInfo()
    local info = {
        MH = { has = hasMH, exp = mhExp },
        OH = { has = hasOH, exp = ohExp },
    }

    for key, f in pairs(icons) do
        local slot = SLOTS[key]
        local tex = GetInventoryItemTexture("player", slot)
        local st = info[key]
        f.label:SetShown(not db.locked)

        if testMode then
            f:Show()
            f.icon:SetTexture(tex or "Interface\\Icons\\Ability_Poisons")
            f.icon:SetDesaturated(false)
            f.icon:SetAlpha(1)
            f.time:SetText("")
            setGlow(f, true)
        elseif tex and isWeapon(slot) and not st.has then
            -- Weapon with no poison: show it glowing.
            f:Show()
            f.icon:SetTexture(tex)
            f.icon:SetDesaturated(false)
            f.icon:SetAlpha(1)
            f.time:SetText("")
            setGlow(f, true)
        elseif not db.locked then
            -- Unlocked: keep a dimmed placeholder visible (even if poisoned
            -- or no weapon) so the icon can be positioned.
            f:Show()
            f.icon:SetTexture(tex or "Interface\\Icons\\Ability_Poisons")
            f.icon:SetDesaturated(true)
            f.icon:SetAlpha(0.5)
            f.time:SetText("")
            setGlow(f, false)
        else
            f:Hide()
            setGlow(f, false)
        end
    end
end

---------------------------------------------------------------------------
-- Setup, events, slash commands
---------------------------------------------------------------------------

local function createLockButton()
    local b = CreateFrame("Button", "ShowWeaponsThatNeedPoisonLockButton", UIParent, "UIPanelButtonTemplate")
    b:SetSize(120, 24)
    b:SetText("Lock position")
    b:SetPoint("TOP", icons.MH, "BOTTOM", 40, -20)
    b:SetScript("OnClick", function()
        db.locked = true
        layout() update()
        say("locked. Use /swp unlock to move again.")
    end)
    return b
end

---------------------------------------------------------------------------
-- Options panel (Esc > Options > AddOns)
---------------------------------------------------------------------------

local PANEL_NAME = "ShowWeaponsThatNeedPoison"
local optionsCategory

function optionsRefresh() end -- replaced once the panel exists

function createOptionsPanel()
    local panel = CreateFrame("Frame")
    panel.name = PANEL_NAME

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(PANEL_NAME)

    local slider = CreateFrame("Slider", "ShowWeaponsThatNeedPoisonScaleSlider", panel, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 4, -40)
    slider:SetWidth(260)
    slider:SetMinMaxValues(0, 200)
    slider:SetValueStep(1)
    if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
    _G[slider:GetName() .. "Low"]:SetText("0%")
    _G[slider:GetName() .. "High"]:SetText("200%")
    local sliderText = _G[slider:GetName() .. "Text"]

    local refreshing = false
    slider:SetScript("OnValueChanged", function(_, value)
        if refreshing then return end
        setScale(value)
        sliderText:SetText("Icon scale: " .. db.scale .. "%")
    end)

    local lock = CreateFrame("CheckButton", "ShowWeaponsThatNeedPoisonLockCheck", panel, "UICheckButtonTemplate")
    lock:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", -4, -30)
    _G[lock:GetName() .. "Text"]:SetText("Lock icon positions")
    lock:SetScript("OnClick", function(self)
        db.locked = self:GetChecked() and true or false
        layout() update()
    end)

    local reset = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    reset:SetSize(160, 24)
    reset:SetText("Reset position and scale")
    reset:SetPoint("TOPLEFT", lock, "BOTTOMLEFT", 4, -16)
    reset:SetScript("OnClick", function()
        db.points = CopyTable(DEFAULTS.points)
        db.scale = DEFAULTS.scale
        layout() optionsRefresh()
    end)

    function optionsRefresh()
        refreshing = true
        slider:SetValue(db.scale)
        refreshing = false
        sliderText:SetText("Icon scale: " .. db.scale .. "%")
        lock:SetChecked(db.locked)
    end
    panel:SetScript("OnShow", optionsRefresh)

    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        optionsCategory = Settings.RegisterCanvasLayoutCategory(panel, PANEL_NAME)
        Settings.RegisterAddOnCategory(optionsCategory)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
        optionsCategory = panel
    end
end

function openOptions()
    if Settings and Settings.OpenToCategory and optionsCategory and optionsCategory.GetID then
        Settings.OpenToCategory(optionsCategory:GetID())
    elseif InterfaceOptionsFrame_OpenToCategory and optionsCategory then
        InterfaceOptionsFrame_OpenToCategory(optionsCategory)
        InterfaceOptionsFrame_OpenToCategory(optionsCategory) -- first call can miss
    else
        say("open Esc > Options > AddOns > " .. PANEL_NAME)
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON then return end
        ShowWeaponsThatNeedPoisonDB = ShowWeaponsThatNeedPoisonDB or {}
        db = ShowWeaponsThatNeedPoisonDB
        local version = db.layoutVersion or 1
        -- v1.0.0 defaults overlapped the two icons; reset saved positions once.
        if version < 2 then db.points = nil end
        -- v3: pixel size replaced by a percentage scale.
        if version < 3 then
            if type(db.size) == "number" and not db.scale then
                db.scale = math.max(0, math.min(200, math.floor(db.size / BASE_SIZE * 100 + 0.5)))
            end
            db.size = nil
        end
        db.layoutVersion = DEFAULTS.layoutVersion
        copyDefaults(DEFAULTS, db)

        icons.MH = createIcon("MH", "Main hand")
        icons.OH = createIcon("OH", "Off hand")
        lockButton = createLockButton()
        layout()
        createOptionsPanel()

        self:UnregisterEvent("ADDON_LOADED")
        self:RegisterEvent("PLAYER_ENTERING_WORLD")
        self:RegisterEvent("UNIT_INVENTORY_CHANGED")
        self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
        -- Enchant expiry fires no event, so poll.
        C_Timer.NewTicker(0.5, update)
    end
    update()
end)

SLASH_SHOWWEAPONSTHATNEEDPOISON1 = "/swp"
SLASH_SHOWWEAPONSTHATNEEDPOISON2 = "/poison"
SlashCmdList.SHOWWEAPONSTHATNEEDPOISON = function(msg)
    if not db then return end
    local cmd, arg = msg:match("^(%S*)%s*(.-)$")
    cmd = cmd:lower()
    if cmd == "lock" then
        db.locked = true layout() update() say("locked.")
    elseif cmd == "unlock" then
        db.locked = false layout() update() say("unlocked - drag the icons, then click Lock.")
    elseif cmd == "scale" then
        local n = tonumber(arg)
        if n and n >= 0 and n <= 200 then
            setScale(n)
            if optionsRefresh then optionsRefresh() end
            say("scale " .. db.scale .. "%")
        else
            say("usage: /swp scale 0-200 (100 = default)")
        end
    elseif cmd == "options" or cmd == "config" then
        openOptions()
    elseif cmd == "reset" then
        db.points = CopyTable(DEFAULTS.points)
        layout() say("positions reset.")
    elseif cmd == "test" then
        testMode = not testMode update()
        say(testMode and "test mode ON - both icons forced visible (resets on reload)." or "test mode off.")
    elseif cmd == "status" then
        local mh, mhExp, _, _, oh, ohExp = GetWeaponEnchantInfo()
        say(("class=%s locked=%s MH tex=%s OH tex=%s"):format(select(2, UnitClass("player")), tostring(db.locked),
            tostring(GetInventoryItemTexture("player", 16)), tostring(GetInventoryItemTexture("player", 17))))
        say(("enchant MH=%s(%s) OH=%s(%s)"):format(tostring(mh), tostring(mhExp), tostring(oh), tostring(ohExp)))
    elseif cmd == "all" then
        db.onlyRogue = not db.onlyRogue update()
        say(db.onlyRogue and "only active on Rogues." or "active on all classes (for testing).")
    else
        say("/swp options | unlock | lock | scale <0-200> | reset | test | status | all")
    end
end
