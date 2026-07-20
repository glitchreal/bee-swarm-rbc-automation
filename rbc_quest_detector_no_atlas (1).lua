local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local PathfindingService = game:GetService("PathfindingService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    error("LocalPlayer not found")
end

local playerGui = LocalPlayer:WaitForChild("PlayerGui")

local SCRIPT_VERSION = "2026.07.19.9"
local INSTANCE_KEY = "__RBCQuestDetectorNoAtlas"
local TWEEN_SPEED_MIN = 20
local TWEEN_SPEED_MAX = 70
local TWEEN_SPEED_DEFAULT = 70
local TWEEN_SPEED_MULTIPLIER = 1
local TWEEN_SPEED_LEGACY_RAW_MIN = 71
local globalScope = (getgenv and getgenv()) or _G
local previousInstance = globalScope[INSTANCE_KEY]

if type(previousInstance) == "table" then
    if type(previousInstance.cleanup) == "function" then
        pcall(previousInstance.cleanup, "overlap_execute")
    else
        previousInstance.alive = false
    end
end

local runtime = {
    alive = true,
    version = SCRIPT_VERSION,
    connections = {},
    screenGui = nil,
    moveSession = nil,
    preciseFxModule = nil,
    preciseFxOriginalMake = nil,
    preciseFxWrappedMake = nil
}

globalScope[INSTANCE_KEY] = runtime

function isRuntimeActive()
    return runtime.alive and globalScope[INSTANCE_KEY] == runtime
end

function trackConnection(connection)
    table.insert(runtime.connections, connection)
    return connection
end

function runtime.cleanup(_reason)
    if not runtime.alive then
        return
    end

    runtime.alive = false

    if setCollectorInputHeld then
        pcall(setCollectorInputHeld, false)
    end
    if setAutoRbcWalkSpeed then
        pcall(setAutoRbcWalkSpeed, false)
    end
    if runtime.preciseFxModule
        and runtime.preciseFxOriginalMake
        and runtime.preciseFxModule.Make == runtime.preciseFxWrappedMake then
        runtime.preciseFxModule.Make = runtime.preciseFxOriginalMake
    end

    for _, connection in ipairs(runtime.connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end

    runtime.connections = {}

    if runtime.screenGui then
        pcall(function()
            runtime.screenGui:Destroy()
        end)
        runtime.screenGui = nil
    end

    if runtime.moveSession then
        runtime.moveSession.cancelled = true
        if type(runtime.moveSession.cleanup) == "function" then
            pcall(runtime.moveSession.cleanup)
        end
        runtime.moveSession = nil
    end

    if globalScope[INSTANCE_KEY] == runtime then
        globalScope[INSTANCE_KEY] = nil
    end
end

local state = {
    autoScan = true,
    scanInterval = 1.5,
    includeHidden = false,
    minimized = false,
    activeTab = "quests",
    controlTab = "general",
    smartBoosts = true,
    smartMaterials = true,
    smartCombat = true,
    boostMinRound = 18,
    gooGumdropsMinRound = 15,
    instantConvertMinRound = 20,
    moveMethod = "walk",
    tweenSpeed = TWEEN_SPEED_DEFAULT,
    selectedFarmField = "Pine Tree Forest",
    fieldDropdownOpen = false,
    moveInProgress = false,
    route = "blue",
    autoPick = false,
    autoBeePick = false,
    autoUpgradePick = false,
    autoUpgradeRoll = false,
    autoRbc = false,
    autoRoboBearInteract = false,
    currentRbcQuestField = "",
    currentRbcQuestMode = "field",
    lastAutoRbcMoveTarget = "",
    lastAutoRbcMoveAt = 0,
    tokenPanelOpen = false,
    lastTokenCollectAt = 0,
    lastTokenCollectTarget = "",
    lastFarmPatrolAt = 0,
    farmPatrolIndex = 0,
    lastFarmRootPosition = nil,
    lastFarmMovementAt = 0,
    lastFarmStallRecoverAt = 0,
    lastRbcFieldSwitchAt = 0,
    lastRbcTaskSignature = "",
    lastChallengeTimerSeconds = nil,
    lastChallengeTimerChangedAt = 0,
    guideDefaultsApplied = false,
    collectorInputHeld = false,
    walkSpeedHumanoid = nil,
    originalWalkSpeed = nil,
    tokenQueue = {},
    tokenQueueField = "",
    tokenQueueBuiltAt = 0,
    activeTokenTarget = nil,
    activeTokenStartedAt = 0,
    lastTokenRepathAt = 0,
    tokenFailureUntil = setmetatable({}, { __mode = "k" }),
    tokenPathWaypoints = {},
    tokenPathIndex = 0,
    tokenPathTarget = nil,
    lastTokenQueueRefreshAt = 0,
    lastSprinklerField = "",
    lastSprinklerAt = 0,
    preciseTargets = setmetatable({}, { __mode = "k" }),
    preciseObserved = setmetatable({}, { __mode = "k" }),
    preciseTouchedObserved = setmetatable({}, { __mode = "k" }),
    preciseSeenCount = 0,
    preciseTouchedCount = 0,
    lastHiveMoveAt = 0,
    lastRoboBearEAt = 0,
    lastNpcDialogClickAt = 0,
    lastRoboBearRoundStateCheckAt = 0,
    lastRoboBearRoundEnded = false,
    lastRoboBearRoundEndRound = 0,
    lastRoboBearRoundEndState = "unknown",
    lastRoboBearRoundStartAt = 0,
    lastRoboBearClaimAt = 0,
    pendingPostGameOverCancel = false,
    lastRoboBearRoundStartSignature = "",
    waitingForChallengeInfoAfterRoundStart = false,
    lastChallengeInfoWaitStartedAt = 0,
    actionDelay = 1,
    lastQuestChoicesSeenAt = 0,
    lastBeeChoicesSeenAt = 0,
    lastUpgradeChoicesSeenAt = 0,
    pausedAll = false,
    pauseSnapshot = nil,
    beePanelOpen = false,
    upgradePanelOpen = false,
    autoLoadConfig = true,
    lastPickSignature = "",
    lastBeePickSignature = "",
    lastUpgradePickSignature = "",
    lastUpgradeLockSignature = "",
    lastUpgradePickAt = 0,
    lastUpgradePickAttemptAt = 0,
    lastUpgradeLockAttemptAt = 0,
    lastUpgradeRerollAt = 0,
    lastUpgradeRerollSignature = "",
    lastUpgradeRerollHistorySignature = "",
    lastUpgradeBoughtRound = -1,
    lastUpgradeRerollRound = -1,
    lastObservedRbcRound = 0,
    cachedActiveUpgradeCounts = {},
    materialLastUsedAt = {},
    materialLastUsedRound = {},
    lastAnyMaterialAt = 0,
    lastMaterialReason = "None",
    lastBoostTaskSignature = "",
    lastCombatJumpAt = 0,
    combatTarget = nil,
    combatTargetStartedAt = 0,
    detectorLoopHeartbeat = 0,
    roboLoopHeartbeat = 0,
    autoRbcLoopHeartbeat = 0,
    beePickRound = 0,
    beePickCount = 0,
    beePickedSlots = {},
    lastBeeChoiceSignature = "",
    lastBeePickAt = 0,
    lastStatsFetchAt = 0,
    statsRefreshInterval = 60,
    cachedStats = nil,
    questPickHistory = {},
    beePickHistory = {},
    upgradePickHistory = {},
    lastQuestHistorySignature = "",
    lastBeeHistorySignature = "",
    lastUpgradeHistorySignature = "",
    lastBeeBlockedSignature = "",
    lastUpgradeLockHistorySignature = "",
    lastUpgradeBuyHistorySignature = "",
    lastUpgradeActiveCounts = nil,
    activeUpgradeBaselineReady = false,
    lastSeenLiveRound = 0,
    lastSeenLiveCogs = "?",
    refreshInProgress = false,
    refreshQueued = false,
    lastQuestSnapshot = nil,
    lastQuestSnapshotAt = 0,
    selectedQuestProfile = nil,
    detected = {
        status = "Idle",
        source = "none",
        questName = "No quest detected",
        objective = "Waiting for scan",
        quests = {},
        round = "?",
        score = "?",
        cogs = "?",
        goldenCogmower = "Dead/NoSpawn",
        updatedAt = "Never",
        guiPath = "N/A",
        rawText = "",
        pickedQuest = "None",
        pickedBee = "None",
        pickedUpgrade = "None"
    }
}

-- Expose the live state on the existing runtime handle so executor-side
-- diagnostics can verify behavior without scraping the overlay.
runtime.state = state

local root
local beePanelFrame
local upgradePanelFrame
local tokenPanelFrame
local tokenScroll
local beePriorityRows = {}
local upgradeRows = {}
local tokenPriorityRows = {}
local CONFIG_FILE_NAME = "rbc_quest_detector_config.json"
local upgradeSectionState = {
    Common = true,
    Rare = false,
    Epic = false,
    Legendary = false
}
local AUTO_ROLL_MIN_COGS = 25
local ROBO_BEAR_DIALOG_ACTIONS = {
    start = "StartRoboBearChallenge",
    startRound = "StartRoboBearChallengeRound"
}
local EMPTY_TABLE = {}
local remoteCache = {}
local guiCache = {
    descendants = setmetatable({}, { __mode = "k" }),
    paths = setmetatable({}, { __mode = "k" })
}

function safeCall(fn, fallback)
    local ok, result = pcall(fn)
    if ok then
        return result
    end
    return fallback
end

function resetGuiCache()
    guiCache.descendants = setmetatable({}, { __mode = "k" })
    guiCache.paths = setmetatable({}, { __mode = "k" })
end

function getCachedDescendants(instance)
    if not instance then
        return EMPTY_TABLE
    end

    local cached = guiCache.descendants[instance]
    if cached then
        return cached
    end

    cached = safeCall(function()
        return instance:GetDescendants()
    end, EMPTY_TABLE)
    guiCache.descendants[instance] = cached
    return cached
end

function getScreenGuiRoot()
    return playerGui and playerGui:FindFirstChild("ScreenGui") or nil
end

function getRoboBearPromptRoot()
    local screenGui = getScreenGuiRoot()
    return screenGui and screenGui:FindFirstChild("RoboBearPrompt") or nil
end

function getRoboBearMainFrame()
    local prompt = getRoboBearPromptRoot()
    return prompt and prompt:FindFirstChild("MainFrame") or nil
end

function getRoboBearBoxRoot()
    local mainFrame = getRoboBearMainFrame()
    return mainFrame and mainFrame:FindFirstChild("Box") or nil
end

function getEventsFolder()
    local cached = remoteCache.Events
    if cached and cached.Parent == ReplicatedStorage then
        return cached
    end

    cached = ReplicatedStorage:FindFirstChild("Events")
    remoteCache.Events = cached
    return cached
end

function getRemote(remoteName)
    local cached = remoteCache[remoteName]
    if cached and cached.Parent then
        return cached
    end

    local events = getEventsFolder()
    cached = events and events:FindFirstChild(remoteName) or nil
    remoteCache[remoteName] = cached
    return cached
end

function fireRemote(remoteName, ...)
    local remote = getRemote(remoteName)
    if not remote then
        return false
    end

    local args = { ... }
    return safeCall(function()
        if remote:IsA("RemoteEvent") then
            remote:FireServer(table.unpack(args))
            return true
        end
        if remote:IsA("RemoteFunction") then
            remote:InvokeServer(table.unpack(args))
            return true
        end
        return false
    end, false) == true
end

function invokeRemote(remoteName, ...)
    local remote = getRemote(remoteName)
    if not remote or not remote:IsA("RemoteFunction") then
        return nil
    end

    local args = { ... }
    return safeCall(function()
        return remote:InvokeServer(table.unpack(args))
    end, nil)
end

function compactText(text)
    text = tostring(text or "")
    text = text:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    return text
end

function formatValue(value)
    if value == nil then
        return "N/A"
    end
    if typeof(value) == "number" then
        if math.floor(value) == value then
            return tostring(value)
        end
        return string.format("%.2f", value)
    end
    return tostring(value)
end

function normalizeTweenSpeedLevel(value)
    local numeric = tonumber(value)
    if not numeric then
        numeric = TWEEN_SPEED_DEFAULT
    elseif numeric > TWEEN_SPEED_MAX then
        if numeric >= TWEEN_SPEED_LEGACY_RAW_MIN then
            numeric = numeric / TWEEN_SPEED_MULTIPLIER
        else
            numeric = TWEEN_SPEED_MAX
        end
    end

    return math.clamp(math.floor(numeric + 0.5), TWEEN_SPEED_MIN, TWEEN_SPEED_MAX)
end

function getTweenVelocity()
    return normalizeTweenSpeedLevel(state.tweenSpeed) * TWEEN_SPEED_MULTIPLIER
end

function containsPattern(text, patterns)
    local lowered = string.lower(text)
    for _, pattern in ipairs(patterns) do
        if lowered:find(pattern, 1, true) then
            return true
        end
    end
    return false
end

function getFullPath(instance)
    return safeCall(function()
        return instance:GetFullName()
    end, instance.Name)
end

function getAncestorContext(instance)
    local names = {}
    local current = instance
    while current and current ~= LocalPlayer.PlayerGui do
        table.insert(names, current.Name)
        current = current.Parent
    end
    return table.concat(names, " > ")
end

function isVisibleGuiObject(object)
    if not object:IsA("GuiObject") then
        return true
    end
    if state.includeHidden then
        return true
    end

    local current = object
    while current and current ~= LocalPlayer.PlayerGui do
        if current:IsA("GuiObject") and current.Visible == false then
            return false
        end
        current = current.Parent
    end
    return true
end

local RBC_CONTEXT_PATTERNS = { "robo", "cog", "challenge", "quest", "round" }
local QUEST_TEXT_PATTERNS = {
    "collect", "defeat", "pop", "gather", "token", "pollen", "field", "goo",
    "ability", "mark", "flame", "bomb", "critical", "bee", "boss", "monster"
}

function textLooksLikeReward(text)
    local lowered = string.lower(text)
    return lowered:find("reward", 1, true) ~= nil or lowered:find("cogs", 1, true) ~= nil
end

function textLooksLikeQuestTitle(text)
    local normalized = string.lower(tostring(text or "")):gsub("[%s%p_]+", "")
    return normalized:find("questa", 1, true) ~= nil
        or normalized:find("questb", 1, true) ~= nil
        or normalized:find("questc", 1, true) ~= nil
end

function normalizeQuestTitle(text)
    local lowered = string.lower(compactText(text)):gsub("[%s%p_]+", "")
    if lowered:find("questa", 1, true) then
        return "Quest A"
    end
    if lowered:find("questb", 1, true) then
        return "Quest B"
    end
    if lowered:find("questc", 1, true) then
        return "Quest C"
    end
    return compactText(text)
end

function scoreCandidate(text, context)
    local score = 0
    local loweredText = string.lower(text)
    local loweredContext = string.lower(context)

    if containsPattern(loweredContext, RBC_CONTEXT_PATTERNS) then
        score += 50
    end
    if containsPattern(loweredText, QUEST_TEXT_PATTERNS) then
        score += 30
    end
    if loweredText:find("round", 1, true) then
        score += 10
    end
    if loweredText:find("quest", 1, true) then
        score += 10
    end
    if #text >= 12 then
        score += 5
    end
    return score
end

function getStatsSnapshot()
    return invokeRemote("RetrievePlayerStats")
end

function parseRbcStats(stats)
    local snapshot = {
        round = "?",
        score = "?",
        cogs = "?",
        status = "No RoboChallenges data"
    }

    if type(stats) ~= "table" then
        return snapshot
    end

    local robo = stats.RoboChallenges
    if type(robo) == "table" then
        snapshot.score = robo.HighestScore or snapshot.score
        local activeChallenge = robo.ActiveChallenge
        if type(activeChallenge) == "table" then
            snapshot.round = activeChallenge.Round or activeChallenge.InitiatedRound or snapshot.round
            snapshot.cogs = activeChallenge.TotalCogs or snapshot.cogs
        end
        snapshot.status = "RoboChallenges found"
    end

    return snapshot
end

function getActiveRbcChallenge(stats)
    if type(stats) ~= "table" then
        return nil
    end

    local robo = stats.RoboChallenges
    if type(robo) ~= "table" then
        return nil
    end

    local activeChallenge = robo.ActiveChallenge
    if type(activeChallenge) ~= "table" then
        return nil
    end

    return activeChallenge
end

function getRoboBearRoundRuntimeSummary(stats)
    local activeChallenge = getActiveRbcChallenge(stats)
    local summary = {
        active = false,
        running = false,
        round = 0,
        roundState = "unknown"
    }

    if not activeChallenge then
        return summary
    end

    summary.active = true
    summary.round = tonumber(activeChallenge.Round)
        or tonumber(activeChallenge.InitiatedRound)
        or tonumber(activeChallenge.RoundCompleted)
        or tonumber(activeChallenge.FinishedRound)
        or 0
    local rawRoundState = tostring(activeChallenge.RoundState or "")
    summary.roundState = rawRoundState ~= "" and rawRoundState or "unknown"

    local loweredState = string.lower(summary.roundState)
    local terminalState = loweredState == ""
        or loweredState == "unknown"
        or loweredState:find("complete", 1, true) ~= nil
        or loweredState:find("lost", 1, true) ~= nil
        or loweredState:find("finish", 1, true) ~= nil
        or loweredState:find("end", 1, true) ~= nil

    summary.running = not terminalState and (
        loweredState:find("running", 1, true) ~= nil
        or loweredState:find("active", 1, true) ~= nil
        or loweredState:find("progress", 1, true) ~= nil
        or loweredState:find("started", 1, true) ~= nil
        or (activeChallenge.RoundFinished == false and summary.round > 0)
    )

    return summary
end

function getFreshRoboBearStats(force)
    local now = os.clock()
    if force or not state.cachedStats or (now - state.lastRoboBearRoundStateCheckAt) >= 1.25 then
        local stats = getStatsSnapshot()
        state.lastRoboBearRoundStateCheckAt = now
        if stats then
            state.cachedStats = stats
            state.lastStatsFetchAt = now
        end
    end

    return state.cachedStats
end

function getRbcRoundEndSummaryFromStats(stats)
    local activeChallenge = getActiveRbcChallenge(stats)
    local summary = {
        ended = false,
        round = 0,
        roundState = "unknown",
        reason = "none"
    }

    if not activeChallenge then
        return summary
    end

    summary.round = tonumber(activeChallenge.Round)
        or tonumber(activeChallenge.InitiatedRound)
        or tonumber(activeChallenge.RoundCompleted)
        or tonumber(activeChallenge.FinishedRound)
        or 0

    summary.roundState = tostring(activeChallenge.RoundState or "unknown")
    local loweredState = string.lower(summary.roundState)

    if activeChallenge.RoundFinished == true then
        summary.ended = true
        summary.reason = "RoundFinished"
    elseif loweredState:find("complete", 1, true)
        or loweredState:find("finished", 1, true)
        or loweredState:find("ended", 1, true) then
        summary.ended = true
        summary.reason = "RoundState:" .. summary.roundState
    end

    return summary
end

function setRoboBearRoundEndSummary(summary)
    summary = summary or {}
    state.lastRoboBearRoundEnded = summary.ended == true
    state.lastRoboBearRoundEndRound = tonumber(summary.round) or 0
    state.lastRoboBearRoundEndState = tostring(summary.roundState or "unknown")
end

function refreshRoboBearRoundEndState(force)
    local stats = getFreshRoboBearStats(force)

    local summary = getRbcRoundEndSummaryFromStats(stats)
    setRoboBearRoundEndSummary(summary)
    return summary
end

function getChallengeInfoRuntimeSummary()
    local summary = {
        active = false,
        running = false,
        round = 0,
        roundState = "ui_unknown",
        timerSeconds = nil
    }
    local challengeInfo = getRbcChallengeInfoRoot and getRbcChallengeInfoRoot() or nil
    if not challengeInfo or not isGuiActuallyShown(challengeInfo) then
        return summary
    end

    local hasTask = false
    local hasGiveUp = false
    for _, descendant in ipairs(getCachedDescendants(challengeInfo)) do
        if isTextObject(descendant) and isVisibleGuiObject(descendant) then
            local text = stripRichText(descendant.Text or "")
            local lowered = string.lower(text)
            local roundValue = text:match("ROUND:%s*(%d+)") or text:match("Round%s*(%d+)")
            if roundValue then
                summary.round = tonumber(roundValue) or summary.round
            end
            local minutes, seconds = text:match("(%d+):(%d%d)")
            if minutes and seconds and lowered:find("time", 1, true) then
                summary.timerSeconds = (tonumber(minutes) or 0) * 60 + (tonumber(seconds) or 0)
            elseif lowered:find("time", 1, true) then
                local secondsOnly = text:match("[Tt][Ii][Mm][Ee]:%s*(%d+)%s*[Ss]")
                if secondsOnly then
                    summary.timerSeconds = tonumber(secondsOnly)
                end
            end
            hasGiveUp = hasGiveUp
                or lowered:find("give up", 1, true) ~= nil
                or lowered == "quit"
            hasTask = hasTask
                or lowered:find("collect", 1, true) ~= nil
                or lowered:find("convert", 1, true) ~= nil
                or lowered:find("defeat", 1, true) ~= nil
        end
    end

    local now = os.clock()
    if summary.timerSeconds ~= nil and summary.timerSeconds ~= state.lastChallengeTimerSeconds then
        state.lastChallengeTimerSeconds = summary.timerSeconds
        state.lastChallengeTimerChangedAt = now
    end

    summary.active = summary.round > 0 and hasTask and hasGiveUp
    local timerIsLive = summary.timerSeconds ~= nil and summary.timerSeconds > 0 and (
        summary.timerSeconds < 300
        or (now - state.lastChallengeTimerChangedAt) <= 2.5
    )
    local promptClosed = not (isRoboBearChallengePromptOpen and isRoboBearChallengePromptOpen())
    summary.running = summary.active and timerIsLive and promptClosed
    summary.roundState = summary.running and "ui_running" or "ui_idle"
    return summary
end

function isRoboBearChallengeRoundRunning(force)
    local stats = getFreshRoboBearStats(force)
    local summary = getRoboBearRoundRuntimeSummary(stats)
    local uiSummary = getChallengeInfoRuntimeSummary()
    if uiSummary.running then
        clearChallengeInfoWait()
        return true, uiSummary
    end

    local betweenRoundUi = (isRoboBearChallengePromptOpen and isRoboBearChallengePromptOpen())
        or ((isNpcDialogOpen and isNpcDialogOpen()) and not uiSummary.running)
    if betweenRoundUi then
        summary.running = false
        summary.roundState = "between_round_ui"
    end
    if not summary.running then
        if uiSummary.running and not betweenRoundUi then
            summary = uiSummary
        end
    end
    if summary.running then
        clearChallengeInfoWait()
    end
    return summary.running, summary
end

function isTextObject(instance)
    return instance:IsA("TextLabel") or instance:IsA("TextButton") or instance:IsA("TextBox")
end

function gatherQuestCards(playerGui)
    local cards = {}

    local function getAncestors(instance)
        local ancestors = {}
        local current = instance
        while current and current ~= playerGui do
            ancestors[current] = true
            current = current.Parent
        end
        return ancestors
    end

    local function findSharedAncestor(a, b)
        if not a or not b then
            return nil
        end

        local aAncestors = getAncestors(a)
        local current = b
        while current and current ~= playerGui do
            if aAncestors[current] then
                return current
            end
            current = current.Parent
        end
        return nil
    end

    local questATitle
    local questBTitle
    local roundTitle
    local chooseQuestTitle

    for _, descendant in ipairs(getCachedDescendants(playerGui)) do
        if isTextObject(descendant) and isVisibleGuiObject(descendant) then
            local text = compactText(descendant.Text)
            local normalized = normalizeQuestTitle(text)
            local lowered = string.lower(text)

            if normalized == "Quest A" and not questATitle then
                questATitle = descendant
            elseif normalized == "Quest B" and not questBTitle then
                questBTitle = descendant
            elseif lowered:find("robo bear challenge: round", 1, true) and not roundTitle then
                roundTitle = descendant
            elseif lowered:find("choose a quest", 1, true) and not chooseQuestTitle then
                chooseQuestTitle = descendant
            end
        end
    end

    local searchRoot = findSharedAncestor(questATitle, questBTitle)
    if not searchRoot then
        searchRoot = findSharedAncestor(roundTitle, chooseQuestTitle)
    end
    if not searchRoot then
        searchRoot = findSharedAncestor(questATitle, chooseQuestTitle)
    end
    if not searchRoot and questATitle then
        searchRoot = questATitle.Parent
    end
    if not searchRoot and questBTitle then
        searchRoot = questBTitle.Parent
    end
    if not searchRoot and (questATitle or questBTitle or roundTitle or chooseQuestTitle) then
        searchRoot = playerGui
    end
    if not searchRoot then
        return cards, nil
    end

    if questATitle then
        table.insert(cards, {
            title = "Quest A",
            titleObject = questATitle,
            path = getFullPath(questATitle)
        })
    end

    if questBTitle then
        table.insert(cards, {
            title = "Quest B",
            titleObject = questBTitle,
            path = getFullPath(questBTitle)
        })
    end

    table.sort(cards, function(a, b)
        local ax = safeCall(function()
            return a.titleObject.AbsolutePosition.X
        end, 0)
        local bx = safeCall(function()
            return b.titleObject.AbsolutePosition.X
        end, 0)
        return ax < bx
    end)

    return cards, searchRoot
end

function sortByX(a, b)
    local ax = safeCall(function()
        return a.titleObject.AbsolutePosition.X
    end, 0)
    local bx = safeCall(function()
        return b.titleObject.AbsolutePosition.X
    end, 0)
    return ax < bx
end

function isInsideQuestColumn(textObject, card)
    local titlePos = safeCall(function()
        return card.titleObject.AbsolutePosition
    end, nil)
    local titleSize = safeCall(function()
        return card.titleObject.AbsoluteSize
    end, nil)
    local objPos = safeCall(function()
        return textObject.AbsolutePosition
    end, nil)
    local objSize = safeCall(function()
        return textObject.AbsoluteSize
    end, nil)

    if not titlePos or not titleSize or not objPos or not objSize then
        return false
    end

    local centerX = objPos.X + (objSize.X / 2)
    local minX = titlePos.X - 40
    local maxX = titlePos.X + titleSize.X + 140
    local minY = titlePos.Y + titleSize.Y + 4
    local maxY = titlePos.Y + 420

    return centerX >= minX and centerX <= maxX and objPos.Y >= minY and objPos.Y <= maxY
end

function dedupeList(items)
    local out = {}
    local seen = {}
    for _, item in ipairs(items) do
        local normalized = compactText(item)
        if normalized ~= "" and not seen[normalized] then
            seen[normalized] = true
            table.insert(out, normalized)
        end
    end
    return out
end

local FIELD_GROUPS = {
    blue = {
        "bamboo field",
        "blue flower field",
        "pine tree forest"
    },
    red = {
        "mushroom field",
        "pepper patch",
        "rose field",
        "strawberry field"
    },
    white = {
        "spider field",
        "coconut field",
        "sunflower field",
        "dandelion field",
        "pumpkin patch",
        "pineapple patch"
    },
    mixed = {
        "clover field",
        "mountain top field"
    }
}

local FARM_FIELD_NAMES = {
    "Sunflower Field",
    "Dandelion Field",
    "Mushroom Field",
    "Blue Flower Field",
    "Clover Field",
    "Strawberry Field",
    "Spider Field",
    "Bamboo Field",
    "Pineapple Patch",
    "Stump Field",
    "Cactus Field",
    "Pumpkin Patch",
    "Pine Tree Forest",
    "Rose Field",
    "Mountain Top Field",
    "Ant Field",
    "Pepper Patch",
    "Coconut Field"
}

local FARM_FIELD_SET = {}
for _, fieldName in ipairs(FARM_FIELD_NAMES) do
    FARM_FIELD_SET[fieldName] = true
end

function isValidFarmField(fieldName)
    return type(fieldName) == "string" and FARM_FIELD_SET[fieldName] == true
end

local FARM_FIELD_ALIASES = {
    ["pineapple field"] = "Pineapple Patch",
    ["pumpkin field"] = "Pumpkin Patch",
    ["mountaintop field"] = "Mountain Top Field",
    ["mountain field"] = "Mountain Top Field"
}

local FARM_FIELD_ZONE_NAMES = {
    ["Sunflower Field"] = "Sunflower",
    ["Dandelion Field"] = "Dandelion Field",
    ["Mushroom Field"] = "Mushroom Field",
    ["Blue Flower Field"] = "Blue Flower Field",
    ["Clover Field"] = "CloverField",
    ["Strawberry Field"] = "Strawberry Field",
    ["Spider Field"] = "Spider Field",
    ["Bamboo Field"] = "Bamboo Field",
    ["Pineapple Patch"] = "Pineapple Patch",
    ["Stump Field"] = "Stump Field",
    ["Cactus Field"] = "Cactus Field",
    ["Pumpkin Patch"] = "Pumpkin Patch",
    ["Pine Tree Forest"] = "Pine Tree Forest",
    ["Rose Field"] = "Rose Field",
    ["Mountain Top Field"] = "Mountain Top Field",
    ["Ant Field"] = "Ant Field",
    ["Pepper Patch"] = "Pepper Patch",
    ["Coconut Field"] = "Coconut Field"
}

local FARM_FIELD_ZONE_ALIASES = {
    ["Pumpkin Patch"] = { "Pumpkin Patch", "Pumpkin Field" },
    ["Pineapple Patch"] = { "Pineapple Patch", "Pineapple Field" },
    ["Clover Field"] = { "CloverField", "Clover Field" },
    ["Sunflower Field"] = { "Sunflower", "Sunflower Field" }
}

local FARM_FIELD_ROUTE_SCORE = {}
for routeName, fields in pairs(FIELD_GROUPS) do
    for _, fieldName in ipairs(fields) do
        FARM_FIELD_ROUTE_SCORE[fieldName] = FARM_FIELD_ROUTE_SCORE[fieldName] or {}
        FARM_FIELD_ROUTE_SCORE[fieldName][routeName] = 2
    end
end

local PRIORITY_TOKEN_DEFS = {
    { name = "Pollen Bomb", id = "rbxassetid://1442725244" },
    { name = "Pollen Bomb+", id = "rbxassetid://1442764904" },
    { name = "Target Practice", id = "rbxassetid://8173559749" },
    { name = "Token Link", id = "rbxassetid://1629547638" },
    { name = "Beamstorm", id = "rbxassetid://1671281844" },
    { name = "Scratch", id = "rbxassetid://1104415222" },
    { name = "Gummy Storm", id = "rbxassetid://1839454544" },
    { name = "Glob", id = "" },
    { name = "Gummy Storm+", id = "rbxassetid://1442764904" },
    { name = "Bond Token", id = "rbxassetid://1104415222" },
    { name = "Inspire", id = "rbxassetid://2000457501" },
    { name = "Fetch", id = "rbxassetid://2319100769" },
    { name = "Impale", id = "rbxassetid://2319083910" },
    { name = "Pulse", id = "rbxassetid://1874564120" },
    { name = "Tornado", id = "rbxassetid://3582519526" },
    { name = "Mark Surge", id = "rbxassetid://4528379338" },
    { name = "Triangulate", id = "rbxassetid://4519523935" },
    { name = "Summon Frog", id = "rbxassetid://4528414666" },
    { name = "Inferno", id = "rbxassetid://4519549299" },
    { name = "Fuzz Bombs", id = "rbxassetid://4889322534" },
    { name = "Pollen Haze", id = "rbxassetid://4889470194" },
    { name = "Festive Gift", id = "rbxassetid://1874564120" },
    { name = "Mark", id = "rbxassetid://1874564120" },
    { name = "Surprise Party", id = "rbxassetid://8083943936" },
    { name = "Blue Balloon", id = "rbxassetid://8083436978" },
    { name = "Glitch", id = "rbxassetid://5877939956" },
    { name = "Map Corruption", id = "rbxassetid://5877939956" },
    { name = "Smile Token", id = "rbxassetid://5877939956" },
    { name = "Mind Hack", id = "rbxassetid://5877998606" },
    { name = "Red Boost", id = "rbxassetid://1442859163" },
    { name = "Rage", id = "rbxassetid://1442700745" },
    { name = "Blue Boost", id = "rbxassetid://1442863423" },
    { name = "Baby Love", id = "rbxassetid://1472256444" },
    { name = "Brown Bear Morph", id = "rbxassetid://1472425802" },
    { name = "Panda Bear Morph", id = "rbxassetid://1472580249" },
    { name = "Polar Bear Morph", id = "rbxassetid://1472532912" },
    { name = "Black Bear Morph", id = "rbxassetid://1472491940" },
    { name = "Focus", id = "rbxassetid://1629649299" },
    { name = "Pollen Mark", id = "rbxassetid://2499540966" },
    { name = "Honey Mark", id = "rbxassetid://2499514197" },
    { name = "Gummy Bear Morph", id = "rbxassetid://1837410537" },
    { name = "Beesmas Cheer", id = "rbxassetid://2652364563" },
    { name = "Festive Blessing", id = "rbxassetid://2652424740" },
    { name = "Mother Bear Morph", id = "rbxassetid://2032949183" },
    { name = "Science Bear Morph", id = "rbxassetid://1489734171" },
    { name = "White Boost", id = "rbxassetid://3877732821" },
    { name = "Festive Mark", id = "rbxassetid://6077288982" },
    { name = "Precise Mark", id = "rbxassetid://8173559749" },
    { name = "Melody", id = "rbxassetid://253828517" },
    { name = "Haste", id = "rbxassetid://65867881" },
    { name = "Flame Fuel", id = "rbxassetid://4528208186" },
    { name = "Red Sync", id = "rbxassetid://1874704640" }
}

local PRIORITY_TOKEN_BY_NAME = {}
local PRIORITY_TOKEN_NAME_BY_ID = {}
for _, tokenDef in ipairs(PRIORITY_TOKEN_DEFS) do
    PRIORITY_TOKEN_BY_NAME[tokenDef.name] = tokenDef
    if tokenDef.id ~= "" then
        PRIORITY_TOKEN_NAME_BY_ID[string.lower(tokenDef.id)] = PRIORITY_TOKEN_NAME_BY_ID[string.lower(tokenDef.id)] or tokenDef.name
    end
end

function normalizeFieldText(text)
    return string.lower(compactText(text)):gsub("[%p_]+", " ")
end

function findFarmFieldsInText(text)
    local normalized = normalizeFieldText(text)
    local found = {}

    for _, fieldName in ipairs(FARM_FIELD_NAMES) do
        local loweredName = normalizeFieldText(fieldName)
        if normalized:find(loweredName, 1, true) then
            table.insert(found, fieldName)
        end
    end

    for alias, fieldName in pairs(FARM_FIELD_ALIASES) do
        if normalized:find(alias, 1, true) and not table.find(found, fieldName) then
            table.insert(found, fieldName)
        end
    end

    return found
end

function chooseBestFarmFieldFromText(text, route)
    local found = findFarmFieldsInText(text)
    if #found == 0 then
        return nil
    end

    local bestField = found[1]
    local bestScore = -math.huge
    for _, fieldName in ipairs(found) do
        local loweredName = normalizeFieldText(fieldName)
        local routeScores = FARM_FIELD_ROUTE_SCORE[loweredName] or {}
        local score = routeScores[route] or routeScores.mixed or 0
        if score > bestScore then
            bestField = fieldName
            bestScore = score
        end
    end

    return bestField
end

function inferFarmFieldFromQuest(quest, route)
    if type(quest) ~= "table" then
        return nil
    end

    local parts = {
        quest.objective or "",
        quest.reward or "",
        quest.raw or ""
    }
    if type(quest.tasks) == "table" then
        for _, taskText in ipairs(quest.tasks) do
            table.insert(parts, taskText)
        end
    end

    return chooseBestFarmFieldFromText(table.concat(parts, " "), route)
end

local BEE_SECTIONS = {
    {
        rarity = "Common",
        bees = {
            "Basic Bee"
        }
    },
    {
        rarity = "Rare",
        bees = {
            "Bomber Bee",
            "Brave Bee",
            "Bumble Bee",
            "Cool Bee",
            "Hasty Bee",
            "Looker Bee",
            "Rad Bee",
            "Rascal Bee",
            "Stubborn Bee"
        }
    },
    {
        rarity = "Epic",
        bees = {
            "Bubble Bee",
            "Bucko Bee",
            "Commander Bee",
            "Demo Bee",
            "Exhausted Bee",
            "Fire Bee",
            "Frosty Bee",
            "Honey Bee",
            "Rage Bee",
            "Riley Bee",
            "Shocked Bee"
        }
    },
    {
        rarity = "Legendary",
        bees = {
            "Baby Bee",
            "Carpenter Bee",
            "Demon Bee",
            "Diamond Bee",
            "Lion Bee",
            "Music Bee",
            "Ninja Bee",
            "Shy Bee"
        }
    },
    {
        rarity = "Mythic",
        bees = {
            "Buoyant Bee",
            "Fuzzy Bee",
            "Precise Bee",
            "Spicy Bee",
            "Tadpole Bee",
            "Vector Bee"
        }
    },
    {
        rarity = "Event",
        bees = {
            "Bear Bee",
            "Cobalt Bee",
            "Crimson Bee",
            "Digital Bee",
            "Festive Bee",
            "Gummy Bee",
            "Photon Bee",
            "Puppy Bee",
            "Tabby Bee",
            "Vicious Bee",
            "Windy Bee"
        }
    }
}

local UPGRADE_SECTIONS = {
    {
        rarity = "Common",
        upgrades = {
            { name = "Botnet", cap = 1, effects = "+25% Bee Gather Pollen, +1 Cogs Per Round" },
            { name = "Credit", cap = 3, effects = "+2 Cogs Per Round", capEffects = "+6 Cogs Per Round" },
            { name = "Defragment", cap = 10, effects = "x1.5 Capacity, x0.9 Critical Power", capEffects = "x6 Capacity, x0.5 Critical Power" },
            { name = "Homepage", cap = 10, effects = "x1.25 Sunflower Field Pollen, x1.25 Dandelion Field Pollen, x1.25 Mushroom Field Pollen, x1.25 Blue Flower Field Pollen", capEffects = "x3.5 Sunflower Field Pollen, x3.5 Dandelion Field Pollen, x3.5 Mushroom Field Pollen, x3.5 Blue Flower Field Pollen" },
            { name = "Iterate", cap = 100, effects = "x1.05 Pollen", capEffects = "x6 Pollen" },
            { name = "Overfit: Blue", cap = 10, effects = "x1.25 Blue Pollen, x0.95 Player Movespeed, -5% Bee Movespeed", capEffects = "x4 Blue Pollen, x0.75 Player Movespeed, -15% Bee Movespeed" },
            { name = "Overfit: Red", cap = 10, effects = "x1.25 Red Pollen, x0.9 Capacity", capEffects = "x4 Red Pollen, x0.5 Capacity" },
            { name = "Overfit: White", cap = 10, effects = "x1.25 White Pollen, x0.9 Convert Rate", capEffects = "x4 White Pollen, x0.5 Convert Rate" },
            { name = "Sharpen", cap = 10, effects = "x1.2 Bee Attack, x0.9 Capacity", capEffects = "x3 Bee Attack, x0.5 Capacity" }
        }
    },
    {
        rarity = "Rare",
        upgrades = {
            { name = "APM", cap = 1, effects = "Focus tokens grant x1.03 Tool Pollen and Collector Tool Speed for 20s. Stacks up to 10 times." },
            { name = "Blue Screen", cap = 1, effects = "Blue Boost tokens grant x1.03 Attack and x1.03 Blue Bee Attack for 15s. Stacks up to 10 times." },
            { name = "Crypto", cap = 3, effects = "+3 Cogs Per Round, x0.8 Pollen, x0.8 Capacity", capEffects = "+9 Cogs Per Round, x0.5 Pollen, x0.5 Capacity" },
            { name = "Commit", cap = 2, effects = "+5% Critical Chance, -10% Instant Conversion, -10% Instant Red Conversion, -10% Instant White Conversion", capEffects = "+10% Critical Chance, -20% Instant Conversion, -20% Instant Red Conversion, -20% Instant White Conversion" },
            { name = "Dynamo", cap = 10, effects = "x1.25 Bomb Pollen, x0.9 Bee Gather Pollen", capEffects = "x3.5 Bomb Pollen, x0.4 Bee Gather Pollen" },
            { name = "Equalize", cap = 1, effects = "+1 Bee Attack, x1.25 Ungifted Bee Attack" },
            { name = "Expansion", cap = 100, effects = "x1.25 Capacity", capEffects = "x26 Capacity" },
            { name = "GPU", cap = 3, effects = "x1.25 Pollen, -4 Cogs Per Round", capEffects = "x1.75 Pollen, -12 Cogs Per Round" },
            { name = "Multithread", cap = 1, effects = "All Ability Tokens can be created During Battle, -1 Cogs Per Round" },
            { name = "Nullify", cap = 2, effects = "x1.5 Critical Power, x0.8 Pollen", capEffects = "x2 Critical Power, x0.6 Pollen" },
            { name = "Outsource", cap = 3, effects = "x1.5 Bee Gather Pollen, x0.85 Tool Pollen", capEffects = "x2.5 Bee Gather Pollen, x0.55 Tool Pollen" },
            { name = "RAM", cap = 10, effects = "+75,000 Capacity, +1 Cogs per Round", capEffects = "+750,000 Capacity, +10 Cogs per Round" },
            { name = "Router", cap = 10, effects = "x1.3 Strawberry Field Pollen, x1.3 Spider Field Pollen, x1.3 Bamboo Field Pollen, x1.3 Pineapple Field Pollen", capEffects = "x4 Strawberry Field Pollen, x4 Spider Field Pollen, x4 Bamboo Field Pollen, x4 Pineapple Field Pollen" },
            { name = "Saturate", cap = 3, effects = "x1.25 Blue Bee Attack, x1.25 Colorless Bee Attack, x0.8 Red Bee Attack", capEffects = "x1.75 Blue Bee Attack, x1.75 Colorless Bee Attack, x0.4 Red Bee Attack" },
            { name = "SSD: Blue", cap = 3, effects = "x2 Blue Field Capacity, x1.5 Blue Bee Convert Rate, -3% Critical Chance", capEffects = "x4 Blue Field Capacity, x2.5 Blue Bee Convert Rate, -6% Critical Chance" },
            { name = "SSD: Red", cap = 3, effects = "x2 Red Field Capacity, x1.5 Red Bee Convert Rate, x0.75 Bomb Pollen", capEffects = "x4 Red Field Capacity, x2.5 Red Bee Convert Rate, x0.5 Bomb Pollen" },
            { name = "SSD: White", cap = 3, effects = "x2 White Field Capacity, x1.5 Colorless Bee Convert Rate, x0.8 Bee Attack", capEffects = "x4 White Field Capacity, x2.5 Colorless Bee Convert Rate, x0.6 Bee Attack" },
            { name = "Subscribe", cap = 1, effects = "+1 Cogs Per Round, x1.1 Event Bee Pollen" },
            { name = "Virus", cap = 3, effects = "+1 Bee Attack, +1% Critical Chance, x0.9 Pollen", capEffects = "+3 Bee Attack, +3% Critical Chance, x0.7 Pollen" },
            { name = "VPN", cap = 3, effects = "+10% Dodge Chance", capEffects = "+30% Dodge Chance" }
        }
    },
    {
        rarity = "Epic",
        upgrades = {
            { name = "Bandwidth", cap = 1, effects = "x1.25 Convert Rate At Hive, x1.1 Mark Ability Pollen, x3 Crimson and Cobalt Ability Pollen" },
            { name = "Base-15", cap = 10, effects = "x1.25 Cactus Field Pollen, x1.25 Pumpkin Field Pollen, x1.25 Pine Tree Forest Pollen, x1.25 Rose Field Pollen", capEffects = "x3.5 Cactus Field Pollen, x3.5 Pumpkin Field Pollen, x3.5 Pine Tree Forest Pollen, x3.5 Rose Field Pollen" },
            { name = "beeBay", cap = 1, effects = "+1 Option When Choosing Bees, +1 Cogs per Round" },
            { name = "Client-Side", cap = 1, effects = "x1.25 Player Movespeed, x1.25 Tool Pollen, x0.75 Convert Rate" },
            { name = "Demarcate", cap = 1, effects = "Mark tokens grant x1.03 Critical Power for 15s. Stacks up to 10 times." },
            { name = "F5", cap = 1, effects = "+1 Quest Reroll, -3 Cogs Per Round" },
            { name = "Fission", cap = 1, effects = "x4 Bomb Pollen, +1 Cogs Per Round, +1 Bee Attack, x0.75 Pollen" },
            { name = "FOV", cap = 1, effects = "+1 Option When Choosing Upgrades, -2% Critical Chance" },
            { name = "Furnace", cap = 1, effects = "x1.5 Flame Pollen, x1.5 Flame Duration, x1.5 Flame Damage, -4 Cogs Per Round" },
            { name = "HDD", cap = 1, effects = "x3 Capacity, x4 Convert Rate at Hive, x0.5 Convert Rate. x0 Instant Conversion, x0.5 Goo Conversion" },
            { name = "Inject", cap = 1, effects = "+2 Blue Bee Attack, +1 Colorless Bee Attack, x1.25 Impale Damage" },
            { name = "Invert", cap = 1, effects = "Bubbles collect x4 from Red Flowers. Flames collect x4 from Blue Flowers." },
            { name = "Malware", cap = 3, effects = "+3 Bee Attack, x0.75 Capacity, x0.75 Convert Rate", capEffects = "+9 Bee Attack, x0.25 Capacity, x0.25 Convert Rate" },
            { name = "NFT", cap = 1, effects = "+4 Cogs Per Round, -3 Bee Attack" },
            { name = "Normalize", cap = 1, effects = "x2 Pollen, x2 Bee Attack, x0 Critical Chance" },
            { name = "Pop-Up", cap = 1, effects = "x2 Bubble Pollen, x1.5 Bubble Lifespan, +3 Blue Bee Attack, -4 Cogs Per Round" },
            { name = "Proxy", cap = 1, effects = "Haste tokens grant +2% Dodge Chance for 20s. Stacks up to 10 times." },
            { name = "Refractor", cap = 10, effects = "x1.1 Bee Ability Pollen, x0.9 Convert Rate", capEffects = "x2 Bee Ability Pollen, x0.75 Convert Rate" },
            { name = "Respec: Blue", cap = 2, effects = "x0.6 Blue Pollen, x1.25 White Pollen, x1.25 Red Pollen", capEffects = "x0.4 Blue Pollen, x1.5 White Pollen, x1.5 Red Pollen" },
            { name = "Respec: Red", cap = 2, effects = "x0.6 Red Pollen, x1.25 Blue Pollen, x1.25 White Pollen", capEffects = "x0.4 Red Pollen, x1.5 Blue Pollen, x1.5 White Pollen" },
            { name = "Respec: White", cap = 2, effects = "x0.6 White Pollen, x1.25 Blue Pollen, x1.25 Red Pollen", capEffects = "x0.4 White Pollen, x1.5 Blue Pollen, x1.5 Red Pollen" },
            { name = "RGB", cap = 1, effects = "+1% Critical Chance, x1.25 Flame Pollen, x1.25 Bubble Pollen, x0.8 Bee Gather Pollen" },
            { name = "Synchronize", cap = 1, effects = "x1.2 Bomb Power, Red Bomb Sync is always active if Crimson Bee is active. Blue Bomb Sync is always active if Cobalt Bee is active." },
            { name = "Torrent", cap = 1, effects = "+10% Instant Conversion, x1.5 Tornado Pollen, x1.5 Beamstorm Pollen" },
            { name = "Trojan", cap = 10, effects = "x1.25 Bee Attack, -10% Bee Movespeed", capEffects = "x3.5 Bee Attack, -50% Bee Movespeed" },
            { name = "Network", cap = 1, effects = "x1.25 Mark Duration, x1.5 Convert Rate, x0.75 Bee Attack" },
            { name = "White Noise", cap = 1, effects = "x1.1 White Pollen. x1.5 Buzz Bomb Pollen, -1 Cogs Per Round" },
            { name = "Virtual Pet", cap = 1, effects = "+10% Bee Movespeed, x1.5 Scratch Pollen, x3 Fetch Pollen" }
        }
    },
    {
        rarity = "Legendary",
        upgrades = {
            { name = "Bluetooth", cap = 1, effects = "x2 Blue Bee Attack, x1.25 Blue Pollen" },
            { name = "Bruteforce", cap = 1, effects = "+6% Super-Crit Chance, x1.25 Red Pollen" },
            { name = "Codec", cap = 1, effects = "+20% Instant Conversion, x0.8 Attack" },
            { name = "Corrupt", cap = 1, effects = "+1% Ability Duplication Chance, x2 Duped Ability Pollen" },
            { name = "Fluid Simulation", cap = 1, effects = "x1.25 Goo, x1.25 White Pollen" },
            { name = "Optimize", cap = 25, effects = "x1.1 Pollen, x1.1 Convert Rate, x1.1 Capacity", capEffects = "x3.5 Pollen, x3.5 Convert Rate, x3.5 Capacity" },
            { name = "Overclock", cap = 1, effects = "+10% Bee Movespeed, +10% Bee Ability Rate, x0.75 Capacity" },
            { name = "Pseudo-RNG", cap = 1, effects = "+3% Critical Chance, x1.25 Super-Crit Power, x2 Clover Field Pollen" },
            { name = "Reboot", cap = 1, effects = "+1 Quest Reroll" },
            { name = "Stack Overflow", cap = 1, effects = "+10 Cogs Per Round, x0.75 Movespeed, -25% Bee Movespeed" },
            { name = "The Cloud", cap = 3, effects = "x2.5 Capacity", capEffects = "x5.5 Capacity" },
            { name = "Wifi", cap = 10, effects = "x1.5 Stump Field Pollen, x1.5 Mountain Top Field Pollen, x1.5 Coconut Field Pollen, x1.5 Pepper Patch Pollen", capEffects = "x6 Stump Field Pollen, x6 Mountain Top Field Pollen, x6 Coconut Field Pollen, x6 Pepper Patch Pollen" }
        }
    }
}

local BEE_NAMES = {}
for _, section in ipairs(BEE_SECTIONS) do
    for _, beeName in ipairs(section.bees) do
        table.insert(BEE_NAMES, beeName)
    end
end

local UPGRADE_NAMES = {}
local UPGRADE_BY_NAME = {}
local UPGRADE_RARITY_RANK = {
    Common = 1,
    Rare = 2,
    Epic = 3,
    Legendary = 4
}

-- RBC guide defaults. They only affect the challenge pickers and never mutate the hive.
local RBC_BEE_GUIDE = {
    ["Digital Bee"] = { priority = 50, minRound = 1 },
    ["Bear Bee"] = { priority = 48, minRound = 1 },
    ["Basic Bee"] = { priority = 47, minRound = 1 },
    ["Precise Bee"] = { priority = 46, minRound = 1 },
    ["Hasty Bee"] = { priority = 45, minRound = 1 },
    ["Vector Bee"] = { priority = 44, minRound = 10 },
    ["Spicy Bee"] = { priority = 43, minRound = 8 },
    ["Windy Bee"] = { priority = 42, minRound = 10 },
    ["Tabby Bee"] = { priority = 41, minRound = 5 },
    ["Vicious Bee"] = { priority = 40, minRound = 1 },
    ["Tadpole Bee"] = { priority = 39, minRound = 15 },
    ["Music Bee"] = { priority = 20, minRound = 1 },
    ["Stubborn Bee"] = { priority = 18, minRound = 1 },
    ["Bucko Bee"] = { priority = 16, minRound = 1 },
    ["Brave Bee"] = { priority = 16, minRound = 1 },
    ["Riley Bee"] = { priority = 16, minRound = 1 }
}

local RBC_UPGRADE_GUIDE = {
    ["Credit"] = { rank = 130, target = 3 },
    ["Botnet"] = { rank = 129, target = 1 },
    ["Multithread"] = { rank = 128, target = 1 },
    ["Homepage"] = { rank = 127, target = 10 },
    ["Router"] = { rank = 126, target = 10 },
    ["Bandwidth"] = { rank = 125, target = 1 },
    ["Demarcate"] = { rank = 124, target = 1 },
    ["Corrupt"] = { rank = 123, target = 1 },
    ["Pseudo-RNG"] = { rank = 122, target = 1 },
    ["Optimize"] = { rank = 121, target = 25 },
    ["The Cloud"] = { rank = 120, target = 3 },
    ["Bruteforce"] = { rank = 119, target = 1 },
    ["Virtual Pet"] = { rank = 118, target = 1 },
    ["SSD: Red"] = { rank = 117, target = 3 },
    ["Outsource"] = { rank = 116, target = 3 },
    ["Nullify"] = { rank = 115, target = 2 },
    ["Reboot"] = { rank = 114, target = 1 },
    ["Iterate"] = { rank = 100, target = 20 },

    ["Blue Screen"] = { rank = 99, target = 1 },
    ["Subscribe"] = { rank = 98, target = 1 },
    ["Network"] = { rank = 97, target = 1 },
    ["Torrent"] = { rank = 96, target = 1 },
    ["Refractor"] = { rank = 95, target = 10 },
    ["Bluetooth"] = { rank = 94, target = 1 },
    ["Fluid Simulation"] = { rank = 93, target = 1 },
    ["Overclock"] = { rank = 92, target = 1 },
    ["Crypto"] = { rank = 91, target = 1, maxRound = 8 },
    ["FOV"] = { rank = 90, target = 1, maxRound = 20 },
    ["NFT"] = { rank = 89, target = 1, maxRound = 15 },
    ["Stack Overflow"] = { rank = 88, target = 1, maxRound = 15 },
    ["Overfit: Blue"] = { rank = 81, target = 2 },
    ["Overfit: Red"] = { rank = 80, target = 2 },

    ["Overfit: White"] = { rank = 78, target = 6 },
    ["Sharpen"] = { rank = 77, target = 5 },
    ["Defragment"] = { rank = 76, target = 2, minRound = 11 },
    ["RAM"] = { rank = 75, target = 3, maxRound = 12 },
    ["Expansion"] = { rank = 74, target = 4 },
    ["GPU"] = { rank = 73, target = 1, minRound = 23 },
    ["F5"] = { rank = 72, target = 1, minRound = 20 },
    ["Furnace"] = { rank = 71, target = 1, minRound = 20 },
    ["SSD: White"] = { rank = 70, target = 1 },
    ["Base-15"] = { rank = 69, target = 1 }
}

local RBC_TOKEN_GUIDE_SCORE = {
    ["Target Practice"] = 140,
    ["Glob"] = 139,
    ["Triangulate"] = 138,
    ["Precise Mark"] = 136,
    ["Mark Surge"] = 132,
    ["Pollen Mark"] = 130,
    ["Honey Mark"] = 128,
    ["Festive Mark"] = 126,
    ["Token Link"] = 124,
    ["Smile Token"] = 122,
    ["Glitch"] = 120,
    ["Map Corruption"] = 119,
    ["Mind Hack"] = 118,
    ["Melody"] = 112,
    ["Haste"] = 108,
    ["Flame Fuel"] = 105,
    ["Red Boost"] = 102,
    ["White Boost"] = 100,
    ["Blue Boost"] = 98,
    ["Focus"] = 94,
    ["Rage"] = 90,
    ["Pollen Haze"] = 88,
    ["Fuzz Bombs"] = 86,
    ["Inferno"] = 84,
    ["Summon Frog"] = 82,
    ["Pollen Bomb+"] = 78,
    ["Pollen Bomb"] = 74
}

local RBC_TOKEN_NAME_BY_TEXTURE_ID = {}
local function getTextureAssetId(texture)
    return tostring(texture or ""):match("%d+") or ""
end

do
    local collectibleDefinitions = ReplicatedStorage:FindFirstChild("Collectibles")
    for _, tokenDef in ipairs(PRIORITY_TOKEN_DEFS) do
        local definition = collectibleDefinitions and collectibleDefinitions:FindFirstChild(tokenDef.name)
        local icon = definition and definition:FindFirstChild("Icon")
        local texture = icon and icon:IsA("Decal") and icon.Texture or tokenDef.id
        local textureId = getTextureAssetId(texture)
        local existing = RBC_TOKEN_NAME_BY_TEXTURE_ID[textureId]
        if textureId ~= "" and (not existing
            or (RBC_TOKEN_GUIDE_SCORE[tokenDef.name] or 0) > (RBC_TOKEN_GUIDE_SCORE[existing] or 0)) then
            RBC_TOKEN_NAME_BY_TEXTURE_ID[textureId] = tokenDef.name
        end
    end
end

for _, section in ipairs(UPGRADE_SECTIONS) do
    for _, upgrade in ipairs(section.upgrades) do
        table.insert(UPGRADE_NAMES, upgrade.name)
        UPGRADE_BY_NAME[upgrade.name] = {
            rarity = section.rarity,
            cap = upgrade.cap,
            effects = upgrade.effects,
            capEffects = upgrade.capEffects or ""
        }
    end
end

function createDefaultBeeConfig()
    local config = {}
    for _, beeName in ipairs(BEE_NAMES) do
        local guide = RBC_BEE_GUIDE[beeName]
        config[beeName] = {
            priority = guide and guide.priority or 0,
            minRound = guide and guide.minRound or 1
        }
    end
    return config
end

function createDefaultUpgradeConfig()
    local config = {}
    for _, upgradeName in ipairs(UPGRADE_NAMES) do
        local meta = UPGRADE_BY_NAME[upgradeName]
        local guide = RBC_UPGRADE_GUIDE[upgradeName]
        config[upgradeName] = {
            enabled = guide ~= nil,
            lock = false,
            targetCount = guide and math.min(guide.target, meta.cap) or 0,
            minRound = guide and (guide.minRound or 1) or 1
        }
    end
    return config
end

function createDefaultTokenPriorityConfig()
    local config = {}
    for _, tokenDef in ipairs(PRIORITY_TOKEN_DEFS) do
        config[tokenDef.name] = RBC_TOKEN_GUIDE_SCORE[tokenDef.name] ~= nil
    end
    return config
end

state.beeConfig = createDefaultBeeConfig()
state.upgradeConfig = createDefaultUpgradeConfig()
state.tokenPriorityConfig = createDefaultTokenPriorityConfig()

function applyRbcGuideDefaultsIfUnconfigured()
    if state.guideDefaultsApplied then
        return
    end

    local hasBeePriority = false
    for _, config in pairs(state.beeConfig) do
        hasBeePriority = hasBeePriority or (tonumber(config.priority) or 0) > 0
    end
    if not hasBeePriority then
        for beeName, guide in pairs(RBC_BEE_GUIDE) do
            if state.beeConfig[beeName] then
                state.beeConfig[beeName].priority = guide.priority
                state.beeConfig[beeName].minRound = guide.minRound
            end
        end
    end

    local hasUpgrade = false
    for _, config in pairs(state.upgradeConfig) do
        hasUpgrade = hasUpgrade or config.enabled == true
    end
    if not hasUpgrade then
        for upgradeName, guide in pairs(RBC_UPGRADE_GUIDE) do
            local config = state.upgradeConfig[upgradeName]
            local meta = UPGRADE_BY_NAME[upgradeName]
            if config and meta then
                config.enabled = true
                config.targetCount = math.min(guide.target, meta.cap)
                config.minRound = guide.minRound or 1
            end
        end
    end

    local hasPriorityToken = false
    for _, enabled in pairs(state.tokenPriorityConfig) do
        hasPriorityToken = hasPriorityToken or enabled == true
    end
    if not hasPriorityToken then
        for tokenName in pairs(RBC_TOKEN_GUIDE_SCORE) do
            if state.tokenPriorityConfig[tokenName] ~= nil then
                state.tokenPriorityConfig[tokenName] = true
            end
        end
    end

    state.guideDefaultsApplied = true
end

function getCachedStatsSnapshot(force)
    local now = os.clock()
    if force or not state.cachedStats or (now - state.lastStatsFetchAt) >= state.statsRefreshInterval then
        state.cachedStats = getStatsSnapshot()
        state.lastStatsFetchAt = now
    end
    return state.cachedStats
end

function buildConfigPayload()
    local beeConfig = {}
    for _, beeName in ipairs(BEE_NAMES) do
        local config = state.beeConfig[beeName] or { priority = 0, minRound = 1 }
        beeConfig[beeName] = {
            priority = math.clamp(tonumber(config.priority) or 0, 0, 50),
            minRound = math.clamp(tonumber(config.minRound) or 1, 1, 25)
        }
    end

    local upgradeConfig = {}
    for _, upgradeName in ipairs(UPGRADE_NAMES) do
        local config = state.upgradeConfig[upgradeName] or { enabled = false, targetCount = 0, minRound = 1 }
        local meta = UPGRADE_BY_NAME[upgradeName]
        upgradeConfig[upgradeName] = {
            enabled = config.enabled == true,
            lock = config.lock == true,
            targetCount = math.clamp(tonumber(config.targetCount) or 0, 0, meta and meta.cap or 0),
            minRound = math.clamp(tonumber(config.minRound) or 1, 1, 25)
        }
    end

    local tokenPriorityConfig = {}
    for _, tokenDef in ipairs(PRIORITY_TOKEN_DEFS) do
        tokenPriorityConfig[tokenDef.name] = state.tokenPriorityConfig[tokenDef.name] == true
    end

    return {
        version = 1,
        route = state.route,
        moveMethod = state.moveMethod,
        tweenSpeed = normalizeTweenSpeedLevel(state.tweenSpeed),
        selectedFarmField = state.selectedFarmField,
        autoScan = state.autoScan,
        includeHidden = state.includeHidden,
        autoPick = state.autoPick,
        autoBeePick = state.autoBeePick,
        autoUpgradePick = state.autoUpgradePick,
        autoUpgradeRoll = state.autoUpgradeRoll,
        autoRbc = state.autoRbc,
        autoLoadConfig = state.autoLoadConfig,
        activeTab = state.activeTab,
        controlTab = state.controlTab,
        smartBoosts = state.smartBoosts,
        smartMaterials = state.smartMaterials,
        smartCombat = state.smartCombat,
        boostMinRound = state.boostMinRound,
        gooGumdropsMinRound = state.gooGumdropsMinRound,
        instantConvertMinRound = state.instantConvertMinRound,
        beeConfig = beeConfig,
        upgradeConfig = upgradeConfig,
        tokenPriorityConfig = tokenPriorityConfig
    }
end

function applyConfigPayload(payload)
    if type(payload) ~= "table" then
        return false, "Invalid config"
    end

    if payload.route == "blue" or payload.route == "red" then
        state.route = payload.route
    end
    if payload.moveMethod == "walk" or payload.moveMethod == "tween" then
        state.moveMethod = payload.moveMethod
    end
    if payload.tweenSpeed ~= nil then
        state.tweenSpeed = normalizeTweenSpeedLevel(payload.tweenSpeed)
    end
    if isValidFarmField(payload.selectedFarmField) then
        state.selectedFarmField = payload.selectedFarmField
    elseif isValidFarmField(payload.farmField) then
        state.selectedFarmField = payload.farmField
    end

    if type(payload.autoScan) == "boolean" then
        state.autoScan = payload.autoScan
    end
    if type(payload.includeHidden) == "boolean" then
        state.includeHidden = payload.includeHidden
    end
    if type(payload.autoPick) == "boolean" then
        state.autoPick = payload.autoPick
    end
    if type(payload.autoBeePick) == "boolean" then
        state.autoBeePick = payload.autoBeePick
    end
    if type(payload.autoUpgradePick) == "boolean" then
        state.autoUpgradePick = payload.autoUpgradePick
    end
    if type(payload.autoUpgradeRoll) == "boolean" then
        state.autoUpgradeRoll = payload.autoUpgradeRoll
    end
    if type(payload.autoRbc) == "boolean" then
        state.autoRbc = payload.autoRbc
    end
    if type(payload.autoLoadConfig) == "boolean" then
        state.autoLoadConfig = payload.autoLoadConfig
    end
    if type(payload.smartBoosts) == "boolean" then
        state.smartBoosts = payload.smartBoosts
    end
    if type(payload.smartMaterials) == "boolean" then
        state.smartMaterials = payload.smartMaterials
    end
    if type(payload.smartCombat) == "boolean" then
        state.smartCombat = payload.smartCombat
    end
    state.boostMinRound = math.clamp(math.floor(tonumber(payload.boostMinRound) or state.boostMinRound), 1, 25)
    state.gooGumdropsMinRound = math.clamp(math.floor(tonumber(payload.gooGumdropsMinRound) or state.gooGumdropsMinRound), 1, 25)
    state.instantConvertMinRound = math.clamp(math.floor(tonumber(payload.instantConvertMinRound) or state.instantConvertMinRound), 1, 25)
    if payload.activeTab == "quests" or payload.activeTab == "debug" or payload.activeTab == "test" then
        state.activeTab = payload.activeTab
    end
    if payload.controlTab == "general"
        or payload.controlTab == "questpicker"
        or payload.controlTab == "beepicker"
        or payload.controlTab == "upgradepicker"
        or payload.controlTab == "move"
        or payload.controlTab == "farming"
        or payload.controlTab == "boosts"
        or payload.controlTab == "settings" then
        state.controlTab = payload.controlTab
    end

    if type(payload.beeConfig) == "table" then
        for _, beeName in ipairs(BEE_NAMES) do
            local source = payload.beeConfig[beeName]
            if type(source) == "table" then
                state.beeConfig[beeName] = {
                    priority = math.clamp(math.floor((tonumber(source.priority) or 0) + 0.5), 0, 50),
                    minRound = math.clamp(math.floor((tonumber(source.minRound) or 1) + 0.5), 1, 25)
                }
            end
        end
    end

    if type(payload.upgradeConfig) == "table" then
        for _, upgradeName in ipairs(UPGRADE_NAMES) do
            local source = payload.upgradeConfig[upgradeName]
            local meta = UPGRADE_BY_NAME[upgradeName]
            if type(source) == "table" and meta then
                state.upgradeConfig[upgradeName] = {
                    enabled = source.enabled == true,
                    lock = source.lock == true,
                    targetCount = math.clamp(math.floor((tonumber(source.targetCount) or 0) + 0.5), 0, meta.cap),
                    minRound = math.clamp(math.floor((tonumber(source.minRound) or 1) + 0.5), 1, 25)
                }
            end
        end
    end

    if type(payload.tokenPriorityConfig) == "table" then
        for _, tokenDef in ipairs(PRIORITY_TOKEN_DEFS) do
            if type(payload.tokenPriorityConfig[tokenDef.name]) == "boolean" then
                state.tokenPriorityConfig[tokenDef.name] = payload.tokenPriorityConfig[tokenDef.name]
            end
        end
    end

    state.lastPickSignature = ""
    state.lastBeePickSignature = ""
    state.lastUpgradePickSignature = ""
    state.lastUpgradeLockSignature = ""
    return true
end

function exportConfigToClipboard()
    local payload = HttpService:JSONEncode(buildConfigPayload())
    if setclipboard then
        setclipboard(payload)
        return true, "Config exported"
    end
    return false, "Clipboard unavailable"
end

function importConfigFromClipboard()
    if not getclipboard then
        return false, "Clipboard read unavailable"
    end

    local raw = safeCall(function()
        return getclipboard()
    end, "")
    if raw == "" then
        return false, "Clipboard empty"
    end

    local payload = safeCall(function()
        return HttpService:JSONDecode(raw)
    end, nil)
    if not payload then
        return false, "Clipboard is not valid JSON"
    end

    return applyConfigPayload(payload)
end

function saveConfigToFile()
    if not writefile then
        return false, "writefile unavailable"
    end

    local payload = HttpService:JSONEncode(buildConfigPayload())
    local ok = safeCall(function()
        writefile(CONFIG_FILE_NAME, payload)
        return true
    end, false)
    if ok then
        return true, "Config saved"
    end
    return false, "Save failed"
end

function loadConfigFromFile()
    if not readfile or not isfile then
        return false, "readfile/isfile unavailable"
    end
    if not isfile(CONFIG_FILE_NAME) then
        return false, "Config file not found"
    end

    local raw = safeCall(function()
        return readfile(CONFIG_FILE_NAME)
    end, "")
    if raw == "" then
        return false, "Config file empty"
    end

    local payload = safeCall(function()
        return HttpService:JSONDecode(raw)
    end, nil)
    if not payload then
        return false, "Config file is not valid JSON"
    end

    local ok, message = applyConfigPayload(payload)
    if ok then
        return true, "Config loaded"
    end
    return false, message or "Load failed"
end

function formatScaledNumber(value)
    if math.abs(value - math.floor(value)) < 0.001 then
        local whole = tostring(math.floor(value + 0.0001))
        local reversed = whole:reverse():gsub("(%d%d%d)", "%1,"):reverse()
        return reversed:gsub("^,", "")
    end
    local rounded = string.format("%.2f", value):gsub("0+$", ""):gsub("%.$", "")
    return rounded
end

function extractEffectTokens(text)
    local tokens = {}
    for prefix, numberPart, suffix in text:gmatch("([x%+%-]?)(%d[%d,]*%.?%d*)(%%?)") do
        table.insert(tokens, {
            prefix = prefix,
            raw = numberPart,
            suffix = suffix,
            value = tonumber((numberPart:gsub(",", ""))) or 0
        })
    end
    return tokens
end

function buildUpgradeEffectPreview(upgradeName, count)
    local meta = UPGRADE_BY_NAME[upgradeName]
    if not meta then
        return "Unknown upgrade"
    end
    if count <= 0 then
        return "Off"
    end
    if meta.cap <= 1 or meta.capEffects == "" then
        return meta.effects
    end
    if count == 1 then
        return meta.effects
    end
    if count >= meta.cap then
        return meta.capEffects
    end

    local baseText = meta.effects
    local capText = meta.capEffects
    local baseTokens = extractEffectTokens(baseText)
    local capTokens = extractEffectTokens(capText)
    if #baseTokens == 0 or #baseTokens ~= #capTokens then
        return "Preview " .. tostring(count) .. "/" .. tostring(meta.cap) .. ": " .. meta.effects .. " -> " .. meta.capEffects
    end

    local ratio = (count - 1) / math.max(1, meta.cap - 1)
    local index = 0
    local preview = baseText:gsub("([x%+%-]?)(%d[%d,]*%.?%d*)(%%?)", function(prefix, _, suffix)
        index += 1
        local baseToken = baseTokens[index]
        local capToken = capTokens[index]
        local value = baseToken.value + ((capToken.value - baseToken.value) * ratio)
        return prefix .. formatScaledNumber(value) .. suffix
    end)
    return preview
end

function getActiveUpgradeCounts()
    local counts = {}
    local mainFrame = getRoboBearMainFrame()
    local upgradeLog = mainFrame and mainFrame:FindFirstChild("UpgradeLog")
    if not upgradeLog then
        return state.cachedActiveUpgradeCounts or counts
    end

    for _, descendant in ipairs(getCachedDescendants(upgradeLog)) do
        if isTextObject(descendant) and isVisibleGuiObject(descendant) then
            local text = compactText(tostring(descendant.Text or ""):gsub("<[^>]*>", ""))
            for upgradeName in pairs(UPGRADE_BY_NAME) do
                if text == upgradeName or text:find(upgradeName, 1, true) then
                    local levelText = text:match("LVL%s*(%d+)") or text:match("Level%s*(%d+)")
                    local level = tonumber(levelText)
                    counts[upgradeName] = math.max(counts[upgradeName] or 0, level or 1)
                    break
                end
            end
        end
    end

    if next(counts) then
        state.cachedActiveUpgradeCounts = counts
        return counts
    end
    return state.cachedActiveUpgradeCounts or counts
end

function countMatches(text, values)
    local count = 0
    for _, value in ipairs(values) do
        if text:find(value, 1, true) then
            count += 1
        end
    end
    return count
end

local RBC_QUEST_FIELD_GUIDE_RANK = {
    ["Mushroom Field"] = 1,
    ["Strawberry Field"] = 1,
    ["Rose Field"] = 1,
    ["Pepper Patch"] = 1,
    ["Sunflower Field"] = 3,
    ["Dandelion Field"] = 4,
    ["Spider Field"] = 7,
    ["Cactus Field"] = 8,
    ["Pumpkin Patch"] = 9,
    ["Mountain Top Field"] = 10,
    ["Clover Field"] = 11,
    ["Blue Flower Field"] = 12,
    ["Pineapple Patch"] = 15,
    ["Pine Tree Forest"] = 16,
    ["Bamboo Field"] = 17
}

function getQuestGuideText(quest)
    local parts = {
        quest and quest.objective or "",
        quest and quest.reward or "",
        quest and quest.raw or ""
    }
    if quest and type(quest.tasks) == "table" then
        for _, taskText in ipairs(quest.tasks) do
            table.insert(parts, taskText)
        end
    end
    return string.lower(table.concat(parts, " "))
end

function analyzeQuestForRoute(quest, route)
    local text = getQuestGuideText(quest)
    local taskCount = #(quest.tasks or {})
    if taskCount == 0 and quest.objective and quest.objective ~= "" then
        taskCount = 1
        for _ in string.gmatch(quest.objective, "|") do
            taskCount += 1
        end
    end

    local hasHoney = text:find("honey", 1, true) ~= nil
    local hasGoo = text:find("goo", 1, true) ~= nil
    local hasConvert = text:find("convert", 1, true) ~= nil
    local hasBluePollen = text:find("blue pollen", 1, true) ~= nil
    local hasRedPollen = text:find("red pollen", 1, true) ~= nil
    local hasWhitePollen = text:find("white pollen", 1, true) ~= nil
    local strippedColors = text
        :gsub("red pollen", "")
        :gsub("blue pollen", "")
        :gsub("white pollen", "")
    local hasGenericPollen = strippedColors:find("pollen", 1, true) ~= nil

    local blueCore = countMatches(text, FIELD_GROUPS.blue) + (hasBluePollen and 1 or 0)
    local redCore = countMatches(text, FIELD_GROUPS.red) + (hasRedPollen and 1 or 0)
    local mixedCore = countMatches(text, FIELD_GROUPS.mixed)
    local whiteCore = countMatches(text, FIELD_GROUPS.white)
    local explicitFields = findFarmFieldsInText(text)
    local guideRank
    for _, fieldName in ipairs(explicitFields) do
        local fieldRank = RBC_QUEST_FIELD_GUIDE_RANK[fieldName] or 18
        guideRank = math.max(guideRank or 0, fieldRank)
    end

    if hasConvert then
        guideRank = math.max(guideRank or 0, 23)
    elseif hasBluePollen and hasGoo then
        guideRank = math.max(guideRank or 0, 22)
    elseif hasBluePollen and hasRedPollen then
        guideRank = math.max(guideRank or 0, 20)
    elseif hasBluePollen and hasWhitePollen then
        guideRank = math.max(guideRank or 0, 14)
    elseif hasWhitePollen and hasGoo then
        guideRank = math.max(guideRank or 0, 13)
    elseif hasRedPollen and hasWhitePollen then
        guideRank = math.max(guideRank or 0, 6)
    elseif hasBluePollen then
        guideRank = math.max(guideRank or 0, taskCount >= 3 and 21 or 19)
    elseif hasWhitePollen then
        guideRank = math.max(guideRank or 0, taskCount >= 3 and 18 or 5)
    elseif hasGoo then
        guideRank = math.max(guideRank or 0, 2)
    elseif hasRedPollen or hasGenericPollen or hasHoney then
        guideRank = math.max(guideRank or 0, 1)
    end

    guideRank = guideRank or 18
    local tier = 24 - guideRank
    local score = 10000 - (guideRank * 100) - math.max(0, taskCount - 1) * 7
    return {
        score = score,
        tier = tier,
        guideRank = guideRank,
        blueCore = blueCore,
        redCore = redCore,
        whiteCore = whiteCore,
        taskCount = taskCount
    }
end

function chooseQuestIndex(quests, route)
    local bestIndex = nil
    local bestMeta = nil

    for index, quest in ipairs(quests) do
        local meta = analyzeQuestForRoute(quest, route)
        if not bestMeta
            or meta.guideRank < bestMeta.guideRank
            or (meta.guideRank == bestMeta.guideRank and meta.score > bestMeta.score)
            or (meta.guideRank == bestMeta.guideRank and meta.score == bestMeta.score and meta.taskCount < bestMeta.taskCount) then
            bestIndex = index
            bestMeta = meta
        end
    end

    return bestIndex, bestMeta
end

function fireRoboBearBeeSelect(slotIndex)
    return fireRemote("RoboBearBeeSelect", slotIndex)
end

function fireRoboBearQuestSelect(slotIndex)
    return fireRemote("RoboBearQuestSelect", slotIndex)
end

function fireRoboBearUpgradeSelect(slotIndex)
    return fireRemote("RoboBearUpgradeSelect", slotIndex)
end

function fireRoboBearUpgradeLock(slotIndex, locked)
    return fireRemote("RoboBearUpgradeLock", slotIndex, locked == true)
end

function fireRoboBearRoundStart()
    local fired = fireRemote("RoboBearRoundStart")
    if fired then
        beginChallengeInfoWait()
    end
    return fired
end

function fireRoboBearReroll()
    return fireRemote("RoboBearReroll")
end

function fireSelectNpcOption(actionTag)
    if type(actionTag) ~= "string" or actionTag == "" then
        return false
    end
    return fireRemote("SelectNPCOption", actionTag)
end

function fireRoboBearDialogAction(actionName)
    local actionTag = ROBO_BEAR_DIALOG_ACTIONS[actionName]
    if not actionTag then
        return false, "unknown_action"
    end

    if fireSelectNpcOption(actionTag) then
        return true, actionTag
    end
    return false, "select_npc_option_unavailable"
end

function inferRoboBearDialogAction()
    local roundRunning = isRoboBearChallengeRoundRunning(false)
    if roundRunning then
        return nil
    end

    if isRoboBearChallengePromptOpen() or isLiveRoboBearChallengeUiVisible() then
        return nil
    end

    local roundEndSummary = refreshRoboBearRoundEndState(false)
    if roundEndSummary and roundEndSummary.ended then
        return "startRound"
    end

    return "start"
end

function getCharacterRoot()
    local character = LocalPlayer.Character
    if not character then
        return nil
    end
    return character:FindFirstChild("HumanoidRootPart")
end

function getCharacterHumanoid()
    local character = LocalPlayer.Character
    if not character then
        return nil
    end
    return character:FindFirstChildOfClass("Humanoid")
end

function getRoboBearCircle()
    local npcs = Workspace:FindFirstChild("NPCs")
    local roboBear = npcs and npcs:FindFirstChild("Robo Bear")
    local circle = roboBear and roboBear:FindFirstChild("Circle")
    if circle and circle:IsA("BasePart") then
        return circle
    end
    return nil
end

function isStandingAtRoboBearCircle()
    local rootPart = getCharacterRoot()
    local circle = getRoboBearCircle()
    if not rootPart or not circle then
        return false
    end

    local delta = rootPart.Position - circle.Position
    local horizontalDistance = Vector3.new(delta.X, 0, delta.Z).Magnitude
    local radius = math.max(circle.Size.X, circle.Size.Z) / 2
    local heightAllowance = math.max(8, circle.Size.Y + 8)
    return horizontalDistance <= (radius + 4) and math.abs(delta.Y) <= heightAllowance
end

function getInstanceCenterAndSize(instance)
    if not instance then
        return nil, nil
    end

    if instance:IsA("BasePart") then
        return instance.Position, instance.Size
    end

    if instance:IsA("Model") then
        local ok, cframe, size = pcall(function()
            return instance:GetBoundingBox()
        end)
        if ok and cframe and size then
            return cframe.Position, size
        end
    end

    local minX, minY, minZ = math.huge, math.huge, math.huge
    local maxX, maxY, maxZ = -math.huge, -math.huge, -math.huge
    local foundPart = false
    for _, descendant in ipairs(safeCall(function()
        return instance:GetDescendants()
    end, EMPTY_TABLE)) do
        if descendant:IsA("BasePart") then
            foundPart = true
            local pos = descendant.Position
            local size = descendant.Size
            minX = math.min(minX, pos.X - (size.X / 2))
            minY = math.min(minY, pos.Y - (size.Y / 2))
            minZ = math.min(minZ, pos.Z - (size.Z / 2))
            maxX = math.max(maxX, pos.X + (size.X / 2))
            maxY = math.max(maxY, pos.Y + (size.Y / 2))
            maxZ = math.max(maxZ, pos.Z + (size.Z / 2))
        end
    end

    if foundPart then
        local center = Vector3.new((minX + maxX) / 2, (minY + maxY) / 2, (minZ + maxZ) / 2)
        local size = Vector3.new(maxX - minX, maxY - minY, maxZ - minZ)
        return center, size
    end

    return nil, nil
end

function getFarmFieldZoneNameCandidates(fieldName)
    local candidates = {}
    local seen = {}

    local function addCandidate(candidate)
        if type(candidate) == "string" and candidate ~= "" and not seen[candidate] then
            seen[candidate] = true
            table.insert(candidates, candidate)
        end
    end

    local aliases = FARM_FIELD_ZONE_ALIASES[fieldName]
    if type(aliases) == "table" then
        for _, alias in ipairs(aliases) do
            addCandidate(alias)
        end
    end

    addCandidate(FARM_FIELD_ZONE_NAMES[fieldName])
    addCandidate(fieldName)
    return candidates
end

function findFarmFieldInstance(fieldName)
    if not isValidFarmField(fieldName) then
        return nil
    end

    local zoneNames = getFarmFieldZoneNameCandidates(fieldName)
    local flowerZones = Workspace:FindFirstChild("FlowerZones")
    if flowerZones then
        for _, zoneName in ipairs(zoneNames) do
            local directZone = flowerZones:FindFirstChild(zoneName)
            if directZone then
                return directZone
            end
        end

        local recursiveZone = safeCall(function()
            for _, zoneName in ipairs(zoneNames) do
                local found = flowerZones:FindFirstChild(zoneName, true)
                if found then
                    return found
                end
            end
            return nil
        end, nil)
        if recursiveZone then
            return recursiveZone
        end
    end

    local candidateRoots = {
        Workspace:FindFirstChild("Fields"),
        Workspace:FindFirstChild("FieldZones")
    }

    for _, rootInstance in ipairs(candidateRoots) do
        if rootInstance then
            for _, zoneName in ipairs(zoneNames) do
                local direct = rootInstance:FindFirstChild(zoneName)
                if direct then
                    return direct
                end
            end

            local recursive = safeCall(function()
                for _, zoneName in ipairs(zoneNames) do
                    local found = rootInstance:FindFirstChild(zoneName, true)
                    if found then
                        return found
                    end
                end
                return nil
            end, nil)
            if recursive then
                return recursive
            end
        end
    end

    return nil
end

function getFarmFieldTargetPosition(fieldName)
    local fieldInstance = findFarmFieldInstance(fieldName)
    local center, size = getInstanceCenterAndSize(fieldInstance)
    if not center or not size then
        return nil, nil, nil
    end

    return center + Vector3.new(0, math.max(4, size.Y / 2 + 4), 0), center, size
end

function isStandingAtFarmField(fieldName)
    local rootPart = getCharacterRoot()
    local _, center, size = getFarmFieldTargetPosition(fieldName)
    if not rootPart or not center or not size then
        return false
    end

    local delta = rootPart.Position - center
    local horizontalDistance = Vector3.new(delta.X, 0, delta.Z).Magnitude
    local radius = math.max(size.X, size.Z) / 2
    return horizontalDistance <= (radius + 8) and math.abs(delta.Y) <= math.max(25, size.Y + 12)
end

function inferVisibleRbcQuestField()
    local roots = {
        getRoboBearPromptRoot(),
        getRoboBearMainFrame(),
        playerGui
    }

    for _, rootInstance in ipairs(roots) do
        if rootInstance then
            for _, descendant in ipairs(getCachedDescendants(rootInstance)) do
                if isTextObject(descendant) and isVisibleGuiObject(descendant) and not descendant:IsDescendantOf(root) then
                    local fieldName = chooseBestFarmFieldFromText(stripRichText(descendant.Text or ""), state.route)
                    if fieldName then
                        return fieldName
                    end
                end
            end
        end
    end

    return nil
end

function getRouteDefaultFarmField()
    return state.route == "red" and "Rose Field" or "Blue Flower Field"
end

function getRbcChallengeInfoRoot()
    local screenGui = getScreenGuiRoot()
    return screenGui and screenGui:FindFirstChild("ChallengeInfo") or nil
end

function parseTaskProgress(text)
    local current, goal = tostring(text or ""):match("([%d,]+)%s*/%s*([%d,]+)")
    current = current and tonumber((current:gsub(",", ""))) or nil
    goal = goal and tonumber((goal:gsub(",", ""))) or nil
    if current and goal and goal > 0 then
        return current, goal, math.clamp(current / goal, 0, 1)
    end
    return nil, nil, 0
end

function taskTextLooksComplete(text)
    local lowered = string.lower(tostring(text or ""))
    if lowered:find("complete", 1, true) or lowered:find("done", 1, true) then
        return true
    end

    local current, goal = lowered:match("([%d,]+)%s*/%s*([%d,]+)")
    if current and goal then
        current = tonumber((current:gsub(",", ""))) or 0
        goal = tonumber((goal:gsub(",", ""))) or math.huge
        return goal > 0 and current >= goal
    end

    return false
end

function inferRbcTaskTargetFromText(text)
    local cleaned = stripRichText(text or "")
    local lowered = string.lower(cleaned)
    if cleaned == "" then
        return nil
    end

    local relevant = lowered:find("pollen", 1, true)
        or lowered:find("goo", 1, true)
        or lowered:find("honey", 1, true)
        or lowered:find("convert", 1, true)
        or lowered:find("collect", 1, true)
    if not relevant then
        return nil
    end

    local explicitFields = findFarmFieldsInText(cleaned)
    local fieldName = explicitFields[1]
    local hasRed = lowered:find("red pollen", 1, true) ~= nil
    local hasBlue = lowered:find("blue pollen", 1, true) ~= nil
    local hasWhite = lowered:find("white pollen", 1, true) ~= nil
    local hasGoo = lowered:find("goo", 1, true) ~= nil
    local hasConvert = lowered:find("convert", 1, true) ~= nil

    if not fieldName then
        if hasRed and hasWhite then
            fieldName = "Sunflower Field"
        elseif hasBlue and hasWhite then
            fieldName = "Blue Flower Field"
        elseif hasRed then
            fieldName = "Rose Field"
        elseif hasBlue then
            fieldName = "Blue Flower Field"
        elseif hasWhite then
            fieldName = "Dandelion Field"
        else
            fieldName = getRouteDefaultFarmField()
        end
    end

    local current, goal, progress = parseTaskProgress(cleaned)
    local mode = lowered:find("convert", 1, true) and "convert" or "generic"
    return {
        fieldName = fieldName,
        mode = mode,
        text = cleaned,
        complete = taskTextLooksComplete(cleaned),
        explicitField = #explicitFields > 0,
        fields = explicitFields,
        red = hasRed,
        blue = hasBlue,
        white = hasWhite,
        goo = hasGoo,
        convert = hasConvert,
        current = current,
        goal = goal,
        progress = progress,
        remainingRatio = 1 - progress
    }
end

function getVisibleRbcTaskTargets()
    local candidates = {}
    local seen = {}
    local roots = {
        getRoboBearPromptRoot(),
        getRoboBearMainFrame(),
        getRbcChallengeInfoRoot()
    }

    local function scanRoot(rootInstance)
        if not rootInstance then
            return
        end
        for _, descendant in ipairs(getCachedDescendants(rootInstance)) do
            if isTextObject(descendant) and isVisibleGuiObject(descendant) and not descendant:IsDescendantOf(root) then
                local text = stripRichText(descendant.Text or "")
                local lowered = string.lower(text)
                local context = string.lower(getAncestorContext(descendant))
                local isRbcContext = context:find("robo", 1, true)
                    or context:find("challenge", 1, true)
                if isRbcContext and (lowered:find("collect", 1, true)
                    or lowered:find("gather", 1, true)
                    or lowered:find("make ", 1, true)
                    or lowered:find("convert", 1, true)
                    or lowered:find("defeat", 1, true)) then
                    local key = normalizeFieldText(text)
                    if key ~= "" and not seen[key] then
                        local target = inferRbcTaskTargetFromText(text)
                        if target then
                            seen[key] = true
                            table.insert(candidates, target)
                        end
                    end
                end
            end
        end
    end

    for _, rootInstance in ipairs(roots) do
        scanRoot(rootInstance)
    end

    if #candidates == 0 then
        scanRoot(playerGui)
    end

    table.sort(candidates, function(a, b)
        if a.complete ~= b.complete then
            return not a.complete
        end
        if a.explicitField ~= b.explicitField then
            return a.explicitField
        end
        return (a.remainingRatio or 1) > (b.remainingRatio or 1)
    end)

    return candidates
end

function getVisibleRbcTaskTarget()
    local candidates = getVisibleRbcTaskTargets()
    for _, target in ipairs(candidates) do
        if not target.complete and isValidFarmField(target.fieldName) then
            return target
        end
    end
    return candidates[1]
end

function tokenPosition(token)
    if not token then
        return nil
    end
    if token:IsA("BasePart") then
        return token.Position
    end
    if token:IsA("Model") then
        if token.PrimaryPart then
            return token.PrimaryPart.Position
        end
        local part = token:FindFirstChildWhichIsA("BasePart", true)
        return part and part.Position or nil
    end
    return nil
end

function getTokenIdentityText(token)
    local parts = { string.lower(tostring(token and token.Name or "")) }
    if token then
        local frontDecal = token:FindFirstChild("FrontDecal", true)
        if frontDecal and frontDecal:IsA("Decal") then
            table.insert(parts, string.lower(tostring(frontDecal.Texture or "")))
        end
        for _, descendant in ipairs(safeCall(function()
            return token:GetDescendants()
        end, EMPTY_TABLE)) do
            if descendant:IsA("Decal") then
                table.insert(parts, string.lower(tostring(descendant.Texture or "")))
            elseif descendant:IsA("Texture") then
                table.insert(parts, string.lower(tostring(descendant.Texture or "")))
            end
        end
    end
    return table.concat(parts, " ")
end

function identifyPriorityTokenName(token, requireEnabled)
    local frontDecal = token and token:FindFirstChild("FrontDecal")
    if frontDecal and frontDecal:IsA("Decal") then
        local mappedName = RBC_TOKEN_NAME_BY_TEXTURE_ID[getTextureAssetId(frontDecal.Texture)]
        if mappedName and (not requireEnabled or state.tokenPriorityConfig[mappedName] == true) then
            return mappedName
        end
    end

    local identity = getTokenIdentityText(token)
    for _, tokenDef in ipairs(PRIORITY_TOKEN_DEFS) do
        local tokenId = string.lower(tokenDef.id)
        local matches = identity:find(string.lower(tokenDef.name), 1, true)
            or (tokenId ~= "" and identity:find(tokenId, 1, true))
        if matches and (not requireEnabled or state.tokenPriorityConfig[tokenDef.name] == true) then
            return tokenDef.name
        end
    end
    return nil
end

function isPriorityToken(token)
    local priorityName = identifyPriorityTokenName(token, true)
    if priorityName then
        return true, priorityName
    end
    return false, identifyPriorityTokenName(token, false)
end

function getRbcTokenScore(tokenName, distance)
    if not tokenName or state.tokenPriorityConfig[tokenName] ~= true then
        return -(distance or 0)
    end
    local guideScore = RBC_TOKEN_GUIDE_SCORE[tokenName] or 45
    return (guideScore * 5) - math.min(distance or 0, 140)
end

function setCollectorInputHeld(enabled)
    enabled = enabled == true
    if state.collectorInputHeld == enabled then
        return true
    end

    local camera = Workspace.CurrentCamera
    local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
    local x = math.floor(viewport.X * 0.5)
    local y = math.floor(viewport.Y * 0.3)
    local ok = safeCall(function()
        VirtualInputManager:SendMouseMoveEvent(x, y, game)
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, enabled, game, 0)
        return true
    end, false)
    if ok then
        state.collectorInputHeld = enabled
    end
    return ok
end

function setAutoRbcWalkSpeed(enabled)
    local humanoid = getCharacterHumanoid()
    if enabled and humanoid then
        if state.walkSpeedHumanoid ~= humanoid then
            state.walkSpeedHumanoid = humanoid
            state.originalWalkSpeed = humanoid.WalkSpeed
        end
        humanoid.WalkSpeed = math.clamp(state.tweenSpeed, TWEEN_SPEED_MIN, TWEEN_SPEED_MAX)
        if not runtime.walkSpeedConnection then
            runtime.walkSpeedConnection = RunService.Heartbeat:Connect(function()
                if not isRuntimeActive() or not state.autoRbc then
                    return
                end
                local currentHumanoid = getCharacterHumanoid()
                if not currentHumanoid then
                    return
                end
                if state.walkSpeedHumanoid ~= currentHumanoid then
                    state.walkSpeedHumanoid = currentHumanoid
                    state.originalWalkSpeed = currentHumanoid.WalkSpeed
                end
                local desired = math.clamp(state.tweenSpeed, TWEEN_SPEED_MIN, TWEEN_SPEED_MAX)
                if currentHumanoid.WalkSpeed ~= desired then
                    currentHumanoid.WalkSpeed = desired
                end
            end)
        end
        return true
    end

    if runtime.walkSpeedConnection then
        safeCall(function()
            runtime.walkSpeedConnection:Disconnect()
        end, nil)
        runtime.walkSpeedConnection = nil
    end
    if state.walkSpeedHumanoid and state.walkSpeedHumanoid.Parent and state.originalWalkSpeed then
        state.walkSpeedHumanoid.WalkSpeed = state.originalWalkSpeed
    end
    state.walkSpeedHumanoid = nil
    state.originalWalkSpeed = nil
    return false
end

function placeRbcSprinkler(fieldName)
    local now = os.clock()
    if state.lastSprinklerField == fieldName and (now - state.lastSprinklerAt) < 30 then
        return false
    end
    local placed = safeCall(function()
        local actives = require(ReplicatedStorage:WaitForChild("PlayerActives"))
        local sprinkler = actives.Get("Sprinkler Builder")
        if not sprinkler then
            return false
        end
        sprinkler:ClientActivate()
        return true
    end, false)
    if placed then
        state.lastSprinklerField = fieldName
        state.lastSprinklerAt = now
    end
    return placed
end

function pointIsInsideFarmField(position, fieldName, padding)
    local field = findFarmFieldInstance(fieldName)
    if not position or not field or not field:IsA("BasePart") then
        local _, center, size = getFarmFieldTargetPosition(fieldName)
        if not position or not center or not size then
            return false
        end
        local localX = math.abs(position.X - center.X)
        local localZ = math.abs(position.Z - center.Z)
        return localX <= size.X * 0.5 + (padding or 0)
            and localZ <= size.Z * 0.5 + (padding or 0)
            and math.abs(position.Y - center.Y) <= size.Y * 0.5 + 20
    end

    local localPosition = field.CFrame:PointToObjectSpace(position)
    return math.abs(localPosition.X) <= field.Size.X * 0.5 + (padding or 0)
        and math.abs(localPosition.Z) <= field.Size.Z * 0.5 + (padding or 0)
        and math.abs(localPosition.Y) <= field.Size.Y * 0.5 + 20
end

function isValidCollectibleToken(token, fieldName)
    if not token
        or token.Parent ~= Workspace:FindFirstChild("Collectibles")
        or not token:IsA("BasePart")
        or token.Name ~= "C"
        or token.Transparency >= 0.98 then
        return false
    end
    local front = token:FindFirstChild("FrontDecal")
    local back = token:FindFirstChild("BackDecal")
    if not front or not back or not front:IsA("Decal") or not back:IsA("Decal") then
        return false
    end
    if getTextureAssetId(front.Texture) == ""
        or getTextureAssetId(front.Texture) ~= getTextureAssetId(back.Texture) then
        return false
    end
    return not fieldName or pointIsInsideFarmField(token.Position, fieldName, 3)
end

function getPreciseTargetPosition(target)
    if typeof(target) == "Instance" then
        if target:IsA("BasePart") then
            return target.Position, target
        end
        local part = target:FindFirstChildWhichIsA("BasePart", true)
        return part and part.Position or nil, part
    end
    if type(target) ~= "table" then
        return nil, nil
    end
    for _, key in ipairs({ "Disk", "Part", "Target", "Base" }) do
        local nested = target[key]
        if typeof(nested) == "Instance" or type(nested) == "table" then
            local position, part = getPreciseTargetPosition(nested)
            if position then
                return position, part
            end
        end
    end
    for _, key in ipairs({ "Pos", "Position", "Goal" }) do
        if typeof(target[key]) == "Vector3" then
            return target[key], nil
        end
    end
    return nil, nil
end

function registerPreciseTarget(value, visited, depth)
    visited = visited or {}
    depth = depth or 0
    if depth > 5 or visited[value] then
        return
    end
    visited[value] = true
    if type(value) == "table" then
        local position = getPreciseTargetPosition(value)
        if position and value.Mine == true then
            state.preciseTargets[value] = os.clock()
        end
        if value.Mine ~= false then
            for _, nested in pairs(value) do
                if type(nested) == "table" or typeof(nested) == "Instance" then
                    registerPreciseTarget(nested, visited, depth + 1)
                end
            end
        end
    elseif typeof(value) == "Instance" then
        return
    end
end

function installAutoPreciseHook()
    if runtime.preciseFxModule then
        return true
    end
    local moduleScript = ReplicatedStorage:FindFirstChild("LocalFX")
        and ReplicatedStorage.LocalFX:FindFirstChild("LocalTargetPracticeBeam")
    if not moduleScript then
        return false
    end
    local module = safeCall(function()
        return require(moduleScript)
    end, nil)
    if type(module) ~= "table" or type(module.Make) ~= "function" then
        return false
    end

    local originalMake = module.Make
    local wrappedMake
    wrappedMake = function(...)
        local args = table.pack(...)
        for index = 1, args.n do
            registerPreciseTarget(args[index])
        end
        local results = table.pack(originalMake(...))
        for index = 1, results.n do
            registerPreciseTarget(results[index])
        end
        return table.unpack(results, 1, results.n)
    end
    runtime.preciseFxModule = module
    runtime.preciseFxOriginalMake = originalMake
    runtime.preciseFxWrappedMake = wrappedMake
    runtime.preciseBeamTargets = safeCall(function()
        local values = table.pack(debug.getupvalue(module.UpdateBeams, 2))
        if type(values[1]) == "table" then
            return values[1]
        end
        if type(values[2]) == "table" then
            return values[2]
        end
        return nil
    end, nil)
    module.Make = wrappedMake
    return true
end

function getBestActivePreciseTarget(fieldName)
    local rootPart = getCharacterRoot()
    if not rootPart then
        return nil
    end
    local now = os.clock()
    if type(runtime.preciseBeamTargets) == "table" then
        for _, target in pairs(runtime.preciseBeamTargets) do
            if type(target) == "table" and target.Mine == true then
                local position = getPreciseTargetPosition(target)
                if position then
                    if not state.preciseObserved[target] then
                        state.preciseObserved[target] = true
                        state.preciseSeenCount += 1
                    end
                    if target.Touched == true and not state.preciseTouchedObserved[target] then
                        state.preciseTouchedObserved[target] = true
                        state.preciseTouchedCount += 1
                    end
                    state.preciseTargets[target] = now
                end
            end
        end
    end
    local best, bestPosition, bestPart, bestScore
    for target, seenAt in pairs(state.preciseTargets) do
        local position, part = getPreciseTargetPosition(target)
        local expired = (now - seenAt) > 12
        if type(target) == "table" then
            expired = expired
                or target.Mine ~= true
                or target.Touched == true
                or target.Activated == true
                or target.IsPurple == true
        end
        if not position or expired then
            state.preciseTargets[target] = nil
        else
            local distance = (rootPart.Position - position).Magnitude
            local score = 1000 - distance - (now - seenAt) * 20
            if not bestScore or score > bestScore then
                best, bestPosition, bestPart, bestScore = target, position, part, score
            end
        end
    end
    return best, bestPosition, bestPart
end

function stepAutoPrecise(fieldName)
    local target, position, part = getBestActivePreciseTarget(fieldName)
    if not target or not position then
        return false
    end
    setAutoRbcWalkSpeed(true)
    moveHumanoidToPosition(position)
    local rootPart = getCharacterRoot()
    if rootPart and part and firetouchinterest and (rootPart.Position - position).Magnitude <= 4.5 then
        safeCall(function()
            firetouchinterest(rootPart, part, 0)
            firetouchinterest(rootPart, part, 1)
        end, nil)
        if type(target) == "table" and runtime.preciseFxModule then
            safeCall(function()
                runtime.preciseFxModule.Touch(target)
            end, nil)
        end
    end
    local untouched = 0
    if type(runtime.preciseBeamTargets) == "table" then
        for _, beamTarget in pairs(runtime.preciseBeamTargets) do
            if type(beamTarget) == "table"
                and beamTarget.Mine == true
                and beamTarget.Touched ~= true
                and beamTarget.Activated ~= true then
                untouched += 1
            end
        end
    end
    state.detected.status = "Auto Precise | " .. tostring(untouched) .. " marks left in " .. fieldName
    pushUi()
    return true
end

function getFieldTokenRadius(size)
    if not size then
        return 0
    end
    return math.max(16, math.max(size.X, size.Z) * 0.48)
end

function collectTokensInField(fieldName)
    local collectibles = Workspace:FindFirstChild("Collectibles")
    local rootPart = getCharacterRoot()
    if not collectibles or not rootPart then
        return {}
    end

    local tokens = {}
    for _, token in ipairs(collectibles:GetChildren()) do
        if isValidCollectibleToken(token, fieldName)
            and (state.tokenFailureUntil[token] or 0) <= os.clock() then
            local pos = token.Position
            local priority, tokenName = isPriorityToken(token)
            table.insert(tokens, {
                instance = token,
                position = pos,
                priority = priority,
                tokenName = tokenName or "Field Token",
                distance = (rootPart.Position - pos).Magnitude
            })
        end
    end

    for _, token in ipairs(tokens) do
        token.score = getRbcTokenScore(token.tokenName, token.distance)
    end

    table.sort(tokens, function(a, b)
        if a.score ~= b.score then
            return a.score > b.score
        end
        return a.distance < b.distance
    end)

    return tokens
end

function buildTokenQueue(fieldName, tokens)
    local rootPart = getCharacterRoot()
    if not rootPart then
        return {}
    end

    local remaining = table.clone(tokens or collectTokensInField(fieldName))
    local queue = {}
    local cursor = rootPart.Position
    while #remaining > 0 and #queue < 10 do
        local bestIndex, bestRouteScore
        for index, token in ipairs(remaining) do
            local legDistance = (cursor - token.position).Magnitude
            local priorityScore = token.priority and (RBC_TOKEN_GUIDE_SCORE[token.tokenName] or 45) or 0
            local routeScore = priorityScore * 7 - legDistance * 1.35 - token.distance * 0.1
            if not bestRouteScore or routeScore > bestRouteScore then
                bestIndex, bestRouteScore = index, routeScore
            end
        end
        local selected = table.remove(remaining, bestIndex)
        selected.routeScore = bestRouteScore
        table.insert(queue, selected)
        cursor = selected.position
    end
    return queue
end

function clearActiveTokenTarget(failed)
    local target = state.activeTokenTarget
    if failed and target and target.instance then
        state.tokenFailureUntil[target.instance] = os.clock() + 1.75
    end
    state.activeTokenTarget = nil
    state.activeTokenStartedAt = 0
    state.tokenPathWaypoints = {}
    state.tokenPathIndex = 0
    state.tokenPathTarget = nil
end

function refreshTokenQueue(fieldName, force)
    local now = os.clock()
    if not force
        and state.tokenQueueField == fieldName
        and (now - state.lastTokenQueueRefreshAt) < 0.35 then
        return state.tokenQueue
    end

    state.tokenQueue = buildTokenQueue(fieldName, collectTokensInField(fieldName))
    state.tokenQueueField = fieldName
    state.tokenQueueBuiltAt = now
    state.lastTokenQueueRefreshAt = now
    return state.tokenQueue
end

function popNextTokenTarget(fieldName)
    refreshTokenQueue(fieldName, state.tokenQueueField ~= fieldName or #state.tokenQueue == 0)
    while #state.tokenQueue > 0 do
        local target = table.remove(state.tokenQueue, 1)
        if isValidCollectibleToken(target.instance, fieldName)
            and (state.tokenFailureUntil[target.instance] or 0) <= os.clock() then
            target.position = target.instance.Position
            state.activeTokenTarget = target
            state.activeTokenStartedAt = os.clock()
            return target
        end
    end
    return nil
end

function moveHumanoidToPosition(position)
    local humanoid = getCharacterHumanoid()
    if humanoid and position then
        humanoid:MoveTo(position)
        return true
    end
    return false
end

function recoverFarmMovementIfStalled(targetPosition)
    local rootPart = getCharacterRoot()
    local humanoid = getCharacterHumanoid()
    if not rootPart or not humanoid or not targetPosition then
        return false
    end

    local now = os.clock()
    if not state.lastFarmRootPosition then
        state.lastFarmRootPosition = rootPart.Position
        state.lastFarmMovementAt = now
        return false
    end

    local moved = Vector3.new(
        rootPart.Position.X - state.lastFarmRootPosition.X,
        0,
        rootPart.Position.Z - state.lastFarmRootPosition.Z
    ).Magnitude
    if moved >= 2 then
        state.lastFarmRootPosition = rootPart.Position
        state.lastFarmMovementAt = now
        return false
    end

    local targetDistance = Vector3.new(
        rootPart.Position.X - targetPosition.X,
        0,
        rootPart.Position.Z - targetPosition.Z
    ).Magnitude
    if targetDistance > 5
        and (now - state.lastFarmMovementAt) >= 1.6
        and (now - state.lastFarmStallRecoverAt) >= 1.5 then
        state.lastFarmStallRecoverAt = now
        state.lastFarmMovementAt = now
        state.lastFarmRootPosition = rootPart.Position
        local waypoints = safeCall(function()
            local path = PathfindingService:CreatePath({
                AgentRadius = 2,
                AgentHeight = 5,
                AgentCanJump = true,
                WaypointSpacing = 5
            })
            path:ComputeAsync(rootPart.Position, targetPosition)
            if path.Status == Enum.PathStatus.Success then
                return path:GetWaypoints()
            end
            return EMPTY_TABLE
        end, EMPTY_TABLE)
        state.tokenPathWaypoints = waypoints
        state.tokenPathIndex = math.min(2, #waypoints)
        state.tokenPathTarget = targetPosition
        local waypoint = waypoints[state.tokenPathIndex]
        if waypoint then
            if waypoint.Action == Enum.PathWaypointAction.Jump then
                humanoid.Jump = true
            end
            humanoid:MoveTo(waypoint.Position)
        else
            humanoid.Jump = true
            humanoid:MoveTo(targetPosition)
        end
        return true
    end
    return false
end

local FARM_PATROL_PATTERN = {
    Vector2.new(0, 0),
    Vector2.new(-0.32, -0.30),
    Vector2.new(0.32, -0.30),
    Vector2.new(0.32, 0),
    Vector2.new(-0.32, 0),
    Vector2.new(-0.32, 0.30),
    Vector2.new(0.32, 0.30),
    Vector2.new(0, 0.18)
}

function stepTokenCollectorInField(fieldName)
    local now = os.clock()
    local target = state.activeTokenTarget
    if target and not isValidCollectibleToken(target.instance, fieldName) then
        clearActiveTokenTarget(false)
        target = nil
    end

    if target and (now - state.activeTokenStartedAt) > 7 then
        clearActiveTokenTarget(true)
        target = nil
    end

    local queue = refreshTokenQueue(fieldName, state.tokenQueueField ~= fieldName)
    if target and #queue > 0 then
        local challenger = queue[1]
        local targetPriority = target.priority and (RBC_TOKEN_GUIDE_SCORE[target.tokenName] or 45) or 0
        local challengerPriority = challenger.priority and (RBC_TOKEN_GUIDE_SCORE[challenger.tokenName] or 45) or 0
        if challengerPriority >= targetPriority + 30 then
            clearActiveTokenTarget(false)
            target = nil
        end
    end

    target = target or popNextTokenTarget(fieldName)
    if target then
        target.position = target.instance.Position
        local rootPart = getCharacterRoot()
        local distance = rootPart and (rootPart.Position - target.position).Magnitude or math.huge
        if rootPart and distance <= 4.25 then
            if firetouchinterest then
                safeCall(function()
                    firetouchinterest(rootPart, target.instance, 0)
                    firetouchinterest(rootPart, target.instance, 1)
                end, nil)
            end
            state.tokenFailureUntil[target.instance] = now + 0.5
            clearActiveTokenTarget(false)
            refreshTokenQueue(fieldName, true)
            return true
        end

        if (now - state.lastTokenRepathAt) >= 0.25 then
            state.lastTokenRepathAt = now
            state.lastTokenCollectAt = now
            state.lastTokenCollectTarget = tostring(target.instance)
            setAutoRbcWalkSpeed(true)
            moveHumanoidToPosition(target.position)
            recoverFarmMovementIfStalled(target.position)
        end
        state.detected.status = "Auto farming " .. fieldName .. " | queue "
            .. tostring(target.tokenName) .. " | " .. tostring(#state.tokenQueue + 1) .. " planned"
        pushUi()
        return true
    end

    if (now - state.lastFarmPatrolAt) >= 0.85 then
        local targetPosition, _, size = getFarmFieldTargetPosition(fieldName)
        if targetPosition and size then
            state.farmPatrolIndex = (state.farmPatrolIndex % #FARM_PATROL_PATTERN) + 1
            local point = FARM_PATROL_PATTERN[state.farmPatrolIndex]
            local offset = Vector3.new(point.X * size.X, 0, point.Y * size.Z)
            local patrolTarget = targetPosition + offset
            setAutoRbcWalkSpeed(true)
            moveHumanoidToPosition(patrolTarget)
            recoverFarmMovementIfStalled(patrolTarget)
            state.lastFarmPatrolAt = now
        end
    end

    return false
end

function getBackpackFillRatioFromGui()
    if not playerGui then
        return 0
    end

    for _, descendant in ipairs(getCachedDescendants(playerGui)) do
        if isTextObject(descendant) and isVisibleGuiObject(descendant) and not descendant:IsDescendantOf(root) then
            local text = compactText(stripRichText(descendant.Text or ""))
            local lowered = string.lower(text)
            if lowered:find("pollen", 1, true) then
                local current, capacity = text:match("([%d,]+)%s*/%s*([%d,]+)")
                if current and capacity then
                    current = tonumber((current:gsub(",", ""))) or 0
                    capacity = tonumber((capacity:gsub(",", ""))) or 0
                    if capacity > 0 then
                        return current / capacity
                    end
                end
            end
        end
    end

    return 0
end

local RBC_ACTIVE_ITEM_INVENTORY_KEYS = {
    ["Gumdrops"] = "Gumdrops",
    ["Field Dice"] = "FieldDice",
    ["Smooth Dice"] = "SmoothDice",
    ["Loaded Dice"] = "LoadedDice",
    ["Glitter"] = "Glitter",
    ["Blue Extract"] = "BlueExtract",
    ["Red Extract"] = "RedExtract",
    ["Purple Potion"] = "PurplePotion",
    ["Super Smoothie"] = "SuperSmoothie",
    ["Micro-Converter"] = "Micro-Converter",
    ["Honeysuckle"] = "Honeysuckle"
}

local RBC_ACTIVE_ITEM_RESERVES = {
    ["Gumdrops"] = 500,
    ["Field Dice"] = 50,
    ["Smooth Dice"] = 50,
    ["Loaded Dice"] = 2,
    ["Glitter"] = 100,
    ["Blue Extract"] = 25,
    ["Red Extract"] = 25,
    ["Purple Potion"] = 20,
    ["Super Smoothie"] = 1,
    ["Micro-Converter"] = 5,
    ["Honeysuckle"] = 250
}

function getRbcInventoryCount(itemName)
    local stats = getCachedStatsSnapshot(false)
    local inventoryKey = RBC_ACTIVE_ITEM_INVENTORY_KEYS[itemName]
    if type(stats) ~= "table" or type(stats.Eggs) ~= "table" or not inventoryKey then
        return 0
    end
    return tonumber(stats.Eggs[inventoryKey]) or 0
end

function useRbcActiveItem(itemName, currentRound, reason, allowRepeat, cooldown)
    if not state.smartMaterials and itemName ~= "Field Dice" and itemName ~= "Smooth Dice" and itemName ~= "Loaded Dice" then
        return false
    end
    local now = os.clock()
    cooldown = tonumber(cooldown) or 3
    if (now - state.lastAnyMaterialAt) < 0.85
        or (now - (state.materialLastUsedAt[itemName] or 0)) < cooldown then
        return false
    end
    if not allowRepeat and state.materialLastUsedRound[itemName] == currentRound then
        return false
    end

    local count = getRbcInventoryCount(itemName)
    if count <= (RBC_ACTIVE_ITEM_RESERVES[itemName] or 0) then
        return false
    end

    local activated = safeCall(function()
        local actives = require(ReplicatedStorage:WaitForChild("PlayerActives"))
        local active = actives.Get(itemName)
        if not active or type(active.ClientActivate) ~= "function" then
            return false
        end
        active:ClientActivate()
        return true
    end, false)
    if activated then
        state.materialLastUsedAt[itemName] = now
        state.materialLastUsedRound[itemName] = currentRound
        state.lastAnyMaterialAt = now
        state.lastMaterialReason = itemName .. ": " .. tostring(reason or "RBC policy")
        state.cachedStats = nil
    end
    return activated
end

function getRbcTaskProfile()
    local profile = {
        red = false,
        blue = false,
        white = false,
        goo = false,
        convert = false,
        defeat = false,
        generic = false,
        remaining = 0,
        taskCount = 0
    }
    for _, target in ipairs(getVisibleRbcTaskTargets()) do
        if not target.complete then
            local text = string.lower(target.text or "")
            profile.taskCount += 1
            profile.red = profile.red or target.red == true
            profile.blue = profile.blue or target.blue == true
            profile.white = profile.white or target.white == true
            profile.goo = profile.goo or target.goo == true
            profile.convert = profile.convert or target.convert == true
            profile.defeat = profile.defeat or text:find("defeat", 1, true) ~= nil
            profile.remaining = math.max(profile.remaining, target.remainingRatio or 1)
            if not target.explicitField
                and not target.red
                and not target.blue
                and not target.white
                and not target.convert
                and not profile.defeat then
                profile.generic = true
            end
        end
    end
    return profile
end

function stepSmartRbcMaterials(roundSummary, fieldName)
    local currentRound = tonumber(roundSummary and roundSummary.round) or getCurrentRbcRound()
    if currentRound <= 0 then
        return false
    end
    local timerSeconds = tonumber(roundSummary and roundSummary.timerSeconds) or 999
    local profile = getRbcTaskProfile()

    if state.smartMaterials and profile.goo and currentRound >= state.gooGumdropsMinRound then
        if useRbcActiveItem("Gumdrops", currentRound, "matching goo quest", true, 4.2) then
            return true
        end
    end

    if state.smartMaterials and currentRound >= state.boostMinRound then
        if profile.blue and state.route == "red"
            and useRbcActiveItem("Blue Extract", currentRound, "off-color blue quest", false, 10) then
            return true
        end
        if profile.white and currentRound >= 20 and timerSeconds <= 170
            and useRbcActiveItem("Purple Potion", currentRound, "late white quest", false, 10) then
            return true
        end
        if profile.red and currentRound >= 23 and timerSeconds <= 110
            and useRbcActiveItem("Red Extract", currentRound, "late red quest", false, 10) then
            return true
        end
        if currentRound >= 23 and timerSeconds <= 90 and profile.remaining >= 0.45
            and useRbcActiveItem("Super Smoothie", currentRound, "round 23+ emergency", false, 30) then
            return true
        end
    end

    if state.smartBoosts and currentRound >= state.boostMinRound then
        local signature = tostring(currentRound) .. "::" .. tostring(state.lastRbcTaskSignature) .. "::" .. tostring(fieldName)
        if signature ~= state.lastBoostTaskSignature then
            local itemName = currentRound >= 22 and "Loaded Dice"
                or currentRound >= 18 and "Smooth Dice"
                or "Field Dice"
            if useRbcActiveItem(itemName, currentRound, "new difficult field objective", false, 15) then
                state.lastBoostTaskSignature = signature
                return true
            end
        end
    end

    local fillRatio = getBackpackFillRatioFromGui()
    if state.smartMaterials and currentRound >= state.instantConvertMinRound and fillRatio >= 0.9 then
        if useRbcActiveItem("Micro-Converter", currentRound, "high bag fill", false, 8) then
            return true
        end
        if timerSeconds <= 65
            and useRbcActiveItem("Honeysuckle", currentRound, "conversion emergency", false, 12) then
            return true
        end
    end
    return false
end

function getRbcCombatTarget(currentRound)
    if not state.smartCombat then
        return nil, 0
    end
    local monsters = Workspace:FindFirstChild("FEMonsters")
    if not monsters then
        return nil, 0
    end
    local profile = getRbcTaskProfile()
    local rootPart = getCharacterRoot()
    local candidates = {}
    local relevantCount = 0
    for _, monster in ipairs(monsters:GetChildren()) do
        local lowered = string.lower(tostring(monster.Name or ""))
        local golden = lowered:find("golden cogmower", 1, true) ~= nil
        local mechsquito = lowered:find("mechsquito", 1, true) ~= nil
        if (golden and currentRound < 20) or (mechsquito and profile.defeat) then
            local position = getInstanceCenterAndSize(monster)
            if position then
                relevantCount += 1
                local big = lowered:find("mega", 1, true) or lowered:find("big", 1, true)
                local distance = rootPart and (rootPart.Position - position).Magnitude or math.huge
                table.insert(candidates, {
                    instance = monster,
                    position = position,
                    score = (golden and 500 or 0) + (big and 300 or 0) - distance
                })
            end
        end
    end
    table.sort(candidates, function(a, b)
        return a.score > b.score
    end)
    return candidates[1], relevantCount
end

function stepRbcCombat(currentRound)
    local target, targetCount = getRbcCombatTarget(currentRound)
    if not target then
        state.combatTarget = nil
        state.combatTargetStartedAt = 0
        return false
    end
    local humanoid = getCharacterHumanoid()
    local rootPart = getCharacterRoot()
    if not humanoid or not rootPart or humanoid.Health < math.max(30, humanoid.MaxHealth * 0.3) then
        return false
    end
    if state.combatTarget ~= target.instance then
        state.combatTarget = target.instance
        state.combatTargetStartedAt = os.clock()
    elseif (os.clock() - state.combatTargetStartedAt) > 9 and targetCount < 4 then
        return false
    end

    local distance = (rootPart.Position - target.position).Magnitude
    local movePosition = target.position + Vector3.new(0, 3, 0)
    if distance > 11 then
        moveHumanoidToPosition(movePosition)
        recoverFarmMovementIfStalled(movePosition)
    else
        humanoid:MoveTo(rootPart.Position)
        if (os.clock() - state.lastCombatJumpAt) >= 0.55 then
            humanoid.Jump = true
            state.lastCombatJumpAt = os.clock()
        end
    end
    state.detected.status = "Combat focus: " .. tostring(target.instance.Name)
        .. " | nearby objectives " .. tostring(targetCount)
    pushUi()
    return true
end

function getClaimedHiveTargetPosition()
    local stats = getCachedStatsSnapshot(false)
    local claimedHive = nil
    if type(stats) == "table" and type(stats.Transient) == "table" then
        claimedHive = stats.Transient.ClaimedHive
    end

    local hivePlatforms = Workspace:FindFirstChild("HivePlatforms")
    if hivePlatforms then
        for _, platform in ipairs(hivePlatforms:GetChildren()) do
            local hiveValue = platform:FindFirstChild("Hive")
            local matchesClaim = not claimedHive
                or tostring(platform.Name) == tostring(claimedHive)
                or (hiveValue and hiveValue.Value and tostring(hiveValue.Value.Name) == tostring(claimedHive))
            if matchesClaim then
                local center, size = getInstanceCenterAndSize(platform)
                if center and size then
                    return center + Vector3.new(0, math.max(4, size.Y / 2 + 4), 0)
                end
            end
        end
    end

    local honeycombs = Workspace:FindFirstChild("Honeycombs")
    if honeycombs and claimedHive then
        local hive = honeycombs:FindFirstChild(tostring(claimedHive))
        local center, size = getInstanceCenterAndSize(hive)
        if center and size then
            return center + Vector3.new(0, math.max(4, size.Y / 2 + 4), 0)
        end
    end

    return nil
end

function stepConvertQuestIfNeeded()
    if getBackpackFillRatioFromGui() < 0.98 then
        return false
    end

    local now = os.clock()
    if (now - state.lastHiveMoveAt) < 2.5 then
        return true
    end

    local hivePosition = getClaimedHiveTargetPosition()
    if not hivePosition then
        return false
    end

    state.lastHiveMoveAt = now
    moveHumanoidToPosition(hivePosition)
    state.detected.status = "Auto RBC convert: backpack full, moving to hive"
    pushUi()
    return true
end

function getUprightTweenCFrame(rootPart, targetPosition)
    local flatTarget = Vector3.new(targetPosition.X, rootPart.Position.Y, targetPosition.Z)
    if (flatTarget - rootPart.Position).Magnitude < 0.1 then
        return rootPart.CFrame
    end
    return CFrame.lookAt(rootPart.Position, flatTarget)
end

function setCharacterNoclip(enabled, session)
    local character = LocalPlayer.Character
    if enabled and not character then
        return
    end

    if enabled then
        session.partCollision = session.partCollision or {}
        session.noclipEnabled = true
        for _, descendant in ipairs(character:GetDescendants()) do
            if descendant:IsA("BasePart") then
                if session.partCollision[descendant] == nil then
                    session.partCollision[descendant] = descendant.CanCollide
                end
                descendant.CanCollide = false
            end
        end

        if not session.noclipDescendantConnection then
            session.noclipDescendantConnection = character.DescendantAdded:Connect(function(descendant)
                if session.noclipEnabled and descendant:IsA("BasePart") then
                    if session.partCollision[descendant] == nil then
                        session.partCollision[descendant] = descendant.CanCollide
                    end
                    descendant.CanCollide = false
                end
            end)
        end

        if not session.noclipStepConnection then
            session.noclipStepConnection = RunService.Stepped:Connect(function()
                if session.cancelled or not session.noclipEnabled then
                    return
                end
                local currentCharacter = LocalPlayer.Character
                if not currentCharacter then
                    return
                end
                for _, descendant in ipairs(currentCharacter:GetDescendants()) do
                    if descendant:IsA("BasePart") then
                        if session.partCollision[descendant] == nil then
                            session.partCollision[descendant] = descendant.CanCollide
                        end
                        descendant.CanCollide = false
                    end
                end
            end)
        end
        return
    end

    session.noclipEnabled = false
    if session.noclipDescendantConnection then
        pcall(function()
            session.noclipDescendantConnection:Disconnect()
        end)
        session.noclipDescendantConnection = nil
    end
    if session.noclipStepConnection then
        pcall(function()
            session.noclipStepConnection:Disconnect()
        end)
        session.noclipStepConnection = nil
    end

    if type(session.partCollision) == "table" then
        for part, canCollide in pairs(session.partCollision) do
            if part and part.Parent then
                pcall(function()
                    part.CanCollide = canCollide
                end)
            end
        end
    end
    session.partCollision = {}
end

function cleanupMoveSession(session)
    if not session then
        return
    end

    setCharacterNoclip(false, session)
    if session.humanoid and session.humanoid.Parent and session.previousAutoRotate ~= nil then
        pcall(function()
            session.humanoid.AutoRotate = session.previousAutoRotate
        end)
    end
    if session.align then
        pcall(function()
            session.align:Destroy()
        end)
        session.align = nil
    end
    if session.orientation then
        pcall(function()
            session.orientation:Destroy()
        end)
        session.orientation = nil
    end
    if session.attachment then
        pcall(function()
            session.attachment:Destroy()
        end)
        session.attachment = nil
    end
    if runtime.moveSession == session then
        runtime.moveSession = nil
    end
    state.moveInProgress = false
end

function stopMoveSession()
    local session = runtime.moveSession
    if session then
        session.cancelled = true
        cleanupMoveSession(session)
    end
end

function tweenToRoboBearCircle()
    if state.moveInProgress then
        state.detected.status = "Move already in progress"
        pushUi()
        return false
    end

    local rootPart = getCharacterRoot()
    local circle = getRoboBearCircle()
    if not rootPart or not circle then
        state.detected.status = "Tween move failed: character or Robo Bear circle missing"
        pushUi()
        return false
    end

    stopMoveSession()

    local function getCircleTargetPosition()
        return circle.Position + Vector3.new(0, math.max(3, circle.Size.Y / 2 + 3), 0)
    end

    local targetPosition = getCircleTargetPosition()
    local session = {
        cancelled = false,
        partCollision = {}
    }
    session.cleanup = function()
        cleanupMoveSession(session)
    end
    runtime.moveSession = session
    state.moveInProgress = true

    local humanoid = getCharacterHumanoid()
    if humanoid then
        session.humanoid = humanoid
        session.previousAutoRotate = humanoid.AutoRotate
        pcall(function()
            humanoid.AutoRotate = false
        end)
    end

    local attachment = Instance.new("Attachment")
    attachment.Name = "RBCMoveAttachment"
    attachment.Parent = rootPart
    session.attachment = attachment

    local align = Instance.new("AlignPosition")
    align.Name = "RBCMoveAlignPosition"
    align.Mode = Enum.PositionAlignmentMode.OneAttachment
    align.Attachment0 = attachment
    align.Position = targetPosition
    align.ApplyAtCenterOfMass = true
    align.MaxForce = 1000000
    align.MaxVelocity = getTweenVelocity()
    align.Responsiveness = 120
    align.RigidityEnabled = false
    align.Parent = rootPart
    session.align = align

    local orientation = Instance.new("AlignOrientation")
    orientation.Name = "RBCMoveAlignOrientation"
    orientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
    orientation.Attachment0 = attachment
    orientation.CFrame = getUprightTweenCFrame(rootPart, targetPosition)
    orientation.MaxTorque = 1000000
    orientation.Responsiveness = 200
    orientation.RigidityEnabled = true
    orientation.Parent = rootPart
    session.orientation = orientation

    task.spawn(function()
        local startedAt = os.clock()
        local timeout = math.clamp((rootPart.Position - targetPosition).Magnitude / math.max(20, align.MaxVelocity) + 4, 6, 30)
        while isRuntimeActive() and not session.cancelled do
            if not rootPart.Parent or not circle.Parent then
                break
            end

            targetPosition = getCircleTargetPosition()

            align.Position = targetPosition
            align.MaxVelocity = getTweenVelocity()
            orientation.CFrame = getUprightTweenCFrame(rootPart, targetPosition)
            setCharacterNoclip(true, session)

            local horizontalDistance = Vector3.new(rootPart.Position.X - targetPosition.X, 0, rootPart.Position.Z - targetPosition.Z).Magnitude
            if horizontalDistance <= 1.5 and math.abs(rootPart.Position.Y - targetPosition.Y) <= 5 then
                break
            end
            if (os.clock() - startedAt) > timeout then
                break
            end
            task.wait(0.05)
        end

        cleanupMoveSession(session)
        if rootPart and rootPart.Parent then
            pcall(function()
                rootPart.AssemblyLinearVelocity = Vector3.new()
                rootPart.AssemblyAngularVelocity = Vector3.new()
            end)
        end
        if isRuntimeActive() then
            state.detected.status = session.cancelled and "Tween move cancelled" or "Tween move finished at Robo Bear circle"
            pushUi()
        end
    end)

    state.detected.status = "Tweening to Robo Bear circle"
    pushUi()
    return true
end

function tweenToFarmField(fieldName)
    if state.moveInProgress then
        state.detected.status = "Move already in progress"
        pushUi()
        return false
    end

    if not isValidFarmField(fieldName) then
        state.detected.status = "Field tween failed: invalid field"
        pushUi()
        return false
    end

    local rootPart = getCharacterRoot()
    local targetPosition = getFarmFieldTargetPosition(fieldName)
    if not rootPart or not targetPosition then
        state.detected.status = "Field tween failed: character or " .. fieldName .. " missing"
        pushUi()
        return false
    end

    stopMoveSession()

    local session = {
        cancelled = false,
        partCollision = {}
    }
    session.cleanup = function()
        cleanupMoveSession(session)
    end
    runtime.moveSession = session
    state.moveInProgress = true

    local humanoid = getCharacterHumanoid()
    if humanoid then
        session.humanoid = humanoid
        session.previousAutoRotate = humanoid.AutoRotate
        pcall(function()
            humanoid.AutoRotate = false
        end)
    end

    local attachment = Instance.new("Attachment")
    attachment.Name = "RBCMoveAttachment"
    attachment.Parent = rootPart
    session.attachment = attachment

    local align = Instance.new("AlignPosition")
    align.Name = "RBCMoveAlignPosition"
    align.Mode = Enum.PositionAlignmentMode.OneAttachment
    align.Attachment0 = attachment
    align.Position = targetPosition
    align.ApplyAtCenterOfMass = true
    align.MaxForce = 1000000
    align.MaxVelocity = getTweenVelocity()
    align.Responsiveness = 120
    align.RigidityEnabled = false
    align.Parent = rootPart
    session.align = align

    local orientation = Instance.new("AlignOrientation")
    orientation.Name = "RBCMoveAlignOrientation"
    orientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
    orientation.Attachment0 = attachment
    orientation.CFrame = getUprightTweenCFrame(rootPart, targetPosition)
    orientation.MaxTorque = 1000000
    orientation.Responsiveness = 200
    orientation.RigidityEnabled = true
    orientation.Parent = rootPart
    session.orientation = orientation

    task.spawn(function()
        local startedAt = os.clock()
        local timeout = math.clamp((rootPart.Position - targetPosition).Magnitude / math.max(20, align.MaxVelocity) + 4, 6, 40)
        while isRuntimeActive() and not session.cancelled do
            if not rootPart.Parent then
                break
            end

            targetPosition = getFarmFieldTargetPosition(fieldName)
            if not targetPosition then
                break
            end

            align.Position = targetPosition
            align.MaxVelocity = getTweenVelocity()
            orientation.CFrame = getUprightTweenCFrame(rootPart, targetPosition)
            setCharacterNoclip(true, session)

            if isStandingAtFarmField(fieldName) then
                break
            end
            if (os.clock() - startedAt) > timeout then
                break
            end
            task.wait(0.05)
        end

        cleanupMoveSession(session)
        if rootPart and rootPart.Parent then
            pcall(function()
                rootPart.AssemblyLinearVelocity = Vector3.new()
                rootPart.AssemblyAngularVelocity = Vector3.new()
            end)
        end
        if isRuntimeActive() then
            state.detected.status = session.cancelled and "Field tween cancelled" or ("Tween move finished at " .. fieldName)
            pushUi()
        end
    end)

    state.detected.status = "Tweening to " .. fieldName
    pushUi()
    return true
end

function setMoveMethod(methodName)
    if methodName ~= "walk" and methodName ~= "tween" then
        return
    end

    state.moveMethod = methodName
    if methodName == "walk" then
        stopMoveSession()
        state.detected.status = "Move method set to Walk (placeholder)"
        pushUi()
        return
    end

    tweenToRoboBearCircle()
end

function beginChallengeInfoWait()
    state.waitingForChallengeInfoAfterRoundStart = true
    state.lastChallengeInfoWaitStartedAt = os.clock()
end

function clearChallengeInfoWait()
    state.waitingForChallengeInfoAfterRoundStart = false
    state.lastChallengeInfoWaitStartedAt = 0
end

function isLiveRoboBearChallengeUiVisible()
    local mainFrame = findRoboBearChallengePromptFrame()
    if not isGuiActuallyShown(mainFrame) then
        return false
    end

    return hasVisibleTextUnder(mainFrame, {
        "choose a quest",
        "choose a bee",
        "choose an upgrade",
        "choose a upgrade",
        "purchase upgrades",
        "robo bear challenge: round",
        "active bees",
        "active upgrades",
        "reroll (cost:",
        "cogs:"
    })
end

function isWaitingForChallengeInfo()
    if state.waitingForChallengeInfoAfterRoundStart ~= true then
        return false
    end

    if isLiveRoboBearChallengeUiVisible() then
        clearChallengeInfoWait()
        return false
    end

    if state.lastChallengeInfoWaitStartedAt > 0 and (os.clock() - state.lastChallengeInfoWaitStartedAt) > 6 then
        clearChallengeInfoWait()
        return false
    end

    return true
end

function findRoboBearPromptGui()
    local screenGui = getScreenGuiRoot()
    if not screenGui then
        return nil
    end

    local activateText = findDescendantByPath(screenGui, { "ActivateButton", "TextBox" })
    if activateText and isTextObject(activateText) and isVisibleGuiObject(activateText) then
        local text = string.lower(compactText(stripRichText(activateText.Text or "")))
        if text:find("talk to robo bear", 1, true) then
            return activateText
        end
    end

    for _, descendant in ipairs(getCachedDescendants(screenGui)) do
        if isTextObject(descendant) and isVisibleGuiObject(descendant) then
            local text = string.lower(compactText(stripRichText(descendant.Text or "")))
            if text:find("talk to robo bear", 1, true) then
                return descendant
            end
        end
    end

    return nil
end

function findRoboBearChallengePromptFrame()
    return getRoboBearMainFrame()
end

function hasVisibleTextUnder(rootInstance, patterns)
    if not rootInstance then
        return false
    end

    for _, descendant in ipairs(getCachedDescendants(rootInstance)) do
        if isTextObject(descendant) and isVisibleGuiObject(descendant) then
            local text = string.lower(stripRichText(descendant.Text or ""))
            for _, pattern in ipairs(patterns) do
                if text:find(pattern, 1, true) then
                    return true
                end
            end
        end
    end

    return false
end

function isGuiActuallyShown(guiObject)
    if not guiObject or not guiObject:IsA("GuiObject") then
        return false
    end

    local current = guiObject
    while current and current ~= playerGui do
        if current:IsA("GuiObject") and current.Visible == false then
            return false
        end
        current = current.Parent
    end

    local size = safeCall(function()
        return guiObject.AbsoluteSize
    end, nil)
    local position = safeCall(function()
        return guiObject.AbsolutePosition
    end, nil)

    return size ~= nil
        and position ~= nil
        and size.X > 20
        and size.Y > 20
        and position.X > -5000
        and position.Y > -5000
end

function isRoboBearChallengePromptOpen()
    local mainFrame = findRoboBearChallengePromptFrame()
    return isGuiActuallyShown(mainFrame) and hasVisibleTextUnder(mainFrame, {
        "choose a quest",
        "choose a bee",
        "purchase upgrades",
        "choose an upgrade"
    })
end

function isRoboBearPromptVisible()
    return findRoboBearPromptGui() ~= nil
end

function getNpcDialogGui()
    return findDescendantByPath(getScreenGuiRoot(), { "NPC" })
end

function isNpcDialogOpen()
    local npcGui = getNpcDialogGui()
    if not npcGui or not npcGui:IsA("GuiObject") or npcGui.Visible ~= true then
        return false
    end

    local size = safeCall(function()
        return npcGui.AbsoluteSize
    end, nil)
    if not size or size.X < 100 or size.Y < 80 then
        return false
    end

    for _, descendant in ipairs(getCachedDescendants(npcGui)) do
        if isTextObject(descendant) and isVisibleGuiObject(descendant) then
            local text = compactText(stripRichText(descendant.Text or ""))
            local lowered = string.lower(text)
            if text ~= ""
                and (lowered:find("robo bear", 1, true)
                    or lowered:find("welcome", 1, true)
                    or lowered:find("click to continue", 1, true)
                    or lowered:find("challenge", 1, true)) then
                return true
            end
        end
    end

    return false
end

function isNpcDialogShowingRoundInProgress()
    local npcGui = getNpcDialogGui()
    if not npcGui or not isNpcDialogOpen() then
        return false
    end

    for _, descendant in ipairs(getCachedDescendants(npcGui)) do
        if isTextObject(descendant) and isVisibleGuiObject(descendant) then
            local text = string.lower(compactText(stripRichText(descendant.Text or "")))
            if text:find("round is in progress", 1, true) then
                return true
            end
        end
    end

    return false
end

function triggerRoboBearInteract()
    if isNpcDialogOpen() then
        return clickNpcDialogAction()
    end

    if not isStandingAtRoboBearCircle() and not isRoboBearPromptVisible() then
        return false, "not_at_robo_bear"
    end

    local sent = safeCall(function()
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
        return true
    end, false)
    return sent, sent and "virtual_e" or "virtual_e_unavailable"
end

function getGuiBounds(guiObject)
    if not guiObject or not guiObject:IsA("GuiObject") then
        return nil, nil
    end

    local position = safeCall(function()
        return guiObject.AbsolutePosition
    end, nil)
    local size = safeCall(function()
        return guiObject.AbsoluteSize
    end, nil)

    if not position or not size then
        return nil, nil
    end

    return position, size
end

function getNpcDialogOptionKind(text)
    local lowered = string.lower(compactText(stripRichText(text or "")))
    local normalized = lowered:gsub("[^%w%s]", " "):gsub("%s+", " ")

    if normalized:find("spend", 1, true)
        and normalized:find("robo pass", 1, true)
        and normalized:find("challenge", 1, true) then
        return "start"
    end

    if normalized:find("start", 1, true)
        and normalized:find("robo bear", 1, true)
        and normalized:find("challenge", 1, true) then
        return "start"
    end

    if normalized:find("explain", 1, true) and normalized:find("rules", 1, true) then
        return "explain"
    end

    if normalized:find("cancel", 1, true) then
        return "cancel"
    end

    return nil
end

function findDialogOptionRow(textObject, npcGui)
    local clickable = findClickableAncestor(textObject)
    if clickable and clickable:IsA("GuiObject") then
        return clickable
    end

    local textPosition, textSize = getGuiBounds(textObject)
    local current = textObject and textObject.Parent
    while current and current ~= npcGui and current ~= playerGui do
        if current:IsA("GuiObject") then
            local position, size = getGuiBounds(current)
            if position and size and textSize and size.X >= textSize.X and size.Y >= textSize.Y and size.Y <= 90 then
                return current
            end
        end
        current = current.Parent
    end

    return textObject
end

function collectNpcDialogOptions(npcGui)
    local options = {}
    local byRow = {}

    if not npcGui then
        return options
    end

    for _, descendant in ipairs(getCachedDescendants(npcGui)) do
        if isTextObject(descendant) and isVisibleGuiObject(descendant) then
            local text = compactText(stripRichText(descendant.Text or ""))
            local kind = getNpcDialogOptionKind(text)
            local textPosition, textSize = getGuiBounds(descendant)

            if kind and textPosition and textSize then
                local rowObject = findDialogOptionRow(descendant, npcGui)
                local rowPosition, rowSize = getGuiBounds(rowObject)
                local key = rowObject and getFullPath(rowObject) or getFullPath(descendant)
                local candidate = {
                    kind = kind,
                    text = text,
                    object = descendant,
                    rowObject = rowObject,
                    position = rowPosition or textPosition,
                    size = rowSize or textSize,
                    textPosition = textPosition,
                    textSize = textSize
                }

                if not byRow[key] or #candidate.text > #(byRow[key].text or "") then
                    byRow[key] = candidate
                end
            end
        end
    end

    for _, candidate in pairs(byRow) do
        table.insert(options, candidate)
    end

    table.sort(options, function(a, b)
        if math.abs(a.position.Y - b.position.Y) > 2 then
            return a.position.Y < b.position.Y
        end
        return a.position.X < b.position.X
    end)

    for index, candidate in ipairs(options) do
        candidate.optionIndex = index
    end

    return options
end

function findNpcDialogStartOption(npcGui)
    local options = collectNpcDialogOptions(npcGui)
    for _, candidate in ipairs(options) do
        if candidate.kind == "start" then
            return candidate, options
        end
    end
    return nil, options
end

function invokeNpcTextBoxClick()
    local controllerClick = runtime.npcTextBoxClick
    if type(controllerClick) ~= "function" then
        for _, value in ipairs(safeCall(function()
            return getgc(true)
        end, EMPTY_TABLE)) do
            if type(value) == "function"
                and debug.info(value, "n") == "textBoxClick"
                and tostring(debug.info(value, "s") or ""):find("Camera.Controllers.NPC", 1, true) then
                controllerClick = value
                runtime.npcTextBoxClick = value
                break
            end
        end
    end
    if type(controllerClick) ~= "function" then
        return false
    end
    return safeCall(function()
        controllerClick()
        return true
    end, false)
end

function dismissNpcDialogDuringRound()
    if not isNpcDialogOpen() then
        return false
    end
    local npcGui = getNpcDialogGui()
    for _, candidate in ipairs(collectNpcDialogOptions(npcGui)) do
        if candidate.kind == "cancel" then
            local cancelled = select(1, clickNpcDialogContinue(candidate))
            if cancelled then
                runtime.npcDialogForcedHidden = false
                return true
            end
        end
    end
    local finishDialogue = runtime.npcFinishDialogue
    if type(finishDialogue) ~= "function" then
        for _, value in ipairs(safeCall(function()
            return getgc(true)
        end, EMPTY_TABLE)) do
            if type(value) == "function"
                and debug.info(value, "n") == "finishDialogue"
                and tostring(debug.info(value, "s") or ""):find("Camera.Controllers.NPC", 1, true) then
                finishDialogue = value
                runtime.npcFinishDialogue = value
                break
            end
        end
    end
    if type(finishDialogue) == "function" then
        safeCall(function()
            finishDialogue()
            return true
        end, false)
    end
    if npcGui then
        return safeCall(function()
            npcGui.Visible = false
            runtime.npcDialogForcedHidden = true
            return true
        end, false)
    end
    return false
end

function invokeGuiButtonClick(button)
    if not button or not button:IsA("GuiButton") then
        return false
    end
    if getconnections then
        for _, connection in ipairs(safeCall(function()
            return getconnections(button.MouseButton1Click)
        end, EMPTY_TABLE)) do
            local fn = connection.Function
            if type(fn) == "function" then
                local source = tostring(debug.info(fn, "s") or "")
                if source:find("Camera.Controllers.NPC", 1, true) then
                    local selectOption = debug.getupvalue(fn, 2)
                    local optionIndex = debug.getupvalue(fn, 3)
                    if type(selectOption) == "function" and type(optionIndex) == "number" then
                        return safeCall(function()
                            selectOption(optionIndex)
                            return true
                        end, false)
                    end
                end
                local invoked = safeCall(function()
                    fn()
                    return true
                end, false)
                if invoked then
                    return true
                end
            end
        end
    end
    if firesignal then
        return safeCall(function()
            firesignal(button.MouseButton1Click)
            return true
        end, false)
    end
    return false
end

function clickNpcDialogContinue(candidate)
    if not candidate then
        return false, "no_continue_candidate"
    end

    local object = candidate.rowObject or candidate.object
    local clickable = findClickableAncestor(object) or object
    if clickable and clickable:IsA("GuiButton") then
        local fired = invokeGuiButtonClick(clickable)
        if fired then
            return true, "dialog_signal"
        end
    end

    if invokeNpcTextBoxClick() then
        return true, "dialog_controller"
    end

    local position = candidate.position
    local size = candidate.size
    if (not position or not size) and object then
        position, size = getGuiBounds(object)
    end
    if not position or not size then
        return false, "dialog_bounds_missing"
    end

    local wasOverlayVisible = root and root.Visible == true
    if wasOverlayVisible then
        root.Visible = false
    end
    local x = math.floor(position.X + size.X / 2)
    local y = math.floor(position.Y + size.Y / 2)
    local advanced = safeCall(function()
        VirtualInputManager:SendMouseMoveEvent(x, y, game)
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 0)
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 0)
        return true
    end, false)
    if wasOverlayVisible then
        task.delay(0.12, function()
            if isRuntimeActive() and root then
                root.Visible = true
            end
        end)
    end
    if advanced then
        return true, "dialog_mouse_safe"
    end

    return false, "dialog_click_unavailable"
end

function clickNpcDialogOption(candidate)
    if not candidate then
        return false, "no_candidate"
    end

    if candidate.kind == "start" then
        local clicked, clickAction = clickNpcDialogContinue(candidate)
        local lowered = string.lower(candidate.text or "")
        local roundEndSummary = refreshRoboBearRoundEndState(false)
        local continuing = lowered:find("start round", 1, true) ~= nil
            or lowered:find("continue", 1, true) ~= nil
            or (roundEndSummary and roundEndSummary.ended)
        local actionName = continuing and "startRound" or "start"
        local fired, action = fireRoboBearDialogAction(actionName)
        if fired then
            local npcGui = getNpcDialogGui()
            local cancelButton = npcGui and npcGui:FindFirstChild("OptionFrame")
                and npcGui.OptionFrame:FindFirstChild("Option3")
            if cancelButton and cancelButton:IsA("GuiButton") then
                invokeGuiButtonClick(cancelButton)
            end
            return true, "start_remote_" .. tostring(action)
        end
        if clicked then
            return true, "start_" .. tostring(clickAction)
        end
        return false, tostring(action)
    end

    return false, "dialog_option_not_remote_safe"
end

function clickNpcDialogAction()
    if not isNpcDialogOpen() and isRoboBearChallengePromptOpen() then
        return false, "robo_prompt_open"
    end

    local npcGui = getNpcDialogGui()
    if not npcGui or not isNpcDialogOpen() then
        return false, "closed"
    end

    local continueCandidate
    local fallbackText
    local visibleTexts = {}
    local startCandidate = findNpcDialogStartOption(npcGui)

    for _, descendant in ipairs(getCachedDescendants(npcGui)) do
        if isTextObject(descendant) and isVisibleGuiObject(descendant) then
            local text = compactText(stripRichText(descendant.Text or ""))
            local lowered = string.lower(text)
            local pos, size = getGuiBounds(descendant)

            if text ~= "" then
                fallbackText = fallbackText or descendant
                table.insert(visibleTexts, lowered)
            end

            if pos and size and lowered:find("commencing round", 1, true) then
                continueCandidate = { object = descendant, position = pos, size = size }
            elseif pos and size and lowered:find("loading: round", 1, true) then
                continueCandidate = { object = descendant, position = pos, size = size }
            elseif pos and size and lowered:find("click to continue", 1, true) then
                continueCandidate = { object = descendant, position = pos, size = size }
            end
        end
    end

    if startCandidate then
        local clicked, action = clickNpcDialogOption(startCandidate)
        if clicked then
            return true, "start_remote_" .. tostring(action)
        end
        return false, tostring(action)
    end

    if continueCandidate then
        return clickNpcDialogContinue(continueCandidate)
    end

    if fallbackText then
        for _, text in ipairs(visibleTexts) do
            if text:find("welcome", 1, true) then
                local pos, size = getGuiBounds(fallbackText)
                return clickNpcDialogContinue({ object = fallbackText, position = pos, size = size })
            end
            if text:find("ready", 1, true) and text:find("challenge", 1, true) then
                local pos, size = getGuiBounds(fallbackText)
                return clickNpcDialogContinue({ object = fallbackText, position = pos, size = size })
            end
        end
        return false, "dialog_waiting_for_remote"
    end

    return false, "no_remote_dialog_action"
end

function findClickableAncestor(instance)
    local current = instance
    while current and current ~= playerGui do
        if current:IsA("GuiButton") then
            return current
        end
        local name = tostring(current.Name or "")
        if name:match("^Button%d+$") or name:find("Button", 1, true) then
            return current
        end
        current = current.Parent
    end
    return nil
end

function htmlDecode(text)
    text = tostring(text or "")
    text = text:gsub("&lt;", "<")
    text = text:gsub("&gt;", ">")
    text = text:gsub("&amp;", "&")
    return text
end

function stripRichText(text)
    text = htmlDecode(text)
    text = text:gsub("<.->", "")
    return compactText(text)
end

function normalizeBullet(text)
    local cleaned = stripRichText(text)
    cleaned = cleaned:gsub("^â€¢%s*", "")
    cleaned = cleaned:gsub("^•%s*", "")
    cleaned = cleaned:gsub("^·%s*", "")
    cleaned = cleaned:gsub("^%-+%s*", "")
    cleaned = cleaned:gsub("^%*+%s*", "")
    cleaned = cleaned:gsub("^%s+", "")
    return compactText(cleaned)
end

function findDescendantByPath(rootInstance, pathParts)
    if not rootInstance then
        return nil
    end

    local key = table.concat(pathParts, "\0")
    local rootCache = guiCache.paths[rootInstance]
    if rootCache and rootCache[key] ~= nil then
        return rootCache[key] or nil
    end

    local current = rootInstance
    for _, part in ipairs(pathParts) do
        if not current then
            break
        end
        current = current:FindFirstChild(part)
    end

    if not rootCache then
        rootCache = {}
        guiCache.paths[rootInstance] = rootCache
    end
    rootCache[key] = current or false
    return current
end

function readVisibleText(instance)
    if not instance or not isTextObject(instance) then
        return ""
    end
    if not isVisibleGuiObject(instance) then
        return ""
    end
    return stripRichText(instance.Text)
end

function getCurrentRbcRound()
    local uiSummary = getChallengeInfoRuntimeSummary()
    if uiSummary and uiSummary.running and uiSummary.round > 0 then
        state.lastSeenLiveRound = uiSummary.round
        return uiSummary.round
    end

    local roundLabel = findDescendantByPath(getRoboBearBoxRoot(), { "TitleBar", "Title" })
    if roundLabel then
        local roundText = readVisibleText(roundLabel)
        local roundNumber = roundText:match("Round%s*(%d+)")
        if roundNumber then
            return tonumber(roundNumber)
        end
    end

    local scanRoots = {
        getRoboBearPromptRoot(),
        getRoboBearMainFrame()
    }

    for _, rootInstance in ipairs(scanRoots) do
        if rootInstance then
            for _, descendant in ipairs(getCachedDescendants(rootInstance)) do
                if isTextObject(descendant) and isVisibleGuiObject(descendant) then
                    local text = stripRichText(descendant.Text)
                    local completed = text:match("Rounds%s+Completed:%s*(%d+)")
                    if completed then
                        return (tonumber(completed) or 0) + 1
                    end
                    local roundValue = text:match("ROUND:%s*(%d+)")
                    if roundValue then
                        return tonumber(roundValue)
                    end
                end
            end
        end
    end

    return tonumber(state.detected.round) or 0
end

function getCurrentRbcCogs()
    local cogsLabel = findDescendantByPath(getRoboBearMainFrame(), { "CogsTxt" })
    if cogsLabel then
        local cogsText = readVisibleText(cogsLabel)
        local cogsNumber = cogsText:match("Cogs:%s*(%d+)")
        if cogsNumber then
            state.lastSeenLiveCogs = tonumber(cogsNumber) or 0
            return state.lastSeenLiveCogs
        end
    end
    return tonumber(state.lastSeenLiveCogs)
end

function isQuestSelectPromptVisible()
    local promptLabel = findDescendantByPath(getRoboBearBoxRoot(), {
        "QuestSelectScreen",
        "Prompt Description"
    })

    if not promptLabel or not isTextObject(promptLabel) or not isVisibleGuiObject(promptLabel) then
        return false
    end

    local text = string.lower(stripRichText(promptLabel.Text))
    return text:find("choose a quest", 1, true) ~= nil
end

function findVisibleBeeChoices()
    local beeSelectRoot = getRoboBearBoxRoot()
    if not beeSelectRoot then
        return {}
    end

    local chooseBeeFound = false
    for _, descendant in ipairs(getCachedDescendants(beeSelectRoot)) do
        if isTextObject(descendant) and isVisibleGuiObject(descendant) then
            local text = string.lower(stripRichText(descendant.Text))
            if text:find("choose a bee", 1, true) then
                chooseBeeFound = true
                break
            end
        end
    end

    if not chooseBeeFound then
        return {}
    end

    local roboPrompt = getRoboBearPromptRoot()
    if not roboPrompt then
        return {}
    end

    local choices = {}
    local function extractBeeName(text)
        local cleaned = stripRichText(text)
        cleaned = cleaned:gsub("^%s*[★%*]+%s*", "")
        cleaned = compactText(cleaned)

        for _, beeName in ipairs(BEE_NAMES) do
            if cleaned:find(beeName, 1, true) then
                return beeName
            end
        end
        return nil
    end

    local function findBeeChoiceContainer(instance)
        local current = instance
        while current and current ~= playerGui do
            if current:IsA("GuiButton") then
                return current
            end

            if current:IsA("GuiObject") and isVisibleGuiObject(current) then
                local size = safeCall(function()
                    return current.AbsoluteSize
                end, nil)
                if size and size.X >= 240 and size.Y >= 40 then
                    return current
                end
            end

            current = current.Parent
        end
        return nil
    end

    for _, descendant in ipairs(getCachedDescendants(roboPrompt)) do
        if isTextObject(descendant) and isVisibleGuiObject(descendant) then
            local beeName = extractBeeName(descendant.Text)
            if beeName and state.beeConfig[beeName] then
                local button = findBeeChoiceContainer(descendant)
                if button then
                    local y = safeCall(function()
                        return button.AbsolutePosition.Y
                    end, math.huge)
                    local duplicate = false
                    for _, existing in ipairs(choices) do
                        if existing.button == button then
                            duplicate = true
                            break
                        end
                    end
                    if not duplicate then
                        table.insert(choices, {
                            beeName = beeName,
                            button = button,
                            y = y
                        })
                    end
                end
            end
        end
    end

    table.sort(choices, function(a, b)
        return a.y < b.y
    end)

    for index, choice in ipairs(choices) do
        choice.slot = index
    end

    return choices
end

function findVisibleUpgradeChoices()
    local boxRoot = getRoboBearBoxRoot()
    if not boxRoot then
        return {}
    end

    local chooseUpgradeFound = false
    for _, descendant in ipairs(getCachedDescendants(boxRoot)) do
        if isTextObject(descendant) and isVisibleGuiObject(descendant) then
            local text = string.lower(stripRichText(descendant.Text))
            if text:find("choose an upgrade", 1, true)
                or text:find("choose a upgrade", 1, true)
                or text:find("purchase upgrades", 1, true) then
                chooseUpgradeFound = true
                break
            end
        end
    end

    if not chooseUpgradeFound then
        return {}
    end

    local choices = {}
    local function extractUpgradeName(text)
        local cleaned = compactText(stripRichText(text))
        for _, upgradeName in ipairs(UPGRADE_NAMES) do
            if cleaned:find(upgradeName, 1, true) then
                return upgradeName
            end
        end
        return nil
    end

    local function extractUpgradeCostNear(rowY)
        if not rowY then
            return 0
        end
        for _, item in ipairs(getCachedDescendants(boxRoot)) do
            if isTextObject(item) and isVisibleGuiObject(item) then
                local pos = safeCall(function()
                    return item.AbsolutePosition
                end, nil)
                if pos and math.abs(pos.Y - rowY) <= 24 then
                    local text = stripRichText(item.Text)
                    local cost = text:match("Cost:%s*(%d+)")
                    if cost then
                        return tonumber(cost) or 0
                    end
                end
            end
        end
        return 0
    end

    local function inferUpgradeSlot(rowY)
        if not rowY then
            return nil
        end

        local promptY
        for _, item in ipairs(getCachedDescendants(boxRoot)) do
            if isTextObject(item) and isVisibleGuiObject(item) then
                local text = string.lower(stripRichText(item.Text))
                if text:find("purchase upgrades", 1, true)
                    or text:find("choose an upgrade", 1, true)
                    or text:find("choose a upgrade", 1, true) then
                    local pos = safeCall(function()
                        return item.AbsolutePosition
                    end, nil)
                    if pos then
                        promptY = pos.Y
                        break
                    end
                end
            end
        end

        if not promptY then
            return nil
        end

        local relativeY = rowY - promptY
        local slot = math.floor((relativeY - 25) / 84) + 1
        if slot < 1 then
            slot = 1
        elseif slot > 4 then
            slot = 4
        end
        return slot
    end

    local seenRows = {}
    for _, descendant in ipairs(getCachedDescendants(boxRoot)) do
        if isTextObject(descendant) and isVisibleGuiObject(descendant) then
            local upgradeName = extractUpgradeName(descendant.Text)
            if upgradeName and UPGRADE_BY_NAME[upgradeName] then
                local pos = safeCall(function()
                    return descendant.AbsolutePosition
                end, nil)
                local size = safeCall(function()
                    return descendant.AbsoluteSize
                end, nil)
                if pos and size then
                    local rowKey = tostring(math.floor((pos.Y + 10) / 12)) .. "::" .. upgradeName
                    if not seenRows[rowKey] then
                        seenRows[rowKey] = true
                        table.insert(choices, {
                            upgradeName = upgradeName,
                            cost = extractUpgradeCostNear(pos.Y),
                            y = pos.Y,
                            x = pos.X
                        })
                    end
                end
            end
        end
    end

    table.sort(choices, function(a, b)
        if math.abs(a.y - b.y) <= 3 then
            return a.x < b.x
        end
        return a.y < b.y
    end)

    local compactChoices = {}
    for _, choice in ipairs(choices) do
        local duplicate = false
        for _, existing in ipairs(compactChoices) do
            if existing.upgradeName == choice.upgradeName and math.abs(existing.y - choice.y) <= 8 then
                duplicate = true
                break
            end
        end
        if not duplicate then
            table.insert(compactChoices, choice)
        end
    end

    for index, choice in ipairs(compactChoices) do
        choice.slot = inferUpgradeSlot(choice.y) or index
    end
    return compactChoices
end

function chooseBeeName(visibleChoices, currentRound)
    local bestChoice = nil
    local bestPriority = -math.huge
    local bestMinRound = -math.huge

    for _, choice in ipairs(visibleChoices) do
        local beeName = choice.beeName
        local config = state.beeConfig[beeName]
        if config then
            if config and config.priority > 0 and currentRound >= config.minRound then
                if config.priority > bestPriority
                    or (config.priority == bestPriority and config.minRound > bestMinRound) then
                    bestChoice = choice
                    bestPriority = config.priority
                    bestMinRound = config.minRound
                end
            end
        end
    end

    if not bestChoice then
        if #visibleChoices > 0 then
            return visibleChoices[math.random(1, #visibleChoices)]
        end
    end

    return bestChoice
end

function getBeeBlockedReason(visibleChoices, currentRound)
    if type(visibleChoices) ~= "table" or #visibleChoices == 0 then
        return nil
    end

    local blocked = {}
    for _, choice in ipairs(visibleChoices) do
        local config = state.beeConfig[choice.beeName]
        if config and config.priority > 0 and currentRound < config.minRound then
            table.insert(blocked, choice.beeName .. " min " .. tostring(config.minRound))
        else
            return nil
        end
    end

    if #blocked == 0 then
        return nil
    end
    return table.concat(blocked, " | ")
end

function getRbcUpgradeGuideRank(upgradeName, currentRound)
    local guide = RBC_UPGRADE_GUIDE[upgradeName]
    if not guide then
        return -math.huge
    end
    currentRound = tonumber(currentRound) or 0
    if guide.minRound and currentRound < guide.minRound then
        return -math.huge
    end
    if guide.maxRound and currentRound > guide.maxRound then
        return -math.huge
    end
    local rank = guide.rank
    local profile = state.selectedQuestProfile
    if type(profile) == "table" then
        if upgradeName == "Overfit: Blue" and not profile.blue then
            return -math.huge
        elseif upgradeName == "Overfit: Red" and not profile.red then
            return -math.huge
        elseif upgradeName == "Overfit: White" and not profile.white then
            return -math.huge
        elseif upgradeName == "Fluid Simulation" and (profile.goo or profile.white) then
            rank += 18
        elseif upgradeName == "Homepage" and profile.starterField then
            rank += 12
        elseif upgradeName == "Router" and profile.routerField then
            rank += 12
        elseif upgradeName == "Base-15" and profile.base15Field then
            rank += 12
        elseif upgradeName == "Codec" then
            local active = getActiveUpgradeCounts()
            if (active["Sharpen"] or 0) < 4 and not active["Bruteforce"] then
                return -math.huge
            end
        end
    end
    return rank
end

function buildSelectedQuestProfile(quest)
    local textParts = { quest and quest.objective or "", quest and quest.raw or "" }
    for _, taskText in ipairs((quest and quest.tasks) or EMPTY_TABLE) do
        table.insert(textParts, taskText)
    end
    local text = normalizeFieldText(table.concat(textParts, " "))
    local profile = {
        red = text:find("red pollen", 1, true) ~= nil,
        blue = text:find("blue pollen", 1, true) ~= nil,
        white = text:find("white pollen", 1, true) ~= nil,
        goo = text:find("goo", 1, true) ~= nil,
        convert = text:find("convert", 1, true) ~= nil,
        starterField = false,
        routerField = false,
        base15Field = false
    }
    for _, fieldName in ipairs(findFarmFieldsInText(text)) do
        if fieldName == "Sunflower Field" or fieldName == "Dandelion Field"
            or fieldName == "Mushroom Field" or fieldName == "Blue Flower Field" then
            profile.starterField = true
        elseif fieldName == "Strawberry Field" or fieldName == "Spider Field"
            or fieldName == "Bamboo Field" or fieldName == "Pineapple Patch" then
            profile.routerField = true
        elseif fieldName == "Cactus Field" or fieldName == "Pumpkin Patch"
            or fieldName == "Pine Tree Forest" or fieldName == "Rose Field" then
            profile.base15Field = true
        end
    end
    if profile.red or profile.blue or profile.white or profile.goo then
        profile.starterField = true
    end
    return profile
end

function chooseUpgradeChoice(visibleChoices, activeCounts, currentCogs, currentRound, requireAffordable)
    local bestChoice
    local bestRank = -math.huge
    local bestRemaining = -math.huge

    for _, choice in ipairs(visibleChoices) do
        local upgradeName = choice.upgradeName
        local config = state.upgradeConfig[upgradeName]
        local meta = UPGRADE_BY_NAME[upgradeName]
        local taken = activeCounts[upgradeName] or 0
        if config and meta and config.enabled and currentRound >= (config.minRound or 1) and config.targetCount > taken then
            local affordable = (choice.cost or 0) <= (currentCogs or 0)
            if requireAffordable and not affordable then
                continue
            end
            local rank = getRbcUpgradeGuideRank(upgradeName, currentRound)
            if rank == -math.huge then
                continue
            end
            local remaining = config.targetCount - taken
            if (rank > bestRank)
                or (rank == bestRank and remaining > bestRemaining)
                or (rank == bestRank and remaining == bestRemaining and choice.slot < (bestChoice and bestChoice.slot or math.huge)) then
                bestChoice = choice
                bestRank = rank
                bestRemaining = remaining
            end
        end
    end

    return bestChoice
end

function chooseLockableUpgradeChoice(visibleChoices, activeCounts, currentCogs, currentRound)
    local bestChoice
    local bestRank = -math.huge
    local bestRemaining = -math.huge

    for _, choice in ipairs(visibleChoices) do
        local upgradeName = choice.upgradeName
        local config = state.upgradeConfig[upgradeName]
        local meta = UPGRADE_BY_NAME[upgradeName]
        local taken = activeCounts[upgradeName] or 0
        local cost = choice.cost or 0
        if config and meta and config.enabled and currentRound >= (config.minRound or 1) and config.lock and config.targetCount > taken and cost > (currentCogs or 0) then
            local rank = getRbcUpgradeGuideRank(upgradeName, currentRound)
            if rank == -math.huge then
                continue
            end
            local remaining = config.targetCount - taken
            if (rank > bestRank)
                or (rank == bestRank and remaining > bestRemaining)
                or (rank == bestRank and remaining == bestRemaining and choice.slot < (bestChoice and bestChoice.slot or math.huge)) then
                bestChoice = choice
                bestRank = rank
                bestRemaining = remaining
            end
        end
    end

    return bestChoice
end

function buildUpgradeLockSignature(choice, activeCounts, currentCogs, currentRound)
    if not choice then
        return ""
    end

    return table.concat({
        tostring(currentRound),
        tostring(choice.upgradeName),
        tostring(choice.slot),
        tostring(choice.cost or "?"),
        tostring(currentCogs),
        tostring(activeCounts[choice.upgradeName] or 0),
        "lock"
    }, "::")
end

function buildUpgradeBuySignature(choice, activeCounts, currentCogs, currentRound, visibleChoices)
    if not choice then
        return ""
    end

    return table.concat({
        tostring(currentRound),
        tostring(choice.upgradeName),
        tostring(choice.slot),
        tostring(choice.cost or "?"),
        tostring(currentCogs),
        tostring(activeCounts[choice.upgradeName] or 0),
        formatUpgradeChoicesForHistory(visibleChoices)
    }, "::")
end

function getPendingUpgradeAutomationAction(visibleChoices, activeCounts, currentCogs, currentRound)
    if type(visibleChoices) ~= "table" or #visibleChoices == 0 then
        return nil
    end

    if not state.autoUpgradePick then
        return nil
    end

    if state.autoUpgradeRoll then
        local buyChoice = chooseUpgradeChoice(visibleChoices, activeCounts, currentCogs, currentRound, true)
        if buyChoice then
            return "buy", buyChoice
        end
        return nil
    end

    local lockableChoice = chooseLockableUpgradeChoice(visibleChoices, activeCounts, currentCogs, currentRound)
    if lockableChoice then
        local lockSignature = buildUpgradeLockSignature(lockableChoice, activeCounts, currentCogs, currentRound)
        if lockSignature ~= state.lastUpgradeLockSignature then
            return "lock", lockableChoice
        end
    end

    local buyChoice = chooseUpgradeChoice(visibleChoices, activeCounts, currentCogs, currentRound, true)
    if buyChoice then
        local buySignature = buildUpgradeBuySignature(buyChoice, activeCounts, currentCogs, currentRound, visibleChoices)
        if buySignature ~= state.lastUpgradePickSignature then
            return "buy", buyChoice
        end
    end

    return nil
end

function tryAutoRollUpgradePicker(visibleChoices, activeCounts, currentCogs, currentRound)
    if not state.autoRoboBearInteract or not state.autoUpgradePick or not state.autoUpgradeRoll then
        return false, "auto_roll_off"
    end

    currentCogs = tonumber(currentCogs) or 0
    currentRound = tonumber(currentRound) or 0

    if type(visibleChoices) ~= "table" or #visibleChoices == 0 then
        return false, "no_upgrade_choices"
    end
    if state.lastUpgradeBoughtRound ~= currentRound then
        return false, "wait_for_upgrade_purchase"
    end
    if state.lastUpgradeRerollRound == currentRound then
        return false, "round_reroll_limit"
    end

    local now = os.clock()
    if (now - state.lastUpgradeChoicesSeenAt) < state.actionDelay then
        return false, "waiting_for_upgrade_picker"
    end

    local affordableChoice = chooseUpgradeChoice(visibleChoices, activeCounts, currentCogs, currentRound, true)
    if affordableChoice then
        return false, "affordable_upgrade_available"
    end

    local whitelistedChoice = chooseUpgradeChoice(visibleChoices, activeCounts, currentCogs, currentRound, false)
    local rerollSignature = table.concat({
        tostring(currentRound),
        tostring(currentCogs),
        formatUpgradeChoicesForHistory(visibleChoices)
    }, "::")

    if currentCogs >= AUTO_ROLL_MIN_COGS then
        if (now - state.lastUpgradeRerollAt) >= 0.9 and state.lastUpgradeRerollSignature ~= rerollSignature and fireRoboBearReroll() then
            if rerollSignature ~= state.lastUpgradeRerollHistorySignature then
                pushHistory(state.upgradePickHistory, table.concat({
                    "[" .. os.date("%X") .. "] Round " .. tostring(currentRound),
                    "Action: Reroll",
                    "Choices: " .. formatUpgradeChoicesForHistory(visibleChoices),
                    "Cogs: " .. tostring(currentCogs),
                    whitelistedChoice and "Whitelisted upgrade found but rerolling for more value" or "No whitelisted upgrade found"
                }, "\n"))
                state.lastUpgradeRerollHistorySignature = rerollSignature
            end
            state.lastUpgradeRerollSignature = rerollSignature
            state.lastUpgradeRerollAt = now
            state.lastUpgradeRerollRound = currentRound
            state.detected.status = "Auto-rolled upgrades"
            return true, "reroll"
        end

        return false, "reroll_cooldown"
    end

    if whitelistedChoice then
        local lockableChoice = chooseLockableUpgradeChoice(visibleChoices, activeCounts, currentCogs, currentRound)
        if lockableChoice then
            local lockSignature = buildUpgradeLockSignature(lockableChoice, activeCounts, currentCogs, currentRound)
            if lockSignature ~= state.lastUpgradeLockSignature
                and (now - state.lastUpgradeLockAttemptAt) >= 0.75
                and fireRoboBearUpgradeLock(lockableChoice.slot, true) then
                if lockSignature ~= state.lastUpgradeLockHistorySignature then
                    pushHistory(state.upgradePickHistory, table.concat({
                        "[" .. os.date("%X") .. "] Round " .. tostring(currentRound),
                        "Action: Lock",
                        "Choices: " .. formatUpgradeChoicesForHistory(visibleChoices),
                        "Cogs: " .. tostring(currentCogs) .. " | Cost: " .. tostring(lockableChoice.cost or "?"),
                        "Sent lock: " .. lockableChoice.upgradeName .. " (slot " .. tostring(lockableChoice.slot) .. ")"
                    }, "\n"))
                    state.lastUpgradeLockHistorySignature = lockSignature
                end
                state.lastUpgradeLockSignature = lockSignature
                state.lastUpgradeLockAttemptAt = now
                state.detected.status = "Auto Roll locked " .. lockableChoice.upgradeName
                return true, "lock"
            end

            return false, "lock_cooldown"
        end
    end

    return tryRoboBearRoundStartAfterUpgrades(visibleChoices, activeCounts, currentCogs, currentRound)
end

function tryRoboBearRoundStartAfterUpgrades(visibleChoices, activeCounts, currentCogs, currentRound)
    if not state.autoRoboBearInteract then
        return false, "robo_e_off"
    end

    currentCogs = tonumber(currentCogs) or 0
    currentRound = tonumber(currentRound) or 0

    if type(visibleChoices) ~= "table" or #visibleChoices == 0 then
        return false, "no_upgrade_choices"
    end

    local now = os.clock()
    if (now - state.lastUpgradeChoicesSeenAt) < (state.actionDelay + 0.6) then
        return false, "waiting_for_upgrade_picker"
    end

    local lastUpgradeActionAt = math.max(state.lastUpgradePickAttemptAt or 0, state.lastUpgradeLockAttemptAt or 0)
    if lastUpgradeActionAt > 0 and (now - lastUpgradeActionAt) < 1.35 then
        return false, "waiting_for_upgrade_action"
    end

    local pendingAction = getPendingUpgradeAutomationAction(visibleChoices, activeCounts, currentCogs, currentRound)
    if pendingAction then
        return false, "pending_upgrade_" .. tostring(pendingAction)
    end

    local startSignature = table.concat({
        tostring(currentRound),
        tostring(currentCogs),
        formatUpgradeChoicesForHistory(visibleChoices)
    }, "::")

    if startSignature == state.lastRoboBearRoundStartSignature and (now - state.lastRoboBearRoundStartAt) < 4 then
        return false, "recent_round_start"
    end

    if fireRoboBearRoundStart() then
        state.lastRoboBearRoundStartAt = now
        state.lastRoboBearRoundStartSignature = startSignature
        pushHistory(state.upgradePickHistory, table.concat({
            "[" .. os.date("%X") .. "] Round " .. tostring(currentRound),
            "Action: Start round",
            "Sent RoboBearRoundStart after upgrade picker settled",
            "Choices: " .. formatUpgradeChoicesForHistory(visibleChoices),
            "Cogs: " .. tostring(currentCogs)
        }, "\n"))
        state.detected.status = "Sent RoboBearRoundStart after upgrades"
        return true, "round_start"
    end

    return false, "round_start_remote_failed"
end

function tryRoboBearRoundStartFromCurrentUpgradePrompt()
    local visibleChoices = findVisibleUpgradeChoices()
    if #visibleChoices == 0 then
        return false, "no_upgrade_choices"
    end

    local activeCounts = getActiveUpgradeCounts()
    local currentCogs = getCurrentRbcCogs()
    local currentRound = getCurrentRbcRound()
    if state.autoUpgradeRoll then
        return tryAutoRollUpgradePicker(
            visibleChoices,
            activeCounts,
            currentCogs,
            currentRound
        )
    end

    return tryRoboBearRoundStartAfterUpgrades(
        visibleChoices,
        activeCounts,
        currentCogs,
        currentRound
    )
end

function getRoboBearPromptButtonText(object)
    local texts = {}
    if object:IsA("TextButton") then
        table.insert(texts, tostring(object.Text or ""))
    end
    for _, descendant in ipairs(object:GetDescendants()) do
        if isTextObject(descendant) and isVisibleGuiObject(descendant) then
            table.insert(texts, tostring(descendant.Text or ""))
        end
    end
    return string.lower(compactText(stripRichText(table.concat(texts, " "))))
end

function clickVisibleRoboBearClaimRewardsButton()
    if not playerGui then
        return false
    end
    local box = getRoboBearBoxRoot()
    local object = box and box:FindFirstChild("StartRoundButton")
    if object and object:IsA("GuiButton")
        and isVisibleGuiObject(object)
        and getRoboBearPromptButtonText(object):find("claim rewards", 1, true) then
        invokeGuiButtonClick(object)
        local fired = fireRemote("RoboBearClaimRewards")
        if fired then
            return true
        end
        local position, size = getGuiBounds(object)
        if position and size then
            return safeCall(function()
                local x = math.floor(position.X + size.X / 2)
                local y = math.floor(position.Y + size.Y / 2)
                VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 0)
                VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 0)
                return true
            end, false)
        end
    end
    return false
end

function clickVisibleRoboBearStartRoundButton()
    if not playerGui or not isRoboBearChallengePromptOpen() then
        return false, "prompt_closed"
    end

    local box = getRoboBearBoxRoot()
    local object = box and box:FindFirstChild("StartRoundButton")
    if object and object:IsA("GuiButton")
        and isVisibleGuiObject(object)
        and getRoboBearPromptButtonText(object):find("start round", 1, true) then
        local clicked = invokeGuiButtonClick(object)
        if not clicked then
            clicked = safeCall(function()
                local position, size = getGuiBounds(object)
                if not position or not size then
                    return false
                end
                local x = math.floor(position.X + size.X / 2)
                local y = math.floor(position.Y + size.Y / 2)
                VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 0)
                VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 0)
                return true
            end, false)
        end
        if clicked then
            beginChallengeInfoWait()
            return true, "visible_start_button"
        end
    end

    if fireRoboBearRoundStart() then
        return true, "round_start_remote"
    end
    return false, "start_unavailable"
end

function buildQuestFromButton(button, title)
    if not button then
        return nil
    end

    local objectives = {}
    local reward = ""

    for index = 1, 8 do
        local label = button:FindFirstChild("TaskLbl" .. tostring(index))
        if label and isTextObject(label) and isVisibleGuiObject(label) then
            local text = normalizeBullet(label.Text)
            if text ~= "" then
                table.insert(objectives, text)
            end
        end
    end

    local rewardLabel = button:FindFirstChild("RewardLbl")
    if rewardLabel and isTextObject(rewardLabel) and isVisibleGuiObject(rewardLabel) then
        reward = stripRichText(rewardLabel.Text)
    end

    objectives = dedupeList(objectives)
    if #objectives == 0 then
        return nil
    end

    local rawParts = {}
    for _, value in ipairs(objectives) do
        table.insert(rawParts, value)
    end
    if reward ~= "" then
        table.insert(rawParts, reward)
    end

    return {
        title = title,
        tasks = objectives,
        objective = table.concat(objectives, " | "),
        reward = reward,
        path = getFullPath(button),
        raw = table.concat(rawParts, " || "),
        button = button
    }
end

function scanDirectRbcQuestUi(playerGui)
    if not isQuestSelectPromptVisible() then
        return nil
    end

    local prompt = findDescendantByPath(getRoboBearBoxRoot(), { "QuestSelectScreen", "ButtonFrame" })
    if not prompt then
        return nil
    end

    local button1 = prompt:FindFirstChild("Button1")
    local button2 = prompt:FindFirstChild("Button2")
    local questA = buildQuestFromButton(button1, "Quest A")
    local questB = buildQuestFromButton(button2, "Quest B")

    local quests = {}
    if questA then
        table.insert(quests, questA)
    end
    if questB then
        table.insert(quests, questB)
    end

    local roundText = ""
    local roundLabel = findDescendantByPath(getRoboBearBoxRoot(), { "TitleBar", "Title" })
    if roundLabel then
        roundText = readVisibleText(roundLabel)
    end

    local cogsText = ""
    local cogsLabel = findDescendantByPath(getRoboBearMainFrame(), { "CogsTxt" })
    if cogsLabel then
        cogsText = readVisibleText(cogsLabel)
    end

    return {
        quests = quests,
        promptFound = true,
        guiPath = getFullPath(prompt),
        roundText = roundText,
        cogsText = cogsText
    }
end

function findRbcPromptTexts()
    if not playerGui then
        return {}
    end

    local items = {}
    for _, descendant in ipairs(getCachedDescendants(playerGui)) do
        if isTextObject(descendant) and isVisibleGuiObject(descendant) and not descendant:IsDescendantOf(root) then
            local text = compactText(descendant.Text)
            if text ~= "" then
                local lowered = string.lower(text)
                local context = string.lower(getAncestorContext(descendant))
                local normalized = lowered:gsub("[%s%p_]+", "")
                local relevant = normalized:find("robo", 1, true)
                    or normalized:find("challenge", 1, true)
                    or normalized:find("questa", 1, true)
                    or normalized:find("questb", 1, true)
                    or normalized:find("chooseaquest", 1, true)
                    or lowered:find("reward", 1, true)
                    or context:find("robo", 1, true)
                    or context:find("challenge", 1, true)
                    or context:find("quest", 1, true)

                if relevant then
                    local pos = safeCall(function()
                        return descendant.AbsolutePosition
                    end, Vector2.new())
                    local size = safeCall(function()
                        return descendant.AbsoluteSize
                    end, Vector2.new())

                    table.insert(items, {
                        text = text,
                        full_name = getFullPath(descendant),
                        parent = descendant.Parent and descendant.Parent.Name or "nil",
                        x = pos.X,
                        y = pos.Y,
                        width = size.X,
                        height = size.Y
                    })
                end
            end
        end
    end

    table.sort(items, function(a, b)
        if a.y == b.y then
            return a.x < b.x
        end
        return a.y < b.y
    end)

    return items
end

function getGoldenCogmowerStatus()
    local feMonsters = Workspace:FindFirstChild("FEMonsters")
    if not feMonsters then
        return "Dead/NoSpawn"
    end

    for _, child in ipairs(feMonsters:GetChildren()) do
        local name = tostring(child.Name or "")
        if name:find("Golden Cogmower", 1, true) then
            return "Spawned"
        end
    end

    return "Dead/NoSpawn"
end

function scanGuiForQuestData()
    if not playerGui then
        return nil
    end

    local direct = scanDirectRbcQuestUi(playerGui)
    if direct and #direct.quests > 0 then
        return {
            best = nil,
            quests = direct.quests,
            promptFound = true,
            cardCount = #direct.quests,
            guiPath = direct.guiPath,
            roundText = direct.roundText,
            cogsText = direct.cogsText,
            direct = true
        }
    end

    if not isQuestSelectPromptVisible() then
        return {
            best = nil,
            quests = {},
            promptFound = false,
            cardCount = 0,
            guiPath = "Quest chooser not visible",
            direct = false
        }
    end

    local questGroups = {}
    local best = nil
    local bestScore = -math.huge

    local cards, searchRoot = gatherQuestCards(playerGui)
    for _, card in ipairs(cards) do
        questGroups[card.path] = {
            titleObject = card.titleObject,
            path = card.path,
            title = card.title,
            objectives = {},
            rewards = {},
            raw = {}
        }
    end

    local descendants = searchRoot and getCachedDescendants(searchRoot) or EMPTY_TABLE
    for _, descendant in ipairs(descendants) do
        if isTextObject(descendant) and isVisibleGuiObject(descendant) then
            local text = compactText(descendant.Text)
            if text ~= "" then
                if descendant:IsDescendantOf(root) then
                    continue
                end

                local context = getAncestorContext(descendant)
                local looksRelevant = containsPattern(context, RBC_CONTEXT_PATTERNS) or containsPattern(text, RBC_CONTEXT_PATTERNS)
                local looksLikeQuest = containsPattern(text, QUEST_TEXT_PATTERNS)

                if looksRelevant or looksLikeQuest then
                    local score = scoreCandidate(text, context)
                    if score > bestScore then
                        bestScore = score
                        best = {
                            text = text,
                            path = getFullPath(descendant),
                            context = context
                        }
                    end
                end

                for _, card in ipairs(cards) do
                    if descendant ~= card.titleObject and isInsideQuestColumn(descendant, card) then
                        local group = questGroups[card.path]
                        table.insert(group.raw, text)

                        if textLooksLikeReward(text) then
                            table.insert(group.rewards, text)
                        elseif looksLikeQuest and not textLooksLikeQuestTitle(text) then
                            table.insert(group.objectives, text)
                        end
                        break
                    end
                end
            end
        end
    end

    local quests = {}
    for _, group in pairs(questGroups) do
        if #group.objectives > 0 then
            local uniqueObjectives = dedupeList(group.objectives)
            local uniqueRewards = dedupeList(group.rewards)

            local rewardText = ""
            if #uniqueRewards > 0 then
                rewardText = uniqueRewards[1]
            end

                table.insert(quests, {
                    title = group.title ~= "" and group.title or ("Quest " .. tostring(#quests + 1)),
                    tasks = uniqueObjectives,
                    objective = table.concat(uniqueObjectives, " | "),
                    reward = rewardText,
                    path = group.path,
                    raw = table.concat(group.raw, " || "),
                    titleObject = group.titleObject
            })
        end
    end

    table.sort(quests, sortByX)

    if #quests == 0 and #cards > 0 then
        for _, card in ipairs(cards) do
            local fallbackObjectives = {}
            local fallbackRewards = {}
            for _, descendant in ipairs(getCachedDescendants(playerGui)) do
                if isTextObject(descendant) and isVisibleGuiObject(descendant) and descendant ~= card.titleObject then
                    local text = compactText(descendant.Text)
                    if text ~= "" and isInsideQuestColumn(descendant, card) then
                        if textLooksLikeReward(text) then
                            table.insert(fallbackRewards, text)
                        elseif containsPattern(text, QUEST_TEXT_PATTERNS) then
                            table.insert(fallbackObjectives, text)
                        end
                    end
                end
            end

            fallbackObjectives = dedupeList(fallbackObjectives)
            fallbackRewards = dedupeList(fallbackRewards)

            if #fallbackObjectives > 0 then
                table.insert(quests, {
                    title = card.title,
                    tasks = fallbackObjectives,
                    objective = table.concat(fallbackObjectives, " | "),
                    reward = fallbackRewards[1] or "",
                    path = card.path,
                    raw = table.concat(fallbackObjectives, " || "),
                    titleObject = card.titleObject
                })
            end
        end

        table.sort(quests, sortByX)
    end

    return {
        best = best,
        quests = quests,
        promptFound = searchRoot ~= nil,
        cardCount = #cards,
        guiPath = searchRoot and getFullPath(searchRoot) or "N/A",
        direct = false
    }
end

function extractQuestName(text)
    local cleaned = compactText(text)
    local firstPart = cleaned:match("^([^:]+):")
    if firstPart and #firstPart >= 4 then
        return firstPart
    end
    return cleaned
end

function extractObjective(text)
    local cleaned = compactText(text)
    local afterColon = cleaned:match(":%s*(.+)$")
    if afterColon and #afterColon >= 4 then
        return afterColon
    end
    return cleaned
end

local existing = playerGui:FindFirstChild("RBCDetectorNative")
if existing then
    existing:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "RBCDetectorNative"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 999999
screenGui.IgnoreGuiInset = false
screenGui.Parent = playerGui
runtime.screenGui = screenGui

root = Instance.new("Frame")
root.Size = UDim2.new(0, 980, 0, 460)
root.Position = UDim2.new(1, -430, 0, 115)
root.BackgroundColor3 = Color3.fromRGB(23, 18, 23)
root.BorderSizePixel = 0
root.ZIndex = 100
root.Parent = screenGui

local rootCorner = Instance.new("UICorner")
rootCorner.CornerRadius = UDim.new(0, 8)
rootCorner.Parent = root

local rootStroke = Instance.new("UIStroke")
rootStroke.Color = Color3.fromRGB(164, 53, 90)
rootStroke.Thickness = 1
rootStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
rootStroke.Parent = root

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.new(0, 12, 0, 8)
title.Size = UDim2.new(1, -24, 0, 24)
title.Font = Enum.Font.GothamBold
title.TextColor3 = Color3.fromRGB(255, 218, 233)
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextSize = 17
title.Text = "RBC Quest Detector v" .. SCRIPT_VERSION
title.ZIndex = 101
title.Parent = root

local sub = Instance.new("TextLabel")
sub.BackgroundTransparency = 1
sub.Position = UDim2.new(0, 12, 0, 32)
sub.Size = UDim2.new(1, -24, 0, 18)
sub.Font = Enum.Font.Gotham
sub.TextColor3 = Color3.fromRGB(210, 210, 210)
sub.TextXAlignment = Enum.TextXAlignment.Left
sub.TextSize = 12
sub.Text = "Built-in UI only. Overlap execute replaces the previous run. Press RightControl to show or hide."
sub.ZIndex = 101
sub.Parent = root

local topBarFrame = Instance.new("Frame")
topBarFrame.Name = "TopBarFrame"
topBarFrame.BackgroundTransparency = 1
topBarFrame.Position = UDim2.new(0, 0, 0, 0)
topBarFrame.Size = UDim2.new(1, 0, 0, 128)
topBarFrame.ZIndex = 100
topBarFrame.Parent = root

local controlTabBar = Instance.new("Frame")
controlTabBar.Name = "ControlTabBar"
controlTabBar.BackgroundTransparency = 1
controlTabBar.Position = UDim2.new(0, 12, 0, 56)
controlTabBar.Size = UDim2.new(1, -24, 0, 28)
controlTabBar.ZIndex = 100
controlTabBar.Parent = topBarFrame

local controlTabLayout = Instance.new("UIListLayout")
controlTabLayout.FillDirection = Enum.FillDirection.Horizontal
controlTabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
controlTabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
controlTabLayout.Padding = UDim.new(0, 8)
controlTabLayout.Parent = controlTabBar

local controlSectionFrame = Instance.new("Frame")
controlSectionFrame.Name = "ControlSectionFrame"
controlSectionFrame.BackgroundTransparency = 1
controlSectionFrame.Position = UDim2.new(0, 12, 0, 90)
controlSectionFrame.Size = UDim2.new(1, -24, 0, 34)
controlSectionFrame.ZIndex = 100
controlSectionFrame.Parent = topBarFrame

local contentFrame = Instance.new("Frame")
contentFrame.Name = "ContentFrame"
contentFrame.BackgroundTransparency = 1
contentFrame.Position = UDim2.new(0, 0, 0, 126)
contentFrame.Size = UDim2.new(1, 0, 1, -236)
contentFrame.ZIndex = 100
contentFrame.Parent = root

local bottomBarFrame = Instance.new("Frame")
bottomBarFrame.Name = "BottomBarFrame"
bottomBarFrame.BackgroundTransparency = 1
bottomBarFrame.AnchorPoint = Vector2.new(0, 1)
bottomBarFrame.Position = UDim2.new(0, 0, 1, -8)
bottomBarFrame.Size = UDim2.new(1, 0, 0, 72)
bottomBarFrame.ZIndex = 100
bottomBarFrame.Parent = root

local bottomBarLayout = Instance.new("UIListLayout")
bottomBarLayout.FillDirection = Enum.FillDirection.Horizontal
bottomBarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
bottomBarLayout.VerticalAlignment = Enum.VerticalAlignment.Center
bottomBarLayout.Padding = UDim.new(0, 8)
bottomBarLayout.Parent = bottomBarFrame

local bottomBarPadding = Instance.new("UIPadding")
bottomBarPadding.PaddingLeft = UDim.new(0, 12)
bottomBarPadding.PaddingRight = UDim.new(0, 12)
bottomBarPadding.Parent = bottomBarFrame

local dragBar = Instance.new("TextButton")
dragBar.Name = "DragBar"
dragBar.BackgroundTransparency = 1
dragBar.Position = UDim2.new(0, 0, 0, 0)
dragBar.Size = UDim2.new(1, 0, 0, 48)
dragBar.Text = ""
dragBar.AutoButtonColor = false
dragBar.ZIndex = 102
dragBar.Parent = root

function makeButton(name, text, x, y, width)
    local button = Instance.new("TextButton")
    button.Name = name
    button.Size = UDim2.new(0, width, 0, 28)
    button.BackgroundColor3 = Color3.fromRGB(43, 33, 43)
    button.BorderSizePixel = 0
    button.Font = Enum.Font.GothamSemibold
    button.TextColor3 = Color3.fromRGB(245, 245, 245)
    button.TextSize = 13
    button.Text = text
    button.ZIndex = 101
    button.Parent = root

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = button
    return button
end

function makeControlGroup(name)
    local frame = Instance.new("Frame")
    frame.Name = name
    frame.BackgroundTransparency = 1
    frame.Size = UDim2.new(1, 0, 0, 34)
    frame.Visible = false
    frame.Parent = controlSectionFrame

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    layout.VerticalAlignment = Enum.VerticalAlignment.Center
    layout.Padding = UDim.new(0, 8)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = frame

    return frame
end

local buttons = {}
buttons.refresh = makeButton("Refresh", "Refresh", 0, 0, 80)
buttons.auto = makeButton("Auto", "Auto: ON", 0, 0, 84)
buttons.interact = makeButton("RoboInteract", "Robo E: OFF", 0, 0, 108)
buttons.autoRbc = makeButton("AutoRbc", "Auto RBC: OFF", 0, 0, 118)
buttons.route = makeButton("Route", "Route: Blue", 0, 0, 110)
buttons.pick = makeButton("Pick", "AutoPick: OFF", 0, 0, 120)
buttons.beePick = makeButton("BeePick", "AutoBee: OFF", 0, 0, 110)
buttons.beePriority = makeButton("BeePriority", "Bee Priority", 0, 0, 110)
buttons.upgradePick = makeButton("UpgradePick", "AutoUpgrade: OFF", 0, 0, 130)
buttons.upgradeRoll = makeButton("UpgradeRoll", "AutoRoll: OFF", 0, 0, 118)
buttons.upgradeConfig = makeButton("UpgradeConfig", "Upgrade Config", 0, 0, 124)
buttons.tokenPriority = makeButton("TokenPriority", "Priority Token", 0, 0, 124)
buttons.moveWalk = makeButton("MoveWalk", "Walk", 0, 0, 70)
buttons.moveTween = makeButton("MoveTween", "Tween", 0, 0, 78)
buttons.autoLoad = makeButton("AutoLoad", "AutoLoad: ON", 0, 0, 112)
buttons.saveConfig = makeButton("SaveConfig", "Save", 0, 0, 70)
buttons.loadConfig = makeButton("LoadConfig", "Load", 0, 0, 70)
buttons.exportConfig = makeButton("ExportConfig", "Export", 0, 0, 76)
buttons.importConfig = makeButton("ImportConfig", "Import", 0, 0, 76)
buttons.dump = makeButton("Dump", "Dump UI", 0, 0, 84)
buttons.copy = makeButton("Copy", "Copy Debug", 0, 0, 104)

buttons.generalTab = makeButton("GeneralTab", "General", 0, 0, 84)
buttons.questPickerTab = makeButton("QuestPickerTab", "Quest Picker", 0, 0, 108)
buttons.beePickerTab = makeButton("BeePickerTab", "Bee Picker", 0, 0, 100)
buttons.upgradePickerTab = makeButton("UpgradePickerTab", "Upgrade Picker", 0, 0, 122)
buttons.moveMethodTab = makeButton("MoveMethodTab", "Move Method", 0, 0, 116)
buttons.farmingTab = makeButton("FarmingTab", "Farming", 0, 0, 88)
buttons.boostsTab = makeButton("BoostsTab", "Boosts", 0, 0, 80)
buttons.settingsTab = makeButton("SettingsTab", "Settings", 0, 0, 86)

buttons.generalTab.Parent = controlTabBar
buttons.questPickerTab.Parent = controlTabBar
buttons.beePickerTab.Parent = controlTabBar
buttons.upgradePickerTab.Parent = controlTabBar
buttons.moveMethodTab.Parent = controlTabBar
buttons.farmingTab.Parent = controlTabBar
buttons.boostsTab.Parent = controlTabBar
buttons.settingsTab.Parent = controlTabBar

local generalControls = makeControlGroup("GeneralControls")
local questPickerControls = makeControlGroup("QuestPickerControls")
local beePickerControls = makeControlGroup("BeePickerControls")
local upgradePickerControls = makeControlGroup("UpgradePickerControls")
local moveMethodControls = makeControlGroup("MoveMethodControls")
local farmingControls = makeControlGroup("FarmingControls")
local boostsControls = makeControlGroup("BoostsControls")
local settingsControls = makeControlGroup("SettingsControls")

buttons.smartBoosts = makeButton("SmartBoosts", "Boosts: ON", 0, 0, 108)
buttons.smartMaterials = makeButton("SmartMaterials", "Materials: ON", 0, 0, 122)
buttons.smartCombat = makeButton("SmartCombat", "Combat: ON", 0, 0, 112)

buttons.refresh.Parent = generalControls
buttons.auto.Parent = generalControls
buttons.interact.Parent = generalControls
buttons.autoRbc.Parent = generalControls
buttons.route.Parent = questPickerControls
buttons.pick.Parent = questPickerControls
buttons.beePick.Parent = beePickerControls
buttons.beePriority.Parent = beePickerControls
buttons.upgradePick.Parent = upgradePickerControls
buttons.upgradeRoll.Parent = upgradePickerControls
buttons.upgradeConfig.Parent = upgradePickerControls
buttons.tokenPriority.Parent = farmingControls
buttons.smartBoosts.Parent = boostsControls
buttons.smartMaterials.Parent = boostsControls
buttons.smartCombat.Parent = boostsControls
buttons.moveWalk.Parent = moveMethodControls
buttons.moveTween.Parent = moveMethodControls
buttons.moveWalk.LayoutOrder = 1
buttons.moveTween.LayoutOrder = 2
buttons.autoLoad.Parent = settingsControls
buttons.saveConfig.Parent = settingsControls
buttons.loadConfig.Parent = settingsControls
buttons.exportConfig.Parent = settingsControls
buttons.importConfig.Parent = settingsControls
buttons.dump.Parent = settingsControls
buttons.copy.Parent = settingsControls

local statusLabel = Instance.new("TextLabel")
statusLabel.BackgroundTransparency = 1
statusLabel.Position = UDim2.new(0, 12, 0, 0)
statusLabel.Size = UDim2.new(1, -24, 1, 0)
statusLabel.Font = Enum.Font.Code
statusLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
statusLabel.TextSize = 12
statusLabel.TextWrapped = true
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.TextYAlignment = Enum.TextYAlignment.Top
statusLabel.Text = "Waiting for first scan..."
statusLabel.ZIndex = 101
statusLabel.Parent = contentFrame

local debugBox = Instance.new("TextLabel")
debugBox.BackgroundColor3 = Color3.fromRGB(17, 13, 17)
debugBox.Position = UDim2.new(0, 12, 0, 0)
debugBox.Size = UDim2.new(1, -24, 1, 0)
debugBox.BorderSizePixel = 0
debugBox.Font = Enum.Font.Code
debugBox.TextColor3 = Color3.fromRGB(210, 210, 210)
debugBox.TextSize = 12
debugBox.TextWrapped = true
debugBox.TextXAlignment = Enum.TextXAlignment.Left
debugBox.TextYAlignment = Enum.TextYAlignment.Top
debugBox.Text = "No debug data yet."
debugBox.ZIndex = 101
debugBox.Parent = contentFrame

local debugCorner = Instance.new("UICorner")
debugCorner.CornerRadius = UDim.new(0, 6)
debugCorner.Parent = debugBox

beePanelFrame = Instance.new("Frame")
beePanelFrame.Name = "BeePriorityPanel"
beePanelFrame.Visible = false
beePanelFrame.Position = UDim2.new(1, 12, 0, 0)
beePanelFrame.Size = UDim2.new(0, 420, 1, 0)
beePanelFrame.BackgroundColor3 = Color3.fromRGB(24, 20, 24)
beePanelFrame.BorderSizePixel = 0
beePanelFrame.ZIndex = 100
beePanelFrame.Parent = contentFrame

local beePanelCorner = Instance.new("UICorner")
beePanelCorner.CornerRadius = UDim.new(0, 8)
beePanelCorner.Parent = beePanelFrame

local beePanelStroke = Instance.new("UIStroke")
beePanelStroke.Color = Color3.fromRGB(72, 52, 72)
beePanelStroke.Thickness = 1
beePanelStroke.Parent = beePanelFrame

local beePanelTitle = Instance.new("TextLabel")
beePanelTitle.BackgroundTransparency = 1
beePanelTitle.Position = UDim2.new(0, 12, 0, 10)
beePanelTitle.Size = UDim2.new(1, -24, 0, 22)
beePanelTitle.Font = Enum.Font.GothamBold
beePanelTitle.TextColor3 = Color3.fromRGB(245, 235, 245)
beePanelTitle.TextXAlignment = Enum.TextXAlignment.Left
beePanelTitle.TextSize = 15
beePanelTitle.Text = "Bee Priority"
beePanelTitle.ZIndex = 101
beePanelTitle.Parent = beePanelFrame

local beePanelHint = Instance.new("TextLabel")
beePanelHint.BackgroundTransparency = 1
beePanelHint.Position = UDim2.new(0, 12, 0, 32)
beePanelHint.Size = UDim2.new(1, -24, 0, 18)
beePanelHint.Font = Enum.Font.Gotham
beePanelHint.TextColor3 = Color3.fromRGB(210, 210, 210)
beePanelHint.TextXAlignment = Enum.TextXAlignment.Left
beePanelHint.TextSize = 11
beePanelHint.Text = "Priority 0-50. Minimum round 1-25."
beePanelHint.ZIndex = 101
beePanelHint.Parent = beePanelFrame

local beeScroll = Instance.new("ScrollingFrame")
beeScroll.Name = "BeeScroll"
beeScroll.Position = UDim2.new(0, 12, 0, 58)
beeScroll.Size = UDim2.new(1, -24, 1, -70)
beeScroll.BackgroundTransparency = 1
beeScroll.BorderSizePixel = 0
beeScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
beeScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
beeScroll.ScrollBarThickness = 6
beeScroll.ZIndex = 101
beeScroll.Parent = beePanelFrame

local beeScrollLayout = Instance.new("UIListLayout")
beeScrollLayout.Padding = UDim.new(0, 6)
beeScrollLayout.SortOrder = Enum.SortOrder.LayoutOrder
beeScrollLayout.Parent = beeScroll

upgradePanelFrame = Instance.new("Frame")
upgradePanelFrame.Name = "UpgradePriorityPanel"
upgradePanelFrame.Visible = false
upgradePanelFrame.Position = UDim2.new(1, 12, 0, 0)
upgradePanelFrame.Size = UDim2.new(0, 540, 1, 0)
upgradePanelFrame.BackgroundColor3 = Color3.fromRGB(24, 20, 24)
upgradePanelFrame.BorderSizePixel = 0
upgradePanelFrame.ZIndex = 100
upgradePanelFrame.Parent = contentFrame

local upgradePanelCorner = Instance.new("UICorner")
upgradePanelCorner.CornerRadius = UDim.new(0, 8)
upgradePanelCorner.Parent = upgradePanelFrame

local upgradePanelStroke = Instance.new("UIStroke")
upgradePanelStroke.Color = Color3.fromRGB(72, 52, 72)
upgradePanelStroke.Thickness = 1
upgradePanelStroke.Parent = upgradePanelFrame

local upgradePanelTitle = Instance.new("TextLabel")
upgradePanelTitle.BackgroundTransparency = 1
upgradePanelTitle.Position = UDim2.new(0, 12, 0, 10)
upgradePanelTitle.Size = UDim2.new(1, -24, 0, 22)
upgradePanelTitle.Font = Enum.Font.GothamBold
upgradePanelTitle.TextColor3 = Color3.fromRGB(245, 235, 245)
upgradePanelTitle.TextXAlignment = Enum.TextXAlignment.Left
upgradePanelTitle.TextSize = 15
upgradePanelTitle.Text = "Upgrade Picker"
upgradePanelTitle.ZIndex = 101
upgradePanelTitle.Parent = upgradePanelFrame

local upgradePanelHint = Instance.new("TextLabel")
upgradePanelHint.BackgroundTransparency = 1
upgradePanelHint.Position = UDim2.new(0, 12, 0, 32)
upgradePanelHint.Size = UDim2.new(1, -24, 0, 18)
upgradePanelHint.Font = Enum.Font.Gotham
upgradePanelHint.TextColor3 = Color3.fromRGB(210, 210, 210)
upgradePanelHint.TextXAlignment = Enum.TextXAlignment.Left
upgradePanelHint.TextSize = 11
upgradePanelHint.Text = "Enable upgrades, set target count, preview effect scaling."
upgradePanelHint.ZIndex = 101
upgradePanelHint.Parent = upgradePanelFrame

local upgradeScroll = Instance.new("ScrollingFrame")
upgradeScroll.Name = "UpgradeScroll"
upgradeScroll.Position = UDim2.new(0, 12, 0, 58)
upgradeScroll.Size = UDim2.new(1, -24, 1, -70)
upgradeScroll.BackgroundTransparency = 1
upgradeScroll.BorderSizePixel = 0
upgradeScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
upgradeScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
upgradeScroll.ScrollBarThickness = 6
upgradeScroll.ZIndex = 101
upgradeScroll.Parent = upgradePanelFrame

local upgradeScrollLayout = Instance.new("UIListLayout")
upgradeScrollLayout.Padding = UDim.new(0, 6)
upgradeScrollLayout.SortOrder = Enum.SortOrder.LayoutOrder
upgradeScrollLayout.Parent = upgradeScroll

tokenPanelFrame = Instance.new("Frame")
tokenPanelFrame.Name = "TokenPriorityPanel"
tokenPanelFrame.Visible = false
tokenPanelFrame.Position = UDim2.new(1, 12, 0, 0)
tokenPanelFrame.Size = UDim2.new(0, 420, 1, 0)
tokenPanelFrame.BackgroundColor3 = Color3.fromRGB(24, 20, 24)
tokenPanelFrame.BorderSizePixel = 0
tokenPanelFrame.ZIndex = 100
tokenPanelFrame.Parent = contentFrame

local tokenPanelCorner = Instance.new("UICorner")
tokenPanelCorner.CornerRadius = UDim.new(0, 8)
tokenPanelCorner.Parent = tokenPanelFrame

local tokenPanelStroke = Instance.new("UIStroke")
tokenPanelStroke.Color = Color3.fromRGB(72, 52, 72)
tokenPanelStroke.Thickness = 1
tokenPanelStroke.Parent = tokenPanelFrame

local tokenPanelTitle = Instance.new("TextLabel")
tokenPanelTitle.BackgroundTransparency = 1
tokenPanelTitle.Position = UDim2.new(0, 12, 0, 10)
tokenPanelTitle.Size = UDim2.new(1, -24, 0, 22)
tokenPanelTitle.Font = Enum.Font.GothamBold
tokenPanelTitle.TextColor3 = Color3.fromRGB(245, 235, 245)
tokenPanelTitle.TextXAlignment = Enum.TextXAlignment.Left
tokenPanelTitle.TextSize = 15
tokenPanelTitle.Text = "Priority Token"
tokenPanelTitle.ZIndex = 101
tokenPanelTitle.Parent = tokenPanelFrame

local tokenPanelHint = Instance.new("TextLabel")
tokenPanelHint.BackgroundTransparency = 1
tokenPanelHint.Position = UDim2.new(0, 12, 0, 32)
tokenPanelHint.Size = UDim2.new(1, -24, 0, 18)
tokenPanelHint.Font = Enum.Font.Gotham
tokenPanelHint.TextColor3 = Color3.fromRGB(210, 210, 210)
tokenPanelHint.TextXAlignment = Enum.TextXAlignment.Left
tokenPanelHint.TextSize = 11
tokenPanelHint.Text = "Enabled tokens are collected before nearest regular tokens."
tokenPanelHint.ZIndex = 101
tokenPanelHint.Parent = tokenPanelFrame

tokenScroll = Instance.new("ScrollingFrame")
tokenScroll.Name = "TokenScroll"
tokenScroll.Position = UDim2.new(0, 12, 0, 58)
tokenScroll.Size = UDim2.new(1, -24, 1, -70)
tokenScroll.BackgroundTransparency = 1
tokenScroll.BorderSizePixel = 0
tokenScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
tokenScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
tokenScroll.ScrollBarThickness = 6
tokenScroll.ZIndex = 101
tokenScroll.Parent = tokenPanelFrame

local tokenScrollLayout = Instance.new("UIListLayout")
tokenScrollLayout.Padding = UDim.new(0, 6)
tokenScrollLayout.SortOrder = Enum.SortOrder.LayoutOrder
tokenScrollLayout.Parent = tokenScroll

buttons.questTab = makeButton("QuestTab", "Quests", 12, 12, 84)
buttons.debugTab = makeButton("DebugTab", "Debug", 104, 12, 84)
buttons.testTab = makeButton("TestTab", "Test", 196, 12, 84)
buttons.stopAll = makeButton("StopAll", "Stop All", 288, 12, 92)

buttons.questTab.Parent = bottomBarFrame
buttons.debugTab.Parent = bottomBarFrame
buttons.testTab.Parent = bottomBarFrame
buttons.stopAll.Parent = bottomBarFrame

local resizeGrip = Instance.new("TextButton")
resizeGrip.Name = "ResizeGrip"
resizeGrip.AnchorPoint = Vector2.new(1, 1)
resizeGrip.Position = UDim2.new(1, -8, 1, -8)
resizeGrip.Size = UDim2.new(0, 18, 0, 18)
resizeGrip.BackgroundColor3 = Color3.fromRGB(66, 50, 66)
resizeGrip.BorderSizePixel = 0
resizeGrip.Text = ""
resizeGrip.ZIndex = 102
resizeGrip.Parent = root

local resizeCorner = Instance.new("UICorner")
resizeCorner.CornerRadius = UDim.new(0, 4)
resizeCorner.Parent = resizeGrip

local dragging = false
local dragStart
local startPos
local resizing = false
local resizeStart
local startSize
local activeSliderDrag
local moveSpeedFill
local moveSpeedValue
local boostRoundFill
local boostRoundValue
local gooRoundFill
local gooRoundValue
local convertRoundFill
local convertRoundValue
local fieldDropdownButton
local fieldDropdownFrame
local MIN_WIDTH = 620
local MIN_HEIGHT = 360
local SIDE_PANEL_MIN_WIDTH = 980

dragBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = root.Position

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

trackConnection(UserInputService.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
        if dragging then
            local delta = input.Position - dragStart
            root.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        elseif resizing then
            local delta = input.Position - resizeStart
            local newWidth = math.max(MIN_WIDTH, startSize.X.Offset + delta.X)
            local newHeight = math.max(MIN_HEIGHT, startSize.Y.Offset + delta.Y)
            root.Size = UDim2.new(0, newWidth, 0, newHeight)
            if newWidth < SIDE_PANEL_MIN_WIDTH then
                state.beePanelOpen = false
                state.upgradePanelOpen = false
                state.tokenPanelOpen = false
                pushUi()
            end
        elseif activeSliderDrag then
            activeSliderDrag.update(input.Position.X)
        end
    end
end))

resizeGrip.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        resizing = true
        resizeStart = input.Position
        startSize = root.Size

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                resizing = false
            end
        end)
    end
end)

