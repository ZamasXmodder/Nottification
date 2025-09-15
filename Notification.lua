-- Mini Panel ESP Optimizado (Sin Lag)
-- Ubicación: Esquina superior derecha

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Lista de modelos a detectar (convertida a hash table para búsqueda O(1))
local targetModels = {}
local modelNames = {
    "La Extinct Grande",
    "Graipuss Medussi",
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
    "Los Hotspositos",
    "Tralalalaledon",
    "Ketupat Kepat",
    "Los Bros",
    "La Supreme Combinasion",
    "Ketchuru and Masturu",
    "Garama and Madundung",
    "Dragon Cannelloni"
}

-- Convertir a hash table para búsqueda rápida
for _, name in pairs(modelNames) do
    targetModels[name:lower()] = name
end

-- Crear ScreenGui principal
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ESPModelPanel"
screenGui.Parent = PlayerGui
screenGui.ResetOnSpawn = false

-- Frame principal del panel (más pequeño)
local mainFrame = Instance.new("Frame")
mainFrame.Name = "ESPPanel"
mainFrame.Parent = screenGui
mainFrame.Size = UDim2.new(0, 180, 0, 80)
mainFrame.Position = UDim2.new(1, -190, 0, 10) -- Esquina superior derecha
mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
mainFrame.BorderSizePixel = 0
mainFrame.BackgroundTransparency = 0.1

-- Esquinas redondeadas
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = mainFrame

-- Variable para estado del ESP
local espEnabled = true

-- Botón toggle para ESP
local espToggle = Instance.new("TextButton")
espToggle.Name = "ESPToggle"
espToggle.Parent = mainFrame
espToggle.Size = UDim2.new(1, -20, 1, -20)
espToggle.Position = UDim2.new(0, 10, 0, 10)
espToggle.BackgroundColor3 = Color3.fromRGB(0, 255, 0) -- Verde cuando activo
espToggle.Text = "ESP: ON"
espToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
espToggle.TextScaled = true
espToggle.Font = Enum.Font.GothamBold
espToggle.BorderSizePixel = 0

local toggleCorner = Instance.new("UICorner")
toggleCorner.CornerRadius = UDim.new(0, 6)
toggleCorner.Parent = espToggle

-- Optimizaciones de rendimiento
local foundModels = {}
local processedObjects = {} -- Cache para evitar procesar el mismo objeto múltiples veces
local lastScanTime = 0
local SCAN_INTERVAL = 2 -- Escanear cada 2 segundos en lugar de cada frame

-- Variables para control de sonido
local lastSoundTime = 0
local SOUND_COOLDOWN = 0.5 -- Cooldown entre sonidos para evitar spam

-- Sistema de Toast Notifications
local function createToast(message)
    local toastGui = Instance.new("ScreenGui")
    toastGui.Name = "ToastNotification"
    toastGui.Parent = PlayerGui
    toastGui.ResetOnSpawn = false
    
    local toastFrame = Instance.new("Frame")
    toastFrame.Name = "ToastFrame"
    toastFrame.Parent = toastGui
    toastFrame.Size = UDim2.new(0, 300, 0, 60)
    toastFrame.Position = UDim2.new(0.5, -150, 1, 100) -- Empieza fuera de pantalla (abajo)
    toastFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    toastFrame.BorderSizePixel = 0
    toastFrame.BackgroundTransparency = 0.1
    
    local toastCorner = Instance.new("UICorner")
    toastCorner.CornerRadius = UDim.new(0, 10)
    toastCorner.Parent = toastFrame
    
    local toastLabel = Instance.new("TextLabel")
    toastLabel.Parent = toastFrame
    toastLabel.Size = UDim2.new(1, -20, 1, -10)
    toastLabel.Position = UDim2.new(0, 10, 0, 5)
    toastLabel.BackgroundTransparency = 1
    toastLabel.Text = message
    toastLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    toastLabel.TextScaled = true
    toastLabel.Font = Enum.Font.Gotham
    toastLabel.TextXAlignment = Enum.TextXAlignment.Center
    
    -- Animación de entrada
    toastFrame:TweenPosition(
        UDim2.new(0.5, -150, 1, -80), -- Posición final (visible)
        "Out",
        "Quart",
        0.5,
        true
    )
    
    -- Esperar y animar salida
    spawn(function()
        wait(3) -- Mostrar por 3 segundos
        toastFrame:TweenPosition(
            UDim2.new(0.5, -150, 1, 100), -- Volver abajo
            "In",
            "Quart",
            0.5,
            true,
            function()
                toastGui:Destroy() -- Limpiar después de la animación
            end
        )
    end)
