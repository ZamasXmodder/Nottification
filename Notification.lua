local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Modelos objetivo
local targetModels = {
    "Chicleteira Bicicleteira",
    "Spaghetti Tualetti", 
    "Esok Sekolah",
    "Los Nooo My Hotspotsitos",
    "La Grande Combinassion",
    "Los Chicleteiras",
    "67",
    "Los Combinasionas",
    "Nuclearo Dinosauro",
    "Las Sis",
    "Los Hotspositos",
    "Tralalalaledon",
    "Ketupat Kepat",
    "Los Bros",
    "La Supreme Combinasion",
    "Ketchuru and Masturu",
    "Garama and Madundung",
    "Dragon Cannelloni",
    "Celularcini Viciosini"
}

-- Variables
local espEnabled = false
local notificationsEnabled = false
local espLines = {}
local trackedModels = {}
local trackedPlayers = {}

-- Crear GUI principal
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ESPPanel"
screenGui.Parent = playerGui
screenGui.ResetOnSpawn = false

-- Panel principal
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainPanel"
mainFrame.Size = UDim2.new(0, 200, 0, 120)
mainFrame.Position = UDim2.new(1, -210, 0, 10)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui

-- Esquinas redondeadas
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = mainFrame

-- Título
local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.Size = UDim2.new(1, 0, 0, 30)
titleLabel.Position = UDim2.new(0, 0, 0, 0)
titleLabel.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
titleLabel.Text = "ESP Panel"
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextScaled = true
titleLabel.Font = Enum.Font.GothamBold
titleLabel.Parent = mainFrame

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 8)
titleCorner.Parent = titleLabel

-- Botón ESP
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

-- Botón Notificaciones
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

-- Crear sonidos de notificación
local notificationSounds = {}
local soundIds = {
    "rbxassetid://131961136",
    "rbxassetid://2865227271",
    "rbxassetid://156785206",
    "rbxassetid://2767090"
}

for i, soundId in pairs(soundIds) do
    local sound = Instance.new("Sound")
    sound.SoundId = soundId
    sound.Volume = 0.7
    sound.Parent = screenGui
    table.insert(notificationSounds, sound)
end

-- Función para reproducir sonido de notificación
local function playNotificationSound()
    for _, sound in pairs(notificationSounds) do
        spawn(function()
            pcall(function()
                sound:Play()
            end)
        end)
    end
    print("🔊 Sonido de notificación reproducido!")
end

-- Función para crear líneas ESP más delgadas
local function createESPLine(targetObject, targetName)
    local character = player.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then return end
    
    local objectId = tostring(targetObject)
    if trackedModels[objectId] then return end
    
    local targetPosition
    if targetObject:IsA("Model") then
        if targetObject.PrimaryPart then
            targetPosition = targetObject.PrimaryPart.Position
        elseif targetObject:FindFirstChildOfClass("BasePart") then
            targetPosition = targetObject:FindFirstChildOfClass("BasePart").Position
        else
            return
        end
    elseif targetObject:IsA("BasePart") then
        targetPosition = targetObject.Position
    else
        return
    end
    
    -- Crear línea usando Beam MÁS DELGADA
    local attachment0 = Instance.new("Attachment")
    local attachment1 = Instance.new("Attachment")
    
    attachment0.Parent = character.HumanoidRootPart
    
    local targetPart = Instance.new("Part")
    targetPart.Anchored = true
    targetPart.CanCollide = false
    targetPart.Transparency = 1
    targetPart.Size = Vector3.new(0.1, 0.1, 0.1)
    targetPart.Position = targetPosition
    targetPart.Parent = workspace
    
    attachment1.Parent = targetPart
    
    local beam = Instance.new("Beam")
    beam.Attachment0 = attachment0
    beam.Attachment1 = attachment1
    beam.Color = ColorSequence.new(Color3.fromRGB(255, 0, 255)) -- Magenta brillante
    beam.Width0 = 0.1 -- MUY delgada
    beam.Width1 = 0.1 -- MUY delgada
    beam.Transparency = NumberSequence.new(0.3) -- Un poco transparente
    beam.FaceCamera = true
    beam.Parent = workspace
    
    local espData = {
        beam = beam,
        attachment0 = attachment0,
        attachment1 = attachment1,
        targetPart = targetPart,
        timestamp = tick(),
        targetName = targetName,
        objectId = objectId
    }
    
    table.insert(espLines, espData)
    trackedModels[objectId] = espData
    
    print("✅ ESP creado para:", targetName, "en Plot")
    return espData
