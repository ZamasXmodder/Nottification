--// =========================
--//  ESP LITE+ SECURE v1.8.3
--//  Brainrots ESP + Player ESP + Notifs
--//  X-Ray + Ghost + Game Night + Sky predeterminado Roblox (FORZADO)
--//  GUI pro (gradiente, sombra, scroll, tecla [T])
--//  Potato: optimiza MAPA (mundo), no la GUI
--//  Specials: pulso oscuro <-> rojo (highlight y línea)
--// =========================

-- anti doble ejecución
local G = getgenv and getgenv() or _G
G.BRAINROT_ESP_VERSION = "1.8.3-secure"
G.BRAINROT_ESP_NAME    = "ESP_LITE_PLUS_SECURE"
if G.__BRAINROT_ESP_RUNNING then return end
G.__BRAINROT_ESP_RUNNING = true

-- esperar game
local function waitForGameLoaded()
    if not game or not game.IsLoaded then return end
    if not game:IsLoaded() then repeat task.wait() until game:IsLoaded() end
end
waitForGameLoaded()

-- servicios seguros
local function safeService(name) local ok,svc=pcall(game.GetService,game,name) return ok and svc or nil end
local Players=safeService("Players"); local RunService=safeService("RunService")
local TweenService=safeService("TweenService"); local Lighting=safeService("Lighting")
local UserInput=safeService("UserInputService"); local SoundService=safeService("SoundService")
local ContentProvider=safeService("ContentProvider")
if not (Players and RunService and TweenService and Lighting and UserInput) then G.__BRAINROT_ESP_RUNNING=false; return end

local LP=Players.LocalPlayer
if not LP then repeat task.wait() until Players.LocalPlayer; LP=Players.LocalPlayer end
local playerGui=LP:FindFirstChildOfClass("PlayerGui") or LP:WaitForChild("PlayerGui",10)
if not playerGui then G.__BRAINROT_ESP_RUNNING=false; return end

-- helpers
local function isInstance(x) return typeof(x)=="Instance" end
local function isValid(i) return isInstance(i) and i.Parent and i:IsDescendantOf(game) end
local function safeDestroy(x) if isInstance(x) and x.Destroy then pcall(function() x:Destroy() end) end end
local function hsv(h) return Color3.fromHSV(h,1,1) end

-- conexiones
local CONNECTIONS={}
local function safeConnect(signal,fn) local c=signal:Connect(function(...) pcall(fn,...) end) table.insert(CONNECTIONS,c) return c end
local function disconnectAll() for _,c in ipairs(CONNECTIONS) do pcall(function() c:Disconnect() end) end table.clear(CONNECTIONS) end

-- parámetros
local MARK_DURATION=15
local RAINBOW_SPEED=0.35
local SCAN_STEP_BUDGET=1200
local CONT_SCAN_PERIOD=2
local PLAYER_LINE_FPS=30
local XRAY_TRANSPARENCY=0.8

-- Specials: pulso oscuro<->rojo
local RED_STRONG = Color3.fromRGB(220,40,40)
local SPECIAL_PULSE_SPEED = 1.2
local function pulseAlpha(t, speed) return 0.5 + 0.5 * math.sin(t * speed) end

-- targets
local targetNames={
    "La Secret Combinasion","Burguro And Fryuro","Los 67","Chillin Chili","Tang Tang Keletang",
    "Money Money Puggy","Los Primos","Los Tacoritas","La Grande Combinasion","Pot Hotspot",
    "Mariachi Corazoni","Secret Lucky Block","To to to Sahur","Strawberry Elephant",
    "Ketchuru and Musturu","La Extinct Grande","Tictac Sahur","Tacorita Bicicleta",
    "Chicleteira Bicicleteira","Spaghetti Tualetti","Esok Sekolah","Los Chicleteiras","67",
    "Los Combinasionas","Nuclearo Dinosauro","Las Sis","Los Hotspotsitos","Tralaledon",
    "Ketupat Kepat","Los Bros","La Supreme Combinasion","Ketchuru and Masturu",
    "Garama and Madundung","Dragon Cannelloni","Celularcini Viciosini","La Spooky Grande","Los Mobilis","Eviledon",
    "Spooky and Pumpky","Mieteteira Bicicleteira","Meowl"
}
local targetSet={} for _,n in ipairs(targetNames) do targetSet[n]=true end

-- colores oscuros por brainrot (más fuertes)
local specialDarkMap={
    ["La Secret Combinasion"]={line=Color3.fromRGB(28,28,40), fill=Color3.fromRGB(24,24,34)},
    ["Burguro And Fryuro"]   ={line=Color3.fromRGB(40,26,26), fill=Color3.fromRGB(34,22,22)},
    ["Tang Tang Keletang"]   ={line=Color3.fromRGB(22,42,38), fill=Color3.fromRGB(18,34,31)},
    ["Strawberry Elephant"]  ={line=Color3.fromRGB(42,26,34), fill=Color3.fromRGB(34,20,28)},
    ["Ketchuru and Musturu"] ={line=Color3.fromRGB(44,36,22), fill=Color3.fromRGB(36,30,18)},
    ["Tictac Sahur"]         ={line=Color3.fromRGB(26,34,46), fill=Color3.fromRGB(20,26,38)},
    ["Nuclearo Dinosauro"]   ={line=Color3.fromRGB(34,46,34), fill=Color3.fromRGB(26,38,26)},
    ["Tralaledon"]           ={line=Color3.fromRGB(38,26,42), fill=Color3.fromRGB(30,20,34)},
    ["Ketupat Kepat"]        ={line=Color3.fromRGB(34,38,26), fill=Color3.fromRGB(26,30,20)},
    ["La Supreme Combinasion"]={line=Color3.fromRGB(46,38,26), fill=Color3.fromRGB(38,30,20)},
    ["Garama and Madundung"] ={line=Color3.fromRGB(26,42,46), fill=Color3.fromRGB(20,34,38)},
    ["Dragon Cannelloni"]    ={line=Color3.fromRGB(46,26,26), fill=Color3.fromRGB(38,20,20)},
    ["Spooky and Pumpky"]    ={line=Color3.fromRGB(46,26,26), fill=Color3.fromRGB(38,20,20)},
    ["Mieteteira Bicicleteira"] = { line = Color3.fromRGB(36,26,46), fill = Color3.fromRGB(28,20,38) }, -- tono morado oscuro
    ["Meowl"]                   = { line = Color3.fromRGB(30,30,42), fill = Color3.fromRGB(24,24,34) }  -- gris/azul oscuro (cat vibes)
}

-- estado esp
local rainbowHue=0
local everMarked=setmetatable({}, {__mode="k"})
local activeMarks=setmetatable({}, {__mode="k"})

-- raíces brainrot
local brainrotRoots=setmetatable({}, {__mode="k"})
local function addBrainrotRoot(r) brainrotRoots[r]=true end
local function hasBrainrotAncestor(obj)
    local cur=obj
    for _=1,32 do
        if not cur or not isValid(cur) then return false end
        if brainrotRoots[cur] then return true end
        cur=cur.Parent
    end
    return false
