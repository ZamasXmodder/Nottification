--// =========================
--//  ESP Panel Rainbow + Player ESP (versión optimizada)
--//  Mejoras: time()/task.*, pooling de líneas, Highlight.Adornee, validaciones seguras,
--//  consolidación de eventos, logs opcionales, GUI arrastrable, sonido único, dedup de targets.
--// =========================

--// Servicios
local Players            = game:GetService("Players")
local RunService         = game:GetService("RunService")
local SoundService       = game:GetService("SoundService")
local TweenService       = game:GetService("TweenService")
local UserInputService   = game:GetService("UserInputService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

--// ================
--// Config/Utilidades
--// ================
local DEBUG = false
local function dprint(...) if DEBUG then print(...) end end

-- Conteo seguro de diccionarios
local function dictCount(t)
    local c = 0
    for _ in pairs(t) do c += 1 end
    return c
end

-- Validación robusta de instancia viva
local function isObjectValid(obj)
    return typeof(obj) == "Instance" and obj.Parent ~= nil and obj:IsDescendantOf(game)
end

-- Son utilidades para destruir sin error
local function safeDestroy(x)
    if x and typeof(x) == "Instance" and x.Destroy then
        x:Destroy()
    end
end

-- Pool de líneas para reducir GC/instancias
local linePool = {}
local function acquireLine()
    local line = table.remove(linePool)
    if line then
        line.Parent = workspace
        return line
    end
    line = Instance.new("Part")
    line.Name = "PlayerESPLine"
    line.Size = Vector3.new(0.1, 0.1, 1)
    line.Material = Enum.Material.Neon
    line.BrickColor = BrickColor.new("Really red")
    line.Anchored = true
    line.CanCollide = false
    line.Parent = workspace
    return line
end

local function releaseLine(line)
    if not line then return end
    line.Parent = nil
    table.insert(linePool, line)
end

-- Highlight fábrica (mejor con Adornee y parent en workspace)
local function newHighlightFor(target)
    local h = Instance.new("Highlight")
    h.FillTransparency = 0.5
    h.OutlineTransparency = 0.2
    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    h.OutlineColor = Color3.fromRGB(255, 255, 255)
    h.Adornee = target
    h.Parent = workspace
    return h
end

-- Genera color rainbow
local function getRainbowColor(hue)
    return Color3.fromHSV(hue, 1, 1)
end

-- =======================
-- Objetivos (deduplicados)
-- =======================
local targetModels = {
    "La Secret Combinasion",
    "Burguro And Fryuro",
    "Los 67",
    "Chillin Chili",
    "Tang Tang Kelentang",
    "Money Money Puggy",
    "Los Primos",
    "Los Tacoritas",
    "La Grande Combinasion",
    "Pot Hotspot",
    "Mariachi Corazoni",
    "Secret Lucky Block",
    "To to to Sahur",
    "Strawberry Elephant",
    "Ketchuru and Musturu",
    "La Extinct Grande",
    "Tictac Sahur",
    "Tacorita Bicicleta",
    "Chicleteira Bicicleteira",
    "Spaghetti Tualetti", 
    "Esok Sekolah",
    -- "La Grande Combinasion", -- duplicado
    "Los Chicleteiras",
    "67",
    "Los Combinasionas",
    "Nuclearo Dinosauro",
    "Las Sis",
    "Los Hotspotsitos",
    "Tralaledon",
    "Ketupat Kepat",
    "Los Bros",
    "La Supreme Combinasion",
    "Ketchuru and Masturu",
    "Garama and Madundung",
    "Dragon Cannelloni",
    "Celularcini Viciosini"
}

local targetSet = {}
for _, name in ipairs(targetModels) do
    targetSet[name] = true
end

-- =======================
-- Estado / Variables
-- =======================
local espEnabled              = false
local notificationsEnabled    = false
local playerESPEnabled        = false

local espLines        = {}     -- { {highlight, timestamp, targetName, uniqueId, targetObject, initialHue}, ... }
local trackedPlayers  = {}     -- userId => true
local playerESPData   = {}     -- userId => { targetPlayer, highlight, line, timestamp }

-- Memoria anti redetección
local detectedBrainrots = {}   -- memoryId => {timestamp, name}

-- Efecto rainbow
local rainbowHue = 0

-- Búsqueda continua
local continuousSearchEnabled = true
local lastSearchTime = 0
local searchInterval = 2 -- segundos

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

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = mainFrame

-- Persistencia simple de posición (en atributos: 4 números)
local function savePanelPos()
    local pos = mainFrame.Position
    playerGui:SetAttribute("ESPPanelPosXS", pos.X.Scale)
    playerGui:SetAttribute("ESPPanelPosXO",  pos.X.Offset)
    playerGui:SetAttribute("ESPPanelPosYS", pos.Y.Scale)
    playerGui:SetAttribute("ESPPanelPosYO",  pos.Y.Offset)
end

local function loadPanelPos()
    local xs = playerGui:GetAttribute("ESPPanelPosXS")
    local xo = playerGui:GetAttribute("ESPPanelPosXO")
    local ys = playerGui:GetAttribute("ESPPanelPosYS")
    local yo = playerGui:GetAttribute("ESPPanelPosYO")
    if typeof(xs) == "number" and typeof(xo) == "number" and typeof(ys) == "number" and typeof(yo) == "number" then
        mainFrame.Position = UDim2.new(xs, xo, ys, yo)
    end
end
loadPanelPos()
mainFrame:GetPropertyChangedSignal("Position"):Connect(savePanelPos)

-- Título
local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.Size = UDim2.new(1, 0, 0, 30)
titleLabel.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
titleLabel.Text = "ESP Panel"
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextScaled = true
titleLabel.Font = Enum.Font.GothamBold
titleLabel.Parent = mainFrame

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 8)
titleCorner.Parent = titleLabel

