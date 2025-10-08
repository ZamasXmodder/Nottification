--// =========================
--//  ESP LITE+ SECURE v1.6.0
--//  Brainrots ESP (15s, sin límite) + Notifs + ESP Player PRO
--//  X-Ray (LTM, no revive invisibles, excluye brainrots) + Ghost + Reset + Unload
--//  GUI mejorada (layout limpio, switches) + Modo Noche
--// =========================

-- ===== Seguridad / Anti doble ejecución =====
local G = getgenv and getgenv() or _G
G.BRAINROT_ESP_VERSION = "1.6.0-secure"
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

-- Conexiones manejables (para Unload)
local CONNECTIONS = {}
local function safeConnect(signal, fn)
    local c = signal:Connect(function(...)
        local ok = pcall(fn, ...)
        if not ok then end
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
    h.DepthMode           = Enum.HighlightDepthMode.AlwaysOnTop
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

-- Quitar LTM a brainrot detectado
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

-- Nuevos objetos
safeConnect(workspace.DescendantAdded, function(i)
    if xrayEnabled and i:IsA("BasePart") and not shouldIgnore(i) and not hasBrainrotAncestor(i) and not isBrainrotNode(i) then
        setLTM(i, XRAY_TRANSPARENCY)
    end
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
    f.Size = UDim2.new(0,320,0,80)
    f.Position = UDim2.new(0.5,-160,1,-90)
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
    TweenService:Create(f,TweenInfo.new(0.3, Enum.EasingStyle.Back),{Position=UDim2.new(0.5,-160,1,-90)}):Play()
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
    if l then l.Parent = workspace; return l end
    l = Instance.new("Part")
    l.Name = "PlayerESPLine"
    l.Anchored = true
    l.CanCollide = false
    l.Size = Vector3.new(0.25, 0.25, 1)
    l.Material = Enum.Material.ForceField
    l.Color = Color3.fromRGB(255, 0, 0)
    l.Transparency = 0.1
    l.Parent = workspace
    return l
end
local function freeLine(l) if l then l.Parent=nil table.insert(linePool,l) end end

local function makeBillboard(targetPlayer)
    local bb = Instance.new("BillboardGui")
    bb.Name = "ESPPlayerBillboard"
    bb.AlwaysOnTop = true
    bb.Size = UDim2.fromOffset(180, 42)
    bb.StudsOffsetWorldSpace = Vector3.new(0, 3.2, 0)
    bb.MaxDistance = 3000
    local holder = Instance.new("Frame"); holder.Name="Holder"; holder.BackgroundColor3 = Color3.fromRGB(25,25,25); holder.BackgroundTransparency=0.25; holder.Size = UDim2.fromScale(1,1); holder.Parent = bb
    local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0,6); corner.Parent = holder
    local label = Instance.new("TextLabel"); label.Name="Text"; label.BackgroundTransparency=1; label.Size=UDim2.fromScale(1,1); label.TextScaled=true; label.Font=Enum.Font.GothamBold; label.TextColor3=Color3.new(1,1,1); label.TextStrokeTransparency=0.3; label.TextXAlignment = Enum.TextXAlignment.Center; label.Text = targetPlayer.Name; label.Parent = holder
    return bb, label
end

local playerESPEnabled=false
-- uid -> {p, hl, line, bb, lbl}
local playerESPData={}
local lastPEspUpd = 0

local function newHighlightPlayer(char)
    local h = newHighlight(char); h.FillColor = Color3.new(1,0,0); return h
end

local function ensurePlayerESP(uid)
    local d = playerESPData[uid]
    if not d then return end
    if not isValid(d.hl) and d.p and d.p.Character then d.hl = newHighlightPlayer(d.p.Character) end
    if not isValid(d.line) then d.line = getLine() end
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
    local hl = newHighlightPlayer(char)
    local line = getLine()
    local bb, lbl = makeBillboard(p); bb.Adornee = hrp; bb.Parent = workspace
    playerESPData[p.UserId] = {p=p, hl=hl, line=line, bb=bb, lbl=lbl}
end

local function clearPlayerESP()
    for _,d in pairs(playerESPData) do safeDestroy(d.hl) freeLine(d.line) safeDestroy(d.bb) end
    table.clear(playerESPData)
end

local function updatePlayerESPLines()
    local now = time(); if now - lastPEspUpd < 1/PLAYER_LINE_FPS then return end; lastPEspUpd = now
    local myHRP = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart"); if not myHRP then return end
    local myPos = myHRP.Position
    local toRemove={}
    for uid,d in pairs(playerESPData) do
        local p=d.p; local char=p and p.Character; local hrp=char and char:FindFirstChild("HumanoidRootPart")
        if not (p and char and hrp) then table.insert(toRemove, uid)
        else
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
    for _,uid in ipairs(toRemove) do local d = playerESPData[uid]; if d then safeDestroy(d.hl) freeLine(d.line) safeDestroy(d.bb) playerESPData[uid]=nil end end
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

-- ===== THEME (Modo Noche) =====
local theme = {
    night = {
        mainBg   = Color3.fromRGB(20,20,22),
        headerBg = Color3.fromRGB(36,36,40),
        text     = Color3.fromRGB(235,235,245),
        muted    = Color3.fromRGB(170,170,180),
        switchOn = Color3.fromRGB(60,200,60),
        switchOff= Color3.fromRGB(90,90,95),
        btnReset = Color3.fromRGB(70,110,255),
        btnOff   = Color3.fromRGB(90,90,95),
        shadow   = 0.65,
    },
    day = {
        mainBg   = Color3.fromRGB(240,240,245),
        headerBg = Color3.fromRGB(220,220,230),
        text     = Color3.fromRGB(20,20,25),
        muted    = Color3.fromRGB(70,70,80),
        switchOn = Color3.fromRGB(60,170,250),
        switchOff= Color3.fromRGB(180,180,190),
        btnReset = Color3.fromRGB(255,120,80),
        btnOff   = Color3.fromRGB(180,180,190),
        shadow   = 0.35,
    }
}
local themeModeNight = true -- por defecto: modo noche

-- ===== GUI (layout limpio, nada se sale) =====
local gui = Instance.new("ScreenGui"); gui.Name="GUI_"..G.BRAINROT_ESP_NAME; gui.ResetOnSpawn=false; gui.Parent=playerGui

local main = Instance.new("Frame"); main.Size=UDim2.new(0,280,0,470); main.Position=UDim2.new(1,-290,0,10); main.Active=true; main.Draggable=true; main.Parent=gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0,12)

