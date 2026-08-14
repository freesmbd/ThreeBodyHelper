local ADDON_NAME = ...

local ThreeBodyHelper = {}
_G.ThreeBodyHelper = ThreeBodyHelper

local DEFAULT_DB = {
    minimap = { hide = false },
    channel = "AUTO",
    battleRes = {
        enabled = true,
    },
    scope = {
        includeParty = false,
    },
    readyAnnounce = {
        enabled = true,
        message = "threebody小工具已就绪！",
        leaderKeywords = {
            "原野之刃",
            "萌奇奇",
        },
    },
    leaderChangeAnnounce = {
        enabled = true,
        message = "为新王的诞生献上礼炮！",
    },
    deathAnnounce = {
        enabled = true,
        keyword = "萌奇奇",
        message = "篡位者，给我倒下！",
    },
    noBattleResDeathAnnounce = {
        enabled = true,
        keyword = "朵拉贡",
        message = "没战复了，先打",
        maxDeadCount = 2,
    },
    chatReply = {
        enabled = true,
        trigger = "我爱酥妈",
        message = "我也是！",
    },
    randomExactChatReply = {
        enabled = true,
        trigger = "串一下",
        messages = {
            "大宝，使不得",
            "我问一下现在法师是不能刷智力了吗？",
            "躲这个技能是有什么困难吗?",
        },
    },
    quickEncounterAnnounce = {
        enabled = true,
        maxDuration = 5,
        message = "牛消",
    },
    messages = {
        "ThreeBody 集合，准备开工。",
        "三体人注意：请保持队形。",
        "面壁者已上线。",
    },
}

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

local function Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffThreeBodyHelper|r " .. tostring(message))
end

local function GetOutputChannel()
    local selected = ThreeBodyHelperDB and ThreeBodyHelperDB.channel or "AUTO"
    if selected == "SAY" then
        return "SAY"
    end
    if selected == "PARTY" then
        return IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and "INSTANCE_CHAT" or "PARTY"
    end
    if selected == "RAID" then
        return IsInRaid() and "RAID" or (IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and "INSTANCE_CHAT" or "PARTY")
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

local function IsPartyScopeEnabled()
    local scope = ThreeBodyHelperDB and ThreeBodyHelperDB.scope
    if scope and scope.includeParty ~= nil then
        return scope.includeParty
    end
    return DEFAULT_DB.scope.includeParty
end

local function IsAnnouncementScopeActive()
    if IsInRaid() then
        return true
    end
    return IsPartyScopeEnabled() and IsInGroup()
end

local function GetAnnouncementChannel()
    if IsInRaid() then
        return "RAID"
    end
    if IsPartyScopeEnabled() and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        return "INSTANCE_CHAT"
    end
    if IsPartyScopeEnabled() and IsInGroup() then
        return "PARTY"
    end
    return nil
end

local function SendTeamMessage(message)
    if not message or message == "" then
        Print("消息为空。")
        return
    end

    if UnitAffectingCombat("player") and C_ChatInfo and C_ChatInfo.SendChatMessage then
        C_ChatInfo.SendChatMessage(message, GetOutputChannel())
    else
        SendChatMessage(message, GetOutputChannel())
    end
end

local wasInRaid = false
local checkedCurrentRaid = false
local readyStateInitialized = false
local currentRaidLeaderKey = nil
local GetBattleResInfo
local currentEncounterStartTime = nil
local currentEncounterID = nil

local function SendRaidMessage(message)
    local channel = GetAnnouncementChannel()
    if not message or message == "" or not channel then
        return
    end

    if UnitAffectingCombat("player") and C_ChatInfo and C_ChatInfo.SendChatMessage then
        C_ChatInfo.SendChatMessage(message, channel)
    else
        SendChatMessage(message, channel)
    end
end

local function GetUnitFullName(unit)
    local name, realm = UnitName(unit)
    if not name then
        return nil
    end
    return realm and realm ~= "" and (name .. "-" .. realm) or name
end

local function ForEachAnnouncementScopeUnit(callback)
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            if callback("raid" .. i) then
                return true
            end
        end
    elseif IsPartyScopeEnabled() and IsInGroup() then
        if callback("player") then
            return true
        end
        for i = 1, GetNumSubgroupMembers() do
            if callback("party" .. i) then
                return true
            end
        end
    end
    return false
