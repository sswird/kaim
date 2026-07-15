-- ==============================================================================
--       :::    :::           :::        :::::::::::         :::   ::: 
--      :+:   :+:          :+: :+:          :+:            :+:+: :+:+: 
--     +:+  +:+          +:+   +:+         +:+           +:+ +:+:+ +:+ 
--    +#++:++          +#++:++#++:        +#+           +#+  +:+  +#+  
--   +#+  +#+         +#+     +#+        +#+           +#+       +#+   
--  #+#   #+#        #+#     #+#        #+#           #+#       #+#    
-- ###    ###       ###     ###    ###########       ###       ###     
--                           [ v13 ]
-- ==============================================================================
--  • Obsidian UI (no Rayfield)
--  • Sirius Sense ESP (self-hosted)
--  • Single-Lock Aimbot | Zero-Bridge Drawing | Global Ray Cache
-- ==============================================================================
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

-- MEMORY OPTIMIZATIONS
local mFloor = math.floor
local mClamp = math.clamp
local mRand  = math.random
local mMax   = math.max
local mMin   = math.min   -- was missing; fixes ESP health bar gradient
local mRad   = math.rad   -- was missing; fixes SpinBot
local mAbs   = math.abs
local V2 = Vector2.new
local V3 = Vector3.new
local C3 = Color3.fromRGB
local C3N = Color3.new
local CF = CFrame.new

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