-- Botones
local espButton = Instance.new("TextButton")
espButton.Name = "ESPButton"
espButton.Size = UDim2.new(1, -20, 0, 30)
espButton.Position = UDim2.new(0, 10, 0, 40)
espButton.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
espButton.Text = "ESP: OFF"
espButton.TextColor3 = Color3.fromRGB(255, 255, 255)
espButton.TextScaled = true
espButton.Font = Enum.Font.Gotham
espButton.Parent = mainFrame

local espCorner = Instance.new("UICorner")
espCorner.CornerRadius = UDim.new(0, 5)
espCorner.Parent = espButton

local notifButton = Instance.new("TextButton")
notifButton.Name = "NotifButton"
notifButton.Size = UDim2.new(1, -20, 0, 30)
notifButton.Position = UDim2.new(0, 10, 0, 80)
notifButton.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
notifButton.Text = "Notificaciones: OFF"
notifButton.TextColor3 = Color3.fromRGB(255, 255, 255)
notifButton.TextScaled = true
notifButton.Font = Enum.Font.Gotham
notifButton.Parent = mainFrame

local notifCorner = Instance.new("UICorner")
notifCorner.CornerRadius = UDim.new(0, 5)
notifCorner.Parent = notifButton

local continuousButton = Instance.new("TextButton")
continuousButton.Name = "ContinuousButton"
continuousButton.Size = UDim2.new(1, -20, 0, 30)
continuousButton.Position = UDim2.new(0, 10, 0, 120)
continuousButton.BackgroundColor3 = Color3.fromRGB(50, 255, 50)
continuousButton.Text = "Búsqueda Continua: ON"
continuousButton.TextColor3 = Color3.fromRGB(255, 255, 255)
continuousButton.TextScaled = true
continuousButton.Font = Enum.Font.Gotham
continuousButton.Parent = mainFrame

local continuousCorner = Instance.new("UICorner")
continuousCorner.CornerRadius = UDim.new(0, 5)
continuousCorner.Parent = continuousButton

local playerESPButton = Instance.new("TextButton")
playerESPButton.Name = "PlayerESPButton"
playerESPButton.Size = UDim2.new(1, -20, 0, 30)
playerESPButton.Position = UDim2.new(0, 10, 0, 160)
playerESPButton.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
playerESPButton.Text = "ESP Player: OFF"
playerESPButton.TextColor3 = Color3.fromRGB(255, 255, 255)
playerESPButton.TextScaled = true
playerESPButton.Font = Enum.Font.Gotham
playerESPButton.Parent = mainFrame

local playerESPCorner = Instance.new("UICorner")
playerESPCorner.CornerRadius = UDim.new(0, 5)
playerESPCorner.Parent = playerESPButton