end

local function GetRaidLeaderNameAndKey()
    if not IsAnnouncementScopeActive() then
        return nil, nil
    end

    local foundName, foundKey
    ForEachAnnouncementScopeUnit(function(unit)
        if UnitIsGroupLeader(unit) then
            foundName = GetUnitFullName(unit)
            foundKey = foundName and (UnitGUID(unit) or foundName) or nil
            return foundName ~= nil
        end
        return false
    end)

    return foundName, foundKey
end

local function GetRaidLeaderName()
    local leaderName = GetRaidLeaderNameAndKey()
    return leaderName
end

local function LeaderMatchesReadyRule(leaderName)
    local config = ThreeBodyHelperDB and ThreeBodyHelperDB.readyAnnounce
    local keywords = config and config.leaderKeywords or DEFAULT_DB.readyAnnounce.leaderKeywords
    for _, keyword in ipairs(keywords) do
        if leaderName and leaderName:find(keyword, 1, true) then
            return true
        end
    end
    return false
end

local function TryReadyAnnouncement()
    local config = ThreeBodyHelperDB and ThreeBodyHelperDB.readyAnnounce
    if not config or not config.enabled then
        return
    end

    if not IsAnnouncementScopeActive() then
        return
    end

    local leaderName = GetRaidLeaderName()
    if not leaderName then
        return
    end

    if LeaderMatchesReadyRule(leaderName) then
        SendRaidMessage(config.message or DEFAULT_DB.readyAnnounce.message)
    end
end

local function TryLeaderChangeAnnouncement(leaderName)
    local config = ThreeBodyHelperDB and ThreeBodyHelperDB.leaderChangeAnnounce
    if not config or not config.enabled then
        return
    end

    if LeaderMatchesReadyRule(leaderName) then
        SendRaidMessage(config.message or DEFAULT_DB.leaderChangeAnnounce.message)
    end
end

local function TryQuickEncounterAnnouncement(duration)
    local config = ThreeBodyHelperDB and ThreeBodyHelperDB.quickEncounterAnnounce
    if not config or not config.enabled then
        return
    end

    if not IsAnnouncementScopeActive() then
        return
    end

    local leaderName = GetRaidLeaderName()
    if not LeaderMatchesReadyRule(leaderName) then
        return
    end

    local maxDuration = config.maxDuration or DEFAULT_DB.quickEncounterAnnounce.maxDuration
    if duration and duration < maxDuration then
        SendRaidMessage(config.message or DEFAULT_DB.quickEncounterAnnounce.message)
    end
end

local function IsMatchingRaidMemberDeath(destGUID, destName, keyword)
    if not destName or not keyword or not destName:find(keyword, 1, true) then
        return false
    end

    local matched = false
    ForEachAnnouncementScopeUnit(function(unit)
        local memberName = GetUnitFullName(unit)
        if memberName and memberName:find(keyword, 1, true) then
            local memberGUID = UnitGUID(unit)
            local shortName = memberName:match("^[^-]+")
            if memberGUID and destGUID and memberGUID == destGUID then
                matched = true
                return true
            end
            if destName == memberName or destName == shortName then
                matched = true
                return true
            end
        end
        return false
    end)

    return matched
end

local function TryDeathAnnouncement(destGUID, destName)
    local config = ThreeBodyHelperDB and ThreeBodyHelperDB.deathAnnounce
    if not config or not config.enabled then
        return
    end

    if not IsAnnouncementScopeActive() or not UnitAffectingCombat("player") then
        return
    end

    local keyword = config.keyword or DEFAULT_DB.deathAnnounce.keyword
    if IsMatchingRaidMemberDeath(destGUID, destName, keyword) then
        SendRaidMessage(config.message or DEFAULT_DB.deathAnnounce.message)
    end
end

local function CountDeadRaidMembers()
    local deadCount = 0
    ForEachAnnouncementScopeUnit(function(unit)
        if UnitIsDeadOrGhost(unit) then
            deadCount = deadCount + 1
        end
        return false
    end)
    return deadCount
end

