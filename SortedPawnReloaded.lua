local ADDON = "SortedPawnReloaded"
local addonName = ...

local frame = CreateFrame("Frame")

--------------------------------------------------
-- Caches
--------------------------------------------------

-- itemID → true
local EquippableItems = {}

-- itemLink → percent OR false
local PawnCache = {}

-- itemLink → itemID
local ItemIDCache = {}

--------------------------------------------------
-- Debug
--------------------------------------------------

local DEBUG = false

local function Print(...)
    print("|cff66ccff" .. ADDON .. ":|r", ...)
end

local function D(...)
    if not DEBUG then return end
    print("|cff66ccffSPR|r", ...)
end

--------------------------------------------------
-- Slash command: /sp
--------------------------------------------------

local function PrintHelp()
    Print("Commands:")
    print("|cffaaaaaa/sp|r           → help")
    print("|cffaaaaaa/sp info|r      → status / preflight checks")
    print("|cffaaaaaa/sp dump|r      → dump equippable cache")
    print("|cffaaaaaa/sp debug|r     → toggle debug logging")
end

local function Preflight()
    local hasSorted = LibStub("Sorted.", true) ~= nil
    local hasPawnGetItemData = type(PawnGetItemData) == "function"
    local hasPawnIsItemAnUpgrade = type(PawnIsItemAnUpgrade) == "function"

    Print("Status:")
    Print("Sorted detected:", hasSorted)
    Print("PawnGetItemData:", hasPawnGetItemData)
    Print("PawnIsItemAnUpgrade:", hasPawnIsItemAnUpgrade)

    if not hasSorted then
        Print("Note: Sorted not detected. Enable the Sorted addon.")
    end

    if not (hasPawnGetItemData and hasPawnIsItemAnUpgrade) then
        Print("Note: Pawn API not ready. Enable Pawn and /reload.")
    end
end

SLASH_SORTEDPAWNRELOADED1 = "/sp"
SlashCmdList["SORTEDPAWNRELOADED"] = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")

    if msg == "" then
        PrintHelp()
        return
    end

    if msg == "debug" then
        DEBUG = not DEBUG
        Print("Debug:", DEBUG and "ON" or "OFF")
        return
    end

    if msg == "info" then
        Preflight()
        return
    end

    if msg == "dump" then
        Print("Equippable cache dump:")
        for itemID in pairs(EquippableItems) do
            print("  itemID:", itemID)
        end
        return
    end

    PrintHelp()
end

--------------------------------------------------
-- Localize globals (Lua perf)
--------------------------------------------------

local GetItemInfoInstant = GetItemInfoInstant
local IsEquippableItem = IsEquippableItem
local GetContainerItemLink = C_Container.GetContainerItemLink
local GetContainerNumSlots = C_Container.GetContainerNumSlots

-- NOTE: keep these as locals (fast), but DO NOT rely on them being non-nil at load time.
-- We still check in GetPawnUpgradePercent.
local PawnGetItemData = PawnGetItemData
local PawnIsItemAnUpgrade = PawnIsItemAnUpgrade

--------------------------------------------------
-- Item helpers
--------------------------------------------------

local function GetItemIDFromLink(link)
    local id = ItemIDCache[link]
    if id ~= nil then
        return id
    end

    id = link:match("item:(%d+)")
    id = id and tonumber(id)

    ItemIDCache[link] = id
    return id
end

local NON_GEAR_EQUIPLOCS = {
    INVTYPE_BAG = true,
    INVTYPE_REAGENTBAG = true,
    INVTYPE_QUIVER = true,
    INVTYPE_AMMO = true,
    INVTYPE_PROFESSION_TOOL = true,
    INVTYPE_PROFESSION_GEAR = true,
}

local function IsRealGear(itemLink)
    if not IsEquippableItem(itemLink) then
        return false
    end

    local _, _, _, equipLoc = GetItemInfoInstant(itemLink)
    if not equipLoc or NON_GEAR_EQUIPLOCS[equipLoc] then
        return false
    end

    return true
end

local function IsItemInEquippableCache(link)
    local itemID = GetItemIDFromLink(link)
    return itemID and EquippableItems[itemID]
end

--------------------------------------------------
-- Pawn helpers
--------------------------------------------------

local function SafeCall(fn, ...)
    local ok, result = pcall(fn, ...)
    if not ok then
        D("Pawn call failed:", result)
        return nil
    end
    return result
end

local function NormalizePawnPercent(p)
    if type(p) ~= "number" then
        return nil
    end

    if math.abs(p) <= 1.5 then
        return p * 100
    end

    return p
end

