--// =========================
--//  ESP LITE+ SECURE (Highlight 15s, Notifs, X-Ray LTM, Ghost, ESP Player, Unload)
--//  Repo/Loadstring-friendly, anti-doble ejecución, callbacks protegidos
--// =========================

-- ===== Seguridad básica / Anti doble ejecución =====
local G = getgenv and getgenv() or _G
G.BRAINROT_ESP_VERSION = "1.2.0-secure"
G.BRAINROT_ESP_NAME    = "ESP_LITE_PLUS_SECURE"

if G.__BRAINROT_ESP_RUNNING then
    -- Ya está corriendo una instancia, no lanzar otra
    return
end
G.__BRAINROT_ESP_RUNNING = true

-- ===== Esperar entorno listo =====
local function waitForGameLoaded()
    if not game or not game.IsLoaded then return end
    if not game:IsLoaded() then
        repeat task.wait() until game:IsLoaded()
    end
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
    warn("[ESP] Servicios faltantes. Abortando.")
    G.__BRAINROT_ESP_RUNNING = false
    return
end

local LP = Players.LocalPlayer
if not LP then
    -- Esperar LocalPlayer (entorno cliente)
    repeat task.wait() until Players.LocalPlayer
    LP = Players.LocalPlayer
end

local playerGui = LP:FindFirstChildOfClass("PlayerGui") or LP:WaitForChild("PlayerGui", 10)
if not playerGui then
    warn("[ESP] No se encontró PlayerGui. Abortando.")
    G.__BRAINROT_ESP_RUNNING = false
    return
end

-- ===== Helpers seguros =====
local function isInstance(x) return typeof(x) == "Instance" end
local function isValid(inst) return isInstance(inst) and inst.Parent ~= nil and inst:IsDescendantOf(game) end
local function safeDestroy(x) if isInstance(x) and x.Destroy then pcall(function() x:Destroy() end) end end
local function hsv(h) return Color3.fromHSV(h,1,1) end

-- Conexiones protegidas para poder “Unload”
local CONNECTIONS = {}
local function safeConnect(signal, fn)
    local conn = signal:Connect(function(...)
        local ok, err = pcall(fn, ...)
        if not ok then
            -- Silencioso para no spammear output
            -- warn("[ESP] Callback error: ", err)
        end
    end)
    table.insert(CONNECTIONS, conn)
    return conn
end
local function disconnectAll()
    for _,c in ipairs(CONNECTIONS) do
        pcall(function() c:Disconnect() end)
    end
    table.clear(CONNECTIONS)
end

-- ===== Parámetros =====
local MARK_DURATION     = 15      -- segundos por highlight
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
local targetSet = {}
for _,n in ipairs(targetNames) do targetSet[n]=true end

-- ===== Estado ESP Brainrots =====
local rainbowHue  = 0
local everMarked  = setmetatable({}, {__mode="k"})   -- no remarcar la misma instancia
local activeMarks = setmetatable({}, {__mode="k"})   -- inst -> {hl, createdAt, baseHue}

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

local function markOnce(inst)
    if not isValid(inst) or everMarked[inst] then return end
    if not (inst:IsA("Model") or inst:IsA("BasePart")) then return end
    if not targetSet[inst.Name] then return end
    everMarked[inst] = true
    local hl = newHighlight(inst)
    hl.FillColor = hsv(rainbowHue)
    activeMarks[inst] = {hl=hl, createdAt=time(), baseHue=rainbowHue}
end

-- ===== Escaneo incremental (BFS) + listener nuevos =====
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

local function startScan()
    qreset()
    qpush(workspace)
end

safeConnect(workspace.DescendantAdded, function(i)
    if targetSet[i.Name] and (i:IsA("Model") or i:IsA("BasePart")) then
        markOnce(i)
    end
end)

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
    task.delay(3.5, function()
        local tw = TweenService:Create(f,TweenInfo.new(0.3),{Position=UDim2.new(0.5,-160,1,0)})
        tw:Play()
        tw.Completed:Once(function() safeDestroy(gui) end)
    end)
end

-- ===== Player ESP =====
local linePool = {}
local function getLine()
    local l = table.remove(linePool)
    if l then l.Parent = workspace; return l end
    l = Instance.new("Part")
    l.Name = "PlayerESPLine"
    l.Anchored = true
    l.CanCollide = false
    l.Size = Vector3.new(0.08,0.08,1)
    l.Material = Enum.Material.Neon
    l.Color = Color3.fromRGB(255,64,64)
    l.Parent = workspace
    return l
end
local function freeLine(l) if l then l.Parent=nil table.insert(linePool,l) end end

local playerESPEnabled = false
local playerESPData = {} -- uid -> {p, hl, line}

local function createPlayerESP(p)
    if p == LP or playerESPData[p.UserId] then return end
    local char = p.Character
    if not char then return end
    local hrp  = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local hl = newHighlight(char)
    hl.FillColor = Color3.new(1,0,0)
    local line = getLine()
    playerESPData[p.UserId] = {p=p, hl=hl, line=line}
