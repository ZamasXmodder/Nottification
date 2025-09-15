-- Enhanced ESP Panel with Improved Detection and Features
-- Features: 36 studs max distance, color coding, anchored sizes, better detection

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Enhanced model detection with color coding
local targetModels = {}
local modelConfig = {
    ["la extinct grande"] = {name = "La Extinct Grande", color = Color3.fromRGB(255, 0, 0)}, -- Red
    ["graipuss medussi"] = {name = "Graipuss Medussi", color = Color3.fromRGB(0, 255, 0)}, -- Green
    ["nooo my hotspot"] = {name = "Nooo My Hotspot", color = Color3.fromRGB(0, 0, 255)}, -- Blue
    ["pot hotspot"] = {name = "Pot Hotspot", color = Color3.fromRGB(255, 255, 0)}, -- Yellow
    ["la sahur combinasion"] = {name = "La Sahur Combinasion", color = Color3.fromRGB(255, 0, 255)}, -- Magenta
    ["chicleteira bicicleteira"] = {name = "Chicleteira Bicicleteira", color = Color3.fromRGB(0, 255, 255)}, -- Cyan
    ["spaghetti tualetti"] = {name = "Spaghetti Tualetti", color = Color3.fromRGB(255, 165, 0)}, -- Orange
    ["esok sekolah"] = {name = "Esok Sekolah", color = Color3.fromRGB(128, 0, 128)}, -- Purple
    ["los nooo my hotspotsitos"] = {name = "Los Nooo My Hotspotsitos", color = Color3.fromRGB(255, 192, 203)}, -- Pink
    ["la grande combinassion"] = {name = "La Grande Combinassion", color = Color3.fromRGB(173, 216, 230)}, -- Light Blue
    ["los combinasionas"] = {name = "Los Combinasionas", color = Color3.fromRGB(144, 238, 144)}, -- Light Green
    ["nuclearo dinosauro"] = {name = "Nuclearo Dinosauro", color = Color3.fromRGB(255, 69, 0)}, -- Red Orange
    ["los hotspositos"] = {name = "Los Hotspositos", color = Color3.fromRGB(75, 0, 130)}, -- Indigo
    ["tralalalaledon"] = {name = "Tralalalaledon", color = Color3.fromRGB(255, 215, 0)}, -- Gold
    ["ketupat kepat"] = {name = "Ketupat Kepat", color = Color3.fromRGB(127, 255, 212)}, -- Aquamarine
    ["los bros"] = {name = "Los Bros", color = Color3.fromRGB(220, 20, 60)}, -- Crimson
    ["la supreme combinasion"] = {name = "La Supreme Combinasion", color = Color3.fromRGB(255, 140, 0)}, -- Dark Orange
    ["ketchuru and masturu"] = {name = "Ketchuru and Masturu", color = Color3.fromRGB(102, 205, 170)}, -- Medium Aquamarine
    ["garama and madundung"] = {name = "Garama and Madundung", color = Color3.fromRGB(186, 85, 211)}, -- Medium Orchid
    ["dragon cannelloni"] = {name = "Dragon Cannelloni", color = Color3.fromRGB(50, 205, 50)} -- Lime Green
}

-- Convert to hash table for fast lookup
for key, config in pairs(modelConfig) do
    targetModels[key] = config
end

-- Constants
local MAX_ESP_DISTANCE = 36 -- Maximum distance in studs
local SCAN_INTERVAL = 1.5 -- Scan every 1.5 seconds
local ESP_LABEL_SIZE = UDim2.new(0, 150, 0, 40) -- Fixed size for labels
local SOUND_COOLDOWN = 0.3

-- Create main GUI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "EnhancedESPPanel"
screenGui.Parent = PlayerGui
screenGui.ResetOnSpawn = false

-- Main panel frame
local mainFrame = Instance.new("Frame")
mainFrame.Name = "ESPPanel"
mainFrame.Parent = screenGui
mainFrame.Size = UDim2.new(0, 200, 0, 100)
mainFrame.Position = UDim2.new(1, -210, 0, 10)
mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
mainFrame.BorderSizePixel = 0
mainFrame.BackgroundTransparency = 0.1

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = mainFrame

-- ESP state variables
local espEnabled = true
local foundModels = {}
local processedObjects = {}
local lastScanTime = 0
local lastSoundTime = 0
local playerAttachments = {}

-- ESP Toggle Button
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

-- Distance display label
local distanceLabel = Instance.new("TextLabel")
distanceLabel.Parent = mainFrame
distanceLabel.Size = UDim2.new(1, -20, 0, 20)
distanceLabel.Position = UDim2.new(0, 10, 0, 45)
distanceLabel.BackgroundTransparency = 1
distanceLabel.Text = "Max Distance: " .. MAX_ESP_DISTANCE .. " studs"
distanceLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
distanceLabel.TextScaled = true
distanceLabel.Font = Enum.Font.Gotham

