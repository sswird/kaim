---- ==============================================================================
--      :::    :::           :::        :::::::::::         :::   ::: 
--     :+:   :+:          :+: :+:          :+:            :+:+: :+:+: 
--    +:+  +:+          +:+   +:+         +:+           +:+ +:+:+ +:+ 
--   +#++:++          +#++:++#++:        +#+           +#+  +:+  +#+  
--  +#+  +#+         +#+     +#+        +#+           +#+       +#+   
-- #+#   #+#        #+#     #+#        #+#           #+#       #+#    
--###    ###       ###     ###    ###########       ###       ###     
--                           [ V11 ]
-- ==============================================================================
--  • Obsidian UI (no Rayfield)
--  • Sirius Sense ESP (self-hosted)
--  • Single-Lock Aimbot | Zero-Bridge Drawing | Global Ray Cache
-- ==============================================================================
task.spawn(function()
local ok, err = xpcall(function()

local _env = (type(getgenv) == "function" and getgenv()) or _G
if _env.KAIM_LOADED and type(_env.KAIM_UNLOAD) == "function" then
    pcall(_env.KAIM_UNLOAD)
end
if not game:IsLoaded() then game.Loaded:Wait() end

-- ==============================================================================
--  1. SERVICES
-- ==============================================================================
local RS  = game:GetService("RunService")
local Plr = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local Lit = game:GetService("Lighting")
local LP  = Plr.LocalPlayer

local SafeGui = LP:FindFirstChild("PlayerGui") or workspace
pcall(function() SafeGui = game:GetService("CoreGui") end)
pcall(function() local h = gethui and gethui(); if h then SafeGui = h end end)

-- ==============================================================================
--  2. LOAD LIBRARIES
-- ==============================================================================
local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()
assert(Library, "KAIM | Failed to load Obsidian Library.")

_env.KAIM_LOADED = true

local success, SenseESP = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/sswird/sense/main/sense.lua"))()
end)
if not success or type(SenseESP) ~= "table" then
    warn("KAIM | Failed to load Sense ESP from GitHub. Ensure your executor supports loadstring.")
    getgenv().SenseESP = nil
else
    getgenv().SenseESP = SenseESP
end
getgenv().SenseESP.sharedSettings.useTeamColor  = false
getgenv().SenseESP.teamSettings.enemy.enabled   = false
getgenv().SenseESP.teamSettings.friendly.enabled = false
getgenv().SenseESP.Load()

-- ==============================================================================
--  3. MATH & FAST LOCALS
-- ==============================================================================
local mFloor, mClamp, mMax, mMin, mSqrt = math.floor, math.clamp, math.max, math.min, math.sqrt
local mRand = math.random
local mSin, mCos = math.sin, math.cos
local iNew = Instance.new
local tClear = table.clear
local V2, V3, C3, CF = Vector2.new, Vector3.new, Color3.fromRGB, CFrame.new
local tIns, tRem = table.insert, table.remove

local WHITE  = C3(255,255,255)
local RED    = C3(255,50,50)
local ORANGE = C3(255,130,0)

local HP_PAL = {C3(255,50,50), C3(255,130,0), C3(255,200,0), C3(100,255,50), C3(0,255,100)}
local function HPC(p)
    if p <= 0 then return HP_PAL[1] end; if p >= 1 then return HP_PAL[5] end
    local s = p*4+1; local i = mFloor(s); local f = s-i
    return (HP_PAL[i] and HP_PAL[i+1]) and HP_PAL[i]:Lerp(HP_PAL[i+1], f) or HP_PAL[5]
end

-- ==============================================================================
--  4. DRAWING PROXY (safe wrapper for executors without Drawing API)
-- ==============================================================================
local HAS_D = type(Drawing) == "table" and type(Drawing.new) == "function"

local function ND(t)
    local obj
    if HAS_D then local ok2, r = pcall(Drawing.new, t); if ok2 and r then obj = r end end
    if not obj then
        obj = {Remove=function()end, Destroy=function()end}
        setmetatable(obj, {__newindex=function()end})
    end
    local cache = {
        Visible=false, ZIndex=1, Transparency=1, Color=Color3.new(),
        Thickness=1, Filled=false, Position=Vector2.new(),
        Size=(t=="Text" and 12 or (t=="Square" and Vector2.new() or 0)),
        Text="", Center=false, Outline=false, OutlineColor=Color3.new(),
        Font=1, From=Vector2.new(), To=Vector2.new(), Radius=0
    }
    for k,v in pairs(cache) do pcall(function() obj[k]=v end) end
    local proxy = {
        Remove=function() pcall(function() obj:Remove() end) end,
        Destroy=function() pcall(function() obj:Destroy() end) end
    }
    return setmetatable(proxy, {
        __index=function(_,k)
            if cache[k]~=nil then return cache[k] end
            local ok3,val = pcall(function() return obj[k] end)
            if ok3 then return val end; return nil
        end,
        __newindex=function(_,k,v)
            if cache[k]~=v then cache[k]=v; obj[k]=v end
        end
    })
end

local function setL(l,f,t2,c,th,z) l.From=f; l.To=t2; l.Color=c; l.Thickness=th; l.ZIndex=z; l.Visible=true end
local function setRect(r,sz,pos,c,z,th,tr,vis)
    if r.Size~=sz then r.Size=sz end; if r.Position~=pos then r.Position=pos end
    if c and r.Color~=c then r.Color=c end; if z and r.ZIndex~=z then r.ZIndex=z end
    if th and r.Thickness~=th then r.Thickness=th end; if tr and r.Transparency~=tr then r.Transparency=tr end
    if vis~=nil then if r.Visible~=vis then r.Visible=vis end elseif not r.Visible then r.Visible=true end
end
local function setCirc(c2,p,r,col,th,tr,vis)
    if p and c2.Position~=p then c2.Position=p end; if r and c2.Radius~=r then c2.Radius=r end
    if col and c2.Color~=col then c2.Color=col end; if th and c2.Thickness~=th then c2.Thickness=th end
    if tr and c2.Transparency~=tr then c2.Transparency=tr end
    if vis~=nil then if c2.Visible~=vis then c2.Visible=vis end elseif not c2.Visible then c2.Visible=true end
end

-- ==============================================================================
--  5. STATE
-- ==============================================================================
local S = {
    Aim = {
        On=false, Mode="Smart", Priority="Crosshair", WallCheck=true, WallCheckDelay=0.5, TeamCheck=true,
        ESPTargetsOnly=false, Pred=true, PredStr=0.135, Smooth=false, SmoothSpd=0.3, HitChance=100,
        LockTracer=true, SoundCue=true, NotifyLock=false,
        OffX=0, OffY=0, OffZ=0,
        Target=nil, IsAiming=false, HasLockedThisPress=false
    },
    HB  = {On=false, Part="Head", Size=5, Trans=0.5},
    FOV = {Show=true, Follow=true, Radius=150, ZoomScale=true, Thick=1.5,
           Color=WHITE, ColorLerp=true, LockCol=ORANGE, Trans=0.8, Filled=false, FC=WHITE, FT=0.92},
    World = {On=false, Time=14, Bright=2, Shadows=false, Ambient=WHITE},
    Mov   = {SpeedOn=false, Speed=16, JumpOn=false, Jump=50, InfJump=false, BHop=false,
             FOVOn=false, CamFOV=70, Noclip=false, NoclipKey="N",
             GravOn=false, Gravity=196.2, BlinkOn=false,
             FlyOn=false, FlySpeed=50, SpinOn=false, SpinSpeed=20},
    Perf  = {LOD=500, Watermark=true, ShowFPS=true, ShowPing=true, ShowTime=false},
}

local _limbPool = {}
local _aimOff   = V3(0,0,0)
local _aimKC    = "RightClick" 
local _blinkKC  = Enum.KeyCode.Unknown
local _graceTimer = 0
local chaosT, CHAOS_INT, chaosName = 0, 0.22, "Head"

local RP  = RaycastParams.new(); RP.FilterType  = Enum.RaycastFilterType.Exclude; RP.IgnoreWater = true
local TRP = RaycastParams.new(); TRP.FilterType = Enum.RaycastFilterType.Exclude; TRP.IgnoreWater = true

local Conns, PList, TC, CC, HBOrig = {}, {}, {}, {}, {}

local fps = 0
local _fpsCount = 0
local _fpsLast  = os.clock()
local OrigLit = {}

-- ==============================================================================
--  6. DRAWING OBJECTS
-- ==============================================================================
local lockSound = iNew("Sound"); lockSound.SoundId = "rbxassetid://127004816100960"; lockSound.Volume=0.5
local uiOnSound = iNew("Sound"); uiOnSound.SoundId = "rbxassetid://115916891254154"; uiOnSound.Volume=1.5
local uiOffSound = iNew("Sound"); uiOffSound.SoundId = "rbxassetid://8968249849"; uiOffSound.Volume=1.5
local loadSound = iNew("Sound"); loadSound.SoundId = "rbxassetid://134699420140804"; loadSound.Volume=2
local clickSound = iNew("Sound"); clickSound.SoundId = "rbxassetid://136275224021234"; clickSound.Volume=1.5
local notifySound = iNew("Sound"); notifySound.SoundId = "rbxassetid://95648732815431"; notifySound.Volume=1.5
pcall(function() 
    lockSound.Parent = SafeGui
    uiOnSound.Parent = SafeGui
    uiOffSound.Parent = SafeGui
    loadSound.Parent = SafeGui
    clickSound.Parent = SafeGui
    notifySound.Parent = SafeGui
end)

local oldNotify = Library.Notify
Library.Notify = function(self, ...)
    pcall(function() notifySound:Play() end)
    return oldNotify(self, ...)
end

local FOVR   = ND("Circle"); FOVR.Thickness=1.5; FOVR.Filled=false
local FOVF   = ND("Circle"); FOVF.Thickness=1;   FOVF.Filled=true
local LTracer = ND("Line");   LTracer.Thickness=1.5

local THUD = {BG=ND("Square"), Txt=ND("Text"), BarBG=ND("Square"), Bar=ND("Square")}
THUD.Txt.Center=true; THUD.Txt.Outline=true; THUD.Txt.Color=WHITE; THUD.Txt.Font=2; THUD.Txt.Size=14

local function CacheL() OrigLit={T=Lit.ClockTime, B=Lit.Brightness, S=Lit.GlobalShadows, A=Lit.Ambient} end
CacheL()

-- ==============================================================================
--  7. RAY CACHING
-- ==============================================================================
local visRayFilter, tbRayFilter, _lastVisChar = {}, {}, nil

local function UpdateTBRayFilter()
    tClear(tbRayFilter)
    local cam = workspace.CurrentCamera
    if cam then tIns(tbRayFilter, cam) end
    if LP.Character then tIns(tbRayFilter, LP.Character) end
    TRP.FilterDescendantsInstances = tbRayFilter
end

local function SetVisFilter(targetChar)
    if _lastVisChar == targetChar then return end
    _lastVisChar = targetChar
    tClear(visRayFilter)
    if LP.Character then tIns(visRayFilter, LP.Character) end
    if targetChar then tIns(visRayFilter, targetChar) end
    RP.FilterDescendantsInstances = visRayFilter
end

tIns(Conns, LP.CharacterAdded:Connect(function() task.delay(0.5, UpdateTBRayFilter); _lastVisChar=nil end))

-- ==============================================================================
--  8. CORE UTILS
-- ==============================================================================
local function IsTeam(p) if TC[p]==nil then TC[p]=(p.Team~=nil and p.Team==LP.Team) end; return TC[p] end
tIns(Conns, LP:GetPropertyChangedSignal("Team"):Connect(function() tClear(TC) end))

local function BuildCC(pl, char)
    local old = CC[pl]
    if old and old._hpConn then pcall(function() old._hpConn:Disconnect() end) end
    CC[pl] = nil
    if not char then UpdateTBRayFilter(); return end
    task.spawn(function()
        local hrp, head, hum
        task.spawn(function() hrp  = char:WaitForChild("HumanoidRootPart", 5) end)
        task.spawn(function() head = char:WaitForChild("Head", 5) end)
        task.spawn(function() hum  = char:WaitForChild("Humanoid", 5) end)
        while (not hrp or not head or not hum) and char.Parent do task.wait() end
        if not char.Parent or pl.Character ~= char then return end
        if hrp and head and hum then
            local c = {Char=char, HRP=hrp, Head=head, Hum=hum}
            c._rig    = char:FindFirstChild("UpperTorso") and "R15" or "R6"
            c._maxHP  = hum.MaxHealth
            c._hpConn = hum:GetPropertyChangedSignal("MaxHealth"):Connect(function() c._maxHP=hum.MaxHealth end)
            c._chaosParts = {}
            for _, n in ipairs({"Head","Neck","UpperTorso","LowerTorso","Torso","LeftUpperArm","RightUpperArm",
                "LeftLowerArm","RightLowerArm","LeftHand","RightHand","LeftUpperLeg","RightUpperLeg",
                "LeftLowerLeg","RightLowerLeg","Left Arm","Right Arm","Left Leg","Right Leg"}) do
                local p = char:FindFirstChild(n); if p and p:IsA("BasePart") then tIns(c._chaosParts, p) end
            end
            c._lastPos = hrp.Position
            c._sp = V3(); c._onSc=false; c._depth=0; c._distSq=0; c._wsValid=false
            CC[pl] = c
            UpdateTBRayFilter()
        end
    end)
end

local function IsVis(part, camP, targetChar)
    if not part then return false end
    SetVisFilter(targetChar)
    return workspace:Raycast(camP, part.Position - camP, RP) == nil
end

-- ==============================================================================
--  9. AIMBOT
-- ==============================================================================
local SMART_P = {"Head","Neck","UpperTorso","LowerTorso","Torso","HumanoidRootPart"}

local function GetAimPart(cd, mode, camP, fovP, cam)
    local ch = cd.Char
    if mode == "Smart" then
        if cd._smartPart then
            local sp = ch:FindFirstChild(cd._smartPart)
            if sp and IsVis(sp, camP, ch) then return sp, true end
            cd._smartPart = nil
        end
        for i=1, #SMART_P do
            local p = ch:FindFirstChild(SMART_P[i])
            if p and IsVis(p, camP, ch) then cd._smartPart=SMART_P[i]; return p, true end
        end
        return cd.HRP, false
    elseif mode == "Nearest Part" then
        local bestP, bestD = cd.HRP, math.huge
        for i=1, #SMART_P do
            local p = ch:FindFirstChild(SMART_P[i])
            if p then
                local sp, on = cam:WorldToViewportPoint(p.Position)
                if on then
                    local d = (V2(sp.X,sp.Y)-fovP).Magnitude
                    if d<bestD and (not S.Aim.WallCheck or IsVis(p,camP,ch)) then bestD=d; bestP=p end
                end
            end
        end
        return bestP, IsVis(bestP, camP, ch)
    end
    local part = cd.HRP
    if mode=="Chaos" then part=ch:FindFirstChild(chaosName) or cd.HRP
    elseif mode=="Head" then part=cd.Head or cd.HRP
    elseif mode=="Neck" then part=ch:FindFirstChild("Neck") or cd.Head or cd.HRP
    elseif mode=="Torso" then part=ch:FindFirstChild("UpperTorso") or ch:FindFirstChild("Torso") or cd.HRP
    elseif mode=="LowerTorso" then part=ch:FindFirstChild("LowerTorso") or ch:FindFirstChild("Torso") or cd.HRP
    elseif mode=="Limbs" then
        tClear(_limbPool)
        for _,n in ipairs({"LeftUpperArm","RightUpperArm","LeftUpperLeg","RightUpperLeg","Left Arm","Right Arm","Left Leg","Right Leg"}) do
            local p=ch:FindFirstChild(n); if p then tIns(_limbPool,p) end
        end
        part = #_limbPool>0 and _limbPool[mRand(1,mMax(1,#_limbPool))] or cd.HRP
    elseif mode=="HRP" then part=cd.HRP end
    return part, IsVis(part, camP, ch)
end

local function PickChaos(cd)
    if cd and cd._chaosParts and #cd._chaosParts>0 then
        chaosName = cd._chaosParts[mRand(1,#cd._chaosParts)].Name
    end
end

local function GetTarget(camP, fovP, cam)
    local bestTarget, bestVal = nil, math.huge
    local scale = S.FOV.ZoomScale and (70/cam.FieldOfView) or 1
    local efR    = S.FOV.Radius * scale
    local efRSq  = efR * efR  -- cache squared for comparison
    local byD    = S.Aim.Priority == "Distance"

    for i=1, #PList do
        local pl = PList[i]; local cd = CC[pl]
        if not cd or not cd.Hum or cd.Hum.Health<=0 then continue end
        if S.Aim.TeamCheck and IsTeam(pl) then continue end
        if not cd._onSc or not cd._wsValid then continue end

        if S.Aim.ESPTargetsOnly and getgenv().SenseESP then
            local isEn
            if IsTeam(pl) then isEn = getgenv().SenseESP.teamSettings.friendly.enabled
            else               isEn = getgenv().SenseESP.teamSettings.enemy.enabled end
            if not isEn then continue end
            if getgenv().SenseESP.sharedSettings.limitDistance then
                local md = getgenv().SenseESP.sharedSettings.maxDistance
                if cd._distSq > md*md then continue end
            end
        end

        local _dx = fovP.X-cd._sp.X; local _dy = fovP.Y-cd._sp.Y
        local dist2DSq = _dx*_dx + _dy*_dy
        if dist2DSq > efRSq then continue end  -- squared comparison, no sqrt needed

        local val = byD and cd._distSq or dist2DSq
        if val < bestVal then
            if not S.Aim.WallCheck or select(2, GetAimPart(cd, S.Aim.Mode, camP, fovP, cam)) then
                bestVal=val; bestTarget=pl
            end
        end
    end
    return bestTarget
end

-- ==============================================================================
--  10. PLAYER REGISTRATION
-- ==============================================================================
local function RegPl(pl)
    if pl==LP then return end
    tIns(PList, pl)
    tIns(Conns, pl:GetPropertyChangedSignal("Team"):Connect(function() TC[pl]=nil end))
    tIns(Conns, pl.CharacterAdded:Connect(function(c) BuildCC(pl,c) end))
    tIns(Conns, pl.CharacterRemoving:Connect(function()
        if CC[pl] and CC[pl]._hpConn then pcall(function() CC[pl]._hpConn:Disconnect() end) end
        CC[pl]=nil; HBOrig[pl]=nil; UpdateTBRayFilter()
    end))
    if pl.Character then BuildCC(pl, pl.Character) end
end

task.spawn(function() for _,p in ipairs(Plr:GetPlayers()) do if p~=LP then RegPl(p); task.wait() end end end)
tIns(Conns, Plr.PlayerAdded:Connect(RegPl))
tIns(Conns, Plr.PlayerRemoving:Connect(function(pl)
    local _plCount = #PList
    for i=1,_plCount do if PList[i]==pl then tRem(PList,i); break end end
    CC[pl]=nil; HBOrig[pl]=nil; UpdateTBRayFilter()
end))
tIns(Conns, LP.CharacterAdded:Connect(function(c)
    BuildCC(LP,c); UpdateTBRayFilter()
    if S.Mov.Noclip then task.defer(function() if _G._KaimNC then _G._KaimNC(c) end end) end
end))
if LP.Character then BuildCC(LP, LP.Character) end
UpdateTBRayFilter()

-- ==============================================================================
--  11. NOCLIP
-- ==============================================================================
local _ncConn, _ncParts = nil, {}
local function BuildNoclipCache(char)
    tClear(_ncParts)
    if not char then return end
    for _,p in ipairs(char:GetDescendants()) do if p:IsA("BasePart") then tIns(_ncParts,p) end end
end
_G._KaimNC = BuildNoclipCache

local function SetNC(enabled)
    S.Mov.Noclip = enabled
    if enabled then
        local char = LP.Character; if char then BuildNoclipCache(char) end
        if not _ncConn then
            _ncConn = RS.Stepped:Connect(function()
                if not S.Mov.Noclip then return end
                for i=1,#_ncParts do local p=_ncParts[i]; if p and p.Parent and p.CanCollide then p.CanCollide=false end end
            end)
            tIns(Conns, _ncConn)
        end
    else
        if _ncConn then pcall(function() _ncConn:Disconnect() end); _ncConn=nil end
        local char = LP.Character
        if char then
            for _,p in ipairs(char:GetDescendants()) do
                if p:IsA("BasePart") and (p.Name=="HumanoidRootPart" or p.Name=="Torso" or
                   p.Name=="UpperTorso" or p.Name=="LowerTorso" or p.Name=="Head") then
                    p.CanCollide=true
                end
            end
        end
        tClear(_ncParts)
    end
end

-- ==============================================================================
--  12. RENDER / AIM TICK
-- ==============================================================================

local _currFovR = 0
local function TickFOV(ctr, cam, dt)
    local pos = S.FOV.Follow and UIS:GetMouseLocation() or ctr
    local scale = S.FOV.ZoomScale and (70/cam.FieldOfView) or 1
    local targetR = mMax(1, S.FOV.Radius * scale)
    
    if _currFovR == 0 then _currFovR = targetR end
    _currFovR = _currFovR + (targetR - _currFovR) * mClamp(dt * 15, 0, 1)
    
    local fCol = (S.FOV.ColorLerp and S.Aim.Target and S.Aim.IsAiming) and S.FOV.LockCol or S.FOV.Color
    setCirc(FOVR, pos, _currFovR, fCol, S.FOV.Thick, S.FOV.Trans, S.FOV.Show)
    setCirc(FOVF, pos, _currFovR, S.FOV.FC, nil, S.FOV.FT, S.FOV.Show and S.FOV.Filled)
    return pos
end

local _lockedDiedConn = nil
local _thudLastHP   = -1
local _thudLastDist = -1
local _thudLastName = ""
local function ClearTarget()
    S.Aim.Target = nil
    _thudLastHP = -1; _thudLastDist = -1; _thudLastName = ""
    if _lockedDiedConn then pcall(function() _lockedDiedConn:Disconnect() end); _lockedDiedConn=nil end
end

local function TickAim(camP, sw, sh, dt, fovP, cam)
    if S.Aim.Mode=="Chaos" and S.Aim.IsAiming then
        chaosT=chaosT-dt; if chaosT<=0 then chaosT=CHAOS_INT; local tc=S.Aim.Target and CC[S.Aim.Target]; if tc then PickChaos(tc) end end
    end

    if S.Aim.On and S.Aim.IsAiming then
        if not S.Aim.Target and not S.Aim.HasLockedThisPress then
            local newT = GetTarget(camP, fovP, cam)
            if newT then
                S.Aim.Target = newT; S.Aim.HasLockedThisPress=true; _graceTimer=0
                if S.Aim.SoundCue then pcall(function() lockSound:Play() end) end
                if S.Aim.NotifyLock then Library:Notify({Title="Lock", Description="Locked: "..newT.DisplayName, Time=2}) end
                local cd = CC[newT]
                if cd and cd.Hum then _lockedDiedConn = cd.Hum.Died:Connect(ClearTarget) end
            end
        end

        local tar = S.Aim.Target; local cd = tar and CC[tar]
        if cd then
            if cd.Hum.Health<=0 then ClearTarget()
            else
                local part, lockVis = GetAimPart(cd, S.Aim.Mode, camP, fovP, cam)
                if not lockVis and S.Aim.WallCheck then
                    _graceTimer=_graceTimer+dt
                    if _graceTimer>S.Aim.WallCheckDelay then ClearTarget(); part=nil end
                else _graceTimer=0 end

                if part then
                    local ap = part.Position
                    local distToTarget = cd._distSq^0.5

                    if S.Aim.Pred then
                        local vel = part.AssemblyLinearVelocity
                        local vmag2 = vel.X*vel.X + vel.Y*vel.Y + vel.Z*vel.Z
                        if vmag2 > 90000 then  -- 300^2, avoids sqrt
                            local invM = 300 / mSqrt(vmag2)
                            vel = Vector3.new(vel.X*invM, vel.Y*invM, vel.Z*invM)
                        end
                        ap = ap + vel * S.Aim.PredStr
                    end
                    if S.Aim.OffX~=0 or S.Aim.OffY~=0 or S.Aim.OffZ~=0 then ap=ap+_aimOff end
                    local tCF = CF(camP, ap)

                    local apSc, on2 = cam:WorldToViewportPoint(ap)
                    local snap = false
                    if on2 then
                        local cx, cy = sw*0.5, sh*0.5
                        if S.FOV.Follow then local ms=UIS:GetMouseLocation(); cx=ms.X; cy=ms.Y end
                        local dx = apSc.X-cx; local dy = apSc.Y-cy
                        if dx*dx + dy*dy < 64 then snap=true end  -- 8^2=64, no sqrt needed
                    end

                    if S.Aim.HitChance >= 100 or mRand(1,100)<=S.Aim.HitChance then
                        if S.Aim.Smooth and not snap then
                            local sf = mClamp((S.Aim.SmoothSpd^1.5)*(dt*60), 0.01, 1)
                            cam.CFrame = cam.CFrame:Lerp(tCF, sf)
                        else cam.CFrame = tCF end
                    end

                    if S.Aim.LockTracer and cd._onSc then
                        setL(LTracer, V2(sw*0.5,sh*0.5), V2(cd._sp.X,cd._sp.Y), lockVis and WHITE or RED, 1.5, 1)
                    else if LTracer.Visible then LTracer.Visible=false end end


                    local maxHP  = mMax(1, cd._maxHP or 100)
                    local hp     = mClamp(cd.Hum.Health, 0, maxHP)
                    local pct    = hp / maxHP
                    local hpFlr  = mFloor(hp)
                    local dstFlr = mFloor(distToTarget)
                    -- Only rebuild format string when values actually changed
                    if hpFlr ~= _thudLastHP or dstFlr ~= _thudLastDist or tar.DisplayName ~= _thudLastName then
                        _thudLastHP   = hpFlr
                        _thudLastDist = dstFlr
                        _thudLastName = tar.DisplayName
                        THUD.Txt.Text = ("Target: %s  |  HP: %d/%d  |  %dm"):format(tar.DisplayName, hpFlr, mFloor(maxHP), dstFlr)
                    end
                    local w = mMax(260, THUD.Txt.TextBounds.X+30); local hh=26; local x=(sw-w)*0.5; local y=sh-100
                    setRect(THUD.BG,    V2(w,hh),            V2(x,y),    C3(20,20,25), 10, 0, 0.85, true)
                    THUD.Txt.Position = V2(sw*0.5, y+5); THUD.Txt.Visible=true
                    setRect(THUD.BarBG, V2(w,4),             V2(x,y+hh), C3(40,40,45), 11, 0, 1, true)
                    setRect(THUD.Bar,   V2(mMax(1,w*pct),4), V2(x,y+hh), HPC(pct),     12, 0, 1, true)
                end
            end
        end
    else
        if S.Aim.Target then ClearTarget() end  -- only call when there is something to clear
    end

    if not S.Aim.Target or not S.Aim.IsAiming then
        if LTracer.Visible then LTracer.Visible=false end
        if THUD.BG.Visible then THUD.BG.Visible=false; THUD.Txt.Visible=false; THUD.BarBG.Visible=false; THUD.Bar.Visible=false end
    end
end

-- ==============================================================================
--  13. HEARTBEAT
-- ==============================================================================
local _hbActive = false
local _hbTimer = 0
local function TickHB(dt)
    do -- World/FOV overrides (guarded)
        if S.Mov.FOVOn then
            local cam = workspace.CurrentCamera
            if cam and cam.FieldOfView ~= S.Mov.CamFOV then cam.FieldOfView = S.Mov.CamFOV end
        end
        if S.Mov.GravOn and workspace.Gravity ~= S.Mov.Gravity then
            workspace.Gravity = S.Mov.Gravity
        end
        if S.World.On then
            local t = S.World.Time
            if Lit.ClockTime ~= t then Lit.ClockTime = t end
            local b = S.World.Bright
            if Lit.Brightness ~= b then Lit.Brightness = b end
            local s = S.World.Shadows
            if Lit.GlobalShadows ~= s then Lit.GlobalShadows = s end
            local a = S.World.Ambient
            if Lit.Ambient ~= a then Lit.Ambient = a end
        end
    end
    local mc = CC[LP]
    if mc and mc.Hum and mc.HRP then
        local hum = mc.Hum
        local mov = S.Mov
        if mov.SpeedOn  and hum.WalkSpeed ~= mov.Speed then hum.WalkSpeed = mov.Speed end
        if mov.JumpOn then
            if not hum.UseJumpPower then hum.UseJumpPower = true end
            if hum.JumpPower ~= mov.Jump then hum.JumpPower = mov.Jump end
        end
        if mov.BHop and hum.MoveDirection.Magnitude > 0 then
            if hum.FloorMaterial ~= Enum.Material.Air then hum.Jump = true end
        end
        
        if mov.SpinOn and mc.HRP then
            mc.HRP.CFrame = mc.HRP.CFrame * CFrame.Angles(0, math.rad(mov.SpinSpeed), 0)
        end
        
        if mov.FlyOn and mc.HRP then
            local cam = workspace.CurrentCamera
            local moveDir = Vector3.zero
            if UIS:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + cam.CFrame.LookVector end
            if UIS:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - cam.CFrame.LookVector end
            if UIS:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + cam.CFrame.RightVector end
            if UIS:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - cam.CFrame.RightVector end
            if UIS:IsKeyDown(Enum.KeyCode.Space) then moveDir = moveDir + Vector3.new(0, 1, 0) end
            if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then moveDir = moveDir + Vector3.new(0, -1, 0) end
            
            mc.HRP.AssemblyLinearVelocity = moveDir.Magnitude > 0 and (moveDir.Unit * mov.FlySpeed) or Vector3.zero
            mc.HRP.AssemblyAngularVelocity = Vector3.zero
            workspace.Gravity = 0
        elseif S.Mov.GravOn then
            workspace.Gravity = S.Mov.Gravity
        else
            workspace.Gravity = 196.2
        end
    end


    if S.HB.On then
        _hbActive=true
        _hbTimer = _hbTimer + dt
        if _hbTimer >= 0.1 then
            _hbTimer = 0
            local newSz=V3(S.HB.Size,S.HB.Size,S.HB.Size); local newTr=S.HB.Trans
            local _plCount = #PList
            for ii=1,_plCount do
                local pl=PList[ii]; if S.Aim.TeamCheck and IsTeam(pl) then continue end
                local cd=CC[pl]
                if cd and cd.Hum and cd.Hum.Health>0 and cd._wsValid then
                    local part = S.HB.Part=="Head" and cd.Head or (S.HB.Part=="HumanoidRootPart" and cd.HRP or cd.Char:FindFirstChild(S.HB.Part))
                    if part and part:IsA("BasePart") then
                        if not HBOrig[pl] then HBOrig[pl]={} end
                        if not HBOrig[pl][part] then HBOrig[pl][part]={Size=part.Size,Trans=part.Transparency,CC=part.CanCollide} end
                        if part.Size~=newSz then part.Size=newSz end
                        if part.Transparency~=newTr then part.Transparency=newTr end
                        if part.CanCollide then part.CanCollide=false end
                    end
                end
            end
        end
    elseif _hbActive then
        for pl,parts in pairs(HBOrig) do
            for part,d in pairs(parts) do if part and part.Parent then part.Size=d.Size; part.Transparency=d.Trans; part.CanCollide=d.CC end end
        end
        if next(HBOrig) then tClear(HBOrig) end
        _hbActive=false
    end
end

-- ==============================================================================
--  14. RENDER STEPPED
-- ==============================================================================
local function TickRender(dt)
    local cam=workspace.CurrentCamera; if not cam then return end
    -- FPS tracking (merged, no extra connection needed)
    _fpsCount = _fpsCount + 1
    local _fpsNow = os.clock()
    if _fpsNow - _fpsLast >= 1 then
        fps = math.floor(_fpsCount / (_fpsNow - _fpsLast))
        _fpsCount = 0
        _fpsLast  = _fpsNow
    end
    local vp=cam.ViewportSize; if vp.X==0 or vp.Y==0 then return end
    local cp=cam.CFrame.Position; local sw,sh=vp.X,vp.Y
    local myC=CC[LP]; local myP=(myC and myC.HRP) and myC.HRP.Position or cp

    local _plCount = #PList
    for i=1,_plCount do
        local pl=PList[i]; local cd=CC[pl]
        local _ph = cd and cd.Hum and cd.Hum.Health
        if cd and cd.HRP and _ph and _ph > 0 then
            if cd.HRP.Parent then
                cd._wsValid=true
                local hp=cd.HRP.Position
                local sp,on=cam:WorldToViewportPoint(hp)
                cd._sp=sp; cd._onSc=on; cd._depth=sp.Z
                local dx,dy,dz=hp.X-myP.X,hp.Y-myP.Y,hp.Z-myP.Z
                cd._distSq=dx*dx+dy*dy+dz*dz
            else cd._wsValid=false; cd._onSc=false; cd._depth=0 end
        else if cd then cd._wsValid=false; cd._onSc=false; cd._depth=0 end end
    end

    local _cX, _cY = sw*0.5, sh*0.5
    local fovP = TickFOV(V2(_cX, _cY), cam, dt)
    TickAim(cp, sw, sh, dt, fovP, cam)
    

end

tIns(Conns, RS.Heartbeat:Connect(TickHB))
tIns(Conns, RS.RenderStepped:Connect(TickRender))





-- ==============================================================================
--  15. WINDUI 
-- ==============================================================================


local Window = Library:CreateWindow({
    Title = "KAIM v11",
    Footer = "v11 | github.com/sswird/kaim",
    Icon = 95816097006870,
    NotifySide = "Right",
    ShowCustomCursor = false,
})

local Tabs = {
    Home    = Window:AddTab("Home", "home"),
    Combat  = Window:AddTab("Combat", "crosshair"),
    Visuals = Window:AddTab("Visuals", "eye"),
    Player  = Window:AddTab("Player", "user"),
    Settings = Window:AddTab("Settings", "settings"),
    Extra    = Window:AddTab("Extra Stuff", "file"),
}

local KaimWatermark = Library:AddDraggableLabel("KAIM v11 | FPS: 0 | Ping: 0ms")

-- ==============================================================================
--  HOME TAB
-- ==============================================================================
local _gameName = "Unknown"
pcall(function() _gameName = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name end)
local _exeName = (identifyexecutor and identifyexecutor()) or (syn and "Synapse") or "Unknown"

local HomeLeft = Tabs.Home:AddLeftGroupbox("Session")
HomeLeft:AddLabel("Player: " .. LP.Name)
HomeLeft:AddLabel("Game: " .. _gameName)
HomeLeft:AddLabel("Place: " .. tostring(game.PlaceId))
HomeLeft:AddLabel("Executor: " .. _exeName)

local HomeRight = Tabs.Home:AddRightGroupbox("About KAIM")
HomeRight:AddLabel("KAIM v11")
HomeRight:AddLabel("by sswird")
HomeRight:AddDivider()
HomeRight:AddLabel("Aimlock  |  ESP  |  Player Mods")

HomeRight:AddImage("KaimLogo", {
    Image = "rbxthumb://type=Asset&id=88692317010756&w=420&h=420",
    Height = 150,
})

-- ==============================================================================
--  COMBAT TAB
-- ==============================================================================

-- [ Aimlock ]
local AimLeft = Tabs.Combat:AddLeftGroupbox("Aimlock")
AimLeft:AddToggle("AimOn", {Text="Enable Aimlock", Default=false, Tooltip="Locks your camera onto the nearest enemy.", Callback=function(v) S.Aim.On=v end})
AimLeft:AddDropdown("AimKey",  {Text="Hold Key",    Default="RightClick", Values={"RightClick","LeftClick","E","Q","F","C","V","X","Z","LeftShift","LeftAlt"}, Callback=function(v) _aimKC=v end})
AimLeft:AddDropdown("AimPref", {Text="Target Part", Default="Smart",      Values={"Smart","Nearest Part","Chaos","Head","Torso","Limbs"}, Callback=function(v) S.Aim.Mode=v end})

-- [ Smooth Aim ]
local SmoothRight = Tabs.Combat:AddRightGroupbox("Smooth Aim")
SmoothRight:AddToggle("SmoothOn", {Text="Enable Smooth Aim", Default=false, Callback=function(v) S.Aim.Smooth=v end})
SmoothRight:AddSlider("SmoothAmt", {Text="Smoothness", Default=5, Min=1, Max=20, Rounding=1, Callback=function(v) S.Aim.SmoothSpd=(v/10) end})

-- [ Safety Checks ]
local CheckRight = Tabs.Combat:AddRightGroupbox("Safety Checks")
CheckRight:AddToggle("WallCheck", {Text="Wall Check", Default=true, Callback=function(v) S.Aim.WallCheck=v end})
CheckRight:AddSlider("WallCheckDelay", {Text="Wall Check Delay (s)", Default=0.5, Min=0, Max=3, Rounding=1, Callback=function(v) S.Aim.WallCheckDelay=v end})
CheckRight:AddToggle("TeamCheck", {Text="Team Check", Default=true, Callback=function(v) S.Aim.TeamCheck=v end})
CheckRight:AddToggle("EspTarg", {Text="ESP Targets Only", Default=false, Callback=function(v) S.Aim.ESPTargetsOnly=v end})

-- [ Feedback ]
local FeedbackRight = Tabs.Combat:AddRightGroupbox("Lock Feedback")
FeedbackRight:AddToggle("LockSnd", {Text="Lock Sound", Default=true, Callback=function(v) S.Aim.SoundCue=v end})
FeedbackRight:AddInput("LockSndID", {Text="Sound ID", Default="127004816100960", Finished=false, Placeholder="Asset ID", Tooltip="Change aimlock sound", Callback=function(v)
    if v and v ~= "" then lockSound.SoundId = "rbxassetid://"..tostring(v) end
end})
FeedbackRight:AddToggle("LockTrac", {Text="Lock Tracer", Default=true, Callback=function(v) S.Aim.LockTracer=v end})

-- [ FOV Circle ]
local FovRight = Tabs.Combat:AddRightGroupbox("FOV Circle")
FovRight:AddToggle("ShowFov", {Text="Show FOV Circle", Default=true, Callback=function(v) S.FOV.Show=v; if FOVR then FOVR.Visible=v; FOVF.Visible=v end end})
FovRight:AddSlider("FovRad", {Text="FOV Radius", Default=150, Min=10, Max=800, Rounding=0, Callback=function(v) S.FOV.Radius=v; if FOVR then FOVR.Radius=v; FOVF.Radius=v end end})

-- [ Hitbox Expander ]
local HitboxLeft = Tabs.Combat:AddLeftGroupbox("Hitbox Expander")
HitboxLeft:AddToggle("H_On", {Text="Enable Hitbox Expander", Default=false, Callback=function(v) S.HB.On=v end})
HitboxLeft:AddDropdown("H_Part", {Text="Expand Part", Default="Head", Values={"Head","HumanoidRootPart","UpperTorso"}, Callback=function(v) S.HB.Part=v end})
HitboxLeft:AddSlider("H_Size", {Text="Expand Size", Default=5, Min=2, Max=30, Rounding=0, Callback=function(v) S.HB.Size=v end})

-- ==============================================================================
--  VISUALS TAB
-- ==============================================================================

-- [ ESP - Tabbox for Enemy / Friendly ]
local VisTabBox = Tabs.Visuals:AddLeftTabbox()
local VisEnemy  = VisTabBox:AddTab("Enemy")
local VisFriend = VisTabBox:AddTab("Friendly")

-- ── Enemy ──────────────────────────────────────────────────
local _eS = function() return getgenv().SenseESP and getgenv().SenseESP.teamSettings.enemy end
VisEnemy:AddToggle("E_On", {Text="Enable Enemy ESP", Tooltip="Master switch for all enemy ESP.", Default=false,
    Callback=function(v) local s=_eS(); if s then s.enabled=v end end})
VisEnemy:AddDivider()
-- Boxes
VisEnemy:AddToggle("E_2D",  {Text="2D Box",      Default=false, Callback=function(v) local s=_eS(); if s then s.box=v end end})
VisEnemy:AddToggle("E_3D",  {Text="3D Box",      Default=false, Callback=function(v) local s=_eS(); if s then s.box3d=v end end})
-- Info
VisEnemy:AddToggle("E_Name",{Text="Name Tag",    Default=false, Callback=function(v) local s=_eS(); if s then s.name=v end end})
VisEnemy:AddToggle("E_Dist",{Text="Distance",    Default=false, Callback=function(v) local s=_eS(); if s then s.distance=v end end})
VisEnemy:AddToggle("E_HB",  {Text="Health Bar",  Default=false, Callback=function(v) local s=_eS(); if s then s.healthBar=v end end})
VisEnemy:AddToggle("E_Wep", {Text="Weapon Name", Default=false, Callback=function(v) local s=_eS(); if s then s.weapon=v end end})
VisEnemy:AddToggle("E_Head",{Text="Head Dot",    Default=false, Tooltip="Small dot at head position. Zero extra performance cost.",
    Callback=function(v) local s=_eS(); if s then s.headDot=v end end})
VisEnemy:AddDivider()
-- Tracer
VisEnemy:AddToggle("E_Trac",{Text="Tracer",      Default=false, Callback=function(v) local s=_eS(); if s then s.tracer=v end end})
VisEnemy:AddDropdown("E_TrOrigin",{Text="Tracer Origin", Default="Bottom", Values={"Bottom","Middle","Top"},
    Callback=function(v) local s=_eS(); if s then s.tracerOrigin=v end end})
VisEnemy:AddDivider()
-- Chams
VisEnemy:AddToggle("E_Cham",  {Text="Chams",              Default=false, Callback=function(v) local s=_eS(); if s then s.chams=v end end})
VisEnemy:AddToggle("E_ChamVO",{Text="Visible-Only Chams", Default=true,
    Tooltip="ON: chams only show on visible players (not through walls). OFF: always on top.",
    Callback=function(v) local s=_eS(); if s then s.chamsVisibleOnly=v end end})

-- ── Friendly ───────────────────────────────────────────────
local _fS = function() return getgenv().SenseESP and getgenv().SenseESP.teamSettings.friendly end
VisFriend:AddToggle("F_On", {Text="Enable Friendly ESP", Tooltip="Master switch for all friendly ESP.", Default=false,
    Callback=function(v) local s=_fS(); if s then s.enabled=v end end})
VisFriend:AddDivider()
-- Boxes
VisFriend:AddToggle("F_2D",  {Text="2D Box",      Default=false, Callback=function(v) local s=_fS(); if s then s.box=v end end})
VisFriend:AddToggle("F_3D",  {Text="3D Box",      Default=false, Callback=function(v) local s=_fS(); if s then s.box3d=v end end})
-- Info
VisFriend:AddToggle("F_Name",{Text="Name Tag",    Default=false, Callback=function(v) local s=_fS(); if s then s.name=v end end})
VisFriend:AddToggle("F_Dist",{Text="Distance",    Default=false, Callback=function(v) local s=_fS(); if s then s.distance=v end end})
VisFriend:AddToggle("F_HB",  {Text="Health Bar",  Default=false, Callback=function(v) local s=_fS(); if s then s.healthBar=v end end})
VisFriend:AddToggle("F_Wep", {Text="Weapon Name", Default=false, Callback=function(v) local s=_fS(); if s then s.weapon=v end end})
VisFriend:AddToggle("F_Head",{Text="Head Dot",    Default=false, Tooltip="Small dot at head position.",
    Callback=function(v) local s=_fS(); if s then s.headDot=v end end})
VisFriend:AddDivider()
-- Tracer
VisFriend:AddToggle("F_Trac",{Text="Tracer",      Default=false, Callback=function(v) local s=_fS(); if s then s.tracer=v end end})
VisFriend:AddDropdown("F_TrOrigin",{Text="Tracer Origin", Default="Bottom", Values={"Bottom","Middle","Top"},
    Callback=function(v) local s=_fS(); if s then s.tracerOrigin=v end end})
VisFriend:AddDivider()
-- Chams
VisFriend:AddToggle("F_Cham",  {Text="Chams",              Default=false, Callback=function(v) local s=_fS(); if s then s.chams=v end end})
VisFriend:AddToggle("F_ChamVO",{Text="Visible-Only Chams", Default=true,
    Tooltip="ON: chams only show on visible players. OFF: always on top.",
    Callback=function(v) local s=_fS(); if s then s.chamsVisibleOnly=v end end})

-- [ Global ESP Settings - Right side ]
local VisSettings = Tabs.Visuals:AddRightGroupbox("Global Settings")
VisSettings:AddToggle("G_Lim",  {Text="Limit Distance",       Default=false,
    Callback=function(v) local s=getgenv().SenseESP; if s then s.sharedSettings.limitDistance=v end end})
VisSettings:AddSlider("G_MaxD", {Text="Max Distance (studs)",  Default=1000, Min=50, Max=5000, Rounding=0,
    Callback=function(v) local s=getgenv().SenseESP; if s then s.sharedSettings.maxDistance=v end end})
VisSettings:AddSlider("G_TxtSz",{Text="Text Size",             Default=13,   Min=8,  Max=24,   Rounding=0,
    Callback=function(v) local s=getgenv().SenseESP; if s then s.sharedSettings.textSize=v end end})
VisSettings:AddLabel("Text Color"):AddColorPicker("G_TxtCol",{Default=Color3.new(1,1,1),
    Callback=function(v) local s=getgenv().SenseESP; if s then s.sharedSettings.textColor=v end end})
VisSettings:AddToggle("G_TCol", {Text="Use Team Colors",       Default=false,
    Callback=function(v) local s=getgenv().SenseESP; if s then s.sharedSettings.useTeamColor=v end end})

-- ==============================================================================
--  PLAYER TAB
-- ==============================================================================

-- [ Movement ]
local MovChar = Tabs.Player:AddLeftGroupbox("Movement")
MovChar:AddToggle("P_WSOn", {Text="Speed Boost", Default=false, Callback=function(v) S.Mov.SpeedOn=v; if not v and CC[LP] and CC[LP].Hum then CC[LP].Hum.WalkSpeed=16 end end})
MovChar:AddSlider("P_WS",   {Text="Walk Speed", Default=16, Min=16, Max=150, Rounding=0, Callback=function(v) S.Mov.Speed=v end})
MovChar:AddToggle("P_JPOn", {Text="Jump Boost", Default=false, Callback=function(v) S.Mov.JumpOn=v end})
MovChar:AddSlider("P_JP",   {Text="Jump Power", Default=50, Min=50, Max=300, Rounding=0, Callback=function(v) S.Mov.Jump=v end})
MovChar:AddToggle("P_InfJ", {Text="Infinite Jump", Default=false, Callback=function(v) S.Mov.InfJump=v end})
MovChar:AddToggle("U_NC",   {Text="Noclip (N)", Default=false, Callback=function(v) SetNC(v) end})
MovChar:AddToggle("P_Fly",  {Text="Fly", Default=false, Callback=function(v) S.Mov.FlyOn=v end})
MovChar:AddSlider("P_FlyS", {Text="Fly Speed", Default=50, Min=10, Max=200, Rounding=0, Callback=function(v) S.Mov.FlySpeed=v end})
MovChar:AddToggle("P_Spin", {Text="Spinbot", Default=false, Callback=function(v) S.Mov.SpinOn=v end})
MovChar:AddSlider("P_SpinS",{Text="Spin Speed", Default=20, Min=5, Max=100, Rounding=0, Callback=function(v) S.Mov.SpinSpeed=v end})

-- [ World ]
local MovWorld = Tabs.Player:AddRightGroupbox("World")
MovWorld:AddToggle("W_GravOn", {Text="Override Gravity", Default=false, Callback=function(v) S.Mov.GravOn=v; if not v then workspace.Gravity=196.2 end end})
MovWorld:AddSlider("W_Grav",   {Text="Gravity", Default=196, Min=0, Max=500, Rounding=0, Callback=function(v) S.Mov.Gravity=v end})
MovWorld:AddToggle("W_FOVOn",  {Text="Override Camera FOV", Default=false, Callback=function(v) S.Mov.FOVOn=v; if not v then pcall(function() workspace.CurrentCamera.FieldOfView=70 end) end end})
MovWorld:AddSlider("W_FOV",    {Text="Camera FOV", Default=70, Min=10, Max=120, Rounding=0, Callback=function(v) S.Mov.CamFOV=v end})

-- [ Lighting ]
local MovLighting = Tabs.Player:AddRightGroupbox("Lighting")
MovLighting:AddToggle("W_LitOn", {Text="Override Lighting", Default=false, Callback=function(v) S.World.On=v; if not v then pcall(function() Lit.ClockTime=OrigLit.T; Lit.Brightness=OrigLit.B; Lit.GlobalShadows=OrigLit.S; Lit.Ambient=OrigLit.A end) end end})
MovLighting:AddSlider("W_Time",  {Text="Time of Day", Default=14, Min=0, Max=24, Rounding=1, Callback=function(v) S.World.Time=v end})

-- ==============================================================================
--  EXTRA STUFF TAB
-- ==============================================================================
local _currentSong = nil
local _currentSongName = ""
local _songVol = 2

-- Create custom Standalone GUI specifically for the media player
local AudioGUI = iNew("ScreenGui")
AudioGUI.Name = "KAIM_AudioPlayer"
AudioGUI.ResetOnSpawn = false
AudioGUI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
AudioGUI.Parent = SafeGui

local MainFrame = iNew("Frame")
MainFrame.Size = UDim2.fromOffset(250, 60)
MainFrame.Position = UDim2.fromOffset(100, 100)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
MainFrame.BorderSizePixel = 0
MainFrame.Visible = false
MainFrame.Parent = AudioGUI

local corner = iNew("UICorner")
corner.CornerRadius = UDim.new(0, 6)
corner.Parent = MainFrame

local outline = iNew("UIStroke")
outline.Color = Color3.fromRGB(50, 50, 50)
outline.Parent = MainFrame

local SongLabel = iNew("TextLabel")
SongLabel.BackgroundTransparency = 1
SongLabel.Size = UDim2.new(1, -30, 0, 20)
SongLabel.Position = UDim2.new(0, 5, 0, 0)
SongLabel.Text = "No Song"
SongLabel.TextColor3 = Color3.new(1,1,1)
SongLabel.Font = Enum.Font.Code
SongLabel.TextSize = 13
SongLabel.TextXAlignment = Enum.TextXAlignment.Left
SongLabel.Parent = MainFrame

local CloseBtn = iNew("TextButton")
CloseBtn.BackgroundTransparency = 1
CloseBtn.Size = UDim2.new(0, 20, 0, 20)
CloseBtn.Position = UDim2.new(1, -25, 0, 0)
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.new(1, 0.3, 0.3)
CloseBtn.Font = Enum.Font.Code
CloseBtn.TextSize = 15
CloseBtn.Parent = MainFrame

-- Full screen subliminal flash overlay for Epstein Edit
local IslandOverlay = iNew("ImageLabel")
IslandOverlay.Image = "rbxassetid://42093013"
IslandOverlay.Size = UDim2.new(1, 0, 1, 0)
IslandOverlay.BackgroundTransparency = 1
IslandOverlay.ImageTransparency = 1
IslandOverlay.ImageColor3 = Color3.fromRGB(255, 50, 50)
IslandOverlay.ZIndex = -10
IslandOverlay.Parent = AudioGUI

-- Time Slider
local TimeBG = iNew("Frame")
TimeBG.BackgroundColor3 = Color3.new(0.15, 0.15, 0.15)
TimeBG.Size = UDim2.new(1, -10, 0, 8)
TimeBG.Position = UDim2.new(0, 5, 0, 25)
TimeBG.BorderSizePixel = 0
TimeBG.Parent = MainFrame

local TimeFill = iNew("Frame")
TimeFill.BackgroundColor3 = Color3.fromRGB(0, 162, 255)
TimeFill.Size = UDim2.new(0, 0, 1, 0)
TimeFill.BorderSizePixel = 0
TimeFill.Parent = TimeBG

local TimeBtn = iNew("TextButton")
TimeBtn.BackgroundTransparency = 1
TimeBtn.Size = UDim2.new(1, 0, 1, 0)
TimeBtn.Text = ""
TimeBtn.Parent = TimeBG

-- Volume Slider
local VolBG = iNew("Frame")
VolBG.BackgroundColor3 = Color3.new(0.15, 0.15, 0.15)
VolBG.Size = UDim2.new(1, -10, 0, 8)
VolBG.Position = UDim2.new(0, 5, 0, 40)
VolBG.BorderSizePixel = 0
VolBG.Parent = MainFrame

local VolFill = iNew("Frame")
VolFill.BackgroundColor3 = Color3.fromRGB(0, 255, 100)
VolFill.Size = UDim2.new(0.2, 0, 1, 0) -- default 2 out of 10
VolFill.BorderSizePixel = 0
VolFill.Parent = VolBG

local VolBtn = iNew("TextButton")
VolBtn.BackgroundTransparency = 1
VolBtn.Size = UDim2.new(1, 0, 1, 0)
VolBtn.Text = ""
VolBtn.Parent = VolBG

-- Custom Dragging Logic for the MainFrame
local dragging = false
local dragStart, startPos
MainFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
    end
end)
UIS.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)
UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

local function clearEpstein()
    pcall(function()
        local cam = workspace.CurrentCamera
        if cam and cam.CameraType == Enum.CameraType.Scriptable then
            cam.CameraType = Enum.CameraType.Custom
        end
        outline.Color = Color3.fromRGB(50, 50, 50)
        if IslandOverlay then IslandOverlay.ImageTransparency = 1 end
    end)
end

CloseBtn.MouseButton1Click:Connect(function()
    if _currentSong then _currentSong:Destroy(); _currentSong = nil end
    MainFrame.Visible = false
    clearEpstein()
end)

-- Slider Logic
local isDraggingTime = false
local isDraggingVol = false
TimeBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        isDraggingTime = true
    end
end)
VolBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        isDraggingVol = true
    end