trackConnection(UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        activeSliderDrag = nil
    end
end))

function buildQuestLines(quest)
    local lines = { quest.title }
    local tasks = quest.tasks or {}
    if #tasks == 0 and quest.objective ~= "" then
        tasks = {}
        for task in string.gmatch(quest.objective, "([^|]+)") do
            table.insert(tasks, compactText(task))
        end
    end

    for _, task in ipairs(tasks) do
        if task ~= "" then
            table.insert(lines, "  " .. task)
        end
    end

    if quest.reward ~= "" then
        table.insert(lines, "  " .. quest.reward)
    end

    return table.concat(lines, "\n")
end

function makeSliderBar(parent, x, y, width)
    local bar = Instance.new("TextButton")
    bar.BackgroundColor3 = Color3.fromRGB(40, 32, 40)
    bar.BorderSizePixel = 0
    bar.Position = UDim2.new(0, x, 0, y)
    bar.Size = UDim2.new(0, width, 0, 14)
    bar.Text = ""
    bar.AutoButtonColor = false
    bar.ZIndex = 101
    bar.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = bar

    local fill = Instance.new("Frame")
    fill.BackgroundColor3 = Color3.fromRGB(164, 53, 90)
    fill.BorderSizePixel = 0
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.ZIndex = 102
    fill.Parent = bar

    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(0, 4)
    fillCorner.Parent = fill

    return bar, fill