end

-- Función para limpiar líneas ESP expiradas
local function cleanupExpiredESP()
    local currentTime = tick()
    for i = #espLines, 1, -1 do
        local espData = espLines[i]
        if currentTime - espData.timestamp > 20 then
            if espData.beam then espData.beam:Destroy() end
            if espData.attachment0 then espData.attachment0:Destroy() end
            if espData.attachment1 then espData.attachment1:Destroy() end
            if espData.targetPart then espData.targetPart:Destroy() end
            
            trackedModels[espData.objectId] = nil
            table.remove(espLines, i)
            
            print("⏰ ESP expirado para:", espData.targetName)
        end
    end
end

-- Función DIRECTA para buscar en carpetas Plots
local function findTargetModelsInPlots()
    local foundModels = {}
    
    -- Buscar todas las carpetas llamadas "Plots" en workspace
    local function findPlotsFolder(container)
        for _, obj in pairs(container:GetChildren()) do
            if obj.Name == "Plots" and obj:IsA("Folder") then
                print("📁 Encontrada carpeta Plots en:", container.Name)
                
                -- Buscar en cada plot
                for _, plot in pairs(obj:GetChildren()) do
                    print("🔍 Buscando en plot:", plot.Name)
                    
                    -- Buscar recursivamente en el plot
                    local function searchInPlot(plotContainer, depth)
                        if depth > 10 then return end
                        
                        for _, item in pairs(plotContainer:GetChildren()) do
                            -- Verificar si es uno de nuestros brainrots objetivo
                            for _, targetName in pairs(targetModels) do
                                local itemName = string.lower(item.Name)
                                local searchName = string.lower(targetName)
                                
                                if itemName == searchName or 
                                   string.find(itemName, searchName, 1, true) or 
                                   string.find(searchName, itemName, 1, true) then
                                    
                                    if (item:IsA("Model") or item:IsA("BasePart")) and not trackedModels[tostring(item)] then
                                        table.insert(foundModels, {object = item, name = item.Name})
                                        print("🎯 BRAINROT ENCONTRADO:", item.Name, "en plot:", plot.Name)
                                    end
                                end
                            end
                            
                            -- Buscar recursivamente en subcarpetas
                            if item:IsA("Folder") or item:IsA("Model") then
                                searchInPlot(item, depth + 1)
                            end
                        end
                    end
                    
                    searchInPlot(plot, 0)
                end
            elseif obj:IsA("Folder") then
                -- Buscar carpetas Plots dentro de otras carpetas
                findPlotsFolder(obj)
            end
        end
    end
    
    findPlotsFolder(workspace)
    
    return foundModels
end

-- Función para mostrar toast de notificación
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
    
    local modelsText = #models > 0 and table.concat(models, ", ") or "Ningún brainrot detectado"
    
    local toastText = Instance.new("TextLabel")
    toastText.Size = UDim2.new(1, -20, 1, -20)
    toastText.Position = UDim2.new(0, 10, 0, 10)
    toastText.BackgroundTransparency = 1
    toastText.Text = "🚨 " .. playerName .. " se unió!\n🎯 Brainrots: " .. modelsText
    toastText.TextColor3 = Color3.fromRGB(255, 255, 255)
    toastText.TextScaled = true
    toastText.Font = Enum.Font.Gotham
    toastText.Parent = toastFrame
    
    -- Animación de entrada
    toastFrame.Position = UDim2.new(0.5, -175, 1, 0)
    local tweenIn = TweenService:Create(toastFrame, TweenInfo.new(0.5, Enum.EasingStyle.Back), {Position = UDim2.new(0.5, -175, 1, -180)})
    tweenIn:Play()
    
    spawn(function()
        wait(5)
        local tweenOut = TweenService:Create(toastFrame, TweenInfo.new(0.5), {Position = UDim2.new(0.5, -175, 1, 0)})
        tweenOut:Play()
        tweenOut.Completed:Connect(function()
            toastGui:Destroy()
        end)
    end)
end

-- Función para detectar nuevos jugadores
local function checkForNewPlayers()
    local currentPlayers = Players:GetPlayers()
    
    for _, newPlayer in pairs(currentPlayers) do
        if not trackedPlayers[newPlayer.UserId] and newPlayer ~= player then
            trackedPlayers[newPlayer.UserId] = true
            
            if notificationsEnabled then
                print("🎉 Nuevo jugador detectado:", newPlayer.Name)
                
                local playerModels = {}
                if newPlayer.Character then
                    for _, targetName in pairs(targetModels) do
                        if newPlayer.Character:FindFirstChild(targetName) then
                            table.insert(playerModels, targetName)
                        end
                    end
                end
                
                playNotificationSound()
                showNotificationToast(newPlayer.Name, playerModels)
            end
        end
    end