end
local function cleanupBrainrotRoots() for r,_ in pairs(brainrotRoots) do if not isValid(r) then brainrotRoots[r]=nil end end end

-- highlight base
local function newHighlight(t)
    local h=Instance.new("Highlight")
    h.Adornee=t; h.FillTransparency=0.45; h.OutlineTransparency=0.12
    h.OutlineColor=Color3.new(1,1,1); h.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
    h.Parent=workspace; return h
end

-- X-RAY
local xrayEnabled=false
local originalLTM=setmetatable({}, {__mode="k"})
local function shouldIgnore(i) return i:IsDescendantOf(playerGui) or i:IsDescendantOf(Players) end
local function isBrainrotNode(i) return targetSet[i.Name] and (i:IsA("Model") or i:IsA("BasePart")) end
local function setLTM(p,v) if originalLTM[p]==nil then originalLTM[p]=p.LocalTransparencyModifier end p.LocalTransparencyModifier=math.max(p.LocalTransparencyModifier,v) end
local function applyXRay(n)
    if shouldIgnore(n) then return end
    if hasBrainrotAncestor(n) then return end
    if isBrainrotNode(n) then return end
    if n:IsA("BasePart") then setLTM(n,XRAY_TRANSPARENCY) end
    for _,c in ipairs(n:GetChildren()) do applyXRay(c) end
end
local function restoreXRay(n)
    if n:IsA("BasePart") and originalLTM[n]~=nil then n.LocalTransparencyModifier=originalLTM[n]; originalLTM[n]=nil end
    for _,c in ipairs(n:GetChildren()) do restoreXRay(c) end
end
local function enableXRay() xrayEnabled=true; applyXRay(workspace) end
local function disableXRay() xrayEnabled=false; restoreXRay(workspace) end
local function unXrayBrainrot(root)
    if not isValid(root) then return end
    local function restoreTree(n)
        if n:IsA("BasePart") and originalLTM[n]~=nil then n.LocalTransparencyModifier=originalLTM[n]; originalLTM[n]=nil end
        for _,c in ipairs(n:GetChildren()) do restoreTree(c) end
    end
    restoreTree(root)
end

-- pool de líneas
local linePool={}
local function getLine()
    local l=table.remove(linePool); if l then l.Parent=workspace; return l end
    l=Instance.new("Part"); l.Name="ESPLine"; l.Anchored=true; l.CanCollide=false
    l.Size=Vector3.new(0.25,0.25,1); l.Material=Enum.Material.ForceField
    l.Color=Color3.fromRGB(255,0,0); l.Transparency=0.1; l.Parent=workspace; return l
end
local function freeLine(l) if l then l.Parent=nil; table.insert(linePool,l) end end

local function getWorldPos(obj)
    if not isValid(obj) then return nil end
    if obj:IsA("BasePart") then return obj.Position end
    if obj:IsA("Model") then
        local pp=obj.PrimaryPart; if pp and isValid(pp) then return pp.Position end
        local ok,cf=pcall(obj.GetBoundingBox,obj); if ok and cf then return cf.Position end
        for _,d in ipairs(obj:GetDescendants()) do if d:IsA("BasePart") then return d.Position end end
    end
    return nil
end

-- estructuras especiales
local specialBrainrotLines=setmetatable({}, {__mode="k"}) -- {inst={line,color,baseFill,baseLine}}

-- markOnce
local function markOnce(inst)
    if not isValid(inst) or everMarked[inst] then return end
    if not (inst:IsA("Model") or inst:IsA("BasePart")) then return end
    if not targetSet[inst.Name] then return end

    everMarked[inst]=true
    addBrainrotRoot(inst)
    unXrayBrainrot(inst)

    local hl=newHighlight(inst)
    hl.FillColor=hsv(rainbowHue)
    activeMarks[inst]={hl=hl, createdAt=time(), baseHue=rainbowHue}

    local spec=specialDarkMap[inst.Name]
    if spec then
        if isValid(hl) then
            hl.FillTransparency=0.48
            hl.OutlineTransparency=0.05
            hl.OutlineColor=Color3.fromRGB(8,8,10)
            hl.FillColor=spec.fill
        end
        local L=getLine()
        L.Material=Enum.Material.Neon
        L.Transparency=0.14
        L.Color=spec.line
        specialBrainrotLines[inst]={line=L, color=spec.line, baseFill=spec.fill, baseLine=spec.line}
    end
end

-- BFS
local scanQueue, qh, qt = {},1,0
local function qpush(x) qt+=1; scanQueue[qt]=x end
local function qpop() if qh<=qt then local v=scanQueue[qh]; scanQueue[qh]=nil; qh+=1; return v end end
local function qempty() return qh>qt end
local function qreset() for i=qh,qt do scanQueue[i]=nil end qh,qt=1,0 end
local function processScanStep()
    local budget=SCAN_STEP_BUDGET
    while budget>0 do
        local node=qpop(); if not node then break end
        if isValid(node) then
            if targetSet[node.Name] then markOnce(node) end
            for _,ch in ipairs(node:GetChildren()) do if isValid(ch) then qpush(ch) end end
        end
        budget-=1
    end
end
local function startScan() qreset(); qpush(workspace) end

safeConnect(workspace.DescendantAdded,function(i)
    if xrayEnabled and i:IsA("BasePart") and not shouldIgnore(i) and not hasBrainrotAncestor(i) and not isBrainrotNode(i) then setLTM(i,XRAY_TRANSPARENCY) end
    if isBrainrotNode(i) and targetSet[i.Name] then markOnce(i) end
    -- si Potato está ON, aplicamos optimización a nuevos nodos del mapa
    if potatoOn then enqueuePotatoCandidate(i) end
end)

-- mantenimiento ESP
local function cleanupExpired()
    local now=time()
    for inst,data in pairs(activeMarks) do
        if (now-data.createdAt)>=MARK_DURATION or not isValid(inst) then
            safeDestroy(data.hl); activeMarks[inst]=nil
            local s=specialBrainrotLines[inst]; if s then freeLine(s.line); specialBrainrotLines[inst]=nil end
        end
    end
    for inst,s in pairs(specialBrainrotLines) do
        if not isValid(inst) or not activeMarks[inst] then freeLine(s.line); specialBrainrotLines[inst]=nil end
    end
end

-- colores/pulsos
local function updateColors()
    local tNow = time()
    for inst, data in pairs(activeMarks) do
        local hl = data.hl
        if isValid(hl) then
            local spec = specialDarkMap[inst.Name]
            if spec then
                local s = 0.5 + 0.5 * math.sin(tNow * SPECIAL_PULSE_SPEED)
                s = s * 0.7
                local fill = spec.fill:Lerp(RED_STRONG, s)
                hl.FillColor = fill
                hl.OutlineTransparency = 0.05
                hl.OutlineColor = Color3.fromRGB(8, 8, 10)
            else
                local hue = (data.baseHue + (tNow - data.createdAt) * RAINBOW_SPEED) % 1
                hl.FillColor = hsv(hue)
            end
        end
    end
