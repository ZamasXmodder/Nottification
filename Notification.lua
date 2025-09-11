-- Panel GUI + ESP System para Roblox
-- Coloca este script en ServerScriptService o como LocalScript

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

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
local espEnabled = true

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
    sound.SoundId = "rbxasset://sounds/electronicpingshort.wav"
    sound.Volume = 0.5
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
    notification.Position = UDim2.new(0, 300, 0, #activeNotifications * 70) -- Empezar fuera de pantalla
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
end

-- =========================
-- SISTEMA ESP
-- =========================

local function createESP(model)
    if not model or not model.Parent then return end
    
    -- Verificar si ya tiene ESP
    if espObjects[model] then return end
    
    -- Crear Highlight
    local highlight = Instance.new("Highlight")
    highlight.Name = "ModelESP"
    highlight.Adornee = model
    highlight.FillColor = Color3.fromRGB(255, 100, 100)
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.FillTransparency = 0.7
    highlight.OutlineTransparency = 0
    highlight.Parent = model
    
    -- Guardar referencia
    espObjects[model] = highlight
    
    -- Cleanup cuando el modelo se destruya
    model.AncestryChanged:Connect(function()
        if not model.Parent then
            if espObjects[model] then
                espObjects[model]:Destroy()
                espObjects[model] = nil
            end
        end
    end)
end

local function removeESP(model)
    if espObjects[model] then
        espObjects[model]:Destroy()
        espObjects[model] = nil
    end
end

local function toggleESP()
    espEnabled = not espEnabled
    
    if espEnabled then
        espToggle.Text = "ESP: ON"
        espToggle.BackgroundColor3 = Color3.fromRGB(0, 170, 0)
        
        -- Activar ESP para todos los modelos encontrados
        for _, model in pairs(workspace:GetDescendants()) do
            if model:IsA("Model") and targetModelsSet[model.Name] then
                createESP(model)
            end
        end
    else
        espToggle.Text = "ESP: OFF"
        espToggle.BackgroundColor3 = Color3.fromRGB(170, 0, 0)
        
        -- Remover todos los ESP
        for model, highlight in pairs(espObjects) do
            highlight:Destroy()
        end
        espObjects = {}
    end
end

-- Optimización: Verificar modelos cada 0.5 segundos en lugar de constantemente
local lastESPCheck = 0
local function checkForNewModels()
    if not espEnabled then return end
    
    local currentTime = tick()
    if currentTime - lastESPCheck < 0.5 then return end
    lastESPCheck = currentTime
    
    for _, descendant in pairs(workspace:GetDescendants()) do
        if descendant:IsA("Model") and targetModelsSet[descendant.Name] then
            if not espObjects[descendant] then
                createESP(descendant)
            end
        end
    end
end

-- =========================
-- EVENT HANDLERS
-- =========================

-- Manejar entrada de jugadores
local function onPlayerAdded(newPlayer)
    if newPlayer == player then return end -- No notificar sobre nosotros mismos
    
    local message = "🎮 " .. newPlayer.Name .. " se unió al servidor"
    
    -- Sonido de notificación
    playNotificationSound()
    
    -- Mostrar toast
    spawn(function()
        createToastNotification(message, 4)
    end)
    
    -- Actualizar contador
    playerCountLabel.Text = "Jugadores: " .. #Players:GetPlayers()
end

-- Manejar salida de jugadores
local function onPlayerRemoving(leavingPlayer)
    if leavingPlayer == player then return end
    
    local message = "👋 " .. leavingPlayer.Name .. " salió del servidor"
    
    spawn(function()
        createToastNotification(message, 3)
    end)
    
    -- Actualizar contador
    wait(0.1) -- Pequeño delay para que el conteo sea correcto
    playerCountLabel.Text = "Jugadores: " .. #Players:GetPlayers()
end

-- Toggle ESP button
espToggle.MouseButton1Click:Connect(toggleESP)

-- Conectar eventos
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- =========================
-- INICIALIZACIÓN
-- =========================

-- Verificar jugadores que ya están en el servidor
for _, existingPlayer in pairs(Players:GetPlayers()) do
    if existingPlayer ~= player then
        onPlayerAdded(existingPlayer)
    end
end

-- Inicializar ESP para modelos existentes
if espEnabled then
    for _, model in pairs(workspace:GetDescendants()) do
        if model:IsA("Model") and targetModelsSet[model.Name] then
            createESP(model)
        end
    end
end

-- Ejecutar verificación de modelos en el bucle de renderizado (optimizado)
RunService.Heartbeat:Connect(checkForNewModels)

-- Mensaje de inicio
spawn(function()
    wait(1)
    createToastNotification("✅ Sistema de notificaciones y ESP activado", 3)
end)

print("Panel GUI + ESP System cargado correctamente!")
print("Modelos objetivo: " .. #targetModels)
print("ESP Status: " .. (espEnabled and "Activado" or "Desactivado"))
