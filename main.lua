-- [[ KBBI SAMBUNG KATA V3.5 - ZLENT EDITION ]] --
-- Fitur: Auto-Typing, Speed Control, DupFilter, Local TXT Support
-- Developer: Bima Abiyasa (ZLENT World)

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- [[ KONFIGURASI CORE ]] --
local Kamus = {}
local KataTerpakai = {}
local TargetHuruf = ""
local SedangProses = false
local AutoStatus = false
local NamaFile = "kbbi.txt"

-- Profil Kecepatan (Think = Jeda mikir, Char = Jeda antar huruf)
local SpeedConfig = {
    ["Instant"] = {think = 0, char = 0},
    ["Fast"]    = {think = 0.3, char = 0.02},
    ["Normal"]  = {think = 0.7, char = 0.08},
    ["Slow"]    = {think = 1.5, char = 0.15}
}
local KecepatanSekarang = SpeedConfig["Normal"]

-- [[ FUNGSI SISTEM ]] --

-- Load data dari kbbi.txt di folder workspace
local function MuatKamusLokal()
    if isfile(NamaFile) then
        local sukses, konten = pcall(function() return readfile(NamaFile) end)
        if sukses then
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
            return true, "Berhasil muat " .. hitung .. " kata dari " .. NamaFile
        end
    end
    return false, "File " .. NamaFile .. " tidak ditemukan di Workspace!"
end

-- Cari kata yang cocok berdasarkan awalan
local function AmbilKataCocok(awalan)
    local pref = string.lower(awalan)
    if Kamus[pref] then
        for _, kata in pairs(Kamus[pref]) do
            if not KataTerpakai[kata] then
                return kata
            end
        end
    end
    return nil
end

-- [[ INTERFACE (GUI) ]] --
local ScreenGui = Instance.new("ScreenGui", LocalPlayer:WaitForChild("PlayerGui"))
ScreenGui.ResetOnSpawn = false

local Main = Instance.new("Frame", ScreenGui)
Main.Size = UDim2.new(0, 320, 0, 380)
Main.Position = UDim2.new(0.5, -160, 0.5, -190)
Main.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
Main.BorderSizePixel = 0
Main.Active = true
Main.Draggable = true

local Corner = Instance.new("UICorner", Main)
Corner.CornerRadius = UDim.new(0, 10)

local Header = Instance.new("TextLabel", Main)
Header.Size = UDim2.new(1, 0, 0, 45)
Header.Text = "KBBI SAMBUNG KATA V3.5"
Header.TextColor3 = Color3.fromRGB(255, 255, 255)
Header.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
Header.Font = Enum.Font.GothamBold
Header.TextSize = 14

local UICorner2 = Instance.new("UICorner", Header)

local StatusBox = Instance.new("TextLabel", Main)
StatusBox.Size = UDim2.new(1, -20, 0, 60)
StatusBox.Position = UDim2.new(0, 10, 0, 55)
StatusBox.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
StatusBox.TextColor3 = Color3.fromRGB(0, 255, 150)
StatusBox.Text = "Mengecek file..."
StatusBox.Font = Enum.Font.GothamMedium
StatusBox.TextWrapped = true

local Toggle = Instance.new("TextButton", Main)
Toggle.Size = UDim2.new(1, -20, 0, 45)
Toggle.Position = UDim2.new(0, 10, 0, 125)
Toggle.Text = "AUTO ANSWER: OFF"
Toggle.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
Toggle.TextColor3 = Color3.fromRGB(255, 255, 255)
Toggle.Font = Enum.Font.GothamBold

-- Fungsi Kecepatan UI
local function CreateSpeedBtn(name, pos)
    local btn = Instance.new("TextButton", Main)
    btn.Size = UDim2.new(0, 70, 0, 35)
    btn.Position = pos
    btn.Text = name
    btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 10
    
    btn.MouseButton1Click:Connect(function()
        KecepatanSekarang = SpeedConfig[name]
        StatusBox.Text = "Mode Kecepatan: " .. name
    end)
end

CreateSpeedBtn("Instant", UDim2.new(0, 10, 0, 180))
CreateSpeedBtn("Fast", UDim2.new(0, 87, 0, 180))
CreateSpeedBtn("Normal", UDim2.new(0, 164, 0, 180))
CreateSpeedBtn("Slow", UDim2.new(0, 241, 0, 180))

-- [[ LOGIKA AUTO TYPING ]] --
local function JalankanAutoType(kata)
    if SedangProses or not kata then return end
    SedangProses = true
    
    task.wait(KecepatanSekarang.think)
    
    -- BAGIAN KRUSIAL: Mengetik ke game
    -- Kita asumsikan game menggunakan TextBox untuk input
    -- Script ini akan mencoba mencari TextBox aktif di PlayerGui
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
        -- Simulasi tekan enter
        TextBox:ReleaseFocus(true) 
    else
        -- Jika tidak pakai TextBox, biasanya pakai RemoteEvent
        -- Kamu perlu ganti "RemoteName" dengan hasil dari SimpleSpy
        warn("TextBox tidak ditemukan, mencoba RemoteEvent...")
        -- game.ReplicatedStorage.RemoteName:FireServer(kata)
    end
    
    KataTerpakai[kata] = true
    SedangProses = false
    StatusBox.Text = "Berhasil menjawab: " .. kata
end

-- [[ AKTIVASI ]] --
Toggle.MouseButton1Click:Connect(function()
    AutoStatus = not AutoStatus
    Toggle.Text = AutoStatus and "AUTO ANSWER: ON" or "AUTO ANSWER: OFF"
    Toggle.BackgroundColor3 = AutoStatus and Color3.fromRGB(50, 150, 50) or Color3.fromRGB(150, 50, 50)
end)

-- Main Loop
local ok, pesan = MuatKamusLokal()
StatusBox.Text = pesan

task.spawn(function()
    while true do
        task.wait(0.5)
        if AutoStatus and not SedangProses then
            -- Deteksi giliran (Logika ini harus disesuaikan dengan game spesifik)
            -- Kita cari TextLabel yang menunjukkan huruf awal di layar
            for _, v in pairs(LocalPlayer.PlayerGui:GetDescendants()) do
                if v:IsA("TextLabel") and #v.Text == 1 and v.Text:match("%a") then
                    TargetHuruf = v.Text
                    local kata = AmbilKataCocok(TargetHuruf)
                    if kata then
                        JalankanAutoType(kata)
                    end
                end
            end
        end
    end
end)
