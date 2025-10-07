--// =========================
--//  ESP Panel Rainbow + Player ESP (COMPLETO | SIN LÍMITE)
--//  Cambios clave:
--//   - Marca TODOS los brainrots coincidentes en todo el mapa.
--//   - Sin expiración: los highlights se mantienen mientras ESP esté ON.
--//   - Búsqueda continua vuelve a marcar cualquier brainrot que se haya quedado sin highlight.
--//   - Se respetan solo los nombres definidos (coincidencia exacta).
--//   - Pooling de líneas, Highlight.Adornee, eventos consolidados, GUI arrastrable, time()/task.*.
--// =========================

--// Servicios
local Players            = game:GetService("Players")
local RunService         = game:GetService("RunService")
local TweenService       = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

--// ================
--// Config/Utilidades
--// ================
local DEBUG = false
local function dprint(...) if DEBUG then print(...) end end

local function dictCount(t)
    local c = 0
    for _ in pairs(t) do c += 1 end
    return c
end

local function isObjectValid(obj)
    return typeof(obj) == "Instance" and obj.Parent ~= nil and obj:IsDescendantOf(game)
end

local function safeDestroy(x)
    if x and typeof(x) == "Instance" and x.Destroy then
        x:Destroy()
    end
end

-- Pool de líneas para Player ESP
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

-- Highlight con Adornee (más estable)
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

local function getRainbowColor(hue)
    return Color3.fromHSV(hue, 1, 1)
end

-- =======================
-- Objetivos (nombres exactos)
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

-- Ahora usamos un MAPA de marcas activas por instancia (sin expiración por tiempo)
-- activeMarks[Instance] = { highlight=Highlight, createdAt=time(), initialHue=number, targetName=string }
local activeMarks     = {}

-- Player ESP
local playerESPData   = {}     -- userId => { targetPlayer, highlight, line, timestamp }

-- Efecto rainbow
local rainbowHue = 0

-- Búsqueda continua (suma marcas que faltan y re-marca si algo se perdió)
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

-- Persistencia simple de posición
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
local function newButton(name, y, text, color)
    local b = Instance.new("TextButton")
    b.Name = name
    b.Size = UDim2.new(1, -20, 0, 30)
    b.Position = UDim2.new(0, 10, 0, y)
    b.BackgroundColor3 = color
    b.Text = text
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.TextScaled = true
    b.Font = Enum.Font.Gotham
    b.Parent = mainFrame
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 5)
    c.Parent = b
    return b
end

local espButton         = newButton("ESPButton",          40,  "ESP: OFF",                Color3.fromRGB(255, 50, 50))
local notifButton       = newButton("NotifButton",        80,  "Notificaciones: OFF",     Color3.fromRGB(255, 50, 50))
local continuousButton  = newButton("ContinuousButton",   120, "Búsqueda Continua: ON",   Color3.fromRGB(50, 255, 50))
local playerESPButton   = newButton("PlayerESPButton",    160, "ESP Player: OFF",         Color3.fromRGB(255, 50, 50))

-- =======================
-- Notificación (toast sencillo)
-- =======================
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

-- =======================
-- ESP de Objetos (brainrots) — SIN EXPIRACIÓN
-- =======================
local rainbowSpeed = 0.5 -- velocidad del arcoíris por highlight

local function ensureMark(targetObject)
    -- crea o asegura un highlight activo para targetObject
    local data = activeMarks[targetObject]
    if data and data.highlight and isObjectValid(data.highlight) then
        return data -- ya marcado
    end
    local h = newHighlightFor(targetObject)
    h.FillColor = getRainbowColor(rainbowHue)
    local d = {
        highlight    = h,
        createdAt    = time(),
        initialHue   = rainbowHue,
        targetName   = targetObject.Name
    }
    activeMarks[targetObject] = d
    return d
end

local MAX_VISITED_PER_TICK = 600 -- cuota para evitar freeze en mapas enormes
local function scanAllBrainrots()
    -- escanea TODO el workspace, marca TODOS los que coinciden con targetSet
    local visited = 0
    local foundCount = 0

    local function searchIn(container, depth)
        if depth > 12 then return end
        for _, item in ipairs(container:GetChildren()) do
            if isObjectValid(item) then
                visited += 1
                if visited % MAX_VISITED_PER_TICK == 0 then task.wait() end

                if targetSet[item.Name] and (item:IsA("Model") or item:IsA("BasePart")) then
                    ensureMark(item)
                    foundCount += 1
                end

                if item:IsA("Folder") or item:IsA("Model") then
                    searchIn(item, depth + 1)
                end
            end
        end
    end

    searchIn(workspace, 0)
    return foundCount
