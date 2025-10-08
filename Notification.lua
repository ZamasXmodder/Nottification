--// =========================
--//  ESP LITE+ SECURE v1.5.0
--//  Brainrots ESP (15s, sin límite, sólo nuevos) + Notifs + ESP Player PRO
--//  X-Ray (LTM, no revive invisibles, excluye brainrots) + Ghost + Reset + Unload
--//  Robusto: anti-doble ejecución, pcall/safeConnect, BFS incremental, GUI mejorada
--// =========================

-- ===== Seguridad / Anti doble ejecución =====
local G = getgenv and getgenv() or _G
G.BRAINROT_ESP_VERSION = "1.5.0-secure"
G.BRAINROT_ESP_NAME    = "ESP_LITE_PLUS_SECURE"

if G.__BRAINROT_ESP_RUNNING then return end
G.__BRAINROT_ESP_RUNNING = true

-- ===== Esperar entorno listo =====
local function waitForGameLoaded()
    if not game or not game.IsLoaded then return end
    if not game:IsLoaded() then repeat task.wait() until game:IsLoaded() end
end
waitForGameLoaded()

local function safeService(name)
    local ok, svc = pcall(game.GetService, game, name)
    return ok and svc or nil
end

local Players      = safeService("Players")
local RunService   = safeService("RunService")
local TweenService = safeService("TweenService")
local StarterGui   = safeService("StarterGui")

if not (Players and RunService and TweenService) then
    G.__BRAINROT_ESP_RUNNING = false
    return
end

local LP = Players.LocalPlayer
if not LP then repeat task.wait() until Players.LocalPlayer; LP = Players.LocalPlayer end

local playerGui = LP:FindFirstChildOfClass("PlayerGui") or LP:WaitForChild("PlayerGui", 10)
if not playerGui then G.__BRAINROT_ESP_RUNNING = false; return end

-- ===== Helpers seguros =====
local function isInstance(x) return typeof(x) == "Instance" end
local function isValid(inst) return isInstance(inst) and inst.Parent ~= nil and inst:IsDescendantOf(game) end
local function safeDestroy(x) if isInstance(x) and x.Destroy then pcall(function() x:Destroy() end) end end
local function hsv(h) return Color3.fromHSV(h,1,1) end
local function try(fn, ...) local ok, r = pcall(fn, ...); return ok, r end

-- Conexiones manejables (para Unload)
local CONNECTIONS = {}
local function safeConnect(signal, fn)
    local c = signal:Connect(function(...)
        local ok = pcall(fn, ...)
        if not ok then end -- silencioso
    end)
    table.insert(CONNECTIONS, c)
    return c
end
local function disconnectAll()
    for _,c in ipairs(CONNECTIONS) do pcall(function() c:Disconnect() end) end
    table.clear(CONNECTIONS)
end

-- ===== Parámetros =====
local MARK_DURATION     = 15
local RAINBOW_SPEED     = 0.35
local SCAN_STEP_BUDGET  = 1200
local CONT_SCAN_PERIOD  = 2
local PLAYER_LINE_FPS   = 30
local XRAY_TRANSPARENCY = 0.8

-- ===== Targets =====
local targetNames = {
    "La Secret Combinasion","Burguro And Fryuro","Los 67","Chillin Chili","Tang Tang Kelentang",
    "Money Money Puggy","Los Primos","Los Tacoritas","La Grande Combinasion","Pot Hotspot",
    "Mariachi Corazoni","Secret Lucky Block","To to to Sahur","Strawberry Elephant",
    "Ketchuru and Musturu","La Extinct Grande","Tictac Sahur","Tacorita Bicicleta",
    "Chicleteira Bicicleteira","Spaghetti Tualetti","Esok Sekolah","Los Chicleteiras","67",
    "Los Combinasionas","Nuclearo Dinosauro","Las Sis","Los Hotspotsitos","Tralaledon",
    "Ketupat Kepat","Los Bros","La Supreme Combinasion","Ketchuru and Masturu",
    "Garama and Madundung","Dragon Cannelloni","Celularcini Viciosini"
}
local targetSet = {} for _,n in ipairs(targetNames) do targetSet[n]=true end

-- ===== Estado ESP Brainrots =====
local rainbowHue  = 0
local everMarked  = setmetatable({}, {__mode="k"})   -- instancia ya marcada (no remarcar)
local activeMarks = setmetatable({}, {__mode="k"})   -- inst -> {hl, createdAt, baseHue}

