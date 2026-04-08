--[[
    ╔══════════════════════════════════════════════════════════════╗
    ║              SAMBUNG KATA - KBBI EDITION                    ║
    ║         Script by: Antigravity AI Assistant                 ║
    ║     Inject via Executor | Data dari GitHub (kbbi.txt)       ║
    ╚══════════════════════════════════════════════════════════════╝
    
    CARA PAKAI:
    1. Upload file kbbi.txt ke GitHub repository kamu
    2. Ganti URL_KBBI di bawah dengan raw link GitHub kamu
    3. Inject script ini via executor (Synapse, Fluxus, dll)
    4. Toggle on/off tingkat kesulitan sesuai keinginan
    5. Ketik huruf awal, script akan menampilkan kata lanjutan
    
    TINGKAT KESULITAN (berdasarkan huruf akhir kata):
    - Mudah   : akhiran a, i, u, e, o
    - Normal  : akhiran n, r, s, k, t, l
    - Sulit   : akhiran b, d, g, h, p, m
    - Ekstrim : akhiran v, w, x, y, z, j, c
--]]

------------------------------------------------------------
-- CONFIG
------------------------------------------------------------
local URL_KBBI = "https://raw.githubusercontent.com/zevilents/sambungkata/main/kbbi.txt"

local MAX_RESULTS = 50
local CHAIN_LENGTH = 2
local AUTOTYPE_ENABLED = true -- Set false untuk disable fitur auto-type

-- Speed modes untuk auto-typing
local SPEED_MODES = {
    { name = "Slow",   delay = 0.12, icon = "🐢", color = Color3.fromRGB(255, 152, 0) },
    { name = "Normal", delay = 0.05, icon = "🚶", color = Color3.fromRGB(33, 150, 243) },
    { name = "Cepat",  delay = 0.02, icon = "⚡", color = Color3.fromRGB(76, 175, 80) },
}
local currentSpeedIndex = 2 -- Default: Normal

------------------------------------------------------------
-- DIFFICULTY DEFINITIONS
------------------------------------------------------------
local DIFFICULTY = {
    Mudah = {
        letters = { ["a"] = true, ["i"] = true, ["u"] = true, ["e"] = true, ["o"] = true },
        color = Color3.fromRGB(76, 175, 80),
        icon = "🟢",
        shortDesc = "a i u e o"
    },
    Normal = {
        letters = { ["n"] = true, ["r"] = true, ["s"] = true, ["k"] = true, ["t"] = true, ["l"] = true },
        color = Color3.fromRGB(33, 150, 243),
        icon = "🔵",
        shortDesc = "n r s k t l"
    },
    Sulit = {
        letters = { ["b"] = true, ["d"] = true, ["g"] = true, ["h"] = true, ["p"] = true, ["m"] = true },
        color = Color3.fromRGB(255, 152, 0),
        icon = "🟠",
        shortDesc = "b d g h p m"
    },
    Ekstrim = {
        letters = { ["v"] = true, ["w"] = true, ["x"] = true, ["y"] = true, ["z"] = true, ["j"] = true, ["c"] = true },
        color = Color3.fromRGB(244, 67, 54),
        icon = "🔴",
        shortDesc = "v w x y z j c"
    }
}

local DIFFICULTY_ORDER = { "Mudah", "Normal", "Sulit", "Ekstrim" }

------------------------------------------------------------
-- SERVICES
------------------------------------------------------------
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

------------------------------------------------------------
-- CLEANUP
------------------------------------------------------------
local oldGui = playerGui:FindFirstChild("SambungKataGUI")
if oldGui then oldGui:Destroy() end

------------------------------------------------------------
-- DATA
------------------------------------------------------------
local allWords = {}
local wordsByDifficulty = {
    Mudah = {},
    Normal = {},
    Sulit = {},
    Ekstrim = {}
}

-- Toggle state: which difficulties are ON
local difficultyEnabled = {
    Mudah = true,
    Normal = true,
    Sulit = false,
    Ekstrim = false
}

local chainHistory = {}
local currentChainWord = nil
local score = 0
local isLoaded = false
local isChainMode = false
local isTyping = false         -- Apakah sedang auto-typing
local stopTyping = false       -- Flag untuk menghentikan typing
local lastTypedPrefix = ""     -- Prefix terakhir yang user ketik

------------------------------------------------------------
-- UTILITY
------------------------------------------------------------
local function getLastChar(word)
    return string.sub(word, -1):lower()
end

local function getLastChars(word, n)
    n = n or CHAIN_LENGTH
    if #word < n then return word:lower() end
    return string.sub(word, -n):lower()
end

local function getDifficultyOfWord(word)
    local lastChar = getLastChar(word)
    for _, diffName in ipairs(DIFFICULTY_ORDER) do
        if DIFFICULTY[diffName].letters[lastChar] then
            return diffName
        end
    end
    return nil
end

local function startsWith(word, prefix)
    return string.sub(word:lower(), 1, #prefix) == prefix:lower()
end

local function createTween(obj, props, duration, style, direction)
    return TweenService:Create(obj, TweenInfo.new(
        duration or 0.3,
        style or Enum.EasingStyle.Quart,
        direction or Enum.EasingDirection.Out
    ), props)
end

local function formatNumber(n)
    local s = tostring(n)
    local k
    while true do
        s, k = string.gsub(s, "^(-?%d+)(%d%d%d)", '%1.%2')
        if k == 0 then break end
    end
    return s
end

-- Build active word list from enabled difficulties
local function getActiveWords()
    local words = {}
    for _, diffName in ipairs(DIFFICULTY_ORDER) do
        if difficultyEnabled[diffName] then
            for _, w in ipairs(wordsByDifficulty[diffName]) do
                table.insert(words, w)
            end
        end
    end
    return words
end

local function getActiveWordCount()
    local count = 0
    for _, diffName in ipairs(DIFFICULTY_ORDER) do
        if difficultyEnabled[diffName] then
            count = count + #wordsByDifficulty[diffName]
        end
    end
    return count
end

------------------------------------------------------------
-- AUTOTYPE ENGINE (VirtualInputManager)
------------------------------------------------------------
-- Map karakter ke Enum.KeyCode
local CHAR_TO_KEYCODE = {
    a = Enum.KeyCode.A, b = Enum.KeyCode.B, c = Enum.KeyCode.C,
    d = Enum.KeyCode.D, e = Enum.KeyCode.E, f = Enum.KeyCode.F,
    g = Enum.KeyCode.G, h = Enum.KeyCode.H, i = Enum.KeyCode.I,
    j = Enum.KeyCode.J, k = Enum.KeyCode.K, l = Enum.KeyCode.L,
    m = Enum.KeyCode.M, n = Enum.KeyCode.N, o = Enum.KeyCode.O,
    p = Enum.KeyCode.P, q = Enum.KeyCode.Q, r = Enum.KeyCode.R,
    s = Enum.KeyCode.S, t = Enum.KeyCode.T, u = Enum.KeyCode.U,
    v = Enum.KeyCode.V, w = Enum.KeyCode.W, x = Enum.KeyCode.X,
    y = Enum.KeyCode.Y, z = Enum.KeyCode.Z
}

-- Forward declaration untuk UI status update (akan di-set nanti)
local updateTypingStatus = nil

local function simulateKeyPress(char)
    local keyCode = CHAR_TO_KEYCODE[char:lower()]
    if not keyCode then return end
    
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
        task.wait(0.01)
        VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
    end)
