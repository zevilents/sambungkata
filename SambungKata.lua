--[[
    ╔══════════════════════════════════════════════════════════════╗
    ║              SAMBUNG KATA - KBBI EDITION v3                 ║
    ║         Script by: Antigravity AI Assistant                 ║
    ║     Inject via Executor | Data dari GitHub (kbbi.txt)       ║
    ║     ✅ Responsive: Desktop & Mobile compatible              ║
    ╚══════════════════════════════════════════════════════════════╝
    
    CARA PAKAI:
    1. Upload file kbbi.txt ke GitHub repository kamu
    2. Ganti URL_KBBI di bawah dengan raw link GitHub kamu
    3. Inject script ini via executor
    4. Aktifkan filter akhiran untuk menyaring kata
    5. Ketik huruf awal, script akan menampilkan kata lanjutan
    
    FILTER AKHIRAN:
    - Akhiran 1 : a,i,u,e,o,n,r,s,k,t,l,b,d,g,h,p,m,v,w,x,y,z,j,c
    - Akhiran 2 : AH, UH, KS, IA, IO, OI, IF, NG
--]]

------------------------------------------------------------
-- CONFIG
------------------------------------------------------------
local URL_KBBI = "https://raw.githubusercontent.com/zevilents/sambungkata/main/kbbi.txt"

local MAX_RESULTS = 150
local CHAIN_LENGTH = 2
local AUTOTYPE_ENABLED = true

-- Speed modes
local SPEED_MODES = {
    { name = "Slow",   delay = 0.22, icon = "🐢", color = Color3.fromRGB(245, 158, 11) },
    { name = "Normal", delay = 0.07, icon = "🚶", color = Color3.fromRGB(59, 130, 246) },
    { name = "Cepat",  delay = 0.02, icon = "⚡", color = Color3.fromRGB(16, 185, 129) },
}
local currentSpeedIndex = 2

------------------------------------------------------------
-- ENDING FILTERS
------------------------------------------------------------
local ENDING_1 = { "a","i","u","e","o","n","r","s","k","t","l","b","d","g","h","p","m","v","w","x","y","z","j","c" }
local ENDING_2 = {
    { suffix = "ah", label = "AH" },
    { suffix = "uh", label = "UH" },
    { suffix = "ks", label = "KS" },
    { suffix = "ia", label = "IA" },
    { suffix = "io", label = "IO" },
    { suffix = "oi", label = "OI" },
    { suffix = "if", label = "IF" },
    { suffix = "ng", label = "NG" },
}

local ending1Enabled = {}
for _, ch in ipairs(ENDING_1) do ending1Enabled[ch] = false end

local ending2Enabled = {}
for _, ef in ipairs(ENDING_2) do ending2Enabled[ef.suffix] = false end

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
-- RESPONSIVE: Detect platform & compute sizes
------------------------------------------------------------
local Camera = workspace.CurrentCamera
local viewportSize = Camera.ViewportSize
local isMobile = (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled)
    or viewportSize.X < 800

-- Responsive sizing
local UI_WIDTH = isMobile and math.min(viewportSize.X - 10, 320) or 480
local UI_HEIGHT = isMobile and math.min(viewportSize.Y - 10, 480) or 650
local FONT_TITLE = isMobile and 12 or 16
local FONT_BODY = isMobile and 10 or 14
local FONT_SMALL = isMobile and 8 or 10
local FONT_TINY = isMobile and 7 or 9
local PAD = isMobile and 6 or 12
local BTN_H = isMobile and 22 or 36
local TAG_H = isMobile and 15 or 22
local TAG_W1 = isMobile and 18 or 28
local TAG_GAP = isMobile and 1 or 3
local TAG_W2_MULT = isMobile and 6 or 9
local SEARCH_H = isMobile and 28 or 40
local RESULT_H = isMobile and 26 or 38
local TITLE_H = isMobile and 36 or 52
local ROW_H = isMobile and 20 or 28
local CORNER = isMobile and 8 or 16

------------------------------------------------------------
-- COLOR PALETTE (Light Modern Theme)
------------------------------------------------------------
local C = {
    bg          = Color3.fromRGB(248, 250, 252),
    card        = Color3.fromRGB(255, 255, 255),
    cardHover   = Color3.fromRGB(241, 245, 249),
    border      = Color3.fromRGB(226, 232, 240),
    borderLight = Color3.fromRGB(241, 245, 249),
    text        = Color3.fromRGB(15, 23, 42),
    textSub     = Color3.fromRGB(100, 116, 139),
    textMuted   = Color3.fromRGB(148, 163, 184),
    accent      = Color3.fromRGB(79, 70, 229),
    accentLight = Color3.fromRGB(238, 242, 255),
    success     = Color3.fromRGB(16, 185, 129),
    successBg   = Color3.fromRGB(236, 253, 245),
    danger      = Color3.fromRGB(239, 68, 68),
    dangerBg    = Color3.fromRGB(254, 242, 242),
    warn        = Color3.fromRGB(245, 158, 11),
    warnBg      = Color3.fromRGB(255, 251, 235),
    cyan        = Color3.fromRGB(6, 182, 212),
    cyanBg      = Color3.fromRGB(236, 254, 255),
    purple      = Color3.fromRGB(139, 92, 246),
    purpleBg    = Color3.fromRGB(245, 243, 255),
    orange      = Color3.fromRGB(249, 115, 22),
    orangeBg    = Color3.fromRGB(255, 247, 237),
    tagActive   = Color3.fromRGB(79, 70, 229),
    tagInactive = Color3.fromRGB(241, 245, 249),
}

------------------------------------------------------------
-- DATA
------------------------------------------------------------
local allWords = {}
local chainHistory = {}
local currentChainWord = nil
local score = 0
local isLoaded = false
local isChainMode = false
local isTyping = false
local stopTyping = false
local lastTypedPrefix = ""
local autoDetectEnabled = true
local lastDetectedLetter = ""
local usedWords = {}
local usedWordsCount = 0
local lastTypedLength = 0