-- Raíces de brainrots (para X-Ray exclusion por ancestro)
local brainrotRoots = setmetatable({}, {__mode="k"})
local function addBrainrotRoot(root) brainrotRoots[root] = true end
local function hasBrainrotAncestor(obj)
    local cur = obj
    for _=1,32 do
        if not cur or not isValid(cur) then return false end
        if brainrotRoots[cur] then return true end
        cur = cur.Parent
    end
    return false
end
local function cleanupBrainrotRoots()
    for root,_ in pairs(brainrotRoots) do
        if not isValid(root) then brainrotRoots[root] = nil end
    end
end

-- Highlight helper
local function newHighlight(target)
    local h = Instance.new("Highlight")
    h.Adornee = target
    h.FillTransparency    = 0.45
    h.OutlineTransparency = 0.15
    h.OutlineColor        = Color3.new(1,1,1)
    h.DepthMode           = Enum.HighlightDepthMode.AlwaysOnTop -- atraviesa paredes
    h.Parent = workspace
    return h
end

-- ===== X-RAY (LTM) =====
local xrayEnabled = false
local originalLTM = setmetatable({}, {__mode="k"})
local function shouldIgnore(i) return i:IsDescendantOf(playerGui) or i:IsDescendantOf(Players) end
local function isBrainrotNode(i) return targetSet[i.Name] and (i:IsA("Model") or i:IsA("BasePart")) end
local function setLTM(p, v)
    if originalLTM[p] == nil then originalLTM[p] = p.LocalTransparencyModifier end
    p.LocalTransparencyModifier = math.max(p.LocalTransparencyModifier, v)
end
local function applyXRay(node)
    if shouldIgnore(node) then return end
    if hasBrainrotAncestor(node) then return end
    if isBrainrotNode(node) then return end
    if node:IsA("BasePart") then setLTM(node, XRAY_TRANSPARENCY) end
    for _,c in ipairs(node:GetChildren()) do applyXRay(c) end
end
local function restoreXRay(node)
    if node:IsA("BasePart") and originalLTM[node] ~= nil then
        node.LocalTransparencyModifier = originalLTM[node]
        originalLTM[node] = nil
    end
    for _,c in ipairs(node:GetChildren()) do restoreXRay(c) end
end
local function enableXRay() xrayEnabled = true;  applyXRay(workspace) end
local function disableXRay() xrayEnabled = false; restoreXRay(workspace) end

-- Cuando detectamos un brainrot, quitar cualquier LTM previo en todas sus partes
local function unXrayBrainrot(root)
    if not isValid(root) then return end
    local function restoreTree(n)
        if n:IsA("BasePart") and originalLTM[n] ~= nil then
            n.LocalTransparencyModifier = originalLTM[n]
            originalLTM[n] = nil
        end
        for _,c in ipairs(n:GetChildren()) do restoreTree(c) end
    end
    restoreTree(root)
end

-- ===== Detección/Marcado Brainrots =====
local function markOnce(inst)
    if not isValid(inst) or everMarked[inst] then return end
    if not (inst:IsA("Model") or inst:IsA("BasePart")) then return end
    if not targetSet[inst.Name] then return end

    everMarked[inst] = true
    addBrainrotRoot(inst)
    unXrayBrainrot(inst)

    local hl = newHighlight(inst)
    hl.FillColor = hsv(rainbowHue)
    activeMarks[inst] = {hl=hl, createdAt=time(), baseHue=rainbowHue}
end

-- BFS incremental
local scanQueue, qh, qt = {}, 1, 0
local function qpush(x) qt+=1; scanQueue[qt]=x end
local function qpop() if qh<=qt then local v=scanQueue[qh]; scanQueue[qh]=nil; qh+=1; return v end end
local function qempty() return qh>qt end
local function qreset() for i=qh,qt do scanQueue[i]=nil end qh,qt=1,0 end

local function processScanStep()
    local budget = SCAN_STEP_BUDGET
    while budget>0 do
        local node = qpop()
        if not node then break end
        if isValid(node) then
            if targetSet[node.Name] then markOnce(node) end
            local children = node:GetChildren()
            for _,ch in ipairs(children) do if isValid(ch) then qpush(ch) end end
        end
        budget-=1
    end