end

local function autoTypeText(text, prefix)
    if not AUTOTYPE_ENABLED then return end
    if isTyping then
        stopTyping = true
        task.wait(0.1)
    end
    
    -- Hitung sisa karakter yang perlu di-type
    -- prefix = yang sudah user ketik, text = kata lengkap
    local remaining = ""
    if #prefix > 0 and startsWith(text, prefix) then
        remaining = string.sub(text, #prefix + 1)
    else
        remaining = text
    end
    
    if #remaining == 0 then return end
    
    isTyping = true
    stopTyping = false
    
    if updateTypingStatus then
        updateTypingStatus(true, remaining, 0)
    end
    
    print("[SambungKata] Auto-typing: " .. remaining:upper() .. " (" .. #remaining .. " huruf)")
    
    task.spawn(function()
        for i = 1, #remaining do
            if stopTyping then
                print("[SambungKata] Typing dihentikan!")
                break
            end
            
            local char = string.sub(remaining, i, i)
            simulateKeyPress(char)
            
            if updateTypingStatus then
                updateTypingStatus(true, remaining, i)
            end
            
            task.wait(SPEED_MODES[currentSpeedIndex].delay)
        end
        
        -- Auto-ENTER setelah selesai typing
        if not stopTyping then
            task.wait(0.05)
            pcall(function()
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
                task.wait(0.01)
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
            end)
            print("[SambungKata] Auto-ENTER sent!")
        end
        
        isTyping = false
        stopTyping = false
        
        if updateTypingStatus then
            updateTypingStatus(false, "", 0)
        end
        
        print("[SambungKata] Selesai typing!")
    end)
end

------------------------------------------------------------
-- FETCH KBBI
------------------------------------------------------------
local function fetchKBBI()
    local success, result = pcall(function()
        if game.HttpGet then
            return game:HttpGet(URL_KBBI)
        else
            return HttpService:GetAsync(URL_KBBI)
        end
    end)

    if not success then
        warn("[SambungKata] Gagal fetch KBBI: " .. tostring(result))
        return false
    end

    local count = 0
    for line in result:gmatch("[^\r\n]+") do
        local word = line:match("^%s*(.-)%s*$")
        if word and #word > 0 then
            word = word:lower()
            if word:match("^[a-z]+$") then
                table.insert(allWords, word)
                local diff = getDifficultyOfWord(word)
                if diff and wordsByDifficulty[diff] then
                    table.insert(wordsByDifficulty[diff], word)
                end
                count = count + 1
            end
        end
    end

    print("[SambungKata] Berhasil memuat " .. formatNumber(count) .. " kata!")
    for _, d in ipairs(DIFFICULTY_ORDER) do
        print("  " .. d .. ": " .. formatNumber(#wordsByDifficulty[d]))
    end
    return true
end

------------------------------------------------------------
-- SEARCH
------------------------------------------------------------
local function searchWords(prefix, maxResults)
    maxResults = maxResults or MAX_RESULTS
    local results = {}
    prefix = prefix:lower()
    if #prefix == 0 then return results end

    -- Search through enabled difficulty lists
    for _, diffName in ipairs(DIFFICULTY_ORDER) do
        if difficultyEnabled[diffName] then
            for _, word in ipairs(wordsByDifficulty[diffName]) do
                if startsWith(word, prefix) then
                    -- Skip used words in chain mode
                    local skip = false
                    if isChainMode then
                        for _, used in ipairs(chainHistory) do
                            if used == word then skip = true; break end
                        end
                    end
                    if not skip then
                        table.insert(results, word)
                        if #results >= maxResults then return results end
                    end
                end
            end
        end
    end

    return results
end

------------------------------------------------------------
-- GUI
------------------------------------------------------------
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "SambungKataGUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = playerGui

-- ============ MAIN FRAME ============
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 500, 0, 620)
MainFrame.Position = UDim2.new(0.5, -250, 0.5, -310)
MainFrame.BackgroundColor3 = Color3.fromRGB(16, 16, 22)
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui

Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 14)

local MainStroke = Instance.new("UIStroke", MainFrame)
MainStroke.Color = Color3.fromRGB(50, 50, 75)
MainStroke.Thickness = 1

-- Gradient accent top bar
local AccentBar = Instance.new("Frame")
AccentBar.Size = UDim2.new(1, 0, 0, 3)
AccentBar.BorderSizePixel = 0
AccentBar.Parent = MainFrame

local AccentGrad = Instance.new("UIGradient", AccentBar)
AccentGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(76, 175, 80)),
    ColorSequenceKeypoint.new(0.33, Color3.fromRGB(33, 150, 243)),
    ColorSequenceKeypoint.new(0.66, Color3.fromRGB(255, 152, 0)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(244, 67, 54))
})

-- ============ TITLE BAR ============
local TitleBar = Instance.new("Frame")
TitleBar.Name = "TitleBar"
TitleBar.Size = UDim2.new(1, 0, 0, 44)
TitleBar.Position = UDim2.new(0, 0, 0, 3)
TitleBar.BackgroundTransparency = 1
TitleBar.Parent = MainFrame

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -90, 1, 0)
TitleLabel.Position = UDim2.new(0, 14, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "🔤 SAMBUNG KATA"
TitleLabel.TextColor3 = Color3.fromRGB(235, 235, 255)
TitleLabel.TextSize = 18
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = TitleBar

-- Close
local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 32, 0, 32)
CloseBtn.Position = UDim2.new(1, -40, 0, 6)
CloseBtn.BackgroundColor3 = Color3.fromRGB(244, 67, 54)
CloseBtn.BackgroundTransparency = 0.85
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = Color3.fromRGB(244, 67, 54)
CloseBtn.TextSize = 14
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.BorderSizePixel = 0
CloseBtn.Parent = TitleBar
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 8)