local header = Instance.new("Frame"); header.Size=UDim2.new(1,0,0,46); header.Parent=main; Instance.new("UICorner", header).CornerRadius=UDim.new(0,12)

local title = Instance.new("TextLabel")
title.BackgroundTransparency=1; title.Size=UDim2.new(1,-76,1,0); title.Position=UDim2.new(0,12,0,0)
title.Text="ESP LITE+ • "..G.BRAINROT_ESP_VERSION; title.Font=Enum.Font.GothamBold; title.TextScaled=true; title.Parent=header

local minimize = Instance.new("TextButton")
minimize.Size=UDim2.new(0,30,0,30); minimize.Position=UDim2.new(1,-36,0.5,-15); minimize.Text="–"
minimize.Font=Enum.Font.GothamBold; minimize.TextScaled=true; minimize.Parent=header
Instance.new("UICorner", minimize).CornerRadius = UDim.new(0,8)

local body = Instance.new("Frame"); body.Size=UDim2.new(1,-20,1,-86); body.Position=UDim2.new(0,10,0,60); body.Parent=main
local pad = Instance.new("UIPadding"); pad.PaddingTop=UDim.new(0,6); pad.PaddingBottom=UDim.new(0,6); pad.PaddingLeft=UDim.new(0,6); pad.PaddingRight=UDim.new(0,6); pad.Parent=body
local list = Instance.new("UIListLayout"); list.SortOrder=Enum.SortOrder.LayoutOrder; list.Padding = UDim.new(0,8); list.Parent=body

