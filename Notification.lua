--// =========================
--//  ESP LITE (sin límite, solo nuevos, 15s) + Player ESP
--//  Rendimiento: SelectionBox, escaneo incremental con cola, listener DescendantAdded
--// =========================

-- Servicios
local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Parámetros
local MARK_DURATION           = 15      -- segundos por marca
local RAINBOW_SPEED           = 0.3     -- velocidad animación color
local SCAN_STEP_BUDGET        = 1200    -- cuántos nodos procesa por Heartbeat
local CONT_SCAN_PERIOD        = 2       -- segundos (seguridad; ya hay listener)
local PLAYER_LINE_FPS         = 30      -- Hz de actualización línea jugador
local MAX_RECURSION_DEPTH     = 14      -- seguridad
local USE_TWEEN_TOAST         = true

-- Utilidades
local function isInstance(x) return typeof(x)=="Instance" end
local function isValid(inst) return isInstance(inst) and inst.Parent ~= nil and inst:IsDescendantOf(game) end
local function safeDestroy(x) if isInstance(x) and x.Destroy then x:Destroy() end end
local function hsv(h) return Color3.fromHSV(h,1,1) end

-- Target names (coincidencia exacta)
local targetModels = {
    "La Secret Combinasion","Burguro And Fryuro","Los 67","Chillin Chili","Tang Tang Kelentang",
    "Money Money Puggy","Los Primos","Los Tacoritas","La Grande Combinasion","Pot Hotspot",
    "Mariachi Corazoni","Secret Lucky Block","To to to Sahur","Strawberry Elephant",
    "Ketchuru and Musturu","La Extinct Grande","Tictac Sahur","Tacorita Bicicleta",
    "Chicleteira Bicicleteira","Spaghetti Tualetti","Esok Sekolah","Los Chicleteiras","67",
    "Los Combinasionas","Nuclearo Dinosauro","Las Sis","Los Hotspotsitos","Tralaledon",
    "Ketupat Kepat","Los Bros","La Supreme Combinasion","Ketchuru and Masturu",
    "Garama and Madundung","Dragon Cannelloni","Celularcini Viciosini"
}
local targetSet = {} for _,n in ipairs(targetModels) do targetSet[n]=true end

-- Estado brainrots
-- everMarked: recuerda instancias ya marcadas alguna vez (no volver a marcarlas).
-- activeMarks[inst] = { sb=SelectionBox, createdAt=t, baseHue=h }
local everMarked  = setmetatable({}, {__mode="k"})
local activeMarks = setmetatable({}, {__mode="k"})
local rainbowHue  = 0

-- Cola de escaneo incremental (BFS)
local scanQueue = {}
local queueHead, queueTail = 1, 0
local function qpush(x) queueTail+=1; scanQueue[queueTail]=x end
local function qpop() if queueHead<=queueTail then local v=scanQueue[queueHead]; scanQueue[queueHead]=nil; queueHead+=1; return v end end
local function qreset() for i=queueHead,queueTail do scanQueue[i]=nil end; queueHead,queueTail=1,0 end

-- SelectionBox liviano
local function newSelectionFor(target)
    local sb = Instance.new("SelectionBox")
    sb.LineThickness = 0.03
    sb.Color3 = hsv(rainbowHue)
    sb.Adornee = target -- acepta Model o BasePart
    sb.Archivable = false
    sb.Parent = workspace
    return sb
end

-- Marcar una instancia una sola vez (si coincide y nunca fue marcada)
local function markOnce(inst)
    if not isValid(inst) then return end
    if not (inst:IsA("Model") or inst:IsA("BasePart")) then return end
    if not targetSet[inst.Name] then return end
    if everMarked[inst] then return end
    everMarked[inst] = true

    local sb = newSelectionFor(inst)
    activeMarks[inst] = { sb=sb, createdAt=time(), baseHue=rainbowHue }
end

-- Escaneo incremental: procesa nodos de la cola hasta agotar presupuesto
local function processScanStep()
    local budget = SCAN_STEP_BUDGET
    while budget>0 do
        local node = qpop()
        if not node then break end
        if isValid(node) then
            -- marcar si es target y nunca marcado
            if targetSet[node.Name] and (node:IsA("Model") or node:IsA("BasePart")) then
                if not everMarked[node] then
                    markOnce(node)
                end
            end
            -- encolar hijos
            local children = node:GetChildren()
            for _,ch in ipairs(children) do
                if isValid(ch) then qpush(ch) end
            end
        end
        budget-=1
    end
end

-- Escaneo completo inicial: llenar cola con workspace
local function startFullScan()
    qreset()
    qpush(workspace)
end

-- Listener instantáneo: marca nuevos al aparecer
local function onDescendantAdded(inst)
    if not isValid(inst) then return end
    if not targetSet[inst.Name] then return end
    -- model/basepart, marcar si nunca fue marcado
    if inst:IsA("Model") or inst:IsA("BasePart") then
        if not everMarked[inst] then
            markOnce(inst)
        end
    end
end