-- Minimize
local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 32, 0, 32)
MinBtn.Position = UDim2.new(1, -76, 0, 6)
MinBtn.BackgroundColor3 = Color3.fromRGB(255, 193, 7)
MinBtn.BackgroundTransparency = 0.85
MinBtn.Text = "—"
MinBtn.TextColor3 = Color3.fromRGB(255, 193, 7)
MinBtn.TextSize = 14
MinBtn.Font = Enum.Font.GothamBold
MinBtn.BorderSizePixel = 0
MinBtn.Parent = TitleBar
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0, 8)

-- Separator
local Sep = Instance.new("Frame")
Sep.Size = UDim2.new(1, -28, 0, 1)
Sep.Position = UDim2.new(0, 14, 0, 47)
Sep.BackgroundColor3 = Color3.fromRGB(36, 36, 52)
Sep.BorderSizePixel = 0
Sep.Parent = MainFrame

-- ============ CONTENT ============
local Content = Instance.new("Frame")
Content.Name = "Content"
Content.Size = UDim2.new(1, -28, 1, -54)
Content.Position = UDim2.new(0, 14, 0, 51)
Content.BackgroundTransparency = 1
Content.ClipsDescendants = true
Content.Parent = MainFrame

-- ============ LOADING PAGE ============
local LoadingPage = Instance.new("Frame")
LoadingPage.Name = "LoadingPage"
LoadingPage.Size = UDim2.new(1, 0, 1, 0)
LoadingPage.BackgroundTransparency = 1
LoadingPage.Parent = Content

local LdIcon = Instance.new("TextLabel")
LdIcon.Size = UDim2.new(1, 0, 0, 50)
LdIcon.Position = UDim2.new(0, 0, 0.35, -25)
LdIcon.BackgroundTransparency = 1
LdIcon.Text = "📚"
LdIcon.TextSize = 42
LdIcon.Font = Enum.Font.GothamBold
LdIcon.Parent = LoadingPage

local LdText = Instance.new("TextLabel")
LdText.Name = "LdText"
LdText.Size = UDim2.new(1, 0, 0, 24)
LdText.Position = UDim2.new(0, 0, 0.35, 30)
LdText.BackgroundTransparency = 1
LdText.Text = "Memuat kamus KBBI..."
LdText.TextColor3 = Color3.fromRGB(160, 160, 200)
LdText.TextSize = 15
LdText.Font = Enum.Font.Gotham
LdText.Parent = LoadingPage

local LdBarBg = Instance.new("Frame")
LdBarBg.Size = UDim2.new(0.55, 0, 0, 4)
LdBarBg.Position = UDim2.new(0.225, 0, 0.35, 65)
LdBarBg.BackgroundColor3 = Color3.fromRGB(36, 36, 52)
LdBarBg.BorderSizePixel = 0
LdBarBg.Parent = LoadingPage
Instance.new("UICorner", LdBarBg).CornerRadius = UDim.new(0, 2)

local LdBarFill = Instance.new("Frame")
LdBarFill.Size = UDim2.new(0, 0, 1, 0)
LdBarFill.BackgroundColor3 = Color3.fromRGB(76, 175, 80)
LdBarFill.BorderSizePixel = 0
LdBarFill.Parent = LdBarBg
Instance.new("UICorner", LdBarFill).CornerRadius = UDim.new(0, 2)

-- ============ GAME PAGE ============
local GamePage = Instance.new("Frame")
GamePage.Name = "GamePage"
GamePage.Size = UDim2.new(1, 0, 1, 0)
GamePage.BackgroundTransparency = 1
GamePage.Visible = false
GamePage.Parent = Content

-- ---- ROW 1: Mode toggle + Score ----
local ModeRow = Instance.new("Frame")
ModeRow.Size = UDim2.new(1, 0, 0, 34)
ModeRow.BackgroundTransparency = 1
ModeRow.Parent = GamePage

-- Mode: Search
local ModeSearchBtn = Instance.new("TextButton")
ModeSearchBtn.Name = "ModeSearch"
ModeSearchBtn.Size = UDim2.new(0, 130, 1, 0)
ModeSearchBtn.Position = UDim2.new(0, 0, 0, 0)
ModeSearchBtn.BackgroundColor3 = Color3.fromRGB(33, 150, 243)
ModeSearchBtn.BackgroundTransparency = 0.15
ModeSearchBtn.Text = "🔍 Cari Kata"
ModeSearchBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ModeSearchBtn.TextSize = 12
ModeSearchBtn.Font = Enum.Font.GothamBold
ModeSearchBtn.BorderSizePixel = 0
ModeSearchBtn.AutoButtonColor = false
ModeSearchBtn.Parent = ModeRow
Instance.new("UICorner", ModeSearchBtn).CornerRadius = UDim.new(0, 8)

-- Mode: Chain
local ModeChainBtn = Instance.new("TextButton")
ModeChainBtn.Name = "ModeChain"
ModeChainBtn.Size = UDim2.new(0, 148, 1, 0)
ModeChainBtn.Position = UDim2.new(0, 136, 0, 0)
ModeChainBtn.BackgroundColor3 = Color3.fromRGB(156, 39, 176)
ModeChainBtn.BackgroundTransparency = 0.7
ModeChainBtn.Text = "🔗 Sambung Kata"
ModeChainBtn.TextColor3 = Color3.fromRGB(200, 200, 240)
ModeChainBtn.TextSize = 12
ModeChainBtn.Font = Enum.Font.GothamBold
ModeChainBtn.BorderSizePixel = 0
ModeChainBtn.AutoButtonColor = false
ModeChainBtn.Parent = ModeRow
Instance.new("UICorner", ModeChainBtn).CornerRadius = UDim.new(0, 8)

-- Score label
local ScoreLabel = Instance.new("TextLabel")
ScoreLabel.Name = "ScoreLabel"
ScoreLabel.Size = UDim2.new(0, 100, 1, 0)
ScoreLabel.Position = UDim2.new(1, -100, 0, 0)
ScoreLabel.BackgroundColor3 = Color3.fromRGB(28, 28, 40)
ScoreLabel.Text = "Skor: 0"
ScoreLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
ScoreLabel.TextSize = 13
ScoreLabel.Font = Enum.Font.GothamBold
ScoreLabel.Visible = false
ScoreLabel.Parent = ModeRow
Instance.new("UICorner", ScoreLabel).CornerRadius = UDim.new(0, 8)

-- ---- ROW 2: Difficulty toggles ----
local DiffRow = Instance.new("Frame")
DiffRow.Size = UDim2.new(1, 0, 0, 34)
DiffRow.Position = UDim2.new(0, 0, 0, 40)
DiffRow.BackgroundTransparency = 1
DiffRow.Parent = GamePage

local toggleButtons = {}
local toggleXOffset = 0