local function TryNoBattleResDeathAnnouncement(destGUID, destName)
    local config = ThreeBodyHelperDB and ThreeBodyHelperDB.noBattleResDeathAnnounce
    if not config or not config.enabled then
        return
    end

    if not IsAnnouncementScopeActive() or not UnitAffectingCombat("player") then
        return
    end

    local keyword = config.keyword or DEFAULT_DB.noBattleResDeathAnnounce.keyword
    if not IsMatchingRaidMemberDeath(destGUID, destName, keyword) then
        return
    end

    local currentBattleRes = GetBattleResInfo and GetBattleResInfo()
    if currentBattleRes == 0 and CountDeadRaidMembers() <= (config.maxDeadCount or DEFAULT_DB.noBattleResDeathAnnounce.maxDeadCount) then
        SendRaidMessage(config.message or DEFAULT_DB.noBattleResDeathAnnounce.message)
    end
end

local function HandleCombatLogEvent()
    local _, subEvent, _, _, _, _, _, destGUID, destName = CombatLogGetCurrentEventInfo()
    if subEvent == "UNIT_DIED" then
        TryDeathAnnouncement(destGUID, destName)
        C_Timer.After(0.2, function()
            TryNoBattleResDeathAnnouncement(destGUID, destName)
        end)
    end
end

local function IsGroupChatEvent(event)
    return event == "CHAT_MSG_RAID" or event == "CHAT_MSG_RAID_LEADER"
        or event == "CHAT_MSG_PARTY" or event == "CHAT_MSG_PARTY_LEADER"
        or event == "CHAT_MSG_INSTANCE_CHAT" or event == "CHAT_MSG_INSTANCE_CHAT_LEADER"
end

local function IsWatchedChatEvent(event)
    if event == "CHAT_MSG_RAID" or event == "CHAT_MSG_RAID_LEADER" then
        return IsInRaid()
    end

    if event == "CHAT_MSG_PARTY" or event == "CHAT_MSG_PARTY_LEADER"
        or event == "CHAT_MSG_INSTANCE_CHAT" or event == "CHAT_MSG_INSTANCE_CHAT_LEADER" then
        return not IsInRaid() and IsPartyScopeEnabled() and IsInGroup()
    end

    return false
end

