--// =========================
--//  ESP LITE+ (Highlight, sin límite, 15s, notifs, X-Ray mapa, Ghost player)
--// =========================

-- Servicios
local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Parámetros
local MARK_DURATION           = 15      -- segundos por highlight de brainrot
local RAINBOW_SPEED           = 0.35    -- velocidad arcoíris
local SCAN_STEP_BUDGET        = 1200    -- nodos por frame en el BFS incremental
local CONT_SCAN_PERIOD        = 2       -- s; deja la cola viva si queda vacía
local PLAYER_LINE_FPS         = 30      -- Hz línea a jugadores
local MAX_RECURSION_DEPTH     = 14
local USE_TWEEN_TOAST         = true
local XRAY_TRANSPARENCY       = 0.8     -- 80% invisible

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
-- everMarked: recuerda instancias ya marcadas (no remarcar)
-- activeMarks[inst] = { hl=Highlight, createdAt=t, baseHue=h }
local everMarked  = setmetatable({}, {__mode="k"})
local activeMarks = setmetatable({}, {__mode="k"})
local rainbowHue  = 0

-- Cola BFS incremental
local scanQueue = {}
local qh, qt = 1, 0
local function qpush(x) qt+=1; scanQueue[qt]=x end
local function qpop() if qh<=qt then local v=scanQueue[qh]; scanQueue[qh]=nil; qh+=1; return v end end
local function qempty() return qh>qt end
local function qreset() for i=qh,qt do scanQueue[i]=nil end qh,qt=1,0 end

-- Notificaciones (sonido + toast)
local notifSound = Instance.new("Sound")
notifSound.SoundId = "rbxassetid://77665577458181"
notifSound.Volume = 0.7
notifSound.Parent = playerGui

local function playNotificationSound()
    local ok = pcall(function() notifSound:Play() end)
end

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

-- Highlight helper
local function newHighlightFor(target)
    local h = Instance.new("Highlight")
    h.FillTransparency   = 0.45
    h.OutlineTransparency= 0.15
    h.OutlineColor       = Color3.fromRGB(255,255,255)
    h.DepthMode          = Enum.HighlightDepthMode.AlwaysOnTop -- a través de paredes
    h.Adornee = target
    h.Parent  = workspace
    return h
end

-- Marcar brainrot una sola vez (si coincide y nunca marcado)
local function markOnce(inst)
    if not isValid(inst) then return end
    if not (inst:IsA("Model") or inst:IsA("BasePart")) then return end
    if not targetSet[inst.Name] then return end
    if everMarked[inst] then return end
    everMarked[inst] = true

    local hl = newHighlightFor(inst)
    hl.FillColor = hsv(rainbowHue)

    activeMarks[inst] = { hl=hl, createdAt=time(), baseHue=rainbowHue }
end

-- Escaneo incremental (BFS)
local function processScanStep()
    local budget = SCAN_STEP_BUDGET
    while budget>0 do
        local node = qpop()
        if not node then break end
        if isValid(node) then
            if targetSet[node.Name] and (node:IsA("Model") or node:IsA("BasePart")) then
                if not everMarked[node] then
                    markOnce(node)
                end
            end
            local children = node:GetChildren()
            for _,ch in ipairs(children) do
                if isValid(ch) then qpush(ch) end
            end
        end
        budget-=1
    end
end

-- Primera pasada (llenar cola con workspace)
local function startFullScan()
    qreset()
    qpush(workspace)
end

-- Listener instantáneo para nuevos brainrots
workspace.DescendantAdded:Connect(function(inst)
    if not targetSet[inst.Name] then return end
    if not (inst:IsA("Model") or inst:IsA("BasePart")) then return end
    markOnce(inst)
end)

-- Limpia highlights expirados o inválidos
local function cleanupExpired()
    local now = time()
    for inst, data in pairs(activeMarks) do
        local expired = (now - data.createdAt) >= MARK_DURATION
        if expired or not isValid(inst) or not isValid(data.hl) then
            if data.hl then safeDestroy(data.hl) end
            activeMarks[inst] = nil
        end
    end
end

-- Arcoíris activo
local function updateColors()
    for inst, data in pairs(activeMarks) do
        local hl = data.hl
        if isValid(hl) then
            local t = (time()-data.createdAt)*RAINBOW_SPEED
            local hue = (data.baseHue + t)%1
            hl.FillColor = hsv(hue)
        end
    end
end

-- =======================
-- Player ESP (highlight + línea)
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
local playerESPData = {} -- uid -> {targetPlayer, hl, line}

