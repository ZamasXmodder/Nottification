-- LocalScript completo - Colocar en StarterPlayerScripts
-- Sistema de notificaciones + ESP con panel

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Variables
local espEnabled = false
local highlights = {}
local gui = nil
local isGuiOpen = false

-- Lista de models para ESP
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

-- Función para reproducir sonido de notificación
local function playNotificationSound()
    local sound = Instance.new("Sound")
    sound.SoundId = "rbxasset://sounds/electronicpingshort.wav"
    sound.Volume = 0.5
    sound.Parent = workspace
    sound:Play()
    
    sound.Ended:Connect(function()
        sound:Destroy()
    end)
end

-- Función para mostrar toast notification
local function showToast(playerName)
    StarterGui:SetCore("SendNotification", {
        Title = "¡Jugador Conectado!";
        Text = playerName .. " ha entrado al servidor";
        Duration = 5;
        Icon = "rbxasset://textures/ui/GuiImagePlaceholder.png";
    })
end

-- Función para buscar models recursivamente
local function findModelsRecursively(parent)
    local foundModels = {}
    
    local function searchChildren(obj)
        for _, child in pairs(obj:GetChildren()) do
            if child:IsA("Model") then
                for _, targetName in pairs(targetModels) do
                    if child.Name == targetName then
                        table.insert(foundModels, child)
                        break
                    end
                end
            end
            -- Buscar recursivamente en los hijos
            searchChildren(child)
        end
    end
    
    searchChildren(parent)
    return foundModels
end

-- Función para crear highlight
local function createHighlight(model)
    if highlights[model] then return end
    
    local highlight = Instance.new("Highlight")
    highlight.FillColor = Color3.fromRGB(255, 0, 0)
    highlight.OutlineColor = Color3.fromRGB(255, 255, 0)
    highlight.FillTransparency = 0.5
    highlight.OutlineTransparency = 0
    highlight.Parent = model
    
    highlights[model] = highlight
end

-- Función para remover highlight
local function removeHighlight(model)
    if highlights[model] then
        highlights[model]:Destroy()
        highlights[model] = nil
    end
end

-- Función optimizada para actualizar ESP
local function updateESP()
    if not espEnabled then
        -- Limpiar todos los highlights
        for model, highlight in pairs(highlights) do
            highlight:Destroy()
        end
        highlights = {}
        return
    end
    
    -- Usar la búsqueda optimizada
    local foundModels = findModelsOptimized()
    
    -- Crear highlights solo para models nuevos
    for _, model in pairs(foundModels) do
        if not highlights[model] and model.Parent then
            createHighlight(model)
        end
    end
    
    -- Remover highlights de models que ya no existen (más eficiente)
    local toRemove = {}
    for model, highlight in pairs(highlights) do
        if not model.Parent then
            highlight:Destroy()
            table.insert(toRemove, model)
        end
    end
    
    for _, model in pairs(toRemove) do
        highlights[model] = nil
    end
end

-- Función para crear el GUI
local function createGUI()
    gui = Instance.new("ScreenGui")
    gui.Name = "ESPPanel"
    gui.Parent = playerGui
    gui.ResetOnSpawn = false
    
    -- Frame principal
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 250, 0, 150)
    mainFrame.Position = UDim2.new(1, -270, 0, 20) -- Esquina superior derecha
    mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = gui
    mainFrame.ClipsDescendants = true
    
    -- Esquinas redondeadas
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = mainFrame
    
    -- Título
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, 0, 0, 30)
    title.Position = UDim2.new(0, 0, 0, 0)
    title.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    title.BorderSizePixel = 0
    title.Text = "Panel ESP"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextScaled = true
    title.Font = Enum.Font.SourceSansBold
    title.Parent = mainFrame
    
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 8)
    titleCorner.Parent = title
    
    -- Botón ESP Toggle
    local espButton = Instance.new("TextButton")
    espButton.Name = "ESPButton"
    espButton.Size = UDim2.new(0.9, 0, 0, 35)
    espButton.Position = UDim2.new(0.05, 0, 0, 40)
    espButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    espButton.BorderSizePixel = 0
    espButton.Text = "ESP: OFF"
    espButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    espButton.TextScaled = true
    espButton.Font = Enum.Font.SourceSans
    espButton.Parent = mainFrame
    
    local buttonCorner = Instance.new("UICorner")
    buttonCorner.CornerRadius = UDim.new(0, 4)
    buttonCorner.Parent = espButton
    
    -- Info label
    local infoLabel = Instance.new("TextLabel")
    infoLabel.Name = "InfoLabel"
    infoLabel.Size = UDim2.new(0.9, 0, 0, 60)
    infoLabel.Position = UDim2.new(0.05, 0, 0, 85)
    infoLabel.BackgroundTransparency = 1
    infoLabel.Text = "Presiona F para abrir/cerrar\nESP para models específicos"
    infoLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    infoLabel.TextScaled = true
    infoLabel.Font = Enum.Font.SourceSans
    infoLabel.TextWrapped = true
    infoLabel.Parent = mainFrame
    
    -- Funcionalidad del botón ESP
    espButton.MouseButton1Click:Connect(function()
        espEnabled = not espEnabled
        espButton.Text = espEnabled and "ESP: ON" or "ESP: OFF"
        espButton.BackgroundColor3 = espEnabled and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(60, 60, 60)
        updateESP()
    end)
    
    -- Inicialmente oculto
    mainFrame.Size = UDim2.new(0, 250, 0, 0)
end

-- Función para animar el panel
local function togglePanel()
    if not gui then return end
    
    local mainFrame = gui.MainFrame
    local targetSize = isGuiOpen and UDim2.new(0, 250, 0, 0) or UDim2.new(0, 250, 0, 150)
    
    local tween = TweenService:Create(
        mainFrame,
        TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
        {Size = targetSize}
    )
    
    tween:Play()
    isGuiOpen = not isGuiOpen
end

-- Sistema de notificaciones para nuevos jugadores
Players.PlayerAdded:Connect(function(newPlayer)
    if newPlayer ~= player then
        wait(1)
        playNotificationSound()
        showToast(newPlayer.Name)
        print(newPlayer.Name .. " ha entrado al servidor!")
    end
end)

-- Manejar input del usuario
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Enum.KeyCode.F then
        togglePanel()
    end
end)

-- Loop para actualizar ESP continuamente
RunService.Heartbeat:Connect(function()
    if espEnabled then
        updateESP()
    end
end)

-- Inicializar GUI
createGUI()

print("Script cargado: Presiona F para abrir el panel ESP")