end

-- Función para crear sonido sintético de notificación
local function playNotificationSound()
    local currentTime = tick()
    if currentTime - lastSoundTime < SOUND_COOLDOWN then
        return -- Evitar spam de sonidos
    end
    lastSoundTime = currentTime
    
    -- Crear múltiples tonos para simular una melodía de notificación
    local tones = {
        {pitch = 2.0, duration = 0.1},
        {pitch = 2.5, duration = 0.1},
        {pitch = 3.0, duration = 0.2}
    }
    
    for i, tone in pairs(tones) do
        spawn(function()
            wait((i-1) * 0.1) -- Delay entre tonos
            local sound = Instance.new("Sound")
            sound.SoundId = "rbxasset://sounds/electronicpingshort.wav" -- Sonido interno de Roblox
            sound.Volume = 0.5
            sound.Pitch = tone.pitch
            sound.Parent = workspace
            sound:Play()
            
            -- Cleanup
            spawn(function()
                wait(tone.duration + 0.5)
                if sound and sound.Parent then
                    sound:Destroy()
                end
            end)
        end)
    end
end

-- Función para sonido de beep alternativo
local function playBeepSound()
    local sound = Instance.new("Sound")
    sound.SoundId = "rbxasset://sounds/button_rollover.wav" -- Sonido interno de Roblox
    sound.Volume = 0.7
    sound.Pitch = 1.8
    sound.Parent = workspace
    sound:Play()
    
    -- Cleanup automático
    spawn(function()
        wait(1)
        if sound and sound.Parent then
            sound:Destroy()
        end
    end)
end

-- Función para sonido de jugador uniéndose (más distintivo)
local function playPlayerJoinSound()
    -- Crear secuencia de sonidos para jugador que se une
    local sequence = {
        {sound = "rbxasset://sounds/electronicpingshort.wav", pitch = 1.5, delay = 0},
        {sound = "rbxasset://sounds/electronicpingshort.wav", pitch = 2.0, delay = 0.1},
        {sound = "rbxasset://sounds/button_rollover.wav", pitch = 1.2, delay = 0.3}
    }
    
    for _, note in pairs(sequence) do
        spawn(function()
            wait(note.delay)
            local sound = Instance.new("Sound")
            sound.SoundId = note.sound
            sound.Volume = 0.6
            sound.Pitch = note.pitch
            sound.Parent = workspace
            sound:Play()
            
            -- Cleanup
            spawn(function()
                wait(1)
                if sound and sound.Parent then
                    sound:Destroy()
                end
            end)
        end)
    end
end

-- Función para crear label ESP con nombre
local function createESPLabel(model, modelName)
    -- Verificar si ya tiene label ESP
    if model:FindFirstChild("ESPLabel") then
        return model:FindFirstChild("ESPLabel")
    end
    
    -- Crear BillboardGui para el label
    local billboardGui = Instance.new("BillboardGui")
    billboardGui.Name = "ESPLabel"
    billboardGui.Parent = model
    billboardGui.Size = UDim2.new(0, 200, 0, 50)
    billboardGui.StudsOffset = Vector3.new(0, 3, 0)
    billboardGui.AlwaysOnTop = true -- Ver a través de paredes
    billboardGui.LightInfluence = 0
    
    -- Crear el label con el nombre
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Parent = billboardGui
    nameLabel.Size = UDim2.new(1, 0, 1, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = modelName
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 0) -- Amarillo brillante
    nameLabel.TextStrokeTransparency = 0
    nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0) -- Contorno negro
    nameLabel.TextScaled = true
    nameLabel.Font = Enum.Font.GothamBold
    
    return billboardGui