local function createPlayerESP(p)
    if p==player then return end
    local char = p.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    if playerESPData[p.UserId] then return end
    local hl = newHighlightFor(char)
    hl.FillColor = Color3.fromRGB(255,0,0)
    local line = acquireLine()
    playerESPData[p.UserId] = {targetPlayer=p, hl=hl, line=line}
end

local function cleanupPlayerESP()
    for uid, d in pairs(playerESPData) do
        safeDestroy(d.hl)
        releaseLine(d.line)
        playerESPData[uid]=nil
    end
end

local lastPEspUpd = 0
local function updatePlayerESPLines()
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
        if not (p and chr and hrp and isValid(d.line) and isValid(d.hl)) then
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
        if d then safeDestroy(d.hl) releaseLine(d.line) playerESPData[uid]=nil end
    end
end

local function refreshPlayerESPForAll()
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=player then createPlayerESP(p) end
    end
end

-- =======================
-- X-RAY del mapa (80%) excepto brainrots
-- =======================
local xrayEnabled = false
-- Guardamos opacidad original de BaseParts que modificamos
local originalTransparency = setmetatable({}, {__mode="k"})

local function shouldIgnore(inst)
    if inst:IsDescendantOf(playerGui) then return true end
    if inst:IsDescendantOf(Players) then return true end
    return false
end

local function isBrainrot(inst)
    if not targetSet[inst.Name] then return false end
    return inst:IsA("Model") or inst:IsA("BasePart")
end

local function setPartTransparency(part, t)
    if not originalTransparency[part] then
        originalTransparency[part] = part.Transparency
    end
    part.Transparency = t
end

local function applyXRay(root)
    if shouldIgnore(root) then return end
    if isBrainrot(root) then return end
    if root:IsA("BasePart") then
        setPartTransparency(root, XRAY_TRANSPARENCY)
    end
    for _,ch in ipairs(root:GetChildren()) do
        applyXRay(ch)
    end
end

local function restoreXRay(root)
    if root:IsA("BasePart") and originalTransparency[root] ~= nil then
        root.Transparency = originalTransparency[root]
        originalTransparency[root] = nil
    end
    for _,ch in ipairs(root:GetChildren()) do
        restoreXRay(ch)
    end
end

local function enableXRay()
    xrayEnabled = true
    applyXRay(workspace)
end

local function disableXRay()
    xrayEnabled = false
    restoreXRay(workspace)
end

-- Mantener X-Ray cuando aparezcan nuevas partes
workspace.DescendantAdded:Connect(function(inst)
    if not xrayEnabled then return end
    if shouldIgnore(inst) or isBrainrot(inst) then return end
    if inst:IsA("BasePart") then
        setPartTransparency(inst, XRAY_TRANSPARENCY)
    end
end)

-- =======================
-- Ghost del jugador (70% translucidez)
-- =======================
local ghostEnabled = false
local function setCharacterTransparency(char, t)
    for _,desc in ipairs(char:GetDescendants()) do
        if desc:IsA("BasePart") or desc:IsA("Decal") then
            desc.Transparency = t
        elseif desc:IsA("Accessory") then
            local handle = desc:FindFirstChild("Handle")
            if handle and handle:IsA("BasePart") then
                handle.Transparency = t
            end
        end
    end
end

local function applyGhost()
    ghostEnabled = true
    local char = player.Character
    if char then setCharacterTransparency(char, 0.7) end
end

local function removeGhost()
    ghostEnabled = false
    local char = player.Character
    if char then setCharacterTransparency(char, 0) end
end

-- Reaplicar ghost tras respawn
player.CharacterAdded:Connect(function(char)
    task.wait(0.1)
    if ghostEnabled then setCharacterTransparency(char, 0.7) end
end)

-- =======================
-- GUI
-- =======================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ESPPanelPlus"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.new(0,220,0,260)
main.Position = UDim2.new(1,-230,0,10)
main.BackgroundColor3 = Color3.fromRGB(28,28,28)
main.Active = true
main.Draggable = true
main.Parent = screenGui
do local c=Instance.new("UICorner") c.CornerRadius=UDim.new(0,8) c.Parent=main end

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1,0,0,30)
title.BackgroundColor3 = Color3.fromRGB(45,45,45)
title.Text = "ESP LITE+"
title.TextColor3 = Color3.new(1,1,1)
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.Parent = main
do local c=Instance.new("UICorner") c.CornerRadius=UDim.new(0,8) c.Parent=title end

local function btn(y, text, color)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1,-20,0,32)
    b.Position = UDim2.new(0,10,0,y)
    b.BackgroundColor3 = color or Color3.fromRGB(255,60,60)
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
local notifEnabled=true

