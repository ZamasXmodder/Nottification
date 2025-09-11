-- Mini Panel ESP para Modelos Específicos
-- Ubicación: Esquina superior derecha

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Lista de modelos a detectar
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

-- Tabla para almacenar modelos encontrados
local foundModels = {}
local modelLabels = {}

-- Función para crear sonido de notificación
local function playNotificationSound()
    local sound = Instance.new("Sound")
    sound.SoundId = "rbxassetid://77665577458181"
    sound.Volume = 0.5
    sound.Parent = workspace
    sound:Play()
    
    sound.Ended:Connect(function()
        sound:Destroy()
    end)
end

-- Función para crear highlight (ESP)
local function createHighlight(model)
    local highlight = Instance.new("Highlight")
    highlight.Parent = model
    highlight.FillColor = Color3.fromRGB(255, 0, 0)
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.FillTransparency = 0.5
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop -- Ver a través de paredes
    return highlight
end

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

-- Función para buscar modelos en el workspace
local function scanForModels()
    local function searchInContainer(container)
        for _, obj in pairs(container:GetChildren()) do
            if obj:IsA("Model") or obj:IsA("Part") or obj:IsA("MeshPart") then
                for _, targetModel in pairs(targetModels) do
                    if string.find(obj.Name:lower(), targetModel:lower()) or 
                       (obj:IsA("Model") and obj.PrimaryPart and string.find(obj.PrimaryPart.Name:lower(), targetModel:lower())) then
                        
                        if not foundModels[obj] then
                            foundModels[obj] = targetModel
                            createHighlight(obj)
                            addModelToList(targetModel, obj)
                            playNotificationSound()
                        end
                    end
                end
            end
            
            -- Buscar recursivamente en contenedores
            if obj:IsA("Model") or obj:IsA("Folder") then
                searchInContainer(obj)
            end
        end
    end
    
    searchInContainer(workspace)
end

-- Función para limpiar modelos eliminados
local function cleanupRemovedModels()
    for model, modelName in pairs(foundModels) do
        if not model.Parent then
            foundModels[model] = nil
            removeModelFromList(modelName)
        end
    end
end

-- Detectar cuando nuevos jugadores entran al servidor
Players.PlayerAdded:Connect(function(player)
    playNotificationSound()
end)

-- Bucle principal de escaneo
RunService.Heartbeat:Connect(function()
    scanForModels()
    cleanupRemovedModels()
end)

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