end

function bindSliderDrag(bar, maxValue, setter, offset, span)
    local function updateFromX(mouseX)
        local percent = math.clamp((mouseX - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        setter(offset + (percent * span))
    end

    bar.MouseButton1Down:Connect(function(x)
        activeSliderDrag = {
            bar = bar,
            update = updateFromX
        }
        updateFromX(x)
    end)

    bar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            if activeSliderDrag and activeSliderDrag.bar == bar then
                activeSliderDrag = nil
            end
        end
    end)
end

function setTweenSpeed(value)
    state.tweenSpeed = normalizeTweenSpeedLevel(value)
    if moveSpeedFill then
        moveSpeedFill.Size = UDim2.new((state.tweenSpeed - TWEEN_SPEED_MIN) / (TWEEN_SPEED_MAX - TWEEN_SPEED_MIN), 0, 1, 0)
    end
    if moveSpeedValue then
        moveSpeedValue.Text = tostring(state.tweenSpeed)
    end
    if runtime.moveSession and runtime.moveSession.align then
        runtime.moveSession.align.MaxVelocity = getTweenVelocity()
    end
    if state.autoRbc then
        setAutoRbcWalkSpeed(true)
    end
end

function makeCompactRoundSlider(parent, labelText, layoutOrder, getter, setter)
    local frame = Instance.new("Frame")
    frame.Name = labelText:gsub("%W", "") .. "Frame"
    frame.BackgroundTransparency = 1
    frame.LayoutOrder = layoutOrder
    frame.Size = UDim2.new(0, 180, 0, 34)
    frame.Parent = parent

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Position = UDim2.new(0, 0, 0, 0)
    label.Size = UDim2.new(0, 54, 0, 28)
    label.Font = Enum.Font.Gotham
    label.TextColor3 = Color3.fromRGB(210, 210, 210)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextSize = 11
    label.Text = labelText
    label.ZIndex = 102
    label.Parent = frame

    local bar, fill = makeSliderBar(frame, 56, 10, 86)
    local valueLabel = Instance.new("TextLabel")
    valueLabel.BackgroundTransparency = 1
    valueLabel.Position = UDim2.new(0, 146, 0, 4)
    valueLabel.Size = UDim2.new(0, 28, 0, 18)
    valueLabel.Font = Enum.Font.Code
    valueLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
    valueLabel.TextSize = 12
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    valueLabel.ZIndex = 102
    valueLabel.Parent = frame

    bindSliderDrag(bar, 25, function(value)
        setter(math.clamp(math.floor(value + 0.5), 1, 25))
        pushUi()
    end, 1, 24)
    local value = getter()
    fill.Size = UDim2.new((value - 1) / 24, 0, 1, 0)
    valueLabel.Text = tostring(value)
    return fill, valueLabel
end

boostRoundFill, boostRoundValue = makeCompactRoundSlider(
    boostsControls,
    "Boost R",
    4,
    function() return state.boostMinRound end,
    function(value) state.boostMinRound = value end
)
gooRoundFill, gooRoundValue = makeCompactRoundSlider(
    boostsControls,
    "Goo R",
    5,
    function() return state.gooGumdropsMinRound end,
    function(value) state.gooGumdropsMinRound = value end
)
convertRoundFill, convertRoundValue = makeCompactRoundSlider(
    boostsControls,
    "Convert R",
    6,
    function() return state.instantConvertMinRound end,
    function(value) state.instantConvertMinRound = value end
)

do
    local moveSpeedFrame = Instance.new("Frame")
    moveSpeedFrame.Name = "MoveSpeedFrame"
    moveSpeedFrame.BackgroundTransparency = 1
    moveSpeedFrame.LayoutOrder = 3
    moveSpeedFrame.Size = UDim2.new(0, 260, 0, 34)
    moveSpeedFrame.Parent = moveMethodControls

    local speedLabel = Instance.new("TextLabel")
    speedLabel.BackgroundTransparency = 1
    speedLabel.Position = UDim2.new(0, 0, 0, 0)
    speedLabel.Size = UDim2.new(0, 76, 0, 16)
    speedLabel.Font = Enum.Font.Gotham
    speedLabel.TextColor3 = Color3.fromRGB(210, 210, 210)
    speedLabel.TextXAlignment = Enum.TextXAlignment.Left
    speedLabel.TextSize = 11
    speedLabel.Text = "Move / Walk Speed"
    speedLabel.ZIndex = 102
    speedLabel.Parent = moveSpeedFrame

    local speedBar
    speedBar, moveSpeedFill = makeSliderBar(moveSpeedFrame, 82, 10, 118)
    moveSpeedValue = Instance.new("TextLabel")
    moveSpeedValue.BackgroundTransparency = 1
    moveSpeedValue.Position = UDim2.new(0, 206, 0, 4)
    moveSpeedValue.Size = UDim2.new(0, 38, 0, 18)
    moveSpeedValue.Font = Enum.Font.Code
    moveSpeedValue.TextColor3 = Color3.fromRGB(240, 240, 240)
    moveSpeedValue.TextSize = 12
    moveSpeedValue.TextXAlignment = Enum.TextXAlignment.Right
    moveSpeedValue.ZIndex = 102
    moveSpeedValue.Parent = moveSpeedFrame

    bindSliderDrag(speedBar, TWEEN_SPEED_MAX, setTweenSpeed, TWEEN_SPEED_MIN, TWEEN_SPEED_MAX - TWEEN_SPEED_MIN)
    setTweenSpeed(state.tweenSpeed)
end

do
    local fieldSelectorFrame = Instance.new("Frame")
    fieldSelectorFrame.Name = "FieldSelectorFrame"
    fieldSelectorFrame.BackgroundTransparency = 1
    fieldSelectorFrame.LayoutOrder = 1
    fieldSelectorFrame.Size = UDim2.new(0, 360, 0, 34)
    fieldSelectorFrame.Parent = farmingControls

    local fieldLabel = Instance.new("TextLabel")
    fieldLabel.BackgroundTransparency = 1
    fieldLabel.Position = UDim2.new(0, 0, 0, 0)
    fieldLabel.Size = UDim2.new(0, 78, 0, 28)
    fieldLabel.Font = Enum.Font.Gotham
    fieldLabel.TextColor3 = Color3.fromRGB(210, 210, 210)
    fieldLabel.TextXAlignment = Enum.TextXAlignment.Left
    fieldLabel.TextSize = 12
    fieldLabel.Text = "Field"
    fieldLabel.ZIndex = 202
    fieldLabel.Parent = fieldSelectorFrame

    fieldDropdownButton = Instance.new("TextButton")
    fieldDropdownButton.Name = "FieldDropdownButton"
    fieldDropdownButton.Position = UDim2.new(0, 82, 0, 0)
    fieldDropdownButton.Size = UDim2.new(0, 240, 0, 28)
    fieldDropdownButton.BackgroundColor3 = Color3.fromRGB(43, 33, 43)
    fieldDropdownButton.BorderSizePixel = 0
    fieldDropdownButton.Font = Enum.Font.GothamSemibold
    fieldDropdownButton.TextColor3 = Color3.fromRGB(245, 245, 245)
    fieldDropdownButton.TextSize = 12
    fieldDropdownButton.TextXAlignment = Enum.TextXAlignment.Left
    fieldDropdownButton.Text = state.selectedFarmField
    fieldDropdownButton.ZIndex = 202
    fieldDropdownButton.Parent = fieldSelectorFrame

    local dropdownPadding = Instance.new("UIPadding")
    dropdownPadding.PaddingLeft = UDim.new(0, 10)
    dropdownPadding.PaddingRight = UDim.new(0, 10)
    dropdownPadding.Parent = fieldDropdownButton

    local dropdownCorner = Instance.new("UICorner")
    dropdownCorner.CornerRadius = UDim.new(0, 6)
    dropdownCorner.Parent = fieldDropdownButton

    fieldDropdownFrame = Instance.new("ScrollingFrame")
    fieldDropdownFrame.Name = "FieldDropdown"
    fieldDropdownFrame.Visible = false
    fieldDropdownFrame.Position = UDim2.new(0, 82, 0, 32)
    fieldDropdownFrame.Size = UDim2.new(0, 240, 0, 228)
    fieldDropdownFrame.BackgroundColor3 = Color3.fromRGB(24, 20, 24)
    fieldDropdownFrame.BorderSizePixel = 0
    fieldDropdownFrame.ScrollBarThickness = 5
    fieldDropdownFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    fieldDropdownFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    fieldDropdownFrame.ZIndex = 210
    fieldDropdownFrame.Parent = fieldSelectorFrame

    local frameCorner = Instance.new("UICorner")
    frameCorner.CornerRadius = UDim.new(0, 6)
    frameCorner.Parent = fieldDropdownFrame

    local frameStroke = Instance.new("UIStroke")
    frameStroke.Color = Color3.fromRGB(88, 62, 88)
    frameStroke.Thickness = 1
    frameStroke.Parent = fieldDropdownFrame

    local frameLayout = Instance.new("UIListLayout")
    frameLayout.SortOrder = Enum.SortOrder.LayoutOrder
    frameLayout.Padding = UDim.new(0, 2)
    frameLayout.Parent = fieldDropdownFrame

    for index, fieldName in ipairs(FARM_FIELD_NAMES) do
        local option = Instance.new("TextButton")
        option.Name = fieldName:gsub("%W", "") .. "Option"
        option.Size = UDim2.new(1, -8, 0, 28)
        option.LayoutOrder = index
        option.BackgroundColor3 = Color3.fromRGB(31, 26, 31)
        option.BorderSizePixel = 0
        option.Font = Enum.Font.Gotham
        option.TextColor3 = Color3.fromRGB(240, 240, 240)
        option.TextXAlignment = Enum.TextXAlignment.Left
        option.TextSize = 12
        option.Text = fieldName
        option.ZIndex = 211
        option.Parent = fieldDropdownFrame

        local optionPadding = Instance.new("UIPadding")
        optionPadding.PaddingLeft = UDim.new(0, 10)
        optionPadding.PaddingRight = UDim.new(0, 10)
        optionPadding.Parent = option

        option.MouseButton1Click:Connect(function()
            state.selectedFarmField = fieldName
            state.fieldDropdownOpen = false
            state.detected.status = "Farming field set to " .. fieldName
            pushUi()
        end)
    end

    fieldDropdownButton.MouseButton1Click:Connect(function()
        state.fieldDropdownOpen = not state.fieldDropdownOpen
        pushUi()
    end)
end

function updateBeePriorityPanel()
    if not beePanelFrame then
        return
    end

    local showBeePanel = state.beePanelOpen and state.activeTab == "quests"
    local showUpgradePanel = state.upgradePanelOpen and state.activeTab == "quests"
    local showTokenPanel = state.tokenPanelOpen and state.activeTab == "quests"
    local rootWidth = root.AbsoluteSize.X
    if rootWidth < SIDE_PANEL_MIN_WIDTH then
        showBeePanel = false
        showUpgradePanel = false
        showTokenPanel = false
    end
    beePanelFrame.Visible = showBeePanel
    upgradePanelFrame.Visible = showUpgradePanel
    tokenPanelFrame.Visible = showTokenPanel
    local sideWidth = showUpgradePanel and 552 or ((showBeePanel or showTokenPanel) and 432 or 0)
    contentFrame.Size = sideWidth > 0 and UDim2.new(1, -sideWidth, 1, -236) or UDim2.new(1, 0, 1, -236)

    for beeName, row in pairs(beePriorityRows) do
        local config = state.beeConfig[beeName]
        row.priorityValue.Text = tostring(config.priority)
        row.roundValue.Text = tostring(config.minRound)
        row.priorityFill.Size = UDim2.new(config.priority / 50, 0, 1, 0)
        row.roundFill.Size = UDim2.new((config.minRound - 1) / 24, 0, 1, 0)
    end
end

function updateUpgradePanel()
    if not upgradePanelFrame or not upgradeScroll then
        return
    end

    for _, section in ipairs(UPGRADE_SECTIONS) do
        local header = upgradeScroll:FindFirstChild(section.rarity .. "UpgradeHeader")
        if header and header:IsA("TextButton") then
            header.Text = (upgradeSectionState[section.rarity] and "[-] " or "[+] ") .. section.rarity
        end
    end

    for upgradeName, row in pairs(upgradeRows) do
        if upgradeName ~= "__refresh" then
            local config = state.upgradeConfig[upgradeName]
            local meta = UPGRADE_BY_NAME[upgradeName]
            if config and meta and row.row then
                local visible = upgradeSectionState[row.rarity] == true
                row.row.Visible = visible
                row.enabledButton.Text = config.enabled and "ON" or "OFF"
                row.enabledButton.BackgroundColor3 = config.enabled and Color3.fromRGB(164, 53, 90) or Color3.fromRGB(43, 33, 43)
                if row.lockButton then
                    row.lockButton.Text = config.lock and "LOCK" or "NOLOCK"
                    row.lockButton.BackgroundColor3 = config.lock and Color3.fromRGB(95, 65, 126) or Color3.fromRGB(43, 33, 43)
                end
                row.countValue.Text = tostring(config.targetCount)
                row.countFill.Size = meta.cap > 0 and UDim2.new(config.targetCount / meta.cap, 0, 1, 0) or UDim2.new(0, 0, 1, 0)
                if row.roundValue and row.roundFill then
                    row.roundValue.Text = tostring(config.minRound or 1)
                    row.roundFill.Size = UDim2.new(((config.minRound or 1) - 1) / 24, 0, 1, 0)
                end
                row.previewLabel.Text = "Preview " .. tostring(config.targetCount) .. "/" .. tostring(meta.cap) .. ": " .. buildUpgradeEffectPreview(upgradeName, config.targetCount)
            end
        end
    end
end

upgradeRows.__refresh = updateUpgradePanel

function updateTokenPriorityPanel()
    for tokenName, row in pairs(tokenPriorityRows) do
        local enabled = state.tokenPriorityConfig[tokenName] == true
        row.button.Text = enabled and "ON" or "OFF"
        row.button.BackgroundColor3 = enabled and Color3.fromRGB(164, 53, 90) or Color3.fromRGB(43, 33, 43)
    end
end

function setTokenPriorityEnabled(tokenName, enabled)
    if PRIORITY_TOKEN_BY_NAME[tokenName] then
        state.tokenPriorityConfig[tokenName] = enabled == true
        updateTokenPriorityPanel()
    end
end

function setBeePriority(beeName, priority)
    local config = state.beeConfig[beeName]
    config.priority = math.clamp(math.floor(priority + 0.5), 0, 50)
    updateBeePriorityPanel()
end

function setBeeMinRound(beeName, minRound)
    local config = state.beeConfig[beeName]
    config.minRound = math.clamp(math.floor(minRound + 0.5), 1, 25)
    updateBeePriorityPanel()
end

do
    local layoutOrder = 1
    for _, section in ipairs(BEE_SECTIONS) do
        local header = Instance.new("TextLabel")
        header.Name = section.rarity .. "Header"
        header.Size = UDim2.new(1, -8, 0, 22)
        header.LayoutOrder = layoutOrder
        header.BackgroundTransparency = 1
        header.Font = Enum.Font.GothamBold
        header.TextColor3 = Color3.fromRGB(255, 218, 233)
        header.TextXAlignment = Enum.TextXAlignment.Left
        header.TextSize = 13
        header.Text = section.rarity
        header.ZIndex = 101
        header.Parent = beeScroll
        layoutOrder += 1

        for _, beeName in ipairs(section.bees) do
            local row = Instance.new("Frame")
            row.Name = beeName
            row.Size = UDim2.new(1, -8, 0, 42)
            row.LayoutOrder = layoutOrder
            row.BackgroundColor3 = Color3.fromRGB(31, 26, 31)
            row.BorderSizePixel = 0
            row.ZIndex = 101
            row.Parent = beeScroll
            layoutOrder += 1

            local rowCorner = Instance.new("UICorner")
            rowCorner.CornerRadius = UDim.new(0, 6)
            rowCorner.Parent = row

            local nameLabel = Instance.new("TextLabel")
            nameLabel.BackgroundTransparency = 1
            nameLabel.Position = UDim2.new(0, 8, 0, 0)
            nameLabel.Size = UDim2.new(0, 112, 1, 0)
            nameLabel.Font = Enum.Font.Gotham
            nameLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
            nameLabel.TextXAlignment = Enum.TextXAlignment.Left
            nameLabel.TextSize = 12
            nameLabel.Text = beeName
            nameLabel.ZIndex = 102
            nameLabel.Parent = row

            local priorityLabel = Instance.new("TextLabel")
            priorityLabel.BackgroundTransparency = 1
            priorityLabel.Position = UDim2.new(0, 126, 0, 3)
            priorityLabel.Size = UDim2.new(0, 50, 0, 14)
            priorityLabel.Font = Enum.Font.Gotham
            priorityLabel.TextColor3 = Color3.fromRGB(210, 210, 210)
            priorityLabel.TextSize = 11
            priorityLabel.Text = "Priority"
            priorityLabel.ZIndex = 102
            priorityLabel.Parent = row

            local priorityBar, priorityFill = makeSliderBar(row, 126, 20, 92)
            local priorityValue = Instance.new("TextLabel")
            priorityValue.BackgroundTransparency = 1
            priorityValue.Position = UDim2.new(0, 222, 0, 11)
            priorityValue.Size = UDim2.new(0, 24, 0, 16)
            priorityValue.Font = Enum.Font.Code
            priorityValue.TextColor3 = Color3.fromRGB(240, 240, 240)
            priorityValue.TextSize = 12
            priorityValue.Text = "0"
            priorityValue.TextXAlignment = Enum.TextXAlignment.Right
            priorityValue.ZIndex = 102
            priorityValue.Parent = row

            local roundLabel = Instance.new("TextLabel")
            roundLabel.BackgroundTransparency = 1
            roundLabel.Position = UDim2.new(0, 256, 0, 3)
            roundLabel.Size = UDim2.new(0, 58, 0, 14)
            roundLabel.Font = Enum.Font.Gotham
            roundLabel.TextColor3 = Color3.fromRGB(210, 210, 210)
            roundLabel.TextSize = 11
            roundLabel.Text = "Min Round"
            roundLabel.ZIndex = 102
            roundLabel.Parent = row

            local roundBar, roundFill = makeSliderBar(row, 256, 20, 86)
            local roundValue = Instance.new("TextLabel")
            roundValue.BackgroundTransparency = 1
            roundValue.Position = UDim2.new(0, 346, 0, 11)
            roundValue.Size = UDim2.new(0, 26, 0, 16)
            roundValue.Font = Enum.Font.Code
            roundValue.TextColor3 = Color3.fromRGB(240, 240, 240)
            roundValue.TextSize = 12
            roundValue.Text = "1"
            roundValue.TextXAlignment = Enum.TextXAlignment.Right
            roundValue.ZIndex = 102
            roundValue.Parent = row

            bindSliderDrag(priorityBar, 50, function(value)
                setBeePriority(beeName, value)
            end, 0, 50)

            bindSliderDrag(roundBar, 25, function(value)
                setBeeMinRound(beeName, value)
            end, 1, 24)

            beePriorityRows[beeName] = {
                priorityFill = priorityFill,
                priorityValue = priorityValue,
                roundFill = roundFill,
                roundValue = roundValue
            }
        end
    end
end

function setUpgradeEnabled(upgradeName, enabled)
    local config = state.upgradeConfig[upgradeName]
    if config then
        config.enabled = enabled == true
    end
end

function setUpgradeLock(upgradeName, locked)
    local config = state.upgradeConfig[upgradeName]
    if config then
        config.lock = locked == true
    end
end

function setUpgradeTargetCount(upgradeName, count)
    local config = state.upgradeConfig[upgradeName]
    local meta = UPGRADE_BY_NAME[upgradeName]
    if config and meta then
        config.targetCount = math.clamp(math.floor((count or 0) + 0.5), 0, meta.cap)
    end
end

function setUpgradeMinRound(upgradeName, minRound)
    local config = state.upgradeConfig[upgradeName]
    if config then
        config.minRound = math.clamp(math.floor((minRound or 1) + 0.5), 1, 25)
    end
end

function makeToggleChip(parent, text, width)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0, width, 0, 22)
    button.BackgroundColor3 = Color3.fromRGB(43, 33, 43)
    button.BorderSizePixel = 0
    button.Font = Enum.Font.GothamSemibold
    button.TextColor3 = Color3.fromRGB(245, 245, 245)
    button.TextSize = 11
    button.Text = text
    button.ZIndex = 102
    button.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = button
    return button