end)
UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        isDraggingTime = false
        isDraggingVol = false
    end
end)

local epsteinT = 0
RS.RenderStepped:Connect(function(dt)
    if not _currentSong then return end
    
    if _currentSongName == "Epstein Edit" and _currentSong.IsPlaying then
        epsteinT = epsteinT + dt
        local cam = workspace.CurrentCamera
        local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        if cam and hrp then
            cam.CameraType = Enum.CameraType.Scriptable
            local pos = _currentSong.TimePosition
            
            if pos < 20 then
                -- Do nothing, let it play normally before 20s
                if cam.CameraType == Enum.CameraType.Scriptable then
                    cam.CameraType = Enum.CameraType.Custom
                end
            elseif pos < 23 then
                -- Map Overview (Pan down from sky)
                cam.CameraType = Enum.CameraType.Scriptable
                local targetPos = hrp.Position + Vector3.new(0, 150 - ((pos - 20) * 20), 0)
                cam.CFrame = cam.CFrame:Lerp(CFrame.lookAt(targetPos, hrp.Position), dt * 3)
            elseif pos < 26 then
                -- Right Orbit (Swoop and pan) with TikTok Stutter
                cam.CameraType = Enum.CameraType.Scriptable
                local orbitRadius = 25 - ((pos - 23) * 2)
                local angle = (pos - 23) * (math.pi / 4)
                local offset = Vector3.new(math.cos(angle) * orbitRadius, 5, math.sin(angle) * orbitRadius)
                
                -- The Velocity Stutter (snaps left/right randomly on beats)
                local stutterX = 0
                if math.floor(epsteinT * 12) % 5 == 0 then
                    stutterX = (math.random() - 0.5) * 12 -- Aggressive horizontal glitch
                end
                
                cam.CFrame = cam.CFrame:Lerp(CFrame.lookAt(hrp.Position + offset + Vector3.new(stutterX,0,0), hrp.Position), dt * 4)
                IslandOverlay.ImageTransparency = 1
            else
                -- The Drop! High intensity shakes & stutter
                cam.CameraType = Enum.CameraType.Scriptable
                local beat = math.abs(math.sin(epsteinT * 8)) -- fast beat
                local shakeX = (math.random() - 0.5) * 8
                local shakeY = (math.random() - 0.5) * 8
                
                -- Stuttering effect: every few frames we snap the FOV or rotation aggressively
                local isStutterFrame = (math.floor(epsteinT * 12) % 4 == 0)
                if isStutterFrame then
                    cam.FieldOfView = 20
                    shakeX = shakeX * 3
                else
                    cam.FieldOfView = 70 + (beat * 30)
                end
                
                local orbitRadius = 15
                local angle = (pos - 26) * (math.pi / 2)
                local baseOffset = Vector3.new(math.cos(angle) * orbitRadius, 5 + beat*2, math.sin(angle) * orbitRadius)
                local baseCFrame = CFrame.lookAt(hrp.Position + baseOffset, hrp.Position)
                
                cam.CFrame = baseCFrame * CFrame.Angles(math.rad(shakeX), math.rad(shakeY), math.rad(shakeX*0.5))
                
                -- Subliminal Island Flash Overlay on heavy beats
                if beat > 0.85 then
                    IslandOverlay.ImageTransparency = 0.4
                    outline.Color = Color3.fromHSV(math.random(), 1, 1)
                else
                    IslandOverlay.ImageTransparency = IslandOverlay.ImageTransparency + (dt * 5)
                    outline.Color = Color3.fromRGB(50, 50, 50)
                end
            end
        end
    end
    
    if isDraggingTime then
        local ms = UIS:GetMouseLocation()
        local pct = math.clamp((ms.X - TimeBG.AbsolutePosition.X) / TimeBG.AbsoluteSize.X, 0, 1)
        TimeFill.Size = UDim2.new(pct, 0, 1, 0)
        _currentSong.TimePosition = pct * _currentSong.TimeLength
    else
        local len = _currentSong.TimeLength
        if len > 0 then
            TimeFill.Size = UDim2.new(_currentSong.TimePosition / len, 0, 1, 0)
            local pos = _currentSong.TimePosition
            local fPos = string.format("%02d:%02d", math.floor(pos/60), math.floor(pos%60))
            local fLen = string.format("%02d:%02d", math.floor(len/60), math.floor(len%60))
            SongLabel.Text = _currentSongName .. " | " .. fPos .. " / " .. fLen
        end
    end
    
    if isDraggingVol then
        local ms = UIS:GetMouseLocation()
        local pct = math.clamp((ms.X - VolBG.AbsolutePosition.X) / VolBG.AbsoluteSize.X, 0, 1)
        VolFill.Size = UDim2.new(pct, 0, 1, 0)
        _songVol = pct * 10
        _currentSong.Volume = _songVol
    end
end)