end

local function startScan() qreset(); qpush(workspace) end

-- Nuevos objetos en el mapa
safeConnect(workspace.DescendantAdded, function(i)
    -- X-Ray: no tocar descendientes de brainrots ni Players/UI
    if xrayEnabled and i:IsA("BasePart") and not shouldIgnore(i) and not hasBrainrotAncestor(i) and not isBrainrotNode(i) then
        setLTM(i, XRAY_TRANSPARENCY)
    end
    -- ESP: marcar si es brainrot válido
    if isBrainrotNode(i) and targetSet[i.Name] then
        markOnce(i)
    end
end)

-- Mantenimiento ESP
local function cleanupExpired()
    local now = time()
    for inst, data in pairs(activeMarks) do
        if (now - data.createdAt) >= MARK_DURATION or not isValid(inst) then
            safeDestroy(data.hl)
            activeMarks[inst] = nil
        end
    end
end
local function updateColors()
    for inst, data in pairs(activeMarks) do
        local hl = data.hl
        if isValid(hl) then
            local hue = (data.baseHue + (time()-data.createdAt)*RAINBOW_SPEED)%1
            hl.FillColor = hsv(hue)
        end
    end
end

-- ===== Notificaciones =====
local notifSound = Instance.new("Sound")
notifSound.SoundId = "rbxassetid://77665577458181"
notifSound.Volume  = 0.7
notifSound.Parent  = playerGui
local function playNotificationSound() pcall(function() notifSound:Play() end) end
local function toast(msg)
    local gui = Instance.new("ScreenGui")
    gui.Name = "Toast_"..G.BRAINROT_ESP_NAME
    gui.Parent = playerGui
    local f = Instance.new("Frame")
    f.Size = UDim2.new(0,320,0,85)
    f.Position = UDim2.new(0.5,-160,1,-95)
    f.BackgroundColor3 = Color3.fromRGB(40,40,40)
    f.BorderSizePixel = 0
    f.Parent = gui
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0,10) c.Parent = f
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Size = UDim2.new(1,-20,1,-20)
    l.Position = UDim2.new(0,10,0,10)
    l.Text = msg
    l.TextScaled = true
    l.TextColor3 = Color3.new(1,1,1)
    l.Font = Enum.Font.Gotham
    l.Parent = f
    f.Position = UDim2.new(0.5,-160,1,0)
    TweenService:Create(f,TweenInfo.new(0.3, Enum.EasingStyle.Back),{Position=UDim2.new(0.5,-160,1,-95)}):Play()
    task.delay(3.0, function()
        local tw = TweenService:Create(f,TweenInfo.new(0.25),{Position=UDim2.new(0.5,-160,1,0)})
        tw:Play()
        tw.Completed:Once(function() safeDestroy(gui) end)
    end)
end

-- ===== Player ESP PRO =====
local linePool = {}
local function getLine()
    local l = table.remove(linePool)
    if l then 
        l.Parent = workspace
        return l 
    end
    l = Instance.new("Part")
    l.Name = "PlayerESPLine"
    l.Anchored = true
    l.CanCollide = false
    l.Size = Vector3.new(0.25, 0.25, 1)     -- más gruesa
    l.Material = Enum.Material.ForceField   -- brillante/visible a través
    l.Color = Color3.fromRGB(255, 0, 0)     -- rojo intenso
    l.Transparency = 0.1                    -- glow
    l.Parent = workspace
    return l
end
local function freeLine(l) if l then l.Parent=nil table.insert(linePool,l) end end

local function makeBillboard(targetPlayer)
    local bb = Instance.new("BillboardGui")
    bb.Name = "ESPPlayerBillboard"
    bb.AlwaysOnTop = true
    bb.Size = UDim2.fromOffset(200, 50)
    bb.StudsOffsetWorldSpace = Vector3.new(0, 3.2, 0)
    bb.MaxDistance = 3000
    local holder = Instance.new("Frame")
    holder.Name = "Holder"
    holder.BackgroundColor3 = Color3.fromRGB(25,25,25)
    holder.BackgroundTransparency = 0.25
    holder.Size = UDim2.fromScale(1,1)
    holder.Parent = bb
    local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0,6); corner.Parent = holder
    local label = Instance.new("TextLabel")
    label.Name = "Text"
    label.BackgroundTransparency = 1
    label.Size = UDim2.fromScale(1,1)
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.TextColor3 = Color3.new(1,1,1)
    label.TextStrokeTransparency = 0.3
    label.Text = targetPlayer.Name
    label.Parent = holder
    return bb, label
