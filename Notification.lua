--// =========================
--//  ESP LITE+ SECURE v1.5.3 (Hotkey T + banner + robust mount)
--//  Si no ves nada: presiona T (toggle panel)
--// =========================

-- ===== Seguridad / Anti doble ejecución =====
local G = getgenv and getgenv() or _G
G.BRAINROT_ESP_VERSION = "1.5.3-secure"
G.BRAINROT_ESP_NAME    = "ESP_LITE_PLUS_SECURE"

if G.__BRAINROT_ESP_RUNNING then return end
G.__BRAINROT_ESP_RUNNING = true

-- ===== Esperar juego cargado =====
while not game or not game.IsLoaded do task.wait(0.1) end
if not game:IsLoaded() then repeat task.wait(0.1) until game:IsLoaded() end

-- ===== Servicios =====
local function S(n) local ok,svc=pcall(game.GetService,game,n) return ok and svc or nil end
local Players      = S("Players")
local RunService   = S("RunService")
local TweenService = S("TweenService")
local UserInput    = S("UserInputService")
local StarterGui   = S("StarterGui")
local CoreGui      = S("CoreGui")
if not (Players and RunService and TweenService and UserInput) then G.__BRAINROT_ESP_RUNNING=false return end
local LP = Players.LocalPlayer
if not LP then repeat task.wait(0.05) until Players.LocalPlayer; LP = Players.LocalPlayer end

-- ===== Parent UI (robusto) =====
local function pickUiParent()
    local ok,hui = pcall(function() return gethui and gethui() end)
    if ok and hui then return hui end
    if CoreGui then return CoreGui end
    local pg = LP:FindFirstChildOfClass("PlayerGui") or LP:WaitForChild("PlayerGui", 3)
    return pg or game
end
local uiParent = pickUiParent()

-- ===== Helpers =====
local function isI(x) return typeof(x)=="Instance" end
local function valid(i) return isI(i) and i.Parent~=nil and i:IsDescendantOf(game) end
local function sd(x) if isI(x) then pcall(function() x:Destroy() end) end end
local function hsv(h) return Color3.fromHSV(h,1,1) end

local CONS={}
local function on(sig,fn) local ok,c=pcall(function() return sig:Connect(function(...) pcall(fn,...) end) end); if ok and c then table.insert(CONS,c) end; return c end
local function off() for _,c in ipairs(CONS) do pcall(function() c:Disconnect() end) end table.clear(CONS) end

-- ===== Persistencia simple =====
G.__BRAINROT_SAVE = G.__BRAINROT_SAVE or {}
local function save(k,v) G.__BRAINROT_SAVE[k]=v end
local function load(k,d) local v=G.__BRAINROT_SAVE[k]; if v==nil then return d end; return v end

-- ===== Parámetros =====
local KEY_TOGGLE = Enum.KeyCode.T  -- <<<<<< tecla para abrir/cerrar panel
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

-- ===== Estado marcadores =====
local rainbowHue  = 0
local everMarked  = setmetatable({}, {__mode="k"})
local activeMarks = setmetatable({}, {__mode="k"})
local brainrotRoots = setmetatable({}, {__mode="k"})
local function addRoot(r) brainrotRoots[r]=true end
local function hasRoot(o) local c=o for _=1,32 do if not c or not valid(c) then return false end if brainrotRoots[c] then return true end c=c.Parent end end
local function cleanRoots() for r,_ in pairs(brainrotRoots) do if not valid(r) then brainrotRoots[r]=nil end end end

local function newHL(t) local h=Instance.new("Highlight"); h.Adornee=t; h.FillTransparency=0.45; h.OutlineTransparency=0.15; h.OutlineColor=Color3.new(1,1,1); h.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop; h.Parent=workspace; return h end