local function PlaySong(id, name)
    if _currentSong then _currentSong:Destroy(); _currentSong = nil end
    clearEpstein()
    if id == nil then return end
    
    local snd = iNew("Sound")
    snd.SoundId = "rbxassetid://"..tostring(id)
    snd.Volume = _songVol
    snd.Parent = SafeGui
    snd:Play()
    
    if name == "Epstein Edit" then
        snd.TimePosition = 20
    end
    
    _currentSong = snd
    _currentSongName = name
    epsteinT = 0
    MainFrame.Visible = true
    
    snd.Ended:Connect(function()
        if _currentSong == snd then 
            _currentSong:Destroy()
            _currentSong = nil 
            MainFrame.Visible = false
            clearEpstein()
        end
    end)
end

local ExtraSongs = Tabs.Extra:AddLeftGroupbox("Songs")

ExtraSongs:AddButton({
    Text = "Bumblebee",
    Tooltip = "Plays Bumblebee",
    Func = function() PlaySong("139067966802141", "Bumblebee") end
})

ExtraSongs:AddButton({
    Text = "Epstein Edit",
    Tooltip = "Plays Epstein Edit",
    Func = function() PlaySong("108197545114032", "Epstein Edit") end
})






-- ==============================================================================
--  CONFIG TAB
-- ==============================================================================
ThemeManager:SetLibrary(Library)