------------------------------------------------------------
-- UTILITY
------------------------------------------------------------
local function createTween(inst, props, dur, style, dir)
    return TweenService:Create(inst,
        TweenInfo.new(dur or 0.2, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
        props
    )
end

local function startsWith(str, prefix)
    return string.sub(str, 1, #prefix) == prefix
end

local function getLastChars(str, n)
    if #str < n then return str end
    return string.sub(str, -n)
end

local function formatNumber(n)
    local s = tostring(n)
    local pos = #s % 3
    if pos == 0 then pos = 3 end
    local result = string.sub(s, 1, pos)
    for i = pos + 1, #s, 3 do
        result = result .. "." .. string.sub(s, i, i + 2)
    end
    return result
end

------------------------------------------------------------
-- ENDING FILTER LOGIC
------------------------------------------------------------
local function isAnyEndingOn()
    for _, ch in ipairs(ENDING_1) do
        if ending1Enabled[ch] then return true end
    end
    for _, ef in ipairs(ENDING_2) do
        if ending2Enabled[ef.suffix] then return true end
    end
    return false
end

local function matchesEnding(word)
    for _, ef in ipairs(ENDING_2) do
        if ending2Enabled[ef.suffix] then
            local sfx = ef.suffix
            if #word >= #sfx and string.sub(word, -#sfx) == sfx then
                return true
            end
        end
    end
    for _, ch in ipairs(ENDING_1) do
        if ending1Enabled[ch] then
            if #word >= 1 and string.sub(word, -1) == ch then
                return true
            end
        end
    end
    return false
end

------------------------------------------------------------
-- AUTO-DETECT LETTER FROM GAME UI
------------------------------------------------------------
local function getAllTextElements(root)
    local elements = {}
    for _, desc in ipairs(root:GetDescendants()) do
        if desc:IsA("TextLabel") or desc:IsA("TextButton") then
            table.insert(elements, desc)
        end
    end
    return elements
end

local function isEffectivelyVisible(inst)
    local current = inst
    while current do
        if current:IsA("GuiObject") then
            if current.Visible == false then return false end
        end
        if current:IsA("ScreenGui") then break end
        current = current.Parent
    end
    return true
end

local function getAncestorContainer(inst, maxLevels)
    maxLevels = maxLevels or 6
    local current = inst.Parent
    local level = 0
    while current and level < maxLevels do
        if current:IsA("ScreenGui") then return current end
        if current:IsA("Frame") or current:IsA("SurfaceGui") or current:IsA("BillboardGui") then
            return current
        end
        current = current.Parent
        level = level + 1
    end
    return inst.Parent
end

local function scanForLetter()
    local detected = nil
    for _, gui in ipairs(playerGui:GetChildren()) do
        if gui:IsA("ScreenGui") and gui.Name ~= "SambungKataGUI" then
            local allTexts = getAllTextElements(gui)
            local anchorElement = nil
            for _, elem in ipairs(allTexts) do
                if elem.Text and isEffectivelyVisible(elem) then
                    local t = elem.Text
                    if t:lower():find("hurufnya%s+adalah") then
                        anchorElement = elem
                        local letter = t:match("[Hh]urufnya%s+adalah%s*:?%s*(%a+)")
                        if letter and #letter >= 1 and #letter <= 3 then
                            detected = letter:upper(); break
                        end
                        letter = t:match("%s(%a+)%s*$")
                        if letter and #letter >= 1 and #letter <= 3 then
                            detected = letter:upper(); break
                        end
                        break
                    end
                end
            end
            if anchorElement and not detected then
                local parent = anchorElement.Parent
                if parent then
                    for _, child in ipairs(parent:GetChildren()) do
                        if child ~= anchorElement and (child:IsA("TextLabel") or child:IsA("TextButton")) then
                            local ct = child.Text
                            if ct and #ct >= 1 and #ct <= 3 and ct:match("^%a+$") and isEffectivelyVisible(child) then
                                detected = ct:upper(); break
                            end
                        end
                    end
                end
                if not detected and parent and parent.Parent then
                    for _, desc in ipairs(parent.Parent:GetDescendants()) do
                        if desc ~= anchorElement and (desc:IsA("TextLabel") or desc:IsA("TextButton")) then
                            local ct = desc.Text
                            if ct and #ct >= 1 and #ct <= 3 and ct:match("^%a+$") and isEffectivelyVisible(desc) then
                                detected = ct:upper(); break
                            end
                        end
                    end
                end
                if not detected then
                    local searchRoot = anchorElement.Parent
                    for level = 1, 4 do
                        if not searchRoot or searchRoot:IsA("ScreenGui") then break end
                        searchRoot = searchRoot.Parent
                        if searchRoot then
                            for _, desc in ipairs(searchRoot:GetDescendants()) do
                                if desc ~= anchorElement and (desc:IsA("TextLabel") or desc:IsA("TextButton")) then
                                    local ct = desc.Text
                                    if ct and #ct >= 1 and #ct <= 3 and ct:match("^%a+$") and isEffectivelyVisible(desc) then
                                        detected = ct:upper(); break
                                    end
                                end
                            end
                            if detected then break end
                        end
                    end
                end
            end
            if not detected then
                for _, elem in ipairs(allTexts) do
                    if elem.Text and isEffectivelyVisible(elem) then
                        local letter = elem.Text:match("[Hh]uruf%s*:%s*(%a+)")
                        if letter and #letter >= 1 and #letter <= 3 then
                            detected = letter:upper(); break
                        end
                    end
                end
            end
            if not detected then
                for _, elem in ipairs(allTexts) do
                    if elem.Text and elem.Text:lower():find("waktu bermain") and isEffectivelyVisible(elem) then
                        local container = getAncestorContainer(elem, 4)
                        if container then
                            for _, desc in ipairs(container:GetDescendants()) do
                                if (desc:IsA("TextLabel") or desc:IsA("TextButton")) then
                                    local ct = desc.Text
                                    if ct and #ct >= 1 and #ct <= 3 and ct:match("^%a+$") and isEffectivelyVisible(desc) then
                                        if desc.TextSize >= 20 then detected = ct:upper(); break end
                                    end
                                end
                            end
                            if not detected then
                                for _, desc in ipairs(container:GetDescendants()) do
                                    if (desc:IsA("TextLabel") or desc:IsA("TextButton")) then
                                        local ct = desc.Text
                                        if ct and #ct >= 1 and #ct <= 3 and ct:match("^%a+$") and isEffectivelyVisible(desc) then
                                            detected = ct:upper(); break
                                        end
                                    end
                                end
                            end
                        end
                        break
                    end
                end
            end
            if detected then break end
        end
    end
    return detected
end

local updateDetectStatus = nil

------------------------------------------------------------
-- AUTOTYPE ENGINE
------------------------------------------------------------
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
    if isTyping then stopTyping = true; task.wait(0.1) end
    local remaining = ""
    if #prefix > 0 and startsWith(text, prefix) then
        remaining = string.sub(text, #prefix + 1)
    else
        remaining = text
    end
    if #remaining == 0 then return end
    
    lastTypedLength = #remaining
    
    isTyping = true
    stopTyping = false
    if updateTypingStatus then updateTypingStatus(true, remaining, 0) end
    task.spawn(function()
        for idx = 1, #remaining do
            if stopTyping then break end
            simulateKeyPress(string.sub(remaining, idx, idx))
            if updateTypingStatus then updateTypingStatus(true, remaining, idx) end
            task.wait(SPEED_MODES[currentSpeedIndex].delay)
        end
        if not stopTyping then
            task.wait(0.05)
            pcall(function()
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
                task.wait(0.01)
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
            end)
        end
        isTyping = false
        stopTyping = false
        if updateTypingStatus then updateTypingStatus(false, "", 0) end
    end)
end

------------------------------------------------------------
-- FETCH KBBI
------------------------------------------------------------
local function fetchKBBI()
    local success, result = pcall(function()
        if game.HttpGet then return game:HttpGet(URL_KBBI)
        else return HttpService:GetAsync(URL_KBBI) end
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
                count = count + 1
            end
        end
    end
    table.sort(allWords)
    print("[SambungKata] Berhasil memuat " .. formatNumber(count) .. " kata!")
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
    local filterEnding = isAnyEndingOn()
    for _, word in ipairs(allWords) do
        if startsWith(word, prefix) then
            if not usedWords[word] then
                if not filterEnding or matchesEnding(word) then
                    table.insert(results, word)
                end
            end
        end
    end
    
    -- Sort by string length ascending, then alphabetical
    table.sort(results, function(a, b)
        if #a == #b then
            return a < b
        else
            return #a < #b
        end
    end)
    
    if #results > maxResults then
        local sliced = {}
        for i = 1, maxResults do
            sliced[i] = results[i]
        end
        return sliced
    end
    
    return results
end

------------------------------------------------------------
-- GUI — RESPONSIVE MODERN LIGHT THEME
------------------------------------------------------------
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "SambungKataGUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function() ScreenGui.Parent = (gethui and gethui()) or playerGui end)
if not ScreenGui.Parent then ScreenGui.Parent = playerGui end

-- Shadow
local Shadow = Instance.new("ImageLabel")
Shadow.Name = "Shadow"
Shadow.Size = UDim2.new(0, UI_WIDTH + 40, 0, UI_HEIGHT + 40)
Shadow.Position = UDim2.new(0.5, -(UI_WIDTH+40)/2, 0.5, -(UI_HEIGHT+40)/2)
Shadow.BackgroundTransparency = 1
Shadow.ImageTransparency = 0.7
Shadow.Image = "rbxassetid://5554236805"
Shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
Shadow.ScaleType = Enum.ScaleType.Slice
Shadow.SliceCenter = Rect.new(23, 23, 277, 277)
Shadow.Parent = ScreenGui

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, UI_WIDTH, 0, UI_HEIGHT)
MainFrame.Position = UDim2.new(0.5, -UI_WIDTH/2, 0.5, -UI_HEIGHT/2)
MainFrame.BackgroundColor3 = C.bg
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, CORNER)

local MainStroke = Instance.new("UIStroke", MainFrame)
MainStroke.Color = C.border
MainStroke.Thickness = 1

MainFrame:GetPropertyChangedSignal("Position"):Connect(function()
    Shadow.Position = UDim2.new(
        MainFrame.Position.X.Scale, MainFrame.Position.X.Offset - 20,
        MainFrame.Position.Y.Scale, MainFrame.Position.Y.Offset - 20
    )
end)

-- Sync shadow size with MainFrame size
MainFrame:GetPropertyChangedSignal("Size"):Connect(function()
    Shadow.Size = UDim2.new(
        0, MainFrame.Size.X.Offset + 40,
        0, MainFrame.Size.Y.Offset + 40
    )
end)

-- ====== RESIZE HANDLE ======
local MIN_W, MIN_H = isMobile and 240 or 280, isMobile and 300 or 350
local MAX_W = math.max(viewportSize.X - 20, 500)
local MAX_H = math.max(viewportSize.Y - 20, 500)

local ResizeHandle = Instance.new("TextButton")
ResizeHandle.Name = "ResizeHandle"
ResizeHandle.Size = UDim2.new(0, 20, 0, 20)
ResizeHandle.Position = UDim2.new(1, -20, 1, -20)
ResizeHandle.BackgroundTransparency = 1
ResizeHandle.Text = "⟊"
ResizeHandle.TextColor3 = C.textMuted
ResizeHandle.TextSize = 14
ResizeHandle.Font = Enum.Font.GothamBold
ResizeHandle.BorderSizePixel = 0
ResizeHandle.AutoButtonColor = false
ResizeHandle.ZIndex = 10
ResizeHandle.Parent = MainFrame

-- Visual resize grip (3 dots pattern)
local grip1 = Instance.new("Frame")
grip1.Size = UDim2.new(0, 3, 0, 3)
grip1.Position = UDim2.new(1, -7, 1, -7)
grip1.BackgroundColor3 = C.textMuted
grip1.BorderSizePixel = 0
grip1.ZIndex = 10
grip1.Parent = MainFrame
Instance.new("UICorner", grip1).CornerRadius = UDim.new(1, 0)

local grip2 = Instance.new("Frame")
grip2.Size = UDim2.new(0, 3, 0, 3)
grip2.Position = UDim2.new(1, -13, 1, -7)
grip2.BackgroundColor3 = C.textMuted
grip2.BorderSizePixel = 0
grip2.ZIndex = 10
grip2.Parent = MainFrame
Instance.new("UICorner", grip2).CornerRadius = UDim.new(1, 0)

local grip3 = Instance.new("Frame")
grip3.Size = UDim2.new(0, 3, 0, 3)
grip3.Position = UDim2.new(1, -7, 1, -13)
grip3.BackgroundColor3 = C.textMuted
grip3.BorderSizePixel = 0
grip3.ZIndex = 10
grip3.Parent = MainFrame
Instance.new("UICorner", grip3).CornerRadius = UDim.new(1, 0)

local resizing = false
local resizeStart = nil
local resizeStartSize = nil

ResizeHandle.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        resizing = true
        resizeStart = input.Position
        resizeStartSize = Vector2.new(MainFrame.Size.X.Offset, MainFrame.Size.Y.Offset)
    end
end)

ResizeHandle.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        resizing = false
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if resizing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - resizeStart
        local newW = math.clamp(resizeStartSize.X + delta.X, MIN_W, MAX_W)
        local newH = math.clamp(resizeStartSize.Y + delta.Y, MIN_H, MAX_H)
        MainFrame.Size = UDim2.new(0, newW, 0, newH)
    end
end)

