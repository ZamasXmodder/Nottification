-- Enhanced ESP Panel - Fixed Version with Working Sounds and ESP
-- Features: 36 studs max distance, color coding, anchored sizes, improved detection

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Enhanced model detection with color coding (keeping original structure)
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

-- Color assignment for each model
local modelColors = {
    ["la extinct grande"] = Color3.fromRGB(255, 0, 0), -- Red
    ["graipuss medussi"] = Color3.fromRGB(0, 255, 0), -- Green
    ["nooo my hotspot"] = Color3.fromRGB(0, 0, 255), -- Blue
    ["pot hotspot"] = Color3.fromRGB(255, 255, 0), -- Yellow
    ["la sahur combinasion"] = Color3.fromRGB(255, 0, 255), -- Magenta
    ["chicleteira bicicleteira"] = Color3.fromRGB(0, 255, 255), -- Cyan
    ["spaghetti tualetti"] = Color3.fromRGB(255, 165, 0), -- Orange
    ["esok sekolah"] = Color3.fromRGB(128, 0, 128), -- Purple
    ["los nooo my hotspotsitos"] = Color3.fromRGB(255, 192, 203), -- Pink
    ["la grande combinassion"] = Color3.fromRGB(173, 216, 230), -- Light Blue
    ["los combinasionas"] = Color3.fromRGB(144, 238, 144), -- Light Green
    ["nuclearo dinosauro"] = Color3.fromRGB(255, 69, 0), -- Red Orange
    ["los hotspositos"] = Color3.fromRGB(75, 0, 130), -- Indigo
    ["tralalalaledon"] = Color3.fromRGB(255, 215, 0), -- Gold
    ["ketupat kepat"] = Color3.fromRGB(127, 255, 212), -- Aquamarine
    ["los bros"] = Color3.fromRGB(220, 20, 60), -- Crimson
    ["la supreme combinasion"] = Color3.fromRGB(255, 140, 0), -- Dark Orange
    ["ketchuru and masturu"] = Color3.fromRGB(102, 205, 170), -- Medium Aquamarine
    ["garama and madundung"] = Color3.fromRGB(186, 85, 211), -- Medium Orchid
    ["dragon cannelloni"] = Color3.fromRGB(50, 205, 50) -- Lime Green
}

-- Convert to hash table for búsqueda O(1)
for _, name in pairs(modelNames) do
    targetModels[name:lower()] = name
end

-- Constants
local MAX_ESP_DISTANCE = 36 -- Maximum distance in studs
local SCAN_INTERVAL = 2 -- Scan every 2 seconds
local SOUND_COOLDOWN = 0.5

-- Crear ScreenGui principal
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ESPModelPanel"
screenGui.Parent = PlayerGui
screenGui.ResetOnSpawn = false

-- Frame principal del panel
local mainFrame = Instance.new("Frame")
mainFrame.Name = "ESPPanel"
mainFrame.Parent = screenGui
mainFrame.Size = UDim2.new(0, 200, 0, 120)
mainFrame.Position = UDim2.new(1, -210, 0, 10)
mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
mainFrame.BorderSizePixel = 0
mainFrame.BackgroundTransparency = 0.1

-- Esquinas redondeadas
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = mainFrame

-- Variables
local espEnabled = true
local foundModels = {}
local processedObjects = {}
local lastScanTime = 0
local lastSoundTime = 0
local playerAttachments = {}

-- Botón toggle para ESP
local espToggle = Instance.new("TextButton")
espToggle.Name = "ESPToggle"
espToggle.Parent = mainFrame
espToggle.Size = UDim2.new(1, -20, 0, 30)
espToggle.Position = UDim2.new(0, 10, 0, 10)
espToggle.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
espToggle.Text = "ESP: ON"
espToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
espToggle.TextScaled = true
espToggle.Font = Enum.Font.GothamBold
espToggle.BorderSizePixel = 0

local toggleCorner = Instance.new("UICorner")
toggleCorner.CornerRadius = UDim.new(0, 6)
toggleCorner.Parent = espToggle

-- Distance display
local distanceLabel = Instance.new("TextLabel")
distanceLabel.Parent = mainFrame
distanceLabel.Size = UDim2.new(1, -20, 0, 20)
distanceLabel.Position = UDim2.new(0, 10, 0, 45)
distanceLabel.BackgroundTransparency = 1
distanceLabel.Text = "Max Distance: " .. MAX_ESP_DISTANCE .. " studs"
distanceLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
distanceLabel.TextScaled = true
distanceLabel.Font = Enum.Font.Gotham

-- Model count
local countLabel = Instance.new("TextLabel")
countLabel.Parent = mainFrame
countLabel.Size = UDim2.new(1, -20, 0, 20)
countLabel.Position = UDim2.new(0, 10, 0, 70)
countLabel.BackgroundTransparency = 1
countLabel.Text = "Models Found: 0"
countLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
countLabel.TextScaled = true
countLabel.Font = Enum.Font.Gotham