for i, diffName in ipairs(DIFFICULTY_ORDER) do
    local diff = DIFFICULTY[diffName]
    local isOn = difficultyEnabled[diffName]

    -- Calculate width based on text
    local labelText = diff.icon .. " " .. diffName
    local btnWidth = #labelText * 7 + 30 -- approximate

    local toggle = Instance.new("TextButton")
    toggle.Name = "Toggle_" .. diffName
    toggle.Size = UDim2.new(0, btnWidth, 1, 0)
    toggle.Position = UDim2.new(0, toggleXOffset, 0, 0)
    toggle.BackgroundColor3 = diff.color
    toggle.BackgroundTransparency = isOn and 0.2 or 0.85
    toggle.Text = labelText
    toggle.TextColor3 = isOn and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(120, 120, 150)
    toggle.TextSize = 11
    toggle.Font = Enum.Font.GothamBold
    toggle.BorderSizePixel = 0
    toggle.AutoButtonColor = false
    toggle.Parent = DiffRow
    Instance.new("UICorner", toggle).CornerRadius = UDim.new(0, 8)

    local stroke = Instance.new("UIStroke", toggle)
    stroke.Color = diff.color
    stroke.Transparency = isOn and 0.3 or 0.8
    stroke.Thickness = 1

    toggleButtons[diffName] = { button = toggle, stroke = stroke }
    toggleXOffset = toggleXOffset + btnWidth + 6
end

-- Word count indicator
local WordCountLabel = Instance.new("TextLabel")
WordCountLabel.Name = "WordCount"
WordCountLabel.Size = UDim2.new(0, 80, 1, 0)
WordCountLabel.Position = UDim2.new(1, -80, 0, 0)
WordCountLabel.BackgroundTransparency = 1
WordCountLabel.Text = "0 kata"
WordCountLabel.TextColor3 = Color3.fromRGB(90, 90, 130)
WordCountLabel.TextSize = 10
WordCountLabel.Font = Enum.Font.Gotham
WordCountLabel.TextXAlignment = Enum.TextXAlignment.Right
WordCountLabel.Parent = DiffRow

-- ---- ROW 2.5: Speed toggle buttons ----
local SpeedRow = Instance.new("Frame")
SpeedRow.Size = UDim2.new(1, 0, 0, 28)
SpeedRow.Position = UDim2.new(0, 0, 0, 78)
SpeedRow.BackgroundTransparency = 1
SpeedRow.Parent = GamePage

local SpeedLabel = Instance.new("TextLabel")
SpeedLabel.Size = UDim2.new(0, 52, 1, 0)
SpeedLabel.Position = UDim2.new(0, 0, 0, 0)
SpeedLabel.BackgroundTransparency = 1
SpeedLabel.Text = "⌨ Speed:"
SpeedLabel.TextColor3 = Color3.fromRGB(90, 90, 130)
SpeedLabel.TextSize = 10
SpeedLabel.Font = Enum.Font.GothamBold
SpeedLabel.TextXAlignment = Enum.TextXAlignment.Left
SpeedLabel.Parent = SpeedRow

local speedButtons = {}
local speedXOffset = 56

for i, mode in ipairs(SPEED_MODES) do
    local isActive = (i == currentSpeedIndex)
    local labelText = mode.icon .. " " .. mode.name
    local btnW = 72

    local sBtn = Instance.new("TextButton")
    sBtn.Name = "Speed_" .. mode.name
    sBtn.Size = UDim2.new(0, btnW, 1, 0)
    sBtn.Position = UDim2.new(0, speedXOffset, 0, 0)
    sBtn.BackgroundColor3 = mode.color
    sBtn.BackgroundTransparency = isActive and 0.2 or 0.85
    sBtn.Text = labelText
    sBtn.TextColor3 = isActive and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(100, 100, 140)
    sBtn.TextSize = 10
    sBtn.Font = Enum.Font.GothamBold
    sBtn.BorderSizePixel = 0
    sBtn.AutoButtonColor = false
    sBtn.Parent = SpeedRow
    Instance.new("UICorner", sBtn).CornerRadius = UDim.new(0, 7)

    local sStroke = Instance.new("UIStroke", sBtn)
    sStroke.Color = mode.color
    sStroke.Transparency = isActive and 0.3 or 0.85
    sStroke.Thickness = 1

    speedButtons[i] = { button = sBtn, stroke = sStroke }
    speedXOffset = speedXOffset + btnW + 5
end

-- Auto-enter indicator
local AutoEnterLabel = Instance.new("TextLabel")
AutoEnterLabel.Size = UDim2.new(0, 75, 1, 0)
AutoEnterLabel.Position = UDim2.new(1, -75, 0, 0)
AutoEnterLabel.BackgroundTransparency = 1
AutoEnterLabel.Text = "↵ Auto-Enter"
AutoEnterLabel.TextColor3 = Color3.fromRGB(76, 175, 80)
AutoEnterLabel.TextSize = 9
AutoEnterLabel.Font = Enum.Font.GothamBold
AutoEnterLabel.TextXAlignment = Enum.TextXAlignment.Right
AutoEnterLabel.Parent = SpeedRow

local function updateSpeedVisuals()
    for i, data in ipairs(speedButtons) do
        local isActive = (i == currentSpeedIndex)
        local mode = SPEED_MODES[i]
        createTween(data.button, {
            BackgroundTransparency = isActive and 0.2 or 0.85,
            TextColor3 = isActive and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(100, 100, 140)
        }, 0.15):Play()
        createTween(data.stroke, {
            Transparency = isActive and 0.3 or 0.85
        }, 0.15):Play()
    end
end

for i, data in ipairs(speedButtons) do
    data.button.MouseButton1Click:Connect(function()
        currentSpeedIndex = i
        updateSpeedVisuals()
        print("[SambungKata] Speed: " .. SPEED_MODES[i].name .. " (" .. SPEED_MODES[i].delay .. "s)")
    end)
    data.button.MouseEnter:Connect(function()
        if i ~= currentSpeedIndex then
            createTween(data.button, {BackgroundTransparency = 0.55}, 0.1):Play()
        end
    end)
    data.button.MouseLeave:Connect(function()
        if i ~= currentSpeedIndex then
            createTween(data.button, {BackgroundTransparency = 0.85}, 0.1):Play()
        end
    end)
end

-- ---- ROW 3: Chain info (only visible in chain mode) ----
local ChainInfo = Instance.new("Frame")
ChainInfo.Name = "ChainInfo"
ChainInfo.Size = UDim2.new(1, 0, 0, 50)
ChainInfo.Position = UDim2.new(0, 0, 0, 110)
ChainInfo.BackgroundColor3 = Color3.fromRGB(25, 25, 38)
ChainInfo.BorderSizePixel = 0
ChainInfo.Visible = false
ChainInfo.Parent = GamePage
Instance.new("UICorner", ChainInfo).CornerRadius = UDim.new(0, 10)