-- Hover effect for resize handle
ResizeHandle.MouseEnter:Connect(function()
    createTween(grip1, {BackgroundColor3 = C.accent}, 0.1):Play()
    createTween(grip2, {BackgroundColor3 = C.accent}, 0.1):Play()
    createTween(grip3, {BackgroundColor3 = C.accent}, 0.1):Play()
end)
ResizeHandle.MouseLeave:Connect(function()
    if not resizing then
        createTween(grip1, {BackgroundColor3 = C.textMuted}, 0.1):Play()
        createTween(grip2, {BackgroundColor3 = C.textMuted}, 0.1):Play()
        createTween(grip3, {BackgroundColor3 = C.textMuted}, 0.1):Play()
    end
end)

-- ====== TITLE BAR ======
local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, TITLE_H)
TitleBar.BackgroundColor3 = C.card
TitleBar.BorderSizePixel = 0
TitleBar.Parent = MainFrame
Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, CORNER)

local TitleEdge = Instance.new("Frame")
TitleEdge.Size = UDim2.new(1, 0, 0, CORNER)
TitleEdge.Position = UDim2.new(0, 0, 1, -CORNER)
TitleEdge.BackgroundColor3 = C.card
TitleEdge.BorderSizePixel = 0
TitleEdge.Parent = TitleBar

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -90, 1, 0)
TitleLabel.Position = UDim2.new(0, PAD, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "🔤 Sambung Kata"
TitleLabel.TextColor3 = C.text
TitleLabel.TextSize = FONT_TITLE
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = TitleBar

local closeSz = isMobile and 24 or 30
local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, closeSz, 0, closeSz)
CloseBtn.Position = UDim2.new(1, -closeSz-PAD, 0, (TITLE_H-closeSz)/2)
CloseBtn.BackgroundColor3 = C.dangerBg
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = C.danger
CloseBtn.TextSize = isMobile and 10 or 12
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.BorderSizePixel = 0
CloseBtn.AutoButtonColor = false
CloseBtn.Parent = TitleBar
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 8)

local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, closeSz, 0, closeSz)
MinBtn.Position = UDim2.new(1, -closeSz*2-PAD-4, 0, (TITLE_H-closeSz)/2)
MinBtn.BackgroundColor3 = C.warnBg
MinBtn.Text = "—"
MinBtn.TextColor3 = C.warn
MinBtn.TextSize = isMobile and 10 or 12
MinBtn.Font = Enum.Font.GothamBold
MinBtn.BorderSizePixel = 0
MinBtn.AutoButtonColor = false
MinBtn.Parent = TitleBar
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0, 8)

-- Separator
local Sep = Instance.new("Frame")
Sep.Size = UDim2.new(1, 0, 0, 1)
Sep.Position = UDim2.new(0, 0, 0, TITLE_H)
Sep.BackgroundColor3 = C.border
Sep.BorderSizePixel = 0
Sep.Parent = MainFrame

-- ====== CONTENT ======
local Content = Instance.new("Frame")
Content.Name = "Content"
Content.Size = UDim2.new(1, -PAD*2, 1, -(TITLE_H + 4))
Content.Position = UDim2.new(0, PAD, 0, TITLE_H + 2)
Content.BackgroundTransparency = 1
Content.ClipsDescendants = true
Content.Parent = MainFrame

-- ====== LOADING PAGE ======
local LoadingPage = Instance.new("Frame")
LoadingPage.Size = UDim2.new(1, 0, 1, 0)
LoadingPage.BackgroundTransparency = 1
LoadingPage.Parent = Content

local LdIcon = Instance.new("TextLabel")
LdIcon.Size = UDim2.new(1, 0, 0, 50)
LdIcon.Position = UDim2.new(0, 0, 0.35, -25)
LdIcon.BackgroundTransparency = 1
LdIcon.Text = "📚"
LdIcon.TextSize = isMobile and 36 or 42
LdIcon.Parent = LoadingPage

local LdText = Instance.new("TextLabel")
LdText.Size = UDim2.new(1, 0, 0, 24)
LdText.Position = UDim2.new(0, 0, 0.35, 30)
LdText.BackgroundTransparency = 1
LdText.Text = "Memuat kamus KBBI..."
LdText.TextColor3 = C.textSub
LdText.TextSize = FONT_BODY
LdText.Font = Enum.Font.Gotham
LdText.Parent = LoadingPage

local LdBarBg = Instance.new("Frame")
LdBarBg.Size = UDim2.new(0.6, 0, 0, 6)
LdBarBg.Position = UDim2.new(0.2, 0, 0.35, 62)
LdBarBg.BackgroundColor3 = C.borderLight
LdBarBg.BorderSizePixel = 0
LdBarBg.Parent = LoadingPage
Instance.new("UICorner", LdBarBg).CornerRadius = UDim.new(0, 3)

local LdBarFill = Instance.new("Frame")
LdBarFill.Size = UDim2.new(0, 0, 1, 0)
LdBarFill.BackgroundColor3 = C.accent
LdBarFill.BorderSizePixel = 0
LdBarFill.Parent = LdBarBg
Instance.new("UICorner", LdBarFill).CornerRadius = UDim.new(0, 3)

-- ====== GAME PAGE ======
local GamePage = Instance.new("Frame")
GamePage.Name = "GamePage"
GamePage.Size = UDim2.new(1, 0, 1, 0)
GamePage.BackgroundTransparency = 1
GamePage.Visible = false
GamePage.Parent = Content

-- Track Y cursor for vertical layout
local yPos = 0

-- Helper: create a pill button
local function createPill(parent, text, pos, size, active, activeBg, activeText, inactiveBg, inactiveText)
    local btn = Instance.new("TextButton")
    btn.Size = size
    btn.Position = pos
    btn.BackgroundColor3 = active and activeBg or inactiveBg
    btn.Text = text
    btn.TextColor3 = active and activeText or inactiveText
    btn.TextSize = FONT_SMALL
    btn.Font = Enum.Font.GothamBold
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.Parent = parent
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    return btn
end