-- Sonido único de notificación
local notifSound = Instance.new("Sound")
notifSound.SoundId = "rbxassetid://77665577458181"
notifSound.Volume = 0.7
notifSound.Parent = screenGui

local function playNotificationSound()
    local ok, err = pcall(function() notifSound:Play() end)
    if not ok then dprint("Sound error:", err) end
end

-- =======================
-- Memoria anti-spam/duplicados
-- =======================
local function getObjectMemoryId(targetObject)
    if targetObject:IsA("Model") then
        local prim = targetObject.PrimaryPart or targetObject:FindFirstChildOfClass("BasePart")
        if prim then
            return tostring(targetObject.Name) .. "_" .. tostring(prim.Position)
        end
    elseif targetObject:IsA("BasePart") then
        return tostring(targetObject.Name) .. "_" .. tostring(targetObject.Position)
    end
    return tostring(targetObject)
end

local function wasRecentlyDetected(targetObject)
    local id = getObjectMemoryId(targetObject)
    local now = time()
    local data = detectedBrainrots[id]
    if data then
        if now - data.timestamp > 25 then
            detectedBrainrots[id] = nil
            return false
        end
        return true
    end
    return false
end

local function markAsDetected(targetObject)
    local id = getObjectMemoryId(targetObject)
    detectedBrainrots[id] = { timestamp = time(), name = targetObject.Name }
    dprint("🧠 Marcado en memoria:", targetObject.Name, "ID:", id)
end

local function cleanupMemory()
    local now = time()
    local cleaned = 0
    for id, data in pairs(detectedBrainrots) do
        if now - data.timestamp > 30 then
            detectedBrainrots[id] = nil
            cleaned += 1
        end
    end
    if cleaned > 0 then dprint("🧹 Memoria limpiada:", cleaned, "objetos removidos") end
end

-- =======================
-- ESP de Objetos (brainrots)
-- =======================
local function createESPHighlight(targetObject, targetName)
    if not isObjectValid(targetObject) then
        dprint("❌ Objeto no válido:", targetName)
        return
    end
    if wasRecentlyDetected(targetObject) then
        dprint("🧠 Ya detectado recientemente:", targetName)
        return
    end
    markAsDetected(targetObject)

    -- Highlight con Adornee (padre en workspace)
    local highlight = newHighlightFor(targetObject)
    highlight.FillColor = getRainbowColor(rainbowHue)

    local espData = {
        highlight     = highlight,
        timestamp     = time(),
        targetName    = targetName,
        uniqueId      = tostring(targetObject) .. "_" .. time(),
        targetObject  = targetObject,
        initialHue    = rainbowHue,
    }
    table.insert(espLines, espData)
    dprint("🌈 ESP Highlight creado para:", targetName, "Parent:", targetObject:GetFullName())
    return espData
end

local function cleanupExpiredESP()
    local now = time()
    for i = #espLines, 1, -1 do
        local e = espLines[i]
        local remove, reason = false, ""
        if now - e.timestamp > 25 then
            remove, reason = true, "expiró"
        end
        if not remove and not isObjectValid(e.targetObject) then
            remove, reason = true, "objeto ya no existe"
        end
        if remove then
            safeDestroy(e.highlight)
            table.remove(espLines, i)
            dprint("🗑️ ESP Highlight removido para:", e.targetName, "-", reason)
        end
    end
end

local function updateRainbowColors()
    for _, e in ipairs(espLines) do
        if e.highlight and isObjectValid(e.highlight) then
            local lineHue = (e.initialHue + (time() - e.timestamp) * 0.5) % 1
            e.highlight.FillColor = getRainbowColor(lineHue)
        end
    end
end