end

do
    local layoutOrder = 1
    for _, tokenDef in ipairs(PRIORITY_TOKEN_DEFS) do
        local row = Instance.new("Frame")
        row.Name = tokenDef.name:gsub("%W", "") .. "TokenRow"
        row.Size = UDim2.new(1, -8, 0, 34)
        row.LayoutOrder = layoutOrder
        row.BackgroundColor3 = Color3.fromRGB(31, 26, 31)
        row.BorderSizePixel = 0
        row.ZIndex = 101
        row.Parent = tokenScroll
        layoutOrder += 1

        local rowCorner = Instance.new("UICorner")
        rowCorner.CornerRadius = UDim.new(0, 6)
        rowCorner.Parent = row

        local nameLabel = Instance.new("TextLabel")
        nameLabel.BackgroundTransparency = 1
        nameLabel.Position = UDim2.new(0, 8, 0, 0)
        nameLabel.Size = UDim2.new(1, -70, 1, 0)
        nameLabel.Font = Enum.Font.Gotham
        nameLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.TextSize = 12
        nameLabel.Text = tokenDef.name
        nameLabel.ZIndex = 102
        nameLabel.Parent = row

        local toggleButton = makeToggleChip(row, "OFF", 50)
        toggleButton.Position = UDim2.new(1, -58, 0, 6)
        toggleButton.MouseButton1Click:Connect(function()
            setTokenPriorityEnabled(tokenDef.name, state.tokenPriorityConfig[tokenDef.name] ~= true)
        end)

        tokenPriorityRows[tokenDef.name] = {
            button = toggleButton
        }
    end
