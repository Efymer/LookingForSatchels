local addonName, addon = ...

addon.UI = addon.UI or {}

local ROLES = {
    { key = "tank",   role = "TANK",    label = "Tank"   },
    { key = "heal",   role = "HEALER",  label = "Heal"   },
    { key = "damage", role = "DAMAGER", label = "Damage" },
}

local POPUP_MIN_WIDTH = 166

local popupFrame
local lfgButtons = {}

local function applyPanelTextures(b, includeDisabled)
    local function tex(path)
        local t = b:CreateTexture()
        t:SetTexture(path)
        t:SetTexCoord(0, 0.625, 0, 0.6875)
        t:SetAllPoints()
        return t
    end
    b:SetNormalTexture   (tex("Interface/Buttons/UI-Panel-Button-Up"))
    b:SetHighlightTexture(tex("Interface/Buttons/UI-Panel-Button-Highlight"))
    b:SetPushedTexture   (tex("Interface/Buttons/UI-Panel-Button-Down"))
    if includeDisabled then
        b:SetDisabledTexture(tex("Interface/Buttons/UI-Panel-Button-Disabled"))
    end
end

local function newSecureButton(parent, posSelf, posRelativeTo, posRelative, ox, oy, w, h, text)
    local b = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate")
    b:SetPoint(posSelf, posRelativeTo, posRelative, ox, oy)
    b:SetFrameStrata("DIALOG")
    b:SetSize(w, h)
    b:RegisterForClicks("LeftButtonUp", "LeftButtonDown")
    b:SetText(text)
    b:SetNormalFontObject("GameFontNormal")
    b:SetDisabledFontObject("GameFontDisable")
    applyPanelTextures(b, true)
    return b
end

-- -------- L+ buttons on the LFG frames --------

local function buildLFGButton(index, anchorName, lfgCategory, dungeonIdSource)
    local anchor = _G[anchorName]
    if not anchor then return nil end

    local b = CreateFrame("Button", "LFS_LFGSearchButton" .. index, anchor)
    b:SetPoint("LEFT", _G[anchorName .. "Name"], "LEFT", 4, 0)
    b:SetFrameStrata("DIALOG")
    b:SetSize(30, 22)
    b.lfgCategory = lfgCategory
    b.dungeonIdSource = dungeonIdSource
    b.dungeonID = 0
    b.status = 0

    applyPanelTextures(b, false)
    b:SetNormalFontObject("GameFontNormal")

    b.dungeonRoleCheckboxes = {}
    for j, r in ipairs(ROLES) do
        local rb = CreateFrame("CheckButton", b:GetName() .. "Role" .. j, b, "ChatConfigCheckButtonTemplate")
        rb:SetPoint("LEFT", b, "RIGHT", 22 * (j - 1), 0)
        _G[rb:GetName() .. "Text"]:SetText("")
        rb.role = r.role
        rb.tag  = j

        local roleTex = rb:CreateTexture()
        roleTex:SetAtlas(GetIconForRole(r.role))
        roleTex:SetPoint("TOPLEFT", rb, "TOPLEFT", 4, -4)
        roleTex:SetPoint("BOTTOMRIGHT", rb, "BOTTOMRIGHT", -4, 4)
        roleTex:SetDrawLayer("BORDER", -1)

        rb:SetHitRectInsets(0, 0, 0, 0)

        rb:SetScript("OnClick", function(self)
            local entry = addon.db.LFG_dungeonIDs[b.dungeonID]
            if not entry then return end
            local dr = entry.dungeonRoles
            if not dr then
                if self:GetChecked() then
                    dr = { 0, 0, 0 }
                    dr[self.tag] = 1
                    entry.dungeonRoles = dr
                end
            else
                dr[self.tag] = self:GetChecked() and 1 or 0
                local any = false
                for _, val in ipairs(dr) do if val == 1 then any = true break end end
                if not any then entry.dungeonRoles = nil end
            end
        end)
        rb:Hide()
        b.dungeonRoleCheckboxes[j] = rb
    end

    function b:UpdateStatus()
        local entry = addon.db.LFG_dungeonIDs[self.dungeonID]
        self.status = entry and entry.status or 0
        self:UpdateText()
    end

    function b:UpdateText()
        if self.status == 0 then
            self:SetText("L+")
            for _, rb in ipairs(self.dungeonRoleCheckboxes) do rb:Hide() end
        else
            self:SetText("L-")
            local entry = addon.db.LFG_dungeonIDs[self.dungeonID]
            local dr = entry and entry.dungeonRoles
            for _, rb in ipairs(self.dungeonRoleCheckboxes) do
                rb:Show()
                rb:SetChecked(dr and (dr[rb.tag] == 1))
            end
        end
    end

    b:SetScript("OnClick", function(self)
        if IsShiftKeyDown() then
            if self.lfgCategory == "RaidFinder" then
                for i = 1, GetNumRFDungeons() do
                    local id = GetRFDungeonInfo(i)
                    if IsLFGDungeonJoinable(id) then
                        addon:AddWatch(id, self.lfgCategory)
                    end
                end
            end
        elseif IsControlKeyDown() then
            if self.lfgCategory == "RaidFinder" then
                local toRemove = {}
                for id, v in pairs(addon.db.LFG_dungeonIDs) do
                    if v.status and v.status >= 1 and v.lfgCategory == "RaidFinder" then
                        toRemove[#toRemove + 1] = id
                    end
                end
                for _, id in ipairs(toRemove) do addon:RemoveWatch(id) end
            end
        else
            local selected = self.dungeonIdSource and self.dungeonIdSource[1] and self.dungeonIdSource[1][self.dungeonIdSource[2]]
            if self.status == 0 then
                addon:AddWatch(selected, self.lfgCategory)
            else
                addon:RemoveWatch(selected)
            end
        end
        self:UpdateStatus()
    end)

    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
        GameTooltip:AddLine("|cffaaaaffLFS|r")
        if self.status == 0 then
            GameTooltip:AddLine("|cffffffffClick: Add to watch list|r")
        else
            GameTooltip:AddLine("|cffffffffClick: Remove from watch list|r")
        end
        if self.lfgCategory == "RaidFinder" then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("|cffffffffShift-click: add all RaidFinder wings to watch list|r")
            GameTooltip:AddLine("|cffffffffControl-click: remove all RaidFinder wings from watch list|r")
        end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() if GameTooltip:IsVisible() then GameTooltip:Hide() end end)

    return b
