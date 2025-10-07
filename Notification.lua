--// =========================
--//  ESP Panel Rainbow + Player ESP
--//  Modo: SIN LÍMITE + solo marcar nuevos + 15s de duración por brainrot
--// =========================

-- Servicios
local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Utilidades
local DEBUG = false
local function dprint(...) if DEBUG then print(...) end end

local function dictCount(t) local c=0 for _ in pairs(t) do c+=1 end return c end

local function isInstance(x) return typeof(x)=="Instance" end
local function isObjectValid(obj)
    return isInstance(obj) and obj.Parent ~= nil and obj:IsDescendantOf(game)
end
local function safeDestroy(x)
    if isInstance(x) and x.Destroy then x:Destroy() end
end

-- Highlight helper (Adornee en el objetivo; parent en workspace)
local function newHighlightFor(target)
    local h = Instance.new("Highlight")
    h.FillTransparency = 0.5
    h.OutlineTransparency = 0.2
    h.OutlineColor = Color3.fromRGB(255,255,255)
    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    h.Adornee = target
    h.Parent = workspace
    return h
end

local function hsv(h) return Color3.fromHSV(h,1,1) end

-- =======================
-- Objetivos (nombres exactos)
-- =======================
local targetModels = {
    "La Secret Combinasion","Burguro And Fryuro","Los 67","Chillin Chili","Tang Tang Kelentang",
    "Money Money Puggy","Los Primos","Los Tacoritas","La Grande Combinasion","Pot Hotspot",
    "Mariachi Corazoni","Secret Lucky Block","To to to Sahur","Strawberry Elephant",
    "Ketchuru and Musturu","La Extinct Grande","Tictac Sahur","Tacorita Bicicleta",
    "Chicleteira Bicicleteira","Spaghetti Tualetti","Esok Sekolah","Los Chicleteiras","67",
    "Los Combinasionas","Nuclearo Dinosauro","Las Sis","Los Hotspotsitos","Tralaledon",
    "Ketupat Kepat","Los Bros","La Supreme Combinasion","Ketchuru and Masturu",
    "Garama and Madundung","Dragon Cannelloni","Celularcini Viciosini"
}
local targetSet = {} for _,n in ipairs(targetModels) do targetSet[n]=true end

-- =======================
-- Estado ESP de Brainrots
-- =======================
-- everMarked: todo lo que ya se marcó UNA VEZ (no volver a marcarlo)
-- activeMarks: lo actualmente resaltado (con expiración por tiempo)
-- activeMarks[Instance] = {highlight=Highlight, createdAt=number, initialHue=number}
local everMarked   = setmetatable({}, {__mode="k"})   -- débil por clave (libera si el Instance se destruye)
local activeMarks  = setmetatable({}, {__mode="k"})

local MARK_DURATION = 15 -- segundos
local rainbowHue    = 0
local rainbowSpeed  = 0.5

-- =======================
-- Player ESP
-- =======================
local linePool = {}
local function acquireLine()
    local line = table.remove(linePool)
    if line then line.Parent = workspace; return line end
    line = Instance.new("Part")
    line.Name = "PlayerESPLine"
    line.Size = Vector3.new(0.1,0.1,1)
    line.Material = Enum.Material.Neon
    line.BrickColor = BrickColor.new("Really red")
    line.Anchored = true
    line.CanCollide = false
    line.Parent = workspace
    return line
end
local function releaseLine(line) if line then line.Parent=nil table.insert(linePool,line) end end

local playerESPData = {} -- userId -> {targetPlayer, highlight, line}

local function createPlayerESP(targetPlayer)
    if targetPlayer == player then return end
    local char = targetPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local hl = newHighlightFor(char)
    hl.FillColor = Color3.fromRGB(255,0,0)
    local line = acquireLine()
    playerESPData[targetPlayer.UserId] = {targetPlayer=targetPlayer, highlight=hl, line=line}
end