-- Model count display
local countLabel = Instance.new("TextLabel")
countLabel.Parent = mainFrame
countLabel.Size = UDim2.new(1, -20, 0, 20)
countLabel.Position = UDim2.new(0, 10, 0, 70)
countLabel.BackgroundTransparency = 1
countLabel.Text = "Models Found: 0"
countLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
countLabel.TextScaled = true
countLabel.Font = Enum.Font.Gotham

-- Enhanced toast notification system
local function createToast(message, color)
    color = color or Color3.fromRGB(40, 40, 40)
    
    local toastGui = Instance.new("ScreenGui")
    toastGui.Name = "ToastNotification"
    toastGui.Parent = PlayerGui
    toastGui.ResetOnSpawn = false
    
    local toastFrame = Instance.new("Frame")
    toastFrame.Parent = toastGui
    toastFrame.Size = UDim2.new(0, 320, 0, 60)
    toastFrame.Position = UDim2.new(0.5, -160, 1, 100)
    toastFrame.BackgroundColor3 = color
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
    toastLabel.Font = Enum.Font.GothamBold
    toastLabel.TextXAlignment = Enum.TextXAlignment.Center
    
    -- Animation
    toastFrame:TweenPosition(UDim2.new(0.5, -160, 1, -80), "Out", "Quart", 0.5, true)
    
    spawn(function()
        wait(3)
        toastFrame:TweenPosition(UDim2.new(0.5, -160, 1, 100), "In", "Quart", 0.5, true, function()
            toastGui:Destroy()
        end)
    end)
end

-- Enhanced sound system
local function playNotificationSound()
    local currentTime = tick()
    if currentTime - lastSoundTime < SOUND_COOLDOWN then return end
    lastSoundTime = currentTime
    
    local sound = Instance.new("Sound")
    sound.SoundId = "rbxasset://sounds/electronicpingshort.wav"
    sound.Volume = 0.6
    sound.Pitch = 2.2
    sound.Parent = workspace
    sound:Play()
    
    spawn(function()
        wait(1)
        if sound and sound.Parent then
            sound:Destroy()
        end
    end)
end

-- Enhanced player distance calculation
local function getPlayerDistance(position)
    local character = LocalPlayer.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then
        return math.huge
    end
    
    local playerPosition = character.HumanoidRootPart.Position
    return (position - playerPosition).Magnitude
end

-- Get model center position more accurately
local function getModelCenterPosition(model)
    local cf, size = model:GetBoundingBox()
    return cf.Position
end