-- Búsqueda en Plots (coincidencia exacta, con cuota opcional)
local MAX_VISITED_PER_TICK = 300
local function findTargetModelsInPlots()
    local foundModels, visited = {}, 0

    local function searchIn(container, depth)
        if depth > 10 then return end
        for _, item in ipairs(container:GetChildren()) do
            if isObjectValid(item) then
                visited += 1
                if visited % MAX_VISITED_PER_TICK == 0 then task.wait() end

                if targetSet[item.Name] then
                    if item:IsA("Model") or item:IsA("BasePart") then
                        if not wasRecentlyDetected(item) then
                            table.insert(foundModels, {object = item, name = item.Name})
                            dprint("🎯 BRAINROT:", item.Name, "en:", container.Name)
                        end
                    end
                end

                if item:IsA("Folder") or item:IsA("Model") then
                    searchIn(item, depth + 1)
                end
            end
        end
    end

    local function findPlotsFolder(container)
        for _, obj in ipairs(container:GetChildren()) do
            if obj.Name == "Plots" and obj:IsA("Folder") then
                dprint("📁 Carpeta Plots en:", container.Name)
                for _, plot in ipairs(obj:GetChildren()) do
                    searchIn(plot, 0)
                end
            elseif obj:IsA("Folder") then
                findPlotsFolder(obj)
            end
        end
    end

    findPlotsFolder(workspace)
    return foundModels
end