end

-- Inicializar jugadores existentes
for _, existingPlayer in pairs(Players:GetPlayers()) do
    trackedPlayers[existingPlayer.UserId] = true
end

-- Eventos de botones
espButton.MouseButton1Click:Connect(function()
    espEnabled = not espEnabled
    if espEnabled then
        espButton.Text = "ESP: ON"
        espButton.BackgroundColor3 = Color3.fromRGB(50, 255, 50)
                    print("🔍 ESP activado - Buscando brainrots en carpetas Plots...")
    else
        espButton.Text = "ESP: OFF"
        espButton.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
        for _, espData in pairs(espLines) do
            if espData.beam then espData.beam:Destroy() end
            if espData.attachment0 then espData.attachment0:Destroy() end
            if espData.attachment1 then espData.attachment1:Destroy() end
            if espData.targetPart then espData.targetPart:Destroy() end
        end
        espLines = {}
        trackedModels = {}
        print("❌ ESP desactivado - Líneas limpiadas")
    end
end)

notifButton.MouseButton1Click:Connect(function()
    notificationsEnabled = not notificationsEnabled
    if notificationsEnabled then
        notifButton.Text = "Notificaciones: ON"
        notifButton.BackgroundColor3 = Color3.fromRGB(50, 255, 50)
        print("🔔 Notificaciones activadas")
    else
        notifButton.Text = "Notificaciones: OFF"
        notifButton.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
        print("🔕 Notificaciones desactivadas")
    end
end)

-- Evento para detectar cuando un jugador se une
Players.PlayerAdded:Connect(function(newPlayer)
    if notificationsEnabled and newPlayer ~= player then
        wait(2) -- Esperar a que el jugador cargue completamente
        
        print("🎉 Nuevo jugador detectado:", newPlayer.Name)
        
        local playerModels = {}
        if newPlayer.Character then
            for _, targetName in pairs(targetModels) do
                if newPlayer.Character:FindFirstChild(targetName) then
                    table.insert(playerModels, targetName)
                end
            end
        end
        
        playNotificationSound()
        showNotificationToast(newPlayer.Name, playerModels)
    end
    
    trackedPlayers[newPlayer.UserId] = true
end)

-- Loop principal optimizado para buscar SOLO en carpetas Plots
local lastScanTime = 0
local scanInterval = 3 -- Escanear cada 3 segundos

RunService.Heartbeat:Connect(function()
    local currentTime = tick()
    
    -- Limpiar ESP expirados
    if espEnabled then
        cleanupExpiredESP()
        
        -- Escanear modelos en Plots cada cierto intervalo
        if currentTime - lastScanTime >= scanInterval then
            lastScanTime = currentTime
            
            print("📡 Escaneando carpetas Plots...")
            local foundModels = findTargetModelsInPlots()
            
            for _, modelData in pairs(foundModels) do
                createESPLine(modelData.object, modelData.name)
            end
            
            if #foundModels > 0 then
                print("🎯 Brainrots encontrados en Plots:", #foundModels)
            else
                print("❌ No se encontraron brainrots en las carpetas Plots")
            end
        end
    end
    
    -- Verificar nuevos jugadores
    if notificationsEnabled then
        checkForNewPlayers()
    end
end)

-- Función de prueba para el sonido
local function testSound()
    print("🧪 Probando sonido...")
    playNotificationSound()
end

-- Función de prueba para buscar plots
local function testPlotSearch()
    print("🧪 Probando búsqueda en Plots...")
    local found = findTargetModelsInPlots()
    print("Resultados:", #found, "modelos encontrados")
    for _, model in pairs(found) do
        print("- " .. model.name)
    end
end

-- Comandos de prueba
_G.testESPSound = testSound
_G.testPlotSearch = testPlotSearch

print("🚀 ESP Panel cargado exitosamente!")
print("💡 Tips:")
print("   - Escribe '_G.testESPSound()' para probar el sonido")
print("   - Escribe '_G.testPlotSearch()' para probar la búsqueda en Plots")
print("🎯 Buscando estos brainrots en carpetas Plots:")
for i, name in pairs(targetModels) do
    print("   " .. i .. ". " .. name)
end