local function updatePlayerESPLines()
    local myChar = player.Character
    local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myHRP then return end
    local myPos = myHRP.Position
    local toRemove = {}
    for uid, esp in pairs(playerESPData) do
        local p = esp.targetPlayer
        local char = p and p.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not (p and char and hrp and esp.line and isObjectValid(esp.line)) then
            table.insert(toRemove, uid)
        else
            local tpos = hrp.Position
            local dir  = tpos - myPos
            local dist = dir.Magnitude
            local mid  = myPos + dir*0.5
            local line = esp.line
            line.Size  = Vector3.new(0.1,0.1,dist)
            line.CFrame = CFrame.lookAt(mid, tpos)
        end
    end
    for _,uid in ipairs(toRemove) do
        local d = playerESPData[uid]
        if d then
            safeDestroy(d.highlight)
            releaseLine(d.line)
            playerESPData[uid] = nil
        end
    end
end

local function cleanupPlayerESP()
    for uid,esp in pairs(playerESPData) do
        safeDestroy(esp.highlight)
        releaseLine(esp.line)
        playerESPData[uid] = nil
    end
end

local function updatePlayerESP()
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            if not playerESPData[p.UserId] then
                createPlayerESP(p)
            end
        end
    end
end

-- =======================
-- GUI
-- =======================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ESPPanel"
screenGui.Parent = playerGui
screenGui.ResetOnSpawn = false

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainPanel"
mainFrame.Size = UDim2.new(0, 200, 0, 200)
mainFrame.Position = UDim2.new(1, -210, 0, 10)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui
do local c=Instance.new("UICorner") c.CornerRadius=UDim.new(0,8) c.Parent=mainFrame end

-- Persistencia de posición
local function savePos()
    local p = mainFrame.Position
    playerGui:SetAttribute("ESPPanelPosXS", p.X.Scale)
    playerGui:SetAttribute("ESPPanelPosXO",  p.X.Offset)
    playerGui:SetAttribute("ESPPanelPosYS", p.Y.Scale)
    playerGui:SetAttribute("ESPPanelPosYO",  p.Y.Offset)
end
local function loadPos()
    local xs=playerGui:GetAttribute("ESPPanelPosXS")
    local xo=playerGui:GetAttribute("ESPPanelPosXO")
    local ys=playerGui:GetAttribute("ESPPanelPosYS")
    local yo=playerGui:GetAttribute("ESPPanelPosYO")
    if typeof(xs)=="number" and typeof(xo)=="number" and typeof(ys)=="number" and typeof(yo)=="number" then
        mainFrame.Position = UDim2.new(xs,xo,ys,yo)
    end
end
loadPos()
mainFrame:GetPropertyChangedSignal("Position"):Connect(savePos)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1,0,0,30)
title.BackgroundColor3 = Color3.fromRGB(50,50,50)
title.Text = "ESP Panel"
title.TextColor3 = Color3.new(1,1,1)
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.Parent = mainFrame
do local c=Instance.new("UICorner") c.CornerRadius=UDim.new(0,8) c.Parent=title end

local function newBtn(name, y, text, bg)
    local b = Instance.new("TextButton")
    b.Name=name
    b.Size=UDim2.new(1,-20,0,30)
    b.Position=UDim2.new(0,10,0,y)
    b.BackgroundColor3=bg
    b.Text=text
    b.TextColor3=Color3.new(1,1,1)
    b.TextScaled=true
    b.Font=Enum.Font.Gotham
    b.Parent=mainFrame
    local c=Instance.new("UICorner") c.CornerRadius=UDim.new(0,5) c.Parent=b
    return b
end

local espEnabled=false
local notifEnabled=false
local contEnabled=true
local playerESPEnabled=false

local espBtn        = newBtn("ESPButton",         40,"ESP: OFF",              Color3.fromRGB(255,50,50))
local notifBtn      = newBtn("NotifButton",       80,"Notificaciones: OFF",   Color3.fromRGB(255,50,50))
local contBtn       = newBtn("ContinuousButton", 120,"Búsqueda Continua: ON", Color3.fromRGB(50,255,50))
local playerESPBtn  = newBtn("PlayerESPButton",  160,"ESP Player: OFF",       Color3.fromRGB(255,50,50))