end

local function onLFGRewardsFrameUpdate(_, dungeonID)
    if type(dungeonID) ~= "number" or LFGIsIDHeader(dungeonID) then return end
    for _, b in ipairs(lfgButtons) do
        b.dungeonID = dungeonID
        b:UpdateStatus()
    end
end

-- -------- Popup --------

local function applyPopupAnchor()
    local a = addon.db.popupAnchor
    popupFrame:ClearAllPoints()
    popupFrame:SetPoint(a.point, a.relativeTo, a.relativePoint, a.x, a.y)
end

local function buildPopup()
    popupFrame = CreateFrame("Frame", "LookingForSatchelsPopupFrame", UIParent)
    popupFrame:SetFrameStrata("DIALOG")
    popupFrame:SetSize(POPUP_MIN_WIDTH, 82 + 22)
    popupFrame:EnableMouse(true)
    popupFrame:SetMovable(true)
    popupFrame:RegisterForDrag("LeftButton")
    popupFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    popupFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, rt, rp, x, y = self:GetPoint()
        addon.db.popupAnchor = {
            point         = p  or "CENTER",
            relativeTo    = rt or "UIParent",
            relativePoint = rp or "CENTER",
            x             = x  or 0,
            y             = y  or 0,
        }
    end)

    local bg = popupFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(popupFrame)
    bg:SetColorTexture(0, 0, 0, 0.8)

    popupFrame.text = popupFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    popupFrame.text:SetPoint("TOP", 0, -4)
    popupFrame.text:SetText("Queue?")

    popupFrame.bottomText = popupFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    popupFrame.bottomText:SetPoint("BOTTOM", 0, 2)
    popupFrame.bottomText:SetText("Shift+Click to remove from watchlist")
    popupFrame.bottomText:SetTextColor(0.7, 0.7, 0.7, 1)

    POPUP_MIN_WIDTH = math.max(POPUP_MIN_WIDTH, popupFrame.bottomText:GetStringWidth() + 2)
    popupFrame:SetSize(POPUP_MIN_WIDTH, 82 + 22)

    popupFrame.buttonYES = newSecureButton(popupFrame, "TOPRIGHT", popupFrame, "TOPLEFT",
        POPUP_MIN_WIDTH / 2 - 1, -26 * 2 - 12, 80, 22, "Yes")
    popupFrame.buttonNO  = newSecureButton(popupFrame, "TOPLEFT",  popupFrame, "TOPLEFT",
        POPUP_MIN_WIDTH / 2 + 1, -26 * 2 - 12, 80, 22, "No")

    popupFrame.buttonYES:SetAttribute("type", "macro")
    popupFrame.buttonYES:SetAttribute("macrotext",
        "/run LookingForSatchelsFrame.joinLFG(LookingForSatchelsFrame.__popupDungeonID, LookingForSatchelsFrame.__popupLfgCategory, IsShiftKeyDown())")

    popupFrame.buttonNO:SetAttribute("type", "macro")
    popupFrame.buttonNO:SetAttribute("macrotext",
        "/run LookingForSatchelsFrame.dequeueJoinLFG(LookingForSatchelsFrame.__popupDungeonID, LookingForSatchelsFrame.__popupLfgCategory, IsShiftKeyDown())")

    popupFrame.roleButtonsFrame = CreateFrame("Frame", nil, popupFrame)
    popupFrame.roleButtonsFrame:SetPoint("TOP", popupFrame, "TOP", 0, -41)
    popupFrame.roleButtonsFrame:SetSize(3 * (24 + 22 + 2), 22)

    popupFrame.roleButtons = {}
    for i, r in ipairs(ROLES) do
        local rb = CreateFrame("CheckButton", "LookingForSatchelsRoleCheckButton" .. i, popupFrame.roleButtonsFrame, "ChatConfigCheckButtonTemplate")
        rb:SetPoint("TOPLEFT", popupFrame.roleButtonsFrame, "TOPLEFT", (24 + 22 + 2) * (i - 1), 0)
        _G[rb:GetName() .. "Text"]:SetText("")
        rb.tag  = i
        rb.role = r.role

        local gold = rb:CreateTexture()
        rb.goldTex = gold
        gold:SetTexture("Interface/Icons/INV_Misc_Coin_17")
        gold:SetPoint("TOPLEFT", rb, "TOPLEFT", 4, -4)
        gold:SetPoint("BOTTOMRIGHT", rb, "BOTTOMRIGHT", -4, 4)
        gold:SetDrawLayer("BORDER", -1)

        local roleTex = rb:CreateTexture()
        roleTex:SetAtlas(GetIconForRole(r.role))
        roleTex:SetPoint("TOPLEFT", rb, "TOPLEFT", 22, 0)
        roleTex:SetSize(20, 20)

        rb:SetHitRectInsets(0, -20, 0, 0)
        rb:SetScript("OnClick", function(self)
            local roles = { GetLFGRoles() }
            roles[self.tag + 1] = self:GetChecked()
            SetLFGRoles(unpack(roles))
            addon.UI:UpdateYesEnabled()
        end)
        popupFrame.roleButtons[i] = rb
    end

    popupFrame:Hide()
    applyPopupAnchor()

    hooksecurefunc("SetLFGRoles", function()
        for i, rb in ipairs(popupFrame.roleButtons) do
            rb:SetChecked(select(i + 1, GetLFGRoles()))
        end
    end)