-- ---- ROW: Mode buttons ----
local ModeRow = Instance.new("Frame")
ModeRow.Size = UDim2.new(1, 0, 0, BTN_H)
ModeRow.Position = UDim2.new(0, 0, 0, yPos)
ModeRow.BackgroundTransparency = 1
ModeRow.Parent = GamePage

local modeBtnW = isMobile and 75 or 130
local modeChainW = isMobile and 85 or 140
local delBtnW = isMobile and 50 or 70

local ModeSearchBtn = createPill(ModeRow, "🔍 Cari Kata",
    UDim2.new(0, 0, 0, 0), UDim2.new(0, modeBtnW, 1, 0),
    true, C.accent, Color3.fromRGB(255,255,255), C.accentLight, C.accent)

local ModeChainBtn = createPill(ModeRow, "🔗 Sambung Kata",
    UDim2.new(0, modeBtnW + 4, 0, 0), UDim2.new(0, modeChainW, 1, 0),
    false, C.purple, Color3.fromRGB(255,255,255), C.purpleBg, C.purple)

local DeleteBtn = createPill(ModeRow, "⌫ Hapus",
    UDim2.new(0, modeBtnW + modeChainW + 8, 0, 0), UDim2.new(0, delBtnW, 1, 0),
    false, C.dangerBg, C.danger, C.dangerBg, C.danger)

-- Delete logic
DeleteBtn.MouseButton1Click:Connect(function()
    createTween(DeleteBtn, {BackgroundColor3 = C.danger, TextColor3 = Color3.fromRGB(255,255,255)}, 0.1):Play()
    task.delay(0.2, function() createTween(DeleteBtn, {BackgroundColor3 = C.dangerBg, TextColor3 = C.danger}, 0.2):Play() end)
    
    if lastTypedLength > 0 then
        task.spawn(function()
            for i = 1, lastTypedLength do
                pcall(function()
                    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Backspace, false, game)
                    task.wait(0.01)
                    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Backspace, false, game)
                end)
                task.wait(SPEED_MODES[currentSpeedIndex].delay / 2)
            end
            lastTypedLength = 0 -- Reset after deletion
        end)
    end
end)
DeleteBtn.MouseEnter:Connect(function() createTween(DeleteBtn, {BackgroundColor3 = C.danger, TextColor3 = Color3.fromRGB(255,255,255)}, 0.1):Play() end)
DeleteBtn.MouseLeave:Connect(function() createTween(DeleteBtn, {BackgroundColor3 = C.dangerBg, TextColor3 = C.danger}, 0.1):Play() end)

local ScoreLabel = Instance.new("TextLabel")
ScoreLabel.Size = UDim2.new(0, 70, 0, 24)
ScoreLabel.Position = UDim2.new(1, -70, 0, (BTN_H - 24)/2)
ScoreLabel.BackgroundColor3 = C.warnBg
ScoreLabel.Text = "Skor: 0"
ScoreLabel.TextColor3 = C.warn
ScoreLabel.TextSize = FONT_SMALL
ScoreLabel.Font = Enum.Font.GothamBold
ScoreLabel.Visible = false
ScoreLabel.Parent = ModeRow
Instance.new("UICorner", ScoreLabel).CornerRadius = UDim.new(0, 8)

yPos = yPos + BTN_H + 4

-- ---- ROW: Auto-Detect ----
local DetectRow = Instance.new("Frame")
DetectRow.Size = UDim2.new(1, 0, 0, ROW_H)
DetectRow.Position = UDim2.new(0, 0, 0, yPos)
DetectRow.BackgroundTransparency = 1
DetectRow.Parent = GamePage

local detectBtnW = isMobile and 70 or 110
local DetectToggle = createPill(DetectRow, "📷 Auto-Detect",
    UDim2.new(0, 0, 0, 0), UDim2.new(0, detectBtnW, 1, 0),
    true, C.cyan, Color3.fromRGB(255,255,255), C.cyanBg, C.cyan)

local DetectStatusBg = Instance.new("Frame")
DetectStatusBg.Size = UDim2.new(1, -(detectBtnW + 40), 1, 0)
DetectStatusBg.Position = UDim2.new(0, detectBtnW + 4, 0, 0)
DetectStatusBg.BackgroundColor3 = C.cardHover
DetectStatusBg.BorderSizePixel = 0
DetectStatusBg.Parent = DetectRow
Instance.new("UICorner", DetectStatusBg).CornerRadius = UDim.new(0, 8)

local DetectStatusLabel = Instance.new("TextLabel")
DetectStatusLabel.Size = UDim2.new(1, -10, 1, 0)
DetectStatusLabel.Position = UDim2.new(0, 6, 0, 0)
DetectStatusLabel.BackgroundTransparency = 1
DetectStatusLabel.Text = "🔎 Menunggu huruf..."
DetectStatusLabel.TextColor3 = C.textMuted
DetectStatusLabel.TextSize = FONT_TINY
DetectStatusLabel.Font = Enum.Font.Gotham
DetectStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
DetectStatusLabel.Parent = DetectStatusBg

local badgeSz = isMobile and 18 or 28
local DetectBadge = Instance.new("TextLabel")
DetectBadge.Size = UDim2.new(0, badgeSz, 1, 0)
DetectBadge.Position = UDim2.new(1, -badgeSz-2, 0, 0)
DetectBadge.BackgroundColor3 = C.accentLight
DetectBadge.Text = "?"
DetectBadge.TextColor3 = C.accent
DetectBadge.TextSize = isMobile and 11 or 13
DetectBadge.Font = Enum.Font.GothamBold
DetectBadge.Parent = DetectRow
Instance.new("UICorner", DetectBadge).CornerRadius = UDim.new(0, 8)

updateDetectStatus = function(letter)
    if letter then
        DetectStatusLabel.Text = "✅ Terdeteksi: " .. letter
        DetectStatusLabel.TextColor3 = C.success
        DetectBadge.Text = letter
        DetectBadge.BackgroundColor3 = C.successBg
        DetectBadge.TextColor3 = C.success
    else
        DetectStatusLabel.Text = "🔎 Menunggu huruf..."
        DetectStatusLabel.TextColor3 = C.textMuted
        DetectBadge.Text = "?"
        DetectBadge.BackgroundColor3 = C.accentLight
        DetectBadge.TextColor3 = C.accent
    end
end

DetectToggle.MouseButton1Click:Connect(function()
    autoDetectEnabled = not autoDetectEnabled
    if autoDetectEnabled then
        createTween(DetectToggle, {BackgroundColor3 = C.cyan, TextColor3 = Color3.fromRGB(255,255,255)}, 0.15):Play()
        DetectToggle.Text = "📷 Auto-Detect"
    else
        createTween(DetectToggle, {BackgroundColor3 = C.cyanBg, TextColor3 = C.cyan}, 0.15):Play()
        DetectToggle.Text = "📷 Detect OFF"
        updateDetectStatus(nil)
        lastDetectedLetter = ""
    end
end)

yPos = yPos + ROW_H + 4

-- ---- SECTION: Akhiran 1 (single char) ----
local Akh1Frame = Instance.new("Frame")
Akh1Frame.BackgroundColor3 = C.card
Akh1Frame.BorderSizePixel = 0
Akh1Frame.Parent = GamePage
Instance.new("UICorner", Akh1Frame).CornerRadius = UDim.new(0, 10)
local Akh1Stroke = Instance.new("UIStroke", Akh1Frame)
Akh1Stroke.Color = C.border
Akh1Stroke.Thickness = 1

local Akh1Title = Instance.new("TextLabel")
Akh1Title.Size = UDim2.new(0, 70, 0, 14)
Akh1Title.Position = UDim2.new(0, 6, 0, 2)
Akh1Title.BackgroundTransparency = 1
Akh1Title.Text = "Akhiran 1"
Akh1Title.TextColor3 = C.textSub
Akh1Title.TextSize = FONT_TINY
Akh1Title.Font = Enum.Font.GothamBold
Akh1Title.TextXAlignment = Enum.TextXAlignment.Left
Akh1Title.Parent = Akh1Frame

local ending1Buttons = {}
local e1x = 4
local e1y = 16
local e1MaxW = UI_WIDTH - PAD * 2 - 8