end

-- Función para crear línea ESP desde el jugador
local function createESPLine(model)
    -- Verificar si ya tiene línea ESP
    if model:FindFirstChild("ESPLine") then
        return model:FindFirstChild("ESPLine")
    end
    
    -- Crear la línea usando Beam
    local attachment0 = Instance.new("Attachment")
    attachment0.Name = "PlayerAttachment"
    
    local attachment1 = Instance.new("Attachment")
    attachment1.Name = "ModelAttachment"
    attachment1.Parent = model
    
    local beam = Instance.new("Beam")
    beam.Name = "ESPLine"
    beam.Parent = model
    beam.Attachment0 = attachment0
    beam.Attachment1 = attachment1
    beam.Color = ColorSequence.new(Color3.fromRGB(255, 0, 0)) -- Línea roja
    beam.Width0 = 0.2
    beam.Width1 = 0.2
    beam.Transparency = NumberSequence.new(0.3)
    beam.FaceCamera = true
    
    return beam, attachment0
end

-- Tabla para almacenar attachments del jugador
local playerAttachments = {}

-- Función para toggle del ESP
local function toggleESP()
    espEnabled = not espEnabled
    
    if espEnabled then
        espToggle.BackgroundColor3 = Color3.fromRGB(0, 255, 0) -- Verde
        espToggle.Text = "ESP: ON"
        
        -- Reactivar todos los ESP elements
        for model, modelName in pairs(foundModels) do
            if model.Parent then
                if model:FindFirstChild("ESPLabel") then
                    model.ESPLabel.Enabled = true
                end
                if model:FindFirstChild("ESPLine") then
                    model.ESPLine.Enabled = true
                end
            end
        end
    else
        espToggle.BackgroundColor3 = Color3.fromRGB(255, 0, 0) -- Rojo
        espToggle.Text = "ESP: OFF"
        
        -- Desactivar todos los ESP elements
        for model, modelName in pairs(foundModels) do
            if model.Parent then
                if model:FindFirstChild("ESPLabel") then
                    model.ESPLabel.Enabled = false
                end
                if model:FindFirstChild("ESPLine") then
                    model.ESPLine.Enabled = false
                end
            end
        end
    end
end

-- Conectar el botón toggle
espToggle.MouseButton1Click:Connect(toggleESP)

-- Función optimizada para verificar nombre de modelo
local function isTargetModel(objName)
    local lowerName = objName:lower()
    for targetName, originalName in pairs(targetModels) do
        if string.find(lowerName, targetName) then
            return originalName
        end
    end
    return nil
end

