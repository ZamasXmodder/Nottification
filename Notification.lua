--// =========================
--//  ESP LITE+ SECURE v1.5.2 (Floating Button + Robust Mount)
--//  Botón flotante siempre visible + panel flotante/arrastrable
--// =========================

-- ===== Seguridad / Anti doble ejecución =====
local G = getgenv and getgenv() or _G
G.BRAINROT_ESP_VERSION = "1.5.2-secure"
G.BRAINROT_ESP_NAME    = "ESP_LITE_PLUS_SECURE"

-- Limpieza si quedó a medias
pcall(function()
    for _,parent in ipairs({game:GetService("CoreGui"), (game:GetService("Players").LocalPlayer and game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui"))}) do
        if parent then
            local a = parent:FindFirstChild("GUI_"..G.BRAINROT_ESP_NAME)
            if a and a.Enabled == false then a:Destroy() end
        end
    end
end)

if G.__BRAINROT_ESP_RUNNING then return end
G.__BRAINROT_ESP_RUNNING = true

-- ===== Esperar entorno listo =====
local function waitForGameLoaded()
    while not game or not game.IsLoaded do task.wait(0.1) end
    if not game:IsLoaded() then repeat task.wait(0.1) until game:IsLoaded() end
end
waitForGameLoaded()

-- ===== Servicios =====
local function safeService(n) local ok,svc=pcall(game.GetService,game,n) return ok and svc or nil end
local Players      = safeService("Players")
local RunService   = safeService("RunService")
local TweenService = safeService("TweenService")
local UserInput    = safeService("UserInputService")
if not (Players and RunService and TweenService and UserInput) then G.__BRAINROT_ESP_RUNNING=false return end
local LP = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait() or Players.LocalPlayer

-- ===== Parent UI robusto =====
local function pickUiParent()
    local ok, hui = pcall(function() return (gethui and gethui()) end)
    if ok and hui then return hui end
    local CoreGui = safeService("CoreGui")
    if CoreGui then return CoreGui end
    local pg = LP:FindFirstChildOfClass("PlayerGui") or LP:WaitForChild("PlayerGui",10)
    return pg or CoreGui or game
end
local uiParent = pickUiParent()

-- ===== Helpers =====
local function isInstance(x) return typeof(x)=="Instance" end
local function isValid(i) return isInstance(i) and i.Parent~=nil and i:IsDescendantOf(game) end
local function safeDestroy(x) if isInstance(x) then pcall(function() x:Destroy() end) end end
local function hsv(h) return Color3.fromHSV(h,1,1) end

local CONNECTIONS={}
local function safeConnect(sig,fn)
    local ok,c=pcall(function() return sig:Connect(function(...) pcall(fn,...) end) end)
    if ok and c then table.insert(CONNECTIONS,c) end
    return c
end
local function disconnectAll() for _,c in ipairs(CONNECTIONS) do pcall(function() c:Disconnect() end) end table.clear(CONNECTIONS) end

-- ===== Persistencia simple =====
G.__BRAINROT_SAVE = G.__BRAINROT_SAVE or {}
local function saveFlag(k,v) G.__BRAINROT_SAVE[k]=v end
local function loadFlag(k,def) local v=G.__BRAINROT_SAVE[k]; if v==nil then return def end; return v end

-- ===== Parámetros =====
local MARK_DURATION     = 15
local RAINBOW_SPEED     = 0.35
local SCAN_STEP_BUDGET  = 1200
local CONT_SCAN_PERIOD  = 2
local PLAYER_LINE_FPS   = 30
local XRAY_TRANSPARENCY = 0.8
local TOAST_MIN_DELAY   = 0.4

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

-- ===== Estado =====
local rainbowHue  = 0
local everMarked  = setmetatable({}, {__mode="k"})
local activeMarks = setmetatable({}, {__mode="k"})
local brainrotRoots = setmetatable({}, {__mode="k"})
local function addBrainrotRoot(r) brainrotRoots[r]=true end
local function hasBrainrotAncestor(o)
    local cur=o
    for _=1,32 do
        if not cur or not isValid(cur) then return false end
        if brainrotRoots[cur] then return true end
        cur=cur.Parent
    end
    return false
end
local function cleanupBrainrotRoots()
    for r,_ in pairs(brainrotRoots) do if not isValid(r) then brainrotRoots[r]=nil end end
end

-- Highlight
local function newHighlight(t)
    local h=Instance.new("Highlight")
    h.Adornee=t
    h.FillTransparency=0.45
    h.OutlineTransparency=0.15
    h.OutlineColor=Color3.new(1,1,1)
    h.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
    h.Parent=workspace
    return h
end

-- ===== X-RAY =====
local xrayEnabled=false
local originalLTM=setmetatable({}, {__mode="k"})
local function shouldIgnore(i) return i:IsDescendantOf(uiParent) or i:IsDescendantOf(Players) end
local function isBrainrotNode(i) return targetSet[i.Name] and (i:IsA("Model") or i:IsA("BasePart")) end
local function setLTM(p,v)
    if originalLTM[p]==nil then originalLTM[p]=p.LocalTransparencyModifier end
    local cur=p.LocalTransparencyModifier
    if typeof(cur)~="number" or cur<0 or cur>1 then cur=0 end
    p.LocalTransparencyModifier=math.max(cur,v)
end
local function applyXRay(n)
    if shouldIgnore(n) or hasBrainrotAncestor(n) or isBrainrotNode(n) then return end
    if n:IsA("BasePart") then setLTM(n,XRAY_TRANSPARENCY) end
    for _,c in ipairs(n:GetChildren()) do applyXRay(c) end
end
local function restoreXRay(n)
    if n:IsA("BasePart") and originalLTM[n]~=nil then
        n.LocalTransparencyModifier=originalLTM[n]; originalLTM[n]=nil
    end
    for _,c in ipairs(n:GetChildren()) do restoreXRay(c) end
end
local function enableXRay() xrayEnabled=true;  applyXRay(workspace) end
local function disableXRay() xrayEnabled=false; restoreXRay(workspace) end
local function unXrayBrainrot(root)
    if not isValid(root) then return end
    local function r(n)
        if n:IsA("BasePart") and originalLTM[n]~=nil then n.LocalTransparencyModifier=originalLTM[n]; originalLTM[n]=nil end
        for _,c in ipairs(n:GetChildren()) do r(c) end
    end
    r(root)
end

-- ===== Detección/Marcado =====
local function markOnce(inst)
    if not isValid(inst) or everMarked[inst] then return end
    if not (inst:IsA("Model") or inst:IsA("BasePart")) then return end
    if not targetSet[inst.Name] then return end
    everMarked[inst]=true
    addBrainrotRoot(inst)
    unXrayBrainrot(inst)
    local hl=newHighlight(inst)
    hl.FillColor=hsv(rainbowHue)
    activeMarks[inst]={hl=hl,createdAt=time(),baseHue=rainbowHue}
end

-- ===== BFS =====
local scanQueue,qh,qt={},1,0
local function qpush(x) qt+=1; scanQueue[qt]=x end
local function qpop() if qh<=qt then local v=scanQueue[qh]; scanQueue[qh]=nil; qh+=1; return v end end
local function qempty() return qh>qt end
local function qreset() for i=qh,qt do scanQueue[i]=nil end qh,qt=1,0 end
local function processScanStep()
    local budget=SCAN_STEP_BUDGET
    while budget>0 do
        local node=qpop() if not node then break end
        if isValid(node) then
            if targetSet[node.Name] then markOnce(node) end
            for _,ch in ipairs(node:GetChildren()) do if isValid(ch) then qpush(ch) end end
        end
        budget-=1
    end
end
local function startScan() qreset(); qpush(workspace) end

-- ===== Toasts =====
local toastGui=Instance.new("ScreenGui")
toastGui.Name="Toast_"..G.BRAINROT_ESP_NAME
toastGui.ResetOnSpawn=false
toastGui.DisplayOrder=9999
toastGui.IgnoreGuiInset=true
toastGui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
toastGui.Parent=uiParent

local toastTemplate
do
    local f=Instance.new("Frame")
    f.Size=UDim2.new(0,340,0,86)
    f.Position=UDim2.new(0.5,-170,1,-100)
    f.BackgroundColor3=Color3.fromRGB(40,40,40)
    local c=Instance.new("UICorner"); c.CornerRadius=UDim2.new(0,10); c.Parent=f
    local l=Instance.new("TextLabel"); l.Name="Text"; l.BackgroundTransparency=1
    l.Size=UDim2.new(1,-20,1,-20); l.Position=UDim2.new(0,10,0,10)
    l.TextScaled=true; l.TextColor3=Color3.new(1,1,1); l.Font=Enum.Font.GothamMedium; l.Text=""
    l.Parent=f
    toastTemplate=f
end
local lastToast=0
local notifSound=Instance.new("Sound")
notifSound.SoundId="rbxassetid://77665577458181"; notifSound.Volume=0.7; notifSound.Parent=toastGui
local function playNotificationSound() pcall(function() notifSound:Play() end) end
local function toast(msg,dur)
    local now=time() if now-lastToast<TOAST_MIN_DELAY then return end; lastToast=now
    local f=toastTemplate:Clone(); f.Parent=toastGui; f.Position=UDim2.new(0.5,-170,1,0)
    f.Text.Text=msg
    TweenService:Create(f,TweenInfo.new(0.25,Enum.EasingStyle.Back),{Position=UDim2.new(0.5,-170,1,-100)}):Play()
    task.delay(dur or 3.2,function()
        local tw=TweenService:Create(f,TweenInfo.new(0.25),{Position=UDim2.new(0.5,-170,1,0)}); tw:Play(); tw.Completed:Once(function() safeDestroy(f) end)
    end)
end

-- ===== Player ESP =====
local linePool={}
local function getLine()
    local l=table.remove(linePool); if l then l.Parent=workspace return l end
    l=Instance.new("Part"); l.Name="PlayerESPLine"; l.Anchored=true; l.CanCollide=false
    l.Size=Vector3.new(0.25,0.25,1); l.Material=Enum.Material.ForceField; l.Color=Color3.fromRGB(255,0,0); l.Transparency=0.1
    l.Parent=workspace; return l
end
local function freeLine(l) if l then l.Parent=nil table.insert(linePool,l) end end

local function makeBillboard(p)
    local bb=Instance.new("BillboardGui"); bb.Name="ESPPlayerBillboard"; bb.AlwaysOnTop=true; bb.Size=UDim2.fromOffset(200,50); bb.StudsOffsetWorldSpace=Vector3.new(0,3.2,0); bb.MaxDistance=3000
    local holder=Instance.new("Frame"); holder.BackgroundColor3=Color3.fromRGB(25,25,25); holder.BackgroundTransparency=0.25; holder.Size=UDim2.fromScale(1,1); holder.Parent=bb
    local corner=Instance.new("UICorner"); corner.CornerRadius=UDim.new(0,6); corner.Parent=holder
    local label=Instance.new("TextLabel"); label.Name="Text"; label.BackgroundTransparency=1; label.Size=UDim2.fromScale(1,1); label.TextScaled=true; label.Font=Enum.Font.GothamBold; label.TextColor3=Color3.new(1,1,1); label.TextStrokeTransparency=0.3; label.Text=p.Name; label.Parent=holder
    return bb,label
end

local playerESPEnabled=loadFlag("playerESPEnabled",false)
local playerESPData={}
local lastPEspUpd=0
local function createPlayerESP(p)
    if p==LP or playerESPData[p.UserId] then return end
    local char=p.Character if not char then return end
    local hrp=char:FindFirstChild("HumanoidRootPart") if not hrp then return end
    local hl=newHighlight(char); hl.FillColor=Color3.new(1,0,0)
    local line=getLine()
    local bb,lbl=makeBillboard(p); bb.Adornee=hrp; bb.Parent=workspace
    playerESPData[p.UserId]={p=p,hl=hl,line=line,bb=bb,lbl=lbl}
end
local function clearPlayerESP()
    for _,d in pairs(playerESPData) do safeDestroy(d.hl); freeLine(d.line); safeDestroy(d.bb) end
    table.clear(playerESPData)
end
local function updatePlayerESPLines()
    local now=time() if now-lastPEspUpd<1/PLAYER_LINE_FPS then return end; lastPEspUpd=now
    local myHRP=LP.Character and LP.Character:FindFirstChild("HumanoidRootPart"); if not myHRP then return end
    local myPos=myHRP.Position; local toRemove={}
    for uid,d in pairs(playerESPData) do
        local p=d.p; local char=p and p.Character; local hrp=char and char:FindFirstChild("HumanoidRootPart")
        if not (p and char and hrp and isValid(d.hl) and isValid(d.line) and isValid(d.bb) and isValid(d.lbl)) then
            table.insert(toRemove,uid)
        else
            local tpos=hrp.Position; local dir=tpos-myPos; local dist=dir.Magnitude; if not dist or dist~=dist or dist<=0 then dist=0.1 end
            d.line.Size=Vector3.new(0.25,0.25,dist); d.line.CFrame=CFrame.lookAt(myPos+dir*0.5,tpos)
            if d.bb.Adornee~=hrp then d.bb.Adornee=hrp end
            d.lbl.Text=string.format("%s  •  %dst", p.Name, math.floor(dist))
        end
    end
    for _,uid in ipairs(toRemove) do local d=playerESPData[uid]; if d then safeDestroy(d.hl); freeLine(d.line); safeDestroy(d.bb); playerESPData[uid]=nil end end
end

-- ===== Ghost =====
local ghostEnabled=loadFlag("ghostEnabled",false)
local function setCharTransp(char,t)
    for _,d in ipairs(char:GetDescendants()) do
        if d:IsA("BasePart") or d:IsA("Decal") then d.Transparency=t end
        if d:IsA("Accessory") then local h=d:FindFirstChild("Handle") if h then h.Transparency=t end end
    end
end
local function ghostOn()  ghostEnabled=true;  saveFlag("ghostEnabled",true);  if LP.Character then setCharTransp(LP.Character,0.7) end end
local function ghostOff() ghostEnabled=false; saveFlag("ghostEnabled",false); if LP.Character then setCharTransp(LP.Character,0.0) end end
safeConnect(LP.CharacterAdded,function(c) task.wait(0.2); if ghostEnabled then setCharTransp(c,0.7) end end)

-- ===== GUI (panel + botón flotante) =====
local mainGui=Instance.new("ScreenGui")
mainGui.Name="GUI_"..G.BRAINROT_ESP_NAME
mainGui.ResetOnSpawn=false
mainGui.DisplayOrder=10000
mainGui.IgnoreGuiInset=true
mainGui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
mainGui.Parent=uiParent

-- Botón flotante circular
local floatBtn=Instance.new("TextButton")
floatBtn.Name="ESP_FloatButton"
floatBtn.Parent=mainGui
floatBtn.Size=UDim2.fromOffset(54,54)
floatBtn.Text="ESP"
floatBtn.TextScaled=true
floatBtn.Font=Enum.Font.GothamBold
floatBtn.TextColor3=Color3.new(1,1,1)
floatBtn.BackgroundColor3=Color3.fromRGB(60,120,255)
floatBtn.AutoButtonColor=true
local fbCorner=Instance.new("UICorner",floatBtn); fbCorner.CornerRadius=UDim.new(1,0)

-- Posición persistente del botón
local fbPos=loadFlag("floatBtnPos", {x= -70, y= 140}) -- offset desde esquina derecha por defecto
floatBtn.Position=UDim2.new(1, fbPos.x, 0, fbPos.y)

-- Drag del botón flotante
do
    local dragging=false; local start; local startPos
    safeConnect(floatBtn.InputBegan,function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1 then
            dragging=true; start=inp.Position; startPos=floatBtn.Position
            inp.Changed:Connect(function() if inp.UserInputState==Enum.UserInputState.End then dragging=false end end)
        end
    end)
    safeConnect(UserInput.InputChanged,function(inp)
        if dragging and inp.UserInputType==Enum.UserInputType.MouseMovement then
            local delta=inp.Position-start
            local nx= startPos.X.Offset + delta.X
            local ny= startPos.Y.Offset + delta.Y
            floatBtn.Position=UDim2.new(startPos.X.Scale, nx, startPos.Y.Scale, ny)
        end
    end)
    -- guardado al soltar (polling simple)
    safeConnect(UserInput.InputEnded,function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1 then
            saveFlag("floatBtnPos",{x=floatBtn.Position.X.Offset,y=floatBtn.Position.Y.Offset})
        end
    end)
end

-- Panel flotante
local panel=Instance.new("Frame")
panel.Size=UDim2.new(0,260,0,420)
panel.Position=UDim2.new(1,-270,0,10)
panel.BackgroundColor3=Color3.fromRGB(24,24,24)
panel.Active=true
panel.Parent=mainGui
local pCorner=Instance.new("UICorner",panel); pCorner.CornerRadius=UDim.new(0,10)

local header=Instance.new("Frame")
header.Size=UDim2.new(1,0,0,38); header.BackgroundColor3=Color3.fromRGB(45,45,45); header.Parent=panel
Instance.new("UICorner",header).CornerRadius=UDim.new(0,10)
local headerLabel=Instance.new("TextLabel")
headerLabel.BackgroundTransparency=1; headerLabel.Size=UDim2.new(1,-76,1,0); headerLabel.Position=UDim2.new(0,10,0,0)
headerLabel.Text="ESP LITE+ • "..G.BRAINROT_ESP_VERSION; headerLabel.TextColor3=Color3.new(1,1,1); headerLabel.TextScaled=true; headerLabel.Font=Enum.Font.GothamBold
headerLabel.Parent=header

local minBtn=Instance.new("TextButton")
minBtn.Size=UDim2.new(0,30,0,30); minBtn.Position=UDim2.new(1,-36,0,4)
minBtn.BackgroundColor3=Color3.fromRGB(60,60,60); minBtn.Text="-"; minBtn.TextScaled=true; minBtn.TextColor3=Color3.new(1,1,1); minBtn.Font=Enum.Font.GothamBold; minBtn.Parent=header
Instance.new("UICorner",minBtn).CornerRadius=UDim.new(0,6)

-- Drag del panel (desde header)
do
    local dragging=false; local start; local startPos
    safeConnect(header.InputBegan,function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1 then
            dragging=true; start=inp.Position; startPos=panel.Position
            inp.Changed:Connect(function() if inp.UserInputState==Enum.UserInputState.End then dragging=false end end)
        end
    end)
    safeConnect(UserInput.InputChanged,function(inp)
        if dragging and inp.UserInputType==Enum.UserInputType.MouseMovement then
            local delta=inp.Position-start
            panel.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+delta.X,startPos.Y.Scale,startPos.Y.Offset+delta.Y)
        end
    end)
end

local body=Instance.new("Frame")
body.Size=UDim2.new(1,-20,1,-58); body.Position=UDim2.new(0,10,0,48); body.BackgroundTransparency=1; body.Parent=panel
local function badge(text,color)
    local b=Instance.new("TextLabel"); b.BackgroundColor3=color; b.TextColor3=Color3.new(1,1,1); b.TextScaled=true; b.Font=Enum.Font.GothamMedium; b.Size=UDim2.new(1,0,0,26); b.Text=text; b.Parent=body
    local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,6); c.Parent=b; return b
end
local statusBadge=badge("Listo", Color3.fromRGB(35,120,60)); statusBadge.Position=UDim2.new(0,0,0,0)

local function makeBtn(y, txt, col, tipText)
    local container=Instance.new("Frame"); container.Size=UDim2.new(1,0,0,38); container.Position=UDim2.new(0,0,0,y); container.BackgroundTransparency=1; container.Parent=body
    local b=Instance.new("TextButton"); b.Size=UDim2.new(1,0,1,0); b.BackgroundColor3=col or Color3.fromRGB(255,60,60); b.Text=txt; b.TextScaled=true; b.TextColor3=Color3.new(1,1,1); b.Font=Enum.Font.Gotham; b.Parent=container
    Instance.new("UICorner", b).CornerRadius=UDim.new(0,8)
    local tip=Instance.new("TextLabel"); tip.Visible=false; tip.BackgroundColor3=Color3.fromRGB(20,20,20); tip.TextColor3=Color3.fromRGB(220,220,220); tip.Text=tipText or ""; tip.Font=Enum.Font.Gotham
    tip.TextScaled=true; tip.Size=UDim2.new(0, math.max(160, (tipText and #tipText or 0)*6), 0, 28); tip.Position=UDim2.new(0, 8, 0, -34); tip.Parent=container
    Instance.new("UICorner", tip).CornerRadius=UDim.new(0,6)
    safeConnect(b.MouseEnter,function() if tipText and #tipText>0 then tip.Visible=true end end)
    safeConnect(b.MouseLeave,function() tip.Visible=false end)
    return b
end

local y0=40
local espBtn   = makeBtn(y0+  0, "ESP: OFF",               Color3.fromRGB(200,60,60),  "Marca brainrots 15s con arcoíris")
local contBtn  = makeBtn(y0+ 44, "Búsqueda Continua: ON",  Color3.fromRGB(60,200,60),  "Repite el escaneo automáticamente")
local notifBtn = makeBtn(y0+ 88, "Notificaciones: ON",     Color3.fromRGB(60,200,60),  "Sonido + toast cuando entra alguien")
local pBtn     = makeBtn(y0+132, "ESP Player: OFF",        Color3.fromRGB(200,60,60),  "Línea roja + Nombre/Distancia")
local xBtn     = makeBtn(y0+176, "X-RAY MAP: OFF",         Color3.fromRGB(200,60,60),  "Props semi-transparentes")
local gBtn     = makeBtn(y0+220, "GHOST (Yo): OFF",        Color3.fromRGB(200,60,60),  "70% transparente")
local uBtn     = makeBtn(y0+264, "UNLOAD / SALIR",         Color3.fromRGB(80,80,80),   "Desinstala todo y cierra")

-- ===== Estado toggles =====
local espEnabled   = loadFlag("espEnabled",  false)
local contEnabled  = loadFlag("contEnabled", true)
local notifEnabled = loadFlag("notifEnabled", true)
local playerESPEnabled = loadFlag("playerESPEnabled", false)

local function setBtn(b,on) b.BackgroundColor3 = on and Color3.fromRGB(60,200,60) or Color3.fromRGB(200,60,60) end
local function refreshUI()
    setBtn(espBtn,espEnabled);      espBtn.Text   = espEnabled and "ESP: ON"                 or "ESP: OFF"
    setBtn(contBtn,contEnabled);    contBtn.Text  = contEnabled and "Búsqueda Continua: ON"  or "Búsqueda Continua: OFF"
    setBtn(notifBtn,notifEnabled);  notifBtn.Text = notifEnabled and "Notificaciones: ON"     or "Notificaciones: OFF"
    setBtn(pBtn,playerESPEnabled);  pBtn.Text     = playerESPEnabled and "ESP Player: ON"     or "ESP Player: OFF"
    setBtn(xBtn,xrayEnabled);       xBtn.Text     = xrayEnabled and "X-RAY MAP: ON"           or "X-RAY MAP: OFF"
    setBtn(gBtn,ghostEnabled);      gBtn.Text     = ghostEnabled and "GHOST (Yo): ON"         or "GHOST (Yo): OFF"
end

-- Mostrar/ocultar panel con botón flotante
local panelVisible = true
local function setPanelVisible(v)
    panelVisible=v
    panel.Visible=v
end
safeConnect(floatBtn.MouseButton1Click,function() setPanelVisible(not panelVisible) end)

-- Minimizar
local minimized=false
local function setMinimized(m)
    minimized=m
    if minimized then
        TweenService:Create(body, TweenInfo.new(0.15), {Position=UDim2.new(0,10,0,420), Size=UDim2.new(1,-20,0,0)}):Play()
        TweenService:Create(panel, TweenInfo.new(0.15), {Size=UDim2.new(0,260,0,48)}):Play()
        minBtn.Text="+"
    else
        TweenService:Create(panel, TweenInfo.new(0.15), {Size=UDim2.new(0,260,0,420)}):Play()
        TweenService:Create(body, TweenInfo.new(0.15), {Position=UDim2.new(0,10,0,48), Size=UDim2.new(1,-20,1,-58)}):Play()
        minBtn.Text="-"
    end
end
safeConnect(minBtn.MouseButton1Click,function() setMinimized(not minimized) end)

-- ===== Botones funcionales =====
safeConnect(espBtn.MouseButton1Click,function()
    espEnabled=not espEnabled; saveFlag("espEnabled",espEnabled)
    if espEnabled then startScan(); toast("ESP activado (15s)"); statusBadge.Text="ESP activo"
    else for _,d in pairs(activeMarks) do safeDestroy(d.hl) end; table.clear(activeMarks); toast("ESP desactivado"); statusBadge.Text="Listo" end
    refreshUI()
end)
safeConnect(contBtn.MouseButton1Click,function() contEnabled=not contEnabled; saveFlag("contEnabled",contEnabled); refreshUI() end)
safeConnect(notifBtn.MouseButton1Click,function() notifEnabled=not notifEnabled; saveFlag("notifEnabled",notifEnabled); refreshUI() end)
safeConnect(pBtn.MouseButton1Click,function()
    playerESPEnabled=not playerESPEnabled; saveFlag("playerESPEnabled",playerESPEnabled)
    if playerESPEnabled then for _,p in ipairs(Players:GetPlayers()) do if p~=LP then createPlayerESP(p) end end else clearPlayerESP() end
    refreshUI()
end)
safeConnect(xBtn.MouseButton1Click,function() xrayEnabled=not xrayEnabled; if xrayEnabled then enableXRay() else disableXRay() end; refreshUI() end)
safeConnect(gBtn.MouseButton1Click,function() if ghostEnabled then ghostOff() else ghostOn() end; refreshUI() end)

-- ===== Unload =====
local function UNLOAD()
    if xrayEnabled then disableXRay() end
    if ghostEnabled then ghostOff() end
    if playerESPEnabled then clearPlayerESP() end
    for _,d in pairs(activeMarks) do safeDestroy(d.hl) end
    table.clear(activeMarks)
    disconnectAll()
    pcall(function() restoreXRay(workspace) end)
    safeDestroy(mainGui); safeDestroy(toastGui)
    G.__BRAINROT_ESP_RUNNING=false
end
safeConnect(uBtn.MouseButton1Click, UNLOAD)
G.BRAINROT_UNLOAD=UNLOAD

-- ===== Eventos jugadores =====
safeConnect(Players.PlayerAdded,function(p) if notifEnabled then playNotificationSound(); toast("🚨 "..p.Name.." se unió") end if playerESPEnabled then task.wait(0.3) createPlayerESP(p) end end)
safeConnect(Players.PlayerRemoving,function(p) local d=playerESPData[p.UserId]; if d then safeDestroy(d.hl); freeLine(d.line); safeDestroy(d.bb); playerESPData[p.UserId]=nil end end)

-- ===== Hotkeys =====
safeConnect(UserInput.InputBegan,function(input,gp)
    if gp then return end
    if input.KeyCode==Enum.KeyCode.RightShift then setPanelVisible(not panelVisible) end -- toggle panel
    if input.KeyCode==Enum.KeyCode.M then setMinimized(not minimized) end
    if input.KeyCode==Enum.KeyCode.E then espBtn:Activate() end
    if input.KeyCode==Enum.KeyCode.X then xBtn:Activate() end
    if input.KeyCode==Enum.KeyCode.P then pBtn:Activate() end
    if input.KeyCode==Enum.KeyCode.G then gBtn:Activate() end
    if input.KeyCode==Enum.KeyCode.U then uBtn:Activate() end
end)

-- ===== Loop =====
local lastCont=0
safeConnect(RunService.Heartbeat,function(dt)
    rainbowHue=(rainbowHue + (dt*0.25))%1
    header.BackgroundColor3=Color3.fromHSV(rainbowHue,0.5,0.8)

    if espEnabled then
        processScanStep()
        for inst,data in pairs(activeMarks) do
            local hl=data.hl
            if isValid(hl) then
                local hue=(data.baseHue + (time()-data.createdAt)*RAINBOW_SPEED)%1
                hl.FillColor=hsv(hue)
            end
        end
        local now=time()
        for inst,data in pairs(activeMarks) do
            if (now-data.createdAt)>=MARK_DURATION or not isValid(inst) then safeDestroy(data.hl); activeMarks[inst]=nil end
        end
        cleanupBrainrotRoots()
        if contEnabled and qempty() and time()-lastCont>=CONT_SCAN_PERIOD then lastCont=time(); qpush(workspace) end
    end

    if playerESPEnabled then updatePlayerESPLines() end
end)

-- ===== Nuevos objetos =====
safeConnect(workspace.DescendantAdded,function(i)
    if xrayEnabled and i:IsA("BasePart") and not shouldIgnore(i) and not hasBrainrotAncestor(i) and not isBrainrotNode(i) then setLTM(i,XRAY_TRANSPARENCY) end
    if isBrainrotNode(i) and targetSet[i.Name] then markOnce(i) end
end)

-- ===== Inicialización =====
refreshUI()
toast("ESP listo: usa el botón flotante o RightShift para abrir/cerrar",3.6)
if playerESPEnabled then for _,p in ipairs(Players:GetPlayers()) do if p~=LP then createPlayerESP(p) end end end
if ghostEnabled then ghostOn() end
