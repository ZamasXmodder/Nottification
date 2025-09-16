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
local trackedPlayers = {}
local lastPlayerCount = #Players:GetPlayers()

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

-- Crear sonido de notificación
local notificationSound = Instance.new("Sound")
notificationSound.SoundId = "rbxassetid://131961136" -- Sonido de notificación
notificationSound.Volume = 0.5
notificationSound.Parent = screenGui

-- Función para crear líneas ESP
local function createESPLine(targetPosition, targetName)
    local character = player.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then return end
    
    local playerPosition = character.HumanoidRootPart.Position
    
    -- Crear línea usando Beam
    local attachment0 = Instance.new("Attachment")
    local attachment1 = Instance.new("Attachment")
    
    attachment0.Parent = character.HumanoidRootPart
    attachment1.Parent = workspace.Terrain
    attachment1.WorldPosition = targetPosition
    
    local beam = Instance.new("Beam")
    beam.Attachment0 = attachment0
    beam.Attachment1 = attachment1
    beam.Color = ColorSequence.new(Color3.fromRGB(255, 0, 0))
    beam.Width0 = 0.5
    beam.Width1 = 0.5
    beam.Transparency = NumberSequence.new(0.3)
    beam.Parent = workspace
    
    -- Guardar referencia con timestamp
    local espData = {
        beam = beam,
        attachment0 = attachment0,
        attachment1 = attachment1,
        timestamp = tick(),
        targetName = targetName
    }
    
    table.insert(espLines, espData)
    
    return espData
end

-- Función para limpiar líneas ESP expiradas
local function cleanupExpiredESP()
    local currentTime = tick()
    for i = #espLines, 1, -1 do
        local espData = espLines[i]
        if currentTime - espData.timestamp > 20 then -- 20 segundos
            if espData.beam then espData.beam:Destroy() end
            if espData.attachment0 then espData.attachment0:Destroy() end
            if espData.attachment1 then espData.attachment1:Destroy() end
            table.remove(espLines, i)
        end
    end
end

-- Función para buscar modelos en workspace
local function findTargetModels()
    local foundModels = {}
    
    local function searchInContainer(container)
        for _, obj in pairs(container:GetChildren()) do
            if obj:IsA("Model") or obj:IsA("Part") or obj:IsA("MeshPart") then
                for _, targetName in pairs(targetModels) do
                    if string.find(string.lower(obj.Name), string.lower(targetName)) then
                        local position = nil
                        if obj:IsA("Model") and obj.PrimaryPart then
                            position = obj.PrimaryPart.Position
                        elseif obj:IsA("BasePart") then
                            position = obj.Position
                        end
                        
                        if position then
                            table.insert(foundModels, {name = obj.Name, position = position})
                        end
                    end
                end
            end
            
            -- Buscar recursivamente en carpetas
            if obj:IsA("Folder") then
                searchInContainer(obj)
            end
        end
    end
    
    searchInContainer(workspace)
    return foundModels
end

-- Función para mostrar toast de notificación
local function showNotificationToast(playerName, models)
    local toastGui = Instance.new("ScreenGui")
    toastGui.Name = "NotificationToast"
    toastGui.Parent = playerGui
    
    local toastFrame = Instance.new("Frame")
    toastFrame.Size = UDim2.new(0, 300, 0, 80)
    toastFrame.Position = UDim2.new(0.5, -150, 1, -150)
    toastFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    toastFrame.BorderSizePixel = 0
    toastFrame.Parent = toastGui
    
    local toastCorner = Instance.new("UICorner")
    toastCorner.CornerRadius = UDim.new(0, 10)
    toastCorner.Parent = toastFrame
    
    local toastText = Instance.new("TextLabel")
    toastText.Size = UDim2.new(1, -20, 1, -20)
    toastText.Position = UDim2.new(0, 10, 0, 10)
    toastText.BackgroundTransparency = 1
    toastText.Text = playerName .. " se unió!\nModelos: " .. table.concat(models, ", ")
    toastText.TextColor3 = Color3.fromRGB(255, 255, 255)
    toastText.TextScaled = true
    toastText.Font = Enum.Font.Gotham
    toastText.Parent = toastFrame
    
    -- Animación de entrada
    toastFrame.Position = UDim2.new(0.5, -150, 1, 0)
    local tweenIn = TweenService:Create(toastFrame, TweenInfo.new(0.5), {Position = UDim2.new(0.5, -150, 1, -150)})
    tweenIn:Play()
    
    -- Eliminar después de 5 segundos
    wait(5)
    local tweenOut = TweenService:Create(toastFrame, TweenInfo.new(0.5), {Position = UDim2.new(0.5, -150, 1, 0)})
    tweenOut:Play()
    tweenOut.Completed:Connect(function()
        toastGui:Destroy()
    end)
end

-- Función para detectar nuevos jugadores
local function checkForNewPlayers()
    local currentPlayers = Players:GetPlayers()
    local currentPlayerCount = #currentPlayers
    
    if currentPlayerCount > lastPlayerCount then
        -- Nuevo jugador detectado
        for _, newPlayer in pairs(currentPlayers) do
            if not trackedPlayers[newPlayer.UserId] then
                trackedPlayers[newPlayer.UserId] = true
                
                if notificationsEnabled and newPlayer ~= player then
                    -- Buscar modelos que tiene el jugador
                    local playerModels = {}
                    if newPlayer.Character then
                        for _, targetName in pairs(targetModels) do
                            if newPlayer.Character:FindFirstChild(targetName) then
                                table.insert(playerModels, targetName)
                            end
                        end
                    end
                    
                    -- Reproducir sonido y mostrar toast
                    notificationSound:Play()
                    spawn(function()
                        showNotificationToast(newPlayer.Name, playerModels)
                    end)
                end
            end
        end
    end
    
    lastPlayerCount = currentPlayerCount
end

-- Eventos de botones
espButton.MouseButton1Click:Connect(function()
    espEnabled = not espEnabled
    if espEnabled then
        espButton.Text = "ESP: ON"
        espButton.BackgroundColor3 = Color3.fromRGB(50, 255, 50)
    else
        espButton.Text = "ESP: OFF"
        espButton.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
        -- Limpiar todas las líneas ESP
        for _, espData in pairs(espLines) do
            if espData.beam then espData.beam:Destroy() end
            if espData.attachment0 then espData.attachment0:Destroy() end
            if espData.attachment1 then espData.attachment1:Destroy() end
        end
        espLines = {}
    end
end)

notifButton.MouseButton1Click:Connect(function()
    notificationsEnabled = not notificationsEnabled
    if notificationsEnabled then
        notifButton.Text = "Notificaciones: ON"
        notifButton.BackgroundColor3 = Color3.fromRGB(50, 255, 50)
    else
        notifButton.Text = "Notificaciones: OFF"
        notifButton.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
    end
end)

-- Loop principal
RunService.Heartbeat:Connect(function()
    if espEnabled then
        cleanupExpiredESP()
        
        local foundModels = findTargetModels()
        for _, modelData in pairs(foundModels) do
            createESPLine(modelData.position, modelData.name)
        end
    end
    
    if notificationsEnabled then
        checkForNewPlayers()
    end
end)

print("ESP Panel cargado exitosamente!")
