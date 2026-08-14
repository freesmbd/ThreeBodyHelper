local ADDON_NAME = ...

local ThreeBodyHelper = _G.ThreeBodyHelper or {}
_G.ThreeBodyHelper = ThreeBodyHelper

local VoiceWheel = {}
ThreeBodyHelper.VoiceWheel = VoiceWheel

_G.BINDING_HEADER_THREEBODYHELPER = "ThreeBodyHelper"
_G.BINDING_NAME_THREEBODYHELPER_VOICEWHEEL_TOGGLE = "Open voice wheel"

local PREFIX = "MQQVOICE"
local MESSAGE_VERSION = "VW1"
local ADDON_PATH = "Interface\\AddOns\\ThreeBodyHelper\\"

local PHRASE_CATALOG = {
    { id = "wan_bu_liao_la", label = "玩不了啦", text = "玩不了啦", file = "Media\\Voice\\wan_bu_liao_la.ogg" },
    { id = "ready", label = "到目前为止感觉是人机难度", text = "到目前为止感觉是人机难度", file = "", soundKitID = 8959 },
    { id = "pull", label = "Pull", text = "开怪", file = "", soundKitID = 8959 },
    { id = "move", label = "Move", text = "走位", file = "", soundKitID = 8959 },
    { id = "spread", label = "Spread", text = "分散", file = "", soundKitID = 8959 },
    { id = "stack", label = "Stack", text = "集合", file = "", soundKitID = 8959 },
    { id = "interrupt", label = "Kick", text = "打断", file = "", soundKitID = 8959 },
    { id = "defensive", label = "Def", text = "开减伤", file = "", soundKitID = 8959 },
    { id = "fun", label = "Nice", text = "好活", file = "", soundKitID = 8959 },
}

local DEFAULTS = {
    enabled = true,
    receiveEnabled = true,
    syncEnabled = true,
    sendText = true,
    selfPlay = true,
    sendCooldown = 2.5,
    globalReceiveCooldown = 2.0,
    senderReceiveCooldown = 6.0,
    packId = "threebody-default-v1",
    channel = "AUTO",
    textChannel = "AUTO",
    phrases = PHRASE_CATALOG,
}

local db
local phraseById = {}
local buttons = {}
local selectedIndex = nil
local lastSendAt = -100
local lastGlobalReceiveAt = -100
local lastSenderReceiveAt = {}

local function CopyDefaults(src, dst)
    if type(dst) ~= "table" then
        dst = {}
    end

    for key, value in pairs(src) do
        if type(value) == "table" then
            dst[key] = CopyDefaults(value, dst[key])
        elseif dst[key] == nil then
            dst[key] = value
        end
    end

    return dst
end

local function SyncCatalogPhrases()
    if type(db.phrases) ~= "table" then
        db.phrases = {}
    end

    local existingById = {}
    for _, phrase in ipairs(db.phrases) do
        if type(phrase) == "table" and phrase.id and phrase.id ~= "" and not existingById[phrase.id] then
            existingById[phrase.id] = phrase
        end
    end

    local synced = {}
    local includedIds = {}
    for _, catalogPhrase in ipairs(PHRASE_CATALOG) do
        local phrase = existingById[catalogPhrase.id] or {}
        for key, value in pairs(catalogPhrase) do
            phrase[key] = value
        end
        table.insert(synced, phrase)
        includedIds[catalogPhrase.id] = true
    end

    for _, phrase in ipairs(db.phrases) do
        if type(phrase) == "table" then
            local phraseId = phrase.id
            if phraseId and phraseId ~= "" then
                if not includedIds[phraseId] then
                    table.insert(synced, phrase)
                    includedIds[phraseId] = true
                end
            else
                table.insert(synced, phrase)
            end
        end
    end

    db.phrases = synced
end

local function Print(message)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffThreeBodyHelper Voice|r " .. tostring(message))
    end
end

local function RebuildPhraseLookup()
    wipe(phraseById)
    if not db or type(db.phrases) ~= "table" then
        return
    end

    for index, phrase in ipairs(db.phrases) do
        if phrase.id and phrase.id ~= "" then
            phrase.index = index
            phraseById[phrase.id] = phrase
        end
    end
end

local function GetAddonChannel()
    local channel = db and db.channel or "AUTO"
    if channel == "PARTY" then
        return IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and "INSTANCE_CHAT" or (IsInGroup() and "PARTY" or nil)
    end
    if channel == "RAID" then
        return IsInRaid() and "RAID" or nil
    end
    if channel == "INSTANCE_CHAT" then
        return IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and "INSTANCE_CHAT" or nil
    end

    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        return "INSTANCE_CHAT"
    end
    if IsInRaid() then
        return "RAID"
    end
    if IsInGroup() then
        return "PARTY"
    end
    return nil