-- Limpia marks expirados o inválidos
local function cleanupExpired()
    local now = time()
    for inst, data in pairs(activeMarks) do
        local expired = (now - data.createdAt) >= MARK_DURATION
        if expired or not isValid(inst) or not isValid(data.sb) then
            if data.sb then safeDestroy(data.sb) end
            activeMarks[inst] = nil
        end
    end
end

-- Arcoíris activo
local function updateColors()
    for inst, data in pairs(activeMarks) do
        local sb = data.sb
        if isValid(sb) then
            local t = (time()-data.createdAt)*RAINBOW_SPEED
            local hue = (data.baseHue + t)%1
            sb.Color3 = hsv(hue)
        end
    end
end

-- =======================
-- Player ESP (lite)
-- =======================
local linePool = {}
local function acquireLine()
    local line = table.remove(linePool)
    if line then line.Parent = workspace; return line end
    line = Instance.new("Part")
    line.Name = "PlayerESPLine"
    line.Size = Vector3.new(0.08,0.08,1)
    line.Material = Enum.Material.Neon
    line.Color = Color3.fromRGB(255, 64, 64)
    line.Anchored = true
    line.CanCollide = false
    line.Parent = workspace
    return line
end
local function releaseLine(line) if line then line.Parent=nil table.insert(linePool,line) end end

local playerESPEnabled=false
local playerESPData = {} -- uid -> {targetPlayer, sb=SelectionBox, line}

local function createPlayerESP(p)
    if p==player then return end
    local char = p.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    if playerESPData[p.UserId] then return end
    local sb = Instance.new("SelectionBox")
    sb.LineThickness = 0.03
    sb.Color3 = Color3.fromRGB(255,0,0)
    sb.Adornee = char
    sb.Parent = workspace
    local line = acquireLine()
    playerESPData[p.UserId] = {targetPlayer=p, sb=sb, line=line}
end

local function cleanupPlayerESP()
    for uid, d in pairs(playerESPData) do
        safeDestroy(d.sb)
        releaseLine(d.line)
        playerESPData[uid]=nil
    end
end

local lastPEspUpd = 0
local function updatePlayerESPLines(dt)
    local now = time()
    if now - lastPEspUpd < 1/PLAYER_LINE_FPS then return end
    lastPEspUpd = now

    local myChar = player.Character
    local myHRP  = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myHRP then return end
    local myPos = myHRP.Position

    local toRemove={}
    for uid, d in pairs(playerESPData) do
        local p   = d.targetPlayer
        local chr = p and p.Character
        local hrp = chr and chr:FindFirstChild("HumanoidRootPart")
        if not (p and chr and hrp and isValid(d.line) and isValid(d.sb)) then
            table.insert(toRemove, uid)
        else
            local tpos = hrp.Position
            local dir  = tpos - myPos
            local dist = dir.Magnitude
            local mid  = myPos + dir*0.5
            local line = d.line
            line.Size  = Vector3.new(0.08,0.08,dist)
            line.CFrame = CFrame.lookAt(mid, tpos)
        end
    end
    for _,uid in ipairs(toRemove) do
        local d = playerESPData[uid]
        if d then safeDestroy(d.sb) releaseLine(d.line) playerESPData[uid]=nil end
    end
end

local function refreshPlayerESPForAll()
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=player then createPlayerESP(p) end
    end
end

-- =======================
-- GUI LITE
-- =======================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ESPPanelLite"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.new(0,200,0,180)
main.Position = UDim2.new(1,-210,0,10)
main.BackgroundColor3 = Color3.fromRGB(28,28,28)
main.Active = true
main.Draggable = true
main.Parent = screenGui
do local c=Instance.new("UICorner") c.CornerRadius=UDim.new(0,8) c.Parent=main end

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1,0,0,28)
title.BackgroundColor3 = Color3.fromRGB(45,45,45)
title.Text = "ESP LITE"
title.TextColor3 = Color3.new(1,1,1)
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.Parent = main
do local c=Instance.new("UICorner") c.CornerRadius=UDim.new(0,8) c.Parent=title end

local function btn(y, text)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1,-20,0,30)
    b.Position = UDim2.new(0,10,0,y)
    b.BackgroundColor3 = Color3.fromRGB(255,60,60)
    b.Text = text
    b.TextColor3 = Color3.new(1,1,1)
    b.TextScaled = true
    b.Font = Enum.Font.Gotham
    b.Parent = main
    local c=Instance.new("UICorner") c.CornerRadius=UDim.new(0,6) c.Parent=b
    return b
end

local espEnabled=false
local contEnabled=true

local espBtn   = btn(40,  "ESP: OFF")
local contBtn  = btn(80,  "Búsqueda Continua: ON")
local pEspBtn  = btn(120, "ESP Player: OFF")