end

local playerESPEnabled=false
-- uid -> {p, hl, line, bb, lbl}
local playerESPData={}

local lastPEspUpd = 0
local function ensurePlayerESP(uid)
    local d = playerESPData[uid]
    if not d then return end
    if not isValid(d.hl) and d.p and d.p.Character then
        local hl = newHighlight(d.p.Character); hl.FillColor=Color3.new(1,0,0)
        d.hl = hl
    end
    if not isValid(d.line) then
        d.line = getLine()
    end
    if not (isValid(d.bb) and isValid(d.lbl)) then
        local bb, lbl = makeBillboard(d.p)
        local hrp = d.p.Character and d.p.Character:FindFirstChild("HumanoidRootPart")
        if hrp then bb.Adornee = hrp end
        bb.Parent = workspace
        d.bb, d.lbl = bb, lbl
    end
end

local function createPlayerESP(p)
    if p==LP or playerESPData[p.UserId] then return end
    local char=p.Character if not char then return end
    local hrp=char:FindFirstChild("HumanoidRootPart") if not hrp then return end
    local hl = newHighlight(char); hl.FillColor=Color3.new(1,0,0)
    local line = getLine()
    local bb, lbl = makeBillboard(p)
    bb.Adornee = hrp
    bb.Parent = workspace
    playerESPData[p.UserId] = {p=p, hl=hl, line=line, bb=bb, lbl=lbl}
end

local function clearPlayerESP()
    for _,d in pairs(playerESPData) do
        safeDestroy(d.hl)
        freeLine(d.line)
        safeDestroy(d.bb)
    end
    table.clear(playerESPData)
end

local function updatePlayerESPLines()
    local now = time()
    if now - lastPEspUpd < 1/PLAYER_LINE_FPS then return end
    lastPEspUpd = now
    local myHRP = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if not myHRP then return end
    local myPos = myHRP.Position
    local toRemove={}
    for uid,d in pairs(playerESPData) do
        local p=d.p; local char=p and p.Character; local hrp=char and char:FindFirstChild("HumanoidRootPart")
        if not (p and char and hrp) then
            table.insert(toRemove, uid)
        else
            -- Asegurar componentes si se perdieron por cualquier motivo
            ensurePlayerESP(uid)

            if isValid(d.line) then
                local tpos = hrp.Position
                local dir  = tpos - myPos
                local dist = dir.Magnitude
                d.line.Size   = Vector3.new(0.25, 0.25, dist)
                d.line.CFrame = CFrame.lookAt(myPos + dir*0.5, tpos)
                if isValid(d.bb) and isValid(d.lbl) then
                    if d.bb.Adornee ~= hrp then d.bb.Adornee = hrp end
                    d.lbl.Text = string.format("%s  •  %dst", p.Name, dist and math.floor(dist) or 0)
                end
            end
        end
    end
    for _,uid in ipairs(toRemove) do
        local d = playerESPData[uid]
        if d then safeDestroy(d.hl) freeLine(d.line) safeDestroy(d.bb) playerESPData[uid]=nil end
    end
end

-- ===== Ghost (70%) =====
local ghostEnabled=false
local function setCharTransp(char,t)
    for _,d in ipairs(char:GetDescendants()) do
        if d:IsA("BasePart") or d:IsA("Decal") then d.Transparency=t end
        if d:IsA("Accessory") then local h=d:FindFirstChild("Handle") if h then h.Transparency=t end end
    end
end
local function ghostOn()  ghostEnabled=true;  if LP.Character then setCharTransp(LP.Character,0.7) end end
local function ghostOff() ghostEnabled=false; if LP.Character then setCharTransp(LP.Character,0.0) end end
safeConnect(LP.CharacterAdded, function(c) task.wait(0.2); if ghostEnabled then setCharTransp(c,0.7) end end)

-- ===== GUI Mejorada =====
local gui = Instance.new("ScreenGui")
gui.Name = "GUI_"..G.BRAINROT_ESP_NAME
gui.ResetOnSpawn = false
gui.Parent = playerGui

