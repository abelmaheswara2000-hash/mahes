--[[
    Indo Hangout - Auto Fish, Auto Mining Crystal, Auto Sell, Auto Buy & Equip (LynxGUI)
    Fitur:
    1. Auto Lempar Loop (State Machine: melempar, menunggu sambaran ikan, menarik otomatis)
    2. Auto Follow Garis Merah (Bar putih menempel presisi 100%)
    3. Auto Sell Ikan & Auto Sell Crystal
    4. Auto Buy Rod & Auto Buy Pickaxe (Otomatis upgrade alat saat uang cukup)
    5. Auto Equip Best Rod & Auto Equip Best Pickaxe
    6. Auto Mining Crystal (Mendeteksi, teleport & tambang crystal otomatis di goa)
    7. Instant Catch (Opsi skip minigame bar)
    8. Anti AFK 20 Menit (Bebas disconnect)
]]

-- Matikan instance script sebelumnya agar tidak ada loop dobel
if _G.AutoFishRunning then
    _G.AutoFishRunning = false
    task.wait(0.5)
end
_G.AutoFishRunning = true

-- ==================== 1. LOAD LYNX GUI ====================
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/habibrodriguez7-art/MainLib/refs/heads/main/rewrite.lua"))()


-- ==================== SERVICES & REMOTES ====================
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local Events = ReplicatedStorage:WaitForChild("Events")
local rodRemote = Events:WaitForChild("RemoteEvent"):WaitForChild("Rod")
local sellRemote = Events:WaitForChild("RemoteFunction"):WaitForChild("SellFish")
local rodShopRemote = Events:WaitForChild("RemoteFunction"):WaitForChild("RodShop")

-- Remotes Mining & Pickaxe
local pickaxeRemote = Events:WaitForChild("RemoteEvent"):WaitForChild("Pickaxe")
local pickaxeShopRemote = Events:WaitForChild("RemoteFunction"):WaitForChild("PickaxeShop")
local sellCrystalRemote = Events:WaitForChild("RemoteFunction"):WaitForChild("SellCrystal")
local inventoryRemote = Events:WaitForChild("RemoteFunction"):WaitForChild("Inventory")

-- Instances Reeling Minigame
local reelingGui = PlayerGui:WaitForChild("Reeling")
local mainFrame = reelingGui:WaitForChild("MainFrame")
local frame = mainFrame:WaitForChild("Frame")
local whiteBar = frame:WaitForChild("WhiteBar")
local redBar = frame:WaitForChild("RedBar")
local progressBar = mainFrame:WaitForChild("ProgressBg"):WaitForChild("ProgressBar")

local reelingScript = reelingGui:WaitForChild("ReelingLocalScript")
local env = getsenv(reelingScript)

-- Status State Machine
local FishingState = "IDLE"

local config = {
    -- Fitur Mancing
    autoCast = true,            -- Lempar otomatis berulang kali
    autoFollow = true,          -- Bar putih menempel di garis merah
    instantCatch = false,       -- Skip minigame bar
    reelMultiplier = 1.0,       -- Pengali kecepatan reeling
    autoSell = true,            -- Otomatis menjual ikan
    sellCategory = "Sell All",  -- Kategori penjualan ikan
    autoBuyRod = true,          -- Otomatis membeli rod saat uang cukup
    autoEquipBestRod = true,    -- Otomatis memakai pancingan terbaik dari inventory
    targetRod = "Next Tier (Urut)", -- Pilihan target beli rod
    castDelay = 1.5,            -- Jeda setelah dapat ikan sebelum lempar lagi
    
    -- Fitur Mining Crystal
    autoMine = false,           -- Otomatis menambang crystal di goa
    crystalPriority = "Terdekat (Nearest)", -- Prioritas crystal: "Terdekat (Nearest)" / "Prioritas Rarity"
    mineInterval = 1.5,         -- Jeda ayunan pickaxe (detik)
    autoEquipBestPickaxe = true,-- Otomatis memakai pickaxe terbaik
    autoSellCrystal = true,     -- Otomatis menjual crystal
    sellCrystalCategory = "Sell All", -- Kategori penjualan crystal
    autoBuyPickaxe = true,      -- Otomatis membeli pickaxe saat uang cukup
    targetPickaxe = "Next Tier (Urut)", -- Pilihan target beli pickaxe
    
    -- Utility
    antiAfk = true              -- Mencegah AFK disconnect
}

-- Urutan kualitas rod pancingan dari yang terbaik (Tier Ranking)
local rodTierRanking = {
    "Genesis Rod",
    "Anubis Rod",
    "Blue Dragon Rod",
    "Pink Dragon Rod",
    "Canny Rod",
    "Voltric Rod",
    "Skelly Rod",
    "Trisula Rod",
    "Flowers Rod",
    "Thermo Rod",
    "Piranha Rod",
    "Feather Rod",
    "Shark Rod",
    "Party Rod",
    "Basic Rod"
}

-- Urutan kualitas pickaxe dari yang terbaik (Tier Ranking)
local pickaxeTierRanking = {
    "Hunter Pickaxe",
    "Candy Pickaxe",
    "Emerald Pickaxe",
    "Frost Pickaxe",
    "Ruby Pickaxe",
    "Gold Pickaxe",
    "Basic Pickaxe"
}