end

function createUpgradeRow(section, upgrade, layoutOrder)
    local row = Instance.new("Frame")
    row.Name = upgrade.name
    row.Size = UDim2.new(1, -8, 0, 92)
    row.LayoutOrder = layoutOrder
    row.BackgroundColor3 = Color3.fromRGB(31, 26, 31)
    row.BorderSizePixel = 0
    row.ZIndex = 101
    row.Parent = upgradeScroll

    local rowCorner = Instance.new("UICorner")
    rowCorner.CornerRadius = UDim.new(0, 6)
    rowCorner.Parent = row

    local nameLabel = Instance.new("TextLabel")
    nameLabel.BackgroundTransparency = 1
    nameLabel.Position = UDim2.new(0, 8, 0, 6)
    nameLabel.Size = UDim2.new(0, 190, 0, 18)
    nameLabel.Font = Enum.Font.GothamSemibold
    nameLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.TextSize = 12
    nameLabel.Text = upgrade.name .. " (Cap " .. tostring(upgrade.cap) .. ")"
    nameLabel.ZIndex = 102
    nameLabel.Parent = row

    local enabledButton = makeToggleChip(row, "OFF", 44)
    enabledButton.Position = UDim2.new(0, 204, 0, 4)

    local lockButton = makeToggleChip(row, "NOLOCK", 58)
    lockButton.Position = UDim2.new(0, 254, 0, 4)

    local countLabel = Instance.new("TextLabel")
    countLabel.BackgroundTransparency = 1
    countLabel.Position = UDim2.new(0, 324, 0, 6)
    countLabel.Size = UDim2.new(0, 42, 0, 16)
    countLabel.Font = Enum.Font.Gotham
    countLabel.TextColor3 = Color3.fromRGB(210, 210, 210)
    countLabel.TextSize = 11
    countLabel.Text = "Target"
    countLabel.ZIndex = 102
    countLabel.Parent = row

    local countBar, countFill = makeSliderBar(row, 374, 8, 72)
    local countValue = Instance.new("TextLabel")
    countValue.BackgroundTransparency = 1
    countValue.Position = UDim2.new(0, 452, 0, 6)
    countValue.Size = UDim2.new(0, 34, 0, 16)
    countValue.Font = Enum.Font.Code
    countValue.TextColor3 = Color3.fromRGB(240, 240, 240)
    countValue.TextSize = 12
    countValue.TextXAlignment = Enum.TextXAlignment.Right
    countValue.Text = "0"
    countValue.ZIndex = 102
    countValue.Parent = row

    local roundLabel = Instance.new("TextLabel")
    roundLabel.BackgroundTransparency = 1
    roundLabel.Position = UDim2.new(0, 324, 0, 30)
    roundLabel.Size = UDim2.new(0, 62, 0, 16)
    roundLabel.Font = Enum.Font.Gotham
    roundLabel.TextColor3 = Color3.fromRGB(210, 210, 210)
    roundLabel.TextSize = 11
    roundLabel.Text = "Min Round"
    roundLabel.ZIndex = 102
    roundLabel.Parent = row

    local roundBar, roundFill = makeSliderBar(row, 394, 32, 52)
    local roundValue = Instance.new("TextLabel")
    roundValue.BackgroundTransparency = 1
    roundValue.Position = UDim2.new(0, 452, 0, 30)
    roundValue.Size = UDim2.new(0, 34, 0, 16)
    roundValue.Font = Enum.Font.Code
    roundValue.TextColor3 = Color3.fromRGB(240, 240, 240)
    roundValue.TextSize = 12
    roundValue.TextXAlignment = Enum.TextXAlignment.Right
    roundValue.Text = "1"
    roundValue.ZIndex = 102
    roundValue.Parent = row

    local previewLabel = Instance.new("TextLabel")
    previewLabel.BackgroundTransparency = 1
    previewLabel.Position = UDim2.new(0, 8, 0, 54)
    previewLabel.Size = UDim2.new(1, -16, 0, 34)
    previewLabel.Font = Enum.Font.Gotham
    previewLabel.TextColor3 = Color3.fromRGB(210, 210, 210)
    previewLabel.TextXAlignment = Enum.TextXAlignment.Left
    previewLabel.TextYAlignment = Enum.TextYAlignment.Top
    previewLabel.TextWrapped = true
    previewLabel.TextSize = 10
    previewLabel.Text = upgrade.effects
    previewLabel.ZIndex = 102
    previewLabel.Parent = row

    enabledButton.MouseButton1Click:Connect(function()
        local config = state.upgradeConfig[upgrade.name]
        setUpgradeEnabled(upgrade.name, not config.enabled)
        if upgradeRows.__refresh then
            upgradeRows.__refresh()
        end
    end)

    lockButton.MouseButton1Click:Connect(function()
        local config = state.upgradeConfig[upgrade.name]
        setUpgradeLock(upgrade.name, not config.lock)
        if upgradeRows.__refresh then
            upgradeRows.__refresh()
        end
    end)

    bindSliderDrag(countBar, upgrade.cap, function(value)
        setUpgradeTargetCount(upgrade.name, value)
        if upgradeRows.__refresh then
            upgradeRows.__refresh()
        end
    end, 0, upgrade.cap)

    bindSliderDrag(roundBar, 25, function(value)
        setUpgradeMinRound(upgrade.name, value)
        if upgradeRows.__refresh then
            upgradeRows.__refresh()
        end
    end, 1, 24)

    upgradeRows[upgrade.name] = {
        row = row,
        enabledButton = enabledButton,
        lockButton = lockButton,
        countFill = countFill,
        countValue = countValue,
        roundFill = roundFill,
        roundValue = roundValue,
        previewLabel = previewLabel,
        rarity = section.rarity,
        cap = upgrade.cap
    }