local main = Instance.new("Frame")
main.Size = UDim2.new(0,260,0,420)
main.Position = UDim2.new(1,-270,0,10)
main.BackgroundColor3 = Color3.fromRGB(26,26,28)
main.Active = true
main.Draggable = true
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0,12)

local shadow = Instance.new("ImageLabel")
shadow.Name = "Shadow"
shadow.BackgroundTransparency = 1
shadow.Image = "rbxassetid://5028857084"
shadow.ImageColor3 = Color3.fromRGB(0,0,0)
shadow.ImageTransparency = 0.6
shadow.ScaleType = Enum.ScaleType.Slice
shadow.SliceCenter = Rect.new(24,24,276,276)
shadow.Size = UDim2.new(1,20,1,20)
shadow.Position = UDim2.new(0,-10,0,-10)
shadow.Parent = main

local header = Instance.new("Frame")
header.Size = UDim2.new(1,0,0,40)
header.BackgroundColor3 = Color3.fromRGB(40,40,44)
header.Parent = main
Instance.new("UICorner", header).CornerRadius = UDim.new(0,12)

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Size = UDim2.new(1,-80,1,0)
title.Position = UDim2.new(0,12,0,0)
title.Text = "ESP LITE+ • "..G.BRAINROT_ESP_VERSION
title.TextColor3 = Color3.fromRGB(235,235,245)
title.Font = Enum.Font.GothamBold
title.TextScaled = true
title.Parent = header

local minimize = Instance.new("TextButton")
minimize.Size = UDim2.new(0,28,0,28)
minimize.Position = UDim2.new(1,-36,0.5,-14)
minimize.Text = "–"
minimize.Font = Enum.Font.GothamBold
minimize.TextScaled = true
minimize.TextColor3 = Color3.new(1,1,1)
minimize.BackgroundColor3 = Color3.fromRGB(60,60,64)
minimize.Parent = header
Instance.new("UICorner", minimize).CornerRadius = UDim.new(0,8)

local body = Instance.new("Frame")
body.Size = UDim2.new(1,-20,1,-60)
body.Position = UDim2.new(0,10,0,50)
body.BackgroundTransparency = 1
body.Parent = main

local status = Instance.new("TextLabel")
status.BackgroundTransparency = 1
status.Size = UDim2.new(1,0,0,24)
status.Position = UDim2.new(0,0,1,-26)
status.TextColor3 = Color3.fromRGB(170,170,180)
status.Font = Enum.Font.Gotham
status.TextScaled = true
status.Text = "Brainrots activos: 0  |  Players ESP: 0"
status.Parent = main

local collapsed = false
minimize.MouseButton1Click:Connect(function()
    collapsed = not collapsed
    if collapsed then
        TweenService:Create(main, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {Size = UDim2.new(0,260,0,80)}):Play()
        body.Visible = false
        status.Visible = false
        minimize.Text = "+"
    else
        TweenService:Create(main, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {Size = UDim2.new(0,260,0,420)}):Play()
        task.wait(0.25)
        body.Visible = true
        status.Visible = true
        minimize.Text = "–"
    end
end)