end

-- =========================
-- notifs (parche de sonido confiable)
-- =========================
local NOTIF_ID = "rbxassetid://77665577458181"
local baseNotif = Instance.new("Sound")
baseNotif.Name = "ESP_JoinPingTemplate"
baseNotif.SoundId = NOTIF_ID
baseNotif.Volume = 0.8
baseNotif.PlaybackSpeed = 1
baseNotif.RollOffMode = Enum.RollOffMode.InverseTapered
baseNotif.EmitterSize = 5
baseNotif.Looped = false
if not SoundService then baseNotif.Parent = playerGui end

local lastPingAt = 0
local function playNotificationSound()
    local now = time()
    if now - lastPingAt < 0.15 then return end
    lastPingAt = now
    if SoundService and SoundService.PlayLocalSound then
        local s = baseNotif:Clone()
        s.Name = "ESP_JoinPing"
        s.Parent = SoundService
        if ContentProvider and ContentProvider.PreloadAsync then pcall(function() ContentProvider:PreloadAsync({ s }) end) end
        pcall(function() s:Play() end)
        s.Ended:Once(function() pcall(function() s:Destroy() end) end)
    else
        if not isValid(baseNotif.Parent) then baseNotif.Parent = playerGui end
        pcall(function() baseNotif:Stop(); baseNotif.TimePosition = 0; baseNotif:Play() end)
    end
end

local function toast(msg,tColor)
    local gui=Instance.new("ScreenGui"); gui.Name="Toast_"..G.BRAINROT_ESP_NAME; gui.Parent=playerGui
    local f=Instance.new("Frame"); f.Size=UDim2.new(0,340,0,84); f.Position=UDim2.new(0.5,-170,1,-100); f.BackgroundColor3=Color3.fromRGB(24,24,28); f.BorderSizePixel=0; f.Parent=gui
    local stroke=Instance.new("UIStroke"); stroke.Thickness=2; stroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Border; stroke.Color=tColor or Color3.fromRGB(80,120,255); stroke.Parent=f
    local sh=Instance.new("ImageLabel"); sh.BackgroundTransparency=1; sh.Image="rbxassetid://1316045217"; sh.ScaleType=Enum.ScaleType.Slice; sh.SliceCenter=Rect.new(10,10,118,118); sh.ImageTransparency=0.5; sh.Size=UDim2.new(1,30,1,30); sh.Position=UDim2.new(0,-15,0,-15); sh.ZIndex=0; sh.Parent=f
    Instance.new("UICorner",f).CornerRadius=UDim.new(0,10)
    local l=Instance.new("TextLabel"); l.BackgroundTransparency=1; l.Size=UDim2.new(1,-24,1,-22); l.Position=UDim2.new(0,12,0,11); l.Text=msg; l.TextScaled=true; l.TextColor3=Color3.new(1,1,1); l.Font=Enum.Font.GothamSemibold; l.Parent=f
    f.Position=UDim2.new(0.5,-170,1,0)
    TweenService:Create(f,TweenInfo.new(0.28,Enum.EasingStyle.Back),{Position=UDim2.new(0.5,-170,1,-100)}):Play()
    task.delay(3,function() local tw=TweenService:Create(f,TweenInfo.new(0.25),{Position=UDim2.new(0.5,-170,1,0)}); tw:Play(); tw.Completed:Once(function() safeDestroy(gui) end) end)
end

-- player ESP
local playerESPEnabled=false
local playerESPData={}; local lastPEspUpd=0
local function newHighlightPlayer(char) local h=newHighlight(char); h.FillColor=Color3.new(1,0,0); return h end
local function makeBillboard(p)
    local bb=Instance.new("BillboardGui"); bb.Name="ESPPlayerBillboard"; bb.AlwaysOnTop=true; bb.Size=UDim2.fromOffset(180,42); bb.StudsOffsetWorldSpace=Vector3.new(0,3.2,0); bb.MaxDistance=3000
    local holder=Instance.new("Frame"); holder.Name="Holder"; holder.BackgroundColor3=Color3.fromRGB(22,22,26); holder.BackgroundTransparency=0.18; holder.Size=UDim2.fromScale(1,1); holder.Parent=bb
    Instance.new("UICorner",holder).CornerRadius=UDim.new(0,6)
    local stroke=Instance.new("UIStroke"); stroke.Thickness=1.5; stroke.Color=Color3.fromRGB(70,70,80); stroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Border; stroke.Parent=holder
    local lbl=Instance.new("TextLabel"); lbl.BackgroundTransparency=1; lbl.Size=UDim2.fromScale(1,1); lbl.TextScaled=true; lbl.Font=Enum.Font.GothamBold; lbl.TextColor3=Color3.new(1,1,1); lbl.TextStrokeTransparency=0.4; lbl.TextXAlignment=Enum.TextXAlignment.Center; lbl.Text=p.Name; lbl.Parent=holder
    return bb,lbl
end
local function ensurePlayerESP(uid)
    local d=playerESPData[uid]; if not d then return end
    if not isValid(d.hl) and d.p and d.p.Character then d.hl=newHighlightPlayer(d.p.Character) end
    if not isValid(d.line) then d.line=getLine() end
    if not (isValid(d.bb) and isValid(d.lbl)) then
        local bb,lbl=makeBillboard(d.p); local hrp=d.p.Character and d.p.Character:FindFirstChild("HumanoidRootPart")
        if hrp then bb.Adornee=hrp end; bb.Parent=workspace; d.bb,d.lbl=bb,lbl
    end
end
local function createPlayerESP(p)
    if p==LP or playerESPData[p.UserId] then return end
    local char=p.Character if not char then return end
    local hrp=char:FindFirstChild("HumanoidRootPart") if not hrp then return end
    local hl=newHighlightPlayer(char); local line=getLine(); local bb,lbl=makeBillboard(p); bb.Adornee=hrp; bb.Parent=workspace
    playerESPData[p.UserId]={p=p,hl=hl,line=line,bb=bb,lbl=lbl}
end
local function clearPlayerESP() for _,d in pairs(playerESPData) do safeDestroy(d.hl) freeLine(d.line) safeDestroy(d.bb) end table.clear(playerESPData) end
local function updatePlayerESPLines()
    local now=time(); if now-lastPEspUpd<1/PLAYER_LINE_FPS then return end; lastPEspUpd=now
    local myHRP=LP.Character and LP.Character:FindFirstChild("HumanoidRootPart"); if not myHRP then return end
    local myPos=myHRP.Position; local toRemove={}
    for uid,d in pairs(playerESPData) do
        local p=d.p; local char=p and p.Character; local hrp=char and char:FindFirstChild("HumanoidRootPart")
        if not (p and char and hrp) then table.insert(toRemove,uid) else
            ensurePlayerESP(uid)
            if isValid(d.line) then
                local tpos=hrp.Position; local dir=tpos-myPos; local dist=dir.Magnitude
                d.line.Size=Vector3.new(0.25,0.25,dist); d.line.CFrame=CFrame.lookAt(myPos+dir*0.5,tpos)
                if isValid(d.bb) and isValid(d.lbl) then if d.bb.Adornee~=hrp then d.bb.Adornee=hrp end; d.lbl.Text=string.format("%s  •  %dst",p.Name,dist and math.floor(dist) or 0) end
            end
        end
    end
    for _,uid in ipairs(toRemove) do local d=playerESPData[uid]; if d then safeDestroy(d.hl) freeLine(d.line) safeDestroy(d.bb) playerESPData[uid]=nil end end