-- ==================== HELPER: GET MONEY & BEST ROD ====================
local function getPlayerMoney()
    for _, d in ipairs(PlayerGui:GetDescendants()) do
        if d:IsA("TextLabel") and d.Text and d.Text:match("^RP%s+([%d%.]+)") then
            local cleanStr = d.Text:match("^RP%s+([%d%.]+)"):gsub("%.", "")
            return tonumber(cleanStr) or 0
        end
    end
    return 0
end

local function findBestRod()
    local char = LocalPlayer.Character
    local backpack = LocalPlayer.Backpack
    
    -- Cari rod terbaik sesuai urutan rodTierRanking
    for _, rodName in ipairs(rodTierRanking) do
        local inChar = char and char:FindFirstChild(rodName)
        if inChar and inChar:IsA("Tool") and (inChar:FindFirstChild("RodLocalScript") or inChar.Name:find("Rod")) then
            return inChar
        end
        local inBackpack = backpack and backpack:FindFirstChild(rodName)
        if inBackpack and inBackpack:IsA("Tool") and (inBackpack:FindFirstChild("RodLocalScript") or inBackpack.Name:find("Rod")) then
            return inBackpack
        end
    end
    
    -- Fallback: Ambil tool pancingan apa saja yang ada
    if char then
        for _, item in ipairs(char:GetChildren()) do
            if item:IsA("Tool") and (item:FindFirstChild("RodLocalScript") or item.Name:find("Rod")) then
                return item
            end
        end
    end
    if backpack then
        for _, item in ipairs(backpack:GetChildren()) do
            if item:IsA("Tool") and (item:FindFirstChild("RodLocalScript") or item.Name:find("Rod")) then
                return item
            end
        end
    end
    return nil
end

local function equipBestRod(manualNotify)
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not (char and hum and hum.Health > 0) then return nil end
    
    local bestRod = findBestRod()
    if not bestRod then
        if manualNotify then
            Library:MakeNotify({
                Title = "Equip Rod",
                Description = "Tidak ditemukan pancingan (Rod) di tas maupun karakter!",
                Delay = 2.5
            })
        end
        return nil
    end
    
    if bestRod.Parent ~= char then
        hum:EquipTool(bestRod)
        if manualNotify then
            Library:MakeNotify({
                Title = "Auto Equip Best Rod",
                Description = string.format("Berhasil memasang rod terbaik: %s!", bestRod.Name),
                Delay = 2.5
            })
        end
    else
        if manualNotify then
            Library:MakeNotify({
                Title = "Auto Equip Best Rod",
                Description = string.format("Anda sedang memakai rod terbaik: %s!", bestRod.Name),
                Delay = 2.5
            })
        end
    end
    return bestRod
end

-- ==================== 2. FITUR AUTO BUY ROD ====================
local function checkAutoBuyRod(manualNotify)
    if not rodShopRemote then return false end
    
    local success, profile = pcall(function()
        return rodShopRemote:InvokeServer("GetPlayerProfile")
    end)
    local listSuccess, allRods = pcall(function()
        return rodShopRemote:InvokeServer("GetList")
    end)
    
    if not (success and listSuccess and allRods) then return false end
    local owned = profile or {}
    local currentMoney = getPlayerMoney()
    
    for _, rodInfo in ipairs(allRods) do
        local alreadyOwned = table.find(owned, rodInfo.name) ~= nil
        local matchesTarget = (config.targetRod == "Next Tier (Urut)") or (config.targetRod:find(rodInfo.name) ~= nil)
        
        if not alreadyOwned and matchesTarget then
            if currentMoney >= rodInfo.price then
                local buyOk, buyRes = pcall(function()
                    return rodShopRemote:InvokeServer("Buy", rodInfo.name)
                end)
                if buyOk and buyRes == "success" then
                    Library:MakeNotify({
                        Title = "Auto Buy Rod",
                        Description = string.format("Selamat! Berhasil membeli %s seharga Rp %s!", rodInfo.name, tostring(rodInfo.price)),
                        Delay = 3.5
                    })
                    -- Otomatis pasang rod terbaik ke karakter
                    if config.autoEquipBestRod then
                        task.delay(0.6, function()
                            equipBestRod(true)
                        end)
                    end
                    return true
                end
            else
                if manualNotify then
                    Library:MakeNotify({
                        Title = "Auto Buy Rod",
                        Description = string.format("Uang belum cukup untuk %s (Kurang Rp %s)", rodInfo.name, tostring(rodInfo.price - currentMoney)),
                        Delay = 2.5
                    })
                end
            end
            break -- Berhenti di target terdekat
        end
    end
    return false
end

-- ==================== 3. FITUR AUTO SELL ====================
local function doSellFish(silent)
    if not sellRemote then return end
    local success, totalCash, bonus, totalCount = pcall(function()
        return sellRemote:InvokeServer("CheckFish", config.sellCategory or "Sell All")
    end)
    
    if success and totalCount and tonumber(totalCount) and tonumber(totalCount) > 0 then
        local sellOk, result = pcall(function()
            return sellRemote:InvokeServer("SellFish", config.sellCategory or "Sell All")
        end)
        if sellOk and result == "Success" then
            if not silent then
                Library:MakeNotify({
                    Title = "Auto Sell",
                    Description = string.format("Berhasil menjual %s ikan (+Rp %s)!", tostring(totalCount), tostring(totalCash)),
                    Delay = 2.5
                })
            end
            -- Setelah ikan terjual dan uang bertambah, periksa apakah cukup untuk beli rod baru
            if config.autoBuyRod then
                task.delay(0.5, function()
                    checkAutoBuyRod(false)
                end)
            end
            return true, totalCount, totalCash
        end
    end
    return false
end