local ChainStroke = Instance.new("UIStroke", ChainInfo)
ChainStroke.Color = Color3.fromRGB(156, 39, 176)
ChainStroke.Transparency = 0.6
ChainStroke.Thickness = 1

local ChainWordLabel = Instance.new("TextLabel")
ChainWordLabel.Size = UDim2.new(1, -16, 0, 22)
ChainWordLabel.Position = UDim2.new(0, 8, 0, 4)
ChainWordLabel.BackgroundTransparency = 1
ChainWordLabel.Text = "Kata: -"
ChainWordLabel.TextColor3 = Color3.fromRGB(220, 220, 255)
ChainWordLabel.TextSize = 14
ChainWordLabel.Font = Enum.Font.GothamBold
ChainWordLabel.TextXAlignment = Enum.TextXAlignment.Left
ChainWordLabel.Parent = ChainInfo

local ChainHintLabel = Instance.new("TextLabel")
ChainHintLabel.Size = UDim2.new(1, -16, 0, 18)
ChainHintLabel.Position = UDim2.new(0, 8, 0, 27)
ChainHintLabel.BackgroundTransparency = 1
ChainHintLabel.Text = ""
ChainHintLabel.TextColor3 = Color3.fromRGB(120, 120, 160)
ChainHintLabel.TextSize = 11
ChainHintLabel.Font = Enum.Font.Gotham
ChainHintLabel.TextXAlignment = Enum.TextXAlignment.Left
ChainHintLabel.Parent = ChainInfo

-- New Chain button
local NewChainBtn = Instance.new("TextButton")
NewChainBtn.Size = UDim2.new(0, 24, 0, 24)
NewChainBtn.Position = UDim2.new(1, -32, 0, 13)
NewChainBtn.BackgroundColor3 = Color3.fromRGB(156, 39, 176)
NewChainBtn.BackgroundTransparency = 0.6
NewChainBtn.Text = "↻"
NewChainBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
NewChainBtn.TextSize = 14
NewChainBtn.Font = Enum.Font.GothamBold
NewChainBtn.BorderSizePixel = 0
NewChainBtn.Parent = ChainInfo
Instance.new("UICorner", NewChainBtn).CornerRadius = UDim.new(0, 6)

-- ---- ROW 4: Search bar ----
-- Position will be adjusted dynamically based on chain mode
local SearchFrame = Instance.new("Frame")
SearchFrame.Name = "SearchFrame"
SearchFrame.Size = UDim2.new(1, 0, 0, 40)
SearchFrame.Position = UDim2.new(0, 0, 0, 110)
SearchFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 38)
SearchFrame.BorderSizePixel = 0
SearchFrame.Parent = GamePage
Instance.new("UICorner", SearchFrame).CornerRadius = UDim.new(0, 10)

local SearchStroke = Instance.new("UIStroke", SearchFrame)
SearchStroke.Color = Color3.fromRGB(50, 50, 75)
SearchStroke.Thickness = 1

local SearchIcon = Instance.new("TextLabel")
SearchIcon.Size = UDim2.new(0, 28, 1, 0)
SearchIcon.Position = UDim2.new(0, 8, 0, 0)
SearchIcon.BackgroundTransparency = 1
SearchIcon.Text = "🔍"
SearchIcon.TextSize = 14
SearchIcon.Font = Enum.Font.Gotham
SearchIcon.Parent = SearchFrame

local SearchInput = Instance.new("TextBox")
SearchInput.Name = "SearchInput"
SearchInput.Size = UDim2.new(1, -80, 1, -8)
SearchInput.Position = UDim2.new(0, 38, 0, 4)
SearchInput.BackgroundTransparency = 1
SearchInput.Text = ""
SearchInput.PlaceholderText = "Ketik huruf awal kata..."
SearchInput.PlaceholderColor3 = Color3.fromRGB(70, 70, 110)
SearchInput.TextColor3 = Color3.fromRGB(220, 220, 255)
SearchInput.TextSize = 14
SearchInput.Font = Enum.Font.Gotham
SearchInput.TextXAlignment = Enum.TextXAlignment.Left
SearchInput.ClearTextOnFocus = false
SearchInput.Parent = SearchFrame

local ResultCount = Instance.new("TextLabel")
ResultCount.Size = UDim2.new(0, 36, 1, 0)
ResultCount.Position = UDim2.new(1, -42, 0, 0)
ResultCount.BackgroundTransparency = 1
ResultCount.Text = ""
ResultCount.TextColor3 = Color3.fromRGB(90, 90, 130)
ResultCount.TextSize = 11
ResultCount.Font = Enum.Font.Gotham
ResultCount.Parent = SearchFrame

-- ---- Typing Status Bar ----
local TypingBar = Instance.new("Frame")
TypingBar.Name = "TypingBar"
TypingBar.Size = UDim2.new(1, 0, 0, 30)
TypingBar.Position = UDim2.new(0, 0, 0, 122)
TypingBar.BackgroundColor3 = Color3.fromRGB(20, 35, 20)
TypingBar.BorderSizePixel = 0
TypingBar.Visible = false
TypingBar.Parent = GamePage
Instance.new("UICorner", TypingBar).CornerRadius = UDim.new(0, 8)

local TypingStroke = Instance.new("UIStroke", TypingBar)
TypingStroke.Color = Color3.fromRGB(76, 175, 80)
TypingStroke.Transparency = 0.5
TypingStroke.Thickness = 1

local TypingLabel = Instance.new("TextLabel")
TypingLabel.Name = "TypingLabel"
TypingLabel.Size = UDim2.new(1, -80, 1, 0)
TypingLabel.Position = UDim2.new(0, 10, 0, 0)
TypingLabel.BackgroundTransparency = 1
TypingLabel.Text = "⌨ Typing..."
TypingLabel.TextColor3 = Color3.fromRGB(76, 175, 80)
TypingLabel.TextSize = 11
TypingLabel.Font = Enum.Font.GothamBold
TypingLabel.TextXAlignment = Enum.TextXAlignment.Left
TypingLabel.Parent = TypingBar

local TypingProgress = Instance.new("TextLabel")
TypingProgress.Name = "TypingProgress"
TypingProgress.Size = UDim2.new(0, 36, 1, 0)
TypingProgress.Position = UDim2.new(1, -76, 0, 0)
TypingProgress.BackgroundTransparency = 1
TypingProgress.Text = "0/0"
TypingProgress.TextColor3 = Color3.fromRGB(76, 175, 80)
TypingProgress.TextSize = 10
TypingProgress.Font = Enum.Font.Gotham
TypingProgress.TextXAlignment = Enum.TextXAlignment.Right
TypingProgress.Parent = TypingBar