local function HandleGroupChatEvent(event, text)
    if not IsWatchedChatEvent(event) then
        return
    end

    local randomConfig = ThreeBodyHelperDB and ThreeBodyHelperDB.randomExactChatReply or DEFAULT_DB.randomExactChatReply
    if randomConfig and randomConfig.enabled then
        local trigger = randomConfig.trigger or DEFAULT_DB.randomExactChatReply.trigger
        local pool = randomConfig.messages or DEFAULT_DB.randomExactChatReply.messages
        if text == trigger and pool and #pool > 0 then
            SendRaidMessage(pool[random(#pool)])
        end
    end

    local config = ThreeBodyHelperDB and ThreeBodyHelperDB.chatReply or DEFAULT_DB.chatReply
    if not config or not config.enabled then
        return
    end

    if UnitAffectingCombat("player") then
        return
    end

    local trigger = config.trigger or DEFAULT_DB.chatReply.trigger
    if text and trigger and text:find(trigger, 1, true) then
        SendRaidMessage(config.message or DEFAULT_DB.chatReply.message)
    end
end

local function HandleEncounterStart(encounterID)
    currentEncounterID = encounterID
    currentEncounterStartTime = GetTime()
end

local function HandleEncounterEnd(encounterID)
    if not currentEncounterStartTime or currentEncounterID ~= encounterID then
        currentEncounterStartTime = nil
        currentEncounterID = nil
        return
    end

    local duration = GetTime() - currentEncounterStartTime
    currentEncounterStartTime = nil
    currentEncounterID = nil
    TryQuickEncounterAnnouncement(duration)
end

local function ScheduleReadyAnnouncementCheck()
    if checkedCurrentRaid then
        return
    end

    checkedCurrentRaid = true
    C_Timer.After(2, TryReadyAnnouncement)
end

local function InitializeReadyAnnouncementState()
    wasInRaid = IsAnnouncementScopeActive()
    checkedCurrentRaid = wasInRaid
    readyStateInitialized = true
end

local function InitializeLeaderChangeAnnouncementState()
    if not IsAnnouncementScopeActive() then
        currentRaidLeaderKey = nil
        return
    end

    local _, leaderKey = GetRaidLeaderNameAndKey()
    currentRaidLeaderKey = leaderKey
end

local function UpdateReadyAnnouncementState()
    if not readyStateInitialized then
        InitializeReadyAnnouncementState()
        return
    end

    local isInRaid = IsAnnouncementScopeActive()
    if isInRaid and not wasInRaid then
        checkedCurrentRaid = false
        ScheduleReadyAnnouncementCheck()
    elseif not isInRaid and wasInRaid then
        checkedCurrentRaid = false
    end
    wasInRaid = isInRaid
end

local function UpdateLeaderChangeAnnouncementState()
    if not IsAnnouncementScopeActive() then
        currentRaidLeaderKey = nil
        return
    end

    local leaderName, leaderKey = GetRaidLeaderNameAndKey()
    if not leaderKey then
        return
    end

    if not currentRaidLeaderKey then
        currentRaidLeaderKey = leaderKey
        return
    end

    if leaderKey ~= currentRaidLeaderKey then
        currentRaidLeaderKey = leaderKey
        TryLeaderChangeAnnouncement(leaderName)
    end
end

function GetBattleResInfo()
    if not C_Spell or not C_Spell.GetSpellCharges then
        return nil
    end

    local chargeInfo = C_Spell.GetSpellCharges(20484) -- Rebirth: shared combat resurrection pool
    if not chargeInfo then
        return nil
    end

    local current = chargeInfo.currentCharges or 0
    local maximum = chargeInfo.maxCharges or 0
    local startTime = chargeInfo.cooldownStartTime or 0
    local duration = chargeInfo.cooldownDuration or 0
    local remaining = 0

    if current < maximum and duration > 0 and startTime > 0 then
        remaining = math.max(0, duration - (GetTime() - startTime))
    end

    return current, maximum, remaining
end

local function FormatTimer(seconds)
    seconds = math.max(0, math.floor(seconds or 0))
    return ("%d:%02d"):format(math.floor(seconds / 60), seconds % 60)
end

local frame = CreateFrame("Frame", "ThreeBodyHelperFrame", UIParent, "BasicFrameTemplateWithInset")
frame:SetSize(360, 280)
frame:SetPoint("CENTER")
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
frame:Hide()

frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
frame.title:SetPoint("LEFT", frame.TitleBg, "LEFT", 6, 0)
frame.title:SetText("ThreeBodyHelper")

frame.subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
frame.subtitle:SetPoint("TOPLEFT", 18, -38)
frame.subtitle:SetText("团队娱乐交互助手")

frame.editBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
frame.editBox:SetSize(285, 28)
frame.editBox:SetPoint("TOPLEFT", 25, -72)
frame.editBox:SetAutoFocus(false)
frame.editBox:SetText(DEFAULT_DB.messages[1])
frame.editBox:SetScript("OnEnterPressed", function(self)
    SendTeamMessage(self:GetText())
    self:ClearFocus()
end)

frame.sendButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
frame.sendButton:SetSize(90, 26)
frame.sendButton:SetPoint("TOPLEFT", 25, -112)
frame.sendButton:SetText("发送")
frame.sendButton:SetScript("OnClick", function()
    SendTeamMessage(frame.editBox:GetText())
end)

frame.randomButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
frame.randomButton:SetSize(90, 26)
frame.randomButton:SetPoint("LEFT", frame.sendButton, "RIGHT", 12, 0)
frame.randomButton:SetText("随机台词")
frame.randomButton:SetScript("OnClick", function()
    local messages = ThreeBodyHelperDB and ThreeBodyHelperDB.messages or DEFAULT_DB.messages
    frame.editBox:SetText(messages[random(#messages)])
end)

frame.localButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
frame.localButton:SetSize(90, 26)
frame.localButton:SetPoint("LEFT", frame.randomButton, "RIGHT", 12, 0)
frame.localButton:SetText("本地预览")
frame.localButton:SetScript("OnClick", function()
    Print(frame.editBox:GetText())
end)

frame.battleResText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
frame.battleResText:SetPoint("TOPLEFT", 25, -150)
frame.battleResText:SetWidth(310)
frame.battleResText:SetJustifyH("LEFT")
frame.battleResText:SetText("战复：未检测到共享次数")

frame.scopeCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
frame.scopeCheck:SetPoint("TOPLEFT", 20, -174)
frame.scopeCheck.label = frame.scopeCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
frame.scopeCheck.label:SetPoint("LEFT", frame.scopeCheck, "RIGHT", 2, 0)
frame.scopeCheck.label:SetText("小队中也生效")
frame.scopeCheck:SetScript("OnClick", function(self)
    ThreeBodyHelper.SetPartyScopeEnabled(self:GetChecked())
end)

frame.help = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
frame.help:SetPoint("TOPLEFT", 25, -208)
frame.help:SetWidth(310)
frame.help:SetJustifyH("LEFT")
frame.help:SetText("/mqq 打开/关闭；/mqq send 文本 发送；/mqq brez 查看战复；/mqq channel auto|say|party|raid 设置频道。")

local battleResFrame = CreateFrame("Frame", "ThreeBodyHelperBattleResFrame", UIParent, "BackdropTemplate")
battleResFrame:SetSize(112, 42)
battleResFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 180)
battleResFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
battleResFrame:SetMovable(true)
battleResFrame:EnableMouse(true)
battleResFrame:RegisterForDrag("LeftButton")
battleResFrame:SetScript("OnDragStart", battleResFrame.StartMoving)
battleResFrame:SetScript("OnDragStop", battleResFrame.StopMovingOrSizing)
battleResFrame:Hide()

battleResFrame.title = battleResFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
battleResFrame.title:SetPoint("TOP", 0, -8)
battleResFrame.title:SetText("战斗复活")

battleResFrame.count = battleResFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
battleResFrame.count:SetPoint("BOTTOMLEFT", 14, 8)
battleResFrame.count:SetText("0/0")

battleResFrame.timer = battleResFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
battleResFrame.timer:SetPoint("BOTTOMRIGHT", -12, 9)
battleResFrame.timer:SetText("")

local function UpdateBattleResDisplay()
    local current, maximum, remaining = GetBattleResInfo()
    local enabled = ThreeBodyHelperDB and ThreeBodyHelperDB.battleRes and ThreeBodyHelperDB.battleRes.enabled

    if current then
        local text = ("战复：%d / %d"):format(current, maximum)
        if remaining and remaining > 0 then
            text = text .. "，下次 " .. FormatTimer(remaining)
        end
        frame.battleResText:SetText(text)
        battleResFrame.count:SetText(("%d/%d"):format(current, maximum))
        battleResFrame.timer:SetText(remaining and remaining > 0 and FormatTimer(remaining) or "")
        if current == 0 then
            battleResFrame.count:SetTextColor(1, 0.15, 0.15)
        elseif current == maximum then
            battleResFrame.count:SetTextColor(0.2, 1, 0.2)
        else
            battleResFrame.count:SetTextColor(1, 0.85, 0.15)
        end
    else
        frame.battleResText:SetText("战复：当前场景未提供共享次数")
        battleResFrame.count:SetText("0/0")
        battleResFrame.timer:SetText("")
        battleResFrame.count:SetTextColor(1, 1, 1)
    end

    if enabled and current and UnitAffectingCombat("player") and IsInGroup() then
        battleResFrame:Show()
    else
        battleResFrame:Hide()
    end
end

local function UpdateScopeControls()
    if frame and frame.scopeCheck then
        frame.scopeCheck:SetChecked(IsPartyScopeEnabled())
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("SPELL_UPDATE_CHARGES")
eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
eventFrame:RegisterEvent("CHAT_MSG_RAID")
eventFrame:RegisterEvent("CHAT_MSG_RAID_LEADER")
eventFrame:RegisterEvent("CHAT_MSG_PARTY")
eventFrame:RegisterEvent("CHAT_MSG_PARTY_LEADER")
eventFrame:RegisterEvent("CHAT_MSG_INSTANCE_CHAT")
eventFrame:RegisterEvent("CHAT_MSG_INSTANCE_CHAT_LEADER")
eventFrame:RegisterEvent("ENCOUNTER_START")
eventFrame:RegisterEvent("ENCOUNTER_END")
eventFrame:SetScript("OnEvent", function(_, event, addonName, ...)
    if event == "ADDON_LOADED" and addonName ~= ADDON_NAME then
        return
    end

    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        HandleCombatLogEvent()
        return
    end

    if IsGroupChatEvent(event) then
        HandleGroupChatEvent(event, addonName)
        return
    end

    if event == "ENCOUNTER_START" then
        HandleEncounterStart(addonName)
        return
    end

    if event == "ENCOUNTER_END" then
        HandleEncounterEnd(addonName)
        return
    end

    if event == "ADDON_LOADED" then
        ThreeBodyHelperDB = CopyDefaults(DEFAULT_DB, ThreeBodyHelperDB)
        randomseed(time())
        Print("已加载，输入 /mqq 打开面板。")
        UpdateScopeControls()
        InitializeReadyAnnouncementState()
        InitializeLeaderChangeAnnouncementState()
    end

    if event == "PLAYER_ENTERING_WORLD" then
        InitializeReadyAnnouncementState()
        InitializeLeaderChangeAnnouncementState()
    elseif event == "GROUP_ROSTER_UPDATE" then
        UpdateReadyAnnouncementState()
        UpdateLeaderChangeAnnouncementState()
    end

    UpdateBattleResDisplay()
end)
eventFrame:SetScript("OnUpdate", function(_, elapsed)
    eventFrame.elapsed = (eventFrame.elapsed or 0) + elapsed
    if eventFrame.elapsed < 0.5 then
        return
    end

    eventFrame.elapsed = 0
    UpdateBattleResDisplay()
end)

function ThreeBodyHelper.Toggle()
    UpdateScopeControls()
    frame:SetShown(not frame:IsShown())
end

function ThreeBodyHelper.SetChannel(channel)
    channel = channel and channel:upper() or "AUTO"
    if channel ~= "AUTO" and channel ~= "SAY" and channel ~= "PARTY" and channel ~= "RAID" then
        Print("频道可选：auto, say, party, raid。")
        return
    end

    ThreeBodyHelperDB.channel = channel
    Print("默认频道已设置为 " .. channel .. "。")
end

function ThreeBodyHelper.PrintBattleRes()
    local current, maximum, remaining = GetBattleResInfo()
    if not current then
        Print("当前场景没有可用的共享战复次数数据。需要在团队/副本战斗中检测。")
        return
    end

    local text = ("当前战复：%d / %d"):format(current, maximum)
    if remaining and remaining > 0 then
        text = text .. "，下次恢复 " .. FormatTimer(remaining)
    end
    Print(text)
end

function ThreeBodyHelper.SetBattleResEnabled(value)
    ThreeBodyHelperDB.battleRes.enabled = value
    UpdateBattleResDisplay()
    Print("战复小窗已" .. (value and "开启" or "关闭") .. "。")
end

function ThreeBodyHelper.SetReadyAnnounceEnabled(value)
    ThreeBodyHelperDB.readyAnnounce.enabled = value
    if not value then
        checkedCurrentRaid = true
    elseif IsAnnouncementScopeActive() then
        checkedCurrentRaid = true
    end
    Print("入团就绪自动喊话已" .. (value and "开启" or "关闭") .. "。")
end

function ThreeBodyHelper.SetLeaderChangeAnnounceEnabled(value)
    ThreeBodyHelperDB.leaderChangeAnnounce.enabled = value
    InitializeLeaderChangeAnnouncementState()
    Print("新团长礼炮自动喊话已" .. (value and "开启" or "关闭") .. "。")
end

function ThreeBodyHelper.SetDeathAnnounceEnabled(value)
    ThreeBodyHelperDB.deathAnnounce.enabled = value
    Print("萌奇奇死亡自动喊话已" .. (value and "开启" or "关闭") .. "。")
end

function ThreeBodyHelper.SetNoBattleResDeathAnnounceEnabled(value)
    ThreeBodyHelperDB.noBattleResDeathAnnounce.enabled = value
    Print("无战复朵拉贡死亡自动喊话已" .. (value and "开启" or "关闭") .. "。")
end

function ThreeBodyHelper.SetChatReplyEnabled(value)
    ThreeBodyHelperDB.chatReply.enabled = value
    Print("我爱酥妈自动回复已" .. (value and "开启" or "关闭") .. "。")
end

function ThreeBodyHelper.SetRandomExactChatReplyEnabled(value)
    ThreeBodyHelperDB.randomExactChatReply.enabled = value
    Print("串一下随机回复已" .. (value and "开启" or "关闭") .. "。")
end

function ThreeBodyHelper.SetQuickEncounterAnnounceEnabled(value)
    ThreeBodyHelperDB.quickEncounterAnnounce.enabled = value
    Print("快速首领战斗自动喊话已" .. (value and "开启" or "关闭") .. "。")
end

function ThreeBodyHelper.SetPartyScopeEnabled(value)
    ThreeBodyHelperDB.scope.includeParty = value and true or false
    UpdateScopeControls()
    InitializeReadyAnnouncementState()
    InitializeLeaderChangeAnnouncementState()
    Print("小队生效范围已" .. (ThreeBodyHelperDB.scope.includeParty and "开启" or "关闭") .. "。")
end

local function HandleSlash(input)
    input = strtrim(input or "")
    local command, rest = input:match("^(%S*)%s*(.-)$")
    command = string.lower(command or "")

    if command == "" or command == "show" or command == "toggle" then
        ThreeBodyHelper.Toggle()
        return
    end

    if command == "voice" or command == "wheel" or command == "vw" then
        if ThreeBodyHelper.VoiceWheel and ThreeBodyHelper.VoiceWheel.HandleSlash then
            ThreeBodyHelper.VoiceWheel.HandleSlash(rest)
        else
            Print("Voice wheel module is not loaded.")
        end
        return
    end

    if command == "send" then
        SendTeamMessage(rest)
        return
    end

    if command == "channel" then
        ThreeBodyHelper.SetChannel(rest)
        return
    end

    if command == "brez" or command == "battle" or command == "res" then
        rest = string.lower(strtrim(rest or ""))
        if rest == "on" or rest == "show" then
            ThreeBodyHelper.SetBattleResEnabled(true)
        elseif rest == "off" or rest == "hide" then
            ThreeBodyHelper.SetBattleResEnabled(false)
        else
            ThreeBodyHelper.PrintBattleRes()
        end
        return
    end

    if command == "ready" then
        rest = string.lower(strtrim(rest or ""))
        if rest == "on" then
            ThreeBodyHelper.SetReadyAnnounceEnabled(true)
        elseif rest == "off" then
            ThreeBodyHelper.SetReadyAnnounceEnabled(false)
        else
            local config = ThreeBodyHelperDB.readyAnnounce
            Print("入团就绪自动喊话：" .. (config.enabled and "开启" or "关闭"))
            Print("匹配团长：原野之刃 / 萌奇奇；喊话：" .. config.message)
        end
        return
    end

    if command == "king" or command == "leader" then
        rest = string.lower(strtrim(rest or ""))
        if rest == "on" then
            ThreeBodyHelper.SetLeaderChangeAnnounceEnabled(true)
        elseif rest == "off" then
            ThreeBodyHelper.SetLeaderChangeAnnounceEnabled(false)
        else
            local config = ThreeBodyHelperDB.leaderChangeAnnounce
            Print("新团长礼炮自动喊话：" .. (config.enabled and "开启" or "关闭"))
            Print("匹配新团长：原野之刃 / 萌奇奇；喊话：" .. config.message)
        end
        return
    end

    if command == "death" then
        rest = string.lower(strtrim(rest or ""))
        if rest == "on" then
            ThreeBodyHelper.SetDeathAnnounceEnabled(true)
        elseif rest == "off" then
            ThreeBodyHelper.SetDeathAnnounceEnabled(false)
        else
            local config = ThreeBodyHelperDB.deathAnnounce
            Print("萌奇奇死亡自动喊话：" .. (config.enabled and "开启" or "关闭"))
            Print("匹配名字包含：" .. config.keyword .. "；喊话：" .. config.message)
        end
        return
    end

    if command == "nobrez" then
        rest = string.lower(strtrim(rest or ""))
        if rest == "on" then
            ThreeBodyHelper.SetNoBattleResDeathAnnounceEnabled(true)
        elseif rest == "off" then
            ThreeBodyHelper.SetNoBattleResDeathAnnounceEnabled(false)
        else
            local config = ThreeBodyHelperDB.noBattleResDeathAnnounce
            Print("无战复朵拉贡死亡自动喊话：" .. (config.enabled and "开启" or "关闭"))
            Print("匹配名字包含：" .. config.keyword .. "；死亡人数不超过：" .. config.maxDeadCount .. "；喊话：" .. config.message)
        end
        return
    end

    if command == "love" then
        rest = string.lower(strtrim(rest or ""))
        if rest == "on" then
            ThreeBodyHelper.SetChatReplyEnabled(true)
        elseif rest == "off" then
            ThreeBodyHelper.SetChatReplyEnabled(false)
        else
            local config = ThreeBodyHelperDB.chatReply
            Print("我爱酥妈自动回复：" .. (config.enabled and "开启" or "关闭"))
            Print("触发字符串：" .. config.trigger .. "；回复：" .. config.message)
        end
        return
    end

    if command == "chuan" then
        rest = string.lower(strtrim(rest or ""))
        if rest == "on" then
            ThreeBodyHelper.SetRandomExactChatReplyEnabled(true)
        elseif rest == "off" then
            ThreeBodyHelper.SetRandomExactChatReplyEnabled(false)
        else
            local config = ThreeBodyHelperDB.randomExactChatReply
            Print("串一下随机回复：" .. (config.enabled and "开启" or "关闭"))
            Print("精确触发：" .. config.trigger .. "；池子数量：" .. #config.messages)
        end
        return
    end

    if command == "quick" or command == "boss" then
        rest = string.lower(strtrim(rest or ""))
        if rest == "on" then
            ThreeBodyHelper.SetQuickEncounterAnnounceEnabled(true)
        elseif rest == "off" then
            ThreeBodyHelper.SetQuickEncounterAnnounceEnabled(false)
        else
            local config = ThreeBodyHelperDB.quickEncounterAnnounce
            Print("快速首领战斗自动喊话：" .. (config.enabled and "开启" or "关闭"))
            Print("阈值：" .. config.maxDuration .. "秒；喊话：" .. config.message)
        end
        return
    end

    if command == "scope" then
        rest = string.lower(strtrim(rest or ""))
        if rest == "party on" or rest == "party" or rest == "on" then
            ThreeBodyHelper.SetPartyScopeEnabled(true)
        elseif rest == "party off" or rest == "off" then
            ThreeBodyHelper.SetPartyScopeEnabled(false)
        else
            Print("当前范围：团队默认生效；小队生效=" .. (IsPartyScopeEnabled() and "开启" or "关闭"))
            Print("可用命令：/mqq scope party on|off")
        end
        return
    end

    if command == "help" then
        Print("/mqq - 打开或关闭面板")
        Print("/mqq send 文本 - 向自动频道发送文本")
        Print("/mqq brez - 查看当前共享战复次数")
        Print("/mqq brez on|off - 开关战复小窗")
        Print("/mqq ready on|off - 开关入团就绪自动喊话")
        Print("/mqq king on|off - 开关新团长礼炮自动喊话")
        Print("/mqq death on|off - 开关萌奇奇死亡自动喊话")
        Print("/mqq nobrez on|off - 开关无战复朵拉贡死亡自动喊话")
        Print("/mqq love on|off - 开关我爱酥妈自动回复")
        Print("/mqq chuan on|off - 开关串一下随机回复")
        Print("/mqq quick on|off - 开关快速首领战斗自动喊话")
        Print("/mqq scope party on|off - 开关小队生效范围")
        Print("/mqq channel auto|say|party|raid - 设置发送频道")
        return
    end

    frame.editBox:SetText(input)
    ThreeBodyHelper.Toggle()
end

SLASH_THREEBODYHELPER1 = "/mqq"
SlashCmdList.THREEBODYHELPER = HandleSlash