-- ==================== 4. FITUR AUTO BUY & EQUIP PICKAXE ====================
local function findBestPickaxe()
    local char = LocalPlayer.Character
    local backpack = LocalPlayer.Backpack
    
    for _, name in ipairs(pickaxeTierRanking) do
        local inChar = char and char:FindFirstChild(name)
        if inChar and inChar:IsA("Tool") and (inChar:FindFirstChild("PickaxeLocalScript") or inChar.Name:find("Pickaxe")) then
            return inChar
        end
        local inBp = backpack and backpack:FindFirstChild(name)
        if inBp and inBp:IsA("Tool") and (inBp:FindFirstChild("PickaxeLocalScript") or inBp.Name:find("Pickaxe")) then
            return inBp
        end
    end
    
    if char then
        for _, item in ipairs(char:GetChildren()) do
            if item:IsA("Tool") and (item:FindFirstChild("PickaxeLocalScript") or item.Name:find("Pickaxe")) then
                return item
            end
        end
    end
    if backpack then
        for _, item in ipairs(backpack:GetChildren()) do
            if item:IsA("Tool") and (item:FindFirstChild("PickaxeLocalScript") or item.Name:find("Pickaxe")) then
                return item
            end
        end
    end
    return nil
end

local function equipBestPickaxe(manualNotify)
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not (char and hum and hum.Health > 0) then return nil end
    
    local bestPickaxe = findBestPickaxe()
    if not bestPickaxe then
        if manualNotify then
            Library:MakeNotify({
                Title = "Equip Pickaxe",
                Description = "Tidak ditemukan Pickaxe di tas maupun karakter!",
                Delay = 2.5
            })
        end
        return nil
    end
    
    if bestPickaxe.Parent ~= char then
        hum:EquipTool(bestPickaxe)
        if manualNotify then
            Library:MakeNotify({
                Title = "Auto Equip Pickaxe",
                Description = string.format("Berhasil memasang pickaxe: %s!", bestPickaxe.Name),
                Delay = 2.5
            })
        end
    else
        if manualNotify then
            Library:MakeNotify({
                Title = "Auto Equip Pickaxe",
                Description = string.format("Anda sedang memakai: %s!", bestPickaxe.Name),
                Delay = 2.5
            })
        end
    end
    return bestPickaxe
end

local function checkAutoBuyPickaxe(manualNotify)
    if not pickaxeShopRemote then return false end
    
    local success, profile = pcall(function()
        return pickaxeShopRemote:InvokeServer("GetPlayerProfile")
    end)
    local listSuccess, allPickaxes = pcall(function()
        return pickaxeShopRemote:InvokeServer("GetList")
    end)
    
    if not (success and listSuccess and allPickaxes) then return false end
    local owned = profile or {}
    local currentMoney = getPlayerMoney()
    
    for _, itemInfo in ipairs(allPickaxes) do
        local alreadyOwned = table.find(owned, itemInfo.name) ~= nil
        local matchesTarget = (config.targetPickaxe == "Next Tier (Urut)") or (config.targetPickaxe:find(itemInfo.name) ~= nil)
        
        if not alreadyOwned and matchesTarget then
            if currentMoney >= itemInfo.price then
                local buyOk, buyRes = pcall(function()
                    return pickaxeShopRemote:InvokeServer("Buy", itemInfo.name)
                end)
                if buyOk and (buyRes == "success" or buyRes == true) then
                    Library:MakeNotify({
                        Title = "Auto Buy Pickaxe",
                        Description = string.format("Selamat! Berhasil membeli %s seharga Rp %s!", itemInfo.name, tostring(itemInfo.price)),
                        Delay = 3.5
                    })
                    if config.autoEquipBestPickaxe then
                        task.delay(0.6, function()
                            equipBestPickaxe(true)
                        end)
                    end
                    return true
                end
            else
                if manualNotify then
                    Library:MakeNotify({
                        Title = "Auto Buy Pickaxe",
                        Description = string.format("Uang belum cukup untuk %s (Kurang Rp %s)", itemInfo.name, tostring(itemInfo.price - currentMoney)),
                        Delay = 2.5
                    })
                end
            end
            break
        end
    end
    return false
end

-- ==================== 5. FITUR AUTO SELL CRYSTAL ====================
local function doSellCrystal(silent)
    if not sellCrystalRemote then return end
    local category = config.sellCrystalCategory or "Sell All"
    local success, totalCash, bonus, totalCount = pcall(function()
        return sellCrystalRemote:InvokeServer("CheckCrystal", category)
    end)
    
    if success and totalCount and tonumber(totalCount) and tonumber(totalCount) > 0 then
        local sellOk, result = pcall(function()
            return sellCrystalRemote:InvokeServer("SellCrystal", category)
        end)
        if sellOk and (result == "Success" or result == true or result == "success") then
            if not silent then
                Library:MakeNotify({
                    Title = "Auto Sell Crystal",
                    Description = string.format("Berhasil menjual %s crystal (+Rp %s)!", tostring(totalCount), tostring(totalCash)),
                    Delay = 2.5
                })
            end
            if config.autoBuyPickaxe then
                task.delay(0.5, function()
                    checkAutoBuyPickaxe(false)
                end)
            end
            return true, totalCount, totalCash
        end
    end
    return false
end

-- ==================== 6. HELPER CRYSTAL VALIDATION & SCORING ====================
local function getCrystalsFolder()
    local mapContent = Workspace:FindFirstChild("MapContent")
    if mapContent then
        return mapContent:FindFirstChild("Crystals")
    end
    return nil
