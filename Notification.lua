--// =========================
--//  ESP LITE+ FINAL (Highlight 15s, Notifs, X-Ray, Ghost, ESP Player)
--// =========================

-- Servicios
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Parámetros
local MARK_DURATION = 15
local RAINBOW_SPEED = 0.35
local SCAN_STEP_BUDGET = 1200
local CONT_SCAN_PERIOD = 2
local PLAYER_LINE_FPS = 30
local XRAY_TRANSPARENCY = 0.8

-- Utilidades
local function isInstance(x) return typeof(x)=="Instance" end
local function isValid(inst) return isInstance(inst) and inst.Parent and inst:IsDescendantOf(game) end
local function safeDestroy(x) if isInstance(x) and x.Destroy then x:Destroy() end end
local function hsv(h) return Color3.fromHSV(h,1,1) end

-- Targets
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

-- Estado
local rainbowHue = 0
local everMarked = setmetatable({}, {__mode="k"})
local activeMarks = setmetatable({}, {__mode="k"})

-- Cola BFS
local scanQueue = {}
local qh, qt = 1, 0
local function qpush(x) qt+=1; scanQueue[qt]=x end
local function qpop() if qh<=qt then local v=scanQueue[qh]; scanQueue[qh]=nil; qh+=1; return v end end
local function qempty() return qh>qt end
local function qreset() for i=qh,qt do scanQueue[i]=nil end qh,qt=1,0 end

-- Notificaciones
local notifSound = Instance.new("Sound")
notifSound.SoundId = "rbxassetid://77665577458181"
notifSound.Volume = 0.7
notifSound.Parent = playerGui

local function playNotificationSound() pcall(function() notifSound:Play() end) end
local function toast(msg)
    local gui = Instance.new("ScreenGui", playerGui)
    local f = Instance.new("Frame", gui)
    f.Size = UDim2.new(0,320,0,85)
    f.Position = UDim2.new(0.5,-160,1,-95)
    f.BackgroundColor3 = Color3.fromRGB(40,40,40)
    f.BorderSizePixel = 0
    local c = Instance.new("UICorner", f) c.CornerRadius = UDim.new(0,10)
    local l = Instance.new("TextLabel", f)
    l.BackgroundTransparency = 1
    l.Size = UDim2.new(1,-20,1,-20)
    l.Position = UDim2.new(0,10,0,10)
    l.Text = msg
    l.TextScaled = true
    l.TextColor3 = Color3.new(1,1,1)
    l.Font = Enum.Font.Gotham
    f.Position = UDim2.new(0.5,-160,1,0)
    TweenService:Create(f, TweenInfo.new(0.3, Enum.EasingStyle.Back), {Position=UDim2.new(0.5,-160,1,-95)}):Play()
    task.delay(3.5, function()
        local tw = TweenService:Create(f,TweenInfo.new(0.3),{Position=UDim2.new(0.5,-160,1,0)})
        tw:Play()
        tw.Completed:Once(function() safeDestroy(gui) end)
    end)
end

-- Highlight
local function newHighlight(target)
    local h = Instance.new("Highlight")
    h.Adornee = target
    h.FillTransparency = 0.45
    h.OutlineTransparency = 0.15
    h.OutlineColor = Color3.new(1,1,1)
    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    h.Parent = workspace
    return h
end

local function markOnce(inst)
    if not isValid(inst) or everMarked[inst] then return end
    if not (inst:IsA("Model") or inst:IsA("BasePart")) or not targetSet[inst.Name] then return end
    everMarked[inst] = true
    local hl = newHighlight(inst)
    hl.FillColor = hsv(rainbowHue)
    activeMarks[inst] = {hl=hl, createdAt=time(), baseHue=rainbowHue}
end

workspace.DescendantAdded:Connect(function(i)
    if targetSet[i.Name] and (i:IsA("Model") or i:IsA("BasePart")) then markOnce(i) end
end)

local function processScanStep()
    local budget = SCAN_STEP_BUDGET
    while budget>0 do
        local node = qpop()
        if not node then break end
        if isValid(node) then
            if targetSet[node.Name] then markOnce(node) end
            for _,ch in ipairs(node:GetChildren()) do if isValid(ch) then qpush(ch) end end
        end
        budget-=1
    end
end
local function startScan() qreset(); qpush(workspace) end

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

-- Player ESP
local linePool = {}
local function getLine()
    local l = table.remove(linePool)
    if l then l.Parent = workspace return l end
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

