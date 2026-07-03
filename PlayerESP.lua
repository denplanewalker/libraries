local module = {}

function module.init(context)
    local LocalPlayer = context.LocalPlayer
    local Workspace = context.Workspace
    local Players = context.Players
    local RunService = context.RunService
    local HttpService = context.HttpService
    local AddConnection = context.AddConnection
    local ESPSection = context.ESPSection

    local cam = Workspace.CurrentCamera

    local PlayerESP = {
        settings = {
            enabled = false, boxEnabled = false, nameEnabled = false,
            distanceEnabled = false, weaponEnabled = false, chamsEnabled = false,
            boxType = "Corner", boxOutline = true, boxFill = false,
            fillTransparency = 0.75, renderDistance = 1000,
            boxColor         = Color3.fromRGB(0, 120, 255),
            outlineColor     = Color3.fromRGB(20, 20, 20),
            fillColor        = Color3.fromRGB(0, 120, 255),
            fillColor2       = Color3.fromRGB(20, 20, 20),
            nameColor        = Color3.fromRGB(0, 120, 255),
            nameOutline      = true,
            nameOutlineColor = Color3.fromRGB(20, 20, 20),
            distColor        = Color3.fromRGB(0, 120, 255),
            distOutline      = true,
            distOutlineColor = Color3.fromRGB(20, 20, 20),
            weapColor        = Color3.fromRGB(0, 120, 255),
            weapOutline      = true,
            weapOutlineColor = Color3.fromRGB(20, 20, 20),
            chamsColor       = Color3.fromRGB(0, 120, 255),
            sleepCheck = false, teamCheck = false, aiCheck = false,
        },
        cache = {
            boxes      = setmetatable({}, {__mode = "k"}),
            sleep      = setmetatable({}, {__mode = "k"}),
            player     = setmetatable({}, {__mode = "k"}),
            weapon     = setmetatable({}, {__mode = "k"}),
            weaponTime = setmetatable({}, {__mode = "k"}),
            chams      = setmetatable({}, {__mode = "k"}),
        },
        const = {
            V3_UP = Vector3.new(0, 2.8, 0),
            V3_DN = Vector3.new(0, 3.0, 0),
            ANCHORS = {
                LeftTop         = Vector2.new(0, 0),
                LeftSide        = Vector2.new(0, 0),
                RightTop        = Vector2.new(1, 0),
                RightSide       = Vector2.new(0, 0),
                BottomSide      = Vector2.new(0, 1),
                BottomDown      = Vector2.new(0, 1),
                BottomRightSide = Vector2.new(1, 1),
                BottomRightDown = Vector2.new(1, 1),
            },
        },
    }

    local espGui = Instance.new("ScreenGui")
    espGui.Name           = "PlayerESPHolder"
    espGui.ResetOnSpawn   = false
    espGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    espGui.IgnoreGuiInset = true
    espGui.Parent         = LocalPlayer:WaitForChild("PlayerGui")

    LocalPlayer.CharacterAdded:Connect(function()
        task.wait(0.5)
        if not espGui or not espGui.Parent then
            espGui = Instance.new("ScreenGui")
            espGui.Name           = "PlayerESPHolder"
            espGui.ResetOnSpawn   = false
            espGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
            espGui.IgnoreGuiInset = true
            espGui.Parent         = LocalPlayer:WaitForChild("PlayerGui")
        end
    end)

    -- Helper Functions
    local function PESP_IsTeam(m)
        if not m then return false end
        local h = m:FindFirstChild("Head")
        return h and h:FindFirstChild("Dot") and h.Dot.Enabled == true or false
    end

    local function PESP_IsSleeper(m)
        if not m then return false end
        local c = PlayerESP.cache.sleep[m]
        if c and tick() - c.time < 1 then return c.value end
        local lt = m:FindFirstChild("LowerTorso"); local v = false
        if lt then
            local rr = lt:FindFirstChild("RootRig")
            if rr then
                local ok, a = pcall(function() return rr.CurrentAngle end)
                v = ok and type(a) == "number" and a ~= 0 or false
            end
        end
        PlayerESP.cache.sleep[m] = {value = v, time = tick()}; return v
    end

    local function PESP_IsPlayer(m)
        local c = PlayerESP.cache.player[m]
        if c and tick() - c.time < 2 then return c.value end
        local t = m:FindFirstChild("Torso")
        local v = t and t:FindFirstChild("LeftBooster") and true or false
        PlayerESP.cache.player[m] = {value = v, time = tick()}; return v
    end

    local function PESP_IsAI(m)
        local t = m:FindFirstChild("Torso") or m:FindFirstChild("HumanoidRootPart")
        return t and t.CollisionGroup == "NPC" or false
    end

    local function PESP_ShouldSkip(m)
        if not m or not m.Parent then return true end
        local s = PlayerESP.settings
        if s.sleepCheck and PESP_IsSleeper(m) then return true end
        if s.teamCheck  and PESP_IsTeam(m)    then return true end
        if s.aiCheck    and PESP_IsAI(m)      then return true end
        return false
    end

    local weaponDataESP = {
        Bow={"Arrow","Fabric","Handle","Meshes/Bow","ADS","Mover","AnimationController"},
        Ar15={"AnimSaves","Barrel","Body","Bolt","ChargingHandle","Decor","Grip","Handle","Mag","Rails","Stock","ADS","Muzzle","AnimationController"},
        Blunderbuss={"Body","Handle","Tube","thing","ADS","Muzzle","AnimationController"},
        C9={"Barrel","Body","Bolt","Decor","Grip","Handle","LowerSlide","Mag","Sight1","Sight2","UpperSlide","ADS","Muzzle","AnimationController"},
        CrossBow={"Arrow","BackMetal","Body","FrontNails","Handle","Release","SpringSteel","String","Wheel","ADS","Slide","AnimationController"},
        EnergyRifle={"DefaultSight","FrontCover","Glowing","Grip","Handle","Mag","Metal","Metal2","RearCover","RearDecor","Screws","Tubes","AnimationController"},
        GaussRifle={"DefaultSight","Barrel","Body","CoilHolders","Coils","Decals1","Decals2","Grip","Handle","Housing","Mag","StockBack","AnimationController"},
        Hmar={"DefaultSight","Body","Bolt","Bolts","Cover","Handle","Mag","Rails","Spring","Stock","Wood","Muzzle","AnimationController"},
        LeverActionRifle={"9mm","DefaultSight","Body","Brass","Hammer","Handle","Lever","Metal","Thing","Wood","Muzzle","AnimationController"},
        M4a1={"DefaultSight","Body","Bolt","ChargeHandle","Grip","Handle","Mag","Metal","mbrk","Muzzle","AnimationController"},
        PipePistol={"DefaultSight","Body","Bolt","Handle","Mag","Muzzle","AnimationController"},
        PipeSmg={"DefaultSight","Barrel","Body","Bolt","Flap","Grip","Handle","Mag","Stock","Muzzle","AnimationController"},
        PumpShotgun={"Barrel","Body","Handle","MainMetal","RearSight","Shell","Slider","ADS","Muzzle","AnimationController"},
        RPG={"RocketModel","Body","Body2","Caps","Fasteners","FireMech","Handle","Safety","Sight","Trigger","ADS","Muzzle","AnimationController"},
        Scar={"DefaultSight","Barrel","Body","ChargingHandle","Decals","Handle","Mag","Rails","ShoulderPad","Stock","Muzzle","AnimationController"},
        Svd={"DefaultSight","Body","Bolt","Handle","Magazine","Magazine2","Metal2","Wood","AnimationController"},
        Usp9={"Body","Handle","Mag","Slide","ADS","Muzzle","AnimationController"},
        Uzi={"DefaultSight","Body","Body2","Bolt","ChargingHandle","Decor","Grip","Handle","Mag","Stock","Muzzle","AnimationController"},
        Magnum={"Cylinder","Decor","EjectRod","EjectRodDecal","Frame","Grip"},
    }

    local function PESP_DetectWeapon(m)
        local t  = tick()
        local lu = PlayerESP.cache.weaponTime[m]
        if lu and t - lu < 2 then return PlayerESP.cache.weapon[m] or "None" end
        local hand = m:FindFirstChild("HandModel")
        if not hand then
            PlayerESP.cache.weapon[m] = "None"; PlayerESP.cache.weaponTime[m] = t; return "None"
        end
        local best, bestN = "None", 0
        for wn, parts in next, weaponDataESP do
            local cnt = 0
            for _, p in ipairs(parts) do if hand:FindFirstChild(p, true) then cnt = cnt + 1 end end
            if cnt > bestN then best = wn; bestN = cnt end
        end
        PlayerESP.cache.weapon[m] = best; PlayerESP.cache.weaponTime[m] = t
        return best
    end

    local function PESP_UpdateChams(m, enabled)
        if not PlayerESP.settings.chamsEnabled or not enabled then
            local c = PlayerESP.cache.chams[m]
            if c and c.Enabled then c.Enabled = false end
            return
        end
        local c = PlayerESP.cache.chams[m]
        if not c or not c.Parent then
            if c then pcall(function() c:Destroy() end) end
            local hl = Instance.new("Highlight")
            hl.FillTransparency    = 0
            hl.OutlineTransparency = 1
            hl.DepthMode           = Enum.HighlightDepthMode.AlwaysOnTop
            hl.FillColor           = PlayerESP.settings.chamsColor
            hl.Parent              = m
            PlayerESP.cache.chams[m] = hl
        else
            if c.FillColor ~= PlayerESP.settings.chamsColor then
                c.FillColor = PlayerESP.settings.chamsColor
            end
            if not c.Enabled then c.Enabled = true end
        end
    end

    -- Drawing Functions
    local function PESP_NewText()
        local t = Drawing.new("Text")
        t.Visible = false; t.Size = 13; t.Center = true
        t.Font = 2; t.Outline = true; t.OutlineColor = Color3.fromRGB(0,0,0)
        return t
    end

    local function PESP_NewCornerFrame(anchor)
        local f = Instance.new("Frame")
        f.BackgroundColor3       = PlayerESP.settings.boxColor
        f.BorderSizePixel        = 0
        f.BackgroundTransparency = 0
        f.Visible                = false
        f.AnchorPoint            = anchor
        f.ZIndex                 = 2
        f.Parent                 = espGui
        local s = Instance.new("UIStroke")
        s.Color = Color3.fromRGB(0,0,0); s.Thickness = 1; s.Transparency = 0
        s.LineJoinMode = Enum.LineJoinMode.Miter
        s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        s.Parent = f
        return f, s
    end

    local function PESP_MakeCorners()
        local cf = {}
        for name, anchor in next, PlayerESP.const.ANCHORS do
            local f, s = PESP_NewCornerFrame(anchor)
            cf[name] = {f = f, s = s}
        end
        return cf
    end

    local function PESP_MakeFillFrame()
        local f = Instance.new("Frame")
        f.BorderSizePixel = 0; f.BackgroundColor3 = Color3.fromRGB(255,255,255)
        f.BackgroundTransparency = 1; f.Visible = false; f.ZIndex = 0; f.Parent = espGui
        local g = Instance.new("UIGradient")
        g.Rotation = 90
        g.Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0, PlayerESP.settings.fillColor),
            ColorSequenceKeypoint.new(1, PlayerESP.settings.fillColor2),
        }
        g.Parent = f
        return f, g
    end

    local function PESP_MakeDefaultBox()
        local fill, fillGrad = PESP_MakeFillFrame()
        fill.ZIndex = 0
        local strokeOutline = Instance.new("UIStroke")
        strokeOutline.Color = PlayerESP.settings.outlineColor; strokeOutline.Thickness = 3
        strokeOutline.Transparency = 0; strokeOutline.LineJoinMode = Enum.LineJoinMode.Miter
        strokeOutline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; strokeOutline.Parent = fill
        local main = Instance.new("Frame")
        main.BorderSizePixel = 0; main.BackgroundColor3 = Color3.fromRGB(0,0,0)
        main.BackgroundTransparency = 1; main.Visible = false; main.ZIndex = 2; main.Parent = espGui
        local stroke = Instance.new("UIStroke")
        stroke.Color = PlayerESP.settings.boxColor; stroke.Thickness = 1; stroke.Transparency = 0
        stroke.LineJoinMode = Enum.LineJoinMode.Miter
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; stroke.Parent = main
        return {fill=fill, fillGrad=fillGrad, main=main, stroke=stroke, strokeOutline=strokeOutline}
    end

    local function PESP_ApplyFill(fill, grad, l, t, w, h)
        grad.Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0, PlayerESP.settings.fillColor),
            ColorSequenceKeypoint.new(1, PlayerESP.settings.fillColor2),
        }
        fill.BackgroundTransparency = PlayerESP.settings.boxFill and PlayerESP.settings.fillTransparency or 1
        fill.Position = UDim2.new(0, l, 0, t); fill.Size = UDim2.new(0, w, 0, h)
        fill.Visible = true
    end

    local PESP_CORNER_POS = {}
    local function PESP_BuildCornerPos(l, r, t, b, cx, cy)
        PESP_CORNER_POS.LeftTop         = {l,   t,  cx,  1.5}
        PESP_CORNER_POS.LeftSide        = {l,   t,  1.5, cy}
        PESP_CORNER_POS.RightTop        = {r,   t,  cx,  1.5}
        PESP_CORNER_POS.RightSide       = {r-1, t,  1.5, cy}
        PESP_CORNER_POS.BottomSide      = {l,   b,  1.5, cy}
        PESP_CORNER_POS.BottomDown      = {l,   b,  cx,  1.5}
        PESP_CORNER_POS.BottomRightSide = {r,   b,  1.5, cy}
        PESP_CORNER_POS.BottomRightDown = {r,   b,  cx,  1.5}
    end

    local function PESP_UpdateCorners(cf, fill, grad, px, py, w, h)
        local cx, cy = w*0.22, h*0.22
        local l, r   = px - w*0.5, px + w*0.5
        local t, b   = py - h*0.5, py + h*0.5
        PESP_BuildCornerPos(l, r, t, b, cx, cy)
        local bc  = PlayerESP.settings.boxColor
        local oc  = PlayerESP.settings.outlineColor
        local otr = PlayerESP.settings.boxOutline and 0 or 1
        for name, seg in next, cf do
            local d = PESP_CORNER_POS[name]
            seg.f.Position = UDim2.new(0, d[1], 0, d[2]); seg.f.Size = UDim2.new(0, d[3], 0, d[4])
            seg.f.BackgroundColor3 = bc; seg.f.Visible = true
            seg.s.Color = oc; seg.s.Transparency = otr
        end
        PESP_ApplyFill(fill, grad, l, t, w, h)
    end

    local function PESP_UpdateDefaultBox(db, px, py, w, h)
        local l, t = px - w*0.5, py - h*0.5
        PESP_ApplyFill(db.fill, db.fillGrad, l, t, w, h)
        db.strokeOutline.Color = PlayerESP.settings.outlineColor
        db.strokeOutline.Transparency = PlayerESP.settings.boxOutline and 0 or 1
        db.main.Position = UDim2.new(0, l, 0, t); db.main.Size = UDim2.new(0, w, 0, h)
        db.main.Visible = true; db.stroke.Color = PlayerESP.settings.boxColor; db.stroke.Transparency = 0
    end

    local function PESP_HideCorners(cf, fill)
        for _, seg in next, cf do
            if seg.f.Visible then seg.f.Visible = false end
        end
        if fill.Visible then fill.Visible = false end
    end

    local function PESP_HideDefault(db)
        if db.fill.Visible then db.fill.Visible = false end
        if db.main.Visible then db.main.Visible = false end
    end

    local function PESP_DestroyEntry(m, d)
        pcall(function() d.cacheConn:Disconnect() end)
        for _, seg in next, d.corners do pcall(function() seg.f:Destroy() end) end
        pcall(function() d.cFill:Destroy() end)
        pcall(function() d.default.fill:Destroy() end)
        pcall(function() d.default.main:Destroy() end)
        pcall(function() d.nameText:Remove() end)
        pcall(function() d.distText:Remove() end)
        pcall(function() d.weapText:Remove() end)
        PlayerESP.cache.boxes[m] = nil
    end

    local function PESP_CreateEntry(m)
        if PlayerESP.cache.boxes[m] then return end
        local cFill, cGrad = PESP_MakeFillFrame()
        local entry = {
            corners   = PESP_MakeCorners(),
            cFill     = cFill,
            cGrad     = cGrad,
            default   = PESP_MakeDefaultBox(),
            nameText  = PESP_NewText(),
            distText  = PESP_NewText(),
            weapText  = PESP_NewText(),
            hrp       = m:FindFirstChild("HumanoidRootPart"),
            lastCache = 0,
            isPlayer  = false,
            isSleeper = false,
        }
        entry.cacheConn = m.ChildAdded:Connect(function()
            entry.hrp = m:FindFirstChild("HumanoidRootPart")
        end)
        PlayerESP.cache.boxes[m] = entry
    end

    -- Main Render Loop
    local PESP_INTERVAL = 1 / 90
    local pespLastTick  = 0

    AddConnection(RunService.Heartbeat:Connect(function()
        local now = tick()
        if now - pespLastTick < PESP_INTERVAL then return end
        pespLastTick = now

        local camPos = cam.CFrame.Position
        local s      = PlayerESP.settings

        for m, d in next, PlayerESP.cache.boxes do
            local function hide()
                PESP_HideCorners(d.corners, d.cFill)
                PESP_HideDefault(d.default)
                if d.nameText.Visible then d.nameText.Visible = false end
                if d.distText.Visible then d.distText.Visible = false end
                if d.weapText.Visible then d.weapText.Visible = false end
            end

            if not m or not m.Parent then
                hide(); PESP_DestroyEntry(m, d); continue
            end
            if not s.enabled then hide(); PESP_UpdateChams(m, false); continue end

            local hrp = d.hrp
            if not hrp or not hrp.Parent then
                d.hrp = m:FindFirstChild("HumanoidRootPart")
                hide(); continue
            end

            local hrpPos = hrp.Position
            local dx = hrpPos.X - camPos.X
            local dy = hrpPos.Y - camPos.Y
            local dz = hrpPos.Z - camPos.Z
            local distSq = dx*dx + dy*dy + dz*dz
            local rd = s.renderDistance
            if distSq > rd*rd then
                hide(); PESP_UpdateChams(m, false); continue
            end

            if PESP_ShouldSkip(m) then hide(); PESP_UpdateChams(m, false); continue end

            if now - d.lastCache > 5 then
                d.isPlayer  = PESP_IsPlayer(m)
                d.isSleeper = PESP_IsSleeper(m)
                d.lastCache = now
            end

            local topPos, topVis = cam:WorldToViewportPoint(hrpPos + PlayerESP.const.V3_UP)
            local botPos         = cam:WorldToViewportPoint(hrpPos - PlayerESP.const.V3_DN)

            if not topVis then
                hide(); PESP_UpdateChams(m, true); continue
            end

            local h = botPos.Y - topPos.Y
            if h < 5 then hide(); continue end

            local w  = h * 0.65
            local px = topPos.X
            local py = topPos.Y + h * 0.5
            local dist = math.floor(math.sqrt(distSq))

            if s.boxEnabled then
                if s.boxType == "Corner" then
                    PESP_HideDefault(d.default)
                    PESP_UpdateCorners(d.corners, d.cFill, d.cGrad, px, py, w, h)
                else
                    PESP_HideCorners(d.corners, d.cFill)
                    PESP_UpdateDefaultBox(d.default, px, py, w, h)
                end
            else
                PESP_HideCorners(d.corners, d.cFill)
                PESP_HideDefault(d.default)
            end

            local dtype = d.isSleeper and "Sleeper" or (d.isPlayer and "Player" or "Bot")

            if s.nameEnabled then
                d.nameText.Text         = dtype
                d.nameText.Position     = Vector2.new(px, py - h*0.5 - 16)
                d.nameText.Color        = s.nameColor
                d.nameText.Outline      = s.nameOutline
                d.nameText.OutlineColor = s.nameOutlineColor
                d.nameText.Visible      = true
            else
                if d.nameText.Visible then d.nameText.Visible = false end
            end

            if s.distanceEnabled then
                d.distText.Text         = "[" .. dist .. "m]"
                d.distText.Position     = Vector2.new(px, py + h*0.5 + 4)
                d.distText.Color        = s.distColor
                d.distText.Outline      = s.distOutline
                d.distText.OutlineColor = s.distOutlineColor
                d.distText.Visible      = true
            else
                if d.distText.Visible then d.distText.Visible = false end
            end

            if s.weaponEnabled then
                d.weapText.Text         = PESP_DetectWeapon(m)
                d.weapText.Position     = Vector2.new(px, py + h*0.5 + (s.distanceEnabled and 18 or 4))
                d.weapText.Color        = s.weapColor
                d.weapText.Outline      = s.weapOutline
                d.weapText.OutlineColor = s.weapOutlineColor
                d.weapText.Visible      = true
            else
                if d.weapText.Visible then d.weapText.Visible = false end
            end

            PESP_UpdateChams(m, true)
        end
    end))

    -- Event Handlers
    workspace.DescendantAdded:Connect(function(obj)
        if obj:IsA("Model") then
            task.wait(0.1)
            if obj:FindFirstChild("HumanoidRootPart") and not PlayerESP.cache.boxes[obj] then
                PESP_CreateEntry(obj)
            end
        elseif obj.Name == "HandModel" and obj.Parent then
            PlayerESP.cache.weapon[obj.Parent]     = nil
            PlayerESP.cache.weaponTime[obj.Parent] = nil
        end
    end)

    workspace.DescendantRemoving:Connect(function(obj)
        if obj:IsA("Model") then
            local d = PlayerESP.cache.boxes[obj]
            if d then PESP_DestroyEntry(obj, d) end
            local ch = PlayerESP.cache.chams[obj]
            if ch then
                pcall(function() ch:Destroy() end)
                PlayerESP.cache.chams[obj] = nil
            end
            PlayerESP.cache.weapon[obj]     = nil
            PlayerESP.cache.weaponTime[obj] = nil
            PlayerESP.cache.player[obj]     = nil
            PlayerESP.cache.sleep[obj]      = nil
        elseif obj.Name == "HandModel" and obj.Parent then
            PlayerESP.cache.weapon[obj.Parent]     = nil
            PlayerESP.cache.weaponTime[obj.Parent] = nil
        end
    end)

    -- Cleanup Task
    task.spawn(function()
        while true do
            task.wait(15)
            for m in next, PlayerESP.cache.weapon do
                if not m or not m.Parent then
                    PlayerESP.cache.weapon[m] = nil
                    PlayerESP.cache.weaponTime[m] = nil
                end
            end
            for m in next, PlayerESP.cache.sleep do
                if not m or not m.Parent then PlayerESP.cache.sleep[m] = nil end
            end
            for m in next, PlayerESP.cache.player do
                if not m or not m.Parent then PlayerESP.cache.player[m] = nil end
            end
            for m, d in next, PlayerESP.cache.boxes do
                if not m or not m.Parent then PESP_DestroyEntry(m, d) end
            end
            for m, c in next, PlayerESP.cache.chams do
                if not m or not m.Parent then
                    pcall(function() c:Destroy() end)
                    PlayerESP.cache.chams[m] = nil
                end
            end
        end
    end)

    -- Initialize existing models
    for _, m in next, workspace:GetChildren() do
        if m:IsA("Model") then
            task.spawn(function()
                task.wait(0.1)
                if m:FindFirstChild("HumanoidRootPart") then PESP_CreateEntry(m) end
            end)
        end
    end

    -- UI Setup
    ESPSection:AddToggle("EnableEsp", {
        Text = "Enable ESP", Default = false,
        Callback = function(v) PlayerESP.settings.enabled = v end
    })
    ESPSection:AddToggle("SleepCheck", {
        Text = "Sleep Check", Default = false,
        Callback = function(v) PlayerESP.settings.sleepCheck = v end
    })
    ESPSection:AddToggle("AICheck", {
        Text = "AI Check", Default = false,
        Callback = function(v) PlayerESP.settings.aiCheck = v end
    })
    ESPSection:AddToggle("TeamCheck", {
        Text = "Team Check", Default = false,
        Callback = function(v) PlayerESP.settings.teamCheck = v end
    })
    ESPSection:AddSlider("RenderDistance", {
        Text = "Render Distance", Default = 1000, Min = 500, Max = 1500, Rounding = 0, Suffix = "st",
        Callback = function(v) PlayerESP.settings.renderDistance = v end
    })
    local boxToggle = ESPSection:AddToggle("EnableBox", {
        Text = "Enable Box", Default = false,
        Callback = function(v) PlayerESP.settings.boxEnabled = v end
    })
    boxToggle:AddColorPicker("BoxColor", {
        Title = "Box Color", Default = Color3.fromRGB(0, 120, 255),
        Callback = function(v) PlayerESP.settings.boxColor = v end
    })
    ESPSection:AddDropdown("BoxType", {
        Values = {"Corner","Default"}, Default = 1, Multi = false, Text = "Box Type",
        Callback = function(v) PlayerESP.settings.boxType = v end
    })
    local outlineToggle = ESPSection:AddToggle("BoxOutline", {
        Text = "Box Outline", Default = true,
        Callback = function(v) PlayerESP.settings.boxOutline = v end
    })
    outlineToggle:AddColorPicker("OutlineColor", {
        Title = "Outline Color", Default = Color3.fromRGB(20, 20, 20),
        Callback = function(v) PlayerESP.settings.outlineColor = v end
    })
    local fillToggle = ESPSection:AddToggle("BoxFill", {
        Text = "Box Fill", Default = false,
        Callback = function(v) PlayerESP.settings.boxFill = v end
    })
    fillToggle:AddColorPicker("FillColor1", {
        Title = "Fill Color 1", Default = Color3.fromRGB(0, 120, 255),
        Callback = function(v) PlayerESP.settings.fillColor = v end
    })
    fillToggle:AddColorPicker("FillColor2", {
        Title = "Fill Color 2", Default = Color3.fromRGB(0, 30, 80),
        Callback = function(v) PlayerESP.settings.fillColor2 = v end
    })
    ESPSection:AddSlider("FillTransparency", {
        Text = "Fill Transparency", Default = 0.75, Min = 0, Max = 1, Rounding = 2, Suffix = "%",
        Callback = function(v) PlayerESP.settings.fillTransparency = v end
    })
    local nameToggle = ESPSection:AddToggle("EnableName", {
        Text = "Name", Default = false,
        Callback = function(v) PlayerESP.settings.nameEnabled = v end
    })
    nameToggle:AddColorPicker("NameColor", {
        Title = "Name Color", Default = Color3.fromRGB(0, 120, 255),
        Callback = function(v) PlayerESP.settings.nameColor = v end
    })
    local nameOutlineToggle = ESPSection:AddToggle("NameOutline", {
        Text = "Name Outline", Default = true,
        Callback = function(v) PlayerESP.settings.nameOutline = v end
    })
    nameOutlineToggle:AddColorPicker("NameOutlineColor", {
        Title = "Name Outline Color", Default = Color3.fromRGB(20, 20, 20),
        Callback = function(v) PlayerESP.settings.nameOutlineColor = v end
    })
    local distToggle = ESPSection:AddToggle("EnableDist", {
        Text = "Distance", Default = false,
        Callback = function(v) PlayerESP.settings.distanceEnabled = v end
    })
    distToggle:AddColorPicker("DistColor", {
        Title = "Distance Color", Default = Color3.fromRGB(0, 120, 255),
        Callback = function(v) PlayerESP.settings.distColor = v end
    })
    local distOutlineToggle = ESPSection:AddToggle("DistOutline", {
        Text = "Distance Outline", Default = true,
        Callback = function(v) PlayerESP.settings.distOutline = v end
    })
    distOutlineToggle:AddColorPicker("DistOutlineColor", {
        Title = "Distance Outline Color", Default = Color3.fromRGB(20, 20, 20),
        Callback = function(v) PlayerESP.settings.distOutlineColor = v end
    })
    local weapToggle = ESPSection:AddToggle("EnableWeapon", {
        Text = "Weapon", Default = false,
        Callback = function(v) PlayerESP.settings.weaponEnabled = v end
    })
    weapToggle:AddColorPicker("WeapColor", {
        Title = "Weapon Color", Default = Color3.fromRGB(0, 120, 255),
        Callback = function(v) PlayerESP.settings.weapColor = v end
    })
    local weapOutlineToggle = ESPSection:AddToggle("WeapOutline", {
        Text = "Weapon Outline", Default = true,
        Callback = function(v) PlayerESP.settings.weapOutline = v end
    })
    weapOutlineToggle:AddColorPicker("WeapOutlineColor", {
        Title = "Weapon Outline Color", Default = Color3.fromRGB(20, 20, 20),
        Callback = function(v) PlayerESP.settings.weapOutlineColor = v end
    })
    local chamsToggle = ESPSection:AddToggle("EnableChams", {
        Text = "Chams", Default = false,
        Callback = function(v)
            PlayerESP.settings.chamsEnabled = v
            if not v then
                for _, c in next, PlayerESP.cache.chams do
                    if c.Enabled then c.Enabled = false end
                end
            end
        end
    })
    chamsToggle:AddColorPicker("ChamsColor", {
        Title = "Chams Color", Default = Color3.fromRGB(0, 120, 255),
        Callback = function(v)
            PlayerESP.settings.chamsColor = v
            for _, c in next, PlayerESP.cache.chams do
                if c.Enabled then c.FillColor = v end
            end
        end
    })

    -- ===============================================
    -- CORPSE ESP SYSTEM
    -- ===============================================
    local CorpseESP = {
        enabled     = false,
        maxDistance = 750,
        textSize    = 10,
        color       = Color3.fromRGB(255, 0, 0),
        ESP         = {},
        Cache       = setmetatable({}, {__mode = "k"}),
    }

    local function isCorpse(m)
        local cached = CorpseESP.Cache[m]
        if cached ~= nil then return cached end
        local count, mat1, mat2 = 0, nil, nil
        for _, c in ipairs(m:GetChildren()) do
            if c:IsA("BasePart") then
                count = count + 1
                if     count == 1 then mat1 = c.Material
                elseif count == 2 then mat2 = c.Material
                else CorpseESP.Cache[m] = false; return false end
            end
        end
        if count ~= 2 then CorpseESP.Cache[m] = false; return false end
        local v = (mat1 == Enum.Material.Fabric and mat2 == Enum.Material.Metal) or
                  (mat1 == Enum.Material.Metal   and mat2 == Enum.Material.Fabric)
        CorpseESP.Cache[m] = v
        return v
    end

    local function addCorpse(m)
        if CorpseESP.ESP[m] then return end
        if not isCorpse(m) then return end
        local tx = Drawing.new("Text")
        tx.Text = "Corpse"; tx.Size = CorpseESP.textSize; tx.Center = true
        tx.Outline = true; tx.OutlineColor = Color3.new(0,0,0)
        tx.Color = CorpseESP.color; tx.Visible = false
        CorpseESP.ESP[m] = {Text = tx, Part = m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart")}
    end

    local function removeCorpse(m)
        local d = CorpseESP.ESP[m]
        if not d then return end
        if d.Text then d.Text:Remove() end
        CorpseESP.ESP[m] = nil; CorpseESP.Cache[m] = nil
    end

    local function scanCorpses()
        for _, m in ipairs(workspace:GetChildren()) do
            if m:IsA("Model") and not CorpseESP.ESP[m] then addCorpse(m) end
        end
    end

    task.spawn(scanCorpses)
    workspace.ChildAdded:Connect(function(m) if not m:IsA("Model") then return end; task.wait(); addCorpse(m) end)
    workspace.ChildRemoved:Connect(removeCorpse)
    task.spawn(function()
        while true do
            task.wait(3)
            scanCorpses()
            for m in pairs(CorpseESP.Cache) do
                if not m or not m.Parent then CorpseESP.Cache[m] = nil end
            end
        end
    end)

    -- Corpse ESP UI
    ESPSection:AddDivider()
    ESPSection:AddToggle("CorpseESP_Enable", {
        Text = "Corpse ESP", Default = false,
        Callback = function(v)
            CorpseESP.enabled = v
            if not v then for _, d in pairs(CorpseESP.ESP) do if d.Text then d.Text.Visible = false end end end
        end
    }):AddColorPicker("CorpseESP_Color", {
        Title = "Corpse Color", Default = Color3.fromRGB(255, 0, 0),
        Callback = function(c)
            CorpseESP.color = c
            for _, d in pairs(CorpseESP.ESP) do if d.Text then d.Text.Color = c end end
        end
    })
    ESPSection:AddSlider("CorpseESP_Dist", {
        Text = "Corpse Max Distance", Default = 750, Min = 250, Max = 1250, Rounding = 0,
        Callback = function(v) CorpseESP.maxDistance = v end
    })
    ESPSection:AddSlider("CorpseESP_TextSize", {
        Text = "Corpse Text Size", Default = 10, Min = 8, Max = 16, Rounding = 0,
        Callback = function(v)
            CorpseESP.textSize = v
            for _, d in pairs(CorpseESP.ESP) do if d.Text then d.Text.Size = v end end
        end
    })

    -- ===============================================
    -- LOOT ESP SYSTEM WITH BOX
    -- ===============================================
    local LootESP = {
        enabled     = false,
        maxDistance = 750,
        cache       = setmetatable({}, {__mode = "k"}),
        data        = setmetatable({}, {__mode = "k"}),

        Bucket   = { boxColor = Color3.fromRGB(255, 165, 0),   label = "Bucket",       enabled = false },
        Box      = { boxColor = Color3.fromRGB(230, 182, 0),   label = "DefaultBox",   enabled = false },
        Chest    = { boxColor = Color3.fromRGB(150, 150, 150), label = "GrayBox",      enabled = false },
        Crafting = { boxColor = Color3.fromRGB(255, 0, 207),   label = "HealtMachine", enabled = false },
        Crate    = { boxColor = Color3.fromRGB(44, 97, 0),     label = "GreenCrate",   enabled = false },
        Vault    = { boxColor = Color3.fromRGB(100, 100, 100), label = "Safe",         enabled = false },
        Gas      = { boxColor = Color3.fromRGB(200, 0, 0),     label = "Gasoline",     enabled = false },
    }

    local lootTypes = {"Bucket","Box","Chest","Crafting","Crate","Vault","Gas"}

    local function isSalvage(model)
        local cached = LootESP.cache[model]
        if cached ~= nil then return cached end
        if not model:IsA("Model") then LootESP.cache[model] = false; return false end

        if model:FindFirstChild("default") then
            local n = 0
            for _, c in ipairs(model:GetChildren()) do
                if c:IsA("BasePart") and c.Name == "Part" then n = n + 1 end
            end
            if n >= 10 then LootESP.cache[model] = "Bucket"; return "Bucket" end
        end

        local boxM  = model:FindFirstChild("box")
        local trash = model:FindFirstChild("trash")
        if boxM and boxM:IsA("MeshPart") and trash and trash:IsA("MeshPart") then
            LootESP.cache[model] = "Box"; return "Box"
        end

        local bodyM = model:FindFirstChild("Body")
        local defP  = model:FindFirstChild("default")
        if bodyM and bodyM:IsA("MeshPart") and defP and defP:IsA("BasePart") then
            LootESP.cache[model] = "Chest"; return "Chest"
        end

        if model:FindFirstChild("Dispenser") and model:FindFirstChild("Machine") and model:FindFirstChild("Sign") then
            LootESP.cache[model] = "Crafting"; return "Crafting"
        end

        if model:FindFirstChild("Bottom") and model:FindFirstChild("Handles") and model:FindFirstChild("Top") then
            LootESP.cache[model] = "Crate"; return "Crate"
        end

        if model:FindFirstChild("Body") and model:FindFirstChild("Bolts") and
           model:FindFirstChild("Dials") and model:FindFirstChild("Hinge") and
           model:FindFirstChild("Pins") and model:FindFirstChild("Wheel") then
            LootESP.cache[model] = "Vault"; return "Vault"
        end

        local prim = model:FindFirstChild("Prim")
        if prim and prim:FindFirstChildWhichIsA("SpecialMesh") then
            LootESP.cache[model] = "Gas"; return "Gas"
        end

        LootESP.cache[model] = false
        return false
    end

    local function createLootESP(model)
        if LootESP.data[model] then return end
        local kind = isSalvage(model)
        if not kind then return end
        local s = LootESP[kind]
        if not s then return end
        local anchor = model:FindFirstChildWhichIsA("BasePart")
        if not anchor then return end

        -- Box frame
        local box = Drawing.new("Square")
        box.Visible = false
        box.Filled = false
        box.Thickness = 2
        box.Color = s.boxColor
        box.Transparency = 1

        -- Name text (top)
        local nameText = Drawing.new("Text")
        nameText.Text = s.label
        nameText.Size = 13
        nameText.Center = true
        nameText.Font = 2
        nameText.Outline = true
        nameText.OutlineColor = Color3.new(0,0,0)
        nameText.Color = s.boxColor
        nameText.Visible = false

        -- Distance text (bottom)
        local distText = Drawing.new("Text")
        distText.Text = "[0m]"
        distText.Size = 12
        distText.Center = true
        distText.Font = 2
        distText.Outline = true
        distText.OutlineColor = Color3.new(0,0,0)
        distText.Color = s.boxColor
        distText.Visible = false

        local conn = model.AncestryChanged:Connect(function()
            if not model.Parent then
                box:Remove()
                nameText:Remove()
                distText:Remove()
                LootESP.data[model]  = nil
                LootESP.cache[model] = nil
            end
        end)

        LootESP.data[model] = {box = box, nameText = nameText, distText = distText, anchor = anchor, conn = conn, kind = kind}
    end

    local function removeLootESP(model)
        local d = LootESP.data[model]
        if not d then return end
        d.conn:Disconnect()
        if d.box then d.box:Remove() end
        if d.nameText then d.nameText:Remove() end
        if d.distText then d.distText:Remove() end
        LootESP.data[model]  = nil
        LootESP.cache[model] = nil
    end

    for _, m in ipairs(workspace:GetChildren()) do task.spawn(createLootESP, m) end
    workspace.ChildAdded:Connect(function(m) task.spawn(createLootESP, m) end)
    workspace.ChildRemoved:Connect(removeLootESP)

    -- Loot ESP UI
    ESPSection:AddDivider()
    ESPSection:AddToggle("LootESP_Master", {
        Text = "Enable Loot ESP", Default = false,
        Callback = function(v)
            LootESP.enabled = v
            if not v then
                for _, d in pairs(LootESP.data) do
                    if d.box then d.box.Visible = false end
                    if d.nameText then d.nameText.Visible = false end
                    if d.distText then d.distText.Visible = false end
                end
            end
        end
    })
    ESPSection:AddSlider("LootESP_MaxDist", {
        Text = "Loot Max Distance", Default = 750, Min = 250, Max = 1250, Rounding = 0,
        Callback = function(v) LootESP.maxDistance = v end
    })

    for _, key in ipairs(lootTypes) do
        local toggle = ESPSection:AddToggle("LootESP_"..key, {
            Text = LootESP[key].label, Default = false,
            Callback = function(v) LootESP[key].enabled = v end
        })
        toggle:AddColorPicker("LootESP_"..key.."Color", {
            Title = LootESP[key].label, Default = LootESP[key].boxColor,
            Callback = function(c)
                LootESP[key].boxColor = c
                for _, d in pairs(LootESP.data) do
                    if d and d.kind == key then
                        if d.box then d.box.Color = c end
                        if d.nameText then d.nameText.Color = c end
                        if d.distText then d.distText.Color = c end
                    end
                end
            end
        })
    end

    -- ===============================================
    -- CORPSE & LOOT ESP RENDER LOOP
    -- ===============================================
    local ESP_INTERVAL = 1 / 60
    local espLastTick  = 0

    AddConnection(RunService.Heartbeat:Connect(function()
        local now = tick()
        if now - espLastTick < ESP_INTERVAL then return end
        espLastTick = now

        local camPos = cam.CFrame.Position
        local vp     = cam.ViewportSize

        -- Corpse ESP Rendering
        if CorpseESP.enabled then
            local maxDSq = CorpseESP.maxDistance * CorpseESP.maxDistance
            for m, d in pairs(CorpseESP.ESP) do
                local p = d.Part
                if p and p.Parent then
                    local diff = p.Position - camPos
                    if diff.X*diff.X + diff.Y*diff.Y + diff.Z*diff.Z <= maxDSq then
                        local sp, on = cam:WorldToViewportPoint(p.Position)
                        if on then
                            d.Text.Position = Vector2.new(sp.X, sp.Y - 20)
                            d.Text.Visible  = true
                        else
                            d.Text.Visible = false
                        end
                    else
                        d.Text.Visible = false
                    end
                else
                    removeCorpse(m)
                end
            end
        else
            for _, d in pairs(CorpseESP.ESP) do if d.Text then d.Text.Visible = false end end
        end

        -- Loot ESP Rendering with Box
        if LootESP.enabled then
            local maxDSq = LootESP.maxDistance * LootESP.maxDistance
            for model, d in pairs(LootESP.data) do
                if not model or not model.Parent or not d.anchor or not d.anchor.Parent then
                    removeLootESP(model)
                    continue
                end

                local s = LootESP[d.kind]
                if not s or not s.enabled then
                    if d.box then d.box.Visible = false end
                    if d.nameText then d.nameText.Visible = false end
                    if d.distText then d.distText.Visible = false end
                    continue
                end

                local anchorPos = d.anchor.Position
                local diff = anchorPos - camPos
                local distSq = diff.X*diff.X + diff.Y*diff.Y + diff.Z*diff.Z

                if distSq <= maxDSq then
                    local sp, on = cam:WorldToViewportPoint(anchorPos)
                    if on then
                        local dist = math.floor(math.sqrt(distSq))

                        -- Calculate box size based on distance
                        local boxSize = math.clamp(3000 / dist, 30, 80)
                        local halfSize = boxSize / 2

                        -- Draw box
                        d.box.Size = Vector2.new(boxSize, boxSize)
                        d.box.Position = Vector2.new(sp.X - halfSize, sp.Y - halfSize)
                        d.box.Color = s.boxColor
                        d.box.Visible = true

                        -- Draw name text (top)
                        d.nameText.Text = s.label
                        d.nameText.Position = Vector2.new(sp.X, sp.Y - halfSize - 15)
                        d.nameText.Color = s.boxColor
                        d.nameText.Visible = true

                        -- Draw distance text (bottom)
                        d.distText.Text = "[" .. dist .. "m]"
                        d.distText.Position = Vector2.new(sp.X, sp.Y + halfSize + 5)
                        d.distText.Color = s.boxColor
                        d.distText.Visible = true
                    else
                        d.box.Visible = false
                        d.nameText.Visible = false
                        d.distText.Visible = false
                    end
                else
                    d.box.Visible = false
                    d.nameText.Visible = false
                    d.distText.Visible = false
                end
            end
        else
            for _, d in pairs(LootESP.data) do
                if d.box then d.box.Visible = false end
                if d.nameText then d.nameText.Visible = false end
                if d.distText then d.distText.Visible = false end
            end
        end
    end))

    return {PlayerESP = PlayerESP, CorpseESP = CorpseESP, LootESP = LootESP}
end

return module
