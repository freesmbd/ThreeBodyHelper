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
local SLOT_COUNT = 8

local PHRASE_CATALOG = {
    { id = "wan_bu_liao_la", label = "玩不了啦", text = "玩不了啦", file = "Media\\Voice\\wan_bu_liao_la.ogg" },
    { id = "chong_feng", label = "冲锋", text = "冲锋", file = "Media\\Voice\\chong_feng.ogg" },
    { id = "huan_hu", label = "欢呼", text = "欢呼", file = "Media\\Voice\\huan_hu.ogg" },
    { id = "bei_shang_xiao_hao", label = "悲伤小号", text = "悲伤小号", file = "Media\\Voice\\bei_shang_xiao_hao.ogg" },
    { id = "tian_huo_tian_huo", label = "天火天火", text = "天火天火", file = "Media\\Voice\\tian_huo_tian_huo.ogg" },
    { id = "bai_tuo_shui_qu_sha_le_ta_ba", label = "拜托谁去杀了他吧", text = "拜托谁去杀了他吧", file = "Media\\Voice\\bai_tuo_shui_qu_sha_le_ta_ba.ogg" },
    { id = "piao_liang", label = "漂亮", text = "漂亮", file = "Media\\Voice\\piao_liang.ogg" },
    { id = "dui_you_ne", label = "队友呢", text = "队友呢", file = "Media\\Voice\\dui_you_ne.ogg" },
}

local DEFAULT_SLOT_IDS = {
    "wan_bu_liao_la",
    "chong_feng",
    "huan_hu",
    "bei_shang_xiao_hao",
    "tian_huo_tian_huo",
    "bai_tuo_shui_qu_sha_le_ta_ba",
    "piao_liang",
    "dui_you_ne",
}

local RETIRED_CATALOG_IDS = {
    ready = true,
    pull = true,
    move = true,
    spread = true,
    stack = true,
    interrupt = true,
    defensive = true,
    fun = true,
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
    soundChannel = "Dialog",
    scale = 1.0,
    pointX = 0,
    pointY = 0,
    moveUnlocked = false,
    slots = DEFAULT_SLOT_IDS,
}

local db
local catalogPhrases = {}
local phraseById = {}
local buttons = {}
local selectedIndex = nil
local lastSendAt = -100
local lastGlobalReceiveAt = -100
local lastSenderReceiveAt = {}
local wheel
local optionsFrame
local slotConfigFrame
local optionControls = {}
local slotButtons = {}
local catalogRows = {}
local selectedSlot = 1
local catalogPage = 1
local catalogSearch = ""
local Print

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

local function Clamp(value, minValue, maxValue)
    value = tonumber(value)
    if not value then
        return nil
    end
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

local function CopyPhrase(phrase)
    local copy = {}
    for key, value in pairs(phrase) do
        copy[key] = value
    end
    return copy
end

local function AddCatalogPhrase(phrase, includedIds)
    if type(phrase) ~= "table" or not phrase.id or phrase.id == "" or includedIds[phrase.id] then
        return
    end

    phrase.catalogIndex = #catalogPhrases + 1
    table.insert(catalogPhrases, phrase)
    phraseById[phrase.id] = phrase
    includedIds[phrase.id] = true
end

local function BuildPhraseCatalog()
    wipe(catalogPhrases)
    wipe(phraseById)

    local includedIds = {}
    for _, phrase in ipairs(PHRASE_CATALOG) do
        AddCatalogPhrase(CopyPhrase(phrase), includedIds)
    end

    if type(db.phrases) == "table" then
        for _, phrase in ipairs(db.phrases) do
            local phraseId = type(phrase) == "table" and phrase.id
            if phraseId and phraseId ~= "" and not RETIRED_CATALOG_IDS[phraseId] then
                AddCatalogPhrase(CopyPhrase(phrase), includedIds)
            end
        end
    end
end

local function NormalizeSlots()
    local sourceSlots = {}

    if type(db.slots) == "table" then
        sourceSlots = db.slots
    elseif type(db.phrases) == "table" then
        for _, phrase in ipairs(db.phrases) do
            if type(phrase) == "table" and phrase.id and phrase.id ~= "" and not RETIRED_CATALOG_IDS[phrase.id] then
                table.insert(sourceSlots, phrase.id)
            end
        end
    end

    local normalized = {}
    for index = 1, SLOT_COUNT do
        local phraseId = sourceSlots[index]
        if phraseId == "" then
            normalized[index] = ""
        elseif phraseId and phraseById[phraseId] then
            normalized[index] = phraseId
        elseif DEFAULT_SLOT_IDS[index] and phraseById[DEFAULT_SLOT_IDS[index]] then
            normalized[index] = DEFAULT_SLOT_IDS[index]
        else
            normalized[index] = ""
        end
    end

    db.slots = normalized