end

local function isCrystalValid(crystal)
    if not (crystal and crystal:IsA("BasePart") and crystal.Parent) then return false end
    if crystal.Transparency >= 0.8 then return false end
    local hpPart = crystal:FindFirstChild("HP")
    if not hpPart then return false end
    local bg = hpPart:FindFirstChildOfClass("BillboardGui")
    if bg then
        local label = bg:FindFirstChildOfClass("TextLabel")
        if label and label.Text and label.Text:find("HP:%s*0") then
            return false
        end
    end
    return true
end

local function getCrystalScore(crystal)
    local light = crystal:FindFirstChildOfClass("PointLight")
    local col = (light and light.Color) or crystal.Color
    local r, g, b = col.R, col.G, col.B
    
    if r > 0.4 and b > 0.5 and g < 0.4 then
        return 4 -- Purple (Epic)
    elseif r > 0.5 and g < 0.3 and b < 0.3 then
        return 3 -- Red (Epic)
    elseif b > 0.5 and r < 0.3 then
        return 2 -- Blue (Rare)
    elseif g > 0.5 and r < 0.4 and b < 0.4 then
        return 1 -- Green (Common)
    end
    return 0 -- Brown / Other
end

-- ==================== ANIMASI & NAVIGASI BERJALAN ====================
local Stuffs = ReplicatedStorage:FindFirstChild("Stuffs")
local miningAnims = Stuffs and Stuffs:FindFirstChild("Anims") and Stuffs.Anims:FindFirstChild("Mining")
local hitAnim = miningAnims and miningAnims:FindFirstChild("Mining Hit")

local function playMiningAnimation()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local animator = hum and hum:FindFirstChildOfClass("Animator")
    local tool = char and char:FindFirstChildOfClass("Tool")
    
    -- Mainkan animasi ayunan pickaxe pada karakter
    if animator and hitAnim then
        local track = animator:LoadAnimation(hitAnim)
        track.Priority = Enum.AnimationPriority.Action
        track:Play()
    end
    
    -- Mainkan efek suara ayunan jika ada di tool
    local handle = tool and tool:FindFirstChild("Handle")
    local swingSound = handle and handle:FindFirstChild("Swing")
    if swingSound and swingSound:IsA("Sound") then
        swingSound:Play()
    end
    
    -- Pemicu aktivasi lokal tool
    if tool then
        pcall(function() tool:Activate() end)
    end
end

local function getWalkStandPosition(crystal, currentPos)
    local cPos = crystal.Position
    local dir = Vector3.new(currentPos.X - cPos.X, 0, currentPos.Z - cPos.Z)
    if dir.Magnitude < 0.1 then
        dir = Vector3.new(0, 0, 1)
    else
        dir = dir.Unit
    end
    local standPoint = cPos + dir * 3.5
    return Vector3.new(standPoint.X, cPos.Y, standPoint.Z)
end

local function walkToTarget(targetPos, maxWaitTime)
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not (hum and hrp) then return false end
    
    maxWaitTime = maxWaitTime or 12
    local startTime = os.clock()
    
    while _G.AutoFishRunning and config.autoMine do
        local curPos = hrp.Position
        local dist = (Vector3.new(curPos.X, targetPos.Y, curPos.Z) - targetPos).Magnitude
        
        -- Sudah sampai dekat kristal (radius 4.5 studs)
        if dist <= 4.5 then
            hum:MoveTo(curPos)
            return true
        end
        
        if (os.clock() - startTime) > maxWaitTime then
            hum:MoveTo(curPos)
            return false
        end
        
        hum:MoveTo(targetPos)
        task.wait(0.15)
    end
    return false
end

-- ==================== 4. FITUR ANTI AFK ====================
local antiAfkConn = nil
local function setupAntiAfk()
    if antiAfkConn then antiAfkConn:Disconnect() end
    antiAfkConn = LocalPlayer.Idled:Connect(function()
        if config.antiAfk then
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
            end)
        end
    end)
    
    task.spawn(function()
        while _G.AutoFishRunning do
            task.wait(600)
            if config.antiAfk then
                pcall(function()
                    VirtualUser:CaptureController()
                    VirtualUser:ClickButton2(Vector2.new())
                end)
            end
        end
    end)
end
setupAntiAfk()

-- ==================== 5. TRACK EVENT SERVER ====================
if _G.AutoFishRemoteConn then
    _G.AutoFishRemoteConn:Disconnect()
end

_G.AutoFishRemoteConn = rodRemote.OnClientEvent:Connect(function(action, ...)
    if action == "StartReeling" then
        FishingState = "REELING"
    elseif action == "StopShake" then
        FishingState = "IDLE"
    end
end)

-- ==================== 6. HOOK MINIGAME REELING ====================
local u134 = TweenInfo.new(1.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 0, false)