end

local function GetTextChannel()
    local channel = db and db.textChannel or "AUTO"
    if channel == "SAY" then
        return "SAY"
    end
    if channel == "GUILD" then
        return IsInGuild() and "GUILD" or nil
    end
    if channel == "PARTY" then
        return IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and "INSTANCE_CHAT" or (IsInGroup() and "PARTY" or nil)
    end
    if channel == "RAID" then
        return IsInRaid() and "RAID" or nil
    end
    if channel == "INSTANCE_CHAT" then
        return IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and "INSTANCE_CHAT" or nil
    end

    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        return "INSTANCE_CHAT"
    end
    if IsInRaid() then
        return "RAID"
    end
    if IsInGroup() then
        return "PARTY"
    end
    return "SAY"
end

local function PlayPhrase(phrase)
    if not phrase then
        return false
    end

    if phrase.file and phrase.file ~= "" and PlaySoundFile then
        local path = phrase.file
        if not path:find("^Interface\\", 1, false) and not path:find("^Interface/", 1, false) then
            path = ADDON_PATH .. phrase.file
        end
        local ok, willPlay = pcall(PlaySoundFile, path, phrase.channel or "Master")
        if ok and willPlay then
            return true
        end
    end

    if phrase.soundKitID and PlaySound then
        local ok, willPlay = pcall(PlaySound, phrase.soundKitID, phrase.channel or "Master")
        return ok and willPlay
    end

    return false
end

local function SendPhraseText(phrase)
    if not db.sendText or not phrase.text or phrase.text == "" then
        return
    end

    local channel = GetTextChannel()
    if channel then
        SendChatMessage(phrase.text, channel)
    else
        Print(phrase.text)
    end
end

local function SendPhraseSync(phrase)
    if not db.syncEnabled or not C_ChatInfo or not C_ChatInfo.SendAddonMessage then
        return
    end

    local channel = GetAddonChannel()
    if not channel then
        return
    end

    local payload = table.concat({ MESSAGE_VERSION, db.packId or DEFAULTS.packId, phrase.id }, "\t")
    C_ChatInfo.SendAddonMessage(PREFIX, payload, channel)
end

local function SelectPhrase(index, fromRemote)
    if not db or not db.enabled then
        return
    end

    local phrase = db.phrases and db.phrases[index]
    if not phrase then
        return
    end

    if fromRemote then
        PlayPhrase(phrase)
        return
    end

    local now = GetTime()
    if now - lastSendAt < (db.sendCooldown or DEFAULTS.sendCooldown) then
        Print("voice wheel is cooling down")
        return
    end
    lastSendAt = now

    if db.selfPlay then
        PlayPhrase(phrase)
    end
    SendPhraseText(phrase)
    SendPhraseSync(phrase)
end

local wheel = CreateFrame("Frame", "ThreeBodyHelperVoiceWheelFrame", UIParent)
wheel:SetSize(560, 560)
wheel:SetPoint("CENTER")
wheel:SetFrameStrata("DIALOG")
wheel:EnableMouse(true)
wheel:SetScript("OnMouseDown", function(_, button)
    if button == "RightButton" then
        wheel:Hide()
    end
end)
wheel:Hide()

wheel.centerText = wheel:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
wheel.centerText:SetPoint("CENTER", 0, 0)
wheel.centerText:SetWidth(220)
wheel.centerText:SetJustifyH("CENTER")
wheel.centerText:SetJustifyV("MIDDLE")
wheel.centerText:SetWordWrap(true)
if wheel.centerText.SetNonSpaceWrap then
    wheel.centerText:SetNonSpaceWrap(true)
end
wheel.centerText:SetText("语音轮盘")

wheel.centerSubText = wheel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
wheel.centerSubText:SetPoint("TOP", wheel.centerText, "BOTTOM", 0, -8)
wheel.centerSubText:SetText("点击发送，右键关闭")

local function HighlightSelected(index)
    selectedIndex = index
    for i, button in ipairs(buttons) do
        if i == index then
            button:SetAlpha(1)
            button:SetScale(1.08)
            if button.bg then
                button.bg:SetColorTexture(0.08, 0.15, 0.22, 0.86)
            end
            if button.text then
                button.text:SetTextColor(1, 0.92, 0.35)
            end
        else
            button:SetAlpha(0.78)
            button:SetScale(1)
            if button.bg then
                button.bg:SetColorTexture(0.02, 0.02, 0.02, 0.62)
            end
            if button.text then
                button.text:SetTextColor(0.9, 0.9, 0.9)
            end
        end
    end

    local phrase = index and db and db.phrases and db.phrases[index]
    wheel.centerText:SetText((phrase and (phrase.text or phrase.label or phrase.id)) or "语音轮盘")
