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
    4. Pilih tingkat kesulitan
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
-- GANTI URL INI DENGAN RAW LINK GITHUB KAMU!
-- Contoh: "https://raw.githubusercontent.com/username/repo/main/kbbi.txt"
local URL_KBBI = "https://raw.githubusercontent.com/zevilents/sambungkata/main/kbbi.txt"

local MAX_RESULTS = 50        -- Maksimal kata yang ditampilkan per pencarian
local CHAIN_LENGTH = 2        -- Jumlah huruf akhir yang dipakai untuk sambung kata (2 huruf terakhir)

------------------------------------------------------------
-- DIFFICULTY DEFINITIONS
------------------------------------------------------------
local DIFFICULTY = {
    Mudah = {
        letters = { ["a"] = true, ["i"] = true, ["u"] = true, ["e"] = true, ["o"] = true },
        color = Color3.fromRGB(76, 175, 80),     -- Hijau
        icon = "🟢",
        desc = "Akhiran vokal (a, i, u, e, o)"
    },
    Normal = {
        letters = { ["n"] = true, ["r"] = true, ["s"] = true, ["k"] = true, ["t"] = true, ["l"] = true },
        color = Color3.fromRGB(33, 150, 243),     -- Biru
        icon = "🔵",
        desc = "Akhiran konsonan umum (n, r, s, k, t, l)"
    },
    Sulit = {
        letters = { ["b"] = true, ["d"] = true, ["g"] = true, ["h"] = true, ["p"] = true, ["m"] = true },
        color = Color3.fromRGB(255, 152, 0),      -- Oranye
        icon = "🟠",
        desc = "Akhiran konsonan keras (b, d, g, h, p, m)"
    },
    Ekstrim = {
        letters = { ["v"] = true, ["w"] = true, ["x"] = true, ["y"] = true, ["z"] = true, ["j"] = true, ["c"] = true },
        color = Color3.fromRGB(244, 67, 54),      -- Merah
        icon = "🔴",
        desc = "Akhiran langka (v, w, x, y, z, j, c)"
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

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

------------------------------------------------------------
-- CLEANUP (hapus GUI lama jika di-re-inject)
------------------------------------------------------------
local oldGui = playerGui:FindFirstChild("SambungKataGUI")
if oldGui then oldGui:Destroy() end

------------------------------------------------------------
-- DATA STORAGE
------------------------------------------------------------
local allWords = {}           -- Semua kata dari KBBI
local wordsByDifficulty = {   -- Kata dikelompokkan per kesulitan
    Mudah = {},
    Normal = {},
    Sulit = {},
    Ekstrim = {},
    Lainnya = {}
}
local currentDifficulty = nil -- Kesulitan yang dipilih
local currentWords = {}       -- Kata-kata yang aktif (sesuai kesulitan)
local chainHistory = {}       -- Riwayat kata yang sudah dipakai
local currentChainWord = nil  -- Kata terakhir dalam chain
local score = 0
local isLoaded = false
local isGameActive = false    -- apakah mode game chain aktif

------------------------------------------------------------
-- UTILITY FUNCTIONS
------------------------------------------------------------
local function getLastChar(word)
    return string.sub(word, -1):lower()
end

local function getLastChars(word, n)
    n = n or CHAIN_LENGTH
    if #word < n then
        return word:lower()
    end
    return string.sub(word, -n):lower()
end

local function getDifficultyOfWord(word)
    local lastChar = getLastChar(word)
    for _, diffName in ipairs(DIFFICULTY_ORDER) do
        if DIFFICULTY[diffName].letters[lastChar] then
            return diffName
        end
    end
    return "Lainnya"
end

local function startsWith(word, prefix)
    return string.sub(word:lower(), 1, #prefix) == prefix:lower()
end

local function createTween(obj, props, duration, style, direction)
    local tween = TweenService:Create(obj, TweenInfo.new(
        duration or 0.3,
        style or Enum.EasingStyle.Quart,
        direction or Enum.EasingDirection.Out
    ), props)
    return tween
end

local function formatNumber(n)
    local formatted = tostring(n)
    local k
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1.%2')
        if k == 0 then break end
    end
    return formatted
end

------------------------------------------------------------
-- FETCH & PARSE KBBI DATA
------------------------------------------------------------
local function fetchKBBI()
    local success, result = pcall(function()
        -- Executor biasanya support game:HttpGet
        if game.HttpGet then
            return game:HttpGet(URL_KBBI)
        else
            -- Fallback: HttpService (hanya untuk testing di studio)
            return HttpService:GetAsync(URL_KBBI)
        end
    end)
    
    if not success then
        warn("[SambungKata] Gagal fetch KBBI: " .. tostring(result))
        warn("[SambungKata] Pastikan URL_KBBI sudah benar!")
        return false
    end
    
    -- Parse kata per baris
    local count = 0
    for line in result:gmatch("[^\r\n]+") do
        local word = line:match("^%s*(.-)%s*$") -- trim whitespace
        if word and #word > 0 then
            word = word:lower()
            -- Hanya ambil kata yang valid (huruf saja, tanpa spasi/simbol)
            if word:match("^[a-z]+$") then
                table.insert(allWords, word)
                local diff = getDifficultyOfWord(word)
                if wordsByDifficulty[diff] then
                    table.insert(wordsByDifficulty[diff], word)
                end
                count = count + 1
            end
        end
    end
    
    print("[SambungKata] Berhasil memuat " .. formatNumber(count) .. " kata dari KBBI!")
    print("[SambungKata] Mudah: " .. formatNumber(#wordsByDifficulty.Mudah) .. " kata")
    print("[SambungKata] Normal: " .. formatNumber(#wordsByDifficulty.Normal) .. " kata")
    print("[SambungKata] Sulit: " .. formatNumber(#wordsByDifficulty.Sulit) .. " kata")
    print("[SambungKata] Ekstrim: " .. formatNumber(#wordsByDifficulty.Ekstrim) .. " kata")
    
    return true
end

------------------------------------------------------------
-- SEARCH FUNCTION
------------------------------------------------------------
local function searchWords(prefix, wordList, maxResults)
    maxResults = maxResults or MAX_RESULTS
    local results = {}
    prefix = prefix:lower()
    
    if #prefix == 0 then return results end
    
    for _, word in ipairs(wordList) do
        if startsWith(word, prefix) then
            -- Jangan masukkan kata yang sudah dipakai di chain
            local alreadyUsed = false
            for _, usedWord in ipairs(chainHistory) do
                if usedWord == word then
                    alreadyUsed = true
                    break
                end
            end
            if not alreadyUsed then
                table.insert(results, word)
                if #results >= maxResults then
                    break
                end
            end
        end
    end
    
    return results
end

------------------------------------------------------------
-- GUI CREATION
------------------------------------------------------------
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "SambungKataGUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = playerGui

-- ==================== MAIN FRAME ====================
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 480, 0, 600)
MainFrame.Position = UDim2.new(0.5, -240, 0.5, -300)
MainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 16)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(60, 60, 90)
MainStroke.Thickness = 1.5
MainStroke.Parent = MainFrame

-- Gradient accent line di atas
local AccentLine = Instance.new("Frame")
AccentLine.Name = "AccentLine"
AccentLine.Size = UDim2.new(1, 0, 0, 3)
AccentLine.Position = UDim2.new(0, 0, 0, 0)
AccentLine.BorderSizePixel = 0
AccentLine.Parent = MainFrame

local AccentGradient = Instance.new("UIGradient")
AccentGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(76, 175, 80)),
    ColorSequenceKeypoint.new(0.33, Color3.fromRGB(33, 150, 243)),
    ColorSequenceKeypoint.new(0.66, Color3.fromRGB(255, 152, 0)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(244, 67, 54))
})
AccentGradient.Parent = AccentLine

-- ==================== TITLE BAR ====================
local TitleBar = Instance.new("Frame")
TitleBar.Name = "TitleBar"
TitleBar.Size = UDim2.new(1, 0, 0, 50)
TitleBar.Position = UDim2.new(0, 0, 0, 3)
TitleBar.BackgroundTransparency = 1
TitleBar.Parent = MainFrame

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Name = "Title"
TitleLabel.Size = UDim2.new(1, -50, 1, 0)
TitleLabel.Position = UDim2.new(0, 16, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "🔤 SAMBUNG KATA"
TitleLabel.TextColor3 = Color3.fromRGB(240, 240, 255)
TitleLabel.TextSize = 20
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = TitleBar

local SubTitle = Instance.new("TextLabel")
SubTitle.Name = "SubTitle"
SubTitle.Size = UDim2.new(1, -50, 0, 16)
SubTitle.Position = UDim2.new(0, 16, 1, -18)
SubTitle.BackgroundTransparency = 1
SubTitle.Text = "KBBI Edition"
SubTitle.TextColor3 = Color3.fromRGB(120, 120, 160)
SubTitle.TextSize = 11
SubTitle.Font = Enum.Font.Gotham
SubTitle.TextXAlignment = Enum.TextXAlignment.Left
SubTitle.Parent = TitleBar

-- Close Button
local CloseBtn = Instance.new("TextButton")
CloseBtn.Name = "CloseBtn"
CloseBtn.Size = UDim2.new(0, 36, 0, 36)
CloseBtn.Position = UDim2.new(1, -44, 0, 7)
CloseBtn.BackgroundColor3 = Color3.fromRGB(244, 67, 54)
CloseBtn.BackgroundTransparency = 0.85
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = Color3.fromRGB(244, 67, 54)
CloseBtn.TextSize = 16
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.BorderSizePixel = 0
CloseBtn.Parent = TitleBar

local CloseBtnCorner = Instance.new("UICorner")
CloseBtnCorner.CornerRadius = UDim.new(0, 8)
CloseBtnCorner.Parent = CloseBtn

-- Minimize Button
local MinBtn = Instance.new("TextButton")
MinBtn.Name = "MinBtn"
MinBtn.Size = UDim2.new(0, 36, 0, 36)
MinBtn.Position = UDim2.new(1, -84, 0, 7)
MinBtn.BackgroundColor3 = Color3.fromRGB(255, 193, 7)
MinBtn.BackgroundTransparency = 0.85
MinBtn.Text = "—"
MinBtn.TextColor3 = Color3.fromRGB(255, 193, 7)
MinBtn.TextSize = 16
MinBtn.Font = Enum.Font.GothamBold
MinBtn.BorderSizePixel = 0
MinBtn.Parent = TitleBar

local MinBtnCorner = Instance.new("UICorner")
MinBtnCorner.CornerRadius = UDim.new(0, 8)
MinBtnCorner.Parent = MinBtn

-- ==================== SEPARATOR ====================
local Sep1 = Instance.new("Frame")
Sep1.Size = UDim2.new(1, -32, 0, 1)
Sep1.Position = UDim2.new(0, 16, 0, 53)
Sep1.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
Sep1.BorderSizePixel = 0
Sep1.Parent = MainFrame

-- ==================== CONTENT AREA ====================
local ContentFrame = Instance.new("Frame")
ContentFrame.Name = "ContentFrame"
ContentFrame.Size = UDim2.new(1, -32, 1, -60)
ContentFrame.Position = UDim2.new(0, 16, 0, 56)
ContentFrame.BackgroundTransparency = 1
ContentFrame.ClipsDescendants = true
ContentFrame.Parent = MainFrame

-- ==================== LOADING PAGE ====================
local LoadingPage = Instance.new("Frame")
LoadingPage.Name = "LoadingPage"
LoadingPage.Size = UDim2.new(1, 0, 1, 0)
LoadingPage.BackgroundTransparency = 1
LoadingPage.Parent = ContentFrame

local LoadingIcon = Instance.new("TextLabel")
LoadingIcon.Size = UDim2.new(1, 0, 0, 60)
LoadingIcon.Position = UDim2.new(0, 0, 0.3, -30)
LoadingIcon.BackgroundTransparency = 1
LoadingIcon.Text = "📚"
LoadingIcon.TextSize = 48
LoadingIcon.Font = Enum.Font.GothamBold
LoadingIcon.Parent = LoadingPage

local LoadingText = Instance.new("TextLabel")
LoadingText.Name = "LoadingText"
LoadingText.Size = UDim2.new(1, 0, 0, 30)
LoadingText.Position = UDim2.new(0, 0, 0.3, 35)
LoadingText.BackgroundTransparency = 1
LoadingText.Text = "Memuat kamus KBBI..."
LoadingText.TextColor3 = Color3.fromRGB(180, 180, 220)
LoadingText.TextSize = 16
LoadingText.Font = Enum.Font.Gotham
LoadingText.Parent = LoadingPage

local LoadingBar = Instance.new("Frame")
LoadingBar.Size = UDim2.new(0.6, 0, 0, 4)
LoadingBar.Position = UDim2.new(0.2, 0, 0.3, 75)
LoadingBar.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
LoadingBar.BorderSizePixel = 0
LoadingBar.Parent = LoadingPage

local LoadingBarCorner = Instance.new("UICorner")
LoadingBarCorner.CornerRadius = UDim.new(0, 2)
LoadingBarCorner.Parent = LoadingBar

local LoadingBarFill = Instance.new("Frame")
LoadingBarFill.Size = UDim2.new(0, 0, 1, 0)
LoadingBarFill.BackgroundColor3 = Color3.fromRGB(76, 175, 80)
LoadingBarFill.BorderSizePixel = 0
LoadingBarFill.Parent = LoadingBar

local LoadingBarFillCorner = Instance.new("UICorner")
LoadingBarFillCorner.CornerRadius = UDim.new(0, 2)
LoadingBarFillCorner.Parent = LoadingBarFill

-- ==================== DIFFICULTY SELECT PAGE ====================
local DifficultyPage = Instance.new("Frame")
DifficultyPage.Name = "DifficultyPage"
DifficultyPage.Size = UDim2.new(1, 0, 1, 0)
DifficultyPage.BackgroundTransparency = 1
DifficultyPage.Visible = false
DifficultyPage.Parent = ContentFrame

local DiffTitle = Instance.new("TextLabel")
DiffTitle.Size = UDim2.new(1, 0, 0, 30)
DiffTitle.Position = UDim2.new(0, 0, 0, 5)
DiffTitle.BackgroundTransparency = 1
DiffTitle.Text = "Pilih Tingkat Kesulitan"
DiffTitle.TextColor3 = Color3.fromRGB(220, 220, 255)
DiffTitle.TextSize = 18
DiffTitle.Font = Enum.Font.GothamBold
DiffTitle.Parent = DifficultyPage

local DiffDesc = Instance.new("TextLabel")
DiffDesc.Size = UDim2.new(1, 0, 0, 20)
DiffDesc.Position = UDim2.new(0, 0, 0, 35)
DiffDesc.BackgroundTransparency = 1
DiffDesc.Text = "Kesulitan menentukan huruf akhir kata yang tersedia"
DiffDesc.TextColor3 = Color3.fromRGB(120, 120, 160)
DiffDesc.TextSize = 12
DiffDesc.Font = Enum.Font.Gotham
DiffDesc.Parent = DifficultyPage

-- Mode Selection
local ModeFrame = Instance.new("Frame")
ModeFrame.Name = "ModeFrame"
ModeFrame.Size = UDim2.new(1, 0, 0, 40)
ModeFrame.Position = UDim2.new(0, 0, 0, 65)
ModeFrame.BackgroundTransparency = 1
ModeFrame.Parent = DifficultyPage

local ModeFreeBtn = Instance.new("TextButton")
ModeFreeBtn.Name = "ModeFreeBtn"
ModeFreeBtn.Size = UDim2.new(0.48, 0, 1, 0)
ModeFreeBtn.Position = UDim2.new(0, 0, 0, 0)
ModeFreeBtn.BackgroundColor3 = Color3.fromRGB(33, 150, 243)
ModeFreeBtn.BackgroundTransparency = 0.15
ModeFreeBtn.Text = "🔍 Mode Cari Kata"
ModeFreeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ModeFreeBtn.TextSize = 13
ModeFreeBtn.Font = Enum.Font.GothamBold
ModeFreeBtn.BorderSizePixel = 0
ModeFreeBtn.Parent = ModeFrame

local ModeFreeBtnCorner = Instance.new("UICorner")
ModeFreeBtnCorner.CornerRadius = UDim.new(0, 10)
ModeFreeBtnCorner.Parent = ModeFreeBtn

local ModeChainBtn = Instance.new("TextButton")
ModeChainBtn.Name = "ModeChainBtn"
ModeChainBtn.Size = UDim2.new(0.48, 0, 1, 0)
ModeChainBtn.Position = UDim2.new(0.52, 0, 0, 0)
ModeChainBtn.BackgroundColor3 = Color3.fromRGB(156, 39, 176)
ModeChainBtn.BackgroundTransparency = 0.15
ModeChainBtn.Text = "🔗 Mode Sambung Kata"
ModeChainBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ModeChainBtn.TextSize = 13
ModeChainBtn.Font = Enum.Font.GothamBold
ModeChainBtn.BorderSizePixel = 0
ModeChainBtn.Parent = ModeFrame

local ModeChainBtnCorner = Instance.new("UICorner")
ModeChainBtnCorner.CornerRadius = UDim.new(0, 10)
ModeChainBtnCorner.Parent = ModeChainBtn

-- Difficulty Buttons Container
local DiffBtnContainer = Instance.new("Frame")
DiffBtnContainer.Name = "DiffBtnContainer"
DiffBtnContainer.Size = UDim2.new(1, 0, 0, 330)
DiffBtnContainer.Position = UDim2.new(0, 0, 0, 115)
DiffBtnContainer.BackgroundTransparency = 1
DiffBtnContainer.Parent = DifficultyPage

local selectedMode = "search" -- "search" atau "chain"

local diffButtons = {}

for i, diffName in ipairs(DIFFICULTY_ORDER) do
    local diff = DIFFICULTY[diffName]
    
    local btn = Instance.new("TextButton")
    btn.Name = "Diff_" .. diffName
    btn.Size = UDim2.new(1, 0, 0, 72)
    btn.Position = UDim2.new(0, 0, 0, (i - 1) * 80)
    btn.BackgroundColor3 = Color3.fromRGB(28, 28, 40)
    btn.BorderSizePixel = 0
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.Parent = DiffBtnContainer
    
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 12)
    btnCorner.Parent = btn
    
    local btnStroke = Instance.new("UIStroke")
    btnStroke.Color = diff.color
    btnStroke.Transparency = 0.7
    btnStroke.Thickness = 1
    btnStroke.Parent = btn
    
    -- Color indicator bar
    local colorBar = Instance.new("Frame")
    colorBar.Size = UDim2.new(0, 4, 0.6, 0)
    colorBar.Position = UDim2.new(0, 12, 0.2, 0)
    colorBar.BackgroundColor3 = diff.color
    colorBar.BorderSizePixel = 0
    colorBar.Parent = btn
    
    local colorBarCorner = Instance.new("UICorner")
    colorBarCorner.CornerRadius = UDim.new(0, 2)
    colorBarCorner.Parent = colorBar
    
    -- Difficulty name
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(0.5, -30, 0, 24)
    nameLabel.Position = UDim2.new(0, 28, 0, 12)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = diff.icon .. " " .. diffName
    nameLabel.TextColor3 = diff.color
    nameLabel.TextSize = 17
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Parent = btn
    
    -- Description
    local descLabel = Instance.new("TextLabel")
    descLabel.Size = UDim2.new(1, -30, 0, 16)
    descLabel.Position = UDim2.new(0, 28, 0, 38)
    descLabel.BackgroundTransparency = 1
    descLabel.Text = diff.desc
    descLabel.TextColor3 = Color3.fromRGB(120, 120, 160)
    descLabel.TextSize = 11
    descLabel.Font = Enum.Font.Gotham
    descLabel.TextXAlignment = Enum.TextXAlignment.Left
    descLabel.Parent = btn
    
    -- Word count (akan diupdate setelah load)
    local countLabel = Instance.new("TextLabel")
    countLabel.Name = "CountLabel"
    countLabel.Size = UDim2.new(0.35, 0, 0, 20)
    countLabel.Position = UDim2.new(0.65, -10, 0, 14)
    countLabel.BackgroundTransparency = 1
    countLabel.Text = "..."
    countLabel.TextColor3 = Color3.fromRGB(100, 100, 140)
    countLabel.TextSize = 12
    countLabel.Font = Enum.Font.Gotham
    countLabel.TextXAlignment = Enum.TextXAlignment.Right
    countLabel.Parent = btn
    
    -- Hover effects
    btn.MouseEnter:Connect(function()
        createTween(btn, {BackgroundColor3 = Color3.fromRGB(38, 38, 55)}, 0.2):Play()
        createTween(btnStroke, {Transparency = 0.3}, 0.2):Play()
    end)
    
    btn.MouseLeave:Connect(function()
        createTween(btn, {BackgroundColor3 = Color3.fromRGB(28, 28, 40)}, 0.2):Play()
        createTween(btnStroke, {Transparency = 0.7}, 0.2):Play()
    end)
    
    diffButtons[diffName] = btn
end

-- All Difficulty button
local AllBtn = Instance.new("TextButton")
AllBtn.Name = "Diff_Semua"
AllBtn.Size = UDim2.new(1, 0, 0, 42)
AllBtn.Position = UDim2.new(0, 0, 0, #DIFFICULTY_ORDER * 80)
AllBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 40)
AllBtn.BorderSizePixel = 0
AllBtn.Text = ""
AllBtn.AutoButtonColor = false
AllBtn.Parent = DiffBtnContainer

local AllBtnCorner = Instance.new("UICorner")
AllBtnCorner.CornerRadius = UDim.new(0, 12)
AllBtnCorner.Parent = AllBtn

local AllBtnStroke = Instance.new("UIStroke")
AllBtnStroke.Color = Color3.fromRGB(180, 180, 220)
AllBtnStroke.Transparency = 0.7
AllBtnStroke.Thickness = 1
AllBtnStroke.Parent = AllBtn

local AllNameLabel = Instance.new("TextLabel")
AllNameLabel.Size = UDim2.new(0.6, 0, 1, 0)
AllNameLabel.Position = UDim2.new(0, 16, 0, 0)
AllNameLabel.BackgroundTransparency = 1
AllNameLabel.Text = "⚪ Semua Kata"
AllNameLabel.TextColor3 = Color3.fromRGB(200, 200, 240)
AllNameLabel.TextSize = 15
AllNameLabel.Font = Enum.Font.GothamBold
AllNameLabel.TextXAlignment = Enum.TextXAlignment.Left
AllNameLabel.Parent = AllBtn

local AllCountLabel = Instance.new("TextLabel")
AllCountLabel.Name = "CountLabel"
AllCountLabel.Size = UDim2.new(0.35, 0, 1, 0)
AllCountLabel.Position = UDim2.new(0.65, -10, 0, 0)
AllCountLabel.BackgroundTransparency = 1
AllCountLabel.Text = "..."
AllCountLabel.TextColor3 = Color3.fromRGB(100, 100, 140)
AllCountLabel.TextSize = 12
AllCountLabel.Font = Enum.Font.Gotham
AllCountLabel.TextXAlignment = Enum.TextXAlignment.Right
AllCountLabel.Parent = AllBtn

AllBtn.MouseEnter:Connect(function()
    createTween(AllBtn, {BackgroundColor3 = Color3.fromRGB(38, 38, 55)}, 0.2):Play()
end)
AllBtn.MouseLeave:Connect(function()
    createTween(AllBtn, {BackgroundColor3 = Color3.fromRGB(28, 28, 40)}, 0.2):Play()
end)

-- ==================== GAME PAGE (SEARCH MODE) ====================
local GamePage = Instance.new("Frame")
GamePage.Name = "GamePage"
GamePage.Size = UDim2.new(1, 0, 1, 0)
GamePage.BackgroundTransparency = 1
GamePage.Visible = false
GamePage.Parent = ContentFrame

-- Top info bar
local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 36)
TopBar.BackgroundTransparency = 1
TopBar.Parent = GamePage

local BackBtn = Instance.new("TextButton")
BackBtn.Size = UDim2.new(0, 36, 0, 36)
BackBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 40)
BackBtn.Text = "←"
BackBtn.TextColor3 = Color3.fromRGB(180, 180, 220)
BackBtn.TextSize = 18
BackBtn.Font = Enum.Font.GothamBold
BackBtn.BorderSizePixel = 0
BackBtn.Parent = TopBar

local BackBtnCorner = Instance.new("UICorner")
BackBtnCorner.CornerRadius = UDim.new(0, 8)
BackBtnCorner.Parent = BackBtn

local DiffBadge = Instance.new("TextLabel")
DiffBadge.Name = "DiffBadge"
DiffBadge.Size = UDim2.new(0, 120, 0, 28)
DiffBadge.Position = UDim2.new(0, 44, 0, 4)
DiffBadge.BackgroundColor3 = Color3.fromRGB(28, 28, 40)
DiffBadge.Text = ""
DiffBadge.TextColor3 = Color3.fromRGB(200, 200, 240)
DiffBadge.TextSize = 13
DiffBadge.Font = Enum.Font.GothamBold
DiffBadge.Parent = TopBar

local DiffBadgeCorner = Instance.new("UICorner")
DiffBadgeCorner.CornerRadius = UDim.new(0, 8)
DiffBadgeCorner.Parent = DiffBadge

local ScoreLabel = Instance.new("TextLabel")
ScoreLabel.Name = "ScoreLabel"
ScoreLabel.Size = UDim2.new(0, 120, 0, 28)
ScoreLabel.Position = UDim2.new(1, -120, 0, 4)
ScoreLabel.BackgroundColor3 = Color3.fromRGB(28, 28, 40)
ScoreLabel.Text = "Skor: 0"
ScoreLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
ScoreLabel.TextSize = 13
ScoreLabel.Font = Enum.Font.GothamBold
ScoreLabel.Parent = TopBar
ScoreLabel.Visible = false -- hanya tampil di mode chain

local ScoreCorner = Instance.new("UICorner")
ScoreCorner.CornerRadius = UDim.new(0, 8)
ScoreCorner.Parent = ScoreLabel

-- Mode Label
local ModeLabel = Instance.new("TextLabel")
ModeLabel.Name = "ModeLabel"
ModeLabel.Size = UDim2.new(0, 160, 0, 28)
ModeLabel.Position = UDim2.new(1, -160, 0, 4)
ModeLabel.BackgroundTransparency = 1
ModeLabel.Text = "🔍 Mode Cari"
ModeLabel.TextColor3 = Color3.fromRGB(120, 120, 160)
ModeLabel.TextSize = 12
ModeLabel.Font = Enum.Font.Gotham
ModeLabel.TextXAlignment = Enum.TextXAlignment.Right
ModeLabel.Parent = TopBar

-- Chain info (untuk mode chain)
local ChainInfo = Instance.new("Frame")
ChainInfo.Name = "ChainInfo"
ChainInfo.Size = UDim2.new(1, 0, 0, 60)
ChainInfo.Position = UDim2.new(0, 0, 0, 42)
ChainInfo.BackgroundColor3 = Color3.fromRGB(28, 28, 40)
ChainInfo.BorderSizePixel = 0
ChainInfo.Visible = false
ChainInfo.Parent = GamePage

local ChainInfoCorner = Instance.new("UICorner")
ChainInfoCorner.CornerRadius = UDim.new(0, 10)
ChainInfoCorner.Parent = ChainInfo

local ChainWordLabel = Instance.new("TextLabel")
ChainWordLabel.Name = "ChainWord"
ChainWordLabel.Size = UDim2.new(1, -20, 0, 24)
ChainWordLabel.Position = UDim2.new(0, 10, 0, 6)
ChainWordLabel.BackgroundTransparency = 1
ChainWordLabel.Text = "Kata saat ini: -"
ChainWordLabel.TextColor3 = Color3.fromRGB(220, 220, 255)
ChainWordLabel.TextSize = 15
ChainWordLabel.Font = Enum.Font.GothamBold
ChainWordLabel.TextXAlignment = Enum.TextXAlignment.Left
ChainWordLabel.Parent = ChainInfo

local ChainHintLabel = Instance.new("TextLabel")
ChainHintLabel.Name = "ChainHint"
ChainHintLabel.Size = UDim2.new(1, -20, 0, 20)
ChainHintLabel.Position = UDim2.new(0, 10, 0, 32)
ChainHintLabel.BackgroundTransparency = 1
ChainHintLabel.Text = 'Ketik kata yang dimulai dengan "..."'
ChainHintLabel.TextColor3 = Color3.fromRGB(120, 120, 160)
ChainHintLabel.TextSize = 12
ChainHintLabel.Font = Enum.Font.Gotham
ChainHintLabel.TextXAlignment = Enum.TextXAlignment.Left
ChainHintLabel.Parent = ChainInfo

-- Search input
local SearchFrame = Instance.new("Frame")
SearchFrame.Size = UDim2.new(1, 0, 0, 44)
SearchFrame.Position = UDim2.new(0, 0, 0, 42)
SearchFrame.BackgroundColor3 = Color3.fromRGB(28, 28, 40)
SearchFrame.BorderSizePixel = 0
SearchFrame.Parent = GamePage

local SearchFrameCorner = Instance.new("UICorner")
SearchFrameCorner.CornerRadius = UDim.new(0, 10)
SearchFrameCorner.Parent = SearchFrame

local SearchIcon = Instance.new("TextLabel")
SearchIcon.Size = UDim2.new(0, 30, 1, 0)
SearchIcon.Position = UDim2.new(0, 10, 0, 0)
SearchIcon.BackgroundTransparency = 1
SearchIcon.Text = "🔍"
SearchIcon.TextSize = 16
SearchIcon.Font = Enum.Font.Gotham
SearchIcon.Parent = SearchFrame

local SearchInput = Instance.new("TextBox")
SearchInput.Name = "SearchInput"
SearchInput.Size = UDim2.new(1, -80, 1, -10)
SearchInput.Position = UDim2.new(0, 42, 0, 5)
SearchInput.BackgroundTransparency = 1
SearchInput.Text = ""
SearchInput.PlaceholderText = "Ketik huruf awal kata..."
SearchInput.PlaceholderColor3 = Color3.fromRGB(80, 80, 120)
SearchInput.TextColor3 = Color3.fromRGB(220, 220, 255)
SearchInput.TextSize = 15
SearchInput.Font = Enum.Font.Gotham
SearchInput.TextXAlignment = Enum.TextXAlignment.Left
SearchInput.ClearTextOnFocus = false
SearchInput.Parent = SearchFrame

local ResultCount = Instance.new("TextLabel")
ResultCount.Name = "ResultCount"
ResultCount.Size = UDim2.new(0, 40, 1, 0)
ResultCount.Position = UDim2.new(1, -48, 0, 0)
ResultCount.BackgroundTransparency = 1
ResultCount.Text = "0"
ResultCount.TextColor3 = Color3.fromRGB(100, 100, 140)
ResultCount.TextSize = 12
ResultCount.Font = Enum.Font.Gotham
ResultCount.Parent = SearchFrame

-- Results area
local ResultsFrame = Instance.new("ScrollingFrame")
ResultsFrame.Name = "ResultsFrame"
ResultsFrame.Size = UDim2.new(1, 0, 1, -96)
ResultsFrame.Position = UDim2.new(0, 0, 0, 92)
ResultsFrame.BackgroundTransparency = 1
ResultsFrame.BorderSizePixel = 0
ResultsFrame.ScrollBarThickness = 4
ResultsFrame.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 90)
ResultsFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
ResultsFrame.Parent = GamePage

local ResultsLayout = Instance.new("UIListLayout")
ResultsLayout.SortOrder = Enum.SortOrder.LayoutOrder
ResultsLayout.Padding = UDim.new(0, 4)
ResultsLayout.Parent = ResultsFrame

-- Empty state
local EmptyLabel = Instance.new("TextLabel")
EmptyLabel.Name = "EmptyLabel"
EmptyLabel.Size = UDim2.new(1, 0, 0, 100)
EmptyLabel.BackgroundTransparency = 1
EmptyLabel.Text = "Ketik huruf untuk mencari kata..."
EmptyLabel.TextColor3 = Color3.fromRGB(80, 80, 120)
EmptyLabel.TextSize = 14
EmptyLabel.Font = Enum.Font.Gotham
EmptyLabel.Parent = ResultsFrame

------------------------------------------------------------
-- DRAGGING FUNCTIONALITY
------------------------------------------------------------
local dragging = false
local dragStart = nil
local startPos = nil

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
-- UI FUNCTIONS
------------------------------------------------------------
local function clearResults()
    for _, child in ipairs(ResultsFrame:GetChildren()) do
        if child:IsA("TextButton") or (child:IsA("TextLabel") and child.Name ~= "EmptyLabel") then
            child:Destroy()
        end
    end
end

local function createWordButton(word, index, isChainMode)
    local diff = getDifficultyOfWord(word)
    local diffData = DIFFICULTY[diff]
    local color = diffData and diffData.color or Color3.fromRGB(150, 150, 180)
    
    local btn = Instance.new("TextButton")
    btn.Name = "Word_" .. index
    btn.Size = UDim2.new(1, -4, 0, 38)
    btn.BackgroundColor3 = Color3.fromRGB(24, 24, 36)
    btn.BorderSizePixel = 0
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.LayoutOrder = index
    btn.Parent = ResultsFrame
    
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 8)
    btnCorner.Parent = btn
    
    -- Color indicator
    local indicator = Instance.new("Frame")
    indicator.Size = UDim2.new(0, 3, 0.5, 0)
    indicator.Position = UDim2.new(0, 8, 0.25, 0)
    indicator.BackgroundColor3 = color
    indicator.BorderSizePixel = 0
    indicator.Parent = btn
    
    local indicatorCorner = Instance.new("UICorner")
    indicatorCorner.CornerRadius = UDim.new(0, 2)
    indicatorCorner.Parent = indicator
    
    -- Word text
    local wordLabel = Instance.new("TextLabel")
    wordLabel.Size = UDim2.new(0.6, -20, 1, 0)
    wordLabel.Position = UDim2.new(0, 20, 0, 0)
    wordLabel.BackgroundTransparency = 1
    wordLabel.Text = word:upper()
    wordLabel.TextColor3 = Color3.fromRGB(220, 220, 255)
    wordLabel.TextSize = 14
    wordLabel.Font = Enum.Font.GothamBold
    wordLabel.TextXAlignment = Enum.TextXAlignment.Left
    wordLabel.Parent = btn
    
    -- Difficulty badge
    local badge = Instance.new("TextLabel")
    badge.Size = UDim2.new(0, 70, 0, 22)
    badge.Position = UDim2.new(1, -130, 0, 8)
    badge.BackgroundColor3 = color
    badge.BackgroundTransparency = 0.85
    badge.Text = diff
    badge.TextColor3 = color
    badge.TextSize = 10
    badge.Font = Enum.Font.GothamBold
    badge.Parent = btn
    
    local badgeCorner = Instance.new("UICorner")
    badgeCorner.CornerRadius = UDim.new(0, 6)
    badgeCorner.Parent = badge
    
    -- Letter count
    local lenLabel = Instance.new("TextLabel")
    lenLabel.Size = UDim2.new(0, 45, 0, 22)
    lenLabel.Position = UDim2.new(1, -52, 0, 8)
    lenLabel.BackgroundTransparency = 1
    lenLabel.Text = #word .. " huruf"
    lenLabel.TextColor3 = Color3.fromRGB(80, 80, 120)
    lenLabel.TextSize = 10
    lenLabel.Font = Enum.Font.Gotham
    lenLabel.TextXAlignment = Enum.TextXAlignment.Right
    lenLabel.Parent = btn
    
    -- Hover effects
    btn.MouseEnter:Connect(function()
        createTween(btn, {BackgroundColor3 = Color3.fromRGB(34, 34, 50)}, 0.15):Play()
    end)
    
    btn.MouseLeave:Connect(function()
        createTween(btn, {BackgroundColor3 = Color3.fromRGB(24, 24, 36)}, 0.15):Play()
    end)
    
    -- Click to use in chain mode
    if isChainMode then
        btn.MouseButton1Click:Connect(function()
            -- Pilih kata ini untuk chain
            table.insert(chainHistory, word)
            currentChainWord = word
            score = score + #word -- skor berdasarkan panjang kata
            
            ScoreLabel.Text = "Skor: " .. score
            
            local lastChars = getLastChars(word, CHAIN_LENGTH)
            ChainWordLabel.Text = "Kata: " .. word:upper() .. "  →  Sambung dengan: " .. lastChars:upper() .. "..."
            ChainHintLabel.Text = "Riwayat: " .. #chainHistory .. " kata | Ketik kata berawalan \"" .. lastChars:upper() .. "\""
            
            SearchInput.Text = lastChars
            SearchInput:CaptureFocus()
            
            -- Flash effect
            createTween(btn, {BackgroundColor3 = color}, 0.1):Play()
            task.delay(0.15, function()
                createTween(btn, {BackgroundColor3 = Color3.fromRGB(24, 24, 36)}, 0.2):Play()
            end)
        end)
    end
    
    -- Animate in
    btn.BackgroundTransparency = 1
    wordLabel.TextTransparency = 1
    badge.BackgroundTransparency = 1
    badge.TextTransparency = 1
    
    local delay = index * 0.02
    task.delay(delay, function()
        createTween(btn, {BackgroundTransparency = 0}, 0.2):Play()
        createTween(wordLabel, {TextTransparency = 0}, 0.2):Play()
        createTween(badge, {BackgroundTransparency = 0.85, TextTransparency = 0}, 0.2):Play()
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
        createWordButton(word, i, isGameActive)
    end
    
    -- Update canvas size
    task.delay(0.1, function()
        ResultsFrame.CanvasSize = UDim2.new(0, 0, 0, ResultsLayout.AbsoluteContentSize.Y + 10)
    end)
end

------------------------------------------------------------
-- PAGE NAVIGATION
------------------------------------------------------------
local function showPage(pageName)
    LoadingPage.Visible = pageName == "loading"
    DifficultyPage.Visible = pageName == "difficulty"
    GamePage.Visible = pageName == "game"
end

local function showDifficultyPage()
    -- Update word counts
    for diffName, btn in pairs(diffButtons) do
        local countLabel = btn:FindFirstChild("CountLabel")
        if countLabel then
            countLabel.Text = formatNumber(#wordsByDifficulty[diffName]) .. " kata"
        end
    end
    AllCountLabel.Text = formatNumber(#allWords) .. " kata"
    
    showPage("difficulty")
end

local function startGame(diffName, mode)
    selectedMode = mode
    isGameActive = (mode == "chain")
    
    currentDifficulty = diffName
    chainHistory = {}
    currentChainWord = nil
    score = 0
    
    if diffName == "Semua" then
        currentWords = allWords
        DiffBadge.Text = "⚪ Semua Kata"
        DiffBadge.TextColor3 = Color3.fromRGB(200, 200, 240)
    else
        currentWords = wordsByDifficulty[diffName]
        local diff = DIFFICULTY[diffName]
        DiffBadge.Text = diff.icon .. " " .. diffName
        DiffBadge.TextColor3 = diff.color
    end
    
    -- Setup mode-specific UI
    if isGameActive then
        ScoreLabel.Visible = true
        ScoreLabel.Text = "Skor: 0"
        ChainInfo.Visible = true
        ModeLabel.Text = "🔗 Sambung Kata"
        SearchFrame.Position = UDim2.new(0, 0, 0, 108)
        ResultsFrame.Size = UDim2.new(1, 0, 1, -162)
        ResultsFrame.Position = UDim2.new(0, 0, 0, 158)
        
        -- Pick random starting word
        if #currentWords > 0 then
            local startWord = currentWords[math.random(1, #currentWords)]
            currentChainWord = startWord
            table.insert(chainHistory, startWord)
            
            local lastChars = getLastChars(startWord, CHAIN_LENGTH)
            ChainWordLabel.Text = "Mulai: " .. startWord:upper() .. "  →  Sambung: " .. lastChars:upper() .. "..."
            ChainHintLabel.Text = "Ketik kata yang berawalan \"" .. lastChars:upper() .. "\""
            SearchInput.PlaceholderText = "Ketik kata berawalan " .. lastChars:upper() .. "..."
            SearchInput.Text = lastChars
        end
    else
        ScoreLabel.Visible = false
        ChainInfo.Visible = false
        ModeLabel.Text = "🔍 Mode Cari"
        SearchFrame.Position = UDim2.new(0, 0, 0, 42)
        ResultsFrame.Size = UDim2.new(1, 0, 1, -96)
        ResultsFrame.Position = UDim2.new(0, 0, 0, 92)
        SearchInput.PlaceholderText = "Ketik huruf awal kata..."
        SearchInput.Text = ""
    end
    
    clearResults()
    EmptyLabel.Visible = true
    EmptyLabel.Text = isGameActive and "Pilih kata dari hasil pencarian untuk menyambung!" or "Ketik huruf untuk mencari kata..."
    
    showPage("game")
    
    task.delay(0.1, function()
        SearchInput:CaptureFocus()
    end)
end

------------------------------------------------------------
-- EVENT CONNECTIONS
------------------------------------------------------------

-- Mode buttons
local modeHighlightColor = Color3.fromRGB(33, 150, 243)
local modeNormalTransparency = 0.15
local modeInactiveTransparency = 0.7

local function updateModeButtons(mode)
    if mode == "search" then
        ModeFreeBtn.BackgroundTransparency = modeNormalTransparency
        ModeChainBtn.BackgroundTransparency = modeInactiveTransparency
    else
        ModeFreeBtn.BackgroundTransparency = modeInactiveTransparency
        ModeChainBtn.BackgroundTransparency = modeNormalTransparency
    end
end

ModeFreeBtn.MouseButton1Click:Connect(function()
    selectedMode = "search"
    updateModeButtons("search")
end)

ModeChainBtn.MouseButton1Click:Connect(function()
    selectedMode = "chain"
    updateModeButtons("chain")
end)

-- Difficulty buttons
for diffName, btn in pairs(diffButtons) do
    btn.MouseButton1Click:Connect(function()
        if isLoaded then
            startGame(diffName, selectedMode)
        end
    end)
end

AllBtn.MouseButton1Click:Connect(function()
    if isLoaded then
        startGame("Semua", selectedMode)
    end
end)

-- Back button
BackBtn.MouseButton1Click:Connect(function()
    isGameActive = false
    showDifficultyPage()
end)

-- Search functionality
local searchDebounce = false
SearchInput:GetPropertyChangedSignal("Text"):Connect(function()
    if searchDebounce then return end
    searchDebounce = true
    
    task.delay(0.15, function() -- debounce 150ms
        searchDebounce = false
        local text = SearchInput.Text:lower():gsub("%s+", "")
        
        if #text < 1 then
            clearResults()
            EmptyLabel.Visible = true
            EmptyLabel.Text = isGameActive and "Ketik untuk mencari kata sambungan..." or "Ketik huruf untuk mencari kata..."
            ResultCount.Text = "0"
            return
        end
        
        local results = searchWords(text, currentWords, MAX_RESULTS)
        displayResults(results)
    end)
end)

-- Close button
CloseBtn.MouseButton1Click:Connect(function()
    createTween(MainFrame, {Size = UDim2.new(0, 480, 0, 0)}, 0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In):Play()
    createTween(MainFrame, {BackgroundTransparency = 1}, 0.25):Play()
    task.delay(0.3, function()
        ScreenGui:Destroy()
    end)
end)

-- Minimize button
local isMinimized = false
local savedSize = MainFrame.Size

MinBtn.MouseButton1Click:Connect(function()
    if isMinimized then
        createTween(MainFrame, {Size = savedSize}, 0.3, Enum.EasingStyle.Quart):Play()
        isMinimized = false
    else
        savedSize = MainFrame.Size
        createTween(MainFrame, {Size = UDim2.new(0, 480, 0, 56)}, 0.3, Enum.EasingStyle.Quart):Play()
        isMinimized = true
    end
end)

-- Close/Minimize hover effects
CloseBtn.MouseEnter:Connect(function()
    createTween(CloseBtn, {BackgroundTransparency = 0.5}, 0.15):Play()
end)
CloseBtn.MouseLeave:Connect(function()
    createTween(CloseBtn, {BackgroundTransparency = 0.85}, 0.15):Play()
end)
MinBtn.MouseEnter:Connect(function()
    createTween(MinBtn, {BackgroundTransparency = 0.5}, 0.15):Play()
end)
MinBtn.MouseLeave:Connect(function()
    createTween(MinBtn, {BackgroundTransparency = 0.85}, 0.15):Play()
end)
BackBtn.MouseEnter:Connect(function()
    createTween(BackBtn, {BackgroundColor3 = Color3.fromRGB(40, 40, 60)}, 0.15):Play()
end)
BackBtn.MouseLeave:Connect(function()
    createTween(BackBtn, {BackgroundColor3 = Color3.fromRGB(28, 28, 40)}, 0.15):Play()
end)

------------------------------------------------------------
-- TOGGLE WITH KEYBIND (Right Shift untuk show/hide)
------------------------------------------------------------
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        MainFrame.Visible = not MainFrame.Visible
    end
end)

------------------------------------------------------------
-- INITIALIZE
------------------------------------------------------------
showPage("loading")

-- Animate loading bar
task.spawn(function()
    local loadTween = createTween(LoadingBarFill, {Size = UDim2.new(0.7, 0, 1, 0)}, 2, Enum.EasingStyle.Linear)
    loadTween:Play()
end)

-- Open animation
MainFrame.Size = UDim2.new(0, 480, 0, 0)
MainFrame.BackgroundTransparency = 0.5
createTween(MainFrame, {Size = UDim2.new(0, 480, 0, 600)}, 0.4, Enum.EasingStyle.Back):Play()
createTween(MainFrame, {BackgroundTransparency = 0}, 0.3):Play()

-- Fetch data
task.spawn(function()
    task.wait(0.5) -- tunggu animasi selesai
    
    LoadingText.Text = "Mengunduh kamus KBBI dari GitHub..."
    local success = fetchKBBI()
    
    if success then
        -- Complete loading bar
        createTween(LoadingBarFill, {Size = UDim2.new(1, 0, 1, 0)}, 0.3):Play()
        LoadingText.Text = "✅ Berhasil! Memuat " .. formatNumber(#allWords) .. " kata"
        LoadingBarFill.BackgroundColor3 = Color3.fromRGB(76, 175, 80)
        
        isLoaded = true
        task.wait(1)
        showDifficultyPage()
    else
        LoadingText.Text = "❌ Gagal mengunduh! Cek URL GitHub"
        LoadingBarFill.BackgroundColor3 = Color3.fromRGB(244, 67, 54)
        createTween(LoadingBarFill, {Size = UDim2.new(1, 0, 1, 0)}, 0.3):Play()
    end
end)

------------------------------------------------------------
print("═══════════════════════════════════════════")
print("  🔤 SAMBUNG KATA - KBBI Edition Loaded!")
print("  Tekan Right Shift untuk Show/Hide GUI")
print("═══════════════════════════════════════════")