-- Función optimizada para buscar modelos (solo cuando es necesario)
local function scanForModels()
    local currentTime = tick()
    if currentTime - lastScanTime < SCAN_INTERVAL then
        return -- No escanear tan frecuentemente
    end
    lastScanTime = currentTime
    
    local function searchInContainer(container, depth)
        -- Limitar profundidad para evitar lag
        if depth > 5 then return end
        
        for _, obj in pairs(container:GetChildren()) do
            -- Saltar si ya fue procesado
            if processedObjects[obj] then
                continue
            end
            
            if obj:IsA("Model") or obj:IsA("Part") or obj:IsA("MeshPart") then
                local targetModelName = isTargetModel(obj.Name)
                
                -- También verificar PrimaryPart para modelos
                if not targetModelName and obj:IsA("Model") and obj.PrimaryPart then
                    targetModelName = isTargetModel(obj.PrimaryPart.Name)
                end
                
                if targetModelName and not foundModels[obj] then
                    foundModels[obj] = targetModelName
                    
                    -- Solo crear ESP si está habilitado
                    if espEnabled then
                        createESPLabel(obj, targetModelName)
                        local beam, playerAttachment = createESPLine(obj)
                        if playerAttachment then
                            table.insert(playerAttachments, playerAttachment)
                        end
                    else
                        -- Crear pero deshabilitado
                        local label = createESPLabel(obj, targetModelName)
                        local beam, playerAttachment = createESPLine(obj)
                        if playerAttachment then
                            table.insert(playerAttachments, playerAttachment)
                        end
                        if label then label.Enabled = false end
                        if beam then beam.Enabled = false end
                    end
                    
                    -- Reproducir sonido de modelo encontrado
                    playNotificationSound()
                    
                    processedObjects[obj] = true
                end
            end
            
            -- Buscar recursivamente pero con límite de profundidad
            if (obj:IsA("Model") or obj:IsA("Folder")) and depth < 3 then
                searchInContainer(obj, depth + 1)
            end
        end
    end
    
    searchInContainer(workspace, 0)
end

-- Función optimizada para limpiar modelos eliminados
local function cleanupRemovedModels()
    local toRemove = {}
    
    for model, modelName in pairs(foundModels) do
        if not model.Parent then
            toRemove[model] = modelName
        end
    end
    
    for model, modelName in pairs(toRemove) do
        foundModels[model] = nil
        processedObjects[model] = nil
        
        -- Limpiar ESP elements
        if model:FindFirstChild("ESPLabel") then
            model.ESPLabel:Destroy()
        end
        if model:FindFirstChild("ESPLine") then
            model.ESPLine:Destroy()
        end
        if model:FindFirstChild("ModelAttachment") then
            model.ModelAttachment:Destroy()
        end
    end
end

-- Detectar cuando nuevos jugadores entran al servidor
Players.PlayerAdded:Connect(function(player)
    -- Crear toast notification
    createToast("@" .. player.Name .. " se unió al servidor")
    
    -- Reproducir sonido especial para jugadores que se unen
    playPlayerJoinSound()
end)

-- Manejar respawn del jugador local
LocalPlayer.CharacterAdded:Connect(function(character)
    wait(1) -- Esperar a que el personaje se cargue completamente
    updateESPLines()
end)

-- Usar eventos en lugar de bucle constante para mejor rendimiento
workspace.ChildAdded:Connect(function(child)
    wait(0.1) -- Pequeña espera para que el objeto se inicialice
    scanForModels()
end)

workspace.DescendantAdded:Connect(function(descendant)
    if descendant:IsA("Model") or descendant:IsA("Part") or descendant:IsA("MeshPart") then
        wait(0.1)
        scanForModels()
    end
end)

-- Bucle de limpieza menos frecuente
spawn(function()
    while true do
        wait(5) -- Limpiar cada 5 segundos
        cleanupRemovedModels()
    end
end)

-- Función para actualizar posiciones de las líneas ESP
local function updateESPLines()
    local character = LocalPlayer.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then
        return
    end
    
    local rootPart = character.HumanoidRootPart
    
    -- Actualizar todos los attachments del jugador
    for _, attachment in pairs(playerAttachments) do
        if attachment and attachment.Parent then
            attachment.Parent = rootPart
        end
    end
    
    -- Limpiar attachments inválidos
    local validAttachments = {}
    for _, attachment in pairs(playerAttachments) do
        if attachment and attachment.Parent then
            table.insert(validAttachments, attachment)
        end
    end
    playerAttachments = validAttachments
end

-- Actualizar líneas ESP cada segundo
spawn(function()
    while true do
        wait(1)
        updateESPLines()
    end
end)

-- Escaneo inicial
scanForModels()

-- Hacer el panel draggable
local dragging = false
local dragStart = nil
local startPos = nil

mainFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = mainFrame.Position
    end
end)

mainFrame.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart
        mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

mainFrame.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

print("ESP Panel cargado - Buscando modelos específicos...")