end

local function clearPlayerESP()
    for _,d in pairs(playerESPData) do
        safeDestroy(d.hl)
        freeLine(d.line)
    end
    table.clear(playerESPData)
end

local lastPEspUpd = 0
local function updatePlayerESPLines()
    local now = time()
    if now - lastPEspUpd < 1/PLAYER_LINE_FPS then return end
    lastPEspUpd = now

    local myHRP = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if not myHRP then return end
    local myPos = myHRP.Position

    local toRemove = {}
    for uid, d in pairs(playerESPData) do
        local p = d.p
        local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
        if not (p and hrp and isValid(d.hl) and isValid(d.line)) then
            table.insert(toRemove, uid)
        else
            local tp  = hrp.Position
            local dir = tp - myPos
            d.line.Size   = Vector3.new(0.08,0.08,dir.Magnitude)
            d.line.CFrame = CFrame.lookAt(myPos + dir*0.5, tp)
        end
    end
    for _,uid in ipairs(toRemove) do
        local d = playerESPData[uid]
        if d then safeDestroy(d.hl) freeLine(d.line) playerESPData[uid] = nil end
    end
end

-- ===== X-RAY (LocalTransparencyModifier, no “revivir” invisibles) =====
local xrayEnabled = false
local originalLTM = setmetatable({}, {__mode="k"})

local function shouldIgnore(i)
    return i:IsDescendantOf(playerGui) or i:IsDescendantOf(Players)
end
local function isBrainrot(i)
    return targetSet[i.Name] and (i:IsA("Model") or i:IsA("BasePart"))
end
local function setLTM(p, v)
    if originalLTM[p] == nil then originalLTM[p] = p.LocalTransparencyModifier end
    p.LocalTransparencyModifier = math.max(p.LocalTransparencyModifier, v)
end
local function applyXRay(n)
    if shouldIgnore(n) or isBrainrot(n) then return end
    if n:IsA("BasePart") then setLTM(n, XRAY_TRANSPARENCY) end
    for _,c in ipairs(n:GetChildren()) do applyXRay(c) end
end
local function restoreXRay(n)
    if n:IsA("BasePart") and originalLTM[n] ~= nil then
        n.LocalTransparencyModifier = originalLTM[n]
        originalLTM[n] = nil
    end
    for _,c in ipairs(n:GetChildren()) do restoreXRay(c) end
end
local function enableXRay() xrayEnabled = true;  applyXRay(workspace) end
local function disableXRay() xrayEnabled = false; restoreXRay(workspace) end

safeConnect(workspace.DescendantAdded, function(i)
    if xrayEnabled and not shouldIgnore(i) and not isBrainrot(i) and i:IsA("BasePart") then
        setLTM(i, XRAY_TRANSPARENCY)
    end
end)

-- ===== Ghost (70%) =====
local ghostEnabled = false
local function setCharTransp(char, t)
    for _,d in ipairs(char:GetDescendants()) do
        if d:IsA("BasePart") or d:IsA("Decal") then d.Transparency = t end
        if d:IsA("Accessory") then local h = d:FindFirstChild("Handle") if h then h.Transparency = t end end
    end
end
local function ghostOn()  ghostEnabled = true;  if LP.Character then setCharTransp(LP.Character, 0.7) end end
local function ghostOff() ghostEnabled = false; if LP.Character then setCharTransp(LP.Character, 0.0) end end

safeConnect(LP.CharacterAdded, function(c)
    task.wait(0.2)
    if ghostEnabled then setCharTransp(c, 0.7) end
end)

-- ===== GUI =====
local gui = Instance.new("ScreenGui")
gui.Name = "GUI_"..G.BRAINROT_ESP_NAME
gui.ResetOnSpawn = false
gui.Parent = playerGui

local f = Instance.new("Frame")
f.Size = UDim2.new(0,240,0,340)
f.Position = UDim2.new(1,-250,0,10)
f.BackgroundColor3 = Color3.fromRGB(28,28,28)
f.Active = true
f.Draggable = true
f.Parent = gui
Instance.new("UICorner", f).CornerRadius = UDim.new(0,8)

local header = Instance.new("TextLabel")
header.Size = UDim2.new(1,0,0,34)
header.BackgroundColor3 = Color3.fromRGB(45,45,45)
header.Text = "ESP LITE+ • "..G.BRAINROT_ESP_VERSION
header.TextColor3 = Color3.new(1,1,1)
header.TextScaled = true
header.Font = Enum.Font.GothamBold
header.Parent = f
Instance.new("UICorner", header).CornerRadius = UDim.new(0,8)

local function makeBtn(y, txt, col)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1,-20,0,34)
    b.Position = UDim2.new(0,10,0,y)
    b.BackgroundColor3 = col or Color3.fromRGB(255,60,60)
    b.Text = txt
    b.TextScaled = true
    b.TextColor3 = Color3.new(1,1,1)
    b.Font = Enum.Font.Gotham
    b.Parent = f
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,6)
    return b
