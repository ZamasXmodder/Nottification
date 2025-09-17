local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Modelos objetivo
local targetModels = {
    "Tacorita Bicicleta",
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

-- Sistema de memoria para brainrots detectados
local detectedBrainrots = {} -- Almacena objetos que ya fueron detectados
local memoryCleanupTime = 0

-- Variables para el efecto rainbow
local rainbowHue = 0

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
    "rbxassetid://77665577458181",
    "rbxassetid://77665577458181",
    "rbxassetid://77665577458181",
    "rbxassetid://77665577458181"
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

-- Función para verificar si un objeto aún existe y es válido
local function isObjectValid(obj)
    return obj and obj.Parent and not obj.Parent:IsA("Debris")
end

-- Función para generar color rainbow
local function getRainbowColor(hue)
    return Color3.fromHSV(hue, 1, 1)
end

-- Función para generar ID único de objeto para el sistema de memoria
local function getObjectMemoryId(targetObject)
    if targetObject:IsA("Model") then
        local primaryPart = targetObject.PrimaryPart or targetObject:FindFirstChildOfClass("BasePart")
        if primaryPart then
            return tostring(targetObject.Name) .. "_" .. tostring(primaryPart.Position)
        end
    elseif targetObject:IsA("BasePart") then
        return tostring(targetObject.Name) .. "_" .. tostring(targetObject.Position)
    end
    return tostring(targetObject)
end

-- Función para verificar si un objeto ya fue detectado recientemente
local function wasRecentlyDetected(targetObject)
    local memoryId = getObjectMemoryId(targetObject)
    local currentTime = tick()
    
    if detectedBrainrots[memoryId] then
        -- Si ha pasado más de 25 segundos desde la detección, permitir nueva detección
        if currentTime - detectedBrainrots[memoryId].timestamp > 25 then
            detectedBrainrots[memoryId] = nil
            return false
        end
        return true
    end
    return false
end

-- Función para marcar objeto como detectado en memoria
local function markAsDetected(targetObject)
    local memoryId = getObjectMemoryId(targetObject)
    detectedBrainrots[memoryId] = {
        timestamp = tick(),
        name = targetObject.Name
    }
    print("🧠 Marcado en memoria:", targetObject.Name, "ID:", memoryId)
end

-- Función para limpiar memoria de objetos antiguos
local function cleanupMemory()
    local currentTime = tick()
    local cleanedCount = 0
    
    for memoryId, data in pairs(detectedBrainrots) do
        if currentTime - data.timestamp > 30 then -- 5 segundos extra de gracia
            detectedBrainrots[memoryId] = nil
            cleanedCount = cleanedCount + 1
        end
    end
    
    if cleanedCount > 0 then
        print("🧹 Memoria limpiada:", cleanedCount, "objetos removidos")
    end
end

-- Función para crear líneas ESP con color rainbow
local function createESPLine(targetObject, targetName)
    local character = player.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then return end
    
    -- Verificar que el objeto aún existe
    if not isObjectValid(targetObject) then
        print("❌ Objeto no válido:", targetName)
        return
    end
    
    -- Verificar sistema de memoria
    if wasRecentlyDetected(targetObject) then
        print("🧠 Objeto ya detectado recientemente, omitiendo:", targetName)
        return
    end
    
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
    
    -- Marcar como detectado en memoria
    markAsDetected(targetObject)
    
    -- Crear línea usando Beam súper delgada con color rainbow
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
    beam.Color = ColorSequence.new(getRainbowColor(rainbowHue))
    beam.Width0 = 0.1
    beam.Width1 = 0.1
    beam.Transparency = NumberSequence.new(0.3)
    beam.FaceCamera = true
    beam.Parent = workspace
    
    -- Crear ID único para cada línea
    local uniqueId = tostring(targetObject) .. "_" .. tick()
    
    local espData = {
        beam = beam,
        attachment0 = attachment0,
        attachment1 = attachment1,
        targetPart = targetPart,
        timestamp = tick(),
        targetName = targetName,
        uniqueId = uniqueId,
        targetObject = targetObject, -- Referencia al objeto original
        initialHue = rainbowHue -- Guardar hue inicial para animación individual
    }
    
    table.insert(espLines, espData)
    
    print("🌈 ESP rainbow creado para:", targetName, "ID:", uniqueId)
    return espData
end

-- Función mejorada para limpiar líneas ESP
local function cleanupExpiredESP()
    local currentTime = tick()
    for i = #espLines, 1, -1 do
        local espData = espLines[i]
        local shouldRemove = false
        local reason = ""
        
        -- Verificar si expiró por tiempo (25 segundos)
        if currentTime - espData.timestamp > 25 then
            shouldRemove = true
            reason = "expiró después de 25 segundos"
        end
        
        -- Verificar si el objeto original ya no existe
        if not shouldRemove and not isObjectValid(espData.targetObject) then
            shouldRemove = true
            reason = "objeto ya no existe"
        end
        
        if shouldRemove then
            if espData.beam then espData.beam:Destroy() end
            if espData.attachment0 then espData.attachment0:Destroy() end
            if espData.attachment1 then espData.attachment1:Destroy() end
            if espData.targetPart then espData.targetPart:Destroy() end
            
            table.remove(espLines, i)
            print("🗑️ ESP removido para:", espData.targetName, "- Razón:", reason)
        end
    end
end

-- Función para actualizar colores rainbow de todas las líneas ESP
local function updateRainbowColors()
    for _, espData in pairs(espLines) do
        if espData.beam and isObjectValid(espData.beam) then
            -- Cada línea tiene su propio offset de color basado en su hue inicial
            local lineHue = (espData.initialHue + (tick() - espData.timestamp) * 0.5) % 1
            espData.beam.Color = ColorSequence.new(getRainbowColor(lineHue))
        end
    end
end

-- Función para buscar brainrots en carpetas Plots (solo objetos válidos y no detectados)
local function findTargetModelsInPlots()
    local foundModels = {}
    
    local function findPlotsFolder(container)
        for _, obj in pairs(container:GetChildren()) do
            if obj.Name == "Plots" and obj:IsA("Folder") then
                print("📁 Encontrada carpeta Plots en:", container.Name)
                
                for _, plot in pairs(obj:GetChildren()) do
                    local function searchInPlot(plotContainer, depth)
                        if depth > 10 then return end
                        
                        for _, item in pairs(plotContainer:GetChildren()) do
                            -- Verificar que el objeto es válido antes de procesarlo
                            if isObjectValid(item) then
                                for _, targetName in pairs(targetModels) do
                                    local itemName = string.lower(item.Name)
                                    local searchName = string.lower(targetName)
                                    
                                    if itemName == searchName or 
                                       string.find(itemName, searchName, 1, true) or 
                                       string.find(searchName, itemName, 1, true) then
                                        
                                        if item:IsA("Model") or item:IsA("BasePart") then
                                            -- Solo agregar si no fue detectado recientemente
                                            if not wasRecentlyDetected(item) then
                                                table.insert(foundModels, {object = item, name = item.Name})
                                                print("🎯 NUEVO BRAINROT VÁLIDO ENCONTRADO:", item.Name, "en plot:", plot.Name)
                                            else
                                                print("🧠 Brainrot ya detectado, omitiendo:", item.Name)
                                            end
                                        end
                                    end
                                end
                                
                                if item:IsA("Folder") or item:IsA("Model") then
                                    searchInPlot(item, depth + 1)
                                end
                            end
                        end
                    end
                    
                    searchInPlot(plot, 0)
                end
            elseif obj:IsA("Folder") then
                findPlotsFolder(obj)
            end
        end
    end
    
    findPlotsFolder(workspace)
    return foundModels
end

-- Función para actualizar ESP (solo cuando sea necesario)
local function updateESP()
    if not espEnabled then return end
    
    print("🔄 Actualizando ESP...")
    
    -- Primero limpiar líneas expiradas y objetos que ya no existen
    cleanupExpiredESP()
    
    -- Luego buscar y marcar solo objetos válidos y nuevos
    local foundModels = findTargetModelsInPlots()
    
    for _, modelData in pairs(foundModels) do
        -- Verificar una vez más que el objeto es válido antes de crear ESP
        if isObjectValid(modelData.object) then
            createESPLine(modelData.object, modelData.name)
        end
    end
    
    print("📊 ESP actualizado:", #foundModels, "brainrots nuevos marcados")
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
        print("🌈 ESP rainbow activado - Marcando brainrots nuevos...")
        updateESP() -- Marcar brainrots al activar
    else
        espButton.Text = "ESP: OFF"
        espButton.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
        -- Limpiar todas las líneas ESP
        for _, espData in pairs(espLines) do
            if espData.beam then espData.beam:Destroy() end
            if espData.attachment0 then espData.attachment0:Destroy() end
            if espData.attachment1 then espData.attachment1:Destroy() end
            if espData.targetPart then espData.targetPart:Destroy() end
        end
        espLines = {}
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

-- Evento cuando un jugador se UNE
Players.PlayerAdded:Connect(function(newPlayer)
    print("👤 Jugador se unió:", newPlayer.Name)
    
    if notificationsEnabled and newPlayer ~= player then
        wait(2) -- Esperar a que el jugador cargue
        
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
    
    -- Actualizar ESP cuando entra un jugador (solo objetos válidos y nuevos)
    if espEnabled then
        print("🔄 Actualizando ESP por jugador que se unió...")
        wait(1) -- Pequeña pausa para que el jugador se establezca
        updateESP()
    end
end)

-- Evento cuando un jugador se VA
Players.PlayerRemoving:Connect(function(leavingPlayer)
    print("👋 Jugador se fue:", leavingPlayer.Name)
    
    trackedPlayers[leavingPlayer.UserId] = nil
    
    -- NO actualizar ESP cuando sale un jugador para evitar marcar objetos inexistentes
    print("ℹ️ No se actualiza ESP cuando sale un jugador (evita objetos fantasma)")
end)

-- Loop principal para efectos rainbow, limpieza y memoria
local lastCleanupTime = 0
local lastMemoryCleanup = 0
RunService.Heartbeat:Connect(function()
    local currentTime = tick()
    
    -- Actualizar hue global del rainbow
    rainbowHue = (rainbowHue + 0.02) % 1
    
    -- Actualizar colores rainbow de las líneas ESP
    if espEnabled and #espLines > 0 then
        updateRainbowColors()
    end
    
    -- Limpiar líneas expiradas cada 2 segundos
    if espEnabled and currentTime - lastCleanupTime >= 2 then
        lastCleanupTime = currentTime
        cleanupExpiredESP()
    end
    
    -- Limpiar memoria cada 10 segundos
    if currentTime - lastMemoryCleanup >= 10 then
        lastMemoryCleanup = currentTime
        cleanupMemory()
    end
end)

-- Funciones de prueba
local function testSound()
    print("🧪 Probando sonido...")
    playNotificationSound()
end

local function testPlotSearch()
    print("🧪 Probando búsqueda en Plots...")
    local found = findTargetModelsInPlots()
    print("Resultados:", #found, "modelos válidos y nuevos encontrados")
    for _, model in pairs(found) do
        print("- " .. model.name, "- Válido:", isObjectValid(model.object))
    end
end

local function forceUpdateESP()
    print("🧪 Forzando actualización de ESP...")
    updateESP()
end

local function cleanupAllESP()
    print("🧪 Limpiando todo el ESP...")
    for _, espData in pairs(espLines) do
        if espData.beam then espData.beam:Destroy() end
        if espData.attachment0 then espData.attachment0:Destroy() end
        if espData.attachment1 then espData.attachment1:Destroy() end
        if espData.targetPart then espData.targetPart:Destroy() end
    end
    espLines = {}
    print("✅ Todo el ESP limpiado")
end

local function clearMemory()
    print("🧪 Limpiando memoria de brainrots detectados...")
    detectedBrainrots = {}
    print("✅ Memoria limpiada - todos los brainrots pueden ser detectados nuevamente")
end

local function showMemoryStatus()
    print("🧠 Estado de la memoria:")
    local count = 0
    local currentTime = tick()
    for memoryId, data in pairs(detectedBrainrots) do
        local timeLeft = 25 - (currentTime - data.timestamp)
        if timeLeft > 0 then
            count = count + 1
            print("   - " .. data.name .. " (quedan " .. math.floor(timeLeft) .. "s)")
        end
    end
    print("Total en memoria:", count, "objetos")
end

-- Comandos de prueba
_G.testESPSound = testSound
_G.testPlotSearch = testPlotSearch
_G.forceUpdateESP = forceUpdateESP
_G.cleanupAllESP = cleanupAllESP
_G.clearMemory = clearMemory
_G.showMemoryStatus = showMemoryStatus

print("🚀 ESP Panel Rainbow con Sistema de Memoria cargado exitosamente!")
print("💡 Tips:")
print("   - '_G.testESPSound()' para probar el sonido")
print("   - '_G.testPlotSearch()' para probar la búsqueda")
print("   - '_G.forceUpdateESP()' para forzar actualización de ESP")
print("   - '_G.cleanupAllESP()' para limpiar todo el ESP")
print("   - '_G.clearMemory()' para limpiar la memoria")
print("   - '_G.showMemoryStatus()' para ver el estado de la memoria")
print("🌈 Características nuevas:")
print("   ✅ Colores rainbow animados en las líneas ESP")
print("   🧠 Sistema de memoria que previene re-detección")
print("   ⏰ Memoria se limpia automáticamente después de 25s")
print("   🎯 Solo detecta brainrots nuevos o no detectados recientemente")
print("🎯 Características existentes:")
print("   ✅ Permite brainrots duplicados (si no están en memoria)")
print("   ⏰ Líneas ESP expiran en 25 segundos")
print("   🔄 Solo se actualiza cuando ENTRAN jugadores")
print("   🗑️ Limpia automáticamente objetos que ya no existen")
print("   📏 Líneas súper delgadas para mejor rendimiento")
print("   🚫 No marca objetos fantasma cuando salen jugadores")
print("🎯 Buscando estos brainrots en carpetas Plots:")
for i, name in pairs(targetModels) do
    print("   " .. i .. ". " .. name)
end