local function GetPawnUpgradePercent(itemLink)
    local cached = PawnCache[itemLink]
    if cached ~= nil then
        return cached or nil
    end

    -- refresh locals (covers "Pawn loaded after us" cases)
    PawnGetItemData = PawnGetItemData or _G.PawnGetItemData
    PawnIsItemAnUpgrade = PawnIsItemAnUpgrade or _G.PawnIsItemAnUpgrade

    if not PawnGetItemData or not PawnIsItemAnUpgrade then
        PawnCache[itemLink] = false
        return nil
    end

    local itemData = SafeCall(PawnGetItemData, itemLink)
    if not itemData then
        PawnCache[itemLink] = false
        return nil
    end

    local result = SafeCall(PawnIsItemAnUpgrade, itemData)
    if type(result) ~= "table" then
        PawnCache[itemLink] = false
        return nil
    end

    local entry = result[1]
    if type(entry) ~= "table" then
        PawnCache[itemLink] = false
        return nil
    end

    local percent = NormalizePawnPercent(entry.PercentUpgrade)
    if percent and percent > 0 then
        PawnCache[itemLink] = percent
        return percent
    end

    PawnCache[itemLink] = false
    return nil
end

--------------------------------------------------
-- Bag scanning
--------------------------------------------------

local function ScanBags(reason)
    D("ScanBags:", reason)

    wipe(EquippableItems)
    wipe(PawnCache)

    for bag = 0, NUM_BAG_SLOTS do
        local numSlots = GetContainerNumSlots(bag)

        for slot = 1, numSlots do
            local link = GetContainerItemLink(bag, slot)

            if link and IsRealGear(link) then
                local itemID = GetItemIDFromLink(link)
                if itemID then
                    EquippableItems[itemID] = true
                end
            end
        end
    end

    local Sorted = LibStub("Sorted.", true)
    if Sorted then
        if Sorted.itemLists and Sorted.itemLists.primary then
            Sorted.itemLists.primary:Update()
        elseif Sorted.currentItemList then
            Sorted.currentItemList:Update()
        end
    end
end

--------------------------------------------------
-- Scan scheduler
--------------------------------------------------

local scanScheduled = false
local scanAgain = false
local lastReason

local function ScheduleScan(reason)
    lastReason = reason or lastReason or "unknown"

    if scanScheduled then
        scanAgain = true
        return
    end

    scanScheduled = true

    C_Timer.After(0.15, function()
        scanScheduled = false

        ScanBags(lastReason)

        if scanAgain then
            scanAgain = false
            ScheduleScan("coalesced")
        end
    end)
end

--------------------------------------------------
-- Sorted integration
--------------------------------------------------

local function TryRegisterSortedColumn()
    local Sorted = LibStub("Sorted.", true)
    if not Sorted then return end

    if SortedPawnReloaded_ColumnRegistered then
        return
    end
    SortedPawnReloaded_ColumnRegistered = true

    local COLUMN_KEY = "PAWN"

    local function CreateElement(cell)
        cell.text = cell:CreateFontString(nil, "OVERLAY", "SortedFont")
        cell.text:SetAllPoints()
        cell.text:SetJustifyH("CENTER")
    end

    local function UpdateElement(cell, data)
        cell.text:SetText("")

        local link = data and data.link
        if not link then return end

        if not IsItemInEquippableCache(link) then
            return
        end

        local percent = GetPawnUpgradePercent(link)
        if percent then
            cell.text:SetText(string.format("|TInterface\\Addons\\Pawn\\Textures\\UpgradeArrow:12|t %.0f%%", percent))
        end
    end

    -- Column chooser label
    Sorted:AddItemColumn(
        COLUMN_KEY,
        "Pawn",
        55,
        CreateElement,
        UpdateElement
    )

    local function Sort(asc, data1, data2)
        local p1 = data1 and data1.link and GetPawnUpgradePercent(data1.link)
        local p2 = data2 and data2.link and GetPawnUpgradePercent(data2.link)

        -- upgrades always on top
        if p1 and not p2 then return true end
        if p2 and not p1 then return false end

        -- both upgrades: sort by percent
        if p1 and p2 then
            if asc then
                return p1 < p2
            else
                return p1 > p2
            end
        end

        -- neither upgrade: keep existing order
        return false
    end

    -- Sort header label: Pawn icon (cropped)
    Sorted:AddSortMethod(
        COLUMN_KEY,
        "|TInterface\\Addons\\Pawn\\Textures\\PawnLogo:20:20:0:0:256:128:0:128:0:128|t",
        Sort,
        false
    )
end

--------------------------------------------------
-- Events
--------------------------------------------------

frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("BAG_UPDATE_DELAYED")
frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
frame:RegisterEvent("ADDON_LOADED")

frame:SetScript("OnEvent", function(_, event, arg1)
    D("EVENT:", event)

    if event == "PLAYER_LOGIN" then
        ScheduleScan("login")
        TryRegisterSortedColumn()

    elseif event == "BAG_UPDATE_DELAYED" then
        ScheduleScan("bag update")

    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        ScanBags("equipment change")

    elseif event == "ADDON_LOADED" then
        if arg1 == "Sorted" then
            TryRegisterSortedColumn()
        elseif arg1 == "Pawn" then
            -- Pawn may have loaded after us; refresh caches and repaint.
            wipe(PawnCache)
            if LibStub("Sorted.", true) then
                local Sorted = LibStub("Sorted.", true)
                if Sorted and Sorted.currentItemList then
                    Sorted.currentItemList:Update()
                end
            end
        end
    end
end)