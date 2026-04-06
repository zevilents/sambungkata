-- [[ KBBI SAMBUNG KATA V3.5 - ZLENT World Edition ]] --
-- GitHub: zevilents/sambungkata
-- Developer: Bima Abiyasa

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

-- [[ KONFIGURASI ]] --
local GITHUB_KBBI = "https://raw.githubusercontent.com/zevilents/sambungkata/refs/heads/main/kbbi.txt"
local LOCAL_FILE = "kbbi.txt"

local Kamus = {}
local KataTerpakai = {}
local AutoStatus = false
local SedangProses = false

-- Konfigurasi Kecepatan
local SpeedConfig = {
    ["Instant"] = {think = 0, char = 0},
    ["Fast"]    = {think = 0.3, char = 0.03},
    ["Normal"]  = {think = 0.7, char = 0.08},
    ["Slow"]    = {think = 1.5, char = 0.15}
}
local KecepatanSekarang = SpeedConfig["Normal"]

-- [[ LOGIKA DATA ]] --
local function MuatData()
    local konten = ""
    local sumber = ""

    -- Cek Lokal dulu
    if isfile and isfile(LOCAL_FILE) then
        konten = readfile(LOCAL_FILE)
        sumber = "LOKAL (Workspace)"
    else
        -- Jika lokal tidak ada, ambil dari GitHub zevilents
        local sukses, result = pcall(function() return game:HttpGet(GITHUB_KBBI) end)
        if sukses then
            konten = result
            sumber = "CLOUD (GitHub)"
        else
            return false, "Gagal mengambil data dari Lokal maupun GitHub!"
        end
    end

    -- Parsing Kata
    Kamus = {}
    local hitung = 0
    for kata in string.gmatch(konten, "[^\r\n]+") do
        local clean = string.lower(kata):gsub("%s+", "")
        if #clean >= 2 then
            local awal = string.sub(clean, 1, 1)
            Kamus[awal] = Kamus[awal] or {}
            table.insert(Kamus[awal], clean)
            hitung = hitung + 1
        end
    end
    return true, "Berhasil muat " .. hitung .. " kata dari " .. sumber
end

-- [[ LOGIKA AUTO ANSWER ]] --
local function AutoType(kata)
    if SedangProses or not kata then return end
    SedangProses = true
    
    task.wait(KecepatanSekarang.think)
    
    -- Mencari InputBox (Sesuaikan dengan game)
    local TextBox = nil
    for _, v in pairs(LocalPlayer.PlayerGui:GetDescendants()) do
        if v:IsA("TextBox") and v.Visible and v.Parent.Visible then
            TextBox = v
            break
        end
    end
    
    if TextBox then
        TextBox:CaptureFocus()
        for i = 1, #kata do
            TextBox.Text = string.sub(kata, 1, i)
            task.wait(KecepatanSekarang.char)
        end
        task.wait(0.1)
        TextBox:ReleaseFocus(true) -- Tekan Enter
    end
    
    KataTerpakai[kata] = true
    SedangProses = false
end

-- [[ INTERFACE ]] --
local ScreenGui = Instance.new("ScreenGui", LocalPlayer:WaitForChild("PlayerGui"))
ScreenGui.ResetOnSpawn = false

local Main = Instance.new("Frame", ScreenGui)
Main.Size = UDim2.new(0, 320, 0, 300)
Main.Position = UDim2.new(0.5, -160, 0.5, -150)
Main.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
Main.BorderSizePixel = 0
Main.Active = true
Main.Draggable = true

Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 12)

local Header = Instance.new("TextLabel", Main)
Header.Size = UDim2.new(1, 0, 0, 45)
Header.Text = "ZLENT SAMBUNG KATA V3.5"
Header.TextColor3 = Color3.fromRGB(255, 255, 255)
Header.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
Header.Font = Enum.Font.GothamBold
Instance.new("UICorner", Header)

local Status = Instance.new("TextLabel", Main)
Status.Size = UDim2.new(1, -20, 0, 50)
Status.Position = UDim2.new(0, 10, 0, 55)
Status.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
Status.TextColor3 = Color3.fromRGB(0, 200, 255)
Status.Text = "Menghubungkan ke GitHub..."
Status.Font = Enum.Font.GothamMedium
Instance.new("UICorner", Status)

local Toggle = Instance.new("TextButton", Main)
Toggle.Size = UDim2.new(1, -20, 0, 45)
Toggle.Position = UDim2.new(0, 10, 0, 115)
Toggle.Text = "AUTO ANSWER: OFF"
Toggle.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
Toggle.TextColor3 = Color3.fromRGB(255, 255, 255)
Toggle.Font = Enum.Font.GothamBold
Instance.new("UICorner", Toggle)

Toggle.MouseButton1Click:Connect(function()
    AutoStatus = not AutoStatus
    Toggle.Text = AutoStatus and "AUTO ANSWER: ON" or "AUTO ANSWER: OFF"
    Toggle.BackgroundColor3 = AutoStatus and Color3.fromRGB(50, 150, 50) or Color3.fromRGB(150, 50, 50)
end)

-- Tombol Kecepatan
local function SpeedBtn(name, xPos)
    local btn = Instance.new("TextButton", Main)
    btn.Size = UDim2.new(0, 70, 0, 35)
    btn.Position = UDim2.new(0, xPos, 0, 175)
    btn.Text = name
    btn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 10
    Instance.new("UICorner", btn)
    
    btn.MouseButton1Click:Connect(function()
        KecepatanSekarang = SpeedConfig[name]
        Status.Text = "Mode: " .. name
    end)
end

SpeedBtn("Instant", 10)
SpeedBtn("Fast", 87)
SpeedBtn("Normal", 164)
SpeedBtn("Slow", 241)

-- [[ STARTUP ]] --
local ok, msg = MuatData()
Status.Text = msg

task.spawn(function()
    while true do
        task.wait(0.5)
        if AutoStatus and not SedangProses then
            -- Deteksi Huruf (Cari TextLabel 1 karakter)
            for _, v in pairs(LocalPlayer.PlayerGui:GetDescendants()) do
                if v:IsA("TextLabel") and v.Visible and #v.Text == 1 and v.Text:match("%a") then
                    local kata = AmbilKataCocok(v.Text)
                    if kata then
                        Status.Text = "Menjawab: " .. kata
                        AutoType(kata)
                    end
                end
            end
        end
    end
end)