local espBtn    = btn(40,  "ESP: OFF")
local contBtn   = btn(80,  "Búsqueda Continua: ON", Color3.fromRGB(60,200,60))
local notifBtn  = btn(120, "Notificaciones: ON",    Color3.fromRGB(60,200,60))
local pEspBtn   = btn(160, "ESP Player: OFF")
local xrayBtn   = btn(200, "X-RAY MAP: OFF")
-- fila extra
main.Size = UDim2.new(0,220,0,300)
local ghostBtn  = btn(240, "GHOST (Yo): OFF")

-- Botones
espBtn.MouseButton1Click:Connect(function()
    espEnabled = not espEnabled
    if espEnabled then
        espBtn.Text = "ESP: ON"
        espBtn.BackgroundColor3 = Color3.fromRGB(60,200,60)
        startFullScan()
        toast("ESP activado (15s por brainrot)")
    else
        espBtn.Text = "ESP: OFF"
        espBtn.BackgroundColor3 = Color3.fromRGB(255,60,60)
        for inst,data in pairs(activeMarks) do
            safeDestroy(data.hl)
            activeMarks[inst]=nil
        end
        toast("ESP desactivado")
    end
end)

contBtn.MouseButton1Click:Connect(function()
    contEnabled = not contEnabled
    contBtn.Text = contEnabled and "Búsqueda Continua: ON" or "Búsqueda Continua: OFF"
    contBtn.BackgroundColor3 = contEnabled and Color3.fromRGB(60,200,60) or Color3.fromRGB(255,60,60)
end)

notifBtn.MouseButton1Click:Connect(function()
    notifEnabled = not notifEnabled
    notifBtn.Text = notifEnabled and "Notificaciones: ON" or "Notificaciones: OFF"
    notifBtn.BackgroundColor3 = notifEnabled and Color3.fromRGB(60,200,60) or Color3.fromRGB(255,60,60)
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

xrayBtn.MouseButton1Click:Connect(function()
    xrayEnabled = not xrayEnabled
    if xrayEnabled then
        xrayBtn.Text = "X-RAY MAP: ON"
        xrayBtn.BackgroundColor3 = Color3.fromRGB(60,200,60)
        enableXRay()
    else
        xrayBtn.Text = "X-RAY MAP: OFF"
        xrayBtn.BackgroundColor3 = Color3.fromRGB(255,60,60)
        disableXRay()
    end
end)

ghostBtn.MouseButton1Click:Connect(function()
    if ghostEnabled then
        ghostBtn.Text = "GHOST (Yo): OFF"
        ghostBtn.BackgroundColor3 = Color3.fromRGB(255,60,60)
        removeGhost()
    else
        ghostBtn.Text = "GHOST (Yo): ON"
        ghostBtn.BackgroundColor3 = Color3.fromRGB(60,200,60)
        applyGhost()
    end
end)

-- Eventos jugadores (notificaciones y ESP player)
Players.PlayerAdded:Connect(function(p)
    if notifEnabled then
        playNotificationSound()
        toast("🚨 "..p.Name.." se unió")
    end
    if playerESPEnabled then
        local function onChar() task.wait(0.2)
            local d = playerESPData[p.UserId]
            if d then safeDestroy(d.hl) releaseLine(d.line) playerESPData[p.UserId]=nil end
            createPlayerESP(p)
        end
        if p.Character then onChar() end
        p.CharacterAdded:Connect(onChar)
    end
end)

Players.PlayerRemoving:Connect(function(p)
    local d = playerESPData[p.UserId]
    if d then safeDestroy(d.hl) releaseLine(d.line) playerESPData[p.UserId]=nil end
end)

for _,p in ipairs(Players:GetPlayers()) do
    if p~=player then
        p.CharacterAdded:Connect(function()
            if playerESPEnabled then
                task.wait(0.2)
                local d = playerESPData[p.UserId]
                if d then safeDestroy(d.hl) releaseLine(d.line) playerESPData[p.UserId]=nil end
                createPlayerESP(p)
            end
        end)
    end
end

-- Loop principal
local lastContScan = 0
RunService.Heartbeat:Connect(function()
    rainbowHue = (rainbowHue + 0.02) % 1

    -- Escaneo + highlights de brainrots
    if espEnabled then
        processScanStep()     -- BFS incremental
        updateColors()        -- arcoíris
        cleanupExpired()      -- 15s de duración

        if contEnabled then
            local now = time()
            if now - lastContScan >= CONT_SCAN_PERIOD and qempty() then
                lastContScan = now
                qpush(workspace) -- por seguridad, reexplora si la cola está vacía
            end
        end
    end

    -- Player ESP
    if playerESPEnabled then
        updatePlayerESPLines()
    end
end)

print("✅ ESP LITE+ cargado (Highlight, notifs, X-Ray 80%, Ghost 70%)")