-- Sistema de Toast Notifications (FIXED)
local function createToast(message)
    local toastGui = Instance.new("ScreenGui")
    toastGui.Name = "ToastNotification"
    toastGui.Parent = PlayerGui
    toastGui.ResetOnSpawn = false
    
    local toastFrame = Instance.new("Frame")
    toastFrame.Name = "ToastFrame"
    toastFrame.Parent = toastGui
    toastFrame.Size = UDim2.new(0, 300, 0, 60)
    toastFrame.Position = UDim2.new(0.5, -150, 1, 100)
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
        UDim2.new(0.5, -150, 1, -80),
        "Out",
        "Quart",
        0.5,
        true
    )
    
    spawn(function()
        wait(3)
        toastFrame:TweenPosition(
            UDim2.new(0.5, -150, 1, 100),
            "In",
            "Quart",
            0.5,
            true,
            function()
                toastGui:Destroy()
            end
        )
    end)
end

-- FIXED sound functions - restored original working code
local function playNotificationSound()
    local currentTime = tick()
    if currentTime - lastSoundTime < SOUND_COOLDOWN then
        return
    end
    lastSoundTime = currentTime
    
    local tones = {
        {pitch = 2.0, duration = 0.1},
        {pitch = 2.5, duration = 0.1},
        {pitch = 3.0, duration = 0.2}
    }
    
    for i, tone in pairs(tones) do
        spawn(function()
            wait((i-1) * 0.1)
            local sound = Instance.new("Sound")
            sound.SoundId = "rbxasset://sounds/electronicpingshort.wav"
            sound.Volume = 0.5
            sound.Pitch = tone.pitch
            sound.Parent = workspace
            sound:Play()
            
            spawn(function()
                wait(tone.duration + 0.5)
                if sound and sound.Parent then
                    sound:Destroy()
                end
            end)
        end)
    end
end

local function playPlayerJoinSound()
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
            
            spawn(function()
                wait(1)
                if sound and sound.Parent then
                    sound:Destroy()
                end
            end)
        end)
    end
end

-- Get model distance
local function getPlayerDistance(model)
    local character = LocalPlayer.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then
        return math.huge
    end
    
    local modelPosition
    if model:IsA("Model") then
        local cf, size = model:GetBoundingBox()
        modelPosition = cf.Position
    else
        modelPosition = model.Position
    end
    
    local playerPosition = character.HumanoidRootPart.Position
    return (modelPosition - playerPosition).Magnitude
end

-- Get model color
local function getModelColor(modelName)
    return modelColors[modelName:lower()] or Color3.fromRGB(255, 255, 0)
end