local StopTypingBtn = Instance.new("TextButton")
StopTypingBtn.Name = "StopTyping"
StopTypingBtn.Size = UDim2.new(0, 28, 0, 22)
StopTypingBtn.Position = UDim2.new(1, -34, 0, 4)
StopTypingBtn.BackgroundColor3 = Color3.fromRGB(244, 67, 54)
StopTypingBtn.BackgroundTransparency = 0.5
StopTypingBtn.Text = "■"
StopTypingBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
StopTypingBtn.TextSize = 10
StopTypingBtn.Font = Enum.Font.GothamBold
StopTypingBtn.BorderSizePixel = 0
StopTypingBtn.Parent = TypingBar
Instance.new("UICorner", StopTypingBtn).CornerRadius = UDim.new(0, 6)

StopTypingBtn.MouseButton1Click:Connect(function()
    stopTyping = true
end)

-- Implement the updateTypingStatus function
updateTypingStatus = function(active, text, progress)
    if active then
        TypingBar.Visible = true
        local typed = string.sub(text, 1, progress)
        local remaining = string.sub(text, progress + 1)
        TypingLabel.Text = "⌨ Typing: " .. typed:upper() .. "|" .. remaining:upper()
        TypingProgress.Text = progress .. "/" .. #text
    else
        TypingBar.Visible = false
    end
end

-- ---- ROW 5: Results ----
local ResultsFrame = Instance.new("ScrollingFrame")
ResultsFrame.Name = "Results"
ResultsFrame.Size = UDim2.new(1, 0, 1, -126)
ResultsFrame.Position = UDim2.new(0, 0, 0, 124)
ResultsFrame.BackgroundTransparency = 1
ResultsFrame.BorderSizePixel = 0
ResultsFrame.ScrollBarThickness = 3
ResultsFrame.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 90)
ResultsFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
ResultsFrame.Parent = GamePage

local ResultsLayout = Instance.new("UIListLayout")
ResultsLayout.SortOrder = Enum.SortOrder.LayoutOrder
ResultsLayout.Padding = UDim.new(0, 3)
ResultsLayout.Parent = ResultsFrame

local EmptyLabel = Instance.new("TextLabel")
EmptyLabel.Name = "EmptyLabel"
EmptyLabel.Size = UDim2.new(1, 0, 0, 80)
EmptyLabel.BackgroundTransparency = 1
EmptyLabel.Text = "Ketik huruf untuk mencari kata..."
EmptyLabel.TextColor3 = Color3.fromRGB(70, 70, 110)
EmptyLabel.TextSize = 13
EmptyLabel.Font = Enum.Font.Gotham
EmptyLabel.Parent = ResultsFrame

------------------------------------------------------------
-- LAYOUT HELPERS
------------------------------------------------------------
local function updateLayout()
    if isChainMode then
        ChainInfo.Visible = true
        ScoreLabel.Visible = true
        ChainInfo.Position = UDim2.new(0, 0, 0, 110)
        SearchFrame.Position = UDim2.new(0, 0, 0, 166)
        TypingBar.Position = UDim2.new(0, 0, 0, 210)
        ResultsFrame.Position = UDim2.new(0, 0, 0, 212)
        ResultsFrame.Size = UDim2.new(1, 0, 1, -214)
    else
        ChainInfo.Visible = false
        ScoreLabel.Visible = false
        SearchFrame.Position = UDim2.new(0, 0, 0, 110)
        TypingBar.Position = UDim2.new(0, 0, 0, 154)
        ResultsFrame.Position = UDim2.new(0, 0, 0, 156)
        ResultsFrame.Size = UDim2.new(1, 0, 1, -158)
    end
end

local function updateWordCount()
    WordCountLabel.Text = formatNumber(getActiveWordCount()) .. " kata"
end

local function updateToggleVisuals()
    for diffName, data in pairs(toggleButtons) do
        local isOn = difficultyEnabled[diffName]
        local diff = DIFFICULTY[diffName]
        createTween(data.button, {
            BackgroundTransparency = isOn and 0.2 or 0.85,
            TextColor3 = isOn and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(100, 100, 140)
        }, 0.2):Play()
        createTween(data.stroke, {
            Transparency = isOn and 0.3 or 0.85
        }, 0.2):Play()
    end
    updateWordCount()
end

local function updateModeVisuals()
    if isChainMode then
        createTween(ModeSearchBtn, {BackgroundTransparency = 0.75, TextColor3 = Color3.fromRGB(150, 150, 190)}, 0.2):Play()
        createTween(ModeChainBtn, {BackgroundTransparency = 0.15, TextColor3 = Color3.fromRGB(255, 255, 255)}, 0.2):Play()
    else
        createTween(ModeSearchBtn, {BackgroundTransparency = 0.15, TextColor3 = Color3.fromRGB(255, 255, 255)}, 0.2):Play()
        createTween(ModeChainBtn, {BackgroundTransparency = 0.75, TextColor3 = Color3.fromRGB(150, 150, 190)}, 0.2):Play()
    end
end

------------------------------------------------------------
-- RESULTS DISPLAY
------------------------------------------------------------
local function clearResults()
    for _, child in ipairs(ResultsFrame:GetChildren()) do
        if child:IsA("TextButton") or (child:IsA("Frame") and child.Name ~= "EmptyLabel") then
            child:Destroy()
        end
    end
end