for _, ch in ipairs(ENDING_1) do
    if e1x + TAG_W1 > e1MaxW then
        e1x = 4
        e1y = e1y + TAG_H + TAG_GAP
    end
    local eBtn = Instance.new("TextButton")
    eBtn.Name = "E1_" .. ch
    eBtn.Size = UDim2.new(0, TAG_W1, 0, TAG_H)
    eBtn.Position = UDim2.new(0, e1x, 0, e1y)
    eBtn.BackgroundColor3 = C.tagInactive
    eBtn.Text = ch:upper()
    eBtn.TextColor3 = C.textMuted
    eBtn.TextSize = FONT_TINY
    eBtn.Font = Enum.Font.GothamBold
    eBtn.BorderSizePixel = 0
    eBtn.AutoButtonColor = false
    eBtn.Parent = Akh1Frame
    Instance.new("UICorner", eBtn).CornerRadius = UDim.new(0, 5)
    ending1Buttons[ch] = eBtn
    e1x = e1x + TAG_W1 + TAG_GAP
end

local akh1Height = e1y + TAG_H + 4
Akh1Frame.Size = UDim2.new(1, 0, 0, akh1Height)
Akh1Frame.Position = UDim2.new(0, 0, 0, yPos)

yPos = yPos + akh1Height + 4

-- ---- SECTION: Akhiran 2 (multi char) ----
local Akh2Frame = Instance.new("Frame")
Akh2Frame.BackgroundColor3 = C.card
Akh2Frame.BorderSizePixel = 0
Akh2Frame.Parent = GamePage
Instance.new("UICorner", Akh2Frame).CornerRadius = UDim.new(0, 10)
local Akh2Stroke = Instance.new("UIStroke", Akh2Frame)
Akh2Stroke.Color = C.border
Akh2Stroke.Thickness = 1

local Akh2Title = Instance.new("TextLabel")
Akh2Title.Size = UDim2.new(0, 70, 0, 14)
Akh2Title.Position = UDim2.new(0, 6, 0, 2)
Akh2Title.BackgroundTransparency = 1
Akh2Title.Text = "Akhiran 2"
Akh2Title.TextColor3 = C.textSub
Akh2Title.TextSize = FONT_TINY
Akh2Title.Font = Enum.Font.GothamBold
Akh2Title.TextXAlignment = Enum.TextXAlignment.Left
Akh2Title.Parent = Akh2Frame

local ending2Buttons = {}
local e2x = 4
local e2y = 16
for _, ef in ipairs(ENDING_2) do
    local btnW = #ef.label * TAG_W2_MULT + 12
    if btnW < 30 then btnW = 30 end
    if e2x + btnW > e1MaxW then
        e2x = 4
        e2y = e2y + TAG_H + TAG_GAP
    end
    local eBtn = Instance.new("TextButton")
    eBtn.Name = "E2_" .. ef.suffix
    eBtn.Size = UDim2.new(0, btnW, 0, TAG_H)
    eBtn.Position = UDim2.new(0, e2x, 0, e2y)
    eBtn.BackgroundColor3 = C.tagInactive
    eBtn.Text = ef.label
    eBtn.TextColor3 = C.textMuted
    eBtn.TextSize = FONT_TINY
    eBtn.Font = Enum.Font.GothamBold
    eBtn.BorderSizePixel = 0
    eBtn.AutoButtonColor = false
    eBtn.Parent = Akh2Frame
    Instance.new("UICorner", eBtn).CornerRadius = UDim.new(0, 5)
    ending2Buttons[ef.suffix] = eBtn
    e2x = e2x + btnW + 4
end

local akh2Height = e2y + TAG_H + 4
Akh2Frame.Size = UDim2.new(1, 0, 0, akh2Height)
Akh2Frame.Position = UDim2.new(0, 0, 0, yPos)

yPos = yPos + akh2Height + 4

-- ---- Toggle visuals & handlers ----
local function updateEndingVisuals()
    for ch, btn in pairs(ending1Buttons) do
        local on = ending1Enabled[ch]
        createTween(btn, {
            BackgroundColor3 = on and C.accent or C.tagInactive,
            TextColor3 = on and Color3.fromRGB(255,255,255) or C.textMuted
        }, 0.12):Play()
    end
    for sfx, btn in pairs(ending2Buttons) do
        local on = ending2Enabled[sfx]
        createTween(btn, {
            BackgroundColor3 = on and C.orange or C.tagInactive,
            TextColor3 = on and Color3.fromRGB(255,255,255) or C.textMuted
        }, 0.12):Play()
    end
end

-- Forward declarations
local SearchInput, displayResults

for ch, btn in pairs(ending1Buttons) do
    btn.MouseButton1Click:Connect(function()
        ending1Enabled[ch] = not ending1Enabled[ch]
        updateEndingVisuals()
        if SearchInput and #SearchInput.Text:gsub("%s+","") >= 1 then
            displayResults(searchWords(SearchInput.Text:lower():gsub("%s+",""), MAX_RESULTS))
        end
    end)
    btn.MouseEnter:Connect(function()
        if not ending1Enabled[ch] then createTween(btn, {BackgroundColor3 = C.borderLight}, 0.08):Play() end
    end)
    btn.MouseLeave:Connect(function()
        if not ending1Enabled[ch] then createTween(btn, {BackgroundColor3 = C.tagInactive}, 0.08):Play() end
    end)
end

for _, ef in ipairs(ENDING_2) do
    local btn = ending2Buttons[ef.suffix]
    btn.MouseButton1Click:Connect(function()
        ending2Enabled[ef.suffix] = not ending2Enabled[ef.suffix]
        updateEndingVisuals()
        if SearchInput and #SearchInput.Text:gsub("%s+","") >= 1 then
            displayResults(searchWords(SearchInput.Text:lower():gsub("%s+",""), MAX_RESULTS))
        end
    end)
    btn.MouseEnter:Connect(function()
        if not ending2Enabled[ef.suffix] then createTween(btn, {BackgroundColor3 = C.borderLight}, 0.08):Play() end
    end)
    btn.MouseLeave:Connect(function()
        if not ending2Enabled[ef.suffix] then createTween(btn, {BackgroundColor3 = C.tagInactive}, 0.08):Play() end
    end)
end

-- ---- ROW: Speed + Used + Reset ----
local controlY = yPos
local ControlRow = Instance.new("Frame")
ControlRow.Size = UDim2.new(1, 0, 0, ROW_H - 2)
ControlRow.Position = UDim2.new(0, 0, 0, controlY)
ControlRow.BackgroundTransparency = 1
ControlRow.Parent = GamePage

local SpeedLabel = Instance.new("TextLabel")
SpeedLabel.Size = UDim2.new(0, isMobile and 38 or 48, 1, 0)
SpeedLabel.BackgroundTransparency = 1
SpeedLabel.Text = "⌨ Speed:"
SpeedLabel.TextColor3 = C.textMuted
SpeedLabel.TextSize = FONT_TINY
SpeedLabel.Font = Enum.Font.GothamBold
SpeedLabel.TextXAlignment = Enum.TextXAlignment.Left
SpeedLabel.Parent = ControlRow

local speedButtons = {}
local spX = isMobile and 35 or 50
local spBtnW = isMobile and 42 or 60
for idx, mode in ipairs(SPEED_MODES) do
    local isActive = (idx == currentSpeedIndex)
    local sBtn = Instance.new("TextButton")
    sBtn.Size = UDim2.new(0, spBtnW, 0, TAG_H)
    sBtn.Position = UDim2.new(0, spX, 0, (ROW_H - 2 - TAG_H)/2)
    sBtn.BackgroundColor3 = isActive and mode.color or C.tagInactive
    sBtn.Text = mode.icon .. " " .. mode.name
    sBtn.TextColor3 = isActive and Color3.fromRGB(255,255,255) or C.textMuted
    sBtn.TextSize = FONT_TINY
    sBtn.Font = Enum.Font.GothamBold
    sBtn.BorderSizePixel = 0
    sBtn.AutoButtonColor = false
    sBtn.Parent = ControlRow
    Instance.new("UICorner", sBtn).CornerRadius = UDim.new(0, 6)
    speedButtons[idx] = sBtn
    spX = spX + spBtnW + 3
end

local function updateSpeedVisuals()
    for idx, sBtn in ipairs(speedButtons) do
        local active = (idx == currentSpeedIndex)
        createTween(sBtn, {
            BackgroundColor3 = active and SPEED_MODES[idx].color or C.tagInactive,
            TextColor3 = active and Color3.fromRGB(255,255,255) or C.textMuted
        }, 0.12):Play()
    end
end
for idx, sBtn in ipairs(speedButtons) do
    sBtn.MouseButton1Click:Connect(function()
        currentSpeedIndex = idx
        updateSpeedVisuals()
    end)
end