-- Inject custom KAIM themes
ThemeManager.BuiltInThemes["KAIM Crimson"] = { 100, { FontColor = "ffffff", MainColor = "141414", AccentColor = "ff2a2a", BackgroundColor = "0a0a0a", OutlineColor = "282828", BackgroundImage = "" } }
ThemeManager.BuiltInThemes["KAIM Cyber"] = { 101, { FontColor = "ffffff", MainColor = "0a0f1a", AccentColor = "00e5ff", BackgroundColor = "050810", OutlineColor = "152540", BackgroundImage = "" } }
ThemeManager.BuiltInThemes["KAIM Gold"] = { 102, { FontColor = "ffffff", MainColor = "121212", AccentColor = "ffd700", BackgroundColor = "080808", OutlineColor = "302b1f", BackgroundImage = "" } }
SaveManager:SetLibrary(Library)

SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({"MenuKeybind"})
-- SaveManager handles folder creation automatically
ThemeManager:SetFolder("KAIM_v11")
SaveManager:SetFolder("KAIM_v11/configs")

SaveManager:BuildConfigSection(Tabs.Settings)
ThemeManager:ApplyToTab(Tabs.Settings)

-- Menu toggle keybind
local MenuLeft = Tabs.Settings:AddLeftGroupbox("Menu")
MenuLeft:AddLabel("Toggle Menu Key"):AddKeyPicker("MenuKeybind", {
    Default = "RightAlt",
    NoUI    = false,
    Mode    = "Toggle",
})