env.startFishing = function(penaltyRate, rewardRate)
    FishingState = "REELING"
    
    -- Opsi Instant Catch (Skip Bar)
    if config.instantCatch then
        task.spawn(function()
            task.wait(0.3)
            rodRemote:FireServer("Catch", "Catch")
            env.Reset()
            env.stopShaking()
            env.ShowGUI()
            FishingState = "IDLE"
            
            -- Auto Sell setelah Instant Catch
            if config.autoSell then
                task.wait(0.5)
                doSellFish(false)
            end
        end)
        return
    end

    -- Opsi Auto Follow Garis Merah
    local active = true
    
    local function moveRedBar()
        if not active then return end
        local targetX = (redBar.Position.X.Scale > 0.5) and (0.1 + math.random() * 0.4) or (0.5 + math.random() * 0.4)
        local tween = TweenService:Create(redBar, u134, {
            Position = UDim2.new(targetX, 0, redBar.Position.Y.Scale, 0)
        })
        tween.Completed:Once(function()
            if not active then return end
            task.delay(math.random(2, 3), moveRedBar)
        end)
        tween:Play()
    end
    
    local conn
    conn = RunService.RenderStepped:Connect(function(dt)
        if not active or not reelingGui.Enabled then
            if conn then conn:Disconnect() end
            return
        end
        
        if config.autoFollow then
            local minX = whiteBar.Size.X.Scale * whiteBar.AnchorPoint.X
            local maxX = 1 - whiteBar.Size.X.Scale * (1 - whiteBar.AnchorPoint.X)
            local targetX = math.clamp(redBar.Position.X.Scale, minX, maxX)
            
            whiteBar.Position = UDim2.new(targetX, 0, whiteBar.Position.Y.Scale, 0)
            whiteBar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            
            local rate = (rewardRate or 0.085) * config.reelMultiplier
            local currentProgress = progressBar.Size.X.Scale
            local newProgress = math.clamp(currentProgress + rate * dt, 0, 1)
            progressBar.Size = UDim2.new(newProgress, 0, progressBar.Size.Y.Scale, 0)
            
            if newProgress >= 1 then
                active = false
                if conn then conn:Disconnect() end
                rodRemote:FireServer("Catch", "Catch")
                env.Reset()
                env.stopShaking()
                env.ShowGUI()
                FishingState = "IDLE"
                
                -- Auto Sell setelah berhasil menangkap ikan
                if config.autoSell then
                    task.wait(0.5)
                    doSellFish(false)
                end
            end
        end
    end)
    
    moveRedBar()
end

-- ==================== 7. AUTO CAST LOOP (STATE MACHINE) ====================
task.spawn(function()
    while _G.AutoFishRunning do
        if config.autoCast and not config.autoMine then
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            
            if char and hum and hum.Health > 0 then
                local rod
                if config.autoEquipBestRod then
                    rod = equipBestRod(false)
                else
                    rod = findBestRod()
                    if rod and rod.Parent ~= char then
                        hum:EquipTool(rod)
                        task.wait(0.3)
                    end
                end
                
                if rod then
                    -- HANYA lempar jika status benar-benar IDLE
                    if FishingState == "IDLE" and not reelingGui.Enabled then
                        FishingState = "WAITING_FOR_BITE"
                        rodRemote:FireServer("Throw")
                        
                        -- Tunggu sampai server mengirim event StartReeling (ikan menyambar)
                        local throwStart = os.clock()
                        while _G.AutoFishRunning and FishingState == "WAITING_FOR_BITE" and not reelingGui.Enabled and (os.clock() - throwStart < 18) do
                            task.wait(0.3)
                        end
                        
                        -- Jika timeout 18 detik dan belum ada sambaran, reset agar bisa lempar lagi
                        if FishingState == "WAITING_FOR_BITE" and not reelingGui.Enabled then
                            FishingState = "IDLE"
                            rodRemote:FireServer("Throw")
                            task.wait(1)
                        end
                    elseif FishingState == "REELING" or reelingGui.Enabled then
                        -- Tunggu sampai minigame reeling selesai
                        while _G.AutoFishRunning and (FishingState == "REELING" or reelingGui.Enabled) do
                            task.wait(0.3)
                        end
                        task.wait(config.castDelay)
                        FishingState = "IDLE"
                    else
                        task.wait(0.4)
                    end
                else
                    task.wait(1.5)
                end
            else
                task.wait(1)
            end
        else
            task.wait(1)
        end
    end
end)