-- ===== X-RAY =====
local xrayEnabled=false
local originalLTM=setmetatable({}, {__mode="k"})
local function ignore(i) return i:IsDescendantOf(uiParent) or i:IsDescendantOf(Players) end
local function isBrain(i) return targetSet[i.Name] and (i:IsA("Model") or i:IsA("BasePart")) end
local function setLTM(p,v) if originalLTM[p]==nil then originalLTM[p]=p.LocalTransparencyModifier end local cur=p.LocalTransparencyModifier; if typeof(cur)~="number" or cur<0 or cur>1 then cur=0 end p.LocalTransparencyModifier=math.max(cur,v) end
local function applyX(n) if ignore(n) or hasRoot(n) or isBrain(n) then return end if n:IsA("BasePart") then setLTM(n,XRAY_TRANSPARENCY) end for _,c in ipairs(n:GetChildren()) do applyX(c) end end
local function restoreX(n) if n:IsA("BasePart") and originalLTM[n]~=nil then n.LocalTransparencyModifier=originalLTM[n]; originalLTM[n]=nil end for _,c in ipairs(n:GetChildren()) do restoreX(c) end end
local function xOn() xrayEnabled=true; applyX(workspace) end
local function xOff() xrayEnabled=false; restoreX(workspace) end
local function unXray(root) if not valid(root) then return end local function R(n) if n:IsA("BasePart") and originalLTM[n]~=nil then n.LocalTransparencyModifier=originalLTM[n]; originalLTM[n]=nil end for _,c in ipairs(n:GetChildren()) do R(c) end end R(root) end

-- ===== Detección =====
local function markOnce(inst)
    if not valid(inst) or everMarked[inst] then return end
    if not (inst:IsA("Model") or inst:IsA("BasePart")) then return end
    if not targetSet[inst.Name] then return end
    everMarked[inst]=true; addRoot(inst); unXray(inst)
    local hl=newHL(inst); hl.FillColor=hsv(rainbowHue)
    activeMarks[inst]={hl=hl,createdAt=time(),baseHue=rainbowHue}
end

-- ===== BFS =====
local Q,qi,qj={},1,0
local function qpush(x) qj+=1; Q[qj]=x end
local function qpop() if qi<=qj then local v=Q[qi]; Q[qi]=nil; qi+=1; return v end end
local function qempty() return qi>qj end
local function qreset() for i=qi,qj do Q[i]=nil end qi,qj=1,0 end
local function scanStep()
    local b=SCAN_STEP_BUDGET
    while b>0 do
        local n=qpop(); if not n then break end
        if valid(n) then
            if targetSet[n.Name] then markOnce(n) end
            for _,ch in ipairs(n:GetChildren()) do if valid(ch) then qpush(ch) end end
        end
        b-=1
    end
end
local function startScan() qreset(); qpush(workspace) end

-- ===== Toasts / Notifs =====
local toastGui=Instance.new("ScreenGui")
toastGui.Name="Toast_"..G.BRAINROT_ESP_NAME
toastGui.ResetOnSpawn=false
toastGui.DisplayOrder=9999
toastGui.IgnoreGuiInset=true
toastGui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
toastGui.Parent=uiParent

local toastTpl do
    local f=Instance.new("Frame"); f.Size=UDim2.new(0,340,0,86); f.Position=UDim2.new(0.5,-170,1,-100); f.BackgroundColor3=Color3.fromRGB(40,40,40)
    local c=Instance.new("UICorner",f); c.CornerRadius=UDim2.new(0,10)
    local l=Instance.new("TextLabel",f); l.Name="Text"; l.BackgroundTransparency=1; l.Size=UDim2.new(1,-20,1,-20); l.Position=UDim2.new(0,10,0,10)
    l.TextScaled=true; l.TextColor3=Color3.new(1,1,1); l.Font=Enum.Font.GothamMedium; l.Text=""
    toastTpl=f
end
local lastToast=0
local function toast(msg,dur)
    local now=time() if now-lastToast<TOAST_MIN_DELAY then return end lastToast=now
    local f=toastTpl:Clone(); f.Parent=toastGui; f.Position=UDim2.new(0.5,-170,1,0)
    f.Text.Text=msg
    TweenService:Create(f,TweenInfo.new(0.25,Enum.EasingStyle.Back),{Position=UDim2.new(0.5,-170,1,-100)}):Play()
    task.delay(dur or 3.0,function() local tw=TweenService:Create(f,TweenInfo.new(0.25),{Position=UDim2.new(0.5,-170,1,0)}); tw:Play(); tw.Completed:Once(function() sd(f) end) end)
end
pcall(function() if StarterGui then StarterGui:SetCore("SendNotification",{Title="ESP LITE+",Text="Cargado. Presiona T para abrir/cerrar.",Duration=3}) end end)