end

-- ghost
local ghostEnabled=false
local function setCharTransp(char,t) for _,d in ipairs(char:GetDescendants()) do if d:IsA("BasePart") or d:IsA("Decal") then d.Transparency=t end if d:IsA("Accessory") then local h=d:FindFirstChild("Handle") if h then h.Transparency=t end end end end
local function ghostOn()  ghostEnabled=true;  if LP.Character then setCharTransp(LP.Character,0.7) end end
local function ghostOff() ghostEnabled=false; if LP.Character then setCharTransp(LP.Character,0.0) end end
safeConnect(LP.CharacterAdded,function(c) task.wait(0.2); if ghostEnabled then setCharTransp(c,0.7) end end)

-- theme ui
local theme={
    night={mainBg=Color3.fromRGB(18,18,22), headerBg=Color3.fromRGB(30,30,36), text=Color3.fromRGB(235,235,245), muted=Color3.fromRGB(170,170,180), switchOn=Color3.fromRGB(60,200,60), switchOff=Color3.fromRGB(85,85,95), btnReset=Color3.fromRGB(70,110,255), btnOff=Color3.fromRGB(90,90,95), stroke=Color3.fromRGB(70,70,80)},
    day  ={mainBg=Color3.fromRGB(245,245,250), headerBg=Color3.fromRGB(228,228,238), text=Color3.fromRGB(20,20,25), muted=Color3.fromRGB(70,70,80), switchOn=Color3.fromRGB(60,170,250), switchOff=Color3.fromRGB(180,180,190), btnReset=Color3.fromRGB(255,120,80), btnOff=Color3.fromRGB(180,180,190), stroke=Color3.fromRGB(180,180,190)}
}
local themeModeNight=true

-- game night
local gameNightEnabled=false; local nightConn; local _origLighting={}
local function captureLighting()
    _origLighting.ClockTime=Lighting.ClockTime; _origLighting.Brightness=Lighting.Brightness
    _origLighting.Ambient=Lighting.Ambient; _origLighting.OutdoorAmbient=Lighting.OutdoorAmbient
    _origLighting.EnvironmentDiffuseScale=Lighting.EnvironmentDiffuseScale; _origLighting.EnvironmentSpecularScale=Lighting.EnvironmentSpecularScale
    _origLighting.FogStart=Lighting.FogStart; _origLighting.FogEnd=Lighting.FogEnd
end
local function applyNightLook()
    Lighting.ClockTime=22.5; Lighting.Brightness=1.8; Lighting.Ambient=Color3.fromRGB(40,40,60); Lighting.OutdoorAmbient=Color3.fromRGB(0,0,0)
    Lighting.EnvironmentDiffuseScale=0.2; Lighting.EnvironmentSpecularScale=0.25
    if not Lighting:FindFirstChild("ESP_NightCC") then local cc=Instance.new("ColorCorrectionEffect"); cc.Name="ESP_NightCC"; cc.Brightness=-0.05; cc.Contrast=0.12; cc.Saturation=-0.05; cc.TintColor=Color3.fromRGB(185,205,255); cc.Parent=Lighting end
end
local function removeNightPost() local cc=Lighting:FindFirstChild("ESP_NightCC"); if cc then pcall(function() cc:Destroy() end) end end
local function enableGameNight() if gameNightEnabled then return end; gameNightEnabled=true; captureLighting(); applyNightLook(); nightConn=RunService.RenderStepped:Connect(function() if gameNightEnabled then Lighting.ClockTime=22.5 end end) end
local function disableGameNight() gameNightEnabled=false; if nightConn then pcall(function() nightConn:Disconnect() end) nightConn=nil end; removeNightPost(); for k,v in pairs(_origLighting) do pcall(function() Lighting[k]=v end) end end

-- GUI
local gui=Instance.new("ScreenGui"); gui.Name="GUI_"..G.BRAINROT_ESP_NAME; gui.ResetOnSpawn=false; gui.Parent=playerGui
local main=Instance.new("Frame"); main.Size=UDim2.new(0,300,0,540); main.Position=UDim2.new(1,-310,0,12); main.Active=true; main.Draggable=true; main.Parent=gui
Instance.new("UICorner",main).CornerRadius=UDim.new(0,14)
local mainStroke=Instance.new("UIStroke"); mainStroke.Thickness=2; mainStroke.Color=theme.night.stroke; mainStroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Border; mainStroke.Parent=main
local mainShadow=Instance.new("ImageLabel"); mainShadow.BackgroundTransparency=1; mainShadow.Image="rbxassetid://1316045217"; mainShadow.ScaleType=Enum.ScaleType.Slice; mainShadow.SliceCenter=Rect.new(10,10,118,118); mainShadow.ImageTransparency=0.6; mainShadow.Size=UDim2.new(1,36,1,36); mainShadow.Position=UDim2.new(0,-18,0,-18); mainShadow.ZIndex=0; mainShadow.Parent=main
local header=Instance.new("Frame"); header.Size=UDim2.new(1,0,0,52); header.Parent=main; Instance.new("UICorner",header).CornerRadius=UDim.new(0,14)
local grad=Instance.new("UIGradient"); grad.Rotation=0; grad.Color=ColorSequence.new{ColorSequenceKeypoint.new(0,Color3.fromRGB(80,95,255)), ColorSequenceKeypoint.new(1,Color3.fromRGB(120,60,255))}; grad.Parent=header
local title=Instance.new("TextLabel"); title.BackgroundTransparency=1; title.Size=UDim2.new(1,-96,1,0); title.Position=UDim2.new(0,16,0,0); title.Text="ESP LITE+ • "..G.BRAINROT_ESP_VERSION; title.Font=Enum.Font.GothamBold; title.TextScaled=true; title.TextColor3=Color3.fromRGB(255,255,255); title.Parent=header
local minimize=Instance.new("TextButton"); minimize.Size=UDim2.new(0,34,0,34); minimize.Position=UDim2.new(1,-42,0.5,-17); minimize.Text="–"; minimize.Font=Enum.Font.GothamBold; minimize.TextScaled=true; minimize.TextColor3=Color3.fromRGB(255,255,255); minimize.BackgroundTransparency=0.15; minimize.Parent=header
Instance.new("UICorner",minimize).CornerRadius=UDim.new(0,8)