end

local function LayoutButtons()
    for _, button in ipairs(buttons) do
        button:Hide()
    end

    if not db or type(db.phrases) ~= "table" then
        return
    end

    local count = math.min(#db.phrases, 12)
    local radius = 205
    for i = 1, count do
        local button = buttons[i]
        if not button then
            button = CreateFrame("Button", nil, wheel)
            button:SetSize(176, 54)
            button.bg = button:CreateTexture(nil, "BACKGROUND")
            button.bg:SetAllPoints()
            button.bg:SetColorTexture(0.02, 0.02, 0.02, 0.62)
            button.text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            button.text:SetPoint("CENTER", 0, 0)
            button.text:SetWidth(162)
            button.text:SetJustifyH("CENTER")
            button.text:SetJustifyV("MIDDLE")
            button.text:SetWordWrap(true)
            if button.text.SetNonSpaceWrap then
                button.text:SetNonSpaceWrap(true)
            end
            button:SetScript("OnEnter", function(self)
                HighlightSelected(self.index)
            end)
            button:SetScript("OnLeave", function()
                HighlightSelected(nil)
            end)
            button:SetScript("OnClick", function(self)
                SelectPhrase(self.index, false)
                wheel:Hide()
            end)
            buttons[i] = button
        end

        local phrase = db.phrases[i]
        local angle = ((i - 1) / count) * math.pi * 2 - math.pi / 2
        button.index = i
        button.text:SetText(phrase.label or phrase.text or phrase.id or tostring(i))
        button:ClearAllPoints()
        button:SetPoint("CENTER", wheel, "CENTER", math.cos(angle) * radius, -math.sin(angle) * radius)
        button:Show()
    end
    HighlightSelected(nil)
end

function VoiceWheel.Show()
    if not db or not db.enabled then
        Print("voice wheel is disabled")
        return
    end

    LayoutButtons()
    wheel:Show()
end

function VoiceWheel.Hide()
    wheel:Hide()
end

function VoiceWheel.Toggle()
    if wheel:IsShown() then
        VoiceWheel.Hide()
    else
        VoiceWheel.Show()
    end
end

function VoiceWheel.Select(index)
    SelectPhrase(tonumber(index), false)
end

function VoiceWheel.SetReceiveEnabled(value)
    db.receiveEnabled = value and true or false
    Print("receive voice wheel messages: " .. (db.receiveEnabled and "on" or "off"))
end

function VoiceWheel.SetSyncEnabled(value)
    db.syncEnabled = value and true or false
    Print("send addon sync: " .. (db.syncEnabled and "on" or "off"))
end

function VoiceWheel.SetTextEnabled(value)
    db.sendText = value and true or false
    Print("send voice wheel text: " .. (db.sendText and "on" or "off"))
end

local function NormalizeTextChannel(channel)
    channel = string.upper(strtrim(channel or ""))
    if channel == "INSTANCE" or channel == "INSTANCE_CHAT" or channel == "I" then
        return "INSTANCE_CHAT"
    end
    if channel == "AUTO" or channel == "SAY" or channel == "PARTY" or channel == "RAID" or channel == "GUILD" then
        return channel
    end
    return nil
end

function VoiceWheel.SetTextChannel(channel)
    channel = NormalizeTextChannel(channel)
    if not channel then
        Print("text channel: auto, say, party, raid, instance, guild")
        return
    end

    db.textChannel = channel
    Print("voice wheel text channel = " .. channel)
end

function VoiceWheel.SetCooldown(kind, seconds)
    seconds = tonumber(seconds)
    if not seconds or seconds < 0 then
        Print("cooldown value must be a non-negative number")
        return
    end

    if kind == "send" then
        db.sendCooldown = seconds
    elseif kind == "global" then
        db.globalReceiveCooldown = seconds
    elseif kind == "sender" then
        db.senderReceiveCooldown = seconds
    else
        Print("cooldown kind: send, global, sender")
        return
    end

    Print("voice wheel " .. kind .. " cooldown = " .. seconds .. "s")
end

function VoiceWheel.HandleSlash(input)
    input = strtrim(input or "")
    local command, rest = input:match("^(%S*)%s*(.-)$")
    command = string.lower(command or "")
    rest = strtrim(rest or "")

    if command == "" or command == "show" or command == "toggle" then
        VoiceWheel.Toggle()
        return
    end

    if command == "send" or command == "play" then
        VoiceWheel.Select(tonumber(rest) or 1)
        return
    end

    if command == "receive" or command == "recv" then
        rest = string.lower(rest)
        if rest == "on" then
            VoiceWheel.SetReceiveEnabled(true)
        elseif rest == "off" then
            VoiceWheel.SetReceiveEnabled(false)
        else
            Print("receive voice wheel messages: " .. (db.receiveEnabled and "on" or "off"))
        end
        return
    end

    if command == "sync" then
        rest = string.lower(rest)
        if rest == "on" then
            VoiceWheel.SetSyncEnabled(true)
        elseif rest == "off" then
            VoiceWheel.SetSyncEnabled(false)
        else
            Print("send addon sync: " .. (db.syncEnabled and "on" or "off"))
        end
        return
    end

    if command == "text" then
        rest = string.lower(rest)
        if rest == "on" then
            VoiceWheel.SetTextEnabled(true)
        elseif rest == "off" then
            VoiceWheel.SetTextEnabled(false)
        elseif rest ~= "" then
            VoiceWheel.SetTextChannel(rest)
        else
            Print("send voice wheel text: " .. (db.sendText and "on" or "off"))
            Print("voice wheel text channel: " .. tostring(db.textChannel or "AUTO"))
        end
        return
    end

    if command == "textchannel" or command == "text-channel" or command == "txtchan" then
        if rest == "" then
            Print("voice wheel text channel: " .. tostring(db.textChannel or "AUTO"))
        else
            VoiceWheel.SetTextChannel(rest)
        end
        return
    end

    if command == "status" then
        Print("enabled=" .. tostring(db.enabled) .. ", receive=" .. tostring(db.receiveEnabled)
            .. ", sync=" .. tostring(db.syncEnabled) .. ", text=" .. tostring(db.sendText))
        Print("pack=" .. tostring(db.packId or DEFAULTS.packId))
        Print("text channel=" .. tostring(db.textChannel or "AUTO"))
        Print("cooldowns: send=" .. tostring(db.sendCooldown)
            .. "s, global=" .. tostring(db.globalReceiveCooldown)
            .. "s, sender=" .. tostring(db.senderReceiveCooldown) .. "s")
        return
    end

    if command == "list" or command == "ids" then
        for index, phrase in ipairs(db.phrases or {}) do
            Print(index .. ". " .. tostring(phrase.id or "?") .. " -> " .. tostring(phrase.file or ""))
        end
        return
    end

    if command == "cooldown" or command == "cd" then
        local kind, seconds = rest:match("^(%S+)%s+(%S+)$")
        VoiceWheel.SetCooldown(string.lower(kind or ""), seconds)
        return
    end

    Print("/mqq voice - open wheel")
    Print("/mqq voice receive on|off - allow/block teammates' synced voice")
    Print("/mqq voice sync on|off - send addon sync to group")
    Print("/mqq voice text on|off - send normal chat text")
    Print("/mqq voice text auto|say|party|raid|instance|guild - set text channel")
    Print("/mqq voice list - show phrase ids and local files")
    Print("/mqq voice cooldown global|sender|send seconds")
    Print("/mqq voice send 1-9 - trigger a phrase")
end

local function HandleAddonMessage(prefix, message, channel, sender)
    if prefix ~= PREFIX or not db or not db.receiveEnabled then
        return
    end

    local version, packId, phraseId = strsplit("\t", message or "")
    if version ~= MESSAGE_VERSION or packId ~= (db.packId or DEFAULTS.packId) then
        return
    end

    local phrase = phraseById[phraseId]
    if not phrase then
        return
    end

    local playerName = UnitName("player")
    if sender and playerName and Ambiguate(sender, "short") == playerName then
        return
    end

    local now = GetTime()
    if now - lastGlobalReceiveAt < (db.globalReceiveCooldown or DEFAULTS.globalReceiveCooldown) then
        return
    end
    if sender and now - (lastSenderReceiveAt[sender] or -100) < (db.senderReceiveCooldown or DEFAULTS.senderReceiveCooldown) then
        return
    end

    lastGlobalReceiveAt = now
    if sender then
        lastSenderReceiveAt[sender] = now
    end
    SelectPhrase(phrase.index, true)
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("CHAT_MSG_ADDON")
eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName ~= ADDON_NAME then
            return
        end

        ThreeBodyHelperDB = ThreeBodyHelperDB or {}
        ThreeBodyHelperDB.voiceWheel = CopyDefaults(DEFAULTS, ThreeBodyHelperDB.voiceWheel)
        db = ThreeBodyHelperDB.voiceWheel
        if db.packId == nil or db.packId == "default" then
            db.packId = DEFAULTS.packId
        end
        SyncCatalogPhrases()
        RebuildPhraseLookup()
        if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
            C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
        end
        return
    end

    if event == "CHAT_MSG_ADDON" then
        HandleAddonMessage(...)
    end
end)

SLASH_THREEBODYHELPERVOICEWHEEL1 = "/mqqwheel"
SlashCmdList.THREEBODYHELPERVOICEWHEEL = VoiceWheel.HandleSlash