local resetBtnW = isMobile and 46 or 60
local UsedLabel = Instance.new("TextLabel")
UsedLabel.Size = UDim2.new(0, isMobile and 45 or 70, 1, 0)
UsedLabel.Position = UDim2.new(1, -(resetBtnW + (isMobile and 50 or 74)), 0, 0)
UsedLabel.BackgroundTransparency = 1
UsedLabel.Text = "0 dipakai"
UsedLabel.TextColor3 = C.textMuted
UsedLabel.TextSize = FONT_TINY
UsedLabel.Font = Enum.Font.Gotham
UsedLabel.TextXAlignment = Enum.TextXAlignment.Right
UsedLabel.Parent = ControlRow

local ResetBtn = Instance.new("TextButton")
ResetBtn.Size = UDim2.new(0, resetBtnW, 0, TAG_H)
ResetBtn.Position = UDim2.new(1, -resetBtnW, 0, (ROW_H - 2 - TAG_H)/2)
ResetBtn.BackgroundColor3 = C.dangerBg
ResetBtn.Text = "↻ Reset"
ResetBtn.TextColor3 = C.danger
ResetBtn.TextSize = FONT_TINY
ResetBtn.Font = Enum.Font.GothamBold
ResetBtn.BorderSizePixel = 0
ResetBtn.AutoButtonColor = false
ResetBtn.Parent = ControlRow
Instance.new("UICorner", ResetBtn).CornerRadius = UDim.new(0, 6)

local function updateUsedLabel()
    UsedLabel.Text = formatNumber(usedWordsCount) .. " dipakai"
end

ResetBtn.MouseButton1Click:Connect(function()
    usedWords = {}
    usedWordsCount = 0
    updateUsedLabel()
    createTween(ResetBtn, {BackgroundColor3 = C.successBg, TextColor3 = C.success}, 0.1):Play()
    task.delay(0.4, function() createTween(ResetBtn, {BackgroundColor3 = C.dangerBg, TextColor3 = C.danger}, 0.2):Play() end)
    if SearchInput and #SearchInput.Text:gsub("%s+","") >= 1 then
        displayResults(searchWords(SearchInput.Text:lower():gsub("%s+",""), MAX_RESULTS))
    end
end)
ResetBtn.MouseEnter:Connect(function() createTween(ResetBtn, {BackgroundColor3 = C.danger, TextColor3 = Color3.fromRGB(255,255,255)}, 0.1):Play() end)
ResetBtn.MouseLeave:Connect(function() createTween(ResetBtn, {BackgroundColor3 = C.dangerBg, TextColor3 = C.danger}, 0.1):Play() end)

yPos = yPos + ROW_H + 2

-- ---- Chain info (hidden by default) ----
local chainY = yPos
local ChainInfo = Instance.new("Frame")
ChainInfo.Size = UDim2.new(1, 0, 0, isMobile and 34 or 46)
ChainInfo.Position = UDim2.new(0, 0, 0, chainY)
ChainInfo.BackgroundColor3 = C.purpleBg
ChainInfo.BorderSizePixel = 0
ChainInfo.Visible = false
ChainInfo.Parent = GamePage
Instance.new("UICorner", ChainInfo).CornerRadius = UDim.new(0, 10)
Instance.new("UIStroke", ChainInfo).Color = C.purple

local ChainWordLabel = Instance.new("TextLabel")
ChainWordLabel.Size = UDim2.new(1, -36, 0, 18)
ChainWordLabel.Position = UDim2.new(0, 6, 0, 3)
ChainWordLabel.BackgroundTransparency = 1
ChainWordLabel.Text = ""
ChainWordLabel.TextColor3 = C.purple
ChainWordLabel.TextSize = FONT_SMALL
ChainWordLabel.Font = Enum.Font.GothamBold
ChainWordLabel.TextXAlignment = Enum.TextXAlignment.Left
ChainWordLabel.Parent = ChainInfo

local ChainHintLabel = Instance.new("TextLabel")
ChainHintLabel.Size = UDim2.new(1, -36, 0, 14)
ChainHintLabel.Position = UDim2.new(0, 6, 0, 22)
ChainHintLabel.BackgroundTransparency = 1
ChainHintLabel.Text = ""
ChainHintLabel.TextColor3 = C.textSub
ChainHintLabel.TextSize = FONT_TINY
ChainHintLabel.Font = Enum.Font.Gotham
ChainHintLabel.TextXAlignment = Enum.TextXAlignment.Left
ChainHintLabel.Parent = ChainInfo

local NewChainBtn = Instance.new("TextButton")
NewChainBtn.Size = UDim2.new(0, 22, 0, 22)
NewChainBtn.Position = UDim2.new(1, -28, 0, (isMobile and 34 or 46 - 22)/2)
NewChainBtn.BackgroundColor3 = C.purple
NewChainBtn.Text = "↻"
NewChainBtn.TextColor3 = Color3.fromRGB(255,255,255)
NewChainBtn.TextSize = FONT_SMALL
NewChainBtn.Font = Enum.Font.GothamBold
NewChainBtn.BorderSizePixel = 0
NewChainBtn.Parent = ChainInfo
Instance.new("UICorner", NewChainBtn).CornerRadius = UDim.new(0, 6)

-- ---- Search bar ----
local searchY = yPos
SearchInput = Instance.new("TextBox")

local SearchFrame = Instance.new("Frame")
SearchFrame.Size = UDim2.new(1, 0, 0, SEARCH_H)
SearchFrame.Position = UDim2.new(0, 0, 0, searchY)
SearchFrame.BackgroundColor3 = C.card
SearchFrame.BorderSizePixel = 0
SearchFrame.Parent = GamePage
Instance.new("UICorner", SearchFrame).CornerRadius = UDim.new(0, 10)
Instance.new("UIStroke", SearchFrame).Color = C.border

local SearchIcon = Instance.new("TextLabel")
SearchIcon.Size = UDim2.new(0, 24, 1, 0)
SearchIcon.Position = UDim2.new(0, 6, 0, 0)
SearchIcon.BackgroundTransparency = 1
SearchIcon.Text = "🔍"
SearchIcon.TextSize = isMobile and 12 or 14
SearchIcon.Parent = SearchFrame

SearchInput.Name = "SearchInput"
SearchInput.Size = UDim2.new(1, -68, 1, -6)
SearchInput.Position = UDim2.new(0, 30, 0, 3)
SearchInput.BackgroundTransparency = 1
SearchInput.Text = ""
SearchInput.PlaceholderText = "Ketik huruf awal kata..."
SearchInput.PlaceholderColor3 = C.textMuted
SearchInput.TextColor3 = C.text
SearchInput.TextSize = FONT_BODY
SearchInput.Font = Enum.Font.Gotham
SearchInput.TextXAlignment = Enum.TextXAlignment.Left
SearchInput.ClearTextOnFocus = false
SearchInput.Parent = SearchFrame

local ResultCount = Instance.new("TextLabel")
ResultCount.Size = UDim2.new(0, 32, 1, 0)
ResultCount.Position = UDim2.new(1, -36, 0, 0)
ResultCount.BackgroundTransparency = 1
ResultCount.Text = ""
ResultCount.TextColor3 = C.textMuted
ResultCount.TextSize = FONT_SMALL
ResultCount.Font = Enum.Font.Gotham
ResultCount.Parent = SearchFrame

-- ---- Typing status bar ----
local typingY = searchY + SEARCH_H + 2
local TypingBar = Instance.new("Frame")
TypingBar.Size = UDim2.new(1, 0, 0, ROW_H - 4)
TypingBar.Position = UDim2.new(0, 0, 0, typingY)
TypingBar.BackgroundColor3 = C.successBg
TypingBar.BorderSizePixel = 0
TypingBar.Visible = false
TypingBar.Parent = GamePage
Instance.new("UICorner", TypingBar).CornerRadius = UDim.new(0, 8)

local TypingLabel = Instance.new("TextLabel")
TypingLabel.Size = UDim2.new(1, -60, 1, 0)
TypingLabel.Position = UDim2.new(0, 8, 0, 0)
TypingLabel.BackgroundTransparency = 1
TypingLabel.Text = "⌨ Typing..."
TypingLabel.TextColor3 = C.success
TypingLabel.TextSize = FONT_TINY
TypingLabel.Font = Enum.Font.GothamBold
TypingLabel.TextXAlignment = Enum.TextXAlignment.Left
TypingLabel.Parent = TypingBar

local TypingProgress = Instance.new("TextLabel")
TypingProgress.Size = UDim2.new(0, 28, 1, 0)
TypingProgress.Position = UDim2.new(1, -56, 0, 0)
TypingProgress.BackgroundTransparency = 1
TypingProgress.Text = ""
TypingProgress.TextColor3 = C.success
TypingProgress.TextSize = FONT_TINY
TypingProgress.Font = Enum.Font.Gotham
TypingProgress.TextXAlignment = Enum.TextXAlignment.Right
TypingProgress.Parent = TypingBar

