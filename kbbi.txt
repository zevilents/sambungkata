-- [[ KBBI SAMBUNG KATA V3.5 - SPEEDCONTROL EDITION ]] --
-- Credits: Adapted from Sobing4413 logic
-- Setup: Simpan file kata di /workspace/kbbi.txt (satu kata per baris)

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

-- [[ KONFIGURASI & VARIABEL ]] --
local Kamus = {}
local KataTerpakai = {}
local HurufTarget = ""
local SedangMengetik = false
local AutoAnswerAktif = false

-- Profil Kecepatan (Delay dalam detik)
local SpeedProfiles = {
    ["Instant"] = {think = 0, char = 0},
    ["Fast"]    = {think = 0.2, char = 0.05},
    ["Normal"]  = {think = 0.5, char = 0.1},
    ["Slow"]    = {think = 1.2, char = 0.2}
}
local CurrentSpeed = SpeedProfiles["Normal"]

-- [[ FUNGSI LOADING DATA ]] --
local function LoadKamus()
    if isfile("kbbi.txt") then
        local konten = readfile("kbbi.txt")
        Kamus = {}
        for kata in string.gmatch(konten, "[^\r\n]+") do
            local cleanWord = string.lower(kata):gsub("%s+", "")
            if #cleanWord >= 3 then
                local awalan = string.sub(cleanWord, 1, 1)
                Kamus[awalan] = Kamus[awalan] or {}
                table.insert(Kamus[awalan], cleanWord)
            end
        end
        return true, "Kamus lokal berhasil dimuat!"
    else
        return false, "File kbbi.txt tidak ditemukan di folder workspace!"
    end
end

-- [[ LOGIKA GAME ]] --
local function CariKata(awalan)
    if not Kamus[awalan] then return nil end
    for _, kata in pairs(Kamus[awalan]) do
        if not KataTerpakai[kata] then
            return kata
        end
    end
    return nil
end

-- Fungsi Simulasi Mengetik (Auto Typing)
local function AutoType(kata)
    if SedangMengetik or not kata then return end
    SedangMengetik = true
    
    -- Jeda berfikir
    task.wait(CurrentSpeed.think)
    
    -- Simulasi per huruf
    -- Catatan: Ganti 'RemoteEvent' dengan RemoteEvent asli dari game tersebut
    local Remote = game:GetService("ReplicatedStorage"):FindFirstChild("DefaultChatSystemChatEvents") -- Contoh
    
    for i = 1, #kata do
        local teksSekarang = string.sub(kata, 1, i)
        -- Di sini biasanya game mendeteksi input real-time
        -- game:GetService("ReplicatedStorage").RemoteEvent:FireServer(teksSekarang) 
        task.wait(CurrentSpeed.char)
    end
    
    -- Tekan Enter / Submit
    -- game:GetService("ReplicatedStorage").RemoteEvent:FireServer(kata, true) 
    
    KataTerpakai[kata] = true
    SedangMengetik = false
end

-- [[ PEMBUATAN UI (SEDERHANA & RAPI) ]] --
local ScreenGui = Instance.new("ScreenGui", LocalPlayer:WaitForChild("PlayerGui"))
ScreenGui.Name = "KBBISambungKata"

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size = UDim2.new(0, 350, 0, 400)
MainFrame.Position = UDim2.new(0.5, -175, 0.5, -200)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true

local Title = Instance.new("TextLabel", MainFrame)
Title.Size = UDim2.new(1, 0, 0, 40)
Title.Text = "KBBI SAMBUNG KATA V3.5"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
Title.Font = Enum.Font.GothamBold

local StatusLabel = Instance.new("TextLabel", MainFrame)
StatusLabel.Size = UDim2.new(1, -20, 0, 30)
StatusLabel.Position = UDim2.new(0, 10, 0, 50)
StatusLabel.Text = "Status: Menunggu giliran..."
StatusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
StatusLabel.BackgroundTransparency = 1

local ToggleBtn = Instance.new("TextButton", MainFrame)
ToggleBtn.Size = UDim2.new(1, -20, 0, 40)
ToggleBtn.Position = UDim2.new(0, 10, 0, 90)
ToggleBtn.Text = "AUTO ANSWER: OFF"
ToggleBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
ToggleBtn.Font = Enum.Font.GothamBold

-- Event Toggle
ToggleBtn.MouseButton1Click:Connect(function()
    AutoAnswerAktif = not AutoAnswerAktif
    ToggleBtn.Text = AutoAnswerAktif and "AUTO ANSWER: ON" or "AUTO ANSWER: OFF"
    ToggleBtn.BackgroundColor3 = AutoAnswerAktif and Color3.fromRGB(50, 200, 50) or Color3.fromRGB(200, 50, 50)
end)

-- [[ EKSEKUSI AWAL ]] --
local success, msg = LoadKamus()
StatusLabel.Text = msg

-- Loop Utama untuk mendeteksi giliran (Contoh Logika)
-- Kamu perlu menyesuaikan deteksi giliran ini sesuai game yang kamu mainkan
task.spawn(function()
    while task.wait(0.5) do
        if AutoAnswerAktif and not SedangMengetik then
            -- LOGIKA: Cek apakah sekarang giliranmu dan apa hurufnya
            -- Contoh: HurufTarget = GetCurrentLetterFromGame()
            
            if HurufTarget ~= "" then
                local kataHasil = CariKata(string.lower(HurufTarget))
                if kataHasil then
                    StatusLabel.Text = "Mengetik: " .. kataHasil
                    AutoType(kataHasil)
                end
            end
        end
    end
end)

print("Script Loaded! Gunakan file kbbi.txt di folder workspace.")