local body=Instance.new("ScrollingFrame"); body.Size=UDim2.new(1,-22,1,-140); body.Position=UDim2.new(0,11,0,64); body.Parent=main
body.Active=true; body.ScrollingEnabled=true; body.ScrollingDirection=Enum.ScrollingDirection.Y; body.CanvasSize=UDim2.new(0,0,0,0)
local hasAuto=pcall(function() body.AutomaticCanvasSize=Enum.AutomaticSize.Y end)
body.ScrollBarThickness=6; body.ScrollBarImageTransparency=0.2; body.ScrollBarImageColor3=Color3.fromRGB(120,120,140)
local pad=Instance.new("UIPadding"); pad.PaddingTop=UDim.new(0,8); pad.PaddingBottom=UDim.new(0,8); pad.PaddingLeft=UDim.new(0,8); pad.PaddingRight=UDim.new(0,8); pad.Parent=body
local list=Instance.new("UIListLayout"); list.SortOrder=Enum.SortOrder.LayoutOrder; list.Padding=UDim.new(0,10); list.Parent=body
if not hasAuto then local function updateCanvas() body.CanvasSize=UDim2.new(0,0,0,list.AbsoluteContentSize.Y+16) end; list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvas); task.defer(updateCanvas) end
local status=Instance.new("TextLabel"); status.BackgroundTransparency=1; status.Size=UDim2.new(1,-22,0,24); status.Position=UDim2.new(0,11,1,-30); status.Font=Enum.Font.Gotham; status.TextScaled=true; status.Parent=main

-- switches / botones
local function makeSwitch(labelText, defaultOn, tipText)
    local row=Instance.new("Frame"); row.Size=UDim2.new(1,0,0, tipText and 70 or 52); row.LayoutOrder=10; row.Parent=body
    local bg=Instance.new("Frame"); bg.Size=UDim2.fromScale(1,1); bg.BackgroundTransparency=0.05; bg.Parent=row
    Instance.new("UICorner",bg).CornerRadius=UDim.new(0,10)
    local stroke=Instance.new("UIStroke"); stroke.Thickness=1.5; stroke.Color=Color3.fromRGB(70,70,80); stroke.Parent=bg
    local l=Instance.new("TextLabel"); l.BackgroundTransparency=1; l.Position=UDim2.new(0,10,0,6); l.Size=UDim2.new(1,-100,0,26); l.Font=Enum.Font.GothamSemibold; l.TextScaled=true; l.TextXAlignment=Enum.TextXAlignment.Left; l.Text=labelText; l.Parent=bg
    local tip
    if tipText then tip=Instance.new("TextLabel"); tip.BackgroundTransparency=1; tip.Position=UDim2.new(0,10,0,36); tip.Size=UDim2.new(1,-100,0,18); tip.Font=Enum.Font.Gotham; tip.TextScaled=false; tip.TextSize=12; tip.TextXAlignment=Enum.TextXAlignment.Left; tip.Text=tipText; tip.TextTransparency=0.1; tip.Parent=bg end
    local sw=Instance.new("Frame"); sw.Size=UDim2.new(0,58,0,28); sw.Position=UDim2.new(1,-68,0.5,-14); sw.Parent=bg
    Instance.new("UICorner",sw).CornerRadius=UDim.new(1,0)
    local knob=Instance.new("Frame"); knob.Size=UDim2.new(0,24,0,24); knob.Position=UDim2.new(0,2,0,2); knob.Parent=sw
    Instance.new("UICorner",knob).CornerRadius=UDim.new(1,0)
    local btn=Instance.new("TextButton"); btn.BackgroundTransparency=1; btn.Size=UDim2.new(1,0,1,0); btn.Text=""; btn.Parent=sw
    local state=defaultOn
    local function setState(on) state=on; local t=themeModeNight and theme.night or theme.day; TweenService:Create(sw,TweenInfo.new(0.16),{BackgroundColor3=on and t.switchOn or t.switchOff}):Play(); TweenService:Create(knob,TweenInfo.new(0.16),{Position=on and UDim2.new(1,-26,0,2) or UDim2.new(0,2,0,2)}):Play() end
    setState(defaultOn)
    return {row=row,label=l,tip=tip,switch=sw,knob=knob,btn=btn,get=function() return state end,set=setState,bg=bg,stroke=stroke}
end
local function makeButton(text,color,order)
    local b=Instance.new("TextButton"); b.Size=UDim2.new(1,0,0,44); b.LayoutOrder=order or 100; b.BackgroundColor3=color; b.TextColor3=Color3.new(1,1,1); b.TextScaled=true; b.Font=Enum.Font.GothamBold; b.Text=text; b.Parent=body
    Instance.new("UICorner",b).CornerRadius=UDim.new(0,10)
    local st=Instance.new("UIStroke"); st.Thickness=1.8; st.Color=Color3.fromRGB(20,20,28); st.Parent=b
    return b
end

local swNight     = makeSwitch("Tema UI: Noche", true, "Tema oscuro (solo interfaz)")
local swGameNight = makeSwitch("Modo Noche (Juego)", false, "Fuerza noche en el mundo (cliente)")
local swESP       = makeSwitch("ESP Brainrots", false, "Marca brainrots 15s (sin límite)")
local swCont      = makeSwitch("Búsqueda continua", true, "Refuerza el escaneo")
local swNotif     = makeSwitch("Notificaciones", true, "Alerta al entrar jugadores")
local swPlayer    = makeSwitch("ESP de jugadores", false, "Línea + nombre + distancia + highlight")
local swXRay      = makeSwitch("X-RAY del mapa (80%)", false, "Oculta mapa sin brainrots")
local swGhost     = makeSwitch("Espíritu (Yo 70%)", false, "Transparencia personaje")
local swSky       = makeSwitch("Sky predeterminado (Roblox)", false, "Forzar sky azul y bloquear reemplazos")
local swPotato    = makeSwitch("Gráficos suaves (Potato)", false, "Optimiza el MAPA para FPS")

local btnReset=makeButton("RESET ESP", Color3.fromRGB(70,110,255), 200)
local btnUnload=makeButton("UNLOAD", Color3.fromRGB(90,90,95), 201)

-- min/max
local collapsed=false
minimize.MouseButton1Click:Connect(function()
    collapsed=not collapsed
    if collapsed then TweenService:Create(main,TweenInfo.new(0.22),{Size=UDim2.new(0,300,0,112)}):Play(); body.Visible=false; status.Visible=false; minimize.Text="+"
    else TweenService:Create(main,TweenInfo.new(0.22),{Size=UDim2.new(0,300,0,540)}):Play(); task.wait(0.22); body.Visible=true; status.Visible=true; minimize.Text="–" end
end)

-- [T]
local function setGuiVisible(v) main.Visible=v end
setGuiVisible(true)
safeConnect(UserInput.InputBegan,function(inp,gp) if gp then return end if inp.KeyCode==Enum.KeyCode.T then setGuiVisible(not main.Visible) end end)