-- Notificación simple (visual)
local function showToast(text)
    local gui = Instance.new("ScreenGui")
    gui.Name = "NotificationToast"
    gui.Parent = playerGui

    local f = Instance.new("Frame")
    f.Size = UDim2.new(0,350,0,90)
    f.Position = UDim2.new(0.5,-175,1,-100)
    f.BackgroundColor3 = Color3.fromRGB(40,40,40)
    f.BorderSizePixel=0
    f.Parent = gui
    local c = Instance.new("UICorner") c.CornerRadius=UDim.new(0,10) c.Parent=f

    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency=1
    lbl.Size=UDim2.new(1,-20,1,-20)
    lbl.Position=UDim2.new(0,10,0,10)
    lbl.Text=text
    lbl.TextScaled=true
    lbl.TextColor3 = Color3.new(1,1,1)
    lbl.Font = Enum.Font.Gotham
    lbl.Parent = f

    f.Position = UDim2.new(0.5,-175,1,0)
    TweenService:Create(f, TweenInfo.new(0.4, Enum.EasingStyle.Back), {Position=UDim2.new(0.5,-175,1,-100)}):Play()
    task.spawn(function()
        task.wait(4)
        local tw = TweenService:Create(f, TweenInfo.new(0.35), {Position=UDim2.new(0.5,-175,1,0)})
        tw:Play()
        tw.Completed:Once(function() safeDestroy(gui) end)
    end)
end

-- =======================
-- Lógica de marcado SIN LÍMITE + solo nuevos + 15s
-- =======================

-- Marca una instancia (si no fue marcada antes) y programa su expiración a 15s
local function markInstanceOnce(inst)
    if not isObjectValid(inst) then return end
    if everMarked[inst] then return end -- ya fue marcada alguna vez
    everMarked[inst] = true

    local hl = newHighlightFor(inst)
    hl.FillColor = hsv(rainbowHue)

    activeMarks[inst] = {
        highlight  = hl,
        createdAt  = time(),
        initialHue = rainbowHue
    }
end

-- Escanea TODO el mapa y marca SOLO los que aún no se han marcado nunca
local VISIT_QUOTA = 800 -- solo influye en rendimiento; NO limita cantidad
local function scanAndMarkNew()
    local visited = 0
    local function search(container, depth)
        if depth > 12 then return end
        for _,child in ipairs(container:GetChildren()) do
            if isObjectValid(child) then
                visited += 1
                if visited % VISIT_QUOTA == 0 then task.wait() end

                if targetSet[child.Name] and (child:IsA("Model") or child:IsA("BasePart")) then
                    markInstanceOnce(child)
                end
                if child:IsA("Folder") or child:IsA("Model") then
                    search(child, depth+1)
                end
            end
        end
    end
    search(workspace, 0)
end

-- Quita highlights que ya pasaron de 15s o que quedaron inválidos
local function expireAndCleanupMarks()
    local now = time()
    local removed = 0
    for inst, data in pairs(activeMarks) do
        local invalid = (not isObjectValid(inst)) or (not data.highlight) or (not isObjectValid(data.highlight))
        local expired = (not invalid) and (now - data.createdAt >= MARK_DURATION)
        if invalid or expired then
            if data.highlight then safeDestroy(data.highlight) end
            activeMarks[inst] = nil
            removed += 1
        end
    end
    if removed>0 then dprint("🗑️ Highlights removidos:", removed) end
end

-- Actualiza colores arcoíris en lo actualmente activo
local function updateRainbowActive()
    for inst, data in pairs(activeMarks) do
        local hl = data.highlight
        if hl and isObjectValid(hl) then
            local hue = (data.initialHue + (time()-data.createdAt)*rainbowSpeed) % 1
            hl.FillColor = hsv(hue)
        end
    end
end

-- Primera pasada: marca TODO lo que existe, una sola vez
local function initialFullScan()
    scanAndMarkNew()
    dprint("✅ Initial full scan: everMarked =", dictCount(everMarked), "active =", dictCount(activeMarks))
end

-- En búsqueda continua: SOLO busca nuevos (no re-marca viejos)
local lastScanAt = 0
local scanInterval = 2 -- s
local function continuousScan()
    if not contEnabled then return end
    local now = time()
    if now - lastScanAt < scanInterval then return end
    lastScanAt = now
    scanAndMarkNew()
end