-- Sync picker -> Library's built-in keybind listener on every change
if Library.Keybinds and Library.Keybinds["MenuKeybind"] then
    Library.Keybinds["MenuKeybind"]:OnChanged(function()
        Library.ToggleKeybind = Library.Keybinds["MenuKeybind"].Value
    end)
elseif Library.Options and Library.Options["MenuKeybind"] then
    Library.Options["MenuKeybind"]:OnChanged(function()
        Library.ToggleKeybind = Library.Options["MenuKeybind"].Value
    end)
end
-- Apply immediately on load
Library.ToggleKeybind = Enum.KeyCode.RightAlt

local DangerRight = Tabs.Settings:AddRightGroupbox("Danger Zone")
DangerRight:AddButton({
    Text = "Unload KAIM",
    Tooltip = "Safely reverts all changes and destroys the UI.",
    Risky = true,
    Func = function() pcall(_env.KAIM_UNLOAD) end,
})

SaveManager:LoadAutoloadConfig()

local lastUIRefresh = os.clock()
tIns(Conns, RS.Heartbeat:Connect(function()
    local now = os.clock()
    if now - lastUIRefresh >= 0.5 then
        local ping = 0
        local stats = game:GetService("Stats")
        if stats and stats.Network and stats.Network.ServerStatsItem and stats.Network.ServerStatsItem["Data Ping"] then
            ping = stats.Network.ServerStatsItem["Data Ping"]:GetValue()
        end
        KaimWatermark:SetText("KAIM v11 | FPS: " .. tostring(fps) .. " | Ping: " .. mFloor(ping) .. "ms")
        lastUIRefresh = now
    end
end))

