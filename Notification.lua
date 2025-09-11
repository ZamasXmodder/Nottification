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

-- Convertir a hash table para búsqueda rápida
for _, name in pairs(modelNames) do
    targetModels[name:lower()] = name
end

-- Crear ScreenGui principal
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ESPModelPanel"
screenGui.Parent = PlayerGui
screenGui.ResetOnSpawn = false

-- Frame principal del panel
local mainFrame = Instance.new("Frame")
mainFrame.Name = "ESPPanel"
mainFrame.Parent = screenGui
mainFrame.Size = UDim2.new(0, 200, 0, 300)
mainFrame.Position = UDim2.new(1, -210, 0, 10) -- Esquina superior derecha
mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
mainFrame.BorderSizePixel = 0
mainFrame.BackgroundTransparency = 0.1

-- Esquinas redondeadas
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = mainFrame

-- Título del panel
local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.Parent = mainFrame
titleLabel.Size = UDim2.new(1, 0, 0, 30)
titleLabel.Position = UDim2.new(0, 0, 0, 0)
titleLabel.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
titleLabel.Text = "ESP - Modelos"
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextScaled = true
titleLabel.Font = Enum.Font.GothamBold
titleLabel.BorderSizePixel = 0

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 8)
titleCorner.Parent = titleLabel

-- ScrollingFrame para la lista de modelos
local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Name = "ModelList"
scrollFrame.Parent = mainFrame
scrollFrame.Size = UDim2.new(1, -10, 1, -40)
scrollFrame.Position = UDim2.new(0, 5, 0, 35)
scrollFrame.BackgroundTransparency = 1
scrollFrame.ScrollBarThickness = 6
scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
scrollFrame.BorderSizePixel = 0

-- Layout para organizar los elementos
local listLayout = Instance.new("UIListLayout")
listLayout.Parent = scrollFrame
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Padding = UDim.new(0, 2)

-- Optimizaciones de rendimiento
local foundModels = {}
local modelLabels = {}
local processedObjects = {} -- Cache para evitar procesar el mismo objeto múltiples veces
local lastScanTime = 0
local SCAN_INTERVAL = 2 -- Escanear cada 2 segundos en lugar de cada frame

-- Pool de sonidos para evitar crear/destruir constantemente
local soundPool = {}
local maxSounds = 3

-- Función optimizada para crear sonido de notificación
local function playNotificationSound()
    local sound = nil
    
    -- Buscar sonido disponible en el pool
    for i, poolSound in pairs(soundPool) do
        if not poolSound.IsPlaying then
            sound = poolSound
            break
        end
    end
    
    -- Si no hay sonido disponible, crear uno nuevo
    if not sound and #soundPool < maxSounds then
        sound = Instance.new("Sound")
        sound.SoundId = "rbxassetid://77665577458181"
        sound.Volume = 0.5
        sound.Parent = workspace
        table.insert(soundPool, sound)
    end
    
    if sound then
        sound:Play()
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

-- Función para agregar modelo a la lista
local function addModelToList(modelName, model)
    if modelLabels[modelName] then
        return -- Ya existe en la lista
    end
    
    local modelLabel = Instance.new("TextLabel")
    modelLabel.Name = modelName
    modelLabel.Parent = scrollFrame
    modelLabel.Size = UDim2.new(1, -5, 0, 25)
    modelLabel.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    modelLabel.Text = "✓ " .. modelName
    modelLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
    modelLabel.TextScaled = true
    modelLabel.Font = Enum.Font.Gotham
    modelLabel.BorderSizePixel = 0
    
    local labelCorner = Instance.new("UICorner")
    labelCorner.CornerRadius = UDim.new(0, 4)
    labelCorner.Parent = modelLabel
    
    modelLabels[modelName] = modelLabel
    
    -- Actualizar el tamaño del scroll
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y)
end

-- Función para remover modelo de la lista
local function removeModelFromList(modelName)
    if modelLabels[modelName] then
        modelLabels[modelName]:Destroy()
        modelLabels[modelName] = nil
        scrollFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y)
    end
end

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
                    createESPLabel(obj, targetModelName)
                    local beam, playerAttachment = createESPLine(obj)
                    if playerAttachment then
                        table.insert(playerAttachments, playerAttachment)
                    end
                    addModelToList(targetModelName, obj)
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
        removeModelFromList(modelName)
        
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
    playNotificationSound()
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