-- FIXED ESP label creation with color coding and anchored size
local function createESPLabel(model, modelName)
    if model:FindFirstChild("ESPLabel") then
        return model:FindFirstChild("ESPLabel")
    end
    
    local billboardGui = Instance.new("BillboardGui")
    billboardGui.Name = "ESPLabel"
    billboardGui.Parent = model
    billboardGui.Size = UDim2.new(0, 150, 0, 50) -- Fixed anchored size
    billboardGui.StudsOffset = Vector3.new(0, 3, 0)
    billboardGui.AlwaysOnTop = true
    billboardGui.LightInfluence = 0
    
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Parent = billboardGui
    nameLabel.Size = UDim2.new(1, 0, 0.7, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = modelName
    nameLabel.TextColor3 = getModelColor(modelName) -- Apply color coding
    nameLabel.TextStrokeTransparency = 0
    nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    nameLabel.TextScaled = true
    nameLabel.Font = Enum.Font.GothamBold
    
    -- Distance label
    local distLabel = Instance.new("TextLabel")
    distLabel.Name = "DistanceLabel"
    distLabel.Parent = billboardGui
    distLabel.Size = UDim2.new(1, 0, 0.3, 0)
    distLabel.Position = UDim2.new(0, 0, 0.7, 0)
    distLabel.BackgroundTransparency = 1
    distLabel.Text = "0m"
    distLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    distLabel.TextStrokeTransparency = 0
    distLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    distLabel.TextScaled = true
    distLabel.Font = Enum.Font.Gotham
    
    return billboardGui
end

-- FIXED ESP line creation with color coding
local function createESPLine(model, modelName)
    if model:FindFirstChild("ESPLine") then
        return model:FindFirstChild("ESPLine")
    end
    
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
    beam.Color = ColorSequence.new(getModelColor(modelName)) -- Apply color coding
    beam.Width0 = 0.2
    beam.Width1 = 0.2
    beam.Transparency = NumberSequence.new(0.3)
    beam.FaceCamera = true
    
    return beam, attachment0
end

-- Toggle ESP function
local function toggleESP()
    espEnabled = not espEnabled
    
    if espEnabled then
        espToggle.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
        espToggle.Text = "ESP: ON"
        
        for model, modelName in pairs(foundModels) do
            if model.Parent then
                local distance = getPlayerDistance(model)
                if distance <= MAX_ESP_DISTANCE then
                    if model:FindFirstChild("ESPLabel") then
                        model.ESPLabel.Enabled = true
                    end
                    if model:FindFirstChild("ESPLine") then
                        model.ESPLine.Enabled = true
                    end
                end
            end
        end
    else
        espToggle.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
        espToggle.Text = "ESP: OFF"
        
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

espToggle.MouseButton1Click:Connect(toggleESP)

-- FIXED model detection function (restored original logic)
local function isTargetModel(objName)
    local lowerName = objName:lower()
    for targetName, originalName in pairs(targetModels) do
        if string.find(lowerName, targetName) then
            return originalName
        end
    end
    return nil
end

-- Enhanced scan function with distance checking
local function scanForModels()
    local currentTime = tick()
    if currentTime - lastScanTime < SCAN_INTERVAL then
        return
    end
    lastScanTime = currentTime
    
    local function searchInContainer(container, depth)
        if depth > 5 then return end
        
        for _, obj in pairs(container:GetChildren()) do
            if processedObjects[obj] then
                continue
            end
            
            if obj:IsA("Model") or obj:IsA("Part") or obj:IsA("MeshPart") then
                local targetModelName = isTargetModel(obj.Name)
                
                if not targetModelName and obj:IsA("Model") and obj.PrimaryPart then
                    targetModelName = isTargetModel(obj.PrimaryPart.Name)
                end
                
                if targetModelName and not foundModels[obj] then
                    -- Check distance
                    local distance = getPlayerDistance(obj)
                    
                    if distance <= MAX_ESP_DISTANCE then
                        foundModels[obj] = targetModelName
                        
                        if espEnabled then
                            createESPLabel(obj, targetModelName)
                            local beam, playerAttachment = createESPLine(obj, targetModelName)
                            if playerAttachment then
                                table.insert(playerAttachments, playerAttachment)
                            end
                        else
                            local label = createESPLabel(obj, targetModelName)
                            local beam, playerAttachment = createESPLine(obj, targetModelName)
                            if playerAttachment then
                                table.insert(playerAttachments, playerAttachment)
                            end
                            if label then label.Enabled = false end
                            if beam then beam.Enabled = false end
                        end
                        
                        playNotificationSound()
                        createToast("Found: " .. targetModelName)
                    end
                    
                    processedObjects[obj] = true
                end
            end
            
            if (obj:IsA("Model") or obj:IsA("Folder")) and depth < 3 then
                searchInContainer(obj, depth + 1)
            end
        end
    end
    
    searchInContainer(workspace, 0)
    
    -- Update count
    local count = 0
    for _ in pairs(foundModels) do
        count = count + 1
    end
    countLabel.Text = "Models Found: " .. count
end

-- Update distances and visibility
local function updateDistances()
    for model, modelName in pairs(foundModels) do
        if model.Parent then
            local distance = getPlayerDistance(model)
            
            if model:FindFirstChild("ESPLabel") and model.ESPLabel:FindFirstChild("DistanceLabel") then
                model.ESPLabel.DistanceLabel.Text = math.floor(distance) .. "m"
                
                -- Show/hide based on distance
                local shouldShow = distance <= MAX_ESP_DISTANCE and espEnabled
                model.ESPLabel.Enabled = shouldShow
                if model:FindFirstChild("ESPLine") then
                    model.ESPLine.Enabled = shouldShow
                end
            end
        end
    end
end

-- Cleanup function
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

-- Update ESP lines
local function updateESPLines()
    local character = LocalPlayer.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then
        return
    end
    
    local rootPart = character.HumanoidRootPart
    
    for _, attachment in pairs(playerAttachments) do
        if attachment and attachment.Parent then
            attachment.Parent = rootPart
        end
    end
    
    local validAttachments = {}
    for _, attachment in pairs(playerAttachments) do
        if attachment and attachment.Parent then
            table.insert(validAttachments, attachment)
        end
    end
    playerAttachments = validAttachments
end

-- FIXED Player events (restored original working code)
Players.PlayerAdded:Connect(function(player)
    createToast("@" .. player.Name .. " se unió al servidor")
    playPlayerJoinSound()
end)

LocalPlayer.CharacterAdded:Connect(function(character)
    wait(1)
    updateESPLines()
end)

-- Event connections
workspace.ChildAdded:Connect(function(child)
    wait(0.1)
    scanForModels()
end)

workspace.DescendantAdded:Connect(function(descendant)
    if descendant:IsA("Model") or descendant:IsA("Part") or descendant:IsA("MeshPart") then
        wait(0.1)
        scanForModels()
    end
end)

-- Main loops
spawn(function()
    while true do
        wait(1)
        updateDistances()
    end
end)

spawn(function()
    while true do
        wait(1)
        updateESPLines()
    end
end)

spawn(function()
    while true do
        wait(5)
        cleanupRemovedModels()
    end
end)

-- Make draggable
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

-- Initial scan
scanForModels()

print("Fixed ESP Panel loaded - Working sounds, ESP detection, 36 studs max, and color coding!")