-- aplicar tema
local function applyTheme()
    local t=themeModeNight and theme.night or theme.day
    main.BackgroundColor3=t.mainBg; mainStroke.Color=t.stroke; title.TextColor3=t.text; minimize.TextColor3=Color3.fromRGB(255,255,255); status.TextColor3=t.muted; header.BackgroundColor3=t.headerBg
    local sws={swNight,swGameNight,swESP,swCont,swNotif,swPlayer,swXRay,swGhost,swSky,swPotato}
    for _,s in ipairs(sws) do
        if s.label then s.label.TextColor3=t.text end
        if s.tip then s.tip.TextColor3=t.muted end
        if s.stroke then s.stroke.Color=t.stroke end
        s.set(s.get()); s.knob.BackgroundColor3=Color3.new(1,1,1)
        s.bg.BackgroundColor3=themeModeNight and Color3.fromRGB(22,22,28) or Color3.fromRGB(250,250,255)
    end
    btnReset.BackgroundColor3=themeModeNight and theme.night.btnReset or theme.day.btnReset
    btnUnload.BackgroundColor3=themeModeNight and theme.night.btnOff or theme.day.btnOff
end
applyTheme()

-- ===== Sky predeterminado (FORZADO) =====
local defaultSkyEnabled=false
local removedSkies={}
local skyGuardianConn
local skyAddedConn

local function createDefaultSky()
    local sky=Lighting:FindFirstChild("ESP_DefaultSky")
    if not sky then
        sky=Instance.new("Sky")
        sky.Name="ESP_DefaultSky"
        sky.SkyboxBk="rbxasset://textures/sky/skybox_back.png"
        sky.SkyboxDn="rbxasset://textures/sky/skybox_down.png"
        sky.SkyboxFt="rbxasset://textures/sky/skybox_front.png"
        sky.SkyboxLf="rbxasset://textures/sky/skybox_left.png"
        sky.SkyboxRt="rbxasset://textures/sky/skybox_right.png"
        sky.SkyboxUp="rbxasset://textures/sky/skybox_up.png"
        sky.Parent=Lighting
    end
    return sky
end
local function stashAndRemoveSky(inst) if removedSkies[inst]==nil then removedSkies[inst]=inst.Parent end; inst.Parent=nil end
local function removeAllSkiesExceptDefault() for _,d in ipairs(Lighting:GetDescendants()) do if d:IsA("Sky") and d.Name~="ESP_DefaultSky" then stashAndRemoveSky(d) end end end
local function applyDefaultSkyForced()
    removeAllSkiesExceptDefault(); createDefaultSky()
    if not skyGuardianConn then
        skyGuardianConn = RunService.RenderStepped:Connect(function()
            if not defaultSkyEnabled then return end
            if not Lighting:FindFirstChild("ESP_DefaultSky") then createDefaultSky() end
            for _,d in ipairs(Lighting:GetChildren()) do if d:IsA("Sky") and d.Name~="ESP_DefaultSky" then stashAndRemoveSky(d) end end
        end)
    end
    if not skyAddedConn then
        skyAddedConn = Lighting.DescendantAdded:Connect(function(obj)
            if not defaultSkyEnabled then return end
            if obj:IsA("Sky") and obj.Name~="ESP_DefaultSky" then stashAndRemoveSky(obj) end
        end)
    end
end
local function restoreOriginalSkies()
    if skyGuardianConn then pcall(function() skyGuardianConn:Disconnect() end); skyGuardianConn=nil end
    if skyAddedConn then pcall(function() skyAddedConn:Disconnect() end); skyAddedConn=nil end
    local def=Lighting:FindFirstChild("ESP_DefaultSky"); if def then pcall(function() def:Destroy() end) end
    for inst,parent in pairs(removedSkies) do if inst and parent then pcall(function() inst.Parent=parent end) end end
    table.clear(removedSkies)
end

-- ====== GRÁFICOS SUAVES (POTATO) — MAPA ======
local potatoOn=false

-- Presupuestos de procesado para no lag
local POTATO_SCAN_BUDGET = 1000  -- nodos por Heartbeat

-- Copias de estado para restaurar
local P_ORIG = { -- claves por instancia: {prop = valorOriginal}
    CastShadow = setmetatable({}, {__mode="k"}),
    RenderFidelity = setmetatable({}, {__mode="k"}),
    LightEnabled = setmetatable({}, {__mode="k"}),
    ParticleEnabled = setmetatable({}, {__mode="k"}),
    ParticleRate = setmetatable({}, {__mode="k"}),
    TrailEnabled = setmetatable({}, {__mode="k"}),
    BeamEnabled = setmetatable({}, {__mode="k"}),
    DecalTransparency = setmetatable({}, {__mode="k"}),
    TextureTransparency = setmetatable({}, {__mode="k"}),
}

-- cola de candidatos para aplicar Potato de forma incremental
local POTATO_QUEUE, pqh, pqt = {},1,0
local function pq_push(x) pqt+=1; POTATO_QUEUE[pqt]=x end
local function pq_pop() if pqh<=pqt then local v=POTATO_QUEUE[pqh]; POTATO_QUEUE[pqh]=nil; pqh+=1; return v end end
local function pq_reset() for i=pqh,pqt do POTATO_QUEUE[i]=nil end pqh,pqt=1,0 end

-- detectar si un nodo es “brainrot” o está dentro de uno (no tocar)
local function inBrainrot(n) return hasBrainrotAncestor(n) or (isBrainrotNode(n) and targetSet[n.Name]) end

-- aplicar optimización a un solo objeto
local function potatoApplyOne(obj)
    if not isValid(obj) then return end
    if inBrainrot(obj) then return end  -- no degradar nuestros objetivos

    if obj:IsA("MeshPart") then
        if P_ORIG.RenderFidelity[obj]==nil then P_ORIG.RenderFidelity[obj]=obj.RenderFidelity end
        obj.RenderFidelity = Enum.RenderFidelity.Performance
        if P_ORIG.CastShadow[obj]==nil then P_ORIG.CastShadow[obj]=obj.CastShadow end
        obj.CastShadow=false
    elseif obj:IsA("BasePart") then
        if P_ORIG.CastShadow[obj]==nil then P_ORIG.CastShadow[obj]=obj.CastShadow end
        obj.CastShadow=false
    elseif obj:IsA("PointLight") or obj:IsA("SpotLight") or obj:IsA("SurfaceLight") then
        if P_ORIG.LightEnabled[obj]==nil then P_ORIG.LightEnabled[obj]=obj.Enabled end
        obj.Enabled=false
    elseif obj:IsA("ParticleEmitter") then
        if P_ORIG.ParticleEnabled[obj]==nil then P_ORIG.ParticleEnabled[obj]=obj.Enabled end
        if P_ORIG.ParticleRate[obj]==nil then P_ORIG.ParticleRate[obj]=obj.Rate end
        obj.Enabled=false; obj.Rate=0
    elseif obj:IsA("Trail") then
        if P_ORIG.TrailEnabled[obj]==nil then P_ORIG.TrailEnabled[obj]=obj.Enabled end
        obj.Enabled=false
    elseif obj:IsA("Beam") then
        if P_ORIG.BeamEnabled[obj]==nil then P_ORIG.BeamEnabled[obj]=obj.Enabled end
        obj.Enabled=false
    elseif obj:IsA("Decal") then
        if P_ORIG.DecalTransparency[obj]==nil then P_ORIG.DecalTransparency[obj]=obj.Transparency end
        obj.Transparency = math.clamp((obj.Transparency or 0)+0.35, 0, 1)
    elseif obj.ClassName=="Texture" then
        if P_ORIG.TextureTransparency[obj]==nil then P_ORIG.TextureTransparency[obj]=obj.Transparency end
        obj.Transparency = math.clamp((obj.Transparency or 0)+0.35, 0, 1)
    end