local function createWordItem(word, index)
    local diff = getDifficultyOfWord(word)
    local diffData = diff and DIFFICULTY[diff]
    local color = diffData and diffData.color or Color3.fromRGB(120, 120, 160)
    
    -- Hitung prefix & remaining untuk display
    local currentPrefix = SearchInput.Text:lower():gsub("%s+", "")
    local remainingText = ""
    if #currentPrefix > 0 and startsWith(word, currentPrefix) then
        remainingText = string.sub(word, #currentPrefix + 1)
    end

    local btn = Instance.new("TextButton")
    btn.Name = "W" .. index
    btn.Size = UDim2.new(1, 0, 0, 36)
    btn.BackgroundColor3 = Color3.fromRGB(22, 22, 34)
    btn.BorderSizePixel = 0
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.LayoutOrder = index
    btn.Parent = ResultsFrame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

    -- Left color bar
    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(0, 3, 0.5, 0)
    bar.Position = UDim2.new(0, 7, 0.25, 0)
    bar.BackgroundColor3 = color
    bar.BorderSizePixel = 0
    bar.Parent = btn
    Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 2)

    -- Word label: prefix (dimmed) + remaining (bright)
    -- Show the prefix part dimmer and the remaining part bright to hint what will be auto-typed
    local prefixPart = string.sub(word, 1, #currentPrefix):upper()
    local remainPart = string.sub(word, #currentPrefix + 1):upper()
    
    local wlPrefix = Instance.new("TextLabel")
    wlPrefix.Size = UDim2.new(0, #prefixPart * 8 + 2, 1, 0)
    wlPrefix.Position = UDim2.new(0, 18, 0, 0)
    wlPrefix.BackgroundTransparency = 1
    wlPrefix.Text = prefixPart
    wlPrefix.TextColor3 = Color3.fromRGB(100, 100, 150)
    wlPrefix.TextSize = 13
    wlPrefix.Font = Enum.Font.GothamBold
    wlPrefix.TextXAlignment = Enum.TextXAlignment.Left
    wlPrefix.Parent = btn
    
    local wlRemain = Instance.new("TextLabel")
    wlRemain.Size = UDim2.new(0.45, 0, 1, 0)
    wlRemain.Position = UDim2.new(0, 18 + #prefixPart * 8 + 2, 0, 0)
    wlRemain.BackgroundTransparency = 1
    wlRemain.Text = remainPart
    wlRemain.TextColor3 = Color3.fromRGB(120, 255, 160)
    wlRemain.TextSize = 13
    wlRemain.Font = Enum.Font.GothamBold
    wlRemain.TextXAlignment = Enum.TextXAlignment.Left
    wlRemain.Parent = btn

    -- Auto-type icon indicator
    local typeIcon = Instance.new("TextLabel")
    typeIcon.Size = UDim2.new(0, 20, 0, 20)
    typeIcon.Position = UDim2.new(1, -170, 0, 8)
    typeIcon.BackgroundTransparency = 1
    typeIcon.Text = "⌨"
    typeIcon.TextColor3 = Color3.fromRGB(76, 175, 80)
    typeIcon.TextSize = 12
    typeIcon.Font = Enum.Font.Gotham
    typeIcon.Parent = btn

    -- Difficulty badge
    local badge = Instance.new("TextLabel")
    badge.Size = UDim2.new(0, 60, 0, 20)
    badge.Position = UDim2.new(1, -148, 0, 8)
    badge.BackgroundColor3 = color
    badge.BackgroundTransparency = 0.85
    badge.Text = diff or "?"
    badge.TextColor3 = color
    badge.TextSize = 9
    badge.Font = Enum.Font.GothamBold
    badge.Parent = btn
    Instance.new("UICorner", badge).CornerRadius = UDim.new(0, 5)

    -- Length
    local ll = Instance.new("TextLabel")
    ll.Size = UDim2.new(0, 80, 0, 20)
    ll.Position = UDim2.new(1, -82, 0, 8)
    ll.BackgroundTransparency = 1
    ll.Text = #word .. "h | +" .. #remainingText .. " type"
    ll.TextColor3 = Color3.fromRGB(75, 75, 115)
    ll.TextSize = 9
    ll.Font = Enum.Font.Gotham
    ll.TextXAlignment = Enum.TextXAlignment.Right
    ll.Parent = btn

    -- Hover
    btn.MouseEnter:Connect(function()
        createTween(btn, {BackgroundColor3 = Color3.fromRGB(28, 38, 32)}, 0.12):Play()
        createTween(typeIcon, {TextTransparency = 0}, 0.1):Play()
    end)
    btn.MouseLeave:Connect(function()
        createTween(btn, {BackgroundColor3 = Color3.fromRGB(22, 22, 34)}, 0.12):Play()
    end)

    -- Click handler: Auto-type the remaining characters
    btn.MouseButton1Click:Connect(function()
        local prefix = SearchInput.Text:lower():gsub("%s+", "")
        lastTypedPrefix = prefix
        
        -- Flash effect
        createTween(btn, {BackgroundColor3 = Color3.fromRGB(76, 175, 80)}, 0.08):Play()
        task.delay(0.15, function()
            createTween(btn, {BackgroundColor3 = Color3.fromRGB(22, 22, 34)}, 0.2):Play()
        end)
        
        -- Chain mode: update chain state
        if isChainMode then
            table.insert(chainHistory, word)
            currentChainWord = word
            score = score + #word
            ScoreLabel.Text = "Skor: " .. score
            
            local lastC = getLastChars(word, CHAIN_LENGTH)
            ChainWordLabel.Text = "🔗 " .. word:upper() .. "  ➜  sambung: " .. lastC:upper() .. "..."
            ChainHintLabel.Text = "Riwayat: " .. #chainHistory .. " kata | kata berawalan \"" .. lastC:upper() .. "\""
        end
        
        -- Release focus dari SearchInput supaya keypress masuk ke chat/game
        SearchInput:ReleaseFocus()
        
        -- Tunggu sebentar lalu mulai auto-type
        task.delay(0.15, function()
            autoTypeText(word, prefix)
        end)
    end)

    -- Animate in
    btn.BackgroundTransparency = 1
    wlPrefix.TextTransparency = 1
    wlRemain.TextTransparency = 1
    task.delay(index * 0.015, function()
        createTween(btn, {BackgroundTransparency = 0}, 0.15):Play()
        createTween(wlPrefix, {TextTransparency = 0}, 0.15):Play()
        createTween(wlRemain, {TextTransparency = 0}, 0.15):Play()
    end)

    return btn
end

local function displayResults(results)
    clearResults()

    if #results == 0 then
        EmptyLabel.Visible = true
        EmptyLabel.Text = "Tidak ada kata ditemukan..."
        ResultCount.Text = "0"
        ResultsFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
        return
    end

    EmptyLabel.Visible = false
    ResultCount.Text = tostring(#results)

    for i, word in ipairs(results) do
        createWordItem(word, i)
    end

    task.delay(0.1, function()
        ResultsFrame.CanvasSize = UDim2.new(0, 0, 0, ResultsLayout.AbsoluteContentSize.Y + 8)
    end)
end

------------------------------------------------------------
-- CHAIN HELPERS
------------------------------------------------------------
local function startNewChain()
    chainHistory = {}
    score = 0
    ScoreLabel.Text = "Skor: 0"

    local activeWords = getActiveWords()
    if #activeWords == 0 then
        ChainWordLabel.Text = "⚠ Tidak ada kata! Aktifkan minimal 1 kesulitan"
        ChainHintLabel.Text = ""
        return
    end

    local startWord = activeWords[math.random(1, #activeWords)]
    currentChainWord = startWord
    table.insert(chainHistory, startWord)
    score = score + #startWord
    ScoreLabel.Text = "Skor: " .. score

    local lastC = getLastChars(startWord, CHAIN_LENGTH)
    ChainWordLabel.Text = "🔗 Mulai: " .. startWord:upper() .. "  ➜  sambung: " .. lastC:upper() .. "..."
    ChainHintLabel.Text = "Ketik kata berawalan \"" .. lastC:upper() .. "\""

    SearchInput.Text = lastC
    clearResults()
    EmptyLabel.Visible = true
    EmptyLabel.Text = "Cari & klik kata untuk menyambung!"

    task.delay(0.1, function()
        SearchInput:CaptureFocus()
    end)
end

------------------------------------------------------------
-- DRAGGING
------------------------------------------------------------
local dragging, dragStart, startPos = false, nil, nil

TitleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
    end
end)
TitleBar.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
end)

------------------------------------------------------------
-- EVENT CONNECTIONS
------------------------------------------------------------

-- Difficulty toggles
for _, diffName in ipairs(DIFFICULTY_ORDER) do
    local data = toggleButtons[diffName]
    data.button.MouseButton1Click:Connect(function()
        difficultyEnabled[diffName] = not difficultyEnabled[diffName]
        updateToggleVisuals()

        -- Re-trigger search with current text
        local text = SearchInput.Text:lower():gsub("%s+", "")
        if #text >= 1 then
            local results = searchWords(text, MAX_RESULTS)
            displayResults(results)
        end
    end)

    -- Hover
    data.button.MouseEnter:Connect(function()
        if not difficultyEnabled[diffName] then
            createTween(data.button, {BackgroundTransparency = 0.6}, 0.12):Play()
        end
    end)
    data.button.MouseLeave:Connect(function()
        if not difficultyEnabled[diffName] then
            createTween(data.button, {BackgroundTransparency = 0.85}, 0.12):Play()
        end
    end)
end

-- Mode buttons
ModeSearchBtn.MouseButton1Click:Connect(function()
    if not isChainMode then return end
    isChainMode = false
    updateModeVisuals()
    updateLayout()
    SearchInput.Text = ""
    SearchInput.PlaceholderText = "Ketik huruf awal kata..."
    clearResults()
    EmptyLabel.Visible = true
    EmptyLabel.Text = "Ketik huruf untuk mencari kata..."
end)

ModeChainBtn.MouseButton1Click:Connect(function()
    if isChainMode then return end
    isChainMode = true
    updateModeVisuals()
    updateLayout()
    startNewChain()
end)

-- New chain button
NewChainBtn.MouseButton1Click:Connect(function()
    startNewChain()
end)

NewChainBtn.MouseEnter:Connect(function()
    createTween(NewChainBtn, {BackgroundTransparency = 0.3}, 0.12):Play()
end)
NewChainBtn.MouseLeave:Connect(function()
    createTween(NewChainBtn, {BackgroundTransparency = 0.6}, 0.12):Play()
end)

-- Search input
local searchDebounce = false
SearchInput:GetPropertyChangedSignal("Text"):Connect(function()
    if searchDebounce then return end
    if isTyping then return end -- jangan re-search saat sedang auto-typing
    searchDebounce = true
    task.delay(0.12, function()
        searchDebounce = false
        local text = SearchInput.Text:lower():gsub("%s+", "")
        lastTypedPrefix = text -- simpan prefix terakhir
        if #text < 1 then
            clearResults()
            EmptyLabel.Visible = true
            EmptyLabel.Text = isChainMode and "Cari & klik kata untuk menyambung!" or "Ketik huruf untuk mencari kata..."
            ResultCount.Text = ""
            return
        end
        local results = searchWords(text, MAX_RESULTS)
        displayResults(results)
    end)
end)

-- Close
CloseBtn.MouseButton1Click:Connect(function()
    createTween(MainFrame, {Size = UDim2.new(0, 500, 0, 0)}, 0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In):Play()
    task.delay(0.25, function() ScreenGui:Destroy() end)
end)

-- Minimize
local isMinimized = false
local savedSize = MainFrame.Size
MinBtn.MouseButton1Click:Connect(function()
    if isMinimized then
        createTween(MainFrame, {Size = savedSize}, 0.25):Play()
        isMinimized = false
    else
        savedSize = MainFrame.Size
        createTween(MainFrame, {Size = UDim2.new(0, 500, 0, 50)}, 0.25):Play()
        isMinimized = true
    end
end)

-- Hover effects for close/min
for _, b in ipairs({CloseBtn, MinBtn}) do
    b.MouseEnter:Connect(function() createTween(b, {BackgroundTransparency = 0.5}, 0.12):Play() end)
    b.MouseLeave:Connect(function() createTween(b, {BackgroundTransparency = 0.85}, 0.12):Play() end)
end

-- Toggle visibility: Right Shift
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        MainFrame.Visible = not MainFrame.Visible
    end
end)

------------------------------------------------------------
-- INIT
------------------------------------------------------------
LoadingPage.Visible = true
GamePage.Visible = false

-- Open animation
MainFrame.Size = UDim2.new(0, 500, 0, 0)
MainFrame.BackgroundTransparency = 0.5
createTween(MainFrame, {Size = UDim2.new(0, 500, 0, 620)}, 0.35, Enum.EasingStyle.Back):Play()
createTween(MainFrame, {BackgroundTransparency = 0}, 0.25):Play()

task.spawn(function()
    createTween(LdBarFill, {Size = UDim2.new(0.65, 0, 1, 0)}, 1.5, Enum.EasingStyle.Linear):Play()
end)

task.spawn(function()
    task.wait(0.4)
    LdText.Text = "Mengunduh kamus KBBI..."

    local ok = fetchKBBI()

    if ok then
        createTween(LdBarFill, {Size = UDim2.new(1, 0, 1, 0)}, 0.25):Play()
        LdBarFill.BackgroundColor3 = Color3.fromRGB(76, 175, 80)
        LdText.Text = "✅ " .. formatNumber(#allWords) .. " kata dimuat!"
        isLoaded = true

        task.wait(0.8)
        LoadingPage.Visible = false
        GamePage.Visible = true
        updateToggleVisuals()
        updateModeVisuals()
        updateLayout()
        updateWordCount()
    else
        createTween(LdBarFill, {Size = UDim2.new(1, 0, 1, 0)}, 0.25):Play()
        LdBarFill.BackgroundColor3 = Color3.fromRGB(244, 67, 54)
        LdText.Text = "❌ Gagal! Cek URL GitHub kamu"
    end
end)

print("═══════════════════════════════════════════")
print("  🔤 SAMBUNG KATA - KBBI Edition")
print("  Right Shift = Show/Hide")
print("═══════════════════════════════════════════")