_env.KAIM_UNLOAD = function()
    ClearTarget()
    for i=1,#Conns do pcall(function() Conns[i]:Disconnect() end) end
    pcall(function() getgenv().SenseESP.Unload() end)
    SetNC(false)
    if S.Mov.FOVOn then pcall(function() workspace.CurrentCamera.FieldOfView=70 end) end
    if S.Mov.GravOn then pcall(function() workspace.Gravity=196.2 end) end
    if S.World.On then pcall(function() Lit.ClockTime=OrigLit.T; Lit.Brightness=OrigLit.B; Lit.GlobalShadows=OrigLit.S; Lit.Ambient=OrigLit.A end) end
    if CC[LP] and CC[LP].Hum then CC[LP].Hum.WalkSpeed=16; CC[LP].Hum.UseJumpPower=true; CC[LP].Hum.JumpPower=50 end
    for pl,parts in pairs(HBOrig) do for part,d in pairs(parts) do if part and part.Parent then part.Size=d.Size; part.Transparency=d.Trans; part.CanCollide=d.CC end end end
    pcall(function() FOVR:Remove(); FOVF:Remove(); LTracer:Remove() end)
    pcall(function() lockSound:Destroy(); uiOnSound:Destroy(); uiOffSound:Destroy(); loadSound:Destroy(); clickSound:Destroy() end)
    pcall(function() for _,v in pairs(THUD) do v:Remove() end end)
    if _currentSong then pcall(function() _currentSong:Destroy() end) end