end

-- recorrer Lighting y desactivar post-procesos costosos (con restore)
local L_ORIG = { Effects = {}, Atmospheres = {}, Props = {} }

local function potatoLightingOn()
    -- guardar y desactivar efectos
    for _,d in ipairs(Lighting:GetDescendants()) do
        if d:IsA("BloomEffect") or d:IsA("SunRaysEffect") or d:IsA("DepthOfFieldEffect") or d:IsA("BlurEffect") or d:IsA("ColorCorrectionEffect") then
            table.insert(L_ORIG.Effects, {inst=d, enabled=d.Enabled})
            d.Enabled=false
        elseif d:IsA("Atmosphere") then
            table.insert(L_ORIG.Atmospheres, d)
        end
    end
    -- quitar Atmospheres (guardadas arriba)
    for _,atm in ipairs(L_ORIG.Atmospheres) do pcall(function() atm.Parent=nil end) end
    -- props Lighting menos costosos
    L_ORIG.Props.ClockTime = Lighting.ClockTime
    L_ORIG.Props.Brightness = Lighting.Brightness
    L_ORIG.Props.EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale
    L_ORIG.Props.EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale
    L_ORIG.Props.ShadowSoftness = Lighting.ShadowSoftness
    Lighting.Brightness = math.min(2, Lighting.Brightness)
    Lighting.EnvironmentSpecularScale = 0
    Lighting.EnvironmentDiffuseScale = 0.2
    Lighting.ShadowSoftness = 0
    -- Terrain agua
    local Terrain = workspace and workspace:FindFirstChildOfClass("Terrain")
    if Terrain then
        L_ORIG.Props.WaterWaveSize = Terrain.WaterWaveSize
        L_ORIG.Props.WaterWaveSpeed = Terrain.WaterWaveSpeed
        L_ORIG.Props.WaterReflectance = Terrain.WaterReflectance
        L_ORIG.Props.WaterTransparency = Terrain.WaterTransparency
        Terrain.WaterWaveSize = 0
        Terrain.WaterWaveSpeed = 0
        Terrain.WaterReflectance = 0
        Terrain.WaterTransparency = 0.5
    end
end

local function potatoLightingOff()
    for _,e in ipairs(L_ORIG.Effects) do if isValid(e.inst) then e.inst.Enabled=e.enabled end end
    for _,atm in ipairs(L_ORIG.Atmospheres) do if atm then pcall(function() atm.Parent=Lighting end) end end
    if L_ORIG.Props then
        pcall(function()
            if L_ORIG.Props.ClockTime then Lighting.ClockTime=L_ORIG.Props.ClockTime end
            if L_ORIG.Props.Brightness then Lighting.Brightness=L_ORIG.Props.Brightness end
            if L_ORIG.Props.EnvironmentSpecularScale then Lighting.EnvironmentSpecularScale=L_ORIG.Props.EnvironmentSpecularScale end
            if L_ORIG.Props.EnvironmentDiffuseScale then Lighting.EnvironmentDiffuseScale=L_ORIG.Props.EnvironmentDiffuseScale end
            if L_ORIG.Props.ShadowSoftness then Lighting.ShadowSoftness=L_ORIG.Props.ShadowSoftness end
        end)
        local Terrain = workspace and workspace:FindFirstChildOfClass("Terrain")
        if Terrain then
            pcall(function()
                if L_ORIG.Props.WaterWaveSize~=nil then Terrain.WaterWaveSize=L_ORIG.Props.WaterWaveSize end
                if L_ORIG.Props.WaterWaveSpeed~=nil then Terrain.WaterWaveSpeed=L_ORIG.Props.WaterWaveSpeed end
                if L_ORIG.Props.WaterReflectance~=nil then Terrain.WaterReflectance=L_ORIG.Props.WaterReflectance end
                if L_ORIG.Props.WaterTransparency~=nil then Terrain.WaterTransparency=L_ORIG.Props.WaterTransparency end
            end)
        end
    end
    L_ORIG.Effects, L_ORIG.Atmospheres = {}, {}
end

-- encolas candidatos (mapa) respetando brainrots
function enqueuePotatoCandidate(root)
    if not isValid(root) then return end
    if inBrainrot(root) then return end
    pq_push(root)
    for _,ch in ipairs(root:GetDescendants()) do
        if isValid(ch) and not inBrainrot(ch) then pq_push(ch) end
    end
end

-- proceso incremental por frame
local function processPotatoQueueStep()
    local budget = POTATO_SCAN_BUDGET
    while budget>0 do
        local node = pq_pop()
        if not node then break end
        potatoApplyOne(node)
        budget -= 1
    end
end

-- limpiar/restaurar estado en todo lo tocado
local function potatoRestoreAll()
    for inst,val in pairs(P_ORIG.CastShadow) do if isValid(inst) then pcall(function() inst.CastShadow=val end) end; P_ORIG.CastShadow[inst]=nil end
    for inst,val in pairs(P_ORIG.RenderFidelity) do if isValid(inst) then pcall(function() inst.RenderFidelity=val end) end; P_ORIG.RenderFidelity[inst]=nil end
    for inst,val in pairs(P_ORIG.LightEnabled) do if isValid(inst) then pcall(function() inst.Enabled=val end) end; P_ORIG.LightEnabled[inst]=nil end
    for inst,val in pairs(P_ORIG.ParticleEnabled) do if isValid(inst) then pcall(function() inst.Enabled=val end) end; P_ORIG.ParticleEnabled[inst]=nil end
    for inst,val in pairs(P_ORIG.ParticleRate) do if isValid(inst) then pcall(function() inst.Rate=val end) end; P_ORIG.ParticleRate[inst]=nil end
    for inst,val in pairs(P_ORIG.TrailEnabled) do if isValid(inst) then pcall(function() inst.Enabled=val end) end; P_ORIG.TrailEnabled[inst]=nil end
    for inst,val in pairs(P_ORIG.BeamEnabled) do if isValid(inst) then pcall(function() inst.Enabled=val end) end; P_ORIG.BeamEnabled[inst]=nil end
    for inst,val in pairs(P_ORIG.DecalTransparency) do if isValid(inst) then pcall(function() inst.Transparency=val end) end; P_ORIG.DecalTransparency[inst]=nil end
    for inst,val in pairs(P_ORIG.TextureTransparency) do if isValid(inst) then pcall(function() inst.Transparency=val end) end; P_ORIG.TextureTransparency[inst]=nil end
    pq_reset()
end