-- ===== Player ESP =====
local linePool={}
local function getLine() local l=table.remove(linePool); if l then l.Parent=workspace return l end
    l=Instance.new("Part"); l.Name="PlayerESPLine"; l.Anchored=true; l.CanCollide=false; l.Size=Vector3.new(0.25,0.25,1)
    l.Material=Enum.Material.ForceField; l.Color=Color3.fromRGB(255,0,0); l.Transparency=0.1; l.Parent=workspace; return l end
local function freeLine(l) if l then l.Parent=nil table.insert(linePool,l) end end
local function makeBB(p)
    local bb=Instance.new("BillboardGui"); bb.AlwaysOnTop=true; bb.Size=UDim2.fromOffset(200,50); bb.StudsOffsetWorldSpace=Vector3.new(0,3.2,0); bb.MaxDistance=3000
    local holder=Instance.new("Frame",bb); holder.BackgroundColor3=Color3.fromRGB(25,25,25); holder.BackgroundTransparency=0.25; holder.Size=UDim2.fromScale(1,1)
    Instance.new("UICorner",holder).CornerRadius=UDim.new(0,6)
    local t=Instance.new("TextLabel",holder); t.BackgroundTransparency=1; t.Size=UDim2.fromScale(1,1); t.TextScaled=true; t.Font=Enum.Font.GothamBold; t.TextColor3=Color3.new(1,1,1); t.TextStrokeTransparency=0.3; t.Text=p.Name
    return bb,t
end
local pESP=false
local pData={}
local lastPE=0
local function createP(p)
    if p==LP or pData[p.UserId] then return end
    local c=p.Character if not c then return end
    local hrp=c:FindFirstChild("HumanoidRootPart") if not hrp then return end
    local hl=newHL(c); hl.FillColor=Color3.new(1,0,0)
    local ln=getLine(); local bb,t=makeBB(p); bb.Adornee=hrp; bb.Parent=workspace
    pData[p.UserId]={p=p,hl=hl,line=ln,bb=bb,lbl=t}
end
local function clearP() for _,d in pairs(pData) do sd(d.hl) freeLine(d.line) sd(d.bb) end table.clear(pData) end
local function updP()
    local now=time() if now-lastPE<1/PLAYER_LINE_FPS then return end lastPE=now
    local my=LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") if not my then return end
    local myPos=my.Position; local rem={}
    for uid,d in pairs(pData) do
        local p=d.p; local c=p and p.Character; local hrp=c and c:FindFirstChild("HumanoidRootPart")
        if not (p and c and hrp and valid(d.hl) and valid(d.line) and valid(d.bb) and valid(d.lbl)) then
            table.insert(rem,uid)
        else
            local tpos=hrp.Position; local dir=tpos-myPos; local dist=dir.Magnitude; if not dist or dist~=dist or dist<=0 then dist=0.1 end
            d.line.Size=Vector3.new(0.25,0.25,dist); d.line.CFrame=CFrame.lookAt(myPos+dir*0.5,tpos)
            if d.bb.Adornee~=hrp then d.bb.Adornee=hrp end
            d.lbl.Text=string.format("%s  •  %dst", p.Name, math.floor(dist))
        end
    end
    for _,u in ipairs(rem) do local d=pData[u]; if d then sd(d.hl) freeLine(d.line) sd(d.bb) pData[u]=nil end end
end

-- ===== Ghost =====
local ghost=false
local function setTransp(ch,t) for _,d in ipairs(ch:GetDescendants()) do if d:IsA("BasePart") or d:IsA("Decal") then d.Transparency=t end if d:IsA("Accessory") then local h=d:FindFirstChild("Handle") if h then h.Transparency=t end end end end
local function gOn()  ghost=true;  save("ghost",true);  if LP.Character then setTransp(LP.Character,0.7) end end
local function gOff() ghost=false; save("ghost",false); if LP.Character then setTransp(LP.Character,0.0) end end
on(LP.CharacterAdded,function(c) task.wait(0.2); if ghost then setTransp(c,0.7) end end)

-- ===== GUI (panel) =====
local main=Instance.new("ScreenGui")
main.Name="GUI_"..G.BRAINROT_ESP_NAME
main.ResetOnSpawn=false
main.DisplayOrder=10000
main.IgnoreGuiInset=true
main.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
main.Enabled=true
main.Parent=uiParent