end

function addon.UI:UpdateYesEnabled()
    if not popupFrame then return end
    local _, t, h, d = GetLFGRoles()
    if t or h or d then popupFrame.buttonYES:Enable() else popupFrame.buttonYES:Disable() end
end

function addon.UI:ShowPopup(text, active)
    if not popupFrame then return end
    local frame = addon.EventFrame
    frame.__popupDungeonID    = active.dungeonID
    frame.__popupLfgCategory  = active.lfgCategory

    popupFrame.text:SetText(text)
    local w = math.max(POPUP_MIN_WIDTH, popupFrame.text:GetStringWidth() + 8)
    popupFrame:SetWidth(w)
    popupFrame.buttonYES:SetPoint("TOPRIGHT", popupFrame, "TOPLEFT", w / 2 - 1, -25 * 2 - 12)
    popupFrame.buttonNO :SetPoint("TOPLEFT",  popupFrame, "TOPLEFT", w / 2 + 1, -25 * 2 - 12)

    for i, rb in ipairs(popupFrame.roleButtons) do
        rb:SetChecked(select(i + 1, GetLFGRoles()))
        if active.roles and active.roles[rb.role] then rb.goldTex:Show() else rb.goldTex:Hide() end
    end
    self:UpdateYesEnabled()
    popupFrame:Show()
end

function addon.UI:HidePopup()
    if popupFrame and popupFrame:IsShown() then
        popupFrame:Hide()
    end
end

function addon.UI:IsPopupShown()
    return popupFrame and popupFrame:IsShown()
end

function addon.UI:ResetPopupAnchor()
    if popupFrame then applyPopupAnchor() end
end

function addon.UI:OnWatchlistChanged()
    for _, b in ipairs(lfgButtons) do b:UpdateStatus() end
end

function addon.UI:Initialize()
    -- L+ buttons need their parent frames to exist; LFD/RF frames load on demand
    -- so build them lazily here, after PLAYER_ENTERING_WORLD.
    local lfdBtn = buildLFGButton(1, "LFDQueueFrameTypeDropdown", "LFD", { LFDQueueFrame, "type" })
    if lfdBtn then table.insert(lfgButtons, lfdBtn) end

    local rfBtn = buildLFGButton(2, "RaidFinderQueueFrameSelectionDropdown", "RaidFinder", { RaidFinderQueueFrame, "raid" })
    if rfBtn then table.insert(lfgButtons, rfBtn) end

    if hooksecurefunc and LFGRewardsFrame_UpdateFrame then
        hooksecurefunc("LFGRewardsFrame_UpdateFrame", onLFGRewardsFrameUpdate)
    end

    buildPopup()
end