-- Toast minimal
local function toast(msg)
    local gui = Instance.new("ScreenGui")
    gui.Name="Toast"
    gui.Parent=playerGui
    local f=Instance.new("Frame")
    f.Size=UDim2.new(0,320,0,85)
    f.Position=UDim2.new(0.5,-160,1,-95)
    f.BackgroundColor3=Color3.fromRGB(40,40,40)
    f.BorderSizePixel=0
    f.Parent=gui
    local c=Instance.new("UICorner") c.CornerRadius=UDim.new(0,10) c.Parent=f
    local l=Instance.new("TextLabel")
    l.BackgroundTransparency=1
    l.Size=UDim2.new(1,-20,1,-20)
    l.Position=UDim2.new(0,10,0,10)
    l.Text=msg
    l.TextScaled=true
    l.TextColor3=Color3.new(1,1,1)
    l.Font=Enum.Font.Gotham
    l.Parent=f
    if USE_TWEEN_TOAST then
        f.Position=UDim2.new(0.5,-160,1,0)
        TweenService:Create(f,TweenInfo.new(0.35,Enum.EasingStyle.Back),{Position=UDim2.new(0.5,-160,1,-95)}):Play()
    end
    task.spawn(function()
        task.wait(3.5)
        local tw = TweenService:Create(f,TweenInfo.new(0.3),{Position=UDim2.new(0.5,-160,1,0)})
        tw:Play()
        tw.Completed:Once(function() safeDestroy(gui) end)
    end)
end

-- Botones
espBtn.MouseButton1Click:Connect(function()
    espEnabled = not espEnabled
    if espEnabled then
        espBtn.Text = "ESP: ON"
        espBtn.BackgroundColor3 = Color3.fromRGB(60,200,60)
        startFullScan()         -- arranca cola completa (workspace entero)
        toast("ESP activado (15s por brainrot)")
    else
        espBtn.Text = "ESP: OFF"
        espBtn.BackgroundColor3 = Color3.fromRGB(255,60,60)
        for inst, data in pairs(activeMarks) do
            safeDestroy(data.sb)
            activeMarks[inst] = nil
        end
        toast("ESP desactivado")
    end
end)

contBtn.MouseButton1Click:Connect(function()
    contEnabled = not contEnabled
    contBtn.Text = contEnabled and "Búsqueda Continua: ON" or "Búsqueda Continua: OFF"
    contBtn.BackgroundColor3 = contEnabled and Color3.fromRGB(60,200,60) or Color3.fromRGB(255,60,60)
end)

pEspBtn.MouseButton1Click:Connect(function()
    playerESPEnabled = not playerESPEnabled
    if playerESPEnabled then
        pEspBtn.Text = "ESP Player: ON"
        pEspBtn.BackgroundColor3 = Color3.fromRGB(60,200,60)
        refreshPlayerESPForAll()
    else
        pEspBtn.Text = "ESP Player: OFF"
        pEspBtn.BackgroundColor3 = Color3.fromRGB(255,60,60)
        cleanupPlayerESP()
    end
end)

-- Eventos jugadores (lite)
Players.PlayerAdded:Connect(function(p)
    if playerESPEnabled then
        local function onChar()
            task.wait(0.2)
            local d = playerESPData[p.UserId]
            if d then safeDestroy(d.sb) releaseLine(d.line) playerESPData[p.UserId]=nil end
            createPlayerESP(p)
        end
        if p.Character then onChar() end
        p.CharacterAdded:Connect(onChar)
    end
end)

Players.PlayerRemoving:Connect(function(p)
    local d = playerESPData[p.UserId]
    if d then safeDestroy(d.sb) releaseLine(d.line) playerESPData[p.UserId]=nil end
end)

for _,p in ipairs(Players:GetPlayers()) do
    if p~=player then
        p.CharacterAdded:Connect(function()
            if playerESPEnabled then
                task.wait(0.2)
                local d = playerESPData[p.UserId]
                if d then safeDestroy(d.sb) releaseLine(d.line) playerESPData[p.UserId]=nil end
                createPlayerESP(p)
            end
        end)
    end
end

-- Listener instantáneo para nuevos brainrots
workspace.DescendantAdded:Connect(function(inst)
    if not espEnabled then return end
    -- Solo marcar nuevos (si ya fue marcado alguna vez, no se vuelve a marcar)
    if targetSet[inst.Name] and (inst:IsA("Model") or inst:IsA("BasePart")) then
        if not everMarked[inst] then
            markOnce(inst)
        end
    end
end)

-- Loop principal
local lastContScan = 0
RunService.Heartbeat:Connect(function(dt)
    rainbowHue = (rainbowHue + 0.02) % 1

    if espEnabled then
        -- procesar cola incremental hasta cubrir TODO
        processScanStep()
        -- animación color + expiraciones
        updateColors()
        cleanupExpired()
        -- búsqueda continua (seguridad por si algo no triggereó el listener)
        local now = time()
        if contEnabled and (now - lastContScan) >= CONT_SCAN_PERIOD then
            lastContScan = now
            -- solo encolar raíz si la cola está vacía, para no duplicar
            if queueHead>queueTail then
                qpush(workspace)
            end
        end
    end

    if playerESPEnabled then
        updatePlayerESPLines(dt)
    end
end)

print("✅ ESP LITE cargado (SelectionBox, sin límite, 15s por brainrot, solo nuevos)")