local SenseESP = (function()
-- ======================================================
--  KAIM Sense ESP  |  github.com/sswird/sense
--  v13 Optimized - single shared loop, event-driven chams
--  PERF: 40 Heartbeat connections  1 | Updates throttled to ~20 Hz
-- ======================================================

local runService  = game:GetService("RunService")
local players     = game:GetService("Players")
local workspace   = game:GetService("Workspace")

local localPlayer = players.LocalPlayer
local camera      = workspace.CurrentCamera

local floor   = mFloor
local round   = math.round
local clr     = table.clear
local unpack  = table.unpack
local find    = table.find
local tcreate = table.create

local lerpColor = function(c1, c2, alpha) return c1:Lerp(c2, alpha) end
local min2  = Vector2.zero.Min
local max2  = Vector2.zero.Max
local lerp2 = Vector2.zero.Lerp
local min3  = Vector3.zero.Min
local max3  = Vector3.zero.Max

local wtvp                  = camera.WorldToViewportPoint
local isA                   = workspace.IsA
local findFirstChild        = workspace.FindFirstChild
local findFirstChildOfClass = workspace.FindFirstChildOfClass
local getChildren           = workspace.GetChildren

local container = Instance.new("Folder", gethui and gethui() or game:GetService("CoreGui"))

local HP_BAR_OFF    = V2(5, 0)
local HP_TXT_OFF    = V2(3, 0)
local HP_BAR_OL_OFF = V2(0, 1)
local NAME_OFF      = V2(0, 2)
local DIST_OFF      = V2(0, 2)

local VERTICES = {
    V3(-1,-1,-1), V3(-1,1,-1),
    V3(-1,1,1),   V3(-1,-1,1),
    V3(1,-1,-1),  V3(1,1,-1),
    V3(1,1,1),    V3(1,-1,1)
}

-- 
--  Utilities
-- 
local function isBodyPart(name)
    return name == "Head"
        or name:find("Torso", 1, true)
        or name:find("Leg",   1, true)
        or name:find("Arm",   1, true)
end

local function getBoundingBox(parts)
    local mn, mx
    for i = 1, #parts do
        local p = parts[i]; local cf, sz = p.CFrame, p.Size
        mn = min3(mn or cf.Position, (cf - sz * 0.5).Position)
        mx = max3(mx or cf.Position, (cf + sz * 0.5).Position)
    end
    local center = (mn + mx) * 0.5
    return CFrame.new(center, V3(center.X, center.Y, mx.Z)), mx - mn
end

local function worldToScreen(world)
    local s, inBounds = wtvp(camera, world)
    return V2(s.X, s.Y), inBounds, s.Z
end

local function calcCorners(cf, sz)
    local vp = camera.ViewportSize
    local corners = tcreate(#VERTICES)
    for i = 1, #VERTICES do corners[i] = worldToScreen((cf + sz*0.5*VERTICES[i]).Position) end
    local mn = min2(vp, unpack(corners))
    local mx = Vector2.zero.Max(Vector2.zero, unpack(corners))
    return {
        corners     = corners,
        topLeft     = V2(floor(mn.X), floor(mn.Y)),
        topRight    = V2(floor(mx.X), floor(mn.Y)),
        bottomLeft  = V2(floor(mn.X), floor(mx.Y)),
        bottomRight = V2(floor(mx.X), floor(mx.Y))
    }
end

local function parseColor(self, color, isOutline)
    if color == "Team Color" or (self.interface.sharedSettings.useTeamColor and not isOutline) then
        return self.interface.getTeamColor(self.player) or C3N(1,1,1)
    end
    return color
end

-- 
--  Single shared loop registry
--  (REPLACES per-object Heartbeat connections entirely)
-- 
local _espList   = {}  -- all active EspObjects
local _chamList  = {}  -- all active ChamObjects
local _frame     = 0
local UPDATE_SKIP  = 4  -- Update() runs every 3rd frame   20 Hz
local CHAMS_SKIP   = 10  -- SyncHighlight() runs every 6th frame  10 Hz

runService.Heartbeat:Connect(function()
    _frame = _frame + 1

    local doUpdate = (_frame % UPDATE_SKIP == 0)
    local doChams  = (_frame % CHAMS_SKIP  == 0)

    --  ESP objects 
    local _espCount = #_espList
    for i = 1, _espCount do
        local obj = _espList[i]
        local prevOnScreen = obj.onScreen  -- capture before possible update

        if doUpdate then obj:Update() end

        if obj.onScreen then
            obj:Render()
        elseif prevOnScreen then
            -- Just went off-screen: hide drawings once, then do nothing
            obj:HideAll()
        end
    end

    --  Chams (10 Hz sync, event-driven for character changes) 
    if doChams then
        local _chamCount = #_chamList
        for i = 1, _chamCount do
            _chamList[i]:SyncHighlight()
        end
    end
end)

-- 
--  EspObject
-- 
local EspObject = {}
EspObject.__index = EspObject

function EspObject.new(player, interface)
    local self = setmetatable({}, EspObject)
    self.player    = assert(player,    "player expected")
    self.interface = assert(interface, "interface expected")
    self:Construct()
    return self
end

function EspObject:_mk(class, props)
    local d = Drawing.new(class)
    for k, v in next, props do pcall(function() d[k]=v end) end
    self.bin[#self.bin+1] = d
    return d
end

function EspObject:Construct()
    self.charCache  = {}
    self.childCount = 0
    self.cachedChar = nil   -- track character to detect respawns
    self.cachedHum  = nil   -- cached Humanoid (avoid FindFirstChildOfClass every frame)
    self.bin        = {}
    self.onScreen   = false
    self.enabled    = false

    local b3 = {}
    for _ = 1, 4 do
        b3[#b3+1] = {
            self:_mk("Line",{Thickness=1,Visible=false}),
            self:_mk("Line",{Thickness=1,Visible=false}),
            self:_mk("Line",{Thickness=1,Visible=false})
        }
    end

    self.drawings = {
        box3d = b3,
        visible = {
            tracerOutline = self:_mk("Line",   {Thickness=3, Visible=false}),
            tracer        = self:_mk("Line",   {Thickness=1, Visible=false}),
            boxFill       = self:_mk("Square", {Filled=true, Visible=false}),
            boxOutline    = self:_mk("Square", {Thickness=3, Visible=false}),
            box           = self:_mk("Square", {Thickness=1, Visible=false}),
            hpBarOutline  = self:_mk("Line",   {Thickness=3, Visible=false}),
            hpBar         = self:_mk("Line",   {Thickness=1, Visible=false}),
            hpText        = self:_mk("Text",   {Center=true, Visible=false}),
            name          = self:_mk("Text",   {Text=(self.player and (self.player.DisplayName or self.player.Name) or "Unknown"), Center=true, Visible=false}),
            distance      = self:_mk("Text",   {Center=true, Visible=false}),
            weapon        = self:_mk("Text",   {Center=true, Visible=false}),
            headDot       = self:_mk("Circle", {Radius=3, Filled=true, Thickness=1, Visible=false}),
        }
    }

    -- Register in the shared loop (no individual Heartbeat connection!)
    _espList[#_espList+1] = self
end

function EspObject:Destruct()
    -- Unregister from shared loop
    for i = #_espList, 1, -1 do
        if _espList[i] == self then table.remove(_espList, i); break end
    end
    self:HideAll()
    for i = 1, #self.bin do self.bin[i]:Remove() end
    clr(self)
end

function EspObject:HideAll()
    for i = 1, #self.bin do self.bin[i].Visible = false end
end

function EspObject:Update()
    local iface = self.interface
    self.options   = iface.teamSettings[iface.isFriendly(self.player) and "friendly" or "enemy"]
    self.character = iface.getCharacter(self.player)

    -- Refresh humanoid cache only when character changes (respawn detection)
    if self.character ~= self.cachedChar then
        self.cachedChar = self.character
        self.cachedHum  = self.character and findFirstChildOfClass(self.character, "Humanoid") or nil
        self.charCache  = {}
        self.childCount = 0
    end

    -- Read health from cached Humanoid - no repeated FindFirstChildOfClass
    if self.cachedHum then
        self.health    = self.cachedHum.Health
        self.maxHealth = self.cachedHum.MaxHealth
    else
        self.health, self.maxHealth = 100, 100
    end

    self.weapon  = iface.getWeapon(self.player)
    self.enabled = self.options.enabled
        and self.character
        and not (#iface.whitelist > 0 and not find(iface.whitelist, self.player.UserId))

    local head = self.enabled and findFirstChild(self.character, "Head")
    if not head then self.onScreen = false; return end

    local headScreen, onSc, depth = worldToScreen(head.Position)
    self.headPos  = headScreen
    self.onScreen = onSc
    self.distance = depth

    if iface.sharedSettings.limitDistance and depth > iface.sharedSettings.maxDistance then
        self.onScreen = false
    end

    -- Build bounding box only for on-screen players
    if self.onScreen then
        local cache    = self.charCache
        local children = getChildren(self.character)
        if not cache[1] or self.childCount ~= #children then
            clr(cache)
            for i = 1, #children do
                local p = children[i]
                if isA(p, "BasePart") and isBodyPart(p.Name) then cache[#cache+1]=p end
            end
            self.childCount = #children
        end
        self.corners = calcCorners(getBoundingBox(cache))
    end
end

function EspObject:Render()
    -- Only called when onScreen is true; corners is always valid here
    local en      = self.enabled or false
    local vis     = self.drawings.visible
    local b3      = self.drawings.box3d
    local iface   = self.interface
    local opts    = self.options
    local corners = self.corners
    if not corners then return end

    -- 2D Box
    vis.box.Visible        = en and opts.box
    vis.boxOutline.Visible = vis.box.Visible and opts.boxOutline
    if vis.box.Visible then
        vis.box.Position        = corners.topLeft
        vis.box.Size            = corners.bottomRight - corners.topLeft
        vis.box.Color           = parseColor(self, opts.boxColor[1])
        vis.box.Transparency    = opts.boxColor[2]
        vis.boxOutline.Position = vis.box.Position
        vis.boxOutline.Size     = vis.box.Size
        vis.boxOutline.Color    = parseColor(self, opts.boxOutlineColor[1], true)
        vis.boxOutline.Transparency = opts.boxOutlineColor[2]
    end

    -- Box Fill
    vis.boxFill.Visible = en and opts.boxFill
    if vis.boxFill.Visible then
        vis.boxFill.Position     = corners.topLeft
        vis.boxFill.Size         = corners.bottomRight - corners.topLeft
        vis.boxFill.Color        = parseColor(self, opts.boxFillColor[1])
        vis.boxFill.Transparency = opts.boxFillColor[2]
    end

    -- Health Bar
    vis.hpBar.Visible        = en and opts.healthBar
    vis.hpBarOutline.Visible = vis.hpBar.Visible and opts.healthBarOutline
    if vis.hpBar.Visible then
        local bFrom = corners.topLeft    - HP_BAR_OFF
        local bTo   = corners.bottomLeft - HP_BAR_OFF
        local pct   = mMax(0, mMin(1, self.health / self.maxHealth))
        vis.hpBar.To    = bTo
        vis.hpBar.From  = lerp2(bTo, bFrom, pct)
        vis.hpBar.Color = lerpColor(opts.dyingColor, opts.healthyColor, pct)
        vis.hpBarOutline.To    = bTo   + HP_BAR_OL_OFF
        vis.hpBarOutline.From  = bFrom - HP_BAR_OL_OFF
        vis.hpBarOutline.Color = parseColor(self, opts.healthBarOutlineColor[1], true)
        vis.hpBarOutline.Transparency = opts.healthBarOutlineColor[2]
    end

    -- Health Text
    vis.hpText.Visible = en and opts.healthText
    if vis.hpText.Visible then
        local bFrom = corners.topLeft    - HP_BAR_OFF
        local bTo   = corners.bottomLeft - HP_BAR_OFF
        local pct   = mMax(0, mMin(1, self.health / self.maxHealth))
        local ht    = vis.hpText
        ht.Text         = round(self.health).."hp"
        ht.Size         = iface.sharedSettings.textSize
        ht.Font         = iface.sharedSettings.textFont
        ht.Color        = parseColor(self, opts.healthTextColor[1])
        ht.Transparency = opts.healthTextColor[2]
        ht.Outline      = opts.healthTextOutline
        ht.OutlineColor = parseColor(self, opts.healthTextOutlineColor, true)
        ht.Position     = lerp2(bTo, bFrom, pct) - ht.TextBounds*0.5 - HP_TXT_OFF
    end

    -- Name
    vis.name.Visible = en and opts.name
    if vis.name.Visible then
        local n = vis.name
        n.Size         = iface.sharedSettings.textSize
        n.Font         = iface.sharedSettings.textFont
        n.Color        = parseColor(self, opts.nameColor[1])
        n.Transparency = opts.nameColor[2]
        n.Outline      = opts.nameOutline
        n.OutlineColor = parseColor(self, opts.nameOutlineColor, true)
        n.Position     = (corners.topLeft+corners.topRight)*0.5 - Vector2.yAxis*n.TextBounds.Y - NAME_OFF
    end

    -- Distance
    vis.distance.Visible = en and self.distance and opts.distance
    if vis.distance.Visible then
        local d = vis.distance
        d.Text         = round(self.distance).." studs"
        d.Size         = iface.sharedSettings.textSize
        d.Font         = iface.sharedSettings.textFont
        d.Color        = parseColor(self, opts.distanceColor[1])
        d.Transparency = opts.distanceColor[2]
        d.Outline      = opts.distanceOutline
        d.OutlineColor = parseColor(self, opts.distanceOutlineColor, true)
        d.Position     = (corners.bottomLeft+corners.bottomRight)*0.5 + DIST_OFF
    end

    -- Weapon
    vis.weapon.Visible = en and opts.weapon
    if vis.weapon.Visible then
        local w = vis.weapon
        w.Text         = self.weapon
        w.Size         = iface.sharedSettings.textSize
        w.Font         = iface.sharedSettings.textFont
        w.Color        = parseColor(self, opts.weaponColor[1])
        w.Transparency = opts.weaponColor[2]
        w.Outline      = opts.weaponOutline
        w.OutlineColor = parseColor(self, opts.weaponOutlineColor, true)
        w.Position     = (corners.bottomLeft+corners.bottomRight)*0.5
            + (vis.distance.Visible and DIST_OFF+Vector2.yAxis*vis.distance.TextBounds.Y or Vector2.zero)
    end

    -- Tracer
    vis.tracer.Visible        = en and opts.tracer
    vis.tracerOutline.Visible = vis.tracer.Visible and opts.tracerOutline
    if vis.tracer.Visible then
        local vp = camera.ViewportSize
        local tr = vis.tracer
        tr.Color        = parseColor(self, opts.tracerColor[1])
        tr.Transparency = opts.tracerColor[2]
        tr.To           = (corners.bottomLeft+corners.bottomRight)*0.5
        tr.From = opts.tracerOrigin=="Top"    and vp*V2(0.5,0)
               or opts.tracerOrigin=="Middle" and vp*0.5
               or vp*V2(0.5,1)
        local to = vis.tracerOutline
        to.Color=parseColor(self,opts.tracerOutlineColor[1],true)
        to.Transparency=opts.tracerOutlineColor[2]
        to.To=tr.To; to.From=tr.From
    end

    -- Head Dot (lightweight: position already computed in Update, no extra WtVP call)
    vis.headDot.Visible = en and opts.headDot
    if vis.headDot.Visible and self.headPos then
        local hd = vis.headDot
        hd.Position    = self.headPos
        hd.Color       = parseColor(self, opts.headDotColor[1])
        hd.Transparency= opts.headDotColor[2]
    end

    -- 3D Box
    local b3En = en and opts.box3d
    for i = 1, #b3 do
        local face = b3[i]
        for j = 1, 3 do
            local l = face[j]
            l.Visible      = b3En
            l.Color        = parseColor(self, opts.box3dColor[1])
            l.Transparency = opts.box3dColor[2]
        end
        if b3En then
            face[1].From = corners.corners[i]
            face[1].To   = corners.corners[i==4 and 1 or i+1]
            face[2].From = corners.corners[i==4 and 1 or i+1]
            face[2].To   = corners.corners[i==4 and 5 or i+5]
            face[3].From = corners.corners[i==4 and 5 or i+5]
            face[3].To   = corners.corners[i==4 and 8 or i+4]
        end
    end
end

-- 
--  ChamObject  (event-driven - NOT polling)
--  CharacterAdded fires SyncHighlight immediately.
--  The shared loop only syncs at 10 Hz for settings changes.
--  DepthMode="Occluded" = visible-only is handled by Roblox GPU for free.
-- 
local ChamObject = {}
ChamObject.__index = ChamObject

function ChamObject.new(player, interface)
    local self = setmetatable({}, ChamObject)
    self.player    = assert(player,    "player expected")
    self.interface = assert(interface, "interface expected")
    self:Construct()
    return self
end

function ChamObject:Construct()
    self.highlight = Instance.new("Highlight", container)
    self.highlight.Enabled = false

    -- React to respawns immediately (free, event-driven)
    self._charAddedConn = self.player.CharacterAdded:Connect(function()
        task.defer(function() self:SyncHighlight() end)
    end)

    -- Register for periodic settings sync
    _chamList[#_chamList+1] = self
    self:SyncHighlight()
end

function ChamObject:Destruct()
    for i = #_chamList, 1, -1 do
        if _chamList[i] == self then table.remove(_chamList, i); break end
    end
    if self._charAddedConn then self._charAddedConn:Disconnect() end
    self.highlight:Destroy()
    clr(self)
end

function ChamObject:SyncHighlight()
    local iface = self.interface
    local char  = iface.getCharacter(self.player)
    local opts  = iface.teamSettings[iface.isFriendly(self.player) and "friendly" or "enemy"]
    local en    = opts.enabled and char and opts.chams
        and not (#iface.whitelist > 0 and not find(iface.whitelist, self.player.UserId))
    local hl = self.highlight
    hl.Enabled = en and true or false
    if hl.Enabled then
        hl.Adornee             = char
        hl.FillColor           = parseColor(self, opts.chamsFillColor[1])
        hl.FillTransparency    = opts.chamsFillColor[2]
        hl.OutlineColor        = parseColor(self, opts.chamsOutlineColor[1], true)
        hl.OutlineTransparency = opts.chamsOutlineColor[2]
        hl.DepthMode           = opts.chamsVisibleOnly and "Occluded" or "AlwaysOnTop"
    end
end

-- 
--  EspInterface
-- 
local EspInterface = {
    _hasLoaded   = false,
    _objectCache = {},
    whitelist    = {},
    sharedSettings = {
        textSize      = 13,
        textFont      = 2,
        limitDistance = false,
        maxDistance   = 1000,
        useTeamColor  = false
    },
    teamSettings = {
        enemy = {
            enabled              = false,
            box                  = false,
            boxColor             = {C3N(1,0,0), 1},
            boxOutline           = true,
            boxOutlineColor      = {C3N(), 1},
            boxFill              = false,
            boxFillColor         = {C3N(1,0,0), 0.5},
            healthBar            = false,
            healthyColor         = C3N(0,1,0),
            dyingColor           = C3N(1,0,0),
            healthBarOutline     = true,
            healthBarOutlineColor = {C3N(), 0.5},
            healthText           = false,
            healthTextColor      = {C3N(1,1,1), 1},
            healthTextOutline    = true,
            healthTextOutlineColor = C3N(),
            box3d                = false,
            box3dColor           = {C3N(1,0,0), 1},
            name                 = false,
            nameColor            = {C3N(1,1,1), 1},
            nameOutline          = true,
            nameOutlineColor     = C3N(),
            weapon               = false,
            weaponColor          = {C3N(1,1,1), 1},
            weaponOutline        = true,
            weaponOutlineColor   = C3N(),
            distance             = false,
            distanceColor        = {C3N(1,1,1), 1},
            distanceOutline      = true,
            distanceOutlineColor = C3N(),
            tracer               = false,
            tracerOrigin         = "Bottom",
            tracerColor          = {C3N(1,0,0), 1},
            tracerOutline        = true,
            tracerOutlineColor   = {C3N(), 1},
            chams                = false,
            chamsVisibleOnly     = true,
            chamsFillColor       = {C3N(0.2,0.2,0.2), 0.5},
            chamsOutlineColor    = {C3N(1,0,0), 0},
            headDot              = false,
            headDotColor         = {C3N(1,1,1), 0},
        },
        friendly = {
            enabled              = false,
            box                  = false,
            boxColor             = {C3N(0,1,0), 1},
            boxOutline           = true,
            boxOutlineColor      = {C3N(), 1},
            boxFill              = false,
            boxFillColor         = {C3N(0,1,0), 0.5},
            healthBar            = false,
            healthyColor         = C3N(0,1,0),
            dyingColor           = C3N(1,0,0),
            healthBarOutline     = true,
            healthBarOutlineColor = {C3N(), 0.5},
            healthText           = false,
            healthTextColor      = {C3N(1,1,1), 1},
            healthTextOutline    = true,
            healthTextOutlineColor = C3N(),
            box3d                = false,
            box3dColor           = {C3N(0,1,0), 1},
            name                 = false,
            nameColor            = {C3N(1,1,1), 1},
            nameOutline          = true,
            nameOutlineColor     = C3N(),
            weapon               = false,
            weaponColor          = {C3N(1,1,1), 1},
            weaponOutline        = true,
            weaponOutlineColor   = C3N(),
            distance             = false,
            distanceColor        = {C3N(1,1,1), 1},
            distanceOutline      = true,
            distanceOutlineColor = C3N(),
            tracer               = false,
            tracerOrigin         = "Bottom",
            tracerColor          = {C3N(0,1,0), 1},
            tracerOutline        = true,
            tracerOutlineColor   = {C3N(), 1},
            chams                = false,
            chamsVisibleOnly     = true,
            chamsFillColor       = {C3N(0.2,0.2,0.2), 0.5},
            chamsOutlineColor    = {C3N(0,1,0), 0},
            headDot              = false,
            headDotColor         = {C3N(1,1,1), 0},
        }
    }
}

function EspInterface.Load()
    if EspInterface._hasLoaded then warn("[KAIM Sense] Already loaded."); return end
    local function create(player)
        EspInterface._objectCache[player] = {
            EspObject.new(player, EspInterface),
            ChamObject.new(player, EspInterface)
        }
    end
    local function remove(player)
        local objs = EspInterface._objectCache[player]
        if objs then for i=1,#objs do objs[i]:Destruct() end; EspInterface._objectCache[player]=nil end
    end
    local plrs = players:GetPlayers()
    for i=1,#plrs do if plrs[i]~=localPlayer then create(plrs[i]) end end
    EspInterface._playerAdded    = players.PlayerAdded:Connect(create)
    EspInterface._playerRemoving = players.PlayerRemoving:Connect(remove)
    EspInterface._hasLoaded = true
end

function EspInterface.Unload()
    if not EspInterface._hasLoaded then warn("[KAIM Sense] Not loaded."); return end
    for idx, objs in next, EspInterface._objectCache do
        for i=1,#objs do objs[i]:Destruct() end; EspInterface._objectCache[idx]=nil
    end
    EspInterface._playerAdded:Disconnect()
    EspInterface._playerRemoving:Disconnect()
    EspInterface._hasLoaded = false
end

function EspInterface.getWeapon(player)
    local char = player.Character
    if char then local t=char:FindFirstChildOfClass("Tool"); if t then return t.Name end end
    return ""
end

function EspInterface.isFriendly(player)
    return player.Team ~= nil and player.Team == localPlayer.Team
end

function EspInterface.getTeamColor(player)
    return player.Team and player.Team.TeamColor and player.Team.TeamColor.Color
end

function EspInterface.getCharacter(player) return player.Character end

function EspInterface.getHealth(player)
    local char = player and EspInterface.getCharacter(player)
    local hum  = char and findFirstChildOfClass(char, "Humanoid")
    if hum then return hum.Health, hum.MaxHealth end
    return 100, 100
end

return EspInterface

end)()
getgenv().SenseESP = SenseESP
getgenv().SenseESP.sharedSettings.useTeamColor  = false
getgenv().SenseESP.teamSettings.enemy.enabled   = false
getgenv().SenseESP.teamSettings.friendly.enabled = false
getgenv().SenseESP.Load()

-- ==============================================================================
--  3. MATH & FAST LOCALS
-- ==============================================================================
local mFloor, mClamp, mMax, mMin, mSqrt, mRad, mAbs = mFloor, mClamp, mMax, mMin, math.sqrt, mRad, mAbs
local mRand = math.random
local mSin, mCos = math.sin, math.cos
local iNew = Instance.new
local tClear = table.clear
local V2, V3, C3, CF = V2, V3, C3, CF
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
        Visible=false, ZIndex=1, Transparency=1, Color=C3N(),
        Thickness=1, Filled=false, Position=V2(),
        Size=(t=="Text" and 12 or (t=="Square" and V2() or 0)),
        Text="", Center=false, Outline=false, OutlineColor=C3N(),
        Font=1, From=V2(), To=V2(), Radius=0
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
    Silent = { On=false, Method='Raycast', HitChance=100, HeadshotChance=100, WallCheck=true, Target=nil, FieldOfView=150, ShowFOV=true },
    Aim = {
        On=false, Mode="Smart", Priority="Crosshair", WallCheck=true, WallCheckDelay=0.5, TeamCheck=true,
        ESPTargetsOnly=false, Pred=true, PredStr=0.135, Smooth=false, SmoothSpd=0.3, HitChance=100,
        LockTracer=true, SoundCue=true, NotifyLock=false,
        OffX=0, OffY=0, OffZ=0,
        Target=nil, IsAiming=false
    },
    THUD = { On=true, Scale=1, OffX=80, OffY=-24, BgTrans=0.2 },
    HB  = {On=false, Part="Head", Size=5, Trans=0.5},
    FOV = {Show=true, Follow=true, Radius=150, ZoomScale=true, Thick=1.5,
           Color=WHITE, ColorLerp=true, LockCol=ORANGE, Trans=0.8, Filled=false, FC=WHITE, FT=0.92},
    World = {On=false, Time=14, Bright=2, Shadows=false, Ambient=WHITE, NoFog=false, FullB=false},
    Mov   = {SpeedOn=false, Speed=16, JumpOn=false, Jump=50, InfJump=false, BHop=false,
             FOVOn=false, CamFOV=70, Noclip=false, NoclipKey="N",
             GravOn=false, Gravity=196.2, BlinkOn=false,
             FlyOn=false, FlySpeed=50, SpinOn=false, SpinSpeed=20},
    Perf  = {LOD=500, Watermark=true, ShowFPS=true, ShowPing=true, ShowTime=false},
    Cross = {On=false, Color=WHITE, Size=8, Gap=4, Dot=false},
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
-- (Sounds removed per user request)

local oldNotify = Library.Notify
Library.Notify = function(self, ...)
    return oldNotify(self, ...)
end

local FOVR   = ND("Circle"); FOVR.Thickness=1.5; FOVR.Filled=false
local FOVF   = ND("Circle"); FOVF.Thickness=1;   FOVF.Filled=true
local LTracer = ND("Line");   LTracer.Thickness=1.5

-- Target HUD ScreenGui Setup (v13 Enhanced)
local THUD = {}
local _guiContainer = nil
pcall(function() _guiContainer = gethui() end)
if not _guiContainer then _guiContainer = game:GetService("CoreGui") end

THUD.Screen = Instance.new("ScreenGui")
THUD.Screen.Name = "KaimTargetHUD"
THUD.Screen.IgnoreGuiInset = true
THUD.Screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
THUD.Screen.ResetOnSpawn = false
pcall(function() THUD.Screen.Parent = _guiContainer end)

THUD.Container = Instance.new("Frame")
THUD.Container.Name = "Container"
THUD.Container.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
THUD.Container.BackgroundTransparency = 0.15
THUD.Container.Size = UDim2.new(0, 220, 0, 72)
THUD.Container.Position = UDim2.new(0, -9999, 0, -9999)
THUD.Container.Visible = false
THUD.Container.Parent = THUD.Screen

local bgCorner = Instance.new("UICorner")
bgCorner.CornerRadius = UDim.new(0, 4)
bgCorner.Parent = THUD.Container

local bgStroke = Instance.new("UIStroke")
bgStroke.Color = Color3.fromRGB(50, 50, 50)
bgStroke.Transparency = 0.1
bgStroke.Thickness = 1
bgStroke.Parent = THUD.Container

-- Team-colored accent stripe on left edge
THUD.Accent = Instance.new("Frame")
THUD.Accent.Name = "Accent"
THUD.Accent.BackgroundColor3 = Color3.fromRGB(130, 110, 255)
THUD.Accent.Size = UDim2.new(0, 3, 1, -4)
THUD.Accent.Position = UDim2.new(0, 2, 0, 2)
THUD.Accent.BorderSizePixel = 0
THUD.Accent.Parent = THUD.Container
local acCorner = Instance.new("UICorner"); acCorner.CornerRadius = UDim.new(0, 2); acCorner.Parent = THUD.Accent

-- Avatar (larger, rounded square)
THUD.Avatar = Instance.new("ImageLabel")
THUD.Avatar.Name = "Avatar"
THUD.Avatar.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
THUD.Avatar.Size = UDim2.new(0, 42, 0, 42)
THUD.Avatar.Position = UDim2.new(0, 10, 0, 8)
THUD.Avatar.Parent = THUD.Container
local avCorner = Instance.new("UICorner"); avCorner.CornerRadius = UDim.new(0, 4); avCorner.Parent = THUD.Avatar
local avStroke = Instance.new("UIStroke"); avStroke.Color = Color3.fromRGB(55, 55, 55); avStroke.Transparency = 0.2; avStroke.Thickness = 1; avStroke.Parent = THUD.Avatar

THUD.Scale = Instance.new("UIScale")
THUD.Scale.Scale = 1
THUD.Scale.Parent = THUD.Container

-- Row 1: Name (bold, uppercase)
THUD.NameLbl = Instance.new("TextLabel")
THUD.NameLbl.Name = "Name"
THUD.NameLbl.BackgroundTransparency = 1
THUD.NameLbl.Position = UDim2.new(0, 60, 0, 5)
THUD.NameLbl.Size = UDim2.new(1, -68, 0, 14)
THUD.NameLbl.Font = Enum.Font.GothamBold
THUD.NameLbl.Text = "TARGET"
THUD.NameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
THUD.NameLbl.TextSize = 13
THUD.NameLbl.TextXAlignment = Enum.TextXAlignment.Left
THUD.NameLbl.Parent = THUD.Container

-- Row 2: Weapon + Distance
THUD.DistLbl = Instance.new("TextLabel")
THUD.DistLbl.Name = "Dist"
THUD.DistLbl.BackgroundTransparency = 1
THUD.DistLbl.Position = UDim2.new(0, 60, 0, 20)
THUD.DistLbl.Size = UDim2.new(1, -68, 0, 12)
THUD.DistLbl.Font = Enum.Font.RobotoMono
THUD.DistLbl.Text = "WPN: NONE [0M]"
THUD.DistLbl.TextColor3 = Color3.fromRGB(170, 170, 170)
THUD.DistLbl.TextSize = 10
THUD.DistLbl.TextXAlignment = Enum.TextXAlignment.Left
THUD.DistLbl.Parent = THUD.Container

-- Row 3: Velocity + Visibility status
THUD.InfoLbl = Instance.new("TextLabel")
THUD.InfoLbl.Name = "Info"
THUD.InfoLbl.BackgroundTransparency = 1
THUD.InfoLbl.Position = UDim2.new(0, 60, 0, 33)
THUD.InfoLbl.Size = UDim2.new(1, -68, 0, 12)
THUD.InfoLbl.Font = Enum.Font.RobotoMono
THUD.InfoLbl.Text = "0 ST/S | VISIBLE"
THUD.InfoLbl.TextColor3 = Color3.fromRGB(140, 140, 140)
THUD.InfoLbl.TextSize = 9
THUD.InfoLbl.TextXAlignment = Enum.TextXAlignment.Left
THUD.InfoLbl.Parent = THUD.Container

-- HP bar (thicker, 4px)
THUD.BarBG = Instance.new("Frame")
THUD.BarBG.Name = "BarBG"
THUD.BarBG.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
THUD.BarBG.Position = UDim2.new(0, 60, 0, 53)
THUD.BarBG.Size = UDim2.new(1, -68, 0, 4)
THUD.BarBG.BorderSizePixel = 0
THUD.BarBG.Parent = THUD.Container
local barBGCorner = Instance.new("UICorner"); barBGCorner.CornerRadius = UDim.new(0, 2); barBGCorner.Parent = THUD.BarBG

THUD.BarFill = Instance.new("Frame")
THUD.BarFill.Name = "BarFill"
THUD.BarFill.BackgroundColor3 = Color3.fromRGB(220, 220, 220)
THUD.BarFill.Size = UDim2.new(1, 0, 1, 0)
THUD.BarFill.BorderSizePixel = 0
THUD.BarFill.Parent = THUD.BarBG
local barFillCorner = Instance.new("UICorner"); barFillCorner.CornerRadius = UDim.new(0, 2); barFillCorner.Parent = THUD.BarFill

-- HP text (shows current / max)
THUD.HPText = Instance.new("TextLabel")
THUD.HPText.Name = "HPText"
THUD.HPText.BackgroundTransparency = 1
THUD.HPText.Position = UDim2.new(0, 60, 0, 58)
THUD.HPText.Size = UDim2.new(1, -68, 0, 11)
THUD.HPText.Font = Enum.Font.RobotoMono
THUD.HPText.Text = "100 / 100"
THUD.HPText.TextColor3 = Color3.fromRGB(190, 190, 190)
THUD.HPText.TextSize = 9
THUD.HPText.TextXAlignment = Enum.TextXAlignment.Left
THUD.HPText.Parent = THUD.Container

local function _destroyTHUD()
    if THUD.Screen then
        pcall(function() THUD.Screen:Destroy() end)
        THUD.Screen = nil
    end
end

-- Smooth HP bar interpolation state
local _thudBarPct = 1  -- current displayed HP pct (lerped)

-- Crosshair Drawing objects
local CH_L = ND("Line"); CH_L.Thickness = 1
local CH_R = ND("Line"); CH_R.Thickness = 1
local CH_T = ND("Line"); CH_T.Thickness = 1
local CH_B = ND("Line"); CH_B.Thickness = 1
local CH_D = ND("Circle"); CH_D.Thickness = 1; CH_D.Filled = false

local function CacheL() OrigLit={T=Lit.ClockTime, B=Lit.Brightness, S=Lit.GlobalShadows, A=Lit.Ambient, FEnd=Lit.FogEnd, FStart=Lit.FogStart, OA=Lit.OutdoorAmbient, CSB=Lit.ColorShift_Bottom, CST=Lit.ColorShift_Top} end
CacheL()

-- ==============================================================================
--  7. RAY CACHING
-- ==============================================================================
local visRayFilter, tbRayFilter, _lastVisChar = {}, {}, nil

local function UpdateTBRayFilter()
    tClear(tbRayFilter)
    local cam = workspace.CurrentCamera
    if cam then tbRayFilter[#tbRayFilter+1] = cam end
    if LP.Character then tbRayFilter[#tbRayFilter+1] = LP.Character end
    TRP.FilterDescendantsInstances = tbRayFilter
end

local function SetVisFilter(targetChar)
    if _lastVisChar == targetChar then return end
    _lastVisChar = targetChar
    tClear(visRayFilter)
    
    local cam = workspace.CurrentCamera
    if cam then visRayFilter[#visRayFilter+1] = cam end
    if LP.Character then visRayFilter[#visRayFilter+1] = LP.Character end
    if targetChar then visRayFilter[#visRayFilter+1] = targetChar end
    
    RP.FilterDescendantsInstances = visRayFilter
end

Conns[#Conns+1] = LP.CharacterAdded:Connect(function() task.delay(0.5, UpdateTBRayFilter); _lastVisChar=nil end)

-- ==============================================================================
--  8. CORE UTILS
-- ==============================================================================
local function IsTeam(p) if TC[p]==nil then TC[p]=(p.Team~=nil and p.Team==LP.Team) end; return TC[p] end
Conns[#Conns+1] = LP:GetPropertyChangedSignal("Team"):Connect(function() tClear(TC) end)

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
                local p = char:FindFirstChild(n); if p and p:IsA("BasePart") then c._chaosParts[#c._chaosParts+1] = p end
            end
            c._lastPos = hrp.Position
            c._sp = V3(); c._onSc=false; c._depth=0; c._distSq=0; c._wsValid=false
            CC[pl] = c
            UpdateTBRayFilter()
        end
    end)
end

local function IsVis(part, camP, targetChar)
    -- OPTIMIZED: reuses the global cached RP + SetVisFilter instead of
    -- allocating a new RaycastParams + table on every single call.
    if not part then return false end
    SetVisFilter(targetChar)  -- no-op if targetChar hasn't changed
    local rayDir = part.Position - camP
    local dist   = rayDir.Magnitude
    -- Offset slightly so we don't clip the back of the target's own hitbox
    local result = workspace:Raycast(camP, rayDir.Unit * (dist - 0.1), RP)
    return result == nil
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
        local bestP, bestD = cd.HRP, 9e9
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
            local p=ch:FindFirstChild(n); if p then _limbPool[#_limbPool+1] = p end
        end
        part = #_limbPool>0 and _limbPool[math.random(1,mMax(1,#_limbPool))] or cd.HRP
    elseif mode=="HRP" then part=cd.HRP end
    return part, IsVis(part, camP, ch)
end

local function PickChaos(cd)
    if cd and cd._chaosParts and #cd._chaosParts>0 then
        chaosName = cd._chaosParts[math.random(1,#cd._chaosParts)].Name
    end
end

local function GetTarget(camP, fovP, cam)
    local bestTarget, bestVal = nil, 9e9
    local fov = cam.FieldOfView; if fov <= 0 then fov = 70 end
    local scale = S.FOV.ZoomScale and (70/fov) or 1
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
    PList[#PList+1] = pl
    Conns[#Conns+1] = pl:GetPropertyChangedSignal("Team"):Connect(function() TC[pl]=nil end)
    Conns[#Conns+1] = pl.CharacterAdded:Connect(function(c) BuildCC(pl,c) end)
    Conns[#Conns+1] = pl.CharacterRemoving:Connect(function()
        if CC[pl] and CC[pl]._hpConn then pcall(function() CC[pl]._hpConn:Disconnect() end) end
        CC[pl]=nil; HBOrig[pl]=nil; UpdateTBRayFilter()
    end)
    if pl.Character then BuildCC(pl, pl.Character) end
end

task.spawn(function() for _,p in ipairs(Plr:GetPlayers()) do if p~=LP then RegPl(p); task.wait() end end end)
Conns[#Conns+1] = Plr.PlayerAdded:Connect(RegPl)
Conns[#Conns+1] = Plr.PlayerRemoving:Connect(function(pl)
    local _plCount = #PList
    for i=1,_plCount do if PList[i]==pl then tRem(PList,i); break end end
    CC[pl]=nil; HBOrig[pl]=nil; UpdateTBRayFilter()
end)
Conns[#Conns+1] = LP.CharacterAdded:Connect(function(c)
    BuildCC(LP,c); UpdateTBRayFilter()
    if S.Mov.Noclip then task.defer(function() if _G._KaimNC then _G._KaimNC(c) end end) end
end)
if LP.Character then BuildCC(LP, LP.Character) end
UpdateTBRayFilter()

-- ==============================================================================
--  11. NOCLIP
-- ==============================================================================
local _ncConn, _ncParts = nil, {}
local function BuildNoclipCache(char)
    tClear(_ncParts)
    if not char then return end
    for _,p in ipairs(char:GetDescendants()) do if p:IsA("BasePart") then _ncParts[#_ncParts+1] = p end end
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
            Conns[#Conns+1] = _ncConn
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
    local fov = cam.FieldOfView; if fov <= 0 then fov = 70 end
    local scale = S.FOV.ZoomScale and (70/fov) or 1
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
local _thudLastWep  = ""
local _thudAnimPct  = -1
local _thudAvatarId = 0


local function ClearTarget()
    S.Aim.Target = nil
    _thudLastHP = -1; _thudLastDist = -1; _thudLastName = ""; _thudLastWep = ""; _thudAnimPct = -1; _thudAvatarId = 0
    if _lockedDiedConn then pcall(function() _lockedDiedConn:Disconnect() end); _lockedDiedConn=nil end
end

local function TickAim(camP, sw, sh, dt, fovP, cam)
    if S.Silent.On then
        S.Silent.Target = GetTarget(camP, fovP, cam)
    else
        S.Silent.Target = nil
    end

    if S.Aim.Mode=="Chaos" and S.Aim.IsAiming then
        chaosT=chaosT-dt; if chaosT<=0 then chaosT=CHAOS_INT; local tc=S.Aim.Target and CC[S.Aim.Target]; if tc then PickChaos(tc) end end
    end

    if S.Aim.On and S.Aim.IsAiming then
        if not S.Aim.Target then
            local newT = GetTarget(camP, fovP, cam)
            if newT then
                S.Aim.Target = newT; _graceTimer=0
                if S.Aim.NotifyLock then Library:Notify({Title="Lock", Description="Locked: "..newT.DisplayName, Time=2}) end
                local cd = CC[newT]
                if cd and cd.Hum then _lockedDiedConn = cd.Hum.Died:Connect(ClearTarget) end
            end
        end

        local tar = S.Aim.Target; local cd = tar and CC[tar]
        if cd then
            if cd.Hum.Health<=0 or not tar.Parent or not cd.Char or not cd.Char.Parent or not cd._wsValid then ClearTarget()
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
                            vel = V3(vel.X*invM, vel.Y*invM, vel.Z*invM)
                        end
                        ap = ap + vel * S.Aim.PredStr
                    end
                    if S.Aim.OffX~=0 or S.Aim.OffY~=0 or S.Aim.OffZ~=0 then ap=ap+_aimOff end
                    local tCF = CFrame.new(camP, ap)

                    local apSc, on2 = cam:WorldToViewportPoint(ap)
                    local snap = false
                    if on2 then
                        local cx, cy = sw*0.5, sh*0.5
                        if S.FOV.Follow then local ms=UIS:GetMouseLocation(); cx=ms.X; cy=ms.Y end
                        local dx = apSc.X-cx; local dy = apSc.Y-cy
                        if dx*dx + dy*dy < 64 then snap=true end  -- 8^2=64, no sqrt needed
                    end

                    if S.Aim.HitChance >= 100 or math.random(1,100)<=S.Aim.HitChance then
                        if S.Aim.On and S.Aim.IsAiming then
                            if S.Aim.Smooth and not snap then
                                local sf = mClamp((S.Aim.SmoothSpd^1.5)*(dt*60), 0.01, 1)
                                cam.CFrame = cam.CFrame:Lerp(tCF, sf)
                            else cam.CFrame = tCF end
                        end
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
                    local wepName = "None"
                    local tarChar = tar.Character
                    if tarChar then
                        local tool = tarChar:FindFirstChildOfClass("Tool")
                        if tool then wepName = tool.Name end
                    end
                    
                    if tar.DisplayName ~= _thudLastName then
                        -- Reset unfolding animation when locking onto a new target
                        _thudAnimPct = 0
                    end
                    
                    if hpFlr ~= _thudLastHP or dstFlr ~= _thudLastDist or tar.DisplayName ~= _thudLastName or wepName ~= _thudLastWep then
                        -- Update dirty-cache values; actual THUD rendering happens below
                        _thudLastHP   = hpFlr
                        _thudLastDist = dstFlr
                        _thudLastName = tar.DisplayName
                        _thudLastWep  = wepName
                    end
                    

                    
                    -- Animation scaling (unfolding effect when locked on)
                    if _thudAnimPct < 0 then _thudAnimPct = 0 end
                    _thudAnimPct = _thudAnimPct + (1 - _thudAnimPct) * mClamp(dt * 12, 0, 1)
                    
                    local tC = getgenv().SenseESP and getgenv().SenseESP.getTeamColor(tar) or C3(130, 110, 255)
                    local hpCol = HPC(pct)
                    
                    -- Project target's RootPart into 3D space
                    local rootPos = (tar.Character and tar.Character:FindFirstChild("HumanoidRootPart")) and tar.Character.HumanoidRootPart.Position or (part and part.Position)
                    local screenPos, onScreen = workspace.CurrentCamera:WorldToViewportPoint(rootPos)
                    
                    if not onScreen then
                        if THUD.Container and THUD.Container.Visible then THUD.Container.Visible = false end
                    else
                        if not THUD.Container.Visible then THUD.Container.Visible = true end
                        
                        -- Fetch Avatar Thumbnail dynamically if supported
                        if tar.UserId ~= _thudAvatarId then
                            _thudAvatarId = tar.UserId
                            task.spawn(function()
                                local ok, res = pcall(function()
                                    return game:GetService("Players"):GetUserThumbnailAsync(tar.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
                                end)
                                if ok and res then
                                    pcall(function() THUD.Avatar.Image = res end)
                                end
                            end)
                        end

                        if not S.THUD.On then
                            if THUD.Container.Visible then THUD.Container.Visible = false end
                        else
                            if not THUD.Container.Visible then THUD.Container.Visible = true end
                            
                            -- Apply customization settings
                            THUD.Scale.Scale = S.THUD.Scale
                            THUD.Container.BackgroundTransparency = S.THUD.BgTrans
                            
                            -- Animate sliding in when locked on
                            local animOffsetX = 50 * (1 - _thudAnimPct)
                            local cx = screenPos.X + S.THUD.OffX + animOffsetX
                            local cy = screenPos.Y + S.THUD.OffY
                            
                            THUD.Container.Position = UDim2.new(0, cx, 0, cy)
                            
                            THUD.NameLbl.Text = string.upper(tar.DisplayName)
                            
                            -- Dynamic width based on name length
                            local nBounds = THUD.NameLbl.TextBounds.X
                            local w = mMax(200, nBounds + 90)
                            THUD.Container.Size = UDim2.new(0, w, 0, 72)
                            
                            THUD.DistLbl.Text = "WPN: " .. string.upper(wepName) .. " [" .. tostring(dstFlr) .. "M]"
                            
                            -- Velocity + visibility info row
                            local velMag = 0
                            if cd.HRP then
                                local vel = cd.HRP.AssemblyLinearVelocity
                                velMag = mFloor((vel.X*vel.X + vel.Y*vel.Y + vel.Z*vel.Z)^0.5)
                            end
                            local visStr = lockVis and "VISIBLE" or "BEHIND WALL"
                            THUD.InfoLbl.Text = tostring(velMag) .. " ST/S | " .. visStr
                            THUD.InfoLbl.TextColor3 = lockVis and Color3.fromRGB(100, 200, 100) or Color3.fromRGB(200, 80, 80)
                            
                            -- HP text: current / max
                            THUD.HPText.Text = tostring(hpFlr) .. " / " .. tostring(mFloor(maxHP))
                            
                            -- Team-colored accent stripe
                            THUD.Accent.BackgroundColor3 = tC
                        end  -- closes: if not S.THUD.On then ... else
                        
                        -- Smooth bar fill with interpolation
                        local hpPct = mClamp(hpFlr / mMax(1, maxHP), 0, 1)
                        _thudBarPct = _thudBarPct + (hpPct - _thudBarPct) * mClamp(dt * 8, 0, 1)
                        THUD.BarFill.Size = UDim2.new(_thudBarPct * _thudAnimPct, 0, 1, 0)
                        
                        -- Gradient HP colors: green > yellow > red
                        local barCol = HPC(hpPct)
                        THUD.BarFill.BackgroundColor3 = barCol
                        if hpPct <= 0.3 then
                            THUD.HPText.TextColor3 = Color3.fromRGB(200, 50, 50)
                        elseif hpPct <= 0.6 then
                            THUD.HPText.TextColor3 = Color3.fromRGB(220, 200, 100)
                        else
                            THUD.HPText.TextColor3 = Color3.fromRGB(190, 190, 190)
                        end
                    end
                end
            end
        end
    else
        if S.Aim.Target then ClearTarget() end  -- only call when there is something to clear
    end

    if not S.Aim.Target or not S.Aim.IsAiming then
        if LTracer.Visible then LTracer.Visible=false end
        if THUD.Container and THUD.Container.Visible then THUD.Container.Visible = false end
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
        if S.World.NoFog then
            if Lit.FogEnd ~= 100000 then Lit.FogEnd = 100000 end
            if Lit.FogStart ~= 0 then Lit.FogStart = 0 end
        end
        if S.World.FullB then
            if Lit.Ambient ~= C3N(1,1,1) then Lit.Ambient = C3N(1,1,1) end
            if Lit.OutdoorAmbient ~= C3N(1,1,1) then Lit.OutdoorAmbient = C3N(1,1,1) end
            if Lit.ColorShift_Bottom ~= C3N(1,1,1) then Lit.ColorShift_Bottom = C3N(1,1,1) end
            if Lit.ColorShift_Top ~= C3N(1,1,1) then Lit.ColorShift_Top = C3N(1,1,1) end
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
            mc.HRP.CFrame = mc.HRP.CFrame * CFrame.Angles(0, mRad(mov.SpinSpeed), 0)
        end
        
        if mov.FlyOn and mc.HRP then
            local cam = workspace.CurrentCamera
            local moveDir = Vector3.zero
            if UIS:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + cam.CFrame.LookVector end
            if UIS:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - cam.CFrame.LookVector end
            if UIS:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + cam.CFrame.RightVector end
            if UIS:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - cam.CFrame.RightVector end
            if UIS:IsKeyDown(Enum.KeyCode.Space) then moveDir = moveDir + V3(0, 1, 0) end
            if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then moveDir = moveDir + V3(0, -1, 0) end
            
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
        fps = mFloor(_fpsCount / (_fpsNow - _fpsLast))
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
    
    if S.Cross.On then
        local cC, cS, cG = S.Cross.Color, S.Cross.Size, S.Cross.Gap
        local center = V2(_cX, _cY)
        if S.FOV.Follow then local ms=UIS:GetMouseLocation(); center=ms end
        
        setL(CH_L, center - V2(cG + cS, 0), center - V2(cG, 0), cC, 1, 1)
        setL(CH_R, center + V2(cG, 0), center + V2(cG + cS, 0), cC, 1, 1)
        setL(CH_T, center - V2(0, cG + cS), center - V2(0, cG), cC, 1, 1)
        setL(CH_B, center + V2(0, cG), center + V2(0, cG + cS), cC, 1, 1)
        
        if S.Cross.Dot then
            setCirc(CH_D, center, 1, cC, 1, 1, true)
            CH_D.Filled = true
        else
            if CH_D.Visible then CH_D.Visible = false end
        end
    else
        if CH_L.Visible then
            CH_L.Visible=false; CH_R.Visible=false; CH_T.Visible=false; CH_B.Visible=false; CH_D.Visible=false
        end
    end
end

Conns[#Conns+1] = RS.Heartbeat:Connect(TickHB)
Conns[#Conns+1] = RS.RenderStepped:Connect(TickRender)





-- ==============================================================================
--  15. WINDUI 
-- ==============================================================================


local Window = Library:CreateWindow({
    Title = "KAIM v13",
    Footer = "v13 | github.com/sswird/kaim",
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

local KaimWatermark = Library:AddDraggableLabel("KAIM v13 | FPS: 0 | Ping: 0ms")

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
HomeRight:AddLabel("KAIM v13")
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
AimLeft:AddToggle("AimOn",     {Text="Enable Aimlock",       Default=false, Tooltip="Locks your camera onto the nearest enemy.", Callback=function(v) S.Aim.On=v end})
AimLeft:AddDropdown("AimKey",  {Text="Hold Key",             Default="RightClick", Values={"RightClick","LeftClick","E","Q","F","C","V","X","Z","LeftShift","LeftAlt"}, Callback=function(v) _aimKC=v end})
AimLeft:AddDropdown("AimPref", {Text="Target Part",          Default="Smart",      Values={"Smart","Nearest Part","Chaos","Head","Torso","Limbs"}, Callback=function(v) S.Aim.Mode=v end})
AimLeft:AddDivider()
AimLeft:AddToggle("AimPred",    {Text="Movement Prediction", Default=true, Tooltip="Leads aim ahead of moving targets to compensate for bullet travel.", Callback=function(v) S.Aim.Pred=v end})
AimLeft:AddSlider("AimPredStr", {Text="Prediction Strength", Default=14, Min=1, Max=30, Rounding=0, Tooltip="Higher = further lead. Tune per-game bullet speed.", Callback=function(v) S.Aim.PredStr=v/100 end})
AimLeft:AddSlider("AimHit",     {Text="Hit Chance (%)",      Default=100, Min=1, Max=100, Rounding=0, Tooltip="Randomly skips aimbot frames at <100%% for subtle play.", Callback=function(v) S.Aim.HitChance=v end})
AimLeft:AddToggle("AimNotify",  {Text="Notify on Lock",      Default=false, Tooltip="Show a UI notification when a target is locked.", Callback=function(v) S.Aim.NotifyLock=v end})

-- [ Silent Aim ]
local SilentSec = Tabs.Combat:AddLeftGroupbox("Silent Aim")
SilentSec:AddToggle("SilentOn", {Text="Enable Silent Aim", Default=false, Callback=function(v) S.Silent.On=v end})
SilentSec:AddSlider("SilentHit", {Text="Hit Chance", Default=100, Min=0, Max=100, Rounding=0, Callback=function(v) S.Silent.HitChance=v end})
SilentSec:AddSlider("SilentHead", {Text="Headshot Chance", Default=100, Min=0, Max=100, Rounding=0, Callback=function(v) S.Silent.HeadshotChance=v end})



-- [ Smooth Aim ]
local SmoothRight = Tabs.Combat:AddRightGroupbox("Smooth Aim")
SmoothRight:AddToggle("SmoothOn", {Text="Enable Smooth Aim", Default=false, Callback=function(v) S.Aim.Smooth=v end})
SmoothRight:AddSlider("SmoothAmt", {Text="Smoothness", Default=5, Min=1, Max=20, Rounding=1, Callback=function(v) S.Aim.SmoothSpd=(v/10) end})

-- [ Target HUD Settings ]
local ThudGrp = Tabs.Combat:AddRightGroupbox("Target HUD")
ThudGrp:AddToggle("T_On", {Text="Enable Target HUD", Default=true, Callback=function(v) S.THUD.On=v end})
ThudGrp:AddSlider("T_Scale", {Text="HUD Scale", Default=1.0, Min=0.5, Max=2.0, Rounding=1, Callback=function(v) S.THUD.Scale=v end})
ThudGrp:AddSlider("T_OffX", {Text="X Offset", Default=80, Min=-300, Max=300, Rounding=0, Callback=function(v) S.THUD.OffX=v end})
ThudGrp:AddSlider("T_OffY", {Text="Y Offset", Default=-24, Min=-300, Max=300, Rounding=0, Callback=function(v) S.THUD.OffY=v end})
ThudGrp:AddSlider("T_Trans", {Text="BG Transparency", Default=0.2, Min=0, Max=1, Rounding=1, Callback=function(v) S.THUD.BgTrans=v end})

-- [ Safety Checks ]
local CheckRight = Tabs.Combat:AddRightGroupbox("Safety Checks")
CheckRight:AddToggle("WallCheck", {Text="Wall Check", Default=true, Callback=function(v) S.Aim.WallCheck=v end})
CheckRight:AddSlider("WallCheckDelay", {Text="Wall Check Delay (s)", Default=0.5, Min=0, Max=3, Rounding=1, Callback=function(v) S.Aim.WallCheckDelay=v end})
CheckRight:AddToggle("TeamCheck", {Text="Team Check", Default=true, Callback=function(v) S.Aim.TeamCheck=v end})
CheckRight:AddToggle("EspTarg", {Text="ESP Targets Only", Default=false, Callback=function(v) S.Aim.ESPTargetsOnly=v end})

-- [ Feedback ]
local FeedbackRight = Tabs.Combat:AddRightGroupbox("Lock Feedback")
FeedbackRight:AddToggle("LockTrac", {Text="Lock Tracer", Default=true, Callback=function(v) S.Aim.LockTracer=v end})

-- [ Aim Offsets ]
local OffsetLeft = Tabs.Combat:AddLeftGroupbox("Aim Offsets")
OffsetLeft:AddSlider("O_X", {Text="Offset X", Default=0, Min=-5, Max=5, Rounding=1, Tooltip="Horizontal aim offset in studs.", Callback=function(v) S.Aim.OffX=v; _aimOff=V3(S.Aim.OffX,S.Aim.OffY,S.Aim.OffZ) end})
OffsetLeft:AddSlider("O_Y", {Text="Offset Y", Default=0, Min=-5, Max=5, Rounding=1, Tooltip="Vertical aim offset in studs.",   Callback=function(v) S.Aim.OffY=v; _aimOff=V3(S.Aim.OffX,S.Aim.OffY,S.Aim.OffZ) end})
OffsetLeft:AddSlider("O_Z", {Text="Offset Z", Default=0, Min=-5, Max=5, Rounding=1, Tooltip="Depth aim offset in studs.",      Callback=function(v) S.Aim.OffZ=v; _aimOff=V3(S.Aim.OffX,S.Aim.OffY,S.Aim.OffZ) end})

-- [ FOV Circle ]
local FovRight = Tabs.Combat:AddRightGroupbox("FOV Circle")
FovRight:AddToggle("ShowFov", {Text="Show FOV Circle", Default=true, Callback=function(v) S.FOV.Show=v; if FOVR then FOVR.Visible=v; FOVF.Visible=v end end})
FovRight:AddSlider("FovRad", {Text="FOV Radius", Default=150, Min=10, Max=800, Rounding=0, Callback=function(v) S.FOV.Radius=v; if FOVR then FOVR.Radius=v; FOVF.Radius=v end end})

-- [ Hitbox Expander ]
local HitboxLeft = Tabs.Combat:AddLeftGroupbox("Hitbox Expander")
HitboxLeft:AddToggle("H_On",    {Text="Enable Hitbox Expander", Default=false, Callback=function(v) S.HB.On=v end})
HitboxLeft:AddDropdown("H_Part",{Text="Expand Part",             Default="Head", Values={"Head","HumanoidRootPart","UpperTorso"}, Callback=function(v) S.HB.Part=v end})
HitboxLeft:AddSlider("H_Size",  {Text="Expand Size",             Default=5,   Min=2,   Max=30,   Rounding=0, Callback=function(v) S.HB.Size=v end})
HitboxLeft:AddSlider("H_Trans", {Text="Part Transparency",       Default=0.5, Min=0.0, Max=0.95, Rounding=2, Tooltip="Transparency of the expanded hitbox part. 0 = fully visible, 0.95 = nearly invisible.", Callback=function(v) S.HB.Trans=v end})

-- ==============================================================================
--  VISUALS TAB
-- ==============================================================================

-- [ ESP - Tabbox for Enemy / Friendly ]
local VisTabBox = Tabs.Visuals:AddLeftTabbox()
local VisEnemy  = VisTabBox:AddTab("Enemy")
local VisFriend = VisTabBox:AddTab("Friendly")

--  Enemy 
local _eS = function() return getgenv().SenseESP and getgenv().SenseESP.teamSettings.enemy end
VisEnemy:AddToggle("E_On", {Text="Enable Enemy ESP", Tooltip="Master switch for all enemy ESP.", Default=false,
    Callback=function(v) local s=_eS(); if s then s.enabled=v end end})
VisEnemy:AddDivider()

-- Boxes
VisEnemy:AddToggle("E_2D",  {Text="2D Box", Default=false, Callback=function(v) local s=_eS(); if s then s.box=v end end})
    :AddColorPicker("E_2DCol", {Default=Color3.fromRGB(255, 50, 50), Callback=function(v) local s=_eS(); if s then s.boxColor[1]=v end end})
VisEnemy:AddToggle("E_2DFill", {Text="Box Fill", Default=false, Callback=function(v) local s=_eS(); if s then s.boxFill=v end end})
    :AddColorPicker("E_2DFillCol", {Default=Color3.fromRGB(255, 50, 50), Callback=function(v) local s=_eS(); if s then s.boxFillColor[1]=v end end})
VisEnemy:AddToggle("E_3D",  {Text="3D Box", Default=false, Callback=function(v) local s=_eS(); if s then s.box3d=v end end})
    :AddColorPicker("E_3DCol", {Default=Color3.fromRGB(255, 50, 50), Callback=function(v) local s=_eS(); if s then s.box3dColor[1]=v end end})

-- Info
VisEnemy:AddToggle("E_Name",{Text="Name Tag", Default=false, Callback=function(v) local s=_eS(); if s then s.name=v end end})
    :AddColorPicker("E_NameCol", {Default=Color3.new(1,1,1), Callback=function(v) local s=_eS(); if s then s.nameColor[1]=v end end})
VisEnemy:AddToggle("E_Dist",{Text="Distance", Default=false, Callback=function(v) local s=_eS(); if s then s.distance=v end end})
    :AddColorPicker("E_DistCol", {Default=Color3.new(1,1,1), Callback=function(v) local s=_eS(); if s then s.distanceColor[1]=v end end})
VisEnemy:AddToggle("E_Wep", {Text="Weapon Name", Default=false, Callback=function(v) local s=_eS(); if s then s.weapon=v end end})
    :AddColorPicker("E_WepCol", {Default=Color3.new(1,1,1), Callback=function(v) local s=_eS(); if s then s.weaponColor[1]=v end end})
VisEnemy:AddToggle("E_Head",{Text="Head Dot", Default=false, Callback=function(v) local s=_eS(); if s then s.headDot=v end end})
    :AddColorPicker("E_HeadCol", {Default=Color3.new(1,1,1), Callback=function(v) local s=_eS(); if s then s.headDotColor[1]=v end end})

-- Health
VisEnemy:AddToggle("E_HB",  {Text="Health Bar", Default=false, Callback=function(v) local s=_eS(); if s then s.healthBar=v end end})
VisEnemy:AddToggle("E_HBTxt",{Text="Health Text", Default=false, Callback=function(v) local s=_eS(); if s then s.healthText=v end end})
    :AddColorPicker("E_HBTxtCol", {Default=Color3.new(1,1,1), Callback=function(v) local s=_eS(); if s then s.healthTextColor[1]=v end end})
VisEnemy:AddDivider()

-- Tracer
VisEnemy:AddToggle("E_Trac",{Text="Tracer", Default=false, Callback=function(v) local s=_eS(); if s then s.tracer=v end end})
    :AddColorPicker("E_TracCol", {Default=Color3.fromRGB(255, 50, 50), Callback=function(v) local s=_eS(); if s then s.tracerColor[1]=v end end})
VisEnemy:AddDropdown("E_TrOrigin",{Text="Tracer Origin", Default="Bottom", Values={"Bottom","Middle","Top"},
    Callback=function(v) local s=_eS(); if s then s.tracerOrigin=v end end})
VisEnemy:AddDivider()

-- Chams
VisEnemy:AddToggle("E_Cham",  {Text="Chams", Default=false, Callback=function(v) local s=_eS(); if s then s.chams=v end end})
    :AddColorPicker("E_ChamFill", {Default=Color3.fromRGB(255, 0, 0), Title="Fill", Callback=function(v) local s=_eS(); if s then s.chamsFillColor[1]=v end end})
    :AddColorPicker("E_ChamOut", {Default=Color3.fromRGB(255, 50, 50), Title="Outline", Callback=function(v) local s=_eS(); if s then s.chamsOutlineColor[1]=v end end})
VisEnemy:AddToggle("E_ChamVO",{Text="Visible-Only Chams", Default=true,
    Tooltip="ON: chams only show on visible players (not through walls). OFF: always on top.",
    Callback=function(v) local s=_eS(); if s then s.chamsVisibleOnly=v end end})


--  Friendly 
local _fS = function() return getgenv().SenseESP and getgenv().SenseESP.teamSettings.friendly end
VisFriend:AddToggle("F_On", {Text="Enable Friendly ESP", Tooltip="Master switch for all friendly ESP.", Default=false,
    Callback=function(v) local s=_fS(); if s then s.enabled=v end end})
VisFriend:AddDivider()

-- Boxes
VisFriend:AddToggle("F_2D",  {Text="2D Box", Default=false, Callback=function(v) local s=_fS(); if s then s.box=v end end})
    :AddColorPicker("F_2DCol", {Default=Color3.fromRGB(50, 255, 50), Callback=function(v) local s=_fS(); if s then s.boxColor[1]=v end end})
VisFriend:AddToggle("F_2DFill", {Text="Box Fill", Default=false, Callback=function(v) local s=_fS(); if s then s.boxFill=v end end})
    :AddColorPicker("F_2DFillCol", {Default=Color3.fromRGB(50, 255, 50), Callback=function(v) local s=_fS(); if s then s.boxFillColor[1]=v end end})
VisFriend:AddToggle("F_3D",  {Text="3D Box", Default=false, Callback=function(v) local s=_fS(); if s then s.box3d=v end end})
    :AddColorPicker("F_3DCol", {Default=Color3.fromRGB(50, 255, 50), Callback=function(v) local s=_fS(); if s then s.box3dColor[1]=v end end})

-- Info
VisFriend:AddToggle("F_Name",{Text="Name Tag", Default=false, Callback=function(v) local s=_fS(); if s then s.name=v end end})
    :AddColorPicker("F_NameCol", {Default=Color3.new(1,1,1), Callback=function(v) local s=_fS(); if s then s.nameColor[1]=v end end})
VisFriend:AddToggle("F_Dist",{Text="Distance", Default=false, Callback=function(v) local s=_fS(); if s then s.distance=v end end})
    :AddColorPicker("F_DistCol", {Default=Color3.new(1,1,1), Callback=function(v) local s=_fS(); if s then s.distanceColor[1]=v end end})
VisFriend:AddToggle("F_Wep", {Text="Weapon Name", Default=false, Callback=function(v) local s=_fS(); if s then s.weapon=v end end})
    :AddColorPicker("F_WepCol", {Default=Color3.new(1,1,1), Callback=function(v) local s=_fS(); if s then s.weaponColor[1]=v end end})
VisFriend:AddToggle("F_Head",{Text="Head Dot", Default=false, Callback=function(v) local s=_fS(); if s then s.headDot=v end end})
    :AddColorPicker("F_HeadCol", {Default=Color3.new(1,1,1), Callback=function(v) local s=_fS(); if s then s.headDotColor[1]=v end end})

-- Health
VisFriend:AddToggle("F_HB",  {Text="Health Bar", Default=false, Callback=function(v) local s=_fS(); if s then s.healthBar=v end end})
VisFriend:AddToggle("F_HBTxt",{Text="Health Text", Default=false, Callback=function(v) local s=_fS(); if s then s.healthText=v end end})
    :AddColorPicker("F_HBTxtCol", {Default=Color3.new(1,1,1), Callback=function(v) local s=_fS(); if s then s.healthTextColor[1]=v end end})
VisFriend:AddDivider()

-- Tracer
VisFriend:AddToggle("F_Trac",{Text="Tracer", Default=false, Callback=function(v) local s=_fS(); if s then s.tracer=v end end})
    :AddColorPicker("F_TracCol", {Default=Color3.fromRGB(50, 255, 50), Callback=function(v) local s=_fS(); if s then s.tracerColor[1]=v end end})
VisFriend:AddDropdown("F_TrOrigin",{Text="Tracer Origin", Default="Bottom", Values={"Bottom","Middle","Top"},
    Callback=function(v) local s=_fS(); if s then s.tracerOrigin=v end end})
VisFriend:AddDivider()

-- Chams
VisFriend:AddToggle("F_Cham",  {Text="Chams", Default=false, Callback=function(v) local s=_fS(); if s then s.chams=v end end})
    :AddColorPicker("F_ChamFill", {Default=Color3.fromRGB(0, 255, 0), Title="Fill", Callback=function(v) local s=_fS(); if s then s.chamsFillColor[1]=v end end})
    :AddColorPicker("F_ChamOut", {Default=Color3.fromRGB(50, 255, 50), Title="Outline", Callback=function(v) local s=_fS(); if s then s.chamsOutlineColor[1]=v end end})
VisFriend:AddToggle("F_ChamVO",{Text="Visible-Only Chams", Default=true,
    Tooltip="ON: chams only show on visible players. OFF: always on top.",
    Callback=function(v) local s=_fS(); if s then s.chamsVisibleOnly=v end end})

-- [ Global ESP Settings - Right side ]
local VisSettings = Tabs.Visuals:AddRightGroupbox("Global Settings")
VisSettings:AddToggle("G_Lim",  {Text="Limit Distance", Default=false,
    Callback=function(v) local s=getgenv().SenseESP; if s then s.sharedSettings.limitDistance=v end end})
VisSettings:AddSlider("G_MaxD", {Text="Max Distance (studs)", Default=1000, Min=50, Max=5000, Rounding=0,
    Callback=function(v) local s=getgenv().SenseESP; if s then s.sharedSettings.maxDistance=v end end})
VisSettings:AddSlider("G_TxtSz",{Text="Text Size", Default=13, Min=8, Max=24, Rounding=0,
    Callback=function(v) local s=getgenv().SenseESP; if s then s.sharedSettings.textSize=v end end})
VisSettings:AddToggle("G_TCol", {Text="Use Team Colors", Default=false,
    Callback=function(v) local s=getgenv().SenseESP; if s then s.sharedSettings.useTeamColor=v end end})

-- [ Custom Crosshair ]
local CrossSettings = Tabs.Visuals:AddRightGroupbox("Custom Crosshair")
CrossSettings:AddToggle("C_On", {Text="Enable Crosshair", Default=false, Callback=function(v) S.Cross.On=v end})
    :AddColorPicker("C_Col", {Default=Color3.new(1,1,1), Callback=function(v) S.Cross.Color=v end})
CrossSettings:AddSlider("C_Size", {Text="Size", Default=8, Min=2, Max=30, Rounding=0, Callback=function(v) S.Cross.Size=v end})
CrossSettings:AddSlider("C_Gap",  {Text="Gap", Default=4, Min=0, Max=20, Rounding=0, Callback=function(v) S.Cross.Gap=v end})
CrossSettings:AddToggle("C_Dot",  {Text="Center Dot", Default=false, Callback=function(v) S.Cross.Dot=v end})


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
MovChar:AddToggle("P_Spin",  {Text="Spinbot",    Default=false, Callback=function(v) S.Mov.SpinOn=v end})
MovChar:AddSlider("P_SpinS", {Text="Spin Speed", Default=20, Min=5, Max=100, Rounding=0, Callback=function(v) S.Mov.SpinSpeed=v end})
MovChar:AddDivider()
MovChar:AddToggle("P_BHop",  {Text="Bunny Hop",  Default=false, Tooltip="Auto-jumps on landing while moving to maintain momentum.", Callback=function(v) S.Mov.BHop=v end})

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
MovLighting:AddToggle("W_NoFog", {Text="No Fog", Default=false, Callback=function(v) S.World.NoFog=v; if not v then pcall(function() Lit.FogEnd=OrigLit.FEnd; Lit.FogStart=OrigLit.FStart end) end end})
MovLighting:AddToggle("W_FullB", {Text="Fullbright", Default=false, Callback=function(v) S.World.FullB=v; if not v then pcall(function() Lit.Ambient=OrigLit.A; Lit.OutdoorAmbient=OrigLit.OA; Lit.ColorShift_Bottom=OrigLit.CSB; Lit.ColorShift_Top=OrigLit.CST end) end end})

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
MainFrame.BackgroundColor3 = C3(20, 20, 20)
MainFrame.BorderSizePixel = 0
MainFrame.Visible = false
MainFrame.Parent = AudioGUI

local corner = iNew("UICorner")
corner.CornerRadius = UDim.new(0, 6)
corner.Parent = MainFrame

local outline = iNew("UIStroke")
outline.Color = C3(50, 50, 50)
outline.Parent = MainFrame

local SongLabel = iNew("TextLabel")
SongLabel.BackgroundTransparency = 1
SongLabel.Size = UDim2.new(1, -30, 0, 20)
SongLabel.Position = UDim2.new(0, 5, 0, 0)
SongLabel.Text = "No Song"
SongLabel.TextColor3 = C3N(1,1,1)
SongLabel.Font = Enum.Font.Code
SongLabel.TextSize = 13
SongLabel.TextXAlignment = Enum.TextXAlignment.Left
SongLabel.Parent = MainFrame

local CloseBtn = iNew("TextButton")
CloseBtn.BackgroundTransparency = 1
CloseBtn.Size = UDim2.new(0, 20, 0, 20)
CloseBtn.Position = UDim2.new(1, -25, 0, 0)
CloseBtn.Text = "X"
CloseBtn.TextColor3 = C3N(1, 0.3, 0.3)
CloseBtn.Font = Enum.Font.Code
CloseBtn.TextSize = 15
CloseBtn.Parent = MainFrame



-- Time Slider
local TimeBG = iNew("Frame")
TimeBG.BackgroundColor3 = C3N(0.15, 0.15, 0.15)
TimeBG.Size = UDim2.new(1, -10, 0, 8)
TimeBG.Position = UDim2.new(0, 5, 0, 25)
TimeBG.BorderSizePixel = 0
TimeBG.Parent = MainFrame

local TimeFill = iNew("Frame")
TimeFill.BackgroundColor3 = C3(0, 162, 255)
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
VolBG.BackgroundColor3 = C3N(0.15, 0.15, 0.15)
VolBG.Size = UDim2.new(1, -10, 0, 8)
VolBG.Position = UDim2.new(0, 5, 0, 40)
VolBG.BorderSizePixel = 0
VolBG.Parent = MainFrame

local VolFill = iNew("Frame")
VolFill.BackgroundColor3 = C3(0, 255, 100)
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

CloseBtn.MouseButton1Click:Connect(function()
    if _currentSong then _currentSong:Destroy(); _currentSong = nil end
    MainFrame.Visible = false
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

RS.RenderStepped:Connect(function(dt)
    if not _currentSong then return end
    
    if isDraggingTime then
        local ms = UIS:GetMouseLocation()
        local pct = mClamp((ms.X - TimeBG.AbsolutePosition.X) / TimeBG.AbsoluteSize.X, 0, 1)
        TimeFill.Size = UDim2.new(pct, 0, 1, 0)
        _currentSong.TimePosition = pct * _currentSong.TimeLength
    else
        local len = _currentSong.TimeLength
        if len > 0 then
            TimeFill.Size = UDim2.new(_currentSong.TimePosition / len, 0, 1, 0)
            local pos = _currentSong.TimePosition
            local fPos = string.format("%02d:%02d", mFloor(pos/60), mFloor(pos%60))
            local fLen = string.format("%02d:%02d", mFloor(len/60), mFloor(len%60))
            SongLabel.Text = _currentSongName .. " | " .. fPos .. " / " .. fLen
        end
    end
    
    if isDraggingVol then
        local ms = UIS:GetMouseLocation()
        local pct = mClamp((ms.X - VolBG.AbsolutePosition.X) / VolBG.AbsoluteSize.X, 0, 1)
        VolFill.Size = UDim2.new(pct, 0, 1, 0)
        _songVol = pct * 10
        _currentSong.Volume = _songVol
    end
end)

local function PlaySong(id, name)
    if _currentSong then _currentSong:Destroy(); _currentSong = nil end
    if id == nil then return end
    
    local snd = iNew("Sound")
    snd.SoundId = "rbxassetid://"..tostring(id)
    snd.Volume = _songVol
    snd.Parent = SafeGui
    snd:Play()
    
    _currentSong = snd
    _currentSongName = name
    MainFrame.Visible = true
    
    snd.Ended:Connect(function()
        if _currentSong == snd then 
            _currentSong:Destroy()
            _currentSong = nil 
            MainFrame.Visible = false
        end
    end)
end

local ExtraSongs = Tabs.Extra:AddLeftGroupbox("Songs")
ExtraSongs:AddButton({Text="Bumblebee",           Tooltip="Plays Bumblebee",             Func=function() PlaySong("139067966802141", "Bumblebee")         end})
ExtraSongs:AddButton({Text="Phonk Drive",         Tooltip="Plays Phonk Drive",           Func=function() PlaySong("7812252261",       "Phonk Drive")       end})
ExtraSongs:AddButton({Text="Astronomia",          Tooltip="Coffin Dance / Astronomia",   Func=function() PlaySong("2681087658",       "Astronomia")        end})
ExtraSongs:AddButton({Text="Bury the Light",      Tooltip="DMC5 - Bury the Light",       Func=function() PlaySong("6801268505",       "Bury the Light")    end})
ExtraSongs:AddButton({Text="Monody",              Tooltip="TheFatRat - Monody",          Func=function() PlaySong("375839169",        "Monody")            end})
ExtraSongs:AddButton({Text="Firefly",             Tooltip="Firefly - lo-fi edit",        Func=function() PlaySong("142376088",        "Firefly")           end})
ExtraSongs:AddButton({Text="Worlds (Imagine Dragons)", Tooltip="Imagine Dragons - Worlds",Func=function() PlaySong("231317974",        "Worlds")            end})
ExtraSongs:AddButton({Text="⏹ Stop Song",         Tooltip="Stops the current song",      Func=function() PlaySong(nil, "") end})








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
ThemeManager:SetFolder("KAIM_v13")
SaveManager:SetFolder("KAIM_v13/configs")

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
Conns[#Conns+1] = RS.Heartbeat:Connect(function()
    local now = os.clock()
    if now - lastUIRefresh >= 0.5 then
        local ping = 0
        local stats = game:GetService("Stats")
        if stats and stats.Network and stats.Network.ServerStatsItem and stats.Network.ServerStatsItem["Data Ping"] then
            ping = stats.Network.ServerStatsItem["Data Ping"]:GetValue()
        end
        local _lockStr = (S.Aim.Target and S.Aim.IsAiming) and (" | LOCK: " .. (S.Aim.Target.DisplayName or "?")) or ""
        KaimWatermark:SetText("KAIM v13 | FPS: " .. tostring(fps) .. " | Ping: " .. mFloor(ping) .. "ms" .. _lockStr)
        lastUIRefresh = now
    end
end)

_env.KAIM_UNLOAD = function()
    ClearTarget()
    for i=1,#Conns do pcall(function() Conns[i]:Disconnect() end) end
    pcall(function() getgenv().SenseESP.Unload() end)
    pcall(_destroyTHUD)
    SetNC(false)
    if S.Mov.FOVOn then pcall(function() workspace.CurrentCamera.FieldOfView=70 end) end
    if S.Mov.GravOn then pcall(function() workspace.Gravity=196.2 end) end
    if S.World.On then pcall(function() Lit.ClockTime=OrigLit.T; Lit.Brightness=OrigLit.B; Lit.GlobalShadows=OrigLit.S; Lit.Ambient=OrigLit.A end) end
    if S.World.NoFog then pcall(function() Lit.FogEnd=OrigLit.FEnd; Lit.FogStart=OrigLit.FStart end) end
    if S.World.FullB then pcall(function() Lit.Ambient=OrigLit.A; Lit.OutdoorAmbient=OrigLit.OA; Lit.ColorShift_Bottom=OrigLit.CSB; Lit.ColorShift_Top=OrigLit.CST end) end
    if CC[LP] and CC[LP].Hum then CC[LP].Hum.WalkSpeed=16; CC[LP].Hum.UseJumpPower=true; CC[LP].Hum.JumpPower=50 end
    for pl,parts in pairs(HBOrig) do for part,d in pairs(parts) do if part and part.Parent then part.Size=d.Size; part.Transparency=d.Trans; part.CanCollide=d.CC end end end
    pcall(function() FOVR:Remove(); FOVF:Remove(); LTracer:Remove() end)
    pcall(function() end)
    pcall(function() if _currentSong then _currentSong:Destroy(); _currentSong=nil end end)
    pcall(function() if AudioGUI    then AudioGUI:Destroy();    AudioGUI=nil    end end)
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
Conns[#Conns+1] = UIS.JumpRequest:Connect(function()
    if S.Mov.InfJump and LP.Character and CC[LP] and CC[LP].Hum then
        CC[LP].Hum:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end)

local _isUiOpen = true
Conns[#Conns+1] = UIS.InputBegan:Connect(function(inp, gpe)
    -- Allow mouse buttons even if gpe is true (e.g. right click camera movement)
    if gpe and inp.UserInputType == Enum.UserInputType.Keyboard then return end

    -- Global UI Click Sound (Removed)

    -- Check for UI Toggle sound (Removed)
    if inp.KeyCode == Library.ToggleKeybind then
        _isUiOpen = not _isUiOpen
    end

    pcall(function()
        if _aimKC == "RightClick" and inp.UserInputType == Enum.UserInputType.MouseButton2 then
            S.Aim.IsAiming = true
                    elseif _aimKC == "LeftClick" and inp.UserInputType == Enum.UserInputType.MouseButton1 then
            S.Aim.IsAiming = true
                    elseif type(_aimKC) == "string" and inp.KeyCode.Name == _aimKC then
            S.Aim.IsAiming = true
                    end
    end)

    if inp.KeyCode == Enum.KeyCode.N then
        local ns = not S.Mov.Noclip; SetNC(ns)
        Library:Notify({Title="Noclip", Description="Noclip "..(ns and "ON" or "OFF"), Time=2})
    end
end)

Conns[#Conns+1] = UIS.InputEnded:Connect(function(inp, gpe)
    pcall(function()
        if _aimKC == "RightClick" and inp.UserInputType == Enum.UserInputType.MouseButton2 then
            S.Aim.IsAiming = false
        elseif _aimKC == "LeftClick" and inp.UserInputType == Enum.UserInputType.MouseButton1 then
            S.Aim.IsAiming = false
        elseif type(_aimKC) == "string" and inp.KeyCode.Name == _aimKC then
            S.Aim.IsAiming = false
        end
    end)
end)

-- ==============================================================================
--  17. INITIALIZATION COMPLETE
-- ==============================================================================
Library:Notify({Title="KAIM Obsidian v13", Description="Loaded - Obsidian Edition", Time=4})



-- SILENT AIM HOOK
if hookmetamethod then
    local _oldNamecall
    local function NamecallHook(self, ...)
        local method = getnamecallmethod()
        local args = {...}
        local tc = CC[S.Silent.Target]
        
        local valid = not checkcaller() and S.Silent.On and S.Silent.Target and tc and tc.Head
        local vMeth = (method == "Raycast" or method == "FindPartOnRayWithIgnoreList" or method == "FindPartOnRayWithWhitelist" or method == "FindPartOnRay")
        local hitRoll = math.random(1, 100)
        
        if valid and vMeth and (hitRoll <= S.Silent.HitChance) then
            local hitPart = tc.Head
            local hsRoll = math.random(1, 100)
            
            if S.Silent.HeadshotChance < 100 and hsRoll > S.Silent.HeadshotChance then
                hitPart = tc.HRP or tc.Head
            end
            
            if method == "Raycast" then
                args[2] = (hitPart.Position - args[1]).Unit * 1000
            else
                local origin = args[1].Origin
                args[1] = Ray.new(origin, (hitPart.Position - origin).Unit * 1000)
            end
        end
        
        return _oldNamecall(self, unpack(args))
    end
    
    _oldNamecall = hookmetamethod(game, "__namecall", NamecallHook)
else
    warn("KAIM: Your executor does not support hookmetamethod! Silent Aim is disabled.")
end