-- Switch helper (visual tipo toggle)
local function makeSwitch(y, labelText, defaultOn, tipText)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1,0,0,40)
    row.Position = UDim2.new(0,0,0,y)
    row.BackgroundTransparency = 1
    row.Parent = body

    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Size = UDim2.new(1,-80,1,0)
    l.Position = UDim2.new(0,0,0,0)
    l.Text = labelText
    l.TextColor3 = Color3.fromRGB(230,230,235)
    l.Font = Enum.Font.Gotham
    l.TextScaled = true
    l.Parent = row

    if tipText then
        l.Text = labelText .. "  "
        local tip = Instance.new("TextLabel")
        tip.BackgroundTransparency = 1
        tip.Size = UDim2.new(1,-80,1,0)
        tip.Position = UDim2.new(0,0,0,20)
        tip.Text = tipText
        tip.TextColor3 = Color3.fromRGB(150,150,160)
        tip.Font = Enum.Font.Gotham
        tip.TextScaled = false
        tip.TextSize = 12
        tip.TextXAlignment = Enum.TextXAlignment.Left
        tip.Parent = row
        row.Size = UDim2.new(1,0,0,50)
    end

    local switch = Instance.new("Frame")
    switch.Size = UDim2.new(0,54,0,26)
    switch.Position = UDim2.new(1,-60,0.5,-13)
    switch.BackgroundColor3 = defaultOn and Color3.fromRGB(60,200,60) or Color3.fromRGB(90,90,95)
    switch.Parent = row
    Instance.new("UICorner", switch).CornerRadius = UDim.new(1,0)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0,22,0,22)
    knob.Position = defaultOn and UDim2.new(1,-24,0.5,-11) or UDim2.new(0,2,0.5,-11)
    knob.BackgroundColor3 = Color3.fromRGB(255,255,255)
    knob.Parent = switch
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1,0)

    local btn = Instance.new("TextButton")
    btn.BackgroundTransparency = 1
    btn.Size = UDim2.new(1,0,1,0)
    btn.Text = ""
    btn.Parent = switch

    local state = defaultOn
    local function setState(on)
        state = on
        TweenService:Create(switch, TweenInfo.new(0.18), {BackgroundColor3 = on and Color3.fromRGB(60,200,60) or Color3.fromRGB(90,90,95)}):Play()
        TweenService:Create(knob, TweenInfo.new(0.18), {Position = on and UDim2.new(1,-24,0.5,-11) or UDim2.new(0,2,0.5,-11)}):Play()
    end
    setState(defaultOn)

    return {
        row = row,
        set = setState,
        get = function() return state end,
        button = btn,
    }
end

-- Botones y switches
local swESP      = makeSwitch(0,   "ESP Brainrots", false, "Marca brainrots listados por 15s (sin límite)")
local swCont     = makeSwitch(55,  "Búsqueda continua", true, "Refuerza el escaneo (bajo costo)")
local swNotif    = makeSwitch(110, "Notificaciones", true, "Alerta al entrar jugadores")
local swPlayer   = makeSwitch(165, "ESP de jugadores", false, "Línea + nombre + distancia + highlight")
local swXRay     = makeSwitch(220, "X-RAY del mapa (80%)", false, "Oculta mapa sin afectar brainrots")
local swGhost    = makeSwitch(275, "Ghost (Yo 70%)", false, "Tu personaje más transparente")

-- Botón Reset / Unload
local actions = Instance.new("Frame")
actions.Size = UDim2.new(1,0,0,40)
actions.Position = UDim2.new(0,0,0,330)
actions.BackgroundTransparency = 1
actions.Parent = body

local btnReset = Instance.new("TextButton")
btnReset.Size = UDim2.new(0.48, -5, 1, 0)
btnReset.Position = UDim2.new(0,0,0,0)
btnReset.BackgroundColor3 = Color3.fromRGB(70,110,255)
btnReset.TextColor3 = Color3.new(1,1,1)
btnReset.TextScaled = true
btnReset.Font = Enum.Font.GothamBold
btnReset.Text = "RESET ESP"
btnReset.Parent = actions
Instance.new("UICorner", btnReset).CornerRadius = UDim.new(0,8)

local btnUnload = Instance.new("TextButton")
btnUnload.Size = UDim2.new(0.48, -5, 1, 0)
btnUnload.Position = UDim2.new(1,-btnUnload.Size.X.Offset-5,0,0)
btnUnload.BackgroundColor3 = Color3.fromRGB(90,90,95)
btnUnload.TextColor3 = Color3.new(1,1,1)
btnUnload.TextScaled = true
btnUnload.Font = Enum.Font.GothamBold
btnUnload.Text = "UNLOAD"
btnUnload.Parent = actions
Instance.new("UICorner", btnUnload).CornerRadius = UDim.new(0,8)

-- ===== Estado toggles =====
local espEnabled  = false
local contEnabled = true
local notifEnabled= true
local playerESPEnabled = false

-- ===== Lógica switches =====
swESP.button.MouseButton1Click:Connect(function()
    espEnabled = not espEnabled
    swESP.set(espEnabled)
    if espEnabled then
        startScan()
        toast("ESP activado (15s)")
    else
        for inst,data in pairs(activeMarks) do safeDestroy(data.hl); activeMarks[inst]=nil end
        toast("ESP desactivado")
    end
end)

swCont.button.MouseButton1Click:Connect(function()
    contEnabled = not contEnabled
    swCont.set(contEnabled)
end)