-- Banner mini “Presiona T...”
local hint=Instance.new("TextLabel")
hint.Name="ESP_Hint"
hint.Parent=main
hint.Size=UDim2.new(0,280,0,26)
hint.Position=UDim2.new(0.5,-140,0,6)
hint.BackgroundColor3=Color3.fromRGB(20,20,20)
hint.Text="ESP cargado • Presiona T para abrir/cerrar"
hint.TextScaled=true
hint.Font=Enum.Font.Gotham
hint.TextColor3=Color3.new(1,1,1)
Instance.new("UICorner",hint).CornerRadius=UDim.new(0,6)
task.delay(4, function() if valid(hint) then TweenService:Create(hint,TweenInfo.new(0.25),{TextTransparency=1, BackgroundTransparency=1}):Play() task.wait(0.3) sd(hint) end end)

-- Panel
local panel=Instance.new("Frame")
panel.Size=UDim2.new(0,260,0,420)
panel.Position=UDim2.new(1,-270,0,10)
panel.BackgroundColor3=Color3.fromRGB(24,24,24)
panel.Active=true
panel.Parent=main
Instance.new("UICorner",panel).CornerRadius=UDim.new(0,10)

local header=Instance.new("Frame")
header.Size=UDim2.new(1,0,0,38)
header.BackgroundColor3=Color3.fromRGB(45,45,45)
header.Parent=panel
Instance.new("UICorner",header).CornerRadius=UDim.New and UDim.New(0,10) or UDim2.new(0,10)

local hText=Instance.new("TextLabel",header)
hText.BackgroundTransparency=1
hText.Size=UDim2.new(1,-76,1,0)
hText.Position=UDim2.new(0,10,0,0)
hText.Text="ESP LITE+ • "..G.BRAINROT_ESP_VERSION
hText.TextColor3=Color3.new(1,1,1)
hText.TextScaled=true
hText.Font=Enum.Font.GothamBold

local btnMin=Instance.new("TextButton",header)
btnMin.Size=UDim2.new(0,30,0,30)
btnMin.Position=UDim2.new(1,-36,0,4)
btnMin.BackgroundColor3=Color3.fromRGB(60,60,60)
btnMin.Text="-"; btnMin.TextScaled=true; btnMin.TextColor3=Color3.new(1,1,1); btnMin.Font=Enum.Font.GothamBold
Instance.new("UICorner",btnMin).CornerRadius=UDim.new(0,6)

-- Drag panel desde header
do
    local dragging=false; local start; local startPos
    on(header.InputBegan,function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1 then
            dragging=true; start=inp.Position; startPos=panel.Position
            inp.Changed:Connect(function() if inp.UserInputState==Enum.UserInputState.End then dragging=false end end)
        end
    end)
    on(UserInput.InputChanged,function(inp)
        if dragging and inp.UserInputType==Enum.UserInputType.MouseMovement then
            local d=inp.Position-start
            panel.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y)
        end
    end)
end

local body=Instance.new("Frame",panel)
body.Size=UDim2.new(1,-20,1,-58); body.Position=UDim2.new(0,10,0,48); body.BackgroundTransparency=1

local function badge(text,color)
    local b=Instance.new("TextLabel",body)
    b.BackgroundColor3=color; b.TextColor3=Color3.new(1,1,1); b.TextScaled=true; b.Font=Enum.Font.GothamMedium; b.Size=UDim2.new(1,0,0,26); b.Text=text
    Instance.new("UICorner",b).CornerRadius=UDim.new(0,6); return b
end
local statusBadge=badge("Listo", Color3.fromRGB(35,120,60)); statusBadge.Position=UDim2.new(0,0,0,0)