-- Enhanced ESP label creation with fixed size and color coding
local function createESPLabel(model, config)
    if model:FindFirstChild("ESPLabel") then
        return model:FindFirstChild("ESPLabel")
    end
    
    local billboardGui = Instance.new("BillboardGui")
    billboardGui.Name = "ESPLabel"
    billboardGui.Parent = model
    billboardGui.Size = ESP_LABEL_SIZE -- Fixed size
    billboardGui.StudsOffset = Vector3.new(0, 3, 0)
    billboardGui.AlwaysOnTop = true
    billboardGui.LightInfluence = 0
    billboardGui.MaxDistance = MAX_ESP_DISTANCE -- Built-in distance limiting
    
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Parent = billboardGui
    nameLabel.Size = UDim2.new(1, 0, 1, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = config.name
    nameLabel.TextColor3 = config.color -- Use configured color
    nameLabel.TextStrokeTransparency = 0
    nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    nameLabel.TextScaled = true
    nameLabel.Font = Enum.Font.GothamBold
    
    -- Distance label
    local distLabel = Instance.new("TextLabel")
    distLabel.Name = "DistanceLabel"
    distLabel.Parent = billboardGui
    distLabel.Size = UDim2.new(1, 0, 0.4, 0)
    distLabel.Position = UDim2.new(0, 0, 0.6, 0)
    distLabel.BackgroundTransparency = 1
    distLabel.Text = "0 studs"
    distLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    distLabel.TextStrokeTransparency = 0
    distLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    distLabel.TextScaled = true
    distLabel.Font = Enum.Font.Gotham
    
    return billboardGui
end

-- Enhanced ESP line creation
local function createESPLine(model, config)
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
    beam.Color = ColorSequence.new(config.color) -- Use configured color
    beam.Width0 = 0.3
    beam.Width1 = 0.3
    beam.Transparency = NumberSequence.new(0.4)
    beam.FaceCamera = true
    
    return beam, attachment0
end

-- Improved model detection with fuzzy matching
local function isTargetModel(objName)
    local lowerName = objName:lower()
    
    -- Direct match first
    if targetModels[lowerName] then
        return targetModels[lowerName]
    end
    
    -- Fuzzy matching for partial names
    for targetName, config in pairs(targetModels) do
        -- Check if any significant part of the target name is in the object name
        local targetWords = {}
        for word in targetName:gmatch("%S+") do
            if #word > 2 then -- Only consider words longer than 2 characters
                table.insert(targetWords, word)
            end
        end
        
        local matchCount = 0
        for _, word in pairs(targetWords) do
            if string.find(lowerName, word) then
                matchCount = matchCount + 1
            end
        end
        
        -- If at least 60% of words match, consider it a match
        if matchCount / #targetWords >= 0.6 then
            return config
        end
    end
    
    return nil
end

-- Enhanced model scanning with distance checking
local function scanForModels()
    local currentTime = tick()
    if currentTime - lastScanTime < SCAN_INTERVAL then return end
    lastScanTime = currentTime
    
    local function searchInContainer(container, depth)
        if depth > 4 then return end
        
        for _, obj in pairs(container:GetChildren()) do
            if processedObjects[obj] then continue end
            
            if obj:IsA("Model") or obj:IsA("Part") or obj:IsA("MeshPart") then
                local config = isTargetModel(obj.Name)
                
                -- Check PrimaryPart for models
                if not config and obj:IsA("Model") and obj.PrimaryPart then
                    config = isTargetModel(obj.PrimaryPart.Name)
                end
                
                if config and not foundModels[obj] then
                    -- Check distance before adding
                    local modelPosition = getModelCenterPosition(obj)
                    local distance = getPlayerDistance(modelPosition)
                    
                    if distance <= MAX_ESP_DISTANCE then
                        foundModels[obj] = {config = config, distance = distance}
                        
                        if espEnabled then
                            createESPLabel(obj, config)
                            local beam, playerAttachment = createESPLine(obj, config)
                            if playerAttachment then
                                table.insert(playerAttachments, playerAttachment)
                            end
                        else
                            local label = createESPLabel(obj, config)
                            local beam, playerAttachment = createESPLine(obj, config)
                            if playerAttachment then
                                table.insert(playerAttachments, playerAttachment)
                            end
                            if label then label.Enabled = false end
                            if beam then beam.Enabled = false end
                        end
                        
                        playNotificationSound()
                        createToast("Found: " .. config.name .. " (" .. math.floor(distance) .. " studs)", Color3.fromRGB(0, 150, 0))
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
    
    -- Update count display
    local count = 0
    for _ in pairs(foundModels) do
        count = count + 1
    end
    countLabel.Text = "Models Found: " .. count
end

-- Enhanced distance update system
local function updateDistances()
    for model, data in pairs(foundModels) do
        if model.Parent then
            local modelPosition = getModelCenterPosition(model)
            local distance = getPlayerDistance(modelPosition)
            data.distance = distance
            
            -- Update distance label if ESP is active
            if espEnabled and model:FindFirstChild("ESPLabel") and model.ESPLabel:FindFirstChild("DistanceLabel") then
                model.ESPLabel.DistanceLabel.Text = math.floor(distance) .. " studs"
                
                -- Hide if too far
                local shouldShow = distance <= MAX_ESP_DISTANCE
                model.ESPLabel.Enabled = shouldShow
                if model:FindFirstChild("ESPLine") then
                    model.ESPLine.Enabled = shouldShow
                end
            end
        end
    end
end

-- Enhanced cleanup function
local function cleanupRemovedModels()
    local toRemove = {}
    
    for model, data in pairs(foundModels) do
        if not model.Parent or data.distance > MAX_ESP_DISTANCE then
            toRemove[model] = data
        end
    end
    
    for model, data in pairs(toRemove) do
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

-- Toggle ESP function
local function toggleESP()
    espEnabled = not espEnabled
    
    if espEnabled then
        espToggle.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
        espToggle.Text = "ESP: ON"
        
        for model, data in pairs(foundModels) do
            if model.Parent and data.distance <= MAX_ESP_DISTANCE then
                if model:FindFirstChild("ESPLabel") then
                    model.ESPLabel.Enabled = true
                end
                if model:FindFirstChild("ESPLine") then
                    model.ESPLine.Enabled = true
                end
            end
        end
    else
        espToggle.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
        espToggle.Text = "ESP: OFF"
        
        for model, data in pairs(foundModels) do
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

-- Connect toggle button
espToggle.MouseButton1Click:Connect(toggleESP)

-- Enhanced player attachment update
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
    
    -- Clean invalid attachments
    local validAttachments = {}
    for _, attachment in pairs(playerAttachments) do
        if attachment and attachment.Parent then
            table.insert(validAttachments, attachment)
        end
    end
    playerAttachments = validAttachments
end

-- Player events
Players.PlayerAdded:Connect(function(player)
    createToast("@" .. player.Name .. " joined the server", Color3.fromRGB(0, 100, 200))
end)

LocalPlayer.CharacterAdded:Connect(function(character)
    wait(1)
    updateESPLines()
end)

-- Workspace events for better detection
workspace.ChildAdded:Connect(function(child)
    wait(0.2)
    processedObjects[child] = nil -- Allow reprocessing of new objects
    scanForModels()
end)

workspace.DescendantAdded:Connect(function(descendant)
    if descendant:IsA("Model") or descendant:IsA("Part") or descendant:IsA("MeshPart") then
        wait(0.2)
        processedObjects[descendant] = nil
        scanForModels()
    end
end)

-- Main update loops
spawn(function()
    while true do
        wait(2)
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

-- Make panel draggable
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

print("Enhanced ESP Panel loaded - Improved detection with 36 studs max distance and color coding!")