local status = Instance.new("TextLabel")
status.BackgroundTransparency=1; status.Size=UDim2.new(1,-20,0,22); status.Position=UDim2.new(0,10,1,-26)
status.Font=Enum.Font.Gotham; status.TextScaled=true; status.Parent=main

-- Switch helper alineado (label izquierda, toggle derecha)
local function makeSwitch(labelText, defaultOn, tipText)
    local row = Instance.new("Frame"); row.Size=UDim2.new(1,0,0, tipText and 62 or 44); row.LayoutOrder = 10; row.Parent=body
    local l = Instance.new("TextLabel"); l.BackgroundTransparency=1; l.Position=UDim2.new(0,0,0,0); l.Size=UDim2.new(1,-84,0,24)
    l.Font=Enum.Font.Gotham; l.TextScaled=true; l.TextXAlignment=Enum.TextXAlignment.Left; l.Text=labelText; l.Parent=row
    local tip
    if tipText then
        tip = Instance.new("TextLabel"); tip.BackgroundTransparency=1; tip.Position=UDim2.new(0,0,0,26); tip.Size=UDim2.new(1,-84,0,18)
        tip.Font=Enum.Font.Gotham; tip.TextScaled=false; tip.TextSize=12; tip.TextXAlignment=Enum.TextXAlignment.Left; tip.Text=tipText; tip.Parent=row
    end
    local switch = Instance.new("Frame"); switch.Size=UDim2.new(0,54,0,26); switch.Position=UDim2.new(1,-60,0,9); switch.Parent=row
    Instance.new("UICorner", switch).CornerRadius=UDim.new(1,0)
    local knob = Instance.new("Frame"); knob.Size=UDim2.new(0,22,0,22); knob.Position=UDim2.new(0,2,0,2); knob.Parent=switch
    Instance.new("UICorner", knob).CornerRadius=UDim.new(1,0)
    local btn = Instance.new("TextButton"); btn.BackgroundTransparency=1; btn.Size=UDim2.new(1,0,1,0); btn.Text=""; btn.Parent=switch

    local state = defaultOn
    local function setState(on)
        state = on
        TweenService:Create(switch, TweenInfo.new(0.16), {BackgroundColor3 = on and (themeModeNight and theme.night.switchOn or theme.day.switchOn) or (themeModeNight and theme.night.switchOff or theme.day.switchOff)}):Play()
        TweenService:Create(knob,   TweenInfo.new(0.16), {Position = on and UDim2.new(1,-24,0,2) or UDim2.new(0,2,0,2)}):Play()
    end
    setState(defaultOn)
    return {
        row=row, label=l, tip=tip, switch=switch, knob=knob, btn=btn,
        get=function() return state end,
        set=setState,
    }
end

-- Botón helper
local function makeButton(text, color, layoutOrder)
    local b = Instance.new("TextButton")
    b.Size=UDim2.new(1,0,0,40); b.LayoutOrder = layoutOrder or 100
    b.BackgroundColor3 = color; b.TextColor3 = Color3.new(1,1,1)
    b.TextScaled=true; b.Font=Enum.Font.GothamBold; b.Text=text; b.Parent=body
    Instance.new("UICorner", b).CornerRadius=UDim.new(0,8)
    return b
end

-- Switches
local swNight   = makeSwitch("Modo Noche", true, "Tema oscuro de alto contraste")
local swESP     = makeSwitch("ESP Brainrots", false, "Marca brainrots listados por 15s (sin límite)")
local swCont    = makeSwitch("Búsqueda continua", true, "Refuerza el escaneo (bajo costo)")
local swNotif   = makeSwitch("Notificaciones", true, "Alerta al entrar jugadores")
local swPlayer  = makeSwitch("ESP de jugadores", false, "Línea + nombre + distancia + highlight")
local swXRay    = makeSwitch("X-RAY del mapa (80%)", false, "Oculta mapa sin afectar brainrots")
local swGhost   = makeSwitch("Ghost (Yo 70%)", false, "Tu personaje más transparente")