local function makeBtn(y, txt, col, tipText)
    local container=Instance.new("Frame",body); container.Size=UDim2.new(1,0,0,38); container.Position=UDim2.new(0,0,0,y); container.BackgroundTransparency=1
    local b=Instance.new("TextButton",container); b.Size=UDim2.new(1,0,1,0); b.BackgroundColor3=col or Color3.fromRGB(255,60,60); b.Text=txt; b.TextScaled=true; b.TextColor3=Color3.new(1,1,1); b.Font=Enum.Font.Gotham
    Instance.new("UICorner", b).CornerRadius=UDim.new(0,8)
    local tip=Instance.new("TextLabel",container); tip.Visible=false; tip.BackgroundColor3=Color3.fromRGB(20,20,20); tip.TextColor3=Color3.fromRGB(220,220,220); tip.Text=tipText or ""; tip.Font=Enum.Font.Gotham
    tip.TextScaled=true; tip.Size=UDim2.new(0, math.max(160, (tipText and #tipText or 0)*6), 0, 28); tip.Position=UDim2.new(0, 8, 0, -34)
    Instance.new("UICorner", tip).CornerRadius=UDim.new(0,6)
    on(b.MouseEnter,function() if tipText and #tipText>0 then tip.Visible=true end end)
    on(b.MouseLeave,function() tip.Visible=false end)
    return b
end

local y0=40
local btnESP   = makeBtn(y0+  0, "ESP: OFF",               Color3.fromRGB(200,60,60),  "Marca brainrots 15s")
local btnCONT  = makeBtn(y0+ 44, "Búsqueda Continua: ON",  Color3.fromRGB(60,200,60),  "Repite el escaneo")
local btnNOTIF = makeBtn(y0+ 88, "Notificaciones: ON",     Color3.fromRGB(60,200,60),  "Sonido + toast")
local btnPESP  = makeBtn(y0+132, "ESP Player: OFF",        Color3.fromRGB(200,60,60),  "Línea + nombre/dist")
local btnXRAY  = makeBtn(y0+176, "X-RAY MAP: OFF",         Color3.fromRGB(200,60,60),  "Props semi-transparentes")
local btnGHOST = makeBtn(y0+220, "GHOST (Yo): OFF",        Color3.fromRGB(200,60,60),  "70% transparente")
local btnUNLD  = makeBtn(y0+264, "UNLOAD / SALIR",         Color3.fromRGB(80,80,80),   "Desinstalar todo")

-- ===== Estado toggles =====
local esp=false
local cont=load("cont",true)
local notif=load("notif",true)
pESP = load("pESP",false)
ghost = load("ghost",false)

local minimized=false
local panelVisible=true
local function setMin(m)
    minimized=m
    if minimized then
        TweenService:Create(body, TweenInfo.new(0.15), {Position=UDim2.new(0,10,0,420), Size=UDim2.new(1,-20,0,0)}):Play()
        TweenService:Create(panel, TweenInfo.new(0.15), {Size=UDim2.new(0,260,0,48)}):Play()
        btnMin.Text="+"
    else
        TweenService:Create(panel, TweenInfo.new(0.15), {Size=UDim2.new(0,260,0,420)}):Play()
        TweenService:Create(body, TweenInfo.new(0.15), {Position=UDim2.new(0,10,0,48), Size=UDim2.new(1,-20,1,-58)}):Play()
        btnMin.Text="-"
    end
end
on(btnMin.MouseButton1Click, function() setMin(not minimized) end)
local function setPanel(v) panelVisible=v; panel.Visible=v end

-- ===== Botones funcionales =====
local function setBtn(b,on) b.BackgroundColor3 = on and Color3.fromRGB(60,200,60) or Color3.fromRGB(200,60,60) end
local function refresh()
    setBtn(btnESP,esp);       btnESP.Text    = esp    and "ESP: ON"                or "ESP: OFF"
    setBtn(btnCONT,cont);     btnCONT.Text   = cont   and "Búsqueda Continua: ON"  or "Búsqueda Continua: OFF"
    setBtn(btnNOTIF,notif);   btnNOTIF.Text  = notif  and "Notificaciones: ON"     or "Notificaciones: OFF"
    setBtn(btnPESP,pESP);     btnPESP.Text   = pESP   and "ESP Player: ON"         or "ESP Player: OFF"
    setBtn(btnXRAY,xrayEnabled); btnXRAY.Text= xrayEnabled and "X-RAY MAP: ON"     or "X-RAY MAP: OFF"
    setBtn(btnGHOST,ghost);   btnGHOST.Text  = ghost  and "GHOST (Yo): ON"         or "GHOST (Yo): OFF"
end

on(btnESP.MouseButton1Click,function()
    esp = not esp
    if esp then startScan(); toast("ESP activado (15s)"); statusBadge.Text="ESP activo"
    else for _,d in pairs(activeMarks) do sd(d.hl) end table.clear(activeMarks); toast("ESP desactivado"); statusBadge.Text="Listo" end
    refresh()
end)
on(btnCONT.MouseButton1Click,function() cont=not cont; save("cont",cont); refresh() end)
on(btnNOTIF.MouseButton1Click,function() notif=not notif; save("notif",notif); refresh() end)
on(btnPESP.MouseButton1Click,function()
    pESP=not pESP; save("pESP",pESP)
    if pESP then for _,p in ipairs(Players:GetPlayers()) do if p~=LP then createP(p) end end else clearP() end
    refresh()
end)
on(btnXRAY.MouseButton1Click,function() xrayEnabled = not xrayEnabled; if xrayEnabled then xOn() else xOff() end; refresh() end)
on(btnGHOST.MouseButton1Click,function() if ghost then gOff() else gOn() end; refresh() end)

-- ===== Unload =====
local function UNLOAD()
    if xrayEnabled then xOff() end
    if ghost then gOff() end
    if pESP then clearP() end
    for _,d in pairs(activeMarks) do sd(d.hl) end; table.clear(activeMarks)
    off(); pcall(function() restoreX(workspace) end)
    sd(main); sd(toastGui)
    G.__BRAINROT_ESP_RUNNING=false
end
on(btnUNLD.MouseButton1Click, UNLOAD)
G.BRAINROT_UNLOAD = UNLOAD

-- ===== Eventos jugadores =====
on(Players.PlayerAdded, function(p) if notif then pcall(function() StarterGui:SetCore("SendNotification",{Title="ESP",Text=p.Name.." se unió",Duration=2}) end); toast("🚨 "..p.Name.." se unió") end if pESP then task.wait(0.3) createP(p) end end)
on(Players.PlayerRemoving, function(p) local d=pData[p.UserId]; if d then sd(d.hl) freeLine(d.line) sd(d.bb) pData[p.UserId]=nil end end)

-- ===== Hotkeys =====
on(UserInput.InputBegan, function(inp, gp)
    if gp then return end
    if inp.KeyCode == KEY_TOGGLE then setPanel(not panelVisible) end -- <<<<<< T abre/cierra
    if inp.KeyCode == Enum.KeyCode.M then setMin(not minimized) end
    if inp.KeyCode == Enum.KeyCode.E then btnESP:Activate() end
    if inp.KeyCode == Enum.KeyCode.X then btnXRAY:Activate() end
    if inp.KeyCode == Enum.KeyCode.P then btnPESP:Activate() end
    if inp.KeyCode == Enum.KeyCode.G then btnGHOST:Activate() end
    if inp.KeyCode == Enum.KeyCode.U then btnUNLD:Activate() end
end)

-- ===== Loop =====
local lastCont=0
on(RunService.Heartbeat, function(dt)
    rainbowHue=(rainbowHue + (dt*0.25))%1
    header.BackgroundColor3=Color3.fromHSV(rainbowHue,0.5,0.8)

    if esp then
        scanStep()
        for inst,data in pairs(activeMarks) do
            local hl=data.hl
            if valid(hl) then
                local hue=(data.baseHue + (time()-data.createdAt)*RAINBOW_SPEED)%1
                hl.FillColor=hsv(hue)
            end
        end
        local now=time()
        for inst,data in pairs(activeMarks) do
            if (now-data.createdAt)>=MARK_DURATION or not valid(inst) then sd(data.hl); activeMarks[inst]=nil end
        end
        cleanRoots()
        if cont and qempty() and time()-lastCont>=CONT_SCAN_PERIOD then lastCont=time(); qpush(workspace) end
    end

    if pESP then updP() end
end)

-- ===== Nuevos objetos =====
on(workspace.DescendantAdded, function(i)
    if xrayEnabled and i:IsA("BasePart") and not ignore(i) and not hasRoot(i) and not isBrain(i) then setLTM(i,XRAY_TRANSPARENCY) end
    if isBrain(i) and targetSet[i.Name] then markOnce(i) end
end)

-- ===== Init =====
refresh()
if pESP then for _,p in ipairs(Players:GetPlayers()) do if p~=LP then createP(p) end end end
if ghost then gOn() end
