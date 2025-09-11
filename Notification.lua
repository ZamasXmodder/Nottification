-- Panel GUI + ESP System Optimizado para Roblox
-- Coloca este script como LocalScript

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = Workspace.CurrentCamera

-- Lista de modelos para ESP
local targetModels = {
    "La Vacca Saturno Saturnita",
    "Bisonte Giuppitere",
    "Blackhole Goat",
    "Agarrini Ia Palini",
    "Karkerkar Kurkur",
    "Los Matteos",
    "Sammyni Spyderini",
    "Trenostruzzo Turbo 4000",
    "Chimpanzini Spiderini",
    "Fragola La La La",
    "Dul Dul Dul",
    "Torrtuginni Dragonfrutini",
    "Los Tralaleritos",
    "Guerriro Digitale",
    "Las Tralaleritas",
    "Las Vaquitas Saturnitas",
    "Job Job Job Sahur",
    "Graipuss Medussi",
    "Los Spyderinis",
    "Nooo My Hotspot",
    "Pot Hotspot",
    "La Sahur Combinasion",
    "Chicleteira Bicicleteira",
    "Spaghetti Tualetti",
    "Esok Sekolah",
    "Los Nooo My Hotspotsitos",
    "La Grande Combinassion",
    "Los Combinasionas",
    "Nuclearo Dinosauro",
    "La Karkerkar Combinasion",
    "Los Hotspositos",
    "Tralalalaledon",
    "Ketupat Kepat",
    "Los Bros",
    "La Supreme Combinasion",
    "Ketchuru and Masturu",
    "Garama and Madundung",
    "Dragon Cannelloni"
}

-- Crear set para búsqueda rápida
local targetModelsSet = {}
for _, name in ipairs(targetModels) do
    targetModelsSet[name] = true
end

-- Variables para ESP
local espObjects = {}
local espConnections = {}
local espEnabled = true
local rainbowHue = 0

-- Variables para optimización
local lastESPCheck = 0
local espCheckInterval = 1 -- Aumentado a 1 segundo para menos lag
local foundModels = {}

-- =========================
-- FUNCIONES RAINBOW
-- =========================

local function getRainbowColor()
    rainbowHue = rainbowHue + 0.01
    if rainbowHue > 1 then
        rainbowHue = 0
    end
    return Color3.fromHSV(rainbowHue, 1, 1)
end

-- =========================
-- GUI PANEL DE NOTIFICACIONES
-- =========================

-- Crear ScreenGui principal
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "NotificationPanel"
screenGui.Parent = playerGui
screenGui.ResetOnSpawn = false

-- Panel principal (esquina superior derecha)
local mainPanel = Instance.new("Frame")
mainPanel.Name = "MainPanel"
mainPanel.Size = UDim2.new(0, 250, 0, 100)
mainPanel.Position = UDim2.new(1, -260, 0, 10)
mainPanel.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
mainPanel.BorderSizePixel = 0
mainPanel.Parent = screenGui

-- Esquinas redondeadas
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = mainPanel

-- Título del panel
local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.Size = UDim2.new(1, 0, 0, 25)
titleLabel.Position = UDim2.new(0, 0, 0, 0)
titleLabel.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
titleLabel.Text = "🔔 Notificaciones"
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextScaled = true
titleLabel.Font = Enum.Font.GothamBold
titleLabel.Parent = mainPanel

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 8)
titleCorner.Parent = titleLabel

-- Contador de jugadores
local playerCountLabel = Instance.new("TextLabel")
playerCountLabel.Name = "PlayerCount"
playerCountLabel.Size = UDim2.new(1, -10, 0, 25)
playerCountLabel.Position = UDim2.new(0, 5, 0, 30)
playerCountLabel.BackgroundTransparency = 1
playerCountLabel.Text = "Jugadores: " .. #Players:GetPlayers()
playerCountLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
playerCountLabel.TextScaled = true
playerCountLabel.Font = Enum.Font.Gotham
playerCountLabel.Parent = mainPanel