end

do
    local layoutOrder = 1
    for _, section in ipairs(UPGRADE_SECTIONS) do
        local headerButton = Instance.new("TextButton")
        headerButton.Name = section.rarity .. "UpgradeHeader"
        headerButton.Size = UDim2.new(1, -8, 0, 24)
        headerButton.LayoutOrder = layoutOrder
        headerButton.BackgroundColor3 = Color3.fromRGB(39, 29, 39)
        headerButton.BorderSizePixel = 0
        headerButton.Font = Enum.Font.GothamBold
        headerButton.TextColor3 = Color3.fromRGB(255, 218, 233)
        headerButton.TextXAlignment = Enum.TextXAlignment.Left
        headerButton.TextSize = 13
        headerButton.Text = section.rarity
        headerButton.ZIndex = 101
        headerButton.Parent = upgradeScroll
        layoutOrder += 1

        local headerCorner = Instance.new("UICorner")
        headerCorner.CornerRadius = UDim.new(0, 6)
        headerCorner.Parent = headerButton

        headerButton.MouseButton1Click:Connect(function()
            upgradeSectionState[section.rarity] = not upgradeSectionState[section.rarity]
            if upgradeRows.__refresh then
                upgradeRows.__refresh()
            end
        end)

        for _, upgrade in ipairs(section.upgrades) do
            createUpgradeRow(section, upgrade, layoutOrder)
            layoutOrder += 1
        end
    end