local function performContinuousSearch()
    if not espEnabled or not continuousSearchEnabled then return end
    local now = time()
    if now - lastSearchTime < searchInterval then return end
    lastSearchTime = now

    dprint("🔄 Búsqueda continua…")
    cleanupExpiredESP()

    local found = findTargetModelsInPlots()
    local newDetections = 0
    for _, data in ipairs(found) do
        if isObjectValid(data.object) then
            if createESPHighlight(data.object, data.name) then
                newDetections += 1
            end
        end
    end
    if newDetections > 0 then
        dprint("🎯 Nuevos brainrots detectados:", newDetections)
    end
    dprint("📊 Highlights activos:", #espLines)
end

local function updateESP()
    if not espEnabled then return end
    dprint("🔄 Actualizando ESP...")
    cleanupExpiredESP()
    local found = findTargetModelsInPlots()
    for _, data in ipairs(found) do
        if isObjectValid(data.object) then
            createESPHighlight(data.object, data.name)
        end
    end
    dprint("📊 Total highlights activos:", #espLines)
end

-- =======================
-- ESP de Jugadores
-- =======================
local function createPlayerESP(targetPlayer)
    if targetPlayer == player then return end
    local char = targetPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    dprint("👤 Creando ESP para:", targetPlayer.Name)

    local highlight = newHighlightFor(char)
    highlight.FillColor = Color3.fromRGB(255, 0, 0)

    local line = acquireLine()

    playerESPData[targetPlayer.UserId] = {
        targetPlayer = targetPlayer,
        highlight = highlight,
        line = line,
        timestamp = time(),
    }
end

local function updatePlayerESPLines()
    local myChar = player.Character
    local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myHRP then return end
    local myPosition = myHRP.Position

    local toRemove = {}

    for userId, esp in pairs(playerESPData) do
        local p = esp.targetPlayer
        local char = p and p.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not (p and char and hrp and esp.line and isObjectValid(esp.line)) then
            table.insert(toRemove, userId)
        else
            local targetPos = hrp.Position
            local dir = targetPos - myPosition
            local dist = dir.Magnitude
            local mid = myPosition + dir * 0.5

            local line = esp.line
            line.Size  = Vector3.new(0.1, 0.1, dist)
            line.CFrame = CFrame.lookAt(mid, targetPos)
        end
    end

    for _, uid in ipairs(toRemove) do
        local d = playerESPData[uid]
        if d then
            safeDestroy(d.highlight)
            if d.line then releaseLine(d.line) end
            playerESPData[uid] = nil
            dprint("🗑️ Limpieza ESP jugador uid:", uid)
        end
    end
end

local function cleanupPlayerESP()
    dprint("🗑️ Limpieza completa Player ESP…")
    local cleaned = 0
    for uid, esp in pairs(playerESPData) do
        safeDestroy(esp.highlight)
        if esp.line then releaseLine(esp.line) end
        playerESPData[uid] = nil
        cleaned += 1
    end
    -- Por si quedaron líneas sueltas en el mundo (no debería por pool)
    local orphaned = 0
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj.Name == "PlayerESPLine" and obj:IsA("BasePart") and obj.Parent == workspace then
            -- En vez de Destroy, preferimos enviarlas al pool:
            releaseLine(obj)
            orphaned += 1
        end
    end
    dprint(("✅ Player ESP limpio: %d jugadores, %d líneas al pool"):format(cleaned, orphaned))
end

local function updatePlayerESP()
    if not playerESPEnabled then return end
    local others = Players:GetPlayers()
    if #others <= 1 then return end
    for _, p in ipairs(others) do
        if p ~= player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            if not playerESPData[p.UserId] then
                createPlayerESP(p)
            end
        end
    end
    dprint("📊 ESP Player activos:", dictCount(playerESPData))
end

-- =======================
-- Notificaciones (Toast)
-- =======================
local lastToastAt = 0
local toastCooldown = 3

local function showNotificationToast(playerName, models)
    local toastGui = Instance.new("ScreenGui")
    toastGui.Name = "NotificationToast"
    toastGui.Parent = playerGui

    local toastFrame = Instance.new("Frame")
    toastFrame.Size = UDim2.new(0, 350, 0, 100)
    toastFrame.Position = UDim2.new(0.5, -175, 1, -180)
    toastFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    toastFrame.BorderSizePixel = 0
    toastFrame.Parent = toastGui

    local toastCorner = Instance.new("UICorner")
    toastCorner.CornerRadius = UDim.new(0, 10)
    toastCorner.Parent = toastFrame

    local modelsText = (models and #models > 0) and table.concat(models, ", ") or "Ningún brainrot detectado"

    local toastText = Instance.new("TextLabel")
    toastText.Size = UDim2.new(1, -20, 1, -20)
    toastText.Position = UDim2.new(0, 10, 0, 10)
    toastText.BackgroundTransparency = 1
    toastText.Text = "🚨 " .. playerName .. " se unió!\n🎯 Brainrots: " .. modelsText
    toastText.TextColor3 = Color3.fromRGB(255, 255, 255)
    toastText.TextScaled = true
    toastText.Font = Enum.Font.Gotham
    toastText.Parent = toastFrame

    toastFrame.Position = UDim2.new(0.5, -175, 1, 0)
    local tweenIn = TweenService:Create(toastFrame, TweenInfo.new(0.5, Enum.EasingStyle.Back), {Position = UDim2.new(0.5, -175, 1, -180)})
    tweenIn:Play()

    task.spawn(function()
        task.wait(5)
        local tweenOut = TweenService:Create(toastFrame, TweenInfo.new(0.5), {Position = UDim2.new(0.5, -175, 1, 0)})
        tweenOut:Play()
        tweenOut.Completed:Once(function()
            safeDestroy(toastGui)
        end)
    end)
end

local function showNotificationToastSafe(playerName, models)
    local now = time()
    if now - lastToastAt < toastCooldown then return end
    lastToastAt = now
    showNotificationToast(playerName, models)
end

-- =======================
-- Inicializar jugadores existentes
-- =======================
for _, existingPlayer in ipairs(Players:GetPlayers()) do
    trackedPlayers[existingPlayer.UserId] = true
end

-- =======================
-- Eventos GUI
-- =======================
espButton.MouseButton1Click:Connect(function()
    espEnabled = not espEnabled
    if espEnabled then
        espButton.Text = "ESP: ON"
        espButton.BackgroundColor3 = Color3.fromRGB(50, 255, 50)
        dprint("🌈 ESP activado")
        updateESP()
        lastSearchTime = 0 -- para que la búsqueda continua dispare pronto
    else
        espButton.Text = "ESP: OFF"
        espButton.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
        for _, e in ipairs(espLines) do safeDestroy(e.highlight) end
        espLines = {}
        dprint("❌ ESP desactivado, highlights limpiados")
    end
end)

notifButton.MouseButton1Click:Connect(function()
    notificationsEnabled = not notificationsEnabled
    notifButton.Text = notificationsEnabled and "Notificaciones: ON" or "Notificaciones: OFF"
    notifButton.BackgroundColor3 = notificationsEnabled and Color3.fromRGB(50, 255, 50) or Color3.fromRGB(255, 50, 50)
    dprint(notificationsEnabled and "🔔 Notificaciones ON" or "🔕 Notificaciones OFF")
end)

continuousButton.MouseButton1Click:Connect(function()
    continuousSearchEnabled = not continuousSearchEnabled
    continuousButton.Text = continuousSearchEnabled and "Búsqueda Continua: ON" or "Búsqueda Continua: OFF"
    continuousButton.BackgroundColor3 = continuousSearchEnabled and Color3.fromRGB(50, 255, 50) or Color3.fromRGB(255, 50, 50)
    if continuousSearchEnabled then
        dprint("🔄 Búsqueda continua activada cada", searchInterval, "s")
        lastSearchTime = 0
    else
        dprint("⏸️ Búsqueda continua desactivada")
    end
end)

playerESPButton.MouseButton1Click:Connect(function()
    playerESPEnabled = not playerESPEnabled
    if playerESPEnabled then
        playerESPButton.Text = "ESP Player: ON"
        playerESPButton.BackgroundColor3 = Color3.fromRGB(50, 255, 50)
        dprint("👥 ESP Player activado")
        updatePlayerESP()
    else
        playerESPButton.Text = "ESP Player: OFF"
        playerESPButton.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
        dprint("❌ ESP Player desactivado, limpiando…")
        cleanupPlayerESP()
    end
end)

-- =======================
-- Eventos Jugadores (consolidado)
-- =======================
Players.PlayerAdded:Connect(function(newPlayer)
    dprint("👤 Jugador se unió:", newPlayer.Name)
    trackedPlayers[newPlayer.UserId] = true

    if notificationsEnabled and newPlayer ~= player then
        task.wait(0.5)
        playNotificationSound()
        showNotificationToastSafe(newPlayer.Name, {})
    end

    if espEnabled then
        dprint("🔄 Actualizando ESP por unión…")
        task.wait(0.5)
        updateESP()
    end

    if playerESPEnabled then
        local function onChar(_char)
            task.wait(0.5)
            -- Limpia anterior si existía
            local d = playerESPData[newPlayer.UserId]
            if d then
                safeDestroy(d.highlight)
                if d.line then releaseLine(d.line) end
                playerESPData[newPlayer.UserId] = nil
            end
            createPlayerESP(newPlayer)
        end
        if newPlayer.Character then onChar(newPlayer.Character) end
        newPlayer.CharacterAdded:Connect(onChar)
    end
end)

Players.PlayerRemoving:Connect(function(leavingPlayer)
    dprint("👋 Jugador se fue:", leavingPlayer.Name)
    trackedPlayers[leavingPlayer.UserId] = nil
    local d = playerESPData[leavingPlayer.UserId]
    if d then
        safeDestroy(d.highlight)
        if d.line then releaseLine(d.line) end
        playerESPData[leavingPlayer.UserId] = nil
        dprint("🗑️ ESP limpiado para:", leavingPlayer.Name)
    end
    dprint("ℹ️ No se actualiza ESP de objetos al salir (evita fantasmas)")
end)

-- Respawns para jugadores ya presentes (distinto del PlayerAdded)
for _, existing in ipairs(Players:GetPlayers()) do
    if existing ~= player then
        existing.CharacterAdded:Connect(function(_char)
            dprint("🔄 Respawn:", existing.Name)
            if playerESPEnabled then
                task.wait(0.5)
                local d = playerESPData[existing.UserId]
                if d then
                    safeDestroy(d.highlight)
                    if d.line then releaseLine(d.line) end
                    playerESPData[existing.UserId] = nil
                end
                createPlayerESP(existing)
            end
        end)
    end
end

-- =======================
-- Loop principal (Heartbeat)
-- =======================
local lastCleanupTime, lastMemoryCleanup, lastPlayerESPUpdate = 0, 0, 0

RunService.Heartbeat:Connect(function(dt)
    local now = time()

    -- Animación global rainbow (suave)
    rainbowHue = (rainbowHue + 0.02) % 1

    if espEnabled and #espLines > 0 then
        updateRainbowColors()
    end

    if espEnabled and continuousSearchEnabled then
        performContinuousSearch()
    end

    -- Actualización de líneas a ~30fps
    if playerESPEnabled and (now - lastPlayerESPUpdate) >= (1/33) then
        lastPlayerESPUpdate = now
        updatePlayerESPLines()
    end

    if espEnabled and (now - lastCleanupTime) >= 2 then
        lastCleanupTime = now
        cleanupExpiredESP()
    end

    if (now - lastMemoryCleanup) >= 10 then
        lastMemoryCleanup = now
        cleanupMemory()
    end
end)

-- =======================
-- Funciones de prueba (debug)
-- =======================
local function testSound() dprint("🧪 Sonido…"); playNotificationSound() end
local function testPlotSearch()
    dprint("🧪 Búsqueda Plots…")
    local found = findTargetModelsInPlots()
    dprint("Resultados:", #found)
    for _, m in ipairs(found) do dprint("- ".. m.name, "- Válido:", isObjectValid(m.object)) end
end

local function forceUpdateESP() dprint("🧪 Forzando update ESP…"); updateESP() end

local function cleanupAllESP()
    dprint("🧪 Limpiando todos los highlights ESP…")
    for _, e in ipairs(espLines) do safeDestroy(e.highlight) end
    espLines = {}
    dprint("✅ Highlights ESP limpiados")
end

local function clearMemory()
    dprint("🧪 Limpiar memoria…")
    detectedBrainrots = {}
    dprint("✅ Memoria limpia")
end

local function showMemoryStatus()
    dprint("🧠 Estado memoria:")
    local count, now = 0, time()
    for _, data in pairs(detectedBrainrots) do
        local left = 25 - (now - data.timestamp)
        if left > 0 then
            count += 1
            dprint(("   - %s (quedan %ds)"):format(data.name, math.floor(left)))
        end
    end
    dprint("Total en memoria:", count)
end

local function setSearchInterval(seconds)
    searchInterval = tonumber(seconds) or 2
    dprint("🔄 Intervalo de búsqueda a:", searchInterval, "s")
end

local function testPlayerESP() dprint("🧪 Probar ESP jugadores…"); updatePlayerESP() end

local function cleanupAllPlayerESP() dprint("🧪 Limpieza total Player ESP…"); cleanupPlayerESP() end

local function showPlayerESPStatus()
    dprint("👥 Estado Player ESP:")
    dprint("   - Activado:", playerESPEnabled)
    local validCount = 0
    for _, esp in pairs(playerESPData) do
        local p = esp.targetPlayer
        local ok = p and p.Parent and p.Character
        if ok then validCount += 1 end
        dprint(("   - %s (Válido:%s, HL:%s, Línea:%s)"):format(
            p and p.Name or "Desconocido",
            tostring(ok),
            tostring(esp.highlight ~= nil),
            tostring(esp.line ~= nil and esp.line.Parent ~= nil)
        ))
    end
    dprint(("   - Total jugadores válidos: %d de %d"):format(validCount, dictCount(playerESPData)))

    local orphaned = 0
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj.Name == "PlayerESPLine" and obj:IsA("BasePart") and obj.Parent == workspace then
            orphaned += 1
        end
    end
    if orphaned > 0 then dprint("   ⚠️ Líneas huérfanas detectadas:", orphaned) end
end

local function cleanupOrphanedLines()
    dprint("🧹 Enviando líneas huérfanas al pool…")
    local count = 0
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj.Name == "PlayerESPLine" and obj:IsA("BasePart") and obj.Parent == workspace then
            releaseLine(obj)
            count += 1
        end
    end
    dprint("✅ Líneas al pool:", count)
end

-- Exponer helpers debug globales
_G.testESPSound           = testSound
_G.testPlotSearch         = testPlotSearch
_G.forceUpdateESP         = forceUpdateESP
_G.cleanupAllESP          = cleanupAllESP
_G.clearMemory            = clearMemory
_G.showMemoryStatus       = showMemoryStatus
_G.setSearchInterval      = setSearchInterval
_G.testPlayerESP          = testPlayerESP
_G.cleanupAllPlayerESP    = cleanupAllPlayerESP
_G.showPlayerESPStatus    = showPlayerESPStatus
_G.cleanupOrphanedLines   = cleanupOrphanedLines

-- =======================
-- Logs iniciales
-- =======================
print("🚀 ESP Panel Rainbow (Optimizado) cargado!")
print("🌈 Nuevas mejoras: pooling de líneas, Highlight.Adornee, eventos consolidados, GUI arrastrable, time()/task.*")
print("🎯 Buscando brainrots (coincidencia exacta):")
for i, name in ipairs((function()
    local list = {}
    for k in pairs(targetSet) do table.insert(list, k) end
    table.sort(list)
    return list
end)()) do
    print(("   %02d. %s"):format(i, name))
end