-- activar/desactivar Potato MAPA
local function applyPotato(on)
    potatoOn = on
    if on then
        potatoLightingOn()
        enqueuePotatoCandidate(workspace)
        toast("🧪 Gráficos suaves (MAPA) activados")
        -- bloquear X-RAY si estuviera encendido (ambos manipulan el mapa)
        if xrayEnabled then disableXRay(); swXRay.set(false) end
    else
        potatoLightingOff()
        potatoRestoreAll()
        toast("✨ Gráficos del mapa restaurados")
    end
end
-- ======================================

-- estado toggles
local espEnabled=false; local contEnabled=true; local notifEnabled=true

-- lógica switches
swNight.btn.MouseButton1Click:Connect(function() themeModeNight=not themeModeNight; applyTheme() end)
swGameNight.btn.MouseButton1Click:Connect(function() local on=not swGameNight.get(); swGameNight.set(on); if on then enableGameNight() else disableGameNight() end end)
swESP.btn.MouseButton1Click:Connect(function()
    espEnabled=not espEnabled; swESP.set(espEnabled)
    if espEnabled then startScan(); toast("ESP activado (15s)")
    else for inst,data in pairs(activeMarks) do safeDestroy(data.hl) activeMarks[inst]=nil end; for inst,s in pairs(specialBrainrotLines) do freeLine(s.line) specialBrainrotLines[inst]=nil end; toast("ESP desactivado") end
end)
swCont.btn.MouseButton1Click:Connect(function() contEnabled=not contEnabled; swCont.set(contEnabled) end)
swNotif.btn.MouseButton1Click:Connect(function() notifEnabled=not notifEnabled; swNotif.set(notifEnabled) end)
swPlayer.btn.MouseButton1Click:Connect(function() playerESPEnabled=not playerESPEnabled; swPlayer.set(playerESPEnabled); if playerESPEnabled then for _,p in ipairs(Players:GetPlayers()) do if p~=LP then createPlayerESP(p) end end else clearPlayerESP() end end)
swXRay.btn.MouseButton1Click:Connect(function()
    if potatoOn then toast("⚠️ X-RAY bloqueado en modo Gráficos suaves (MAPA)"); swXRay.set(false); return end
    xrayEnabled=not xrayEnabled; swXRay.set(xrayEnabled); if xrayEnabled then enableXRay() else disableXRay() end
end)
swGhost.btn.MouseButton1Click:Connect(function() if ghostEnabled then ghostOff() else ghostOn() end; swGhost.set(ghostEnabled) end)
swSky.btn.MouseButton1Click:Connect(function()
    defaultSkyEnabled=not defaultSkyEnabled; swSky.set(defaultSkyEnabled)
    if defaultSkyEnabled then applyDefaultSkyForced(); toast("🌤️ Sky Roblox forzado")
    else restoreOriginalSkies(); toast("☁️ Sky original restaurado") end
end)
swPotato.btn.MouseButton1Click:Connect(function() local on = not swPotato.get(); swPotato.set(on); applyPotato(on) end)

-- reset / unload
local function RESET_ESP()
    for inst,data in pairs(activeMarks) do safeDestroy(data.hl) activeMarks[inst]=nil end
    for inst,s in pairs(specialBrainrotLines) do freeLine(s.line) specialBrainrotLines[inst]=nil end
    if espEnabled then startScan() end
    toast("ESP reseteado", Color3.fromRGB(120,180,255))
end
local function UNLOAD()
    if xrayEnabled then disableXRay() end
    if ghostEnabled then ghostOff() end
    if playerESPEnabled then clearPlayerESP() end
    if gameNightEnabled then disableGameNight() end
    if defaultSkyEnabled then restoreOriginalSkies() end
    if potatoOn then applyPotato(false) end
    for inst,data in pairs(activeMarks) do safeDestroy(data.hl) activeMarks[inst]=nil end
    for inst,s in pairs(specialBrainrotLines) do freeLine(s.line) specialBrainrotLines[inst]=nil end
    disconnectAll(); safeDestroy(gui); G.__BRAINROT_ESP_RUNNING=false; toast("ESP descargado", Color3.fromRGB(180,90,90))
end
local btnReset=body:FindFirstChildWhichIsA("TextButton") or nil -- ya creado arriba
btnReset.MouseButton1Click:Connect(RESET_ESP)
btnUnload.MouseButton1Click:Connect(UNLOAD)
G.BRAINROT_UNLOAD=UNLOAD

-- eventos players
safeConnect(Players.PlayerAdded,function(p)
    if notifEnabled then playNotificationSound(); toast("🚨 "..p.Name.." se unió") end
    if playerESPEnabled then task.wait(0.25); createPlayerESP(p) end
    p.CharacterAdded:Connect(function()
        if playerESPEnabled then task.wait(0.2); local d=playerESPData[p.UserId]; if d then safeDestroy(d.hl) freeLine(d.line) safeDestroy(d.bb) playerESPData[p.UserId]=nil end; createPlayerESP(p) end
    end)
end)
safeConnect(Players.PlayerRemoving,function(p) local d=playerESPData[p.UserId]; if d then safeDestroy(d.hl) freeLine(d.line) safeDestroy(d.bb) playerESPData[p.UserId]=nil end end)
for _,p in ipairs(Players:GetPlayers()) do if p~=LP then p.CharacterAdded:Connect(function() if playerESPEnabled then task.wait(0.2); local d=playerESPData[p.UserId]; if d then safeDestroy(d.hl) freeLine(d.line) safeDestroy(d.bb) playerESPData[p.UserId]=nil end; createPlayerESP(p) end end) end end

-- loop principal
local lastCont=0
safeConnect(RunService.Heartbeat,function()
    local tNow = time()
    rainbowHue=(rainbowHue+0.02)%1
    if espEnabled then
        processScanStep(); updateColors(); cleanupExpired(); cleanupBrainrotRoots()
        if contEnabled and qempty() and tNow-lastCont>=CONT_SCAN_PERIOD then lastCont=tNow; qpush(workspace) end
        local myHRP=LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        if myHRP then
            local myPos=myHRP.Position
            for inst,pack in pairs(specialBrainrotLines) do
                local L=pack.line
                if isValid(inst) and isValid(L) and activeMarks[inst] then
                    local tpos=getWorldPos(inst)
                    if tpos then
                        local dir=tpos-myPos; local dist=dir.Magnitude
                        L.Size=Vector3.new(0.28,0.28,math.max(dist,0.5))
                        L.CFrame=CFrame.lookAt(myPos+dir*0.5,tpos)
                        local s = 0.5 + 0.5 * math.sin(tNow * SPECIAL_PULSE_SPEED)
                        s = s*0.7
                        L.Color = pack.baseLine:Lerp(RED_STRONG, s)
                    end
                else
                    freeLine(L); specialBrainrotLines[inst]=nil
                end
            end
        end
    end
    if potatoOn then processPotatoQueueStep() end
    if playerESPEnabled then updatePlayerESPLines() end
    local cB,cP=0,0; for _ in pairs(activeMarks) do cB+=1 end; for _ in pairs(playerESPData) do cP+=1 end
    status.Text=string.format("Brainrots activos: %d  |  Players ESP: %d  |  Potato MAPA:%s  |  [T] UI", cB, cP, potatoOn and "ON" or "OFF")
end)