-- ==================== 8. AUTO MINING LOOP (CRYSTAL) ====================
task.spawn(function()
    while _G.AutoFishRunning do
        if config.autoMine then
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            
            if char and hum and hum.Health > 0 and hrp then
                -- Pastikan pickaxe terbaik terpasang
                if config.autoEquipBestPickaxe then
                    equipBestPickaxe(false)
                end
                
                -- Cari crystal yang valid
                local crystalsFolder = getCrystalsFolder()
                local targetCrystal = nil
                
                if crystalsFolder then
                    local validCrystals = {}
                    for _, c in ipairs(crystalsFolder:GetChildren()) do
                        if c.Name == "crystal" and isCrystalValid(c) then
                            local dist = (c.Position - hrp.Position).Magnitude
                            table.insert(validCrystals, {crystal = c, dist = dist})
                        end
                    end
                    
                    if #validCrystals > 0 then
                        if config.crystalPriority == "Prioritas Rarity" then
                            table.sort(validCrystals, function(a, b)
                                local scoreA = getCrystalScore(a.crystal)
                                local scoreB = getCrystalScore(b.crystal)
                                if scoreA ~= scoreB then
                                    return scoreA > scoreB
                                end
                                return a.dist < b.dist
                            end)
                        else
                            table.sort(validCrystals, function(a, b)
                                return a.dist < b.dist
                            end)
                        end
                        targetCrystal = validCrystals[1].crystal
                    end
                end
                
                if targetCrystal and isCrystalValid(targetCrystal) then
                    local standPos = getWalkStandPosition(targetCrystal, hrp.Position)
                    local dist = (hrp.Position - targetCrystal.Position).Magnitude
                    
                    -- Jika berada di luar goa (sangat jauh > 80 studs), teleport sekali ke depan goa
                    if dist > 80 then
                        hrp.CFrame = CFrame.new(-124, 0, 211)
                        task.wait(0.5)
                        standPos = getWalkStandPosition(targetCrystal, hrp.Position)
                    end
                    
                    -- BERJALAN alami menuju kristal (tanpa teleportasi)
                    if (hrp.Position - targetCrystal.Position).Magnitude > 4.5 then
                        walkToTarget(standPos, 12)
                    end
                    
                    -- Hadapkan karakter ke kristal
                    if isCrystalValid(targetCrystal) then
                        hrp.CFrame = CFrame.new(hrp.Position, Vector3.new(targetCrystal.Position.X, hrp.Position.Y, targetCrystal.Position.Z))
                    end
                    
                    -- Pukul crystal dengan animasi nambang sampai hancur
                    local hitCount = 0
                    while _G.AutoFishRunning and config.autoMine and isCrystalValid(targetCrystal) and hitCount < 10 do
                        -- Hadapkan karakter ke crystal
                        hrp.CFrame = CFrame.new(hrp.Position, Vector3.new(targetCrystal.Position.X, hrp.Position.Y, targetCrystal.Position.Z))
                        
                        -- Mainkan animasi ayunan pickaxe + suara ayunan
                        playMiningAnimation()
                        
                        -- Kirim Remote Hit
                        pickaxeRemote:FireServer("Hit")
                        hitCount = hitCount + 1
                        
                        task.wait(config.mineInterval or 1.5)
                    end
                    
                    -- Cek Auto Sell Crystal setelah berhasil menambang
                    if config.autoSellCrystal then
                        pcall(function()
                            doSellCrystal(true)
                        end)
                    end
                    
                    task.wait(0.3)
                else
                    -- Menunggu crystal respawn di goa
                    task.wait(2)
                end
            else
                task.wait(1)
            end
        else
            task.wait(1)
        end
    end
end)

-- Background loop berkala: Auto Sell & Auto Buy Rod / Pickaxe setiap 20 detik
task.spawn(function()
    while _G.AutoFishRunning do
        task.wait(20)
        if config.autoSell and FishingState == "WAITING_FOR_BITE" and not config.autoMine then
            pcall(function()
                doSellFish(true)
            end)
        end
        if config.autoBuyRod then
            pcall(function()
                checkAutoBuyRod(false)
            end)
        end
        if config.autoBuyPickaxe then
            pcall(function()
                checkAutoBuyPickaxe(false)
            end)
        end
        if config.autoSellCrystal and config.autoMine then
            pcall(function()
                doSellCrystal(true)
            end)
        end
    end
end)

-- ==================== 8. MENU UI LYNXGUI ====================
local Window = Library:Window({
    Title = "Indo Hangout",
    Footer = "LynX Hub - Fishing & Mining"
})

local MainTab = Window:AddTab({
    Name = "Mancing",
    Icon = "start"
})

-- SECTION 1: FITUR MANCING & REELING
local FishSection = MainTab:AddSection("Fitur Utama", true)

FishSection:AddToggle({
    Title = "Auto Lempar Loop (Non-Stop)",
    Default = true,
    Callback = function(state)
        config.autoCast = state
        if not state then
            FishingState = "IDLE"
        end
        Library:MakeNotify({
            Title = "Auto Cast",
            Description = state and "Auto Cast AKTIF! Pancingan akan melempar dan menunggu sambaran." or "Auto Cast dinonaktifkan.",
            Delay = 2.5
        })
    end
})

FishSection:AddToggle({
    Title = "Auto Follow Garis Merah",
    Default = true,
    Callback = function(state)
        config.autoFollow = state
        Library:MakeNotify({
            Title = "Auto Follow",
            Description = state and "Bar putih akan otomatis menempel di garis merah!" or "Auto Follow dinonaktifkan.",
            Delay = 2
        })
    end
})

FishSection:AddToggle({
    Title = "Instant Catch (Skip Bar)",
    Default = false,
    Callback = function(state)
        config.instantCatch = state
        Library:MakeNotify({
            Title = "Instant Catch",
            Description = state and "Minigame bar di-skip! Tangkap ikan seketika saat menyambar." or "Instant Catch dinonaktifkan.",
            Delay = 2
        })
    end
})

FishSection:AddDropdown({
    Title = "Kecepatan Reeling",
    Multi = false,
    Options = {"1x (Normal)", "2x (Cepat)", "5x (Sangat Cepat)"},
    Default = "1x (Normal)",
    Callback = function(val)
        if val == "2x (Cepat)" then
            config.reelMultiplier = 2.0
        elseif val == "5x (Sangat Cepat)" then
            config.reelMultiplier = 5.0
        else
            config.reelMultiplier = 1.0
        end
    end
})

-- SECTION 2: TOKO & JUAL BELI (AUTO SELL & AUTO BUY)
local ShopSection = MainTab:AddSection("Auto Sell & Auto Buy Rod", true)

ShopSection:AddToggle({
    Title = "Auto Sell Ikan (Otomatis Jual)",
    Default = true,
    Callback = function(state)
        config.autoSell = state
        Library:MakeNotify({
            Title = "Auto Sell",
            Description = state and "Auto Sell AKTIF! Ikan akan langsung dijual setelah didapat." or "Auto Sell dinonaktifkan.",
            Delay = 2.5
        })
    end
})