end

local espBtn   = makeBtn(44,  "ESP: OFF")
local contBtn  = makeBtn(84,  "Búsqueda Continua: ON", Color3.fromRGB(60,200,60))
local notifBtn = makeBtn(124, "Notificaciones: ON",     Color3.fromRGB(60,200,60))
local pBtn     = makeBtn(164, "ESP Player: OFF")
local xBtn     = makeBtn(204, "X-RAY MAP: OFF")
local gBtn     = makeBtn(244, "GHOST (Yo): OFF")
local uBtn     = makeBtn(284, "UNLOAD / SALIR", Color3.fromRGB(80,80,80))

-- ===== Estado toggles =====
local espEnabled  = false
local contEnabled = true
local notifEnabled= true

local function setBtn(b, on)
    b.BackgroundColor3 = on and Color3.fromRGB(60,200,60) or Color3.fromRGB(255,60,60)
end

-- ===== Botones =====
safeConnect(espBtn.MouseButton1Click, function()
    espEnabled = not espEnabled
    if espEnabled then
        espBtn.Text = "ESP: ON"; setBtn(espBtn,true)
        startScan()
        toast("ESP activado (15s)")
    else
        espBtn.Text = "ESP: OFF"; setBtn(espBtn,false)
        for inst, data in pairs(activeMarks) do safeDestroy(data.hl); activeMarks[inst] = nil end
        toast("ESP desactivado")
    end
end)

safeConnect(contBtn.MouseButton1Click, function()
    contEnabled = not contEnabled
    contBtn.Text = contEnabled and "Búsqueda Continua: ON" or "Búsqueda Continua: OFF"
    setBtn(contBtn, contEnabled)
end)

safeConnect(notifBtn.MouseButton1Click, function()
    notifEnabled = not notifEnabled
    notifBtn.Text = notifEnabled and "Notificaciones: ON" or "Notificaciones: OFF"
    setBtn(notifBtn, notifEnabled)
end)

safeConnect(pBtn.MouseButton1Click, function()
    playerESPEnabled = not playerESPEnabled
    if playerESPEnabled then
        pBtn.Text = "ESP Player: ON"; setBtn(pBtn,true)
        for _,p in ipairs(Players:GetPlayers()) do if p ~= LP then createPlayerESP(p) end end
    else
        pBtn.Text = "ESP Player: OFF"; setBtn(pBtn,false)
        clearPlayerESP()
    end
end)

safeConnect(xBtn.MouseButton1Click, function()
    xrayEnabled = not xrayEnabled
    if xrayEnabled then xBtn.Text = "X-RAY MAP: ON";  setBtn(xBtn,true);  enableXRay()
    else               xBtn.Text = "X-RAY MAP: OFF"; setBtn(xBtn,false); disableXRay()
    end
end)

safeConnect(gBtn.MouseButton1Click, function()
    if ghostEnabled then
        gBtn.Text = "GHOST (Yo): OFF"; setBtn(gBtn,false); ghostOff()
    else
        gBtn.Text = "GHOST (Yo): ON";  setBtn(gBtn,true);  ghostOn()
    end
end)

-- Unload total (seguro)
local function UNLOAD()
    -- Toggles off
    if xrayEnabled then disableXRay() end
    if ghostEnabled then ghostOff() end
    if playerESPEnabled then clearPlayerESP() end
    for inst, data in pairs(activeMarks) do safeDestroy(data.hl); activeMarks[inst] = nil end

    -- GUI + conexiones
    disconnectAll()
    safeDestroy(gui)

    -- flags
    G.__BRAINROT_ESP_RUNNING = false
    toast("ESP descargado")
end
safeConnect(uBtn.MouseButton1Click, UNLOAD)

-- ===== Eventos jugadores =====
safeConnect(Players.PlayerAdded, function(p)
    if notifEnabled then playNotificationSound(); toast("🚨 "..p.Name.." se unió") end
    if playerESPEnabled then task.wait(0.3); createPlayerESP(p) end
end)

safeConnect(Players.PlayerRemoving, function(p)
    local d = playerESPData[p.UserId]
    if d then safeDestroy(d.hl) freeLine(d.line) playerESPData[p.UserId] = nil end
end)

-- ===== Loop =====
local lastCont = 0
safeConnect(RunService.Heartbeat, function()
    rainbowHue = (rainbowHue + 0.02) % 1

    if espEnabled then
        processScanStep()
        updateColors()
        cleanupExpired()
        if contEnabled and qempty() and time() - lastCont >= CONT_SCAN_PERIOD then
            lastCont = time()
            qpush(workspace)
        end
    end

    if playerESPEnabled then
        updatePlayerESPLines()
    end
end)

-- ===== Integración con loader (opcional) =====
-- Permite desde el loader: getgenv().BRAINROT_UNLOAD()
G.BRAINROT_UNLOAD = UNLOAD

-- Listo
-- print("ESP LITE+ SECURE cargado") -- sin prints para no spammear consola