local playerESPEnabled=false
local playerESPData={}
local function createPlayerESP(p)
    if p==player or playerESPData[p.UserId] then return end
    local char=p.Character if not char then return end
    local hrp=char:FindFirstChild("HumanoidRootPart") if not hrp then return end
    local hl=newHighlight(char) hl.FillColor=Color3.new(1,0,0)
    local line=getLine()
    playerESPData[p.UserId]={p=p,hl=hl,line=line}
end
local function updatePlayerESPLines()
    local myHRP = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not myHRP then return end
    local myPos = myHRP.Position
    for uid,d in pairs(playerESPData) do
        local p=d.p; local hrp=p.Character and p.Character:FindFirstChild("HumanoidRootPart")
        if not (p and hrp and isValid(d.hl) and isValid(d.line)) then
            safeDestroy(d.hl) freeLine(d.line) playerESPData[uid]=nil
        else
            local tp=hrp.Position
            local dir=tp-myPos
            d.line.Size=Vector3.new(0.08,0.08,dir.Magnitude)
            d.line.CFrame=CFrame.lookAt(myPos+dir*0.5,tp)
        end
    end
end
local function clearPlayerESP() for _,d in pairs(playerESPData) do safeDestroy(d.hl) freeLine(d.line) end playerESPData={} end

-- X-RAY con LocalTransparencyModifier (no revivir invisibles)
local xrayEnabled=false
local originalLTM=setmetatable({}, {__mode="k"})
local function shouldIgnore(i) return i:IsDescendantOf(playerGui) or i:IsDescendantOf(Players) end
local function isBrainrot(i) return targetSet[i.Name] and (i:IsA("Model") or i:IsA("BasePart")) end
local function setLTM(p,v)
    if originalLTM[p]==nil then originalLTM[p]=p.LocalTransparencyModifier end
    p.LocalTransparencyModifier=math.max(p.LocalTransparencyModifier,v)
end
local function applyXRay(n)
    if shouldIgnore(n) or isBrainrot(n) then return end
    if n:IsA("BasePart") then setLTM(n,XRAY_TRANSPARENCY) end
    for _,c in ipairs(n:GetChildren()) do applyXRay(c) end
end
local function restoreXRay(n)
    if n:IsA("BasePart") and originalLTM[n]~=nil then n.LocalTransparencyModifier=originalLTM[n]; originalLTM[n]=nil end
    for _,c in ipairs(n:GetChildren()) do restoreXRay(c) end
end
local function enableXRay() xrayEnabled=true applyXRay(workspace) end
local function disableXRay() xrayEnabled=false restoreXRay(workspace) end
workspace.DescendantAdded:Connect(function(i)
    if xrayEnabled and not shouldIgnore(i) and not isBrainrot(i) and i:IsA("BasePart") then setLTM(i,XRAY_TRANSPARENCY) end
end)

-- Ghost
local ghostEnabled=false
local function setCharTransp(char,t)
    for _,d in ipairs(char:GetDescendants()) do
        if d:IsA("BasePart") or d:IsA("Decal") then d.Transparency=t end
        if d:IsA("Accessory") then local h=d:FindFirstChild("Handle") if h then h.Transparency=t end end
    end
end
local function ghostOn() ghostEnabled=true if player.Character then setCharTransp(player.Character,0.7) end end
local function ghostOff() ghostEnabled=false if player.Character then setCharTransp(player.Character,0) end end
player.CharacterAdded:Connect(function(c) task.wait(0.2) if ghostEnabled then setCharTransp(c,0.7) end end)

-- GUI
local gui=Instance.new("ScreenGui",playerGui) gui.ResetOnSpawn=false gui.Name="ESPPanel"
local f=Instance.new("Frame",gui) f.Size=UDim2.new(0,220,0,300) f.Position=UDim2.new(1,-230,0,10) f.BackgroundColor3=Color3.fromRGB(28,28,28) f.Active=true f.Draggable=true
Instance.new("UICorner",f).CornerRadius=UDim.new(0,8)
local title=Instance.new("TextLabel",f) title.Size=UDim2.new(1,0,0,30) title.Text="ESP LITE+" title.BackgroundColor3=Color3.fromRGB(45,45,45) title.TextColor3=Color3.new(1,1,1) title.TextScaled=true title.Font=Enum.Font.GothamBold Instance.new("UICorner",title).CornerRadius=UDim.new(0,8)
local function makeBtn(y,txt,col)
    local b=Instance.new("TextButton",f) b.Size=UDim2.new(1,-20,0,32) b.Position=UDim2.new(0,10,0,y) b.Text=txt b.TextScaled=true b.TextColor3=Color3.new(1,1,1) b.Font=Enum.Font.Gotham b.BackgroundColor3=col or Color3.fromRGB(255,60,60) Instance.new("UICorner",b).CornerRadius=UDim.new(0,6) return b end