end

function buildStatusText()
    local d = state.detected
    local questBlocks = {}
    if #d.quests > 0 then
        for index, quest in ipairs(d.quests) do
            if index > 4 then
                break
            end
            table.insert(questBlocks, buildQuestLines(quest))
        end
    else
        table.insert(questBlocks, "Quest A\n  Not detected")
        table.insert(questBlocks, "Quest B\n  Not detected")
    end

    local sections = {
        "Status: " .. d.status,
        "Auto RBC: " .. (state.autoRbc and "ON" or "OFF") .. " | Quest Field: " .. (state.currentRbcQuestField ~= "" and state.currentRbcQuestField or "Unknown"),
        "Route: " .. string.upper(state.route) .. " | Picked: " .. d.pickedQuest,
        "Move: " .. string.upper(state.moveMethod) .. " | Walk Speed: " .. tostring(state.tweenSpeed) .. (state.moveInProgress and " | Moving" or ""),
        "Farming Field: " .. tostring(state.selectedFarmField),
        "Bee AutoPick: " .. (state.autoBeePick and "ON" or "OFF") .. " | Picked Bee: " .. d.pickedBee .. " (" .. tostring(state.beePickCount) .. "/4)",
        "Upgrade AutoPick: " .. (state.autoUpgradePick and "ON" or "OFF") .. " | Auto Roll: " .. (state.autoUpgradeRoll and "ON" or "OFF") .. " | Picked Upgrade: " .. d.pickedUpgrade,
        "Golden Cogmower: " .. d.goldenCogmower,
        "Policy: boost R" .. tostring(state.boostMinRound)
            .. " | goo R" .. tostring(state.gooGumdropsMinRound)
            .. " | convert R" .. tostring(state.instantConvertMinRound)
            .. " | " .. state.lastMaterialReason,
        "",
        questBlocks[1] or "Quest A\n  Not detected",
        "",
        questBlocks[2] or "Quest B\n  Not detected",
        "",
        "Round: " .. formatValue(d.round) .. " | Cogs: " .. formatValue(d.cogs),
        "Updated: " .. d.updatedAt
    }

    if questBlocks[3] then
        table.insert(sections, 6, questBlocks[3])
        table.insert(sections, 7, "")
    end

    return table.concat(sections, "\n")
end

function buildDebugText()
    local d = state.detected
    return table.concat({
        "GUI Path:",
        d.guiPath,
        "Raw Text: " .. (d.rawText ~= "" and d.rawText or "N/A")
    }, "\n")
end

function pushHistory(list, text)
    table.insert(list, 1, text)
    while #list > 40 do
        table.remove(list)
    end
end

function buildTestText()
    local liveRound = tonumber(state.lastSeenLiveRound) or tonumber(state.detected.round) or 0
    local liveCogs = tonumber(state.lastSeenLiveCogs) or tonumber(state.detected.cogs) or "?"
    local minHistoryRound = liveRound > 1 and (liveRound - 1) or liveRound
    local function includeHistoryItem(item)
        local roundText = tostring(item or ""):match("Round%s+(%d+)")
        if not roundText or liveRound <= 0 then
            return true
        end
        local round = tonumber(roundText) or 0
        return round >= minHistoryRound and round <= liveRound
    end

    local function appendHistory(linesTable, list, emptyMessage, helperMessage)
        local added = false
        for _, item in ipairs(list) do
            if includeHistoryItem(item) then
                table.insert(linesTable, item)
                table.insert(linesTable, "")
                added = true
            end
        end
        if not added then
            table.insert(linesTable, emptyMessage)
            if helperMessage then
                table.insert(linesTable, helperMessage)
            end
        end
    end

    local lines = {
        "Detector Snapshot",
        "Status: " .. tostring(state.detected.status or "Unknown"),
        "Round: " .. formatValue(liveRound > 0 and liveRound or "?") .. " | Cogs: " .. formatValue(liveCogs),
        "Route: " .. string.upper(tostring(state.route or "blue")),
        "Auto Quest: " .. (state.autoPick and "ON" or "OFF")
            .. " | Auto Bee: " .. (state.autoBeePick and "ON" or "OFF")
            .. " | Auto Upgrade: " .. (state.autoUpgradePick and "ON" or "OFF")
            .. " | Auto Roll: " .. (state.autoUpgradeRoll and "ON" or "OFF"),
        "",
        liveRound > 1 and ("Showing rounds " .. tostring(liveRound - 1) .. "-" .. tostring(liveRound) .. " only") or "Showing latest round only",
        "",
        "Quest Picker History"
    }
    appendHistory(lines, state.questPickHistory, "No quest choices recorded for the shown round yet.", "Open the Robo Bear Choose a Quest screen, or turn AutoPick on before choosing.")

    table.insert(lines, "Bee Picker History")
    appendHistory(lines, state.beePickHistory, "No bee choices recorded for the shown round yet.", "This fills when the Choose a Bee screen appears or AutoBee sends a pick.")

    table.insert(lines, "Upgrade Picker History")
    appendHistory(lines, state.upgradePickHistory, "No upgrade choices recorded for the shown round yet.", "This fills when Purchase Upgrades is visible, AutoUpgrade sends a buy, or active upgrade levels change.")

    return table.concat(lines, "\n")
end

function summarizeQuestForHistory(quest)
    if not quest then
        return "Not detected"
    end
    local text = quest.objective or "Not detected"
    if quest.reward and quest.reward ~= "" then
        text = text .. " [" .. quest.reward .. "]"
    end
    return text
end

function formatBeeChoicesForHistory(choices)
    if type(choices) ~= "table" or #choices == 0 then
        return "None"
    end

    local parts = {}
    for _, choice in ipairs(choices) do
        table.insert(parts, tostring(choice.slot or "?") .. ":" .. tostring(choice.beeName or "?"))
    end
    return table.concat(parts, " | ")
end

function formatUpgradeChoicesForHistory(choices)
    if type(choices) ~= "table" or #choices == 0 then
        return "None"
    end

    local parts = {}
    for _, choice in ipairs(choices) do
        local cost = choice.cost and tostring(choice.cost) or "?"
        table.insert(parts, tostring(choice.slot or "?") .. ":" .. tostring(choice.upgradeName or "?") .. " cost " .. cost)
    end
    return table.concat(parts, " | ")
end

function recordActiveUpgradeChanges(activeCounts, currentRound)
    if type(activeCounts) ~= "table" then
        return
    end

    if not state.activeUpgradeBaselineReady or type(state.lastUpgradeActiveCounts) ~= "table" then
        state.lastUpgradeActiveCounts = {}
        local initial = {}
        for upgradeName, count in pairs(activeCounts) do
            state.lastUpgradeActiveCounts[upgradeName] = count
            if count > 0 then
                table.insert(initial, upgradeName .. " x" .. tostring(count))
            end
        end
        state.activeUpgradeBaselineReady = true
        if #initial > 0 then
            table.sort(initial)
            pushHistory(state.upgradePickHistory, table.concat({
                "[" .. os.date("%X") .. "] Round " .. tostring(currentRound),
                "Active upgrades already present",
                "Detected: " .. table.concat(initial, " | ")
            }, "\n"))
        end
        return
    end

    local changed = {}
    for upgradeName, count in pairs(activeCounts) do
        local previous = state.lastUpgradeActiveCounts[upgradeName] or 0
        if count > previous then
            table.insert(changed, upgradeName .. " " .. tostring(previous) .. "->" .. tostring(count))
        end
    end

    if #changed > 0 then
        table.sort(changed)
        pushHistory(state.upgradePickHistory, table.concat({
            "[" .. os.date("%X") .. "] Round " .. tostring(currentRound),
            "Active upgrade count changed",
            "Detected: " .. table.concat(changed, " | ")
        }, "\n"))
    end

    state.lastUpgradeActiveCounts = {}
    for upgradeName, count in pairs(activeCounts) do
        state.lastUpgradeActiveCounts[upgradeName] = count
    end
end

function cacheQuestSnapshot(quests, round, route)
    if type(quests) ~= "table" or #quests == 0 then
        return
    end

    local cloned = {}
    for index, quest in ipairs(quests) do
        cloned[index] = {
            title = quest.title,
            objective = quest.objective,
            reward = quest.reward,
            tasks = quest.tasks
        }
    end

    state.lastQuestSnapshot = {
        round = round,
        route = route,
        quests = cloned,
        capturedAt = os.date("%X")
    }
    state.lastQuestSnapshotAt = os.clock()
end

function getBufferedQuestSnapshot()
    if not state.lastQuestSnapshot then
        return nil
    end
    if (os.clock() - state.lastQuestSnapshotAt) > 3 then
        return nil
    end
    return state.lastQuestSnapshot
end

function updateTabUi()
    local isQuestTab = state.activeTab == "quests"
    local isDebugTab = state.activeTab == "debug"
    local isTestTab = state.activeTab == "test"
    statusLabel.Visible = isQuestTab
    debugBox.Visible = isDebugTab or isTestTab

    buttons.questTab.BackgroundColor3 = isQuestTab and Color3.fromRGB(76, 52, 76) or Color3.fromRGB(43, 33, 43)
    buttons.debugTab.BackgroundColor3 = isDebugTab and Color3.fromRGB(76, 52, 76) or Color3.fromRGB(43, 33, 43)
    buttons.testTab.BackgroundColor3 = isTestTab and Color3.fromRGB(76, 52, 76) or Color3.fromRGB(43, 33, 43)
    buttons.stopAll.Text = state.pausedAll and "Resume" or "Stop All"
    buttons.stopAll.BackgroundColor3 = state.pausedAll
        and Color3.fromRGB(76, 95, 52)
        or (state.autoScan or state.autoPick or state.autoBeePick or state.autoUpgradePick or state.autoRbc)
        and Color3.fromRGB(112, 42, 58)
        or Color3.fromRGB(43, 33, 43)
end

function updateControlTabUi()
    generalControls.Visible = state.controlTab == "general"
    questPickerControls.Visible = state.controlTab == "questpicker"
    beePickerControls.Visible = state.controlTab == "beepicker"
    upgradePickerControls.Visible = state.controlTab == "upgradepicker"
    moveMethodControls.Visible = state.controlTab == "move"
    farmingControls.Visible = state.controlTab == "farming"
    boostsControls.Visible = state.controlTab == "boosts"
    settingsControls.Visible = state.controlTab == "settings"

    buttons.generalTab.BackgroundColor3 = state.controlTab == "general" and Color3.fromRGB(76, 52, 76) or Color3.fromRGB(43, 33, 43)
    buttons.questPickerTab.BackgroundColor3 = state.controlTab == "questpicker" and Color3.fromRGB(76, 52, 76) or Color3.fromRGB(43, 33, 43)
    buttons.beePickerTab.BackgroundColor3 = state.controlTab == "beepicker" and Color3.fromRGB(76, 52, 76) or Color3.fromRGB(43, 33, 43)
    buttons.upgradePickerTab.BackgroundColor3 = state.controlTab == "upgradepicker" and Color3.fromRGB(76, 52, 76) or Color3.fromRGB(43, 33, 43)
    buttons.moveMethodTab.BackgroundColor3 = state.controlTab == "move" and Color3.fromRGB(76, 52, 76) or Color3.fromRGB(43, 33, 43)
    buttons.farmingTab.BackgroundColor3 = state.controlTab == "farming" and Color3.fromRGB(76, 52, 76) or Color3.fromRGB(43, 33, 43)
    buttons.boostsTab.BackgroundColor3 = state.controlTab == "boosts" and Color3.fromRGB(76, 52, 76) or Color3.fromRGB(43, 33, 43)
    buttons.settingsTab.BackgroundColor3 = state.controlTab == "settings" and Color3.fromRGB(76, 52, 76) or Color3.fromRGB(43, 33, 43)
end

function pushUi()
    if not isRuntimeActive() then
        return
    end

    buttons.auto.Text = state.autoScan and "Auto: ON" or "Auto: OFF"
    buttons.interact.Text = state.autoRoboBearInteract and "Robo E: ON" or "Robo E: OFF"
    buttons.autoRbc.Text = state.autoRbc and "Auto RBC: ON" or "Auto RBC: OFF"
    buttons.autoRbc.BackgroundColor3 = state.autoRbc and Color3.fromRGB(164, 53, 90) or Color3.fromRGB(43, 33, 43)
    buttons.route.Text = state.route == "blue" and "Route: Blue" or "Route: Red"
    buttons.pick.Text = state.autoPick and "AutoPick: ON" or "AutoPick: OFF"
    buttons.beePick.Text = state.autoBeePick and "AutoBee: ON" or "AutoBee: OFF"
    buttons.upgradePick.Text = state.autoUpgradePick and "AutoUpgrade: ON" or "AutoUpgrade: OFF"
    buttons.upgradeRoll.Text = state.autoUpgradeRoll and "AutoRoll: ON" or "AutoRoll: OFF"
    buttons.smartBoosts.Text = state.smartBoosts and "Boosts: ON" or "Boosts: OFF"
    buttons.smartMaterials.Text = state.smartMaterials and "Materials: ON" or "Materials: OFF"
    buttons.smartCombat.Text = state.smartCombat and "Combat: ON" or "Combat: OFF"
    buttons.smartBoosts.BackgroundColor3 = state.smartBoosts and Color3.fromRGB(164, 53, 90) or Color3.fromRGB(43, 33, 43)
    buttons.smartMaterials.BackgroundColor3 = state.smartMaterials and Color3.fromRGB(164, 53, 90) or Color3.fromRGB(43, 33, 43)
    buttons.smartCombat.BackgroundColor3 = state.smartCombat and Color3.fromRGB(164, 53, 90) or Color3.fromRGB(43, 33, 43)
    boostRoundFill.Size = UDim2.new((state.boostMinRound - 1) / 24, 0, 1, 0)
    boostRoundValue.Text = tostring(state.boostMinRound)
    gooRoundFill.Size = UDim2.new((state.gooGumdropsMinRound - 1) / 24, 0, 1, 0)
    gooRoundValue.Text = tostring(state.gooGumdropsMinRound)
    convertRoundFill.Size = UDim2.new((state.instantConvertMinRound - 1) / 24, 0, 1, 0)
    convertRoundValue.Text = tostring(state.instantConvertMinRound)
    buttons.moveWalk.BackgroundColor3 = state.moveMethod == "walk" and Color3.fromRGB(76, 52, 76) or Color3.fromRGB(43, 33, 43)
    buttons.moveTween.BackgroundColor3 = state.moveMethod == "tween" and Color3.fromRGB(164, 53, 90) or Color3.fromRGB(43, 33, 43)
    buttons.moveTween.Text = state.moveInProgress and "Tweening" or "Tween"
    buttons.autoLoad.Text = state.autoLoadConfig and "AutoLoad: ON" or "AutoLoad: OFF"
    if fieldDropdownButton then
        fieldDropdownButton.Text = state.selectedFarmField .. (state.fieldDropdownOpen and "  ^" or "  v")
    end
    if fieldDropdownFrame then
        fieldDropdownFrame.Visible = state.controlTab == "farming" and state.fieldDropdownOpen == true
    end
    setTweenSpeed(state.tweenSpeed)
    statusLabel.Text = buildStatusText()
    debugBox.Text = state.activeTab == "test" and buildTestText() or buildDebugText()
    updateTabUi()
    updateControlTabUi()
    updateBeePriorityPanel()
    updateUpgradePanel()
    updateTokenPriorityPanel()
end