-- Toggle ESP Button
local espToggle = Instance.new("TextButton")
espToggle.Name = "ESPToggle"
espToggle.Size = UDim2.new(0.9, 0, 0, 30)
espToggle.Position = UDim2.new(0.05, 0, 0, 60)
espToggle.BackgroundColor3 = Color3.fromRGB(0, 170, 0)
espToggle.Text = "ESP: ON"
espToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
espToggle.TextScaled = true
espToggle.Font = Enum.Font.GothamBold
espToggle.Parent = mainPanel

local espCorner = Instance.new("UICorner")
espCorner.CornerRadius = UDim.new(0, 4)
espCorner.Parent = espToggle

-- Container para notificaciones
local notificationContainer = Instance.new("Frame")
notificationContainer.Name = "NotificationContainer"
notificationContainer.Size = UDim2.new(0, 280, 1, 0)
notificationContainer.Position = UDim2.new(1, -290, 0, 120)
notificationContainer.BackgroundTransparency = 1
notificationContainer.Parent = screenGui

-- =========================
-- SISTEMA DE SONIDOS
-- =========================

local function playNotificationSound()
    local sound = Instance.new("Sound")
    sound.SoundId = "rbxassetid://76665577458181"
    sound.Volume = 0.3
    sound.Parent = SoundService
    sound:Play()
    
    sound.Ended:Connect(function()
        sound:Destroy()
    end)
end

-- =========================
-- SISTEMA DE NOTIFICACIONES TOAST
-- =========================

local activeNotifications = {}