local btnReset  = makeButton("RESET ESP", theme.night.btnReset, 200)
local btnUnload = makeButton("UNLOAD", theme.night.btnOff, 201)

-- Min/Max
local collapsed=false
minimize.MouseButton1Click:Connect(function()
    collapsed = not collapsed
    if collapsed then
        TweenService:Create(main, TweenInfo.new(0.22), {Size=UDim2.new(0,280,0,86)}):Play()
        body.Visible=false; status.Visible=false; minimize.Text="+"
    else
        TweenService:Create(main, TweenInfo.new(0.22), {Size=UDim2.new(0,280,0,470)}):Play()
        task.wait(0.22); body.Visible=true; status.Visible=true; minimize.Text="–"
    end
end)

-- ===== Theme apply =====
local function applyTheme()
    local t = themeModeNight and theme.night or theme.day
    main.BackgroundColor3   = t.mainBg
    header.BackgroundColor3 = t.headerBg
    title.TextColor3        = t.text
    minimize.TextColor3     = t.text
    status.TextColor3       = t.muted
    -- switches
    local sws = {swNight,swESP,swCont,swNotif,swPlayer,swXRay,swGhost}
    for _,s in ipairs(sws) do
        if s.label then s.label.TextColor3 = t.text end
        if s.tip   then s.tip.TextColor3   = t.muted end
        s.set(s.get())
        s.knob.BackgroundColor3 = Color3.new(1,1,1)
    end
    -- buttons
    btnReset.BackgroundColor3 = t.btnReset
    btnUnload.BackgroundColor3= t.btnOff
end
applyTheme()

-- ===== Estado toggles =====
local espEnabled      = false
local contEnabled     = true
local notifEnabled    = true
local playerESPEnabled= false

-- ===== Lógica switches =====
swNight.btn.MouseButton1Click:Connect(function()
    themeModeNight = not themeModeNight
    -- re-aplicar tema
    applyTheme()
end)

swESP.btn.MouseButton1Click:Connect(function()
    espEnabled = not espEnabled
    swESP.set(espEnabled)
    if espEnabled then startScan(); toast("ESP activado (15s)")
    else for inst,data in pairs(activeMarks) do safeDestroy(data.hl); activeMarks[inst]=nil end; toast("ESP desactivado") end
end)

swCont.btn.MouseButton1Click:Connect(function()
    contEnabled = not contEnabled
    swCont.set(contEnabled)
end)

swNotif.btn.MouseButton1Click:Connect(function()
    notifEnabled = not notifEnabled
    swNotif.set(notifEnabled)
end)

swPlayer.btn.MouseButton1Click:Connect(function()
    playerESPEnabled = not playerESPEnabled
    swPlayer.set(playerESPEnabled)
    if playerESPEnabled then for _,p in ipairs(Players:GetPlayers()) do if p~=LP then createPlayerESP(p) end end
    else clearPlayerESP() end
end)

swXRay.btn.MouseButton1Click:Connect(function()
    xrayEnabled = not xrayEnabled
    swXRay.set(xrayEnabled)
    if xrayEnabled then enableXRay() else disableXRay() end
end)

swGhost.btn.MouseButton1Click:Connect(function()
    if ghostEnabled then ghostOff() else ghostOn() end
    swGhost.set(ghostEnabled)
end)

-- Reset / Unload
local function RESET_ESP()
    for inst,data in pairs(activeMarks) do safeDestroy(data.hl) activeMarks[inst]=nil end
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
    p.CharacterAdded:Connect(function()
        if playerESPEnabled then
            task.wait(0.2)
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

    if playerESPEnabled then updatePlayerESPLines() end

    -- status
    local cB, cP = 0, 0
    for _ in pairs(activeMarks) do cB+=1 end
    for _ in pairs(playerESPData) do cP+=1 end
    status.Text = string.format("Brainrots activos: %d  |  Players ESP: %d", cB, cP)
end)