function refreshDetection()
    if not isRuntimeActive() then
        return
    end

    if state.refreshInProgress then
        state.refreshQueued = true
        return
    end

    state.refreshInProgress = true
    resetGuiCache()
    if not root.Visible then
        state.refreshInProgress = false
        return
    end

    local guiData = scanGuiForQuestData()
    local guiCandidate = guiData and guiData.best or nil
    local visibleBeeChoices = findVisibleBeeChoices()
    local visibleUpgradeChoices = findVisibleUpgradeChoices()
    local activeUpgradeCounts = getActiveUpgradeCounts()
    local visibleBeeChoiceCount = #visibleBeeChoices
    local beeChoiceNames = {}
    for _, choice in ipairs(visibleBeeChoices) do
        table.insert(beeChoiceNames, tostring(choice.slot) .. ":" .. choice.beeName)
    end
    local upgradeChoiceNames = {}
    for _, choice in ipairs(visibleUpgradeChoices) do
        table.insert(upgradeChoiceNames, tostring(choice.slot) .. ":" .. choice.upgradeName)
    end

    local shouldForceStats = (#(guiData and guiData.quests or {}) == 0 and visibleBeeChoiceCount == 0 and #visibleUpgradeChoices == 0)
    local stats = getCachedStatsSnapshot(shouldForceStats)
    local statsSnapshot = parseRbcStats(stats)
    setRoboBearRoundEndSummary(getRbcRoundEndSummaryFromStats(stats))

    state.detected.round = statsSnapshot.round
    state.detected.score = statsSnapshot.score
    state.detected.cogs = statsSnapshot.cogs
    state.detected.goldenCogmower = getGoldenCogmowerStatus()
    state.detected.updatedAt = os.date("%X")
    state.detected.quests = guiData and guiData.quests or {}
    state.detected.pickedQuest = "None"
    state.detected.pickedBee = "None"
    state.detected.pickedUpgrade = "None"

    local currentLiveRound = getCurrentRbcRound()
    if currentLiveRound and currentLiveRound > 0 then
        if currentLiveRound ~= state.lastSeenLiveRound then
            state.lastSeenLiveRound = currentLiveRound
            state.lastQuestHistorySignature = ""
            state.lastBeeHistorySignature = ""
            state.lastUpgradeHistorySignature = ""
            state.lastBeeBlockedSignature = ""
            state.lastUpgradeLockHistorySignature = ""
            state.lastUpgradeBuyHistorySignature = ""
            state.lastQuestChoicesSeenAt = 0
            state.lastBeeChoicesSeenAt = 0
            state.lastUpgradeChoicesSeenAt = 0
            state.lastPickSignature = ""
            state.lastBeeChoiceSignature = ""
            state.lastUpgradePickSignature = ""
            state.lastUpgradeLockSignature = ""
            state.lastUpgradeRerollSignature = ""
            state.lastUpgradeRerollHistorySignature = ""
            state.lastUpgradeRerollAt = 0
            state.lastRoboBearRoundStartSignature = ""
            clearChallengeInfoWait()
        end
        state.detected.round = currentLiveRound
    end
    local currentLiveCogs = getCurrentRbcCogs()
    if currentLiveCogs ~= nil then
        state.lastSeenLiveCogs = currentLiveCogs
        state.detected.cogs = currentLiveCogs
    elseif state.lastSeenLiveCogs ~= "?" then
        state.detected.cogs = state.lastSeenLiveCogs
    end
    recordActiveUpgradeChanges(activeUpgradeCounts, currentLiveRound)

    if #state.detected.quests > 0 then
        local firstQuest = state.detected.quests[1]
        state.detected.status = "Quest choices detected (" .. tostring(#state.detected.quests) .. ")"
        state.detected.source = "PlayerGui"
        state.detected.questName = firstQuest.title
        state.detected.objective = firstQuest.objective
        state.detected.guiPath = guiData.guiPath or firstQuest.path
        state.detected.rawText = firstQuest.raw

        if guiData.direct and guiData.roundText ~= "" then
            local roundNumber = guiData.roundText:match("Round%s*(%d+)")
            if roundNumber then
                state.detected.round = tonumber(roundNumber) or state.detected.round
            end
        end

        if guiData.direct and guiData.cogsText ~= "" then
            local cogsNumber = guiData.cogsText:match("Cogs:%s*(%d+)")
            if cogsNumber then
                state.lastSeenLiveCogs = tonumber(cogsNumber) or state.lastSeenLiveCogs
                state.detected.cogs = state.lastSeenLiveCogs
            end
        end

        cacheQuestSnapshot(state.detected.quests, state.detected.round, state.route)
        local questChoiceSignatureParts = { tostring(state.detected.round), state.route }
        for _, quest in ipairs(state.detected.quests) do
            table.insert(questChoiceSignatureParts, quest.title or "?")
            table.insert(questChoiceSignatureParts, quest.objective or "?")
            table.insert(questChoiceSignatureParts, quest.reward or "?")
        end
        local questChoiceSignature = table.concat(questChoiceSignatureParts, "::")
        if questChoiceSignature ~= state.lastQuestHistorySignature then
            state.lastQuestChoicesSeenAt = os.clock()
            pushHistory(state.questPickHistory, table.concat({
                "[" .. os.date("%X") .. "] Round " .. tostring(state.detected.round) .. " | Route " .. string.upper(state.route),
                "Choices seen",
                "Quest A: " .. summarizeQuestForHistory(state.detected.quests[1]),
                "Quest B: " .. summarizeQuestForHistory(state.detected.quests[2])
            }, "\n"))
            state.lastQuestHistorySignature = questChoiceSignature
        end

        if state.autoPick then
            local pickIndex = chooseQuestIndex(state.detected.quests, state.route)
            if pickIndex then
                local questToPick = state.detected.quests[pickIndex]
                local signature = (questToPick.path or "") .. "::" .. (questToPick.objective or "") .. "::" .. state.route
                state.detected.pickedQuest = questToPick.title
                if signature ~= state.lastPickSignature
                    and (os.clock() - state.lastQuestChoicesSeenAt) >= state.actionDelay then
                    if fireRoboBearQuestSelect(pickIndex) then
                        local snapshotData = getBufferedQuestSnapshot()
                        local snapshotQuests = snapshotData and snapshotData.quests or state.detected.quests
                        local snapshotRound = snapshotData and snapshotData.round or state.detected.round
                        local snapshotRoute = snapshotData and snapshotData.route or state.route
                        local questField = inferFarmFieldFromQuest(questToPick, state.route)
                        state.selectedQuestProfile = buildSelectedQuestProfile(questToPick)
                        if questField then
                            state.currentRbcQuestField = questField
                            state.selectedFarmField = questField
                        end
                        pushHistory(state.questPickHistory, table.concat({
                            "[" .. os.date("%X") .. "] Round " .. tostring(snapshotRound) .. " | Route " .. string.upper(snapshotRoute),
                            "Quest A: " .. summarizeQuestForHistory(snapshotQuests[1]),
                            "Quest B: " .. summarizeQuestForHistory(snapshotQuests[2]),
                            "Sent pick: " .. questToPick.title .. " (slot " .. tostring(pickIndex) .. ")"
                                .. (questField and (" | Field: " .. questField) or "")
                        }, "\n"))
                        state.lastPickSignature = signature
                        state.detected.status = "Auto-picked " .. questToPick.title .. " for " .. state.route
                            .. (questField and (" | field " .. questField) or "")
                    end
                end
            end
        else
            state.lastPickSignature = ""
        end

    elseif guiCandidate then
        state.detected.status = "Quest detected"
        state.detected.source = "PlayerGui"
        state.detected.questName = extractQuestName(guiCandidate.text)
        state.detected.objective = extractObjective(guiCandidate.text)
        state.detected.guiPath = guiCandidate.path
        state.detected.rawText = guiCandidate.text
    elseif visibleBeeChoiceCount > 0 then
        state.detected.status = "Bee choices detected (" .. tostring(visibleBeeChoiceCount) .. ")"
        state.detected.source = "PlayerGui"
        state.detected.questName = "Choose a Bee"
        state.detected.objective = "Bee selection visible"
        state.detected.guiPath = "RoboBearPrompt bee selection"
        state.detected.rawText = table.concat(beeChoiceNames, " | ")
        state.detected.round = getCurrentRbcRound()
    elseif #visibleUpgradeChoices > 0 then
        state.detected.status = "Upgrade choices detected (" .. tostring(#visibleUpgradeChoices) .. ")"
        state.detected.source = "PlayerGui"
        state.detected.questName = "Choose an Upgrade"
        state.detected.objective = "Upgrade selection visible"
        state.detected.guiPath = "RoboBearPrompt upgrade selection"
        state.detected.rawText = table.concat(upgradeChoiceNames, " | ")
        state.detected.round = getCurrentRbcRound()
    elseif guiData and guiData.promptFound then
        state.detected.status = "RBC prompt found, no quest cards detected (" .. tostring(guiData.cardCount or 0) .. ")"
        state.detected.source = "PlayerGui"
        state.detected.questName = "Quest cards not visible"
        state.detected.objective = "Open the Choose a Quest panel fully"
        state.detected.guiPath = "RBC prompt subtree"
        state.detected.rawText = ""
    else
        state.detected.status = statsSnapshot.status
        state.detected.source = "RetrievePlayerStats"
        state.detected.questName = "No live RBC quest text found"
        state.detected.objective = "Open the Robo Bear Challenge prompt with Choose a Quest"
        state.detected.guiPath = "N/A"
        state.detected.rawText = ""
    end

    if visibleBeeChoiceCount > 0 then
        local currentRound = getCurrentRbcRound()
        local beeChoiceSignature = tostring(currentRound) .. "::" .. formatBeeChoicesForHistory(visibleBeeChoices)
        if beeChoiceSignature ~= state.lastBeeHistorySignature then
            state.lastBeeChoicesSeenAt = os.clock()
            pushHistory(state.beePickHistory, table.concat({
                "[" .. os.date("%X") .. "] Round " .. tostring(currentRound),
                "Choices seen",
                "Choices: " .. formatBeeChoicesForHistory(visibleBeeChoices)
            }, "\n"))
            state.lastBeeHistorySignature = beeChoiceSignature
        end
    else
        state.lastBeeHistorySignature = ""
    end

    if state.autoBeePick then
        local currentRound = getCurrentRbcRound()
        local now = os.clock()
        if currentRound ~= state.beePickRound then
            state.beePickRound = currentRound
            state.beePickCount = 0
            state.beePickedSlots = {}
            state.lastBeeChoiceSignature = ""
            state.lastBeePickAt = 0
        end

        local availableBeeChoices = {}
        for _, choice in ipairs(visibleBeeChoices) do
            if choice.slot and not state.beePickedSlots[choice.slot] then
                table.insert(availableBeeChoices, choice)
            end
        end
        local bestChoice = chooseBeeName(availableBeeChoices, currentRound)
        if bestChoice then
            state.lastBeeBlockedSignature = ""
            local choiceSignature = tostring(currentRound) .. "::" .. table.concat(beeChoiceNames, "|")
            local signature = choiceSignature .. "::" .. bestChoice.beeName .. "::" .. tostring(bestChoice.slot)
            state.detected.pickedBee = bestChoice.beeName .. " (" .. tostring(bestChoice.slot) .. ")"
            if state.beePickCount < 4
                and (now - state.lastBeePickAt) >= 0.85
                and (now - state.lastBeeChoicesSeenAt) >= state.actionDelay
                and bestChoice.slot then
                if fireRoboBearBeeSelect(bestChoice.slot) then
                    local nextBeePickCount = state.beePickCount + 1
                    pushHistory(state.beePickHistory, table.concat({
                        "[" .. os.date("%X") .. "] Round " .. tostring(currentRound),
                        "Action: Pick bee " .. tostring(nextBeePickCount) .. "/4",
                        "Choices: " .. formatBeeChoicesForHistory(visibleBeeChoices),
                        "Picked: " .. bestChoice.beeName .. " (slot " .. tostring(bestChoice.slot) .. ")"
                    }, "\n"))
                    state.lastBeePickSignature = signature
                    state.lastBeeChoiceSignature = choiceSignature
                    state.lastBeePickAt = now
                    state.beePickedSlots[bestChoice.slot] = true
                    state.beePickCount = nextBeePickCount
                    state.detected.status = "Auto-picked bee " .. bestChoice.beeName .. " slot " .. tostring(bestChoice.slot) .. " (" .. tostring(state.beePickCount) .. "/4)"
                end
            end
        else
            local blockedReason = getBeeBlockedReason(visibleBeeChoices, currentRound)
            if blockedReason then
                local blockedSignature = tostring(currentRound) .. "::" .. formatBeeChoicesForHistory(visibleBeeChoices) .. "::" .. blockedReason
                if blockedSignature ~= state.lastBeeBlockedSignature then
                    pushHistory(state.beePickHistory, table.concat({
                        "[" .. os.date("%X") .. "] Round " .. tostring(currentRound),
                        "Blocked by Min Round",
                        blockedReason
                    }, "\n"))
                    state.lastBeeBlockedSignature = blockedSignature
                end
            else
                state.lastBeeBlockedSignature = ""
            end
            state.lastBeePickSignature = ""
            state.lastBeeChoiceSignature = ""
            state.lastBeePickAt = 0
        end
    else
        state.lastBeePickSignature = ""
        state.lastBeeChoiceSignature = ""
        state.lastBeePickAt = 0
        state.beePickCount = 0
        state.beePickedSlots = {}
        state.lastBeeBlockedSignature = ""
    end

    if #visibleUpgradeChoices > 0 then
        local currentRound = getCurrentRbcRound()
        local upgradeChoiceSignature = tostring(currentRound) .. "::" .. formatUpgradeChoicesForHistory(visibleUpgradeChoices)
        if upgradeChoiceSignature ~= state.lastUpgradeHistorySignature then
            state.lastUpgradeChoicesSeenAt = os.clock()
            pushHistory(state.upgradePickHistory, table.concat({
                "[" .. os.date("%X") .. "] Round " .. tostring(currentRound),
                "Choices seen",
                "Choices: " .. formatUpgradeChoicesForHistory(visibleUpgradeChoices),
                "Cogs: " .. formatValue(getCurrentRbcCogs())
            }, "\n"))
            state.lastUpgradeHistorySignature = upgradeChoiceSignature
        end
    else
        state.lastUpgradeHistorySignature = ""
    end

    if state.autoUpgradePick then
        local currentCogs = getCurrentRbcCogs()
        local currentRound = getCurrentRbcRound()
        if not state.autoUpgradeRoll then
            local lockableUpgradeChoice = chooseLockableUpgradeChoice(visibleUpgradeChoices, activeUpgradeCounts, currentCogs, currentRound)
            if lockableUpgradeChoice then
                local lockSignature = buildUpgradeLockSignature(lockableUpgradeChoice, activeUpgradeCounts, currentCogs, currentRound)
                local now = os.clock()
                if lockSignature ~= state.lastUpgradeLockSignature
                    and (now - state.lastUpgradeLockAttemptAt) >= 0.75
                    and (now - state.lastUpgradeChoicesSeenAt) >= state.actionDelay
                    and fireRoboBearUpgradeLock(lockableUpgradeChoice.slot, true) then
                    if lockSignature ~= state.lastUpgradeLockHistorySignature then
                        pushHistory(state.upgradePickHistory, table.concat({
                            "[" .. os.date("%X") .. "] Round " .. tostring(currentRound),
                            "Action: Lock",
                            "Choices: " .. formatUpgradeChoicesForHistory(visibleUpgradeChoices),
                            "Cogs: " .. tostring(currentCogs) .. " | Cost: " .. tostring(lockableUpgradeChoice.cost or "?"),
                            "Sent lock: " .. lockableUpgradeChoice.upgradeName .. " (slot " .. tostring(lockableUpgradeChoice.slot) .. ")"
                        }, "\n"))
                        state.lastUpgradeLockHistorySignature = lockSignature
                    end
                    state.lastUpgradeLockSignature = lockSignature
                    state.lastUpgradeLockAttemptAt = now
                    state.detected.status = "Sent lock for upgrade " .. lockableUpgradeChoice.upgradeName .. " slot " .. tostring(lockableUpgradeChoice.slot)
                end
            end
        end

        local bestUpgradeChoice = chooseUpgradeChoice(visibleUpgradeChoices, activeUpgradeCounts, currentCogs, currentRound, true)
        if bestUpgradeChoice then
            local signature = buildUpgradeBuySignature(bestUpgradeChoice, activeUpgradeCounts, currentCogs, currentRound, visibleUpgradeChoices)
            local config = state.upgradeConfig[bestUpgradeChoice.upgradeName]
            local affordable = (bestUpgradeChoice.cost or 0) <= currentCogs
            local activeCount = activeUpgradeCounts[bestUpgradeChoice.upgradeName] or 0
            state.detected.pickedUpgrade = bestUpgradeChoice.upgradeName .. " (" .. tostring(bestUpgradeChoice.slot) .. ")"

            local now = os.clock()
            local sameUpgradeAttempt = signature == state.lastUpgradePickSignature
            local retryDelay = sameUpgradeAttempt and 2.5 or 0.75
            if affordable
                and (now - state.lastUpgradePickAttemptAt) >= retryDelay
                and (now - state.lastUpgradeChoicesSeenAt) >= state.actionDelay
                and fireRoboBearUpgradeSelect(bestUpgradeChoice.slot) then
                if signature ~= state.lastUpgradeBuyHistorySignature then
                    pushHistory(state.upgradePickHistory, table.concat({
                        "[" .. os.date("%X") .. "] Round " .. tostring(currentRound),
                        "Action: Buy",
                        "Choices: " .. formatUpgradeChoicesForHistory(visibleUpgradeChoices),
                        "Cogs: " .. tostring(currentCogs) .. " | Cost: " .. tostring(bestUpgradeChoice.cost or "?"),
                        "Sent buy: " .. bestUpgradeChoice.upgradeName .. " (slot " .. tostring(bestUpgradeChoice.slot) .. ", active " .. tostring(activeCount) .. "->?)"
                    }, "\n"))
                    state.lastUpgradeBuyHistorySignature = signature
                end
                state.lastUpgradePickSignature = signature
                state.lastUpgradePickAt = now
                state.lastUpgradePickAttemptAt = now
                state.lastUpgradeBoughtRound = currentRound
                state.detected.status = "Auto-picked upgrade " .. bestUpgradeChoice.upgradeName .. " slot " .. tostring(bestUpgradeChoice.slot)
            end
        else
            state.lastUpgradePickSignature = ""
        end
    else
        state.lastUpgradePickSignature = ""
        state.lastUpgradeLockSignature = ""
        state.lastUpgradeLockHistorySignature = ""
        state.lastUpgradeBuyHistorySignature = ""
        state.lastUpgradePickAt = 0
        state.lastUpgradePickAttemptAt = 0
        state.lastUpgradeLockAttemptAt = 0
    end

    if #visibleUpgradeChoices > 0 then
        if state.autoUpgradeRoll then
            tryAutoRollUpgradePicker(
                visibleUpgradeChoices,
                activeUpgradeCounts,
                getCurrentRbcCogs(),
                getCurrentRbcRound()
            )
        else
            tryRoboBearRoundStartAfterUpgrades(
                visibleUpgradeChoices,
                activeUpgradeCounts,
                getCurrentRbcCogs(),
                getCurrentRbcRound()
            )
        end
    end

    pushUi()

    state.refreshInProgress = false
    if state.refreshQueued then
        state.refreshQueued = false
        if isRuntimeActive() then
            task.defer(refreshDetection)
        end
    end
end

buttons.refresh.MouseButton1Click:Connect(function()
    refreshDetection()
end)

buttons.auto.MouseButton1Click:Connect(function()
    state.autoScan = not state.autoScan
    pushUi()
end)

buttons.interact.MouseButton1Click:Connect(function()
    state.autoRoboBearInteract = not state.autoRoboBearInteract
    state.detected.status = state.autoRoboBearInteract and "Robo Bear E enabled" or "Robo Bear E disabled"
    pushUi()
end)

function setAutoRbc(enabled)
    state.autoRbc = enabled == true
    if state.autoRbc then
        state.autoScan = true
        state.autoPick = true
        state.autoBeePick = true
        state.autoUpgradePick = true
        state.autoUpgradeRoll = true
        state.autoRoboBearInteract = true
        state.moveMethod = "tween"
        state.pausedAll = false
        state.pauseSnapshot = nil
        state.lastAutoRbcMoveTarget = ""
        state.lastAutoRbcMoveAt = 0
        state.tweenSpeed = TWEEN_SPEED_MAX
        installAutoPreciseHook()
        setAutoRbcWalkSpeed(true)
        state.detected.status = "Auto RBC enabled"
    else
        setCollectorInputHeld(false)
        setAutoRbcWalkSpeed(false)
        clearActiveTokenTarget(false)
        state.detected.status = "Auto RBC disabled"
    end
    pushUi()
end

buttons.autoRbc.MouseButton1Click:Connect(function()
    setAutoRbc(not state.autoRbc)
end)

buttons.generalTab.MouseButton1Click:Connect(function()
    state.controlTab = "general"
    state.fieldDropdownOpen = false
    pushUi()
end)

buttons.questPickerTab.MouseButton1Click:Connect(function()
    state.controlTab = "questpicker"
    state.fieldDropdownOpen = false
    pushUi()
end)

buttons.beePickerTab.MouseButton1Click:Connect(function()
    state.controlTab = "beepicker"
    state.fieldDropdownOpen = false
    pushUi()
end)

buttons.upgradePickerTab.MouseButton1Click:Connect(function()
    state.controlTab = "upgradepicker"
    state.fieldDropdownOpen = false
    pushUi()
end)

buttons.moveMethodTab.MouseButton1Click:Connect(function()
    state.controlTab = "move"
    state.fieldDropdownOpen = false
    pushUi()
end)

buttons.farmingTab.MouseButton1Click:Connect(function()
    state.controlTab = "farming"
    pushUi()
end)

buttons.boostsTab.MouseButton1Click:Connect(function()
    state.controlTab = "boosts"
    state.fieldDropdownOpen = false
    pushUi()
end)

buttons.smartBoosts.MouseButton1Click:Connect(function()
    state.smartBoosts = not state.smartBoosts
    pushUi()
end)

buttons.smartMaterials.MouseButton1Click:Connect(function()
    state.smartMaterials = not state.smartMaterials
    pushUi()
end)

buttons.smartCombat.MouseButton1Click:Connect(function()
    state.smartCombat = not state.smartCombat
    pushUi()
end)

buttons.settingsTab.MouseButton1Click:Connect(function()
    state.controlTab = "settings"
    state.fieldDropdownOpen = false
    pushUi()
end)

buttons.route.MouseButton1Click:Connect(function()
    state.route = state.route == "blue" and "red" or "blue"
    state.lastPickSignature = ""
    refreshDetection()
end)

buttons.pick.MouseButton1Click:Connect(function()
    state.autoPick = not state.autoPick
    state.lastPickSignature = ""
    refreshDetection()
end)

buttons.beePick.MouseButton1Click:Connect(function()
    state.autoBeePick = not state.autoBeePick
    state.lastBeePickSignature = ""
    refreshDetection()
end)

buttons.beePriority.MouseButton1Click:Connect(function()
    state.beePanelOpen = not state.beePanelOpen
    if state.beePanelOpen then
        state.upgradePanelOpen = false
        state.tokenPanelOpen = false
    end
    pushUi()
end)

buttons.upgradePick.MouseButton1Click:Connect(function()
    state.autoUpgradePick = not state.autoUpgradePick
    state.lastUpgradePickSignature = ""
    refreshDetection()
end)

buttons.upgradeRoll.MouseButton1Click:Connect(function()
    state.autoUpgradeRoll = not state.autoUpgradeRoll
    state.lastUpgradeRerollSignature = ""
    state.detected.status = state.autoUpgradeRoll and "Auto Roll enabled" or "Auto Roll disabled"
    refreshDetection()
end)

buttons.upgradeConfig.MouseButton1Click:Connect(function()
    state.upgradePanelOpen = not state.upgradePanelOpen
    if state.upgradePanelOpen then
        state.beePanelOpen = false
        state.tokenPanelOpen = false
    end
    pushUi()
end)

buttons.tokenPriority.MouseButton1Click:Connect(function()
    state.tokenPanelOpen = not state.tokenPanelOpen
    if state.tokenPanelOpen then
        state.beePanelOpen = false
        state.upgradePanelOpen = false
        state.activeTab = "quests"
    end
    pushUi()
end)

buttons.moveWalk.MouseButton1Click:Connect(function()
    setMoveMethod("walk")
end)

buttons.moveTween.MouseButton1Click:Connect(function()
    setMoveMethod("tween")
end)

buttons.autoLoad.MouseButton1Click:Connect(function()
    state.autoLoadConfig = not state.autoLoadConfig
    local ok, message = saveConfigToFile()
    state.detected.status = ok and "Auto-load " .. (state.autoLoadConfig and "enabled" or "disabled")
        or ("Auto-load toggled, " .. (message or "save failed"))
    pushUi()
end)

buttons.saveConfig.MouseButton1Click:Connect(function()
    local ok, message = saveConfigToFile()
    state.detected.status = message or (ok and "Config saved" or "Save failed")
    pushUi()
end)

buttons.loadConfig.MouseButton1Click:Connect(function()
    local ok, message = loadConfigFromFile()
    state.detected.status = message or (ok and "Config loaded" or "Load failed")
    if ok then
        refreshDetection()
    else
        pushUi()
    end
end)

buttons.exportConfig.MouseButton1Click:Connect(function()
    local ok, message = exportConfigToClipboard()
    state.detected.status = message or (ok and "Config exported" or "Export failed")
    pushUi()
end)

buttons.importConfig.MouseButton1Click:Connect(function()
    local ok, message = importConfigFromClipboard()
    state.detected.status = message or (ok and "Config imported" or "Import failed")
    if ok then
        refreshDetection()
    else
        pushUi()
    end
end)

buttons.questTab.MouseButton1Click:Connect(function()
    state.activeTab = "quests"
    pushUi()
end)

buttons.debugTab.MouseButton1Click:Connect(function()
    state.activeTab = "debug"
    pushUi()
end)

buttons.testTab.MouseButton1Click:Connect(function()
    state.activeTab = "test"
    pushUi()
end)

buttons.stopAll.MouseButton1Click:Connect(function()
    if state.pausedAll then
        local snapshot = state.pauseSnapshot or {}
        state.autoScan = snapshot.autoScan == true
        state.autoPick = snapshot.autoPick == true
        state.autoBeePick = snapshot.autoBeePick == true
        state.autoUpgradePick = snapshot.autoUpgradePick == true
        state.autoUpgradeRoll = snapshot.autoUpgradeRoll == true
        state.autoRbc = snapshot.autoRbc == true
        state.autoRoboBearInteract = snapshot.autoRoboBearInteract == true
        state.beePanelOpen = snapshot.beePanelOpen == true
        state.upgradePanelOpen = snapshot.upgradePanelOpen == true
        state.tokenPanelOpen = snapshot.tokenPanelOpen == true
        state.pausedAll = false
        state.pauseSnapshot = nil
        state.detected.status = "Resumed automation"
        pushUi()
        return
    end

    state.pauseSnapshot = {
        autoScan = state.autoScan,
        autoPick = state.autoPick,
        autoBeePick = state.autoBeePick,
        autoUpgradePick = state.autoUpgradePick,
        autoUpgradeRoll = state.autoUpgradeRoll,
        autoRbc = state.autoRbc,
        autoRoboBearInteract = state.autoRoboBearInteract,
        beePanelOpen = state.beePanelOpen,
        upgradePanelOpen = state.upgradePanelOpen,
        tokenPanelOpen = state.tokenPanelOpen
    }
    state.pausedAll = true
    state.autoScan = false
    state.autoPick = false
    state.autoBeePick = false
    state.autoUpgradePick = false
    state.autoUpgradeRoll = false
    state.autoRbc = false
    state.autoRoboBearInteract = false
    setCollectorInputHeld(false)
    setAutoRbcWalkSpeed(false)
    clearActiveTokenTarget(false)
    stopMoveSession()
    state.beePanelOpen = false
    state.upgradePanelOpen = false
    state.tokenPanelOpen = false
    state.lastPickSignature = ""
    state.lastBeePickSignature = ""
    state.lastBeeChoiceSignature = ""
    state.lastBeePickAt = 0
    state.beePickCount = 0
    state.beePickedSlots = {}
    state.lastUpgradePickSignature = ""
    state.lastUpgradeLockSignature = ""
    state.lastUpgradeLockHistorySignature = ""
    state.lastUpgradeBuyHistorySignature = ""
    state.lastUpgradePickAt = 0
    state.lastUpgradePickAttemptAt = 0
    state.lastUpgradeLockAttemptAt = 0
    state.lastUpgradeRerollAt = 0
    state.lastUpgradeRerollSignature = ""
    state.lastUpgradeRerollHistorySignature = ""
    state.lastRoboBearRoundStartAt = 0
    state.lastRoboBearRoundStartSignature = ""
    state.lastAutoRbcMoveTarget = ""
    state.lastAutoRbcMoveAt = 0
    clearChallengeInfoWait()
    state.detected.status = "Stopped all automation"
    pushUi()
end)

buttons.dump.MouseButton1Click:Connect(function()
    resetGuiCache()
    local items = findRbcPromptTexts()
    local encoded = HttpService:JSONEncode(items)
    print("=== RBC UI DUMP START ===")
    print(encoded)
    print("=== RBC UI DUMP END ===")

    if setclipboard then
        setclipboard(encoded)
        state.detected.status = "UI dump copied (" .. tostring(#items) .. ")"
    else
        state.detected.status = "UI dump printed (" .. tostring(#items) .. ")"
    end

    state.detected.guiPath = "Clipboard/console dump"
    state.detected.rawText = #items > 0 and items[1].text or "N/A"
    pushUi()
end)

buttons.copy.MouseButton1Click:Connect(function()
    local payload = HttpService:JSONEncode({
        detected = state.detected
    })
    if setclipboard then
        setclipboard(payload)
        state.detected.status = "Debug copied"
        pushUi()
    else
        state.detected.status = "Clipboard unavailable"
        pushUi()
    end
end)

trackConnection(UserInputService.InputBegan:Connect(function(input, processed)
    if processed then
        return
    end
    if not isRuntimeActive() then
        return
    end
    if input.KeyCode == Enum.KeyCode.RightControl then
        state.minimized = not state.minimized
        root.Visible = not state.minimized
    end
end))

if state.autoLoadConfig then
    local ok, message = loadConfigFromFile()
    if ok then
        state.detected.status = "Config auto-loaded"
    elseif message ~= "Config file not found" then
        state.detected.status = message or "Auto-load failed"
    end
end

function runProtectedLoopStep(loopName, callback)
    local ok, err = xpcall(callback, function(message)
        return tostring(message) .. "\n" .. tostring(debug.traceback())
    end)
    if ok then
        return true
    end
    runtime.lastLoopError = tostring(loopName) .. ": " .. tostring(err)
    state.detected.status = tostring(loopName) .. " recovered after error"
    pushUi()
    task.wait(0.45)
    return false
end

function runAutoScanLoop()
    runProtectedLoopStep("Detector", function()
        refreshDetection()
        updateBeePriorityPanel()
    end)
    while isRuntimeActive() do
        state.detectorLoopHeartbeat = os.clock()
        runProtectedLoopStep("Detector", function()
            if state.autoScan then
                local waitTime = state.scanInterval
                if state.autoBeePick or state.autoUpgradePick then
                    waitTime = 0.5
                end
                task.wait(waitTime)
                if state.autoScan and not state.refreshInProgress then
                    refreshDetection()
                end
            else
                task.wait(0.25)
            end
        end)
    end
end

function stepRoboBearDialog()
    local roundRunning, roundSummary = isRoboBearChallengeRoundRunning(false)
    if roundRunning then
        dismissNpcDialogDuringRound()
        clearChallengeInfoWait()
        state.detected.status = "Robo Bear round running; Robo E paused"
            .. ((roundSummary and roundSummary.round > 0) and (" | round " .. tostring(roundSummary.round)) or "")
        pushUi()
        task.wait(0.4)
        return
    end
    if isNpcDialogShowingRoundInProgress() then
        dismissNpcDialogDuringRound()
        clearChallengeInfoWait()
        state.detected.status = "Dismissed stale round dialogue"
        pushUi()
        task.wait(0.3)
        return
    end

    if not isNpcDialogOpen() and isRoboBearChallengePromptOpen() then
        state.detected.status = "RoboBearPrompt open; Robo E waiting"
        pushUi()
        task.wait(0.4)
        return
    end

    local now = os.clock()
    if (now - state.lastNpcDialogClickAt) < 0.55 then
        task.wait(0.08)
        return
    end

    local clicked, action = clickNpcDialogAction()
    state.lastNpcDialogClickAt = now
    if clicked then
        state.detected.status = "NPC dialog action: " .. tostring(action)
        pushUi()
    else
        state.detected.status = "NPC dialog remote idle: " .. tostring(action)
        pushUi()
    end
    task.wait(0.18)
end

function stepRoboBearInteract()
    local roundRunning, roundSummary = isRoboBearChallengeRoundRunning(false)
    if roundRunning then
        dismissNpcDialogDuringRound()
        clearChallengeInfoWait()
        state.detected.status = "Robo Bear round running; Robo E paused"
            .. ((roundSummary and roundSummary.round > 0) and (" | round " .. tostring(roundSummary.round)) or "")
        pushUi()
        task.wait(0.4)
        return
    end
    if runtime.npcDialogForcedHidden then
        local npcGui = getNpcDialogGui()
        if npcGui and not npcGui.Visible then
            npcGui.Visible = true
        end
        runtime.npcDialogForcedHidden = false
    end
    if isNpcDialogShowingRoundInProgress() then
        dismissNpcDialogDuringRound()
        clearChallengeInfoWait()
        state.detected.status = "Dismissed stale round dialogue"
        pushUi()
        task.wait(0.3)
        return
    end

    -- A dialog that was opened at the end of a round remains actionable after
    -- the player has moved back to a field. Handle it before the proximity gate.
    if isNpcDialogOpen() then
        if isRoboBearChallengePromptOpen() and clickVisibleRoboBearClaimRewardsButton() then
            state.lastRoboBearClaimAt = os.clock()
            state.pendingPostGameOverCancel = true
            state.detected.status = "Game Over rewards claimed"
            pushUi()
            task.wait(0.75)
            return
        end
        if state.pendingPostGameOverCancel then
            local npcGui = getNpcDialogGui()
            local cancelled = false
            for _, candidate in ipairs(collectNpcDialogOptions(npcGui)) do
                if candidate.kind == "cancel" then
                    cancelled = select(1, clickNpcDialogContinue(candidate))
                    break
                end
            end
            if cancelled then
                state.pendingPostGameOverCancel = false
                state.detected.status = "Closed stale Game Over dialogue"
                pushUi()
            end
            task.wait(0.55)
            return
        end
        stepRoboBearDialog()
        return
    end

    if isLiveRoboBearChallengeUiVisible() then
        local now = os.clock()
        if (now - state.lastRoboBearClaimAt) >= 1.5
            and clickVisibleRoboBearClaimRewardsButton() then
            state.lastRoboBearClaimAt = now
            state.pendingPostGameOverCancel = true
            state.detected.status = "Game Over rewards claimed"
            pushUi()
            task.wait(0.75)
            return
        end
        if isRoboBearChallengePromptOpen() then
            if (now - state.lastRoboBearRoundStartAt) >= 1.5 then
                local started, action = clickVisibleRoboBearStartRoundButton()
                state.lastRoboBearRoundStartAt = now
                state.detected.status = started
                    and ("Robo Bear round start: " .. tostring(action))
                    or ("Robo Bear start waiting: " .. tostring(action))
                pushUi()
                task.wait(started and 0.55 or 0.35)
                return
            end
        end
        clearChallengeInfoWait()
        state.detected.status = "Live RoboBearPrompt visible; Robo E paused"
        pushUi()
        task.wait(0.4)
        return
    end

    if isWaitingForChallengeInfo() then
        state.detected.status = "Waiting for live RoboBearPrompt after RoboBearRoundStart"
        pushUi()
        task.wait(0.25)
        return
    end

    if not isStandingAtRoboBearCircle() then
        state.detected.status = "Robo E waiting at Robo Bear circle"
        pushUi()
        task.wait(0.25)
        return
    end

    if isRoboBearChallengePromptOpen() then
        local roundEndSummary = refreshRoboBearRoundEndState(false)
        local startedRound = tryRoboBearRoundStartFromCurrentUpgradePrompt()
        if startedRound then
            pushUi()
            task.wait(0.4)
            return
        end

        state.detected.status = "RoboBearPrompt open; Robo E waiting"
            .. (roundEndSummary.ended and (" | round " .. tostring(roundEndSummary.round) .. " ended") or "")
        pushUi()
        task.wait(0.4)
        return
    end

    local now = os.clock()
    if (now - state.lastRoboBearEAt) < 0.35 then
        task.wait(0.1)
        return
    end

    local promptVisible = isRoboBearPromptVisible()
    local inCircle = isStandingAtRoboBearCircle()
    local fired, action = triggerRoboBearInteract()
    state.lastRoboBearEAt = now
    state.detected.status = (fired and ("Robo Bear interaction: " .. tostring(action)) or ("Robo Bear interaction waiting: " .. tostring(action)))
        .. (promptVisible and " | talk prompt" or "")
        .. (inCircle and " | circle" or "")
    pushUi()
    task.wait(fired and 0.45 or 0.35)
end

local RBC_FIELD_COLOR_CAPABILITIES = {
    ["Sunflower Field"] = { red = 0.35, white = 1.0 },
    ["Dandelion Field"] = { white = 1.0 },
    ["Mushroom Field"] = { red = 0.8, white = 0.45 },
    ["Blue Flower Field"] = { blue = 1.0, white = 0.35 },
    ["Clover Field"] = { red = 0.15, blue = 0.7, white = 0.25 },
    ["Strawberry Field"] = { red = 1.0, white = 0.35 },
    ["Spider Field"] = { white = 1.0 },
    ["Bamboo Field"] = { blue = 1.0, white = 0.3 },
    ["Pineapple Patch"] = { white = 1.0 },
    ["Cactus Field"] = { red = 0.15, blue = 0.85, white = 0.1 },
    ["Pumpkin Patch"] = { white = 1.0, blue = 0.4, red = 0.1 },
    ["Pine Tree Forest"] = { blue = 1.0, white = 0.1 },
    ["Rose Field"] = { red = 1.0, white = 0.35 },
    ["Mountain Top Field"] = { red = 0.05, blue = 1.0 }
}

function rbcFieldMatchesExplicitTarget(fieldName, target)
    for _, targetField in ipairs(target.fields or EMPTY_TABLE) do
        if targetField == fieldName then
            return true
        end
    end
    return false
end

function scoreRbcFieldForTargets(fieldName, targets)
    local capabilities = RBC_FIELD_COLOR_CAPABILITIES[fieldName] or {}
    local score = 0
    local mode = "field"

    for _, target in ipairs(targets) do
        if not target.complete then
            local remaining = math.max(0.15, target.remainingRatio or 1)
            if target.explicitField then
                if rbcFieldMatchesExplicitTarget(fieldName, target) then
                    score += 520 * remaining
                else
                    -- Explicit-field objectives make no progress elsewhere.
                    -- Keep Homepage and travel bonuses from pulling the route
                    -- away from a required field.
                    score -= 650 * remaining
                end
            else
                local matchedColors = 0
                local colorEfficiency = 0
                if target.red and (capabilities.red or 0) > 0 then
                    matchedColors += 1
                    colorEfficiency += capabilities.red
                end
                if target.blue and (capabilities.blue or 0) > 0 then
                    matchedColors += 1
                    colorEfficiency += capabilities.blue
                end
                if target.white and (capabilities.white or 0) > 0 then
                    matchedColors += 1
                    colorEfficiency += capabilities.white
                end
                local requestedColors = (target.red and 1 or 0)
                    + (target.blue and 1 or 0)
                    + (target.white and 1 or 0)
                if requestedColors > 0 then
                    score += colorEfficiency * 150 * remaining
                    if matchedColors == requestedColors then
                        score += 100 * remaining
                    end
                else
                    score += 45 * remaining
                end
                if target.goo then
                    score += 70 * remaining
                end
                if target.convert then
                    score += 35 * remaining
                    mode = "convert"
                end
            end
        end
    end

    if fieldName == state.currentRbcQuestField then
        score += 22
    end

    local activeUpgrades = getActiveUpgradeCounts()
    local homepage = activeUpgrades["Homepage"] or 0
    if homepage > 0 and (fieldName == "Mushroom Field"
        or fieldName == "Dandelion Field"
        or fieldName == "Sunflower Field"
        or fieldName == "Blue Flower Field") then
        score += homepage * 120
    end

    local rootPart = getCharacterRoot()
    local targetPosition = getFarmFieldTargetPosition(fieldName)
    if rootPart and targetPosition then
        score -= math.min(90, (rootPart.Position - targetPosition).Magnitude * 0.055)
    end
    return score, mode
end

function getAutoRbcTargetField()
    local targets = getVisibleRbcTaskTargets()
    local candidateFields = {}
    local hasRed, hasBlue, hasWhite, hasGeneric = false, false, false, false
    for _, target in ipairs(targets) do
        if not target.complete then
            if isValidFarmField(target.fieldName) then
                candidateFields[target.fieldName] = true
            end
            for _, fieldName in ipairs(target.fields or EMPTY_TABLE) do
                if isValidFarmField(fieldName) then
                    candidateFields[fieldName] = true
                end
            end
            hasRed = hasRed or target.red
            hasBlue = hasBlue or target.blue
            hasWhite = hasWhite or target.white
            hasGeneric = hasGeneric or (not target.explicitField
                and not target.red
                and not target.blue
                and not target.white
                and not target.convert)
        end
    end

    if hasRed and hasWhite then
        candidateFields["Sunflower Field"] = true
    end
    if hasBlue and hasWhite then
        candidateFields["Blue Flower Field"] = true
    end
    if hasRed then
        candidateFields["Rose Field"] = true
    end
    if hasBlue then
        candidateFields["Blue Flower Field"] = true
    end
    if hasWhite then
        candidateFields["Dandelion Field"] = true
    end
    if hasGeneric or hasRed then
        candidateFields["Strawberry Field"] = true
        candidateFields["Mushroom Field"] = true
    end
    candidateFields[getRouteDefaultFarmField()] = true
    if isValidFarmField(state.currentRbcQuestField) then
        candidateFields[state.currentRbcQuestField] = true
    end

    local bestField, bestMode, bestScore
    for fieldName in pairs(candidateFields) do
        local score, mode = scoreRbcFieldForTargets(fieldName, targets)
        if not bestScore or score > bestScore then
            bestField, bestMode, bestScore = fieldName, mode, score
        end
    end

    if bestField and isValidFarmField(state.currentRbcQuestField)
        and bestField ~= state.currentRbcQuestField
        and (os.clock() - state.lastRbcFieldSwitchAt) < 5 then
        local currentScore, currentMode = scoreRbcFieldForTargets(state.currentRbcQuestField, targets)
        if currentScore > 0 and bestScore < currentScore + 160 then
            bestField, bestMode, bestScore = state.currentRbcQuestField, currentMode, currentScore
        end
    end

    if bestField then
        if bestField ~= state.currentRbcQuestField then
            state.lastRbcFieldSwitchAt = os.clock()
            state.lastTokenCollectTarget = ""
            clearActiveTokenTarget(false)
            state.tokenQueue = {}
            state.tokenQueueField = ""
            state.lastFarmRootPosition = nil
            state.farmPatrolIndex = 0
        end
        state.currentRbcQuestField = bestField
        state.currentRbcQuestMode = bestMode or "field"
        state.selectedFarmField = bestField
        state.lastRbcTaskSignature = table.concat((function()
            local texts = {}
            for _, target in ipairs(targets) do
                if not target.complete then
                    table.insert(texts, (normalizeFieldText(target.text)))
                end
            end
            return texts
        end)(), "|")
        return bestField, state.currentRbcQuestMode
    end

    if isValidFarmField(state.currentRbcQuestField) then
        return state.currentRbcQuestField, state.currentRbcQuestMode or "field"
    end

    local visibleField = inferVisibleRbcQuestField()
    if isValidFarmField(visibleField) then
        state.currentRbcQuestField = visibleField
        state.currentRbcQuestMode = "field"
        state.selectedFarmField = visibleField
        return visibleField, "field"
    end

    return nil
end

function ensureAutoRbcComponentToggles()
    applyRbcGuideDefaultsIfUnconfigured()
    state.autoScan = true
    state.autoPick = true
    state.autoBeePick = true
    state.autoUpgradePick = true
    state.autoUpgradeRoll = true
    state.autoRoboBearInteract = true
    state.route = "red"
    state.moveMethod = "tween"
    state.tweenSpeed = TWEEN_SPEED_MAX
    installAutoPreciseHook()
end

function stepAutoRbc()
    ensureAutoRbcComponentToggles()

    local roundRunning, roundSummary = isRoboBearChallengeRoundRunning(false)
    local observedRound = tonumber(roundSummary and roundSummary.round) or 0
    if observedRound > 0 and state.lastObservedRbcRound > 0 and observedRound < state.lastObservedRbcRound then
        state.lastUpgradeBoughtRound = -1
        state.lastUpgradeRerollRound = -1
        state.materialLastUsedRound = {}
        state.lastBoostTaskSignature = ""
    end
    if observedRound > 0 then
        state.lastObservedRbcRound = observedRound
    end
    setCollectorInputHeld(roundRunning)
    setAutoRbcWalkSpeed(roundRunning)

    if state.moveInProgress then
        task.wait(0.25)
        return
    end

    if roundRunning then
        clearChallengeInfoWait()
        local fieldName, questMode = getAutoRbcTargetField()
        if not fieldName then
            state.detected.status = "Auto RBC round running; field unknown"
            pushUi()
            task.wait(0.45)
            return
        end


        -- Target Practice marks can remain in the previous field after an
        -- objective switch. Finish owned marks before routing to the next field.
        if stepAutoPrecise(fieldName) then
            task.wait(0.08)
            return
        end

        -- Precise marks have a short lifetime and directly accelerate pollen
        -- collection. Combat is therefore considered only after owned marks.
        if stepRbcCombat(observedRound) then
            task.wait(0.12)
            return
        end

        if isStandingAtFarmField(fieldName) then
            placeRbcSprinkler(fieldName)
            if stepSmartRbcMaterials(roundSummary, fieldName) then
                task.wait(0.12)
            end
            if questMode == "convert" and stepConvertQuestIfNeeded() then
                task.wait(0.35)
                return
            end

            if stepTokenCollectorInField(fieldName) then
                task.wait(0.15)
                return
            end

            state.detected.status = "Auto RBC farming " .. fieldName
                .. ((roundSummary and roundSummary.round > 0) and (" | round " .. tostring(roundSummary.round)) or "")
            pushUi()
            task.wait(0.6)
            return
        end

        local now = os.clock()
        local moveSignature = "field::" .. fieldName
        if state.lastAutoRbcMoveTarget ~= moveSignature or (now - state.lastAutoRbcMoveAt) >= 2.5 then
            state.lastAutoRbcMoveTarget = moveSignature
            state.lastAutoRbcMoveAt = now
            tweenToFarmField(fieldName)
        else
            task.wait(0.25)
        end
        return
    end

    if isLiveRoboBearChallengeUiVisible() or isNpcDialogOpen() or isWaitingForChallengeInfo() or isRoboBearChallengePromptOpen() then
        task.wait(0.35)
        return
    end

    if not isStandingAtRoboBearCircle() then
        local now = os.clock()
        local moveSignature = "robo_bear_circle"
        if state.lastAutoRbcMoveTarget ~= moveSignature or (now - state.lastAutoRbcMoveAt) >= 2.5 then
            state.lastAutoRbcMoveTarget = moveSignature
            state.lastAutoRbcMoveAt = now
            tweenToRoboBearCircle()
        else
            task.wait(0.25)
        end
        return
    end

    state.detected.status = "Auto RBC ready at Robo Bear circle"
    pushUi()
    task.wait(0.45)
end

function runRoboBearInteractLoop()
    while isRuntimeActive() do
        state.roboLoopHeartbeat = os.clock()
        runProtectedLoopStep("Robo interaction", function()
            resetGuiCache()
            if state.autoRoboBearInteract then
                stepRoboBearInteract()
            else
                task.wait(0.4)
            end
        end)
    end
end

function runAutoRbcLoop()
    while isRuntimeActive() do
        state.autoRbcLoopHeartbeat = os.clock()
        runProtectedLoopStep("Auto RBC", function()
            resetGuiCache()
            if state.autoRbc then
                stepAutoRbc()
            else
                setCollectorInputHeld(false)
                setAutoRbcWalkSpeed(false)
                task.wait(0.4)
            end
        end)
    end
end

task.spawn(function()
    runAutoScanLoop()
end)

task.spawn(function()
    runRoboBearInteractLoop()
end)

task.spawn(function()
    runAutoRbcLoop()
end)

-- Executor threads can occasionally be cancelled by a game transition without
-- raising a Luau error. Restart a loop only after its heartbeat is stale long
-- enough that the previous task cannot still be doing normal movement work.
task.spawn(function()
    while isRuntimeActive() do
        task.wait(3)
        local now = os.clock()
        if state.autoScan and state.detectorLoopHeartbeat > 0
            and (now - state.detectorLoopHeartbeat) > 8 then
            state.detectorLoopHeartbeat = now
            task.spawn(runAutoScanLoop)
        end
        if state.autoRoboBearInteract and state.roboLoopHeartbeat > 0
            and (now - state.roboLoopHeartbeat) > 8 then
            state.roboLoopHeartbeat = now
            task.spawn(runRoboBearInteractLoop)
        end
        if state.autoRbc and state.autoRbcLoopHeartbeat > 0
            and (now - state.autoRbcLoopHeartbeat) > 30 then
            state.autoRbcLoopHeartbeat = now
            task.spawn(runAutoRbcLoop)
        end
    end
end)