end

local function cleanupInvalidMarks()
    -- elimina cualquier highlight cuyo objeto ya no exista/valga
    local removed = 0
    for inst, data in pairs(activeMarks) do
        if not isObjectValid(inst) or not (data.highlight and isObjectValid(data.highlight)) then
            if data and data.highlight then safeDestroy(data.highlight) end
            activeMarks[inst] = nil
            removed += 1
        end
    end
    if removed > 0 then dprint("🗑️ Limpieza de marcas inválidas:", removed) end
end

local function updateRainbowColors()
    for inst, data in pairs(activeMarks) do
        if data.highlight and isObjectValid(data.highlight) then
            local hue = (data.initialHue + (time() - data.createdAt) * rainbowSpeed) % 1
            data.highlight.FillColor = getRainbowColor(hue)
        end
    end
end

local function updateESP_All()
    if not espEnabled then return end
    -- siempre: limpia inválidos y marca TODOS los presentes
    cleanupInvalidMarks()
    local count = scanAllBrainrots()
    dprint("📊 Brainrots marcados/asegurados en esta pasada:", count, " | Activos:", dictCount(activeMarks))
end

local function performContinuousSearch()
    if not espEnabled or not continuousSearchEnabled then return end
    local now = time()
    if now - lastSearchTime < searchInterval then return end
    lastSearchTime = now
    updateESP_All()
end

-- =======================
-- ESP de Jugadores (igual que antes)
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
    for uid, esp in pairs(playerESPData) do
        safeDestroy(esp.highlight)
        if esp.line then releaseLine(esp.line) end
        playerESPData[uid] = nil
    end
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
-- Inicializar jugadores existentes (solo tracking)
-- =======================
local trackedPlayers  = {}
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
        lastSearchTime = 0
        updateESP_All() -- enciende y marca TODO ya
    else
        espButton.Text = "ESP: OFF"
        espButton.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
        -- Apaga todo: destruye highlights activos y limpia mapa
        for inst, data in pairs(activeMarks) do
            if data and data.highlight then safeDestroy(data.highlight) end
            activeMarks[inst] = nil
        end
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
        task.wait(0.4)
        showNotificationToast(newPlayer.Name, {})
    end

    if espEnabled then
        task.wait(0.4)
        updateESP_All() -- al entrar alguien, asegúrate de que todo está marcado igual
    end

    if playerESPEnabled then
        local function onChar(_char)
            task.wait(0.3)
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
end)

-- Respawns para jugadores ya presentes
for _, existing in ipairs(Players:GetPlayers()) do
    if existing ~= player then
        existing.CharacterAdded:Connect(function(_char)
            dprint("🔄 Respawn:", existing.Name)
            if playerESPEnabled then
                task.wait(0.3)
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
local lastPlayerESPUpdate = 0

RunService.Heartbeat:Connect(function(dt)
    -- animación rainbow global base
    rainbowHue = (rainbowHue + 0.02) % 1

    -- colores de highlights activos
    if espEnabled and dictCount(activeMarks) > 0 then
        updateRainbowColors()
    end

    -- búsqueda continua (asegura TODO, re-marca lo que falte)
    if espEnabled and continuousSearchEnabled then
        performContinuousSearch()
    end

    -- Player ESP ~30fps
    local now = time()
    if playerESPEnabled and (now - lastPlayerESPUpdate) >= (1/33) then
        lastPlayerESPUpdate = now
        updatePlayerESPLines()
    end

    -- limpieza de marcas inválidas por seguridad
    if espEnabled then
        cleanupInvalidMarks()
    end
end)

-- =======================
-- Helpers debug opcionales
-- =======================
_G.setSearchInterval = function(seconds)
    searchInterval = tonumber(seconds) or 2
    dprint("🔄 Intervalo búsqueda:", searchInterval, "s")
end

print("🚀 ESP Panel Rainbow (FULL, sin límite) cargado!")
print("🌈 Highlights SIN expiración; búsqueda continua re-marca TODO lo que falte.")
print("🎯 Coincidencia exacta para nombres listados (", tostring(dictCount(targetSet)), " nombres ).")