local StopTypingBtn = Instance.new("TextButton")
StopTypingBtn.Size = UDim2.new(0, 22, 0, 18)
StopTypingBtn.Position = UDim2.new(1, -26, 0, 3)
StopTypingBtn.BackgroundColor3 = C.danger
StopTypingBtn.Text = "■"
StopTypingBtn.TextColor3 = Color3.fromRGB(255,255,255)
StopTypingBtn.TextSize = 7
StopTypingBtn.Font = Enum.Font.GothamBold
StopTypingBtn.BorderSizePixel = 0
StopTypingBtn.Parent = TypingBar
Instance.new("UICorner", StopTypingBtn).CornerRadius = UDim.new(0, 5)
StopTypingBtn.MouseButton1Click:Connect(function() stopTyping = true end)

updateTypingStatus = function(active, text, progress)
    if active then
        TypingBar.Visible = true
        local typed = string.sub(text, 1, progress)
        local rem = string.sub(text, progress + 1)
        TypingLabel.Text = "⌨ " .. typed:upper() .. "|" .. rem:upper()
        TypingProgress.Text = progress .. "/" .. #text
    else
        TypingBar.Visible = false
    end
end

-- ---- Results ----
local resultsY = searchY + SEARCH_H + 2
local ResultsFrame = Instance.new("ScrollingFrame")
ResultsFrame.Name = "Results"
ResultsFrame.Size = UDim2.new(1, 0, 1, -resultsY)
ResultsFrame.Position = UDim2.new(0, 0, 0, resultsY)
ResultsFrame.BackgroundTransparency = 1
ResultsFrame.BorderSizePixel = 0
ResultsFrame.ScrollBarThickness = isMobile and 2 or 3
ResultsFrame.ScrollBarImageColor3 = C.border
ResultsFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
ResultsFrame.Parent = GamePage

local ResultsLayout = Instance.new("UIListLayout")
ResultsLayout.SortOrder = Enum.SortOrder.LayoutOrder
ResultsLayout.Padding = UDim.new(0, 2)
ResultsLayout.Parent = ResultsFrame

local EmptyLabel = Instance.new("TextLabel")
EmptyLabel.Size = UDim2.new(1, 0, 0, 80)
EmptyLabel.BackgroundTransparency = 1
EmptyLabel.Text = "Ketik huruf untuk mencari kata..."
EmptyLabel.TextColor3 = C.textMuted
EmptyLabel.TextSize = FONT_BODY
EmptyLabel.Font = Enum.Font.Gotham
EmptyLabel.Parent = ResultsFrame

------------------------------------------------------------
-- LAYOUT HELPERS
------------------------------------------------------------
local function updateLayout()
    local y = controlY + ROW_H + 2
    if isChainMode then
        ChainInfo.Visible = true
        ScoreLabel.Visible = true
        ChainInfo.Position = UDim2.new(0, 0, 0, y)
        y = y + (isMobile and 42 or 50)
    else
        ChainInfo.Visible = false
        ScoreLabel.Visible = false
    end
    SearchFrame.Position = UDim2.new(0, 0, 0, y)
    TypingBar.Position = UDim2.new(0, 0, 0, y + SEARCH_H + 2)
    ResultsFrame.Position = UDim2.new(0, 0, 0, y + SEARCH_H + 2)
    ResultsFrame.Size = UDim2.new(1, 0, 1, -(y + SEARCH_H + 2))
end

local function updateModeVisuals()
    if isChainMode then
        createTween(ModeSearchBtn, {BackgroundColor3 = C.accentLight, TextColor3 = C.accent}, 0.2):Play()
        createTween(ModeChainBtn, {BackgroundColor3 = C.purple, TextColor3 = Color3.fromRGB(255,255,255)}, 0.2):Play()
    else
        createTween(ModeSearchBtn, {BackgroundColor3 = C.accent, TextColor3 = Color3.fromRGB(255,255,255)}, 0.2):Play()
        createTween(ModeChainBtn, {BackgroundColor3 = C.purpleBg, TextColor3 = C.purple}, 0.2):Play()
    end
end