-- =======================
-- Eventos GUI
-- =======================
espBtn.MouseButton1Click:Connect(function()
    espEnabled = not espEnabled
    if espEnabled then
        espBtn.Text = "ESP: ON"
        espBtn.BackgroundColor3 = Color3.fromRGB(50,255,50)
        -- arranque: marcar todo lo que exista (solo nuevos)
        initialFullScan()
        showToast("ESP activado: marcando brainrots (15s cada uno)")
    else
        espBtn.Text = "ESP: OFF"
        espBtn.BackgroundColor3 = Color3.fromRGB(255,50,50)
        -- Apaga highlights activos (everMarked se mantiene para no re-marcar)
        for inst,data in pairs(activeMarks) do
            safeDestroy(data.highlight)
            activeMarks[inst] = nil
        end
        showToast("ESP desactivado")
    end
end)

notifBtn.MouseButton1Click:Connect(function()
    notifEnabled = not notifEnabled
    notifBtn.Text = notifEnabled and "Notificaciones: ON" or "Notificaciones: OFF"
    notifBtn.BackgroundColor3 = notifEnabled and Color3.fromRGB(50,255,50) or Color3.fromRGB(255,50,50)
end)

contBtn.MouseButton1Click:Connect(function()
    contEnabled = not contEnabled
    contBtn.Text = contEnabled and "Búsqueda Continua: ON" or "Búsqueda Continua: OFF"
    contBtn.BackgroundColor3 = contEnabled and Color3.fromRGB(50,255,50) or Color3.fromRGB(255,50,50)
end)

playerESPBtn.MouseButton1Click:Connect(function()
    playerESPEnabled = not playerESPEnabled
    if playerESPEnabled then
        playerESPBtn.Text = "ESP Player: ON"
        playerESPBtn.BackgroundColor3 = Color3.fromRGB(50,255,50)
        updatePlayerESP()
    else
        playerESPBtn.Text = "ESP Player: OFF"
        playerESPBtn.BackgroundColor3 = Color3.fromRGB(255,50,50)
        cleanupPlayerESP()
    end
end)

-- =======================
-- Eventos Jugadores
-- =======================
Players.PlayerAdded:Connect(function(p)
    if playerESPEnabled then
        local function onChar(_)
            task.wait(0.2)
            local old = playerESPData[p.UserId]
            if old then safeDestroy(old.highlight) releaseLine(old.line) playerESPData[p.UserId]=nil end
            createPlayerESP(p)
        end
        if p.Character then onChar(p.Character) end
        p.CharacterAdded:Connect(onChar)
    end
    if espEnabled and notifEnabled then
        showToast("🚨 "..p.Name.." se unió")
    end
end)

Players.PlayerRemoving:Connect(function(p)
    local d = playerESPData[p.UserId]
    if d then safeDestroy(d.highlight) releaseLine(d.line) playerESPData[p.UserId]=nil end
end)

for _,p in ipairs(Players:GetPlayers()) do
    if p~=player then
        p.CharacterAdded:Connect(function(_)
            if playerESPEnabled then
                task.wait(0.2)
                local d = playerESPData[p.UserId]
                if d then safeDestroy(d.highlight) releaseLine(d.line) playerESPData[p.UserId]=nil end
                createPlayerESP(p)
            end
        end)
    end
end

-- =======================
-- Loop principal
-- =======================
local lastPlayerESPUpd = 0
RunService.Heartbeat:Connect(function()
    rainbowHue = (rainbowHue + 0.02) % 1

    if espEnabled then
        -- actualizar colores y expiraciones
        updateRainbowActive()
        expireAndCleanupMarks()
        -- marcar solo NUEVOS en continuo
        continuousScan()
    end

    if playerESPEnabled then
        local now = time()
        if now - lastPlayerESPUpd >= 1/33 then
            lastPlayerESPUpd = now
            updatePlayerESPLines()
        end
    end
end)

-- =======================
-- Debug helpers
-- =======================
_G.setScanInterval = function(s) scanInterval = tonumber(s) or 2 end
_G.toggleDebug = function() DEBUG = not DEBUG print("DEBUG:",DEBUG) end

print("🚀 ESP Panel listo (sin límite, 15s por brainrot, solo nuevos en continuo)")
print("🎯 Nombres válidos:", dictCount(targetSet))
