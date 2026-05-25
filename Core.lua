local addonName, addon = ...

addon.Core = addon.Core or {}
addon.WatchList = addon.WatchList or {}

local PREFIX   = "|cffaaaaffLookingForSatchels|r "
local INTERVAL = 10

local eventFrame = CreateFrame("Frame", "LookingForSatchelsFrame", UIParent)
addon.EventFrame = eventFrame

local scanTicker
local pendingPopupAfterCombat = false
local pendingPopupAfterGroup  = false
local lastFoundSomething      = false
local popupQueue              = {}
local activePopup             = nil -- { dungeonID, lfgCategory }
local scanCounter             = 0

function addon:Print(msg)
    print(PREFIX .. msg)
end

local function dungeonName(id)
    return GetLFGDungeonInfo(id)
end

local function isAlreadyQueued(dungeonID, lfgCategory)
    if lfgCategory == "LFD" then
        return GetLFGMode(LE_LFG_CATEGORY_LFD) and true or false
    elseif lfgCategory == "Scenario" then
        return GetLFGMode(LE_LFG_CATEGORY_SCENARIO) and true or false
    elseif lfgCategory == "RaidFinder" then
        return GetLFGMode(LE_LFG_CATEGORY_RF, dungeonID) and true or false
    end
    return false
end

-- -------- Watch list --------

function addon.WatchList:Status(id)
    local entry = addon.db and addon.db.LFG_dungeonIDs[id]
    return entry and entry.status or 0
end

function addon.WatchList:HasAny()
    if not addon.db then return false end
    for _, v in pairs(addon.db.LFG_dungeonIDs) do
        if v and v.status and v.status >= 1 then return true end
    end
    return false
end

function addon:AddWatch(dungeonID, lfgCategory)
    if type(dungeonID) ~= "number" or LFGIsIDHeader(dungeonID) then return end
    addon.db.LFG_dungeonIDs[dungeonID] = { status = 1, lfgCategory = lfgCategory }
    addon:Print(format("added to watch list: %s", dungeonName(dungeonID) or dungeonID))
    if addon.UI and addon.UI.OnWatchlistChanged then addon.UI:OnWatchlistChanged() end
    addon:StartScan()
end

function addon:RemoveWatch(dungeonID)
    if type(dungeonID) ~= "number" or LFGIsIDHeader(dungeonID) then return end
    addon.db.LFG_dungeonIDs[dungeonID] = nil
    addon:Print(format("removed from watch list: %s", dungeonName(dungeonID) or dungeonID))
    if addon.UI and addon.UI.OnWatchlistChanged then addon.UI:OnWatchlistChanged() end
    if not addon.WatchList:HasAny() then addon:StopScan() end
end

function addon:ClearWatchlist()
    addon.db.LFG_dungeonIDs = {}
    addon:Print("watch list cleared.")
    if addon.UI and addon.UI.OnWatchlistChanged then addon.UI:OnWatchlistChanged() end
    addon:StopScan()
end

function addon:Rescan()
    for _, v in pairs(addon.db.LFG_dungeonIDs) do
        if v.status == 2 then v.status = 1 end
    end
    addon:Print("rescanning...")
    RequestLFDPlayerLockInfo()
end

-- -------- Scan ticker --------

local function tick()
    scanCounter = scanCounter + 1
    RequestLFDPlayerLockInfo()
end

function addon:StartScan()
    if scanTicker then return end
    if not addon.Settings:Get("scanActive") then return end
    if not addon.WatchList:HasAny() then return end
    scanTicker = C_Timer.NewTicker(INTERVAL, tick)
    tick()
end

function addon:StopScan()
    if scanTicker then
        scanTicker:Cancel()
        scanTicker = nil
    end
end

function addon:IsScanning()
    return scanTicker ~= nil
end

-- -------- Popup queue --------

local function pushPopup(dungeonID, lfgCategory)
    for _, v in ipairs(popupQueue) do
        if v.dungeonID == dungeonID then return end
    end
    if isAlreadyQueued(dungeonID, lfgCategory) then return end
    table.insert(popupQueue, { dungeonID = dungeonID, lfgCategory = lfgCategory })
end

local function popPopup()
    table.remove(popupQueue, 1)
    activePopup = nil
    if addon.UI and addon.UI.HidePopup then addon.UI:HidePopup() end
