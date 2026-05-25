local addonName, addon = ...

addon.Settings = addon.Settings or {}

local defaults = {
    scanActive    = true,
    showPopup     = true,
    firstOnly     = false,
    playSound     = true,
    soundId       = 120, -- SOUNDKIT.LOOT_WINDOW_COIN_SOUND
    roles         = { tank = true, heal = true, damage = true },
    LFG_dungeonIDs = {},
    popupAnchor   = { point = "CENTER", relativeTo = "UIParent", relativePoint = "CENTER", x = 0, y = 0 },
}

local changeCallbacks = {}

function addon.Settings:OnChange(key, cb)
    changeCallbacks[key] = changeCallbacks[key] or {}
    table.insert(changeCallbacks[key], cb)
end

local function fireChange(key, value)
    if not changeCallbacks[key] then return end
    for _, cb in ipairs(changeCallbacks[key]) do
        cb(value)
    end
end

local function migrate(db)
    -- v0.23 -> v0.24: 0/1 ints -> booleans, positional roles array -> named table,
    -- drop the floating indicator anchor fields.
    if db.scanActive == 0 then db.scanActive = false
    elseif db.scanActive == 1 then db.scanActive = true end

    if db.playSound == 0 then db.playSound = false
    elseif db.playSound == 1 then db.playSound = true end

    if db.first ~= nil then
        db.firstOnly = db.first and true or false
        db.first = nil
    end

    if type(db.LFG_roles) == "table" and (db.LFG_roles[1] ~= nil) then
        db.roles = {
            tank   = db.LFG_roles[1] == 1,
            heal   = db.LFG_roles[2] == 1,
            damage = db.LFG_roles[3] == 1,
        }
        db.LFG_roles = nil
    end
    if db.roles == nil then
        db.roles = { tank = true, heal = true, damage = true }
    end

    if db.framePointPopup or db.frameRelativeToPopup then
        db.popupAnchor = {
            point         = db.framePointPopup or defaults.popupAnchor.point,
            relativeTo    = db.frameRelativeToPopup or defaults.popupAnchor.relativeTo,
            relativePoint = db.frameRelativePointPopup or defaults.popupAnchor.relativePoint,
            x             = db.frameOffsetXPopup or 0,
            y             = db.frameOffsetYPopup or 0,
        }
        db.framePointPopup, db.frameRelativeToPopup, db.frameRelativePointPopup = nil, nil, nil
        db.frameOffsetXPopup, db.frameOffsetYPopup = nil, nil
    end

    db.framePoint, db.frameRelativeTo, db.frameRelativePoint = nil, nil, nil
    db.frameOffsetX, db.frameOffsetY = nil, nil
    db.showFrame = nil
    db.addonVersion = nil
end

local function seedDefaults(db)
    for k, v in pairs(defaults) do
        if db[k] == nil then
            if type(v) == "table" then
                local copy = {}
                for k2, v2 in pairs(v) do copy[k2] = v2 end
                db[k] = copy
            else
                db[k] = v
            end
        end
    end
end

function addon.Settings:Get(key)
    if addon.db then return addon.db[key] end
    return defaults[key]
end

function addon.Settings:Set(key, value)
    if not addon.db then return end
    addon.db[key] = value
    fireChange(key, value)
end

function addon.Settings:Initialize()
    LookingForSatchelsOptions = LookingForSatchelsOptions or {}
    migrate(LookingForSatchelsOptions)
    seedDefaults(LookingForSatchelsOptions)
    addon.db = LookingForSatchelsOptions
end