_env.KAIM_LOADED=false; _G._KaimNC=nil
    Library:Notify({Title="KAIM", Description="Unloaded safely.", Time=3})
    pcall(function()
        local us = iNew("Sound")
        us.SoundId = "rbxassetid://77698691659588"
        us.Volume = 10
        us.Parent = game:GetService("CoreGui")
        us:Play()
        game:GetService("Debris"):AddItem(us, 10)
    end)
    Library:Unload()
end

-- ==============================================================================
--  INPUT HANDLING
-- ==============================================================================
tIns(Conns, UIS.JumpRequest:Connect(function()
    if S.Mov.InfJump and LP.Character and CC[LP] and CC[LP].Hum then
        CC[LP].Hum:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end))

local _isUiOpen = true
tIns(Conns, UIS.InputBegan:Connect(function(inp, gpe)
    -- Allow mouse buttons even if gpe is true (e.g. right click camera movement)
    if gpe and inp.UserInputType == Enum.UserInputType.Keyboard then return end

    -- Global UI Click Sound
    if gpe and inp.UserInputType == Enum.UserInputType.MouseButton1 and _isUiOpen then
        pcall(function() clickSound:Play() end)
    end

    -- Check for UI Toggle sound
    if inp.KeyCode == Library.ToggleKeybind then
        _isUiOpen = not _isUiOpen
        if _isUiOpen then pcall(function() uiOnSound:Play() end) else pcall(function() uiOffSound:Play() end) end
    end

    pcall(function()
        if _aimKC == "RightClick" and inp.UserInputType == Enum.UserInputType.MouseButton2 then
            S.Aim.IsAiming = true
            S.Aim.HasLockedThisPress = false
        elseif _aimKC == "LeftClick" and inp.UserInputType == Enum.UserInputType.MouseButton1 then
            S.Aim.IsAiming = true
            S.Aim.HasLockedThisPress = false
        elseif type(_aimKC) == "string" and inp.KeyCode.Name == _aimKC then
            S.Aim.IsAiming = true
            S.Aim.HasLockedThisPress = false
        end
    end)

    if inp.KeyCode == Enum.KeyCode.N then
        local ns = not S.Mov.Noclip; SetNC(ns)
        Library:Notify({Title="Noclip", Description="Noclip "..(ns and "ON" or "OFF"), Time=2})
    end
end))

tIns(Conns, UIS.InputEnded:Connect(function(inp, gpe)
    pcall(function()
        if _aimKC == "RightClick" and inp.UserInputType == Enum.UserInputType.MouseButton2 then
            S.Aim.IsAiming = false
            S.Aim.HasLockedThisPress = false
        elseif _aimKC == "LeftClick" and inp.UserInputType == Enum.UserInputType.MouseButton1 then
            S.Aim.IsAiming = false
            S.Aim.HasLockedThisPress = false
        elseif type(_aimKC) == "string" and inp.KeyCode.Name == _aimKC then
            S.Aim.IsAiming = false
            S.Aim.HasLockedThisPress = false
        end
    end)
end))

-- ==============================================================================
--  17. INITIALIZATION COMPLETE
-- ==============================================================================
pcall(function() loadSound:Play() end)
Library:Notify({Title="KAIM Obsidian v11", Description="Loaded - Obsidian Edition", Time=4})


end, debug.traceback)
if not ok then warn("KAIM FATAL:\n"..tostring(err)) end
end)