end

local function GetSlotPhrase(index)
    index = tonumber(index)
    if not index or not db or type(db.slots) ~= "table" then
        return nil
    end

    local phraseId = db.slots[index]
    if not phraseId or phraseId == "" then
        return nil
    end
    return phraseById[phraseId]
end

local function ApplyWheelPlacement()
    if not wheel or not db then
        return
    end

    db.scale = Clamp(db.scale, 0.6, 1.6) or DEFAULTS.scale
    db.pointX = tonumber(db.pointX) or DEFAULTS.pointX
    db.pointY = tonumber(db.pointY) or DEFAULTS.pointY

    wheel:SetScale(db.scale)
    wheel:ClearAllPoints()
    wheel:SetPoint("CENTER", UIParent, "CENTER", db.pointX, db.pointY)
end

local function SaveWheelPosition()
    if not wheel or not db then
        return
    end

    local wheelX, wheelY = wheel:GetCenter()
    local parentX, parentY = UIParent:GetCenter()
    if not wheelX or not wheelY or not parentX or not parentY then
        return
    end

    db.pointX = math.floor((wheelX - parentX) + 0.5)
    db.pointY = math.floor((wheelY - parentY) + 0.5)
    Print("voice wheel center = " .. db.pointX .. ", " .. db.pointY)
end

function Print(message)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffThreeBodyHelper Voice|r " .. tostring(message))
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
        local ok, willPlay = pcall(PlaySoundFile, path, phrase.channel or db.soundChannel or DEFAULTS.soundChannel)
        if ok and willPlay then
            return true
        end
    end

    if phrase.soundKitID and PlaySound then
        local ok, willPlay = pcall(PlaySound, phrase.soundKitID, phrase.channel or db.soundChannel or DEFAULTS.soundChannel)
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

    local phrase = GetSlotPhrase(index)
    if not phrase then
        if not fromRemote then
            Print("voice wheel slot is empty")
        end
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