ShopSection:AddDropdown({
    Title = "Kategori Auto Sell",
    Multi = false,
    Options = {"Sell All", "All under 50 Kg", "All under 100 Kg", "All under 400 Kg", "All under 600 Kg"},
    Default = "Sell All",
    Callback = function(val)
        config.sellCategory = val or "Sell All"
    end
})

ShopSection:AddButton({
    Title = "Jual Ikan Sekarang (Sell Now)",
    Callback = function()
        local ok, count, cash = doSellFish(false)
        if not ok then
            Library:MakeNotify({
                Title = "Auto Sell",
                Description = "Tidak ada ikan yang bisa dijual saat ini.",
                Delay = 2
            })
        end
    end
})

ShopSection:AddToggle({
    Title = "Auto Buy Rod (Beli Otomatis Saat Cukup)",
    Default = true,
    Callback = function(state)
        config.autoBuyRod = state
        Library:MakeNotify({
            Title = "Auto Buy Rod",
            Description = state and "Auto Buy AKTIF! Rod baru akan otomatis dibeli saat uang cukup." or "Auto Buy dinonaktifkan.",
            Delay = 2.5
        })
    end
})

ShopSection:AddDropdown({
    Title = "Target Pembelian Rod",
    Multi = false,
    Options = {
        "Next Tier (Urut)",
        "Shark Rod (300k)",
        "Piranha Rod (450k)",
        "Thermo Rod (600k)",
        "Flowers Rod (750k)",
        "Trisula Rod (950k)",
        "Voltric Rod (8M)"
    },
    Default = "Next Tier (Urut)",
    Callback = function(val)
        config.targetRod = val or "Next Tier (Urut)"
    end
})

ShopSection:AddButton({
    Title = "Cek & Beli Target Rod Sekarang",
    Callback = function()
        checkAutoBuyRod(true)
    end
})

ShopSection:AddToggle({
    Title = "Auto Equip Best Rod",
    Default = true,
    Callback = function(state)
        config.autoEquipBestRod = state
        if state then
            equipBestRod(true)
        end
        Library:MakeNotify({
            Title = "Auto Equip",
            Description = state and "Auto Equip AKTIF! Pancingan terbaik akan otomatis dipakai." or "Auto Equip dinonaktifkan.",
            Delay = 2.5
        })
    end
})

ShopSection:AddButton({
    Title = "Equip Best Rod Sekarang",
    Callback = function()
        equipBestRod(true)
    end
})

-- SECTION 3: UTILITY, SPOT & AFK
local UtilSection = MainTab:AddSection("Spot & AFK", true)

UtilSection:AddToggle({
    Title = "Anti AFK (Cegah Disconnect 20 Menit)",
    Default = true,
    Callback = function(state)
        config.antiAfk = state
        Library:MakeNotify({
            Title = "Anti AFK",
            Description = state and "Anti AFK diaktifkan (Aman dari kick 20 menit)." or "Anti AFK dinonaktifkan.",
            Delay = 2
        })
    end
})

UtilSection:AddButton({
    Title = "Teleport ke Bibir Pantai (Menghadap Laut)",
    Callback = function()
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.CFrame = CFrame.new(Vector3.new(73.57, 1, -332.49), Vector3.new(73.57 - 50, 1, -332.49))
            Library:MakeNotify({
                Title = "Teleport",
                Description = "Berhasil teleport ke spot mancing menghadap laut!",
                Delay = 2.5
            })
        end
    end
})

UtilSection:AddParagraph({
    Title = "[i] Panduan Auto Buy & Equip",
    Content = "1. 'Auto Equip Best Rod': Otomatis mendeteksi dan memakai rod terbaik yang Anda miliki (Genesis > Anubis > Dragon > Voltric > Trisula > Flowers > Thermo > Piranha > Shark > Party > Basic).\n2. 'Next Tier (Urut)': Otomatis membeli rod terbaik berikutnya secara bertahap begitu uang cukup, lalu langsung otomatis dipasang ke tangan!\n3. Uang didapatkan otomatis dari hasil Auto Sell ikan."
})

-- ==================== TAB 2: MINING & CRYSTAL ====================
local MineTab = Window:AddTab({
    Name = "Mining",
    Icon = "cart"
})

-- SECTION 1: FITUR AUTO MINING
local MineSection = MineTab:AddSection("Fitur Auto Mining", true)

MineSection:AddToggle({
    Title = "Auto Mine Crystal (Cari & Tambang)",
    Default = false,
    Callback = function(state)
        config.autoMine = state
        if state then
            Library:MakeNotify({
                Title = "Auto Mining",
                Description = "Auto Mine AKTIF! Karakter akan mencari & menambang crystal di goa.",
                Delay = 3
            })
            equipBestPickaxe(true)
        else
            Library:MakeNotify({
                Title = "Auto Mining",
                Description = "Auto Mine dinonaktifkan.",
                Delay = 2
            })
        end
    end
})

MineSection:AddDropdown({
    Title = "Prioritas Pemilihan Crystal",
    Multi = false,
    Options = {"Terdekat (Nearest)", "Prioritas Rarity"},
    Default = "Terdekat (Nearest)",
    Callback = function(val)
        config.crystalPriority = val or "Terdekat (Nearest)"
    end
})

MineSection:AddDropdown({
    Title = "Jeda Ayunan (Mine Cooldown)",
    Multi = false,
    Options = {"1.5s (Aman/Normal)", "1.2s (Cepat)", "1.0s (Maksimal)"},
    Default = "1.5s (Aman/Normal)",
    Callback = function(val)
        if val == "1.2s (Cepat)" then
            config.mineInterval = 1.2
        elseif val == "1.0s (Maksimal)" then
            config.mineInterval = 1.0
        else
            config.mineInterval = 1.5
        end
    end
})

