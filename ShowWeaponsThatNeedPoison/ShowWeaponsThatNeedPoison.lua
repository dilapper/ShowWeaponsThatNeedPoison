-- ShowWeaponsThatNeedPoison: shows your main-hand / off-hand weapon icons;
-- whichever has no poison (temporary weapon enchant) applied glows until you
-- reapply.

local ADDON = ...

local SLOTS = { MH = 16, OH = 17 }
local DEFAULTS = {
    locked = false,
    size = 48,
    onlyRogue = true,
    points = {
        MH = { "CENTER", "CENTER", -30, -150 },
        OH = { "CENTER", "CENTER", 30, -150 },
    },
}

local db
local icons = {}
local lockButton

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

local function layout()
    for _, f in pairs(icons) do
        f:SetSize(db.size, db.size)
        f.glow:SetSize(db.size * 1.9, db.size * 1.9)
        local p = db.points[f.key]
        f:ClearAllPoints()
        f:SetPoint(p[1], UIParent, p[2], p[3], p[4])
        f:EnableMouse(not db.locked)
    end
    if lockButton then lockButton:SetShown(not db.locked) end
end

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------

local function isWeapon(slot)
    local id = GetInventoryItemID("player", slot)
    if not id then return false end
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

        if tex and isWeapon(slot) and not st.has then
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
    b:SetPoint("TOP", icons.MH, "BOTTOM", 30, -20)
    b:SetScript("OnClick", function()
        db.locked = true
        layout() update()
        say("locked. Use /swp unlock to move again.")
    end)
    return b
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON then return end
        ShowWeaponsThatNeedPoisonDB = ShowWeaponsThatNeedPoisonDB or {}
        db = ShowWeaponsThatNeedPoisonDB
        copyDefaults(DEFAULTS, db)

        icons.MH = createIcon("MH", "Main hand")
        icons.OH = createIcon("OH", "Off hand")
        lockButton = createLockButton()
        layout()

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
    elseif cmd == "size" then
        local n = tonumber(arg)
        if n and n >= 16 and n <= 200 then
            db.size = n layout()
        else
            say("usage: /swp size 16-200")
        end
    elseif cmd == "reset" then
        db.points = CopyTable(DEFAULTS.points)
        layout() say("positions reset.")
    elseif cmd == "all" then
        db.onlyRogue = not db.onlyRogue update()
        say(db.onlyRogue and "only active on Rogues." or "active on all classes (for testing).")
    else
        say("/swp unlock | lock | size <n> | reset | all")
    end
end