wheel = CreateFrame("Frame", "ThreeBodyHelperVoiceWheelFrame", UIParent)
wheel:SetSize(560, 560)
wheel:SetPoint("CENTER")
wheel:SetFrameStrata("DIALOG")
wheel:EnableMouse(true)
wheel:SetMovable(true)
wheel:RegisterForDrag("LeftButton")
wheel:SetScript("OnMouseDown", function(_, button)
    if button == "RightButton" then
        wheel:Hide()
    end
end)
wheel:SetScript("OnDragStart", function()
    if db and db.moveUnlocked then
        wheel:StartMoving()
    end
end)
wheel:SetScript("OnDragStop", function()
    if db and db.moveUnlocked then
        wheel:StopMovingOrSizing()
        SaveWheelPosition()
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
wheel.centerSubText:SetText("点击发送，配置里解锁移动，右键关闭")

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

    local phrase = index and GetSlotPhrase(index)
    wheel.centerText:SetText((phrase and (phrase.text or phrase.label or phrase.id)) or "语音轮盘")
end

local function LayoutButtons()
    for _, button in ipairs(buttons) do
        button:Hide()
    end

    if not db or type(db.slots) ~= "table" then
        return
    end

    local count = SLOT_COUNT
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

        local phrase = GetSlotPhrase(i)
        local angle = ((i - 1) / count) * math.pi * 2 - math.pi / 2
        button.index = i
        button.text:SetText((phrase and (phrase.label or phrase.text or phrase.id)) or "空")
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

function VoiceWheel.SetSlot(index, phraseId)
    index = tonumber(index)
    phraseId = strtrim(phraseId or "")
    if not index or index < 1 or index > SLOT_COUNT then
        Print("slot must be a number from 1 to " .. SLOT_COUNT)
        return
    end
    if phraseId == "" then
        Print("phrase id is required")
        return
    end
    if not phraseById[phraseId] then
        Print("unknown phrase id: " .. phraseId)
        return
    end

    db.slots[index] = phraseId
    if wheel:IsShown() then
        LayoutButtons()
    end
    VoiceWheel.RefreshSlotConfig()
    Print("voice wheel slot " .. index .. " = " .. phraseId)
end

function VoiceWheel.ClearSlot(index)
    index = tonumber(index)
    if not index or index < 1 or index > SLOT_COUNT then
        Print("slot must be a number from 1 to " .. SLOT_COUNT)
        return
    end

    db.slots[index] = ""
    if wheel:IsShown() then
        LayoutButtons()
    end
    VoiceWheel.RefreshSlotConfig()
    Print("voice wheel slot " .. index .. " cleared")
end

function VoiceWheel.ResetSlots()
    for index = 1, SLOT_COUNT do
        db.slots[index] = DEFAULT_SLOT_IDS[index] or ""
    end
    if wheel:IsShown() then
        LayoutButtons()
    end
    VoiceWheel.RefreshSlotConfig()
    Print("voice wheel slots reset")
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

local function NormalizeSoundChannel(channel)
    channel = string.upper(strtrim(channel or ""))
    if channel == "MASTER" then
        return "Master"
    end
    if channel == "SFX" or channel == "SOUND" or channel == "EFFECT" or channel == "EFFECTS" then
        return "SFX"
    end
    if channel == "DIALOG" or channel == "DIALOGUE" or channel == "VOICE" then
        return "Dialog"
    end
    if channel == "MUSIC" then
        return "Music"
    end
    if channel == "AMBIENCE" or channel == "AMBIENT" then
        return "Ambience"
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

function VoiceWheel.SetSoundChannel(channel)
    channel = NormalizeSoundChannel(channel)
    if not channel then
        Print("sound channel: master, sfx, dialog, music, ambience")
        return
    end

    db.soundChannel = channel
    Print("voice wheel sound channel = " .. channel)
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

function VoiceWheel.SetScale(value)
    value = Clamp(value, 0.6, 1.6)
    if not value then
        Print("scale must be a number from 0.6 to 1.6")
        return
    end

    db.scale = value
    ApplyWheelPlacement()
    Print("voice wheel scale = " .. db.scale)
end

function VoiceWheel.SetPosition(x, y)
    x = tonumber(x)
    y = tonumber(y)
    if not x or not y then
        Print("position must be two numbers, for example: /mqq voice pos 0 120")
        return
    end

    db.pointX = math.floor(x + 0.5)
    db.pointY = math.floor(y + 0.5)
    ApplyWheelPlacement()
    Print("voice wheel center = " .. db.pointX .. ", " .. db.pointY)
end

function VoiceWheel.ResetPosition(resetScale)
    db.pointX = DEFAULTS.pointX
    db.pointY = DEFAULTS.pointY
    if resetScale then
        db.scale = DEFAULTS.scale
    end
    ApplyWheelPlacement()
    Print("voice wheel layout reset")
end

function VoiceWheel.SetMoveUnlocked(value)
    db.moveUnlocked = value and true or false
    if db.moveUnlocked then
        VoiceWheel.Show()
    elseif wheel:IsShown() then
        SaveWheelPosition()
        VoiceWheel.Hide()
    end
    Print("voice wheel movement: " .. (db.moveUnlocked and "unlocked" or "locked"))
end

local TEXT_CHANNEL_OPTIONS = { "AUTO", "SAY", "PARTY", "RAID", "INSTANCE_CHAT", "GUILD" }
local SOUND_CHANNEL_OPTIONS = { "Dialog", "Master", "SFX", "Music", "Ambience" }

local function NextOption(options, current)
    for index, value in ipairs(options) do
        if value == current then
            return options[(index % #options) + 1]
        end
    end
    return options[1]
end

local function CreateOptionsCheckbox(parent, label, y, getter, setter)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetPoint("TOPLEFT", 22, y)
    check.Text:SetText(label)
    check:SetScript("OnClick", function(self)
        setter(self:GetChecked())
        VoiceWheel.RefreshOptions()
    end)
    table.insert(optionControls, function()
        check:SetChecked(getter())
    end)
end

local function CreateOptionsCycleButton(parent, label, y, getter, setter)
    local text = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("TOPLEFT", 26, y - 7)
    text:SetText(label)

    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(150, 24)
    button:SetPoint("TOPLEFT", 180, y)
    button:SetScript("OnClick", function()
        setter(getter())
        VoiceWheel.RefreshOptions()
    end)
    table.insert(optionControls, function()
        button:SetText(tostring(getter()))
    end)
end

local function CreateOptionsNumber(parent, label, y, getter, setter)
    local text = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("TOPLEFT", 26, y - 7)
    text:SetText(label)

    local editBox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    editBox:SetSize(74, 24)
    editBox:SetPoint("TOPLEFT", 180, y)
    editBox:SetAutoFocus(false)
    editBox:SetNumeric(false)
    editBox:SetScript("OnEnterPressed", function(self)
        setter(self:GetText())
        self:ClearFocus()
        VoiceWheel.RefreshOptions()
    end)
    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        VoiceWheel.RefreshOptions()
    end)

    local applyButton = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    applyButton:SetSize(58, 24)
    applyButton:SetPoint("LEFT", editBox, "RIGHT", 10, 0)
    applyButton:SetText("应用")
    applyButton:SetScript("OnClick", function()
        setter(editBox:GetText())
        editBox:ClearFocus()
        VoiceWheel.RefreshOptions()
    end)

    table.insert(optionControls, function()
        editBox:SetText(tostring(getter()))
    end)
end

local function PhraseMatchesSearch(phrase, search)
    if search == "" then
        return true
    end

    local haystack = string.lower(table.concat({
        tostring(phrase.id or ""),
        tostring(phrase.label or ""),
        tostring(phrase.text or ""),
    }, " "))
    return haystack:find(search, 1, true) ~= nil
end

local function GetFilteredCatalog()
    local filtered = {}
    local search = string.lower(strtrim(catalogSearch or ""))
    for _, phrase in ipairs(catalogPhrases) do
        if PhraseMatchesSearch(phrase, search) then
            table.insert(filtered, phrase)
        end
    end
    return filtered
end

local function EnsureSlotConfigFrame()
    if slotConfigFrame then
        return slotConfigFrame
    end

    slotConfigFrame = CreateFrame("Frame", "ThreeBodyHelperVoiceSlotConfigFrame", UIParent, "BasicFrameTemplateWithInset")
    slotConfigFrame:SetSize(760, 520)
    slotConfigFrame:SetPoint("CENTER")
    slotConfigFrame:SetFrameStrata("DIALOG")
    slotConfigFrame:EnableMouse(true)
    slotConfigFrame:SetMovable(true)
    slotConfigFrame:RegisterForDrag("LeftButton")
    slotConfigFrame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    slotConfigFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)
    slotConfigFrame:Hide()

    slotConfigFrame.title = slotConfigFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    slotConfigFrame.title:SetPoint("TOPLEFT", 16, -10)
    slotConfigFrame.title:SetText("ThreeBodyHelper 语音轮盘配置")

    slotConfigFrame.summary = slotConfigFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    slotConfigFrame.summary:SetPoint("TOPLEFT", 24, -38)
    slotConfigFrame.summary:SetText("")

    slotConfigFrame.hint = slotConfigFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    slotConfigFrame.hint:SetPoint("TOPLEFT", 24, -60)
    slotConfigFrame.hint:SetText("先点选右边槽位，然后在左侧选择想要放入的语音")

    local libraryTitle = slotConfigFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    libraryTitle:SetPoint("TOPLEFT", 24, -88)
    libraryTitle:SetText("语音库搜索")

    local slotTitle = slotConfigFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    slotTitle:SetPoint("TOPLEFT", 440, -88)
    slotTitle:SetText("轮盘 8 个位置")

    slotConfigFrame.searchBox = CreateFrame("EditBox", nil, slotConfigFrame, "InputBoxTemplate")
    slotConfigFrame.searchBox:SetSize(250, 24)
    slotConfigFrame.searchBox:SetPoint("TOPLEFT", 108, -82)
    slotConfigFrame.searchBox:SetAutoFocus(false)
    slotConfigFrame.searchBox:SetScript("OnTextChanged", function(self)
        catalogSearch = self:GetText() or ""
        catalogPage = 1
        VoiceWheel.RefreshSlotConfig()
    end)
    slotConfigFrame.searchBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    for index = 1, 10 do
        local y = -120 - ((index - 1) * 34)
        local row = CreateFrame("Button", nil, slotConfigFrame, "UIPanelButtonTemplate")
        row:SetSize(300, 28)
        row:SetPoint("TOPLEFT", 24, y)
        row:SetScript("OnClick", function(self)
            if self.phraseId then
                VoiceWheel.SetSlot(selectedSlot, self.phraseId)
            end
        end)

        local playButton = CreateFrame("Button", nil, slotConfigFrame, "UIPanelButtonTemplate")
        playButton:SetSize(54, 28)
        playButton:SetPoint("LEFT", row, "RIGHT", 8, 0)
        playButton:SetText("试听")
        playButton:SetScript("OnClick", function(self)
            if self.phraseId and phraseById[self.phraseId] then
                PlayPhrase(phraseById[self.phraseId])
            end
        end)

        catalogRows[index] = {
            row = row,
            playButton = playButton,
        }
    end

    for index = 1, SLOT_COUNT do
        local y = -120 - ((index - 1) * 38)
        local slotButton = CreateFrame("Button", nil, slotConfigFrame, "UIPanelButtonTemplate")
        slotButton:SetSize(250, 30)
        slotButton:SetPoint("TOPLEFT", 440, y)
        slotButton.slotIndex = index
        slotButton:SetScript("OnClick", function(self)
            selectedSlot = self.slotIndex
            VoiceWheel.RefreshSlotConfig()
        end)
        slotButtons[index] = slotButton
    end

    local prevButton = CreateFrame("Button", nil, slotConfigFrame, "UIPanelButtonTemplate")
    prevButton:SetSize(72, 24)
    prevButton:SetPoint("BOTTOMLEFT", 24, 60)
    prevButton:SetText("上一页")
    prevButton:SetScript("OnClick", function()
        catalogPage = math.max(1, catalogPage - 1)
        VoiceWheel.RefreshSlotConfig()
    end)

    local nextButton = CreateFrame("Button", nil, slotConfigFrame, "UIPanelButtonTemplate")
    nextButton:SetSize(72, 24)
    nextButton:SetPoint("LEFT", prevButton, "RIGHT", 10, 0)
    nextButton:SetText("下一页")
    nextButton:SetScript("OnClick", function()
        catalogPage = catalogPage + 1
        VoiceWheel.RefreshSlotConfig()
    end)

    slotConfigFrame.pageText = slotConfigFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    slotConfigFrame.pageText:SetPoint("LEFT", nextButton, "RIGHT", 12, 0)
    slotConfigFrame.pageText:SetText("")

    local previewButton = CreateFrame("Button", nil, slotConfigFrame, "UIPanelButtonTemplate")
    previewButton:SetSize(82, 24)
    previewButton:SetPoint("BOTTOMLEFT", 440, 98)
    previewButton:SetText("试听槽位")
    previewButton:SetScript("OnClick", function()
        local phrase = GetSlotPhrase(selectedSlot)
        if phrase then
            PlayPhrase(phrase)
        else
            Print("voice wheel slot is empty")
        end
    end)

    local clearButton = CreateFrame("Button", nil, slotConfigFrame, "UIPanelButtonTemplate")
    clearButton:SetSize(82, 24)
    clearButton:SetPoint("LEFT", previewButton, "RIGHT", 10, 0)
    clearButton:SetText("清空槽位")
    clearButton:SetScript("OnClick", function()
        VoiceWheel.ClearSlot(selectedSlot)
    end)

    local resetButton = CreateFrame("Button", nil, slotConfigFrame, "UIPanelButtonTemplate")
    resetButton:SetSize(100, 24)
    resetButton:SetPoint("BOTTOMLEFT", 440, 60)
    resetButton:SetText("恢复默认")
    resetButton:SetScript("OnClick", function()
        VoiceWheel.ResetSlots()
    end)

    local wheelButton = CreateFrame("Button", nil, slotConfigFrame, "UIPanelButtonTemplate")
    wheelButton:SetSize(100, 24)
    wheelButton:SetPoint("LEFT", resetButton, "RIGHT", 10, 0)
    wheelButton:SetText("打开轮盘")
    wheelButton:SetScript("OnClick", function()
        VoiceWheel.Show()
    end)

    local closeButton = CreateFrame("Button", nil, slotConfigFrame, "UIPanelButtonTemplate")
    closeButton:SetSize(76, 24)
    closeButton:SetPoint("BOTTOMRIGHT", -24, 22)
    closeButton:SetText("关闭")
    closeButton:SetScript("OnClick", function()
        slotConfigFrame:Hide()
    end)

    return slotConfigFrame
end

function VoiceWheel.RefreshSlotConfig()
    if not slotConfigFrame then
        return
    end

    slotConfigFrame.summary:SetText("语音包: " .. tostring(db.packId or DEFAULTS.packId)
        .. "    槽位: " .. SLOT_COUNT .. "    当前选中: " .. selectedSlot)

    for index, slotButton in ipairs(slotButtons) do
        local phrase = GetSlotPhrase(index)
        local prefix = (index == selectedSlot) and "> " or "  "
        slotButton:SetText(prefix .. index .. ". " .. ((phrase and (phrase.label or phrase.id)) or "空"))
    end

    local filtered = GetFilteredCatalog()
    local pageSize = #catalogRows
    local maxPage = math.max(1, math.ceil(#filtered / pageSize))
    if catalogPage > maxPage then
        catalogPage = maxPage
    end
    if catalogPage < 1 then
        catalogPage = 1
    end

    for rowIndex, controls in ipairs(catalogRows) do
        local phrase = filtered[((catalogPage - 1) * pageSize) + rowIndex]
        if phrase then
            controls.row.phraseId = phrase.id
            controls.playButton.phraseId = phrase.id
            controls.row:SetText(phrase.label or phrase.id)
            controls.row:Show()
            controls.playButton:Show()
        else
            controls.row.phraseId = nil
            controls.playButton.phraseId = nil
            controls.row:Hide()
            controls.playButton:Hide()
        end
    end

    slotConfigFrame.pageText:SetText(catalogPage .. "/" .. maxPage .. "  共 " .. #filtered .. " 条")
end

function VoiceWheel.ShowSlotConfig()
    if not db then
        return
    end

    if optionsFrame and optionsFrame:IsShown() then
        optionsFrame:Hide()
    end
    EnsureSlotConfigFrame()
    VoiceWheel.RefreshSlotConfig()
    slotConfigFrame:Show()
end

local function EnsureOptionsFrame()
    if optionsFrame then
        return optionsFrame
    end

    optionsFrame = CreateFrame("Frame", "ThreeBodyHelperVoiceOptionsFrame", UIParent, "BasicFrameTemplateWithInset")
    optionsFrame:SetSize(390, 520)
    optionsFrame:SetPoint("CENTER")
    optionsFrame:SetFrameStrata("DIALOG")
    optionsFrame:EnableMouse(true)
    optionsFrame:SetMovable(true)
    optionsFrame:RegisterForDrag("LeftButton")
    optionsFrame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    optionsFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)
    optionsFrame:Hide()

    optionsFrame.title = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    optionsFrame.title:SetPoint("TOPLEFT", 16, -10)
    optionsFrame.title:SetText("ThreeBodyHelper 语音轮盘设置")

    local slotConfigButton = CreateFrame("Button", nil, optionsFrame, "UIPanelButtonTemplate")
    slotConfigButton:SetSize(118, 24)
    slotConfigButton:SetPoint("TOPRIGHT", -22, -38)
    slotConfigButton:SetText("配置轮盘语音")
    slotConfigButton:SetScript("OnClick", function()
        VoiceWheel.ShowSlotConfig()
    end)

    CreateOptionsCheckbox(optionsFrame, "接收队友同步语音", -48, function()
        return db.receiveEnabled
    end, function(value)
        db.receiveEnabled = value and true or false
    end)

    CreateOptionsCheckbox(optionsFrame, "发送队友同步消息", -82, function()
        return db.syncEnabled
    end, function(value)
        db.syncEnabled = value and true or false
    end)

    CreateOptionsCheckbox(optionsFrame, "触发时发送聊天文字", -116, function()
        return db.sendText
    end, function(value)
        db.sendText = value and true or false
    end)

    CreateOptionsCheckbox(optionsFrame, "自己本地播放语音", -150, function()
        return db.selfPlay
    end, function(value)
        db.selfPlay = value and true or false
    end)

    CreateOptionsCheckbox(optionsFrame, "解锁轮盘移动", -184, function()
        return db.moveUnlocked
    end, function(value)
        VoiceWheel.SetMoveUnlocked(value)
    end)

    CreateOptionsCycleButton(optionsFrame, "文字频道", -230, function()
        return db.textChannel or DEFAULTS.textChannel
    end, function(current)
        db.textChannel = NextOption(TEXT_CHANNEL_OPTIONS, current)
    end)

    CreateOptionsCycleButton(optionsFrame, "声音通道", -264, function()
        return db.soundChannel or DEFAULTS.soundChannel
    end, function(current)
        db.soundChannel = NextOption(SOUND_CHANNEL_OPTIONS, current)
    end)

    CreateOptionsNumber(optionsFrame, "轮盘缩放", -310, function()
        return db.scale or DEFAULTS.scale
    end, function(value)
        VoiceWheel.SetScale(value)
    end)

    CreateOptionsNumber(optionsFrame, "发送冷却", -344, function()
        return db.sendCooldown or DEFAULTS.sendCooldown
    end, function(value)
        VoiceWheel.SetCooldown("send", value)
    end)

    CreateOptionsNumber(optionsFrame, "全局接收冷却", -378, function()
        return db.globalReceiveCooldown or DEFAULTS.globalReceiveCooldown
    end, function(value)
        VoiceWheel.SetCooldown("global", value)
    end)

    CreateOptionsNumber(optionsFrame, "单人接收冷却", -412, function()
        return db.senderReceiveCooldown or DEFAULTS.senderReceiveCooldown
    end, function(value)
        VoiceWheel.SetCooldown("sender", value)
    end)

    local resetPosButton = CreateFrame("Button", nil, optionsFrame, "UIPanelButtonTemplate")
    resetPosButton:SetSize(100, 24)
    resetPosButton:SetPoint("BOTTOMLEFT", 24, 18)
    resetPosButton:SetText("重置位置")
    resetPosButton:SetScript("OnClick", function()
        VoiceWheel.ResetPosition(false)
        VoiceWheel.RefreshOptions()
    end)

    local resetLayoutButton = CreateFrame("Button", nil, optionsFrame, "UIPanelButtonTemplate")
    resetLayoutButton:SetSize(112, 24)
    resetLayoutButton:SetPoint("LEFT", resetPosButton, "RIGHT", 12, 0)
    resetLayoutButton:SetText("重置布局")
    resetLayoutButton:SetScript("OnClick", function()
        VoiceWheel.ResetPosition(true)
        VoiceWheel.RefreshOptions()
    end)

    local closeButton = CreateFrame("Button", nil, optionsFrame, "UIPanelButtonTemplate")
    closeButton:SetSize(76, 24)
    closeButton:SetPoint("LEFT", resetLayoutButton, "RIGHT", 12, 0)
    closeButton:SetText("关闭")
    closeButton:SetScript("OnClick", function()
        optionsFrame:Hide()
    end)

    return optionsFrame
end

function VoiceWheel.RefreshOptions()
    for _, updater in ipairs(optionControls) do
        updater()
    end
end

function VoiceWheel.ShowOptions()
    if not db then
        return
    end

    EnsureOptionsFrame()
    VoiceWheel.RefreshOptions()
    optionsFrame:Show()
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

    if command == "config" or command == "options" or command == "settings" then
        VoiceWheel.ShowOptions()
        return
    end

    if command == "slots" or command == "slotconfig" or command == "wheelconfig" then
        VoiceWheel.ShowSlotConfig()
        return
    end

    if command == "slot" then
        local slotIndex, phraseId = rest:match("^(%d+)%s*(.-)$")
        slotIndex = tonumber(slotIndex)
        phraseId = strtrim(phraseId or "")
        if not slotIndex then
            Print("slot usage: /mqq voice slot 1 " .. DEFAULT_SLOT_IDS[1])
        elseif phraseId == "" then
            local phrase = GetSlotPhrase(slotIndex)
            Print("slot " .. slotIndex .. " = " .. ((phrase and phrase.id) or "empty"))
        elseif string.lower(phraseId) == "clear" or string.lower(phraseId) == "empty" then
            VoiceWheel.ClearSlot(slotIndex)
        else
            VoiceWheel.SetSlot(slotIndex, phraseId)
        end
        return
    end

    if command == "resetslots" or command == "defaultslots" then
        VoiceWheel.ResetSlots()
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

    if command == "sound" or command == "soundchannel" or command == "sound-channel" then
        if rest == "" then
            Print("voice wheel sound channel: " .. tostring(db.soundChannel or DEFAULTS.soundChannel))
        else
            VoiceWheel.SetSoundChannel(rest)
        end
        return
    end

    if command == "status" then
        Print("enabled=" .. tostring(db.enabled) .. ", receive=" .. tostring(db.receiveEnabled)
            .. ", sync=" .. tostring(db.syncEnabled) .. ", text=" .. tostring(db.sendText))
        Print("pack=" .. tostring(db.packId or DEFAULTS.packId))
        Print("text channel=" .. tostring(db.textChannel or "AUTO"))
        Print("sound channel=" .. tostring(db.soundChannel or DEFAULTS.soundChannel))
        Print("movement=" .. (db.moveUnlocked and "unlocked" or "locked"))
        Print("layout: scale=" .. tostring(db.scale or DEFAULTS.scale)
            .. ", center=" .. tostring(db.pointX or 0) .. "," .. tostring(db.pointY or 0))
        Print("cooldowns: send=" .. tostring(db.sendCooldown)
            .. "s, global=" .. tostring(db.globalReceiveCooldown)
            .. "s, sender=" .. tostring(db.senderReceiveCooldown) .. "s")
        return
    end

    if command == "list" or command == "ids" or command == "catalog" then
        for index, phrase in ipairs(catalogPhrases or {}) do
            Print(index .. ". " .. tostring(phrase.id or "?") .. " -> " .. tostring(phrase.file or ""))
        end
        return
    end

    if command == "slotlist" or command == "listslots" then
        for index = 1, SLOT_COUNT do
            local phrase = GetSlotPhrase(index)
            Print(index .. ". " .. ((phrase and phrase.id) or "empty"))
        end
        return
    end

    if command == "scale" or command == "size" then
        if rest == "" then
            Print("voice wheel scale = " .. tostring(db.scale or DEFAULTS.scale))
        else
            VoiceWheel.SetScale(rest)
        end
        return
    end

    if command == "pos" or command == "position" then
        local x, y = rest:match("^([%-%d%.]+)%s+([%-%d%.]+)$")
        if x and y then
            VoiceWheel.SetPosition(x, y)
        else
            Print("voice wheel center = " .. tostring(db.pointX or 0) .. ", " .. tostring(db.pointY or 0))
        end
        return
    end

    if command == "center" then
        VoiceWheel.SetPosition(0, 0)
        return
    end

    if command == "resetpos" or command == "resetposition" then
        VoiceWheel.ResetPosition(false)
        return
    end

    if command == "resetlayout" then
        VoiceWheel.ResetPosition(true)
        return
    end

    if command == "unlock" or command == "unlockmove" then
        VoiceWheel.SetMoveUnlocked(true)
        return
    end

    if command == "lock" or command == "lockmove" then
        if rest == "off" then
            VoiceWheel.SetMoveUnlocked(true)
        elseif rest == "on" or rest == "" then
            VoiceWheel.SetMoveUnlocked(false)
        else
            Print("voice wheel movement: " .. (db.moveUnlocked and "unlocked" or "locked"))
        end
        return
    end

    if command == "cooldown" or command == "cd" then
        local kind, seconds = rest:match("^(%S+)%s+(%S+)$")
        VoiceWheel.SetCooldown(string.lower(kind or ""), seconds)
        return
    end

    Print("/mqq voice - open wheel")
    Print("/mqq voice config - open settings panel")
    Print("/mqq voice slots - open wheel phrase slot panel")
    Print("/mqq voice slot 1 phrase_id - bind a phrase to a wheel slot")
    Print("/mqq voice slot 1 clear - clear a wheel slot")
    Print("/mqq voice resetslots - restore default wheel slots")
    Print("/mqq voice receive on|off - allow/block teammates' synced voice")
    Print("/mqq voice sync on|off - send addon sync to group")
    Print("/mqq voice text on|off - send normal chat text")
    Print("/mqq voice text auto|say|party|raid|instance|guild - set text channel")
    Print("/mqq voice sound master|sfx|dialog|music|ambience - set sound channel")
    Print("/mqq voice list - show phrase ids and local files")
    Print("/mqq voice scale 0.6-1.6 - set wheel scale")
    Print("/mqq voice pos x y - set wheel center offset")
    Print("/mqq voice unlock|lock - allow/block dragging the wheel")
    Print("/mqq voice center|resetpos|resetlayout - reset layout")
    Print("/mqq voice cooldown global|sender|send seconds")
    Print("/mqq voice send 1-8 - trigger a phrase")
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
    PlayPhrase(phrase)
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
        BuildPhraseCatalog()
        NormalizeSlots()
        ApplyWheelPlacement()
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