MineSection:AddToggle({
    Title = "Auto Equip Best Pickaxe",
    Default = true,
    Callback = function(state)
        config.autoEquipBestPickaxe = state
        if state then
            equipBestPickaxe(true)
        end
        Library:MakeNotify({
            Title = "Auto Equip Pickaxe",
            Description = state and "Auto Equip Pickaxe AKTIF!" or "Auto Equip Pickaxe dinonaktifkan.",
            Delay = 2
        })
    end
})

MineSection:AddButton({
    Title = "Equip Best Pickaxe Sekarang",
    Callback = function()
        equipBestPickaxe(true)
    end
})

-- SECTION 2: AUTO SELL CRYSTAL & AUTO BUY PICKAXE
local MineShopSection = MineTab:AddSection("Auto Sell Crystal & Buy Pickaxe", true)

MineShopSection:AddToggle({
    Title = "Auto Sell Crystal (Otomatis Jual)",
    Default = true,
    Callback = function(state)
        config.autoSellCrystal = state
        Library:MakeNotify({
            Title = "Auto Sell Crystal",
            Description = state and "Auto Sell Crystal AKTIF!" or "Auto Sell Crystal dinonaktifkan.",
            Delay = 2
        })
    end
})

MineShopSection:AddDropdown({
    Title = "Kategori Auto Sell Crystal",
    Multi = false,
    Options = {"Sell All", "All under 50 Kg", "All under 100 Kg", "All under 400 Kg", "All under 600 Kg"},
    Default = "Sell All",
    Callback = function(val)
        config.sellCrystalCategory = val or "Sell All"
    end
})

MineShopSection:AddButton({
    Title = "Jual Crystal Sekarang (Sell Now)",
    Callback = function()
        local ok, count, cash = doSellCrystal(false)
        if not ok then
            Library:MakeNotify({
                Title = "Auto Sell Crystal",
                Description = "Tidak ada crystal yang bisa dijual saat ini.",
                Delay = 2
            })
        end
    end
})

MineShopSection:AddToggle({
    Title = "Auto Buy Pickaxe (Beli Saat Cukup)",
    Default = true,
    Callback = function(state)
        config.autoBuyPickaxe = state
        Library:MakeNotify({
            Title = "Auto Buy Pickaxe",
            Description = state and "Auto Buy Pickaxe AKTIF!" or "Auto Buy Pickaxe dinonaktifkan.",
            Delay = 2.5
        })
    end
})

MineShopSection:AddDropdown({
    Title = "Target Pembelian Pickaxe",
    Multi = false,
    Options = {
        "Next Tier (Urut)",
        "Gold Pickaxe (150k)",
        "Ruby Pickaxe (300k)",
        "Frost Pickaxe (500k)",
        "Emerald Pickaxe (700k)",
        "Candy Pickaxe (950k)"
    },
    Default = "Next Tier (Urut)",
    Callback = function(val)
        config.targetPickaxe = val or "Next Tier (Urut)"
    end
})

MineShopSection:AddButton({
    Title = "Cek & Beli Target Pickaxe Sekarang",
    Callback = function()
        checkAutoBuyPickaxe(true)
    end
})

-- SECTION 3: SPOT GOA & TELEPORTASI
local MineUtilSection = MineTab:AddSection("Spot Goa & Teleportasi", true)

MineUtilSection:AddButton({
    Title = "Teleport ke Goa Crystal (Area Tambang)",
    Callback = function()
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.CFrame = CFrame.new(-124, 0, 211)
            Library:MakeNotify({
                Title = "Teleport",
                Description = "Berhasil teleport ke Goa Crystal!",
                Delay = 2.5
            })
        end
    end
})

MineUtilSection:AddButton({
    Title = "Teleport ke NPC Jual Crystal (Goa)",
    Callback = function()
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.CFrame = CFrame.new(-226.81, 17.04, 298.81)
            Library:MakeNotify({
                Title = "Teleport",
                Description = "Berhasil teleport ke NPC Jual Crystal di Goa!",
                Delay = 2.5
            })
        end
    end
})

MineUtilSection:AddButton({
    Title = "Teleport ke Toko Pickaxe (NPC)",
    Callback = function()
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.CFrame = CFrame.new(139.75, 41.80, 109.74)
            Library:MakeNotify({
                Title = "Teleport",
                Description = "Berhasil teleport ke NPC Toko Pickaxe!",
                Delay = 2.5
            })
        end
    end
})

MineUtilSection:AddParagraph({
    Title = "[i] Panduan Auto Mining Crystal",
    Content = "1. 'Auto Mine Crystal': Script akan otomatis mencari kristal aktif di dalam goa, berjalan alami ke sampingnya (tanpa teleport), dan memukulnya dengan animasi nambang lengkap hingga pecah.\n2. 'Auto Equip Best Pickaxe': Memastikan kamu selalu menggunakan pickaxe terbaik (Candy > Emerald > Frost > Ruby > Gold > Basic).\n3. 'Auto Sell Crystal': Kristal yang ditambang akan langsung dijual otomatis dan uang langsung bertambah.\n4. 'Auto Buy Pickaxe': Membeli pickaxe tier berikutnya saat uang cukup."
})

Library:MakeNotify({
    Title = "Indo Hangout",
    Description = "Script Indo Hangout (Fishing & Mining) siap digunakan!",
    Delay = 3
})