swNotif.button.MouseButton1Click:Connect(function()
    notifEnabled = not notifEnabled
    swNotif.set(notifEnabled)
end)

swPlayer.button.MouseButton1Click:Connect(function()
    playerESPEnabled = not playerESPEnabled
    swPlayer.set(playerESPEnabled)
    if playerESPEnabled then
        for _,p in ipairs(Players:GetPlayers()) do if p~=LP then createPlayerESP(p) end end
    else
        clearPlayerESP()
    end
end)

swXRay.button.MouseButton1Click:Connect(function()
    xrayEnabled = not xrayEnabled
    swXRay.set(xrayEnabled)
    if xrayEnabled then enableXRay() else disableXRay() end
end)

swGhost.button.MouseButton1Click:Connect(function()
    if ghostEnabled then ghostOff() else ghostOn() end
    swGhost.set(ghostEnabled)
end)

-- ===== Reset / Unload =====
local function RESET_ESP()
    -- Mantiene estados de switches, solo limpia y reescanea
    for inst,data in pairs(activeMarks) do safeDestroy(data.hl) activeMarks[inst]=nil end
    -- no borramos everMarked ni brainrotRoots: queremos seguir “solo nuevos” por instancia
    -- si quieres full reset de memoria, descomenta:
    -- everMarked = setmetatable({}, {__mode="k"})
    -- brainrotRoots = setmetatable({}, {__mode="k"})
    if espEnabled then startScan() end
    toast("ESP reseteado")
end

local function UNLOAD()
    if xrayEnabled   then disableXRay() end
    if ghostEnabled  then ghostOff() end
    if playerESPEnabled then clearPlayerESP() end
    for inst,data in pairs(activeMarks) do safeDestroy(data.hl) activeMarks[inst]=nil end
    disconnectAll()
    safeDestroy(gui)
    G.__BRAINROT_ESP_RUNNING = false
    toast("ESP descargado")
end

btnReset.MouseButton1Click:Connect(RESET_ESP)
btnUnload.MouseButton1Click:Connect(UNLOAD)
G.BRAINROT_UNLOAD = UNLOAD

-- ===== Eventos jugadores =====
safeConnect(Players.PlayerAdded, function(p)
    if notifEnabled then playNotificationSound(); toast("🚨 "..p.Name.." se unió") end
    if playerESPEnabled then task.wait(0.25); createPlayerESP(p) end
    -- recrear ESP player al respawn si está ON
    p.CharacterAdded:Connect(function()
        if playerESPEnabled then task.wait(0.2)
            -- limpia y vuelve a crear para asegurar componentes
            local d = playerESPData[p.UserId]
            if d then safeDestroy(d.hl) freeLine(d.line) safeDestroy(d.bb) playerESPData[p.UserId]=nil end
            createPlayerESP(p)
        end
    end)
end)
safeConnect(Players.PlayerRemoving, function(p)
    local d = playerESPData[p.UserId]
    if d then safeDestroy(d.hl) freeLine(d.line) safeDestroy(d.bb) playerESPData[p.UserId]=nil end
end)
-- también aplicar a los que ya están
for _,p in ipairs(Players:GetPlayers()) do
    if p~=LP then
        p.CharacterAdded:Connect(function()
            if playerESPEnabled then task.wait(0.2)
                local d = playerESPData[p.UserId]
                if d then safeDestroy(d.hl) freeLine(d.line) safeDestroy(d.bb) playerESPData[p.UserId]=nil end
                createPlayerESP(p)
            end
        end)
    end
end

-- ===== Loop =====
local lastCont = 0
safeConnect(RunService.Heartbeat, function()
    rainbowHue = (rainbowHue + 0.02) % 1

    if espEnabled then
        processScanStep()
        updateColors()
        cleanupExpired()
        cleanupBrainrotRoots()
        if contEnabled and qempty() and time() - lastCont >= CONT_SCAN_PERIOD then
            lastCont = time()
            qpush(workspace)
        end
    end

    if playerESPEnabled then
        updatePlayerESPLines()
    end

    -- status live
    local countBrainrots = 0
    for _ in pairs(activeMarks) do countBrainrots+=1 end
    local countPlayers = 0
    for _ in pairs(playerESPData) do countPlayers+=1 end
    status.Text = string.format("Brainrots activos: %d  |  Players ESP: %d", countBrainrots, countPlayers)
end)