end

local function showNextPopup(force)
    if InCombatLockdown() then
        pendingPopupAfterCombat = true
        return
    end
    if IsInGroup() then
        pendingPopupAfterGroup = true
        return
    end
    if #popupQueue == 0 then return end

    local head = popupQueue[1]
    local entry = addon.db.LFG_dungeonIDs[head.dungeonID]
    if not entry or (entry.status ~= 2 and not force) then
        popPopup()
        showNextPopup()
        return
    end

    activePopup = { dungeonID = head.dungeonID, lfgCategory = head.lfgCategory, roles = entry }

    if not addon.Settings:Get("showPopup") then return end
    if not (addon.UI and addon.UI.ShowPopup) then return end

    local numEncounters, numCompleted = GetLFGDungeonNumEncounters(head.dungeonID)
    local name = dungeonName(head.dungeonID) or tostring(head.dungeonID)
    local text
    if numCompleted and numEncounters and numEncounters > 0 then
        text = format("Queue for:\n%s\n%s/%s boss(es) already looted", name, numCompleted, numEncounters)
    else
        text = format("Queue for:\n%s", name)
    end
    addon.UI:ShowPopup(text, activePopup)
end

addon.ShowNextPopup = showNextPopup
addon.GetActivePopup = function() return activePopup end

-- -------- Secure macro targets (must be on LookingForSatchelsFrame) --------

function eventFrame.joinLFG(dungeonID, lfgCategory, removeFromWatchlist)
    if addon._previewing then
        addon:Print("preview: would queue for " .. tostring(dungeonID) .. " (" .. tostring(lfgCategory) .. ") — not actually queueing")
        addon._previewing = false
        if addon.UI and addon.UI.HidePopup then addon.UI:HidePopup() end
        activePopup = nil
        return
    end
    if lfgCategory == "LFD" then
        LFG_JoinDungeon(LE_LFG_CATEGORY_LFD, dungeonID, LFDDungeonList, LFDHiddenByCollapseList)
    elseif lfgCategory == "Scenario" then
        LFG_JoinDungeon(LE_LFG_CATEGORY_SCENARIO, dungeonID, ScenariosList, ScenariosHiddenByCollapseList)
    elseif lfgCategory == "RaidFinder" then
        ClearAllLFGDungeons(LE_LFG_CATEGORY_RF)
        SetLFGDungeon(LE_LFG_CATEGORY_RF, dungeonID)
        JoinSingleLFG(LE_LFG_CATEGORY_RF, dungeonID)
    end
    if removeFromWatchlist then addon:RemoveWatch(dungeonID) end
    popPopup()
    showNextPopup()
end

function eventFrame.dequeueJoinLFG(dungeonID, lfgCategory, removeFromWatchlist)
    if addon._previewing then
        addon._previewing = false
        if addon.UI and addon.UI.HidePopup then addon.UI:HidePopup() end
        activePopup = nil
        return
    end
    if removeFromWatchlist then addon:RemoveWatch(dungeonID) end
    popPopup()
    showNextPopup()
end

function addon:PreviewPopup()
    if not (addon.UI and addon.UI.ShowPopup) then
        addon:Print("UI not yet initialized — open the dungeon finder once first.")
        return
    end
    addon._previewing = true
    activePopup = {
        dungeonID   = 0,
        lfgCategory = "LFD",
        roles       = { TANK = true, HEALER = true, DAMAGER = false },
    }
    addon.UI:ShowPopup("Queue for:\nPreview Dungeon\n3/5 boss(es) already looted", activePopup)
    addon:Print("preview popup shown — click No or any popup button to dismiss")
end

-- -------- Scan body (reward detection) --------

local function effectiveRoleMask(entry)
    if entry.dungeonRoles then
        return entry.dungeonRoles[1] == 1, entry.dungeonRoles[2] == 1, entry.dungeonRoles[3] == 1
    end
    local r = addon.db.roles
    return r.tank, r.heal, r.damage
end