------------------------------------------------------------
-- RESULTS DISPLAY
------------------------------------------------------------
local function clearResults()
    for _, child in ipairs(ResultsFrame:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
end

local function createWordItem(word, index)
    local currentPrefix = SearchInput.Text:lower():gsub("%s+", "")
    local remainingText = ""
    if #currentPrefix > 0 and startsWith(word, currentPrefix) then
        remainingText = string.sub(word, #currentPrefix + 1)
    end

    local btn = Instance.new("TextButton")
    btn.Name = "W" .. index
    btn.Size = UDim2.new(1, 0, 0, RESULT_H)
    btn.BackgroundColor3 = C.card
    btn.BorderSizePixel = 0
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.LayoutOrder = index
    btn.Parent = ResultsFrame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    local btnStroke = Instance.new("UIStroke", btn)
    btnStroke.Color = C.borderLight
    btnStroke.Thickness = 1

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(0, 3, 0.5, 0)
    bar.Position = UDim2.new(0, 5, 0.25, 0)
    bar.BackgroundColor3 = C.accent
    bar.BorderSizePixel = 0
    bar.Parent = btn
    Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 2)

    local prefixPart = string.sub(word, 1, #currentPrefix):upper()
    local remainPart = string.sub(word, #currentPrefix + 1):upper()

    local charW = isMobile and 6.5 or 8
    local wlPrefix = Instance.new("TextLabel")
    wlPrefix.Size = UDim2.new(0, #prefixPart * charW + 2, 1, 0)
    wlPrefix.Position = UDim2.new(0, 14, 0, 0)
    wlPrefix.BackgroundTransparency = 1
    wlPrefix.Text = prefixPart
    wlPrefix.TextColor3 = C.textMuted
    wlPrefix.TextSize = isMobile and 11 or 13
    wlPrefix.Font = Enum.Font.GothamBold
    wlPrefix.TextXAlignment = Enum.TextXAlignment.Left
    wlPrefix.Parent = btn

    local wlRemain = Instance.new("TextLabel")
    wlRemain.Size = UDim2.new(0.4, 0, 1, 0)
    wlRemain.Position = UDim2.new(0, 14 + #prefixPart * charW + 2, 0, 0)
    wlRemain.BackgroundTransparency = 1
    wlRemain.Text = remainPart
    wlRemain.TextColor3 = C.text
    wlRemain.TextSize = isMobile and 11 or 13
    wlRemain.Font = Enum.Font.GothamBold
    wlRemain.TextXAlignment = Enum.TextXAlignment.Left
    wlRemain.Parent = btn

    local endChar = string.sub(word, -2):upper()
    local endBadge = Instance.new("TextLabel")
    endBadge.Size = UDim2.new(0, isMobile and 24 or 28, 0, isMobile and 14 or 18)
    endBadge.Position = UDim2.new(1, isMobile and -84 or -100, 0, (RESULT_H - (isMobile and 14 or 18))/2)
    endBadge.BackgroundColor3 = C.accentLight
    endBadge.Text = endChar
    endBadge.TextColor3 = C.accent
    endBadge.TextSize = FONT_TINY - 1
    endBadge.Font = Enum.Font.GothamBold
    endBadge.Parent = btn
    Instance.new("UICorner", endBadge).CornerRadius = UDim.new(0, 4)

    local info = Instance.new("TextLabel")
    info.Size = UDim2.new(0, isMobile and 50 or 64, 0, 16)
    info.Position = UDim2.new(1, -(isMobile and 54 or 68), 0, (RESULT_H - 16)/2)
    info.BackgroundTransparency = 1
    info.Text = #word .. "h +" .. #remainingText
    info.TextColor3 = C.textMuted
    info.TextSize = FONT_TINY - 1
    info.Font = Enum.Font.Gotham
    info.TextXAlignment = Enum.TextXAlignment.Right
    info.Parent = btn

    btn.MouseEnter:Connect(function()
        createTween(btn, {BackgroundColor3 = C.accentLight}, 0.08):Play()
        createTween(btnStroke, {Color = C.accent}, 0.08):Play()
    end)
    btn.MouseLeave:Connect(function()
        createTween(btn, {BackgroundColor3 = C.card}, 0.08):Play()
        createTween(btnStroke, {Color = C.borderLight}, 0.08):Play()
    end)

    btn.MouseButton1Click:Connect(function()
        local prefix = SearchInput.Text:lower():gsub("%s+", "")
        lastTypedPrefix = prefix
        if not usedWords[word] then
            usedWords[word] = true
            usedWordsCount = usedWordsCount + 1
            updateUsedLabel()
        end
        createTween(btn, {BackgroundColor3 = C.successBg}, 0.08):Play()
        createTween(bar, {BackgroundColor3 = C.success}, 0.08):Play()
        task.delay(0.2, function()
            createTween(btn, {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0)}, 0.2):Play()
            task.delay(0.2, function()
                btn:Destroy()
                task.delay(0.05, function()
                    ResultsFrame.CanvasSize = UDim2.new(0, 0, 0, ResultsLayout.AbsoluteContentSize.Y + 8)
                end)
            end)
        end)
        if isChainMode then
            table.insert(chainHistory, word)
            currentChainWord = word
            score = score + #word
            ScoreLabel.Text = "Skor: " .. score
            local lastC = getLastChars(word, CHAIN_LENGTH)
            ChainWordLabel.Text = "🔗 " .. word:upper() .. " ➜ " .. lastC:upper() .. "..."
            ChainHintLabel.Text = #chainHistory .. " kata | berawalan \"" .. lastC:upper() .. "\""
        end
        SearchInput:ReleaseFocus()
        task.delay(0.15, function() autoTypeText(word, prefix) end)
    end)

    btn.BackgroundTransparency = 1
    wlPrefix.TextTransparency = 1
    wlRemain.TextTransparency = 1
    task.delay(index * 0.012, function()
        createTween(btn, {BackgroundTransparency = 0}, 0.12):Play()
        createTween(wlPrefix, {TextTransparency = 0}, 0.12):Play()
        createTween(wlRemain, {TextTransparency = 0}, 0.12):Play()
    end)
    return btn
end

displayResults = function(results)
    clearResults()
    if not results or #results == 0 then
        EmptyLabel.Visible = true
        EmptyLabel.Text = "Tidak ada kata ditemukan..."
        ResultCount.Text = "0"
        ResultsFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
        return
    end
    EmptyLabel.Visible = false
    ResultCount.Text = tostring(#results)
    for i, word in ipairs(results) do createWordItem(word, i) end
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
    if #allWords == 0 then
        ChainWordLabel.Text = "⚠ Tidak ada kata!"; return
    end
    local startWord = allWords[math.random(1, #allWords)]
    currentChainWord = startWord
    table.insert(chainHistory, startWord)
    score = score + #startWord
    ScoreLabel.Text = "Skor: " .. score
    local lastC = getLastChars(startWord, CHAIN_LENGTH)
    ChainWordLabel.Text = "🔗 " .. startWord:upper() .. " ➜ " .. lastC:upper() .. "..."
    ChainHintLabel.Text = "Ketik kata berawalan \"" .. lastC:upper() .. "\""
    SearchInput.Text = lastC
    clearResults()
    EmptyLabel.Visible = true
    EmptyLabel.Text = "Cari & klik kata untuk menyambung!"
    task.delay(0.1, function() SearchInput:CaptureFocus() end)
end

------------------------------------------------------------
-- DRAGGING
------------------------------------------------------------
local dragging, dragStart, startPos = false, nil, nil
TitleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        if not resizing then -- Don't start drag if resizing
            dragging = true; dragStart = input.Position; startPos = MainFrame.Position
        end
    end
end)
TitleBar.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if resizing then return end -- resize takes priority
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

------------------------------------------------------------
-- EVENT CONNECTIONS
------------------------------------------------------------
ModeSearchBtn.MouseButton1Click:Connect(function()
    if not isChainMode then return end
    isChainMode = false
    updateModeVisuals(); updateLayout()
    SearchInput.Text = ""; SearchInput.PlaceholderText = "Ketik huruf awal kata..."
    clearResults(); EmptyLabel.Visible = true; EmptyLabel.Text = "Ketik huruf untuk mencari kata..."
end)
ModeChainBtn.MouseButton1Click:Connect(function()
    if isChainMode then return end
    isChainMode = true
    updateModeVisuals(); updateLayout(); startNewChain()
end)
NewChainBtn.MouseButton1Click:Connect(function() startNewChain() end)

local searchDebounce = false
SearchInput:GetPropertyChangedSignal("Text"):Connect(function()
    if searchDebounce or isTyping then return end
    searchDebounce = true
    task.delay(0.12, function()
        searchDebounce = false
        local text = SearchInput.Text:lower():gsub("%s+", "")
        lastTypedPrefix = text
        if #text < 1 then
            clearResults(); EmptyLabel.Visible = true
            EmptyLabel.Text = isChainMode and "Cari & klik kata!" or "Ketik huruf untuk mencari kata..."
            ResultCount.Text = ""; return
        end
        displayResults(searchWords(text, MAX_RESULTS))
    end)
end)

CloseBtn.MouseButton1Click:Connect(function()
    createTween(MainFrame, {Size = UDim2.new(0, UI_WIDTH, 0, 0)}, 0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In):Play()
    createTween(Shadow, {ImageTransparency = 1}, 0.2):Play()
    task.delay(0.2, function() ScreenGui:Destroy() end)
end)

local isMinimized = false
local savedSize = MainFrame.Size
MinBtn.MouseButton1Click:Connect(function()
    if isMinimized then
        createTween(MainFrame, {Size = savedSize}, 0.25):Play()
        isMinimized = false
    else
        savedSize = MainFrame.Size
        createTween(MainFrame, {Size = UDim2.new(0, UI_WIDTH, 0, TITLE_H)}, 0.25):Play()
        isMinimized = true
    end
end)

for _, b in ipairs({CloseBtn, MinBtn}) do
    b.MouseEnter:Connect(function() createTween(b, {BackgroundTransparency = 0}, 0.08):Play() end)
    b.MouseLeave:Connect(function() createTween(b, {BackgroundTransparency = 0}, 0.08):Play() end)
end

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        MainFrame.Visible = not MainFrame.Visible
        Shadow.Visible = MainFrame.Visible
    end
end)

------------------------------------------------------------
-- INIT
------------------------------------------------------------
LoadingPage.Visible = true
GamePage.Visible = false

MainFrame.Size = UDim2.new(0, UI_WIDTH, 0, 0)
createTween(MainFrame, {Size = UDim2.new(0, UI_WIDTH, 0, UI_HEIGHT)}, 0.35, Enum.EasingStyle.Back):Play()
task.spawn(function() createTween(LdBarFill, {Size = UDim2.new(0.65, 0, 1, 0)}, 1.5, Enum.EasingStyle.Linear):Play() end)

task.spawn(function()
    task.wait(0.4)
    LdText.Text = "Mengunduh kamus KBBI..."
    local ok = fetchKBBI()
    if ok then
        createTween(LdBarFill, {Size = UDim2.new(1, 0, 1, 0)}, 0.25):Play()
        LdBarFill.BackgroundColor3 = C.success
        LdText.Text = "✅ " .. formatNumber(#allWords) .. " kata dimuat!"
        isLoaded = true
        task.wait(0.8)
        LoadingPage.Visible = false
        GamePage.Visible = true
        updateModeVisuals()
        updateLayout()
        updateEndingVisuals()
    else
        createTween(LdBarFill, {Size = UDim2.new(1, 0, 1, 0)}, 0.25):Play()
        LdBarFill.BackgroundColor3 = C.danger
        LdText.Text = "❌ Gagal! Cek URL GitHub"
    end
end)

print("═══════════════════════════════════════════")
print("  🔤 SAMBUNG KATA v3 - KBBI Edition")
print("  Platform: " .. (isMobile and "📱 MOBILE" or "🖥️ DESKTOP"))
print("  UI Size: " .. UI_WIDTH .. "x" .. UI_HEIGHT)
print("  Right Shift = Show/Hide")
print("═══════════════════════════════════════════")

------------------------------------------------------------
-- AUTO-DETECT LOOP
------------------------------------------------------------
task.spawn(function()
    while ScreenGui and ScreenGui.Parent do
        if isLoaded and autoDetectEnabled and not isTyping then
            local letter = scanForLetter()
            if letter and letter ~= lastDetectedLetter then
                lastDetectedLetter = letter
                if updateDetectStatus then updateDetectStatus(letter) end
                SearchInput.Text = letter:lower()
                lastTypedPrefix = letter:lower()
                task.delay(0.15, function()
                    displayResults(searchWords(letter:lower(), MAX_RESULTS))
                end)
            end
        end
        task.wait(0.5)
    end
end)