local function createToastNotification(message, duration)
    duration = duration or 3
    
    -- Crear notificación
    local notification = Instance.new("Frame")
    notification.Name = "ToastNotification"
    notification.Size = UDim2.new(0, 280, 0, 60)
    notification.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    notification.BorderSizePixel = 0
    notification.Position = UDim2.new(0, 300, 0, #activeNotifications * 70)
    notification.Parent = notificationContainer
    
    local notifCorner = Instance.new("UICorner")
    notifCorner.CornerRadius = UDim.new(0, 6)
    notifCorner.Parent = notification
    
    -- Texto de la notificación
    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, -10, 1, -10)
    textLabel.Position = UDim2.new(0, 5, 0, 5)
    textLabel.BackgroundTransparency = 1
    textLabel.Text = message
    textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    textLabel.TextScaled = true
    textLabel.Font = Enum.Font.Gotham
    textLabel.TextWrapped = true
    textLabel.Parent = notification
    
    -- Añadir a lista activa
    table.insert(activeNotifications, notification)
    
    -- Animación de entrada
    local tweenIn = TweenService:Create(
        notification, 
        TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {Position = UDim2.new(0, 0, 0, (#activeNotifications - 1) * 70)}
    )
    tweenIn:Play()
    
    -- Animación de salida después del tiempo especificado
    spawn(function()
        wait(duration)
        
        local tweenOut = TweenService:Create(
            notification,
            TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In),
            {Position = UDim2.new(0, 300, 0, (#activeNotifications - 1) * 70)}
        )
        tweenOut:Play()
        
        tweenOut.Completed:Connect(function()
            -- Remover de lista activa
            for i, notif in ipairs(activeNotifications) do
                if notif == notification then
                    table.remove(activeNotifications, i)
                    break
                end
            end
            
            notification:Destroy()
            
            -- Reposicionar notificaciones restantes
            for i, notif in ipairs(activeNotifications) do
                local repositionTween = TweenService:Create(
                    notif,
                    TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    {Position = UDim2.new(0, 0, 0, (i - 1) * 70)}
                )
                repositionTween:Play()
            end
        end)
    end)
end

-- =========================
-- SISTEMA ESP OPTIMIZADO
-- =========================

local function getModelCenter(model)
    if not model or not model.Parent then return nil end
    
    local parts = {}
    for _, child in pairs(model:GetDescendants()) do
        if child:IsA("BasePart") then
            table.insert(parts, child)
        end
    end
    
    if #parts == 0 then return nil end
    
    local totalCFrame = CFrame.new()
    for _, part in pairs(parts) do
        totalCFrame = totalCFrame + part.Position
    end
    
    return totalCFrame.Position / #parts
end

local function createESP(model)
    if not model or not model.Parent then return end
    if espObjects[model] then return end
    
    -- Crear Highlight (solo borde, sin relleno, a través de paredes)
    local highlight = Instance.new("Highlight")
    highlight.Name = "ModelESP"
    highlight.Adornee = model
    highlight.FillColor = Color3.fromRGB(255, 255, 255)
    highlight.OutlineColor = Color3.fromRGB(255, 0, 0)
    highlight.FillTransparency = 1 -- Sin relleno
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop -- A través de paredes
    highlight.Parent = model
    
    -- Crear línea al jugador
    local beam = Instance.new("Beam")
    local attachment0 = Instance.new("Attachment")
    local attachment1 = Instance.new("Attachment")
    
    -- Attachment en el jugador
    if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
        attachment0.Parent = player.Character.HumanoidRootPart
    end
    
    -- Attachment en el modelo
    local modelCenter = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChildOfClass("BasePart")
    if modelCenter then
        attachment1.Parent = modelCenter
        
        -- Configurar beam
        beam.Attachment0 = attachment0
        beam.Attachment1 = attachment1
        beam.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
        beam.Transparency = NumberSequence.new(0.3)
        beam.Width0 = 0.5
        beam.Width1 = 0.5
        beam.FaceCamera = true
        beam.Parent = workspace
    end
    
    -- Guardar referencias
    espObjects[model] = {
        highlight = highlight,
        beam = beam,
        attachment0 = attachment0,
        attachment1 = attachment1
    }
    
    -- Cleanup cuando el modelo se destruya
    local connection = model.AncestryChanged:Connect(function()
        if not model.Parent then
            if espObjects[model] then
                local esp = espObjects[model]
                if esp.highlight then esp.highlight:Destroy() end
                if esp.beam then esp.beam:Destroy() end
                if esp.attachment0 then esp.attachment0:Destroy() end
                if esp.attachment1 then esp.attachment1:Destroy() end
                espObjects[model] = nil
            end
            if espConnections[model] then
                espConnections[model]:Disconnect()
                espConnections[model] = nil
            end
        end
    end)
    
    espConnections[model] = connection
end

local function removeESP(model)
    if espObjects[model] then
        local esp = espObjects[model]
        if esp.highlight then esp.highlight:Destroy() end
        if esp.beam then esp.beam:Destroy() end
        if esp.attachment0 then esp.attachment0:Destroy() end
        if esp.attachment1 then esp.attachment1:Destroy() end
        espObjects[model] = nil
    end
    
    if espConnections[model] then
        espConnections[model]:Disconnect()
        espConnections[model] = nil
    end
end

local function toggleESP()
    espEnabled = not espEnabled
    
    if espEnabled then
        espToggle.Text = "ESP: ON"
        espToggle.BackgroundColor3 = Color3.fromRGB(0, 170, 0)
        
        -- Buscar y aplicar ESP a modelos existentes
        for _, model in pairs(foundModels) do
            if model and model.Parent then
                createESP(model)
            end
        end
    else
        espToggle.Text = "ESP: OFF"
        espToggle.BackgroundColor3 = Color3.fromRGB(170, 0, 0)
        
        -- Remover todos los ESP
        for model, _ in pairs(espObjects) do
            removeESP(model)
        end
    end
end

-- Función optimizada para buscar modelos
local function findTargetModels()
    foundModels = {}
    
    -- Búsqueda recursiva optimizada
    local function searchInContainer(container)
        for _, child in pairs(container:GetChildren()) do
            if child:IsA("Model") and targetModelsSet[child.Name] then
                table.insert(foundModels, child)
            end
            
            -- Buscar recursivamente en contenedores
            if child:IsA("Folder") or child:IsA("Model") then
                searchInContainer(child)
            end
        end
    end
    
    searchInContainer(workspace)
    return foundModels
end

-- Verificación periódica optimizada
local function checkForNewModels()
    if not espEnabled then return end
    
    local currentTime = tick()
    if currentTime - lastESPCheck < espCheckInterval then return end
    lastESPCheck = currentTime
    
    local newModels = findTargetModels()
    
    -- Solo crear ESP para modelos nuevos
    for _, model in pairs(newModels) do
        if model and model.Parent and not espObjects[model] then
            createESP(model)
        end
    end
end

-- Actualizar colores rainbow
local rainbowConnection
local function updateRainbowColors()
    if not espEnabled then return end
    
    local rainbowColor = getRainbowColor()
    
    for model, esp in pairs(espObjects) do
        if esp and esp.highlight and esp.highlight.Parent then
            esp.highlight.OutlineColor = rainbowColor
        end
        if esp and esp.beam and esp.beam.Parent then
            esp.beam.Color = ColorSequence.new(rainbowColor)
        end
    end
end

-- =========================
-- EVENT HANDLERS
-- =========================

-- Manejar entrada de jugadores
local function onPlayerAdded(newPlayer)
    if newPlayer == player then return end
    
    local message = "🎮 " .. newPlayer.Name .. " se unió al servidor"
    
    -- Reproducir sonido inmediatamente
    playNotificationSound()
    
    spawn(function()
        createToastNotification(message, 4)
    end)
    
    playerCountLabel.Text = "Jugadores: " .. #Players:GetPlayers()
    print("Jugador entró: " .. newPlayer.Name .. " - Sonido reproducido")
end

-- Manejar salida de jugadores
local function onPlayerRemoving(leavingPlayer)
    if leavingPlayer == player then return end
    
    local message = "👋 " .. leavingPlayer.Name .. " salió del servidor"
    
    spawn(function()
        createToastNotification(message, 3)
    end)
    
    wait(0.1)
    playerCountLabel.Text = "Jugadores: " .. #Players:GetPlayers()
end

-- Manejar nuevos modelos que aparecen
workspace.DescendantAdded:Connect(function(descendant)
    if espEnabled and descendant:IsA("Model") and targetModelsSet[descendant.Name] then
        wait(0.1) -- Pequeño delay para asegurar que el modelo esté completamente cargado
        createESP(descendant)
    end
end)

-- Manejar respawn del jugador para reconectar líneas ESP
player.CharacterAdded:Connect(function(character)
    -- Esperar a que el personaje se cargue completamente
    character:WaitForChild("HumanoidRootPart")
    wait(1) -- Dar tiempo extra para cargar
    
    -- Reconectar todas las líneas ESP existentes
    for model, esp in pairs(espObjects) do
        if esp and esp.attachment0 and character:FindFirstChild("HumanoidRootPart") then
            esp.attachment0.Parent = character.HumanoidRootPart
            esp.attachment0.Position = Vector3.new(0, 0, 0)
            
            if esp.beam then
                esp.beam.Attachment0 = esp.attachment0
            end
        end
    end
    
    -- Mensaje de reconexión
    spawn(function()
        createToastNotification("🔄 ESP líneas reconectadas", 2)
    end)
end)

-- Toggle ESP button
espToggle.MouseButton1Click:Connect(toggleESP)

-- Conectar eventos
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- =========================
-- INICIALIZACIÓN
-- =========================

-- Verificar jugadores existentes
for _, existingPlayer in pairs(Players:GetPlayers()) do
    if existingPlayer ~= player then
        onPlayerAdded(existingPlayer)
    end
end

-- Inicializar ESP
if espEnabled then
    findTargetModels()
    for _, model in pairs(foundModels) do
        createESP(model)
    end
end

-- Iniciar loops optimizados
RunService.Heartbeat:Connect(checkForNewModels)

-- Rainbow effect (30 FPS para suavidad sin lag)
rainbowConnection = RunService.Heartbeat:Connect(function()
    if tick() % (1/30) < 0.016 then -- Aproximadamente 30 FPS
        updateRainbowColors()
    end
end)

-- Mensaje de inicio
spawn(function()
    wait(1)
    createToastNotification("✅ ESP Rainbow System activado", 3)
end)

print("ESP Rainbow System cargado!")
print("Modelos objetivo: " .. #targetModels)
print("Modelos encontrados: " .. #foundModels)