local function onLFGUpdateRandomInfo()
    if not addon.Settings:Get("scanActive") then return end
    if not addon.WatchList:HasAny() then return end

    local foundAnything = false
    for k, v in pairs(addon.db.LFG_dungeonIDs) do
        if v.status and v.status >= 1 then
            local foundForK = false
            local doneonce = GetLFGDungeonRewards(k)
            local wantTank, wantHeal, wantDamage = effectiveRoleMask(v)

            for i = 1, LFG_ROLE_NUM_SHORTAGE_TYPES do
                local eligible, forTank, forHealer, forDamage, itemCount, money, xp = GetLFGRoleShortageRewards(k, i)
                if eligible
                   and ( (forTank and wantTank) or (forHealer and wantHeal) or (forDamage and wantDamage) )
                   and (itemCount ~= 0 or money ~= 0 or xp ~= 0)
                   and (not addon.Settings:Get("firstOnly") or not doneonce)
                   and not isAlreadyQueued(k, v.lfgCategory)
                then
                    foundAnything = true
                    foundForK = true

                    if v.status == 1 then
                        v.status = 2
                        v.TANK    = forTank
                        v.HEALER  = forHealer
                        v.DAMAGER = forDamage

                        local name = dungeonName(k) or tostring(k)
                        addon:Print("LFG reward for: " .. name)
                        RaidNotice_AddMessage(RaidWarningFrame, "LFG reward for: " .. name,
                            { r = 0.67, g = 0.67, b = 1 }, 10)

                        pushPopup(k, v.lfgCategory)
                        showNextPopup()
                    end

                    if not lastFoundSomething then
                        FlashClientIcon()
                        if addon.Settings:Get("playSound") then
                            PlaySound(addon.Settings:Get("soundId"), "master")
                        end
                        lastFoundSomething = true
                    end
                end
            end

            if not foundForK then
                v.status = 1
                if activePopup and activePopup.dungeonID == k then
                    addon:Print("LFG reward for: " .. (dungeonName(k) or k) .. " expired")
                    popPopup()
                    showNextPopup()
                end
            end
        end
    end

    if lastFoundSomething and not foundAnything then
        lastFoundSomething = false
    end
end

-- -------- Events --------

local handlers = {}

function handlers.PLAYER_ENTERING_WORLD()
    eventFrame:UnregisterEvent("PLAYER_ENTERING_WORLD")

    -- On a reload, any "found" status reverts to "watched" so the next scan re-prompts.
    for _, v in pairs(addon.db.LFG_dungeonIDs) do
        if v.status == 2 then v.status = 1 end
    end

    if addon.UI and addon.UI.Initialize then addon.UI:Initialize() end

    eventFrame:RegisterEvent("LFG_UPDATE_RANDOM_INFO")
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")

    addon:StartScan()
end

local debounceTimer
function handlers.LFG_UPDATE_RANDOM_INFO()
    -- The server sends LFG_UPDATE_RANDOM_INFO in bursts (typically 6 events per
    -- RequestLFDPlayerLockInfo call). Coalesce them into one scan.
    if debounceTimer then debounceTimer:Cancel() end
    debounceTimer = C_Timer.NewTimer(0.2, function()
        debounceTimer = nil
        onLFGUpdateRandomInfo()
    end)
end

function handlers.PLAYER_REGEN_DISABLED()
    if addon.UI and addon.UI.IsPopupShown and addon.UI:IsPopupShown() then
        pendingPopupAfterCombat = true
        addon.UI:HidePopup()
    end
end

function handlers.PLAYER_REGEN_ENABLED()
    if pendingPopupAfterCombat then
        pendingPopupAfterCombat = false
        showNextPopup()
    end
end

function handlers.GROUP_ROSTER_UPDATE()
    if pendingPopupAfterGroup then
        if not IsInGroup() then
            pendingPopupAfterGroup = false
            showNextPopup()
        end
    elseif IsInGroup() and addon.UI and addon.UI.IsPopupShown and addon.UI:IsPopupShown() then
        pendingPopupAfterGroup = true
        addon.UI:HidePopup()
    end
end

function handlers.ADDON_LOADED(loaded)
    if loaded ~= addonName then return end
    eventFrame:UnregisterEvent("ADDON_LOADED")
    addon.Settings:Initialize()

    addon.Settings:OnChange("scanActive", function(val)
        addon:Print("scan is " .. (val and "|cffaaffaaactive|r" or "|cffff8888paused|r"))
        if val then addon:StartScan() else addon:StopScan() end
    end)
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    local h = handlers[event]
    if h then h(...) end
end)
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