local espBtn=makeBtn(40,"ESP: OFF")
local contBtn=makeBtn(80,"Búsqueda Continua: ON",Color3.fromRGB(60,200,60))
local notifBtn=makeBtn(120,"Notificaciones: ON",Color3.fromRGB(60,200,60))
local pBtn=makeBtn(160,"ESP Player: OFF")
local xBtn=makeBtn(200,"X-RAY MAP: OFF")
local gBtn=makeBtn(240,"GHOST (Yo): OFF")

local espEnabled=false
local contEnabled=true
local notifEnabled=true

espBtn.MouseButton1Click:Connect(function()
    espEnabled=not espEnabled
    if espEnabled then espBtn.Text="ESP: ON" espBtn.BackgroundColor3=Color3.fromRGB(60,200,60) startScan() toast("ESP ON (15s)") else espBtn.Text="ESP: OFF" espBtn.BackgroundColor3=Color3.fromRGB(255,60,60) for i,d in pairs(activeMarks) do safeDestroy(d.hl) activeMarks[i]=nil end toast("ESP OFF") end
end)
contBtn.MouseButton1Click:Connect(function() contEnabled=not contEnabled contBtn.Text=contEnabled and "Búsqueda Continua: ON" or "Búsqueda Continua: OFF" contBtn.BackgroundColor3=contEnabled and Color3.fromRGB(60,200,60) or Color3.fromRGB(255,60,60) end)
notifBtn.MouseButton1Click:Connect(function() notifEnabled=not notifEnabled notifBtn.Text=notifEnabled and "Notificaciones: ON" or "Notificaciones: OFF" notifBtn.BackgroundColor3=notifEnabled and Color3.fromRGB(60,200,60) or Color3.fromRGB(255,60,60) end)
pBtn.MouseButton1Click:Connect(function() playerESPEnabled=not playerESPEnabled if playerESPEnabled then pBtn.Text="ESP Player: ON" pBtn.BackgroundColor3=Color3.fromRGB(60,200,60) for _,p in ipairs(Players:GetPlayers()) do if p~=player then createPlayerESP(p) end end else pBtn.Text="ESP Player: OFF" pBtn.BackgroundColor3=Color3.fromRGB(255,60,60) clearPlayerESP() end end)
xBtn.MouseButton1Click:Connect(function() xrayEnabled=not xrayEnabled if xrayEnabled then xBtn.Text="X-RAY MAP: ON" xBtn.BackgroundColor3=Color3.fromRGB(60,200,60) enableXRay() else xBtn.Text="X-RAY MAP: OFF" xBtn.BackgroundColor3=Color3.fromRGB(255,60,60) disableXRay() end end)
gBtn.MouseButton1Click:Connect(function() if ghostEnabled then gBtn.Text="GHOST (Yo): OFF" gBtn.BackgroundColor3=Color3.fromRGB(255,60,60) ghostOff() else gBtn.Text="GHOST (Yo): ON" gBtn.BackgroundColor3=Color3.fromRGB(60,200,60) ghostOn() end end)

-- Eventos jugadores
Players.PlayerAdded:Connect(function(p)
    if notifEnabled then playNotificationSound() toast("🚨 "..p.Name.." se unió") end
    if playerESPEnabled then task.wait(0.3) createPlayerESP(p) end
end)
Players.PlayerRemoving:Connect(function(p) local d=playerESPData[p.UserId] if d then safeDestroy(d.hl) freeLine(d.line) playerESPData[p.UserId]=nil end end)

-- Loop
local lastCont = 0
RunService.Heartbeat:Connect(function()
    rainbowHue=(rainbowHue+0.02)%1
    if espEnabled then
        processScanStep()
        updateColors()
        cleanupExpired()
        if contEnabled and qempty() and time()-lastCont>=CONT_SCAN_PERIOD then lastCont=time() qpush(workspace) end
    end
    if playerESPEnabled then updatePlayerESPLines() end
end)

print("✅ ESP LITE+ FINAL cargado.")
