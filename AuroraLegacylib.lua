--[[
    Aurora Legacy UI Library
    -----------------------------------------------------------------
    Visual clone of the "Aurora Legacy | Trident Survival | Full Version"
    cheat menu.

    Loader:
        local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/denplanewalker/libraries/refs/heads/main/AuroraLegacylib.lua"))()

    Quick example:
        local Window = Library:Window({
            Name = "Aurora Legacy | Trident Survival | Full Version",
            Size = UDim2.fromOffset(820, 540),
        })
        local Misc = Window:Page({ Name = "Misc", Columns = 3 })
        local Cam  = Misc:Section({ Name = "Camera", Side = 1 })
        Cam:Toggle({ Name = "Fov Changer", Flag = "fov_t", Default = false,
                     Callback = function(v) print("fov", v) end })
        Cam:Slider({ Name = "Ammount", Min = 0, Max = 150, Default = 80,
                     Suffix = "/150", Flag = "fov_v" })
        Library:KeybindList()

    Documentation (mirrors HELLSHADE):
        Library:Window(Data)        -> Window
        Window:Page(Data)           -> Page
        Page:Section(Data)          -> Section
        Section:Toggle(Data)        -> Toggle  (Toggle:Keybind / Toggle:Colorpicker)
        Section:Button(Data)        -> Button  (Button:SubButton)
        Section:Slider(Data)        -> Slider
        Section:Dropdown(Data)      -> Dropdown
        Section:Label(Text, Align)  -> Label   (Label:Keybind / Label:Colorpicker)
        Section:Textbox(Data)       -> Textbox
        Library:Notification(text, dur, color)
        Library:Watermark(text)
        Library:KeybindList()
        Library:Unload()
]]

if getgenv and getgenv().AuroraLegacy then
    pcall(function() getgenv().AuroraLegacy:Unload() end)
end

local Library do
    local UserInputService = game:GetService("UserInputService")
    local TweenService     = game:GetService("TweenService")
    local RunService       = game:GetService("RunService")
    local Players          = game:GetService("Players")
    local HttpService      = game:GetService("HttpService")
    local CoreGui          = (cloneref and cloneref(game:GetService("CoreGui"))) or game:GetService("CoreGui")

    local gethui_fn = gethui or function() return CoreGui end

    local LocalPlayer = Players.LocalPlayer
    local Mouse       = LocalPlayer:GetMouse()

    local FromRGB     = Color3.fromRGB
    local UDim2New    = UDim2.new
    local UDimNew     = UDim.new
    local Vector2New  = Vector2.new
    local InstanceNew = Instance.new

    local MathClamp = math.clamp
    local MathFloor = math.floor
    local TblInsert = table.insert
    local TblFind   = table.find
    local TblRemove = table.remove
    local TblConcat = table.concat
    local StrFormat = string.format
    local StrFind   = string.find
    local StrGsub   = string.gsub

    Library = {
        Flags        = {},
        SetFlags     = {},
        Connections  = {},
        Threads      = {},

        MenuKeybind  = "RightShift",

        Theme = {
            Background  = FromRGB(8,    8,    8),   -- #080808
            Inline      = FromRGB(18,   18,   22),  -- #121216
            Border      = FromRGB(148,  96,   200), -- #9460C8 (Accent)
            Outline     = FromRGB(6,    6,    6),   -- #060606
            Accent      = FromRGB(148,  96,   200), -- #9460C8
            AccentDim   = FromRGB(120,  70,   170), -- dimmed accent
            Text        = FromRGB(215,  215,  215), -- #D7D7D7
            TextDim     = FromRGB(143,  143,  143), -- #8F8F8F
            Element     = FromRGB(30,   30,   38),  -- #1E1E26
            Risky       = FromRGB(255,  70,   70),
            Divider     = FromRGB(148,  96,   200), -- #9460C8
            SliderBg    = FromRGB(42,   42,   52),  -- #2A2A34
        },

        Holder       = nil,
        Font         = Enum.Font.Gotham,
        FontBold     = Enum.Font.GothamBold,
        KeyList      = nil,

        UnnamedFlags = 0,
    }
    Library.__index         = Library
    Library.Pages           = {}; Library.Pages.__index    = Library.Pages
    Library.Sections        = {}; Library.Sections.__index = Library.Sections

    ----------------------------------------------------------------
    -- Helpers
    ----------------------------------------------------------------
    local function new(class, props, children)
        local inst = InstanceNew(class)
        if props then
            for k, v in pairs(props) do inst[k] = v end
        end
        if children then
            for _, c in ipairs(children) do c.Parent = inst end
        end
        return inst
    end

    -- corner() is intentionally a no-op: this UI uses sharp edges only.
    local function corner(_) return InstanceNew("Folder") end
    local function stroke(c, t, a)
        return new("UIStroke", {
            Color = c or Library.Theme.Border, Thickness = t or 1,
            Transparency = a or 0,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        })
    end

    function Library:NextFlag()
        self.UnnamedFlags = self.UnnamedFlags + 1
        return StrFormat("AuroraFlag_%d", self.UnnamedFlags)
    end

    function Library:SafeCall(fn, ...)
        if not fn then return end
        local args = { ... }
        local ok, err = pcall(function() fn(unpack(args)) end)
        if not ok then warn("[Aurora Legacy] callback error:", err) end
    end

    function Library:Thread(fn)
        local th = coroutine.create(fn)
        coroutine.resume(th)
        TblInsert(self.Threads, th)
        return th
    end

    function Library:Connect(event, cb)
        local c = event:Connect(cb)
        TblInsert(self.Connections, c)
        return c
    end

    function Library:Tween(item, info, goal)
        info = info or TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        local t = TweenService:Create(item, info, goal)
        t:Play()
        return t
    end

    function Library:IsMouseOver(frame)
        if not frame then return false end
        local p, s = frame.AbsolutePosition, frame.AbsoluteSize
        return Mouse.X >= p.X and Mouse.X <= p.X + s.X
           and Mouse.Y >= p.Y and Mouse.Y <= p.Y + s.Y
    end

    function Library:MakeDraggable(gui, handle)
        handle = handle or gui
        local dragging, dragStart, startPos
        handle.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1
            or i.UserInputType == Enum.UserInputType.Touch then
                dragging, dragStart, startPos = true, i.Position, gui.Position
            end
        end)
        handle.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1
            or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
        end)
        self:Connect(UserInputService.InputChanged, function(i)
            if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement
                          or i.UserInputType == Enum.UserInputType.Touch) then
                local d = i.Position - dragStart
                gui.Position = UDim2New(startPos.X.Scale, startPos.X.Offset + d.X,
                                        startPos.Y.Scale, startPos.Y.Offset + d.Y)
            end
        end)
    end

    function Library:Unload()
        for _, c in ipairs(self.Connections) do pcall(function() c:Disconnect() end) end
        for _, t in ipairs(self.Threads)     do pcall(function() coroutine.close(t) end) end
        UserInputService.MouseIconEnabled = true
        if self.Holder   then pcall(function() self.Holder:Destroy()   end) end
        if CursorGui     then pcall(function() CursorGui:Destroy()     end) end
        if getgenv then getgenv().AuroraLegacy = nil end
    end

    ----------------------------------------------------------------
    -- Root ScreenGui
    ----------------------------------------------------------------
    Library.Holder = new("ScreenGui", {
        Name             = "AuroraLegacy",
        ZIndexBehavior   = Enum.ZIndexBehavior.Sibling,
        IgnoreGuiInset   = true,
        DisplayOrder     = 1000,
        ResetOnSpawn     = false,
        Parent           = gethui_fn(),
    })

    ----------------------------------------------------------------
    -- Custom cursor
    --   Replicates the Sirex.cc cursor: three rotated lines forming
    --   a triangular cursor. Lives on its own ScreenGui with
    --   DisplayOrder=9999, fully non-interactive.
    ----------------------------------------------------------------
    local CursorGui = new("ScreenGui", {
        Name                   = "AuroraLegacyCursor",
        IgnoreGuiInset         = true,
        DisplayOrder           = 9999,
        ResetOnSpawn           = false,
        Parent                 = gethui_fn(),
    })
    
    -- Three lines forming a cursor triangle (like Sirex.cc)
    local CursorLine1 = new("Frame", {
        Parent                 = CursorGui,
        Active                 = false,
        Size                   = UDim2New(0, 28, 0, 2),
        BackgroundColor3       = Library.Theme.Accent,
        BorderSizePixel        = 0,
        Rotation               = 135,
        Visible                = false,
    })
    local CursorLine2 = new("Frame", {
        Parent                 = CursorGui,
        Active                 = false,
        Size                   = UDim2New(0, 14, 0, 2),
        BackgroundColor3       = Library.Theme.Accent,
        BorderSizePixel        = 0,
        Rotation               = -110.556,
        Visible                = false,
    })
    local CursorLine3 = new("Frame", {
        Parent                 = CursorGui,
        Active                 = false,
        Size                   = UDim2New(0, 14, 0, 2),
        BackgroundColor3       = Library.Theme.Accent,
        BorderSizePixel        = 0,
        Rotation               = 21.5,
        Visible                = false,
    })
    
    local cursorConn
    local function followCursor()
        if cursorConn then return end
        cursorConn = Library:Connect(RunService.RenderStepped, function()
            local pos = UserInputService:GetMouseLocation()
            -- Center the cursor on mouse position
            -- Line1 is the main shaft (28px), lines 2&3 are the arrow head
            CursorLine1.Position = UDim2New(0, pos.X - 14, 0, pos.Y - 1)
            CursorLine2.Position = UDim2New(0, pos.X - 7, 0, pos.Y - 1)
            CursorLine3.Position = UDim2New(0, pos.X - 7, 0, pos.Y - 1)
        end)
    end
    local function unfollowCursor()
        if cursorConn then
            cursorConn:Disconnect()
            cursorConn = nil
        end
    end
    local function setCursorVisible(b)
        CursorLine1.Visible = b
        CursorLine2.Visible = b
        CursorLine3.Visible = b
        UserInputService.MouseIconEnabled = not b
    end
    function Library:SetCursor(b)
        setCursorVisible(b and true or false)
        if b then followCursor() else unfollowCursor() end
    end

    ----------------------------------------------------------------
    -- Notifications (top-center)
    ----------------------------------------------------------------
    local NotifHolder = new("Frame", {
        Parent                 = Library.Holder,
        AnchorPoint            = Vector2New(0.5, 0),
        Position               = UDim2New(0.5, 0, 0, 14),
        Size                   = UDim2New(0, 320, 1, -14),
        BackgroundTransparency = 1,
    })
    new("UIListLayout", {
        Parent              = NotifHolder,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        SortOrder           = Enum.SortOrder.LayoutOrder,
        Padding             = UDimNew(0, 6),
    })

    function Library:Notification(text, duration, color)
        duration = duration or 4
        color    = color or self.Theme.Accent

        local n = new("Frame", {
            Parent           = NotifHolder,
            Size             = UDim2New(0, 280, 0, 28),
            BackgroundColor3 = self.Theme.Inline,
            BorderSizePixel  = 0,
        })
        corner(4).Parent = n
        stroke(self.Theme.Border, 1, 0.3).Parent = n

        new("Frame", {
            Parent           = n,
            Size             = UDim2New(0, 3, 1, 0),
            BackgroundColor3 = color,
            BorderSizePixel  = 0,
        })
        new("TextLabel", {
            Parent                 = n,
            Position               = UDim2New(0, 10, 0, 0),
            Size                   = UDim2New(1, -14, 1, 0),
            BackgroundTransparency = 1,
            Font                   = self.Font,
            TextSize               = 12,
            Text                   = tostring(text),
            TextColor3             = self.Theme.Text,
            TextXAlignment         = Enum.TextXAlignment.Left,
        })

        task.delay(duration, function()
            self:Tween(n, TweenInfo.new(0.25), { BackgroundTransparency = 1 })
            task.wait(0.3); n:Destroy()
        end)
    end

    ----------------------------------------------------------------
    -- Watermark
    --   Library:Watermark("text")                       -- single static line
    --   Library:Watermark({ "Sirex.cc", "Full",
    --                       "%user%", "%fps%", "%ping%", "%time%" })
    -- Supported live tokens (replaced every frame):
    --   %user%   LocalPlayer.Name
    --   %disp%   LocalPlayer.DisplayName
    --   %fps%    smoothed frames-per-second
    --   %ping%   network ping in ms
    --   %time%   HH:MM (24h, local clock)
    --   %date%   YYYY-MM-DD
    --
    --   Watermark width is fixed (no auto-resize). Default widths
    --   for the standard 6 fields fit the layout in the screenshot.
    --   Pass a `widths` table to override, e.g.
    --       Library:Watermark({...}, {70, 30, 110, 60, 60, 40})
    --   Color format (matches Sirex.cc):
    --   Field 1: Accent color (#9460C8) - "Sirex.cc"
    --   Separators: Dark gray (#060606) - "〡"
    --   Other fields: Light gray (#D7D7D7)
    ----------------------------------------------------------------
    local WATERMARK_DEFAULTS = { 70, 30, 100, 56, 56, 38 }
    local WATERMARK_SEP_W    = 14
    local WATERMARK_PAD      = 8

    function Library:Watermark(text, widths)
        local fields
        if type(text) == "table" then fields = text else fields = { tostring(text) } end

        -- compute fixed total width
        local totalW = WATERMARK_PAD * 2
        for i = 1, #fields do
            local w = (widths and widths[i]) or WATERMARK_DEFAULTS[i] or 60
            totalW = totalW + w
            if i > 1 then totalW = totalW + WATERMARK_SEP_W end
        end

        local wm = new("Frame", {
            Parent           = self.Holder,
            Position         = UDim2New(0, 12, 0, 10),
            Size             = UDim2New(0, totalW, 0, 24),
            BackgroundColor3 = self.Theme.Background,  -- #080808
            BorderSizePixel  = 0,
            ClipsDescendants = true,
        })
        -- Accent top border
        new("Frame", {
            Parent           = wm,
            Size             = UDim2New(1, 0, 0, 2),
            BackgroundColor3 = self.Theme.Accent,
            BorderSizePixel  = 0,
        })
        -- Outer glow strokes
        stroke(self.Theme.Accent, 1, 0.1).Parent = wm
        stroke(self.Theme.Accent, 2, 0.7).Parent  = wm

        local row = new("Frame", {
            Parent                 = wm,
            Size                   = UDim2New(1, 0, 1, 0),
            BackgroundTransparency = 1,
        })
        new("UIListLayout", {
            Parent              = row,
            FillDirection       = Enum.FillDirection.Horizontal,
            VerticalAlignment   = Enum.VerticalAlignment.Center,
            SortOrder           = Enum.SortOrder.LayoutOrder,
        })
        new("UIPadding", {
            Parent       = row,
            PaddingLeft  = UDimNew(0, WATERMARK_PAD),
            PaddingRight = UDimNew(0, WATERMARK_PAD),
        })

        -- live data sources
        local stats           = pcall(function() return game:GetService("Stats") end)
                                  and game:GetService("Stats") or nil
        local fpsSmoothed     = 60
        local lastTick        = os.clock()
        local function getFps()
            local now = os.clock()
            local dt  = now - lastTick
            lastTick  = now
            if dt > 0 then
                local cur = 1 / dt
                fpsSmoothed = fpsSmoothed + (cur - fpsSmoothed) * 0.1
            end
            return MathFloor(fpsSmoothed + 0.5)
        end
        local function getPing()
            local ok, ping = pcall(function()
                if stats and stats.Network and stats.Network.ServerStatsItem
                   and stats.Network.ServerStatsItem["Data Ping"] then
                    return MathFloor(stats.Network.ServerStatsItem["Data Ping"]:GetValue() + 0.5)
                end
                return MathFloor(LocalPlayer:GetNetworkPing() * 1000 + 0.5)
            end)
            return ok and ping or 0
        end
        local function getTime() return os.date("%H:%M") end
        local function getDate() return os.date("%Y-%m-%d") end

        local function resolve(raw)
            local s = tostring(raw)
            s = s:gsub("%%user%%", LocalPlayer.Name)
            s = s:gsub("%%disp%%", LocalPlayer.DisplayName or LocalPlayer.Name)
            s = s:gsub("%%fps%%",  tostring(getFps())  .. " fps")
            s = s:gsub("%%ping%%", tostring(getPing()) .. " ms")
            s = s:gsub("%%time%%", getTime())
            s = s:gsub("%%date%%", getDate())
            return s
        end

        local function isDynamic(raw)
            local s = tostring(raw)
            return s:find("%%fps%%") or s:find("%%ping%%")
                or s:find("%%time%%") or s:find("%%date%%")
        end

        local labels        = {}
        local dynamicLabels = {}

        local function buildField(i, raw)
            local fieldW = (widths and widths[i]) or WATERMARK_DEFAULTS[i] or 60
            if i > 1 then
                -- Separator "〡" in dark gray (#060606)
                new("TextLabel", {
                    Parent                 = row,
                    LayoutOrder            = i * 2 - 1,
                    Size                   = UDim2New(0, WATERMARK_SEP_W, 1, 0),
                    BackgroundTransparency = 1,
                    Font                   = self.Font,
                    TextSize               = 13,
                    Text                   = "〡",
                    TextColor3             = self.Theme.Outline,  -- #060606
                    TextXAlignment         = Enum.TextXAlignment.Center,
                })
            end
            local isFirst = (i == 1)
            local lbl = new("TextLabel", {
                Parent                 = row,
                LayoutOrder            = i * 2,
                Size                   = UDim2New(0, fieldW, 1, 0),
                BackgroundTransparency = 1,
                Font                   = self.Font,
                TextSize               = 12,
                Text                   = resolve(raw),
                -- Field 1 (Sirex.cc) in Accent, others in Text (#D7D7D7)
                TextColor3             = isFirst and self.Theme.Accent or self.Theme.Text,
                TextTruncate           = Enum.TextTruncate.AtEnd,
                TextXAlignment         = Enum.TextXAlignment.Center,
                RichText               = true,
            })
            labels[i] = { Label = lbl, Raw = raw }
            if isDynamic(raw) then
                dynamicLabels[#dynamicLabels + 1] = labels[i]
            end
        end
        for i, v in ipairs(fields) do buildField(i, v) end

        -- live updater (only if there are dynamic fields)
        if #dynamicLabels > 0 then
            self:Connect(RunService.Heartbeat, function()
                getFps() -- keep smoothing fresh
            end)
            self:Thread(function()
                while wm.Parent do
                    for _, item in ipairs(dynamicLabels) do
                        item.Label.Text = resolve(item.Raw)
                    end
                    task.wait(0.25)
                end
            end)
        end

        self:MakeDraggable(wm)
        return {
            Instance   = wm,
            SetField   = function(_, i, t)
                if labels[i] then
                    labels[i].Raw         = t
                    labels[i].Label.Text  = resolve(t)
                end
            end,
            SetVisible = function(_, b) wm.Visible = b end,
        }
    end

    

    ----------------------------------------------------------------
    -- Keybind list panel (the "Keybinds" floating window from the screenshot)
    ----------------------------------------------------------------
    function Library:KeybindList()
        if self.KeyList then return self.KeyList end

        local win = new("Frame", {
            Parent           = self.Holder,
            Position         = UDim2New(0, 30, 0.5, -150),
            Size             = UDim2New(0, 240, 0, 0),
            AutomaticSize    = Enum.AutomaticSize.Y,
            BackgroundColor3 = self.Theme.Background,
            BorderSizePixel  = 0,
        })
        corner(5).Parent = win
        -- layered glow: crisp 1px inner border + soft 3px outer halo
        stroke(self.Theme.Accent, 1, 0).Parent    = win
        stroke(self.Theme.Accent, 3, 0.65).Parent = win

        new("TextLabel", {
            Parent                 = win,
            Size                   = UDim2New(1, 0, 0, 22),
            Position               = UDim2New(0, 0, 0, 6),
            BackgroundTransparency = 1,
            Font                   = self.FontBold,
            TextSize               = 14,
            Text                   = "Keybinds",
            TextColor3             = self.Theme.Text,
        })
        new("Frame", {
            Parent           = win,
            Position         = UDim2New(0, 10, 0, 30),
            Size             = UDim2New(1, -20, 0, 1),
            BackgroundColor3 = self.Theme.Divider,
            BorderSizePixel  = 0,
        })

        local list = new("Frame", {
            Parent                 = win,
            Position               = UDim2New(0, 10, 0, 36),
            Size                   = UDim2New(1, -20, 0, 0),
            AutomaticSize          = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
        })
        new("UIListLayout", {
            Parent = list, Padding = UDimNew(0, 2),
            SortOrder = Enum.SortOrder.LayoutOrder,
        })
        new("UIPadding", { Parent = list, PaddingBottom = UDimNew(0, 8) })

        self:MakeDraggable(win)

        local KL = { Instance = win, Items = {} }

        function KL:Add(mode, name, key)
            local row = new("Frame", {
                Parent                 = list,
                Size                   = UDim2New(1, 0, 0, 14),
                BackgroundTransparency = 1,
            })
            local txt = new("TextLabel", {
                Parent                 = row,
                Size                   = UDim2New(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Font                   = Library.Font,
                TextSize               = 12,
                Text                   = StrFormat("[%s] %s (%s)", tostring(key), tostring(name), tostring(mode)),
                TextColor3             = Library.Theme.Text,
                TextXAlignment         = Enum.TextXAlignment.Left,
            })
            local item = {}
            function item:Set(m, n, k)
                txt.Text = StrFormat("[%s] %s (%s)", tostring(k), tostring(n), tostring(m))
            end
            function item:SetActive(b)
                txt.TextColor3 = b and Library.Theme.Accent or Library.Theme.Text
            end
            function item:Remove() row:Destroy() end
            TblInsert(self.Items, item)
            return item
        end

        function KL:SetVisible(b) win.Visible = b end

        self.KeyList = KL
        return KL
    end

    ----------------------------------------------------------------
    -- ============== WINDOW ==============
    ----------------------------------------------------------------
    function Library:Window(data)
        data = data or {}
        local Window = {
            Name          = data.Name or data.name or "Aurora Legacy",
            Size          = data.Size or data.size or UDim2New(0, 820, 0, 540),
            GradientTitle = data.GradientTitle or data.gradienttitle,
            Pages         = {},
            Active        = nil,
            IsOpen        = true,
        }

        local main = new("Frame", {
            Parent           = self.Holder,
            AnchorPoint      = Vector2New(0.5, 0.5),
            Position         = UDim2New(0.5, 0, 0.5, 0),
            Size             = Window.Size,
            BackgroundColor3 = self.Theme.Background,
            BorderSizePixel  = 0,
        })
        corner(6).Parent = main
        -- layered glow: crisp 1px inner border + soft 3px outer halo
        stroke(self.Theme.Accent, 1, 0).Parent    = main
        stroke(self.Theme.Accent, 3, 0.65).Parent = main

        -- Title
        local titleBar = new("Frame", {
            Parent                 = main,
            Size                   = UDim2New(1, 0, 0, 36),
            BackgroundTransparency = 1,
        })
        local titleLabel = new("TextLabel", {
            Parent                 = titleBar,
            Size                   = UDim2New(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Font                   = self.FontBold,
            TextSize               = 16,
            RichText               = true,
            TextColor3             = self.Theme.Text,
        })

        do
            local first = Window.Name
            local rest  = ""
            local sep   = first:find("|")
            if sep then
                first = Window.Name:sub(1, sep - 1):gsub("%s+$", "")
                rest  = " " .. Window.Name:sub(sep)
            end
            titleLabel.Text = StrFormat(
                '<font color="#C878E6">%s</font><font color="#B7A9C9">%s</font>',
                first, rest
            )
        end

        self:MakeDraggable(main, titleBar)

        -- Tab bar : equal-width tabs separated by thin vertical dividers
        local tabBar = new("Frame", {
            Parent                 = main,
            Size                   = UDim2New(1, 0, 0, 30),
            Position               = UDim2New(0, 0, 0, 40),
            BackgroundTransparency = 1,
        })
        local tabGrid = new("UIListLayout", {
            Parent              = tabBar,
            FillDirection       = Enum.FillDirection.Horizontal,
            HorizontalFlex      = Enum.UIFlexAlignment.Fill,
            VerticalAlignment   = Enum.VerticalAlignment.Center,
            SortOrder           = Enum.SortOrder.LayoutOrder,
        })

        new("Frame", {
            Parent                 = main,
            Size                   = UDim2New(1, 0, 0, 1),
            Position               = UDim2New(0, 0, 0, 71),
            BackgroundColor3       = self.Theme.Divider,
            BorderSizePixel        = 0,
            BackgroundTransparency = 0.5,
        })

        -- Content area
        local content = new("Frame", {
            Parent                 = main,
            Position               = UDim2New(0, 0, 0, 76),
            Size                   = UDim2New(1, 0, 1, -86),
            BackgroundTransparency = 1,
            ClipsDescendants       = true,
        })

        Window.MainFrame = main
        Window.TabBar    = tabBar
        Window.Content   = content

        function Window:SetOpen(b)
            self.IsOpen     = b
            main.Visible    = b
            setCursorVisible(b)
            if b then followCursor() else unfollowCursor() end
        end

        function Window:Toggle() self:SetOpen(not self.IsOpen) end

        function Window:SetTitle(text)
            local f, r = text, ""
            local s = f:find("|")
            if s then f, r = text:sub(1, s - 1):gsub("%s+$", ""), " " .. text:sub(s) end
            titleLabel.Text = StrFormat(
                '<font color="#C878E6">%s</font><font color="#B7A9C9">%s</font>', f, r
            )
        end

        Library:Connect(UserInputService.InputBegan, function(i, gp)
            if gp then return end
            if tostring(i.KeyCode) == "Enum.KeyCode." .. Library.MenuKeybind
            or i.KeyCode.Name == Library.MenuKeybind then
                Window:Toggle()
            end
        end)

        function Window:Page(pdata)
            pdata = pdata or {}
            local Page = {
                Window  = Window,
                Name    = pdata.Name or pdata.name or "Page",
                Columns = pdata.Columns or pdata.columns or 3,
                ColumnsData = {},
                Active  = false,
            }

            -- tab button (equal width via flex)
            local btnHolder = new("Frame", {
                Parent                 = tabBar,
                Size                   = UDim2New(0, 1, 1, 0),
                BackgroundTransparency = 1,
                LayoutOrder            = #Window.Pages + 1,
            })
            new("UIFlexItem", {
                Parent      = btnHolder,
                FlexMode    = Enum.UIFlexMode.Fill,
            })
            local btn = new("TextButton", {
                Parent                 = btnHolder,
                Size                   = UDim2New(1, 0, 1, -4),
                BackgroundTransparency = 1,
                Font                   = Library.Font,
                TextSize               = 15,
                Text                   = Page.Name,
                TextColor3             = Library.Theme.TextDim,
                AutoButtonColor        = false,
            })
            -- thin vertical divider on the right edge (acts like the | between tabs)
            new("Frame", {
                Parent                 = btnHolder,
                AnchorPoint            = Vector2New(1, 0.5),
                Position               = UDim2New(1, 0, 0.5, 0),
                Size                   = UDim2New(0, 1, 0, 14),
                BackgroundColor3       = Library.Theme.Divider,
                BorderSizePixel        = 0,
                BackgroundTransparency = 0.5,
            })
            local underline = new("Frame", {
                Parent                 = btnHolder,
                AnchorPoint            = Vector2New(0.5, 1),
                Position               = UDim2New(0.5, 0, 1, 0),
                Size                   = UDim2New(1, -4, 0, 2),
                BackgroundColor3       = Library.Theme.Accent,
                BorderSizePixel        = 0,
                BackgroundTransparency = 1,
            })

            -- page content frame (3 columns side by side)
            local pageFrame = new("Frame", {
                Parent                 = content,
                Size                   = UDim2New(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Visible                = false,
            })

            local columnsHolder = new("Frame", {
                Parent                 = pageFrame,
                Size                   = UDim2New(1, 0, 1, 0),
                BackgroundTransparency = 1,
            })
            new("UIListLayout", {
                Parent              = columnsHolder,
                FillDirection       = Enum.FillDirection.Horizontal,
                Padding             = UDimNew(0, 1),
                HorizontalFlex      = Enum.UIFlexAlignment.Fill,
                VerticalFlex        = Enum.UIFlexAlignment.Fill,
                SortOrder           = Enum.SortOrder.LayoutOrder,
            })

            for i = 1, Page.Columns do
                local col = new("ScrollingFrame", {
                    Parent                 = columnsHolder,
                    Size                   = UDim2New(0, 1, 1, 0),
                    BackgroundTransparency = 1,
                    BorderSizePixel        = 0,
                    ScrollBarThickness     = 2,
                    ScrollBarImageColor3   = Library.Theme.AccentDim,
                    CanvasSize             = UDim2New(0, 0, 0, 0),
                    AutomaticCanvasSize    = Enum.AutomaticSize.Y,
                    LayoutOrder            = i,
                })
                new("UIFlexItem", { Parent = col, FlexMode = Enum.UIFlexMode.Fill })
                -- right-side vertical divider between columns
                if i < Page.Columns then
                    new("Frame", {
                        Parent                 = col,
                        AnchorPoint            = Vector2New(1, 0),
                        Position               = UDim2New(1, 0, 0, -4),
                        Size                   = UDim2New(0, 1, 1, 8),
                        BackgroundColor3       = Library.Theme.Divider,
                        BorderSizePixel        = 0,
                        BackgroundTransparency = 0.6,
                        ZIndex                 = 0,
                    })
                end
                new("UIListLayout", {
                    Parent    = col,
                    Padding   = UDimNew(0, 14),
                    SortOrder = Enum.SortOrder.LayoutOrder,
                })
                new("UIPadding", {
                    Parent        = col,
                    PaddingTop    = UDimNew(0, 6),
                    PaddingBottom = UDimNew(0, 10),
                    PaddingLeft   = UDimNew(0, 14),
                    PaddingRight  = UDimNew(0, 14),
                })
                Page.ColumnsData[i] = col
            end

            function Page:Turn(b)
                self.Active            = b
                pageFrame.Visible      = b
                btn.TextColor3         = b and Library.Theme.Accent or Library.Theme.TextDim
                btn.Font               = b and Library.FontBold or Library.Font
                underline.BackgroundTransparency = b and 0 or 1
            end

            btn.MouseButton1Click:Connect(function()
                for _, p in ipairs(Window.Pages) do p:Turn(p == Page) end
                Window.Active = Page
            end)

            TblInsert(Window.Pages, Page)
            if #Window.Pages == 1 then Page:Turn(true); Window.Active = Page end

            return setmetatable(Page, Library.Pages)
        end

        return setmetatable(Window, Library)
    end

    ----------------------------------------------------------------
    -- ============== PAGE -> SECTION ==============
    ----------------------------------------------------------------
    function Library.Pages:Section(sdata)
        sdata = sdata or {}
        local Section = {
            Window = self.Window,
            Page   = self,
            Name   = sdata.Name or sdata.name or "Section",
            Side   = sdata.Side or sdata.side or 1,
        }
        local parent = self.ColumnsData[Section.Side] or self.ColumnsData[1]

        local box = new("Frame", {
            Parent                 = parent,
            Size                   = UDim2New(1, 0, 0, 0),
            AutomaticSize          = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
        })
        -- top divider line with the floating label overlapping it
        new("Frame", {
            Parent           = box,
            Position         = UDim2New(0, 0, 0, 8),
            Size             = UDim2New(1, 0, 0, 1),
            BackgroundColor3 = Library.Theme.Divider,
            BorderSizePixel  = 0,
        })
        local header = new("Frame", {
            Parent                 = box,
            Position               = UDim2New(0, 0, 0, 0),
            Size                   = UDim2New(0, 0, 0, 16),
            AutomaticSize          = Enum.AutomaticSize.X,
            BackgroundColor3       = Library.Theme.Background,
            BorderSizePixel        = 0,
        })
        new("UIListLayout", {
            Parent              = header,
            FillDirection       = Enum.FillDirection.Horizontal,
            VerticalAlignment   = Enum.VerticalAlignment.Center,
            SortOrder           = Enum.SortOrder.LayoutOrder,
            Padding             = UDimNew(0, 3),
        })
        new("UIPadding", {
            Parent       = header,
            PaddingLeft  = UDimNew(0, 4),
            PaddingRight = UDimNew(0, 6),
        })
        new("TextLabel", {
            Parent                 = header,
            LayoutOrder            = 1,
            Size                   = UDim2New(0, 8, 0, 14),
            BackgroundTransparency = 1,
            Font                   = Library.FontBold,
            TextSize               = 9,
            Text                   = "v",
            TextColor3             = Library.Theme.Accent,
        })
        new("TextLabel", {
            Parent                 = header,
            LayoutOrder            = 2,
            Size                   = UDim2New(0, 0, 0, 16),
            AutomaticSize          = Enum.AutomaticSize.X,
            BackgroundTransparency = 1,
            Font                   = Library.Font,
            TextSize               = 13,
            Text                   = Section.Name,
            TextColor3             = Library.Theme.Text,
        })

        local body = new("Frame", {
            Parent                 = box,
            Position               = UDim2New(0, 0, 0, 22),
            Size                   = UDim2New(1, 0, 0, 0),
            AutomaticSize          = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
        })
        new("UIListLayout", {
            Parent    = body,
            Padding   = UDimNew(0, 6),
            SortOrder = Enum.SortOrder.LayoutOrder,
        })
        Section.Body = body

        return setmetatable(Section, Library.Sections)
    end

    ----------------------------------------------------------------
    -- ============== SECTION -> COMPONENTS ==============
    ----------------------------------------------------------------

    -- Helper for small "[X]" / "[...]" boxes on the right of a row
    local function MakeKeyBadge(parent, text)
        local k = new("TextLabel", {
            Parent           = parent,
            AnchorPoint      = Vector2New(1, 0.5),
            Position         = UDim2New(1, 0, 0.5, 0),
            Size             = UDim2New(0, 28, 0, 16),
            BackgroundColor3 = Library.Theme.Element,
            BorderSizePixel  = 0,
            Font             = Library.Font,
            TextSize         = 12,
            Text             = tostring(text or "..."),
            TextColor3       = Library.Theme.Text,
        })
        corner(2).Parent = k
        stroke(Library.Theme.AccentDim, 1, 0.4).Parent = k
        return k
    end

    --------------------------------------------------- LABEL
    function Library.Sections:Label(text, align)
        local lblFrame = new("Frame", {
            Parent                 = self.Body,
            Size                   = UDim2New(1, 0, 0, 14),
            BackgroundTransparency = 1,
        })
        local lbl = new("TextLabel", {
            Parent                 = lblFrame,
            Size                   = UDim2New(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Font                   = Library.Font,
            TextSize               = 13,
            Text                   = tostring(text or "Label"),
            TextColor3             = Library.Theme.Text,
            TextXAlignment         = Enum.TextXAlignment[align or "Left"],
            RichText               = true,
        })
        local L = { Instance = lblFrame, TextLabel = lbl }
        function L:Set(t)         lbl.Text = tostring(t) end
        function L:SetVisible(b)  lblFrame.Visible = b end
        return L
    end

    --------------------------------------------------- TOGGLE
    function Library.Sections:Toggle(data)
        data = data or {}
        local Toggle = {
            Name     = data.Name or data.name or "Toggle",
            Default  = data.Default or data.default or false,
            Flag     = data.Flag or data.flag or Library:NextFlag(),
            Risky    = data.Risky or data.risky,
            Callback = data.Callback or data.callback or function() end,
            Value    = false,
        }

        local row = new("Frame", {
            Parent                 = self.Body,
            Size                   = UDim2New(1, 0, 0, 18),
            BackgroundTransparency = 1,
        })
        local box = new("TextButton", {
            Parent           = row,
            Size             = UDim2New(0, 11, 0, 11),
            Position         = UDim2New(0, 0, 0.5, -5),
            BackgroundColor3 = Library.Theme.Element,
            BorderSizePixel  = 0,
            AutoButtonColor  = false,
            Text             = "",
        })
        stroke(Library.Theme.AccentDim, 1, 0.3).Parent = box
        local lbl = new("TextLabel", {
            Parent                 = row,
            Position               = UDim2New(0, 18, 0, 0),
            Size                   = UDim2New(1, -40, 1, 0),
            BackgroundTransparency = 1,
            Font                   = Library.Font,
            TextSize               = 13,
            Text                   = Toggle.Name,
            TextColor3             = Toggle.Risky and Library.Theme.Risky or Library.Theme.Text,
            TextXAlignment         = Enum.TextXAlignment.Left,
        })

        function Toggle:Set(v)
            self.Value = v and true or false
            Library.Flags[self.Flag] = self.Value
            box.BackgroundColor3 = self.Value and Library.Theme.Accent or Library.Theme.Element
            Library:SafeCall(self.Callback, self.Value)
        end
        function Toggle:Get()        return self.Value end
        function Toggle:SetVisible(b) row.Visible = b end

        local function flip() Toggle:Set(not Toggle.Value) end
        box.MouseButton1Click:Connect(flip)
        -- make the whole row clickable too (so the label area works)
        local hit = new("TextButton", {
            Parent                 = row,
            Size                   = UDim2New(1, -40, 1, 0),
            Position               = UDim2New(0, 18, 0, 0),
            BackgroundTransparency = 1,
            Text                   = "",
            AutoButtonColor        = false,
            ZIndex                 = 0,
        })
        hit.MouseButton1Click:Connect(flip)
        Library.SetFlags[Toggle.Flag] = function(v) Toggle:Set(v) end

        if Toggle.Default then Toggle:Set(true) end

        -- chainable add-ons: Toggle:Keybind / Toggle:Colorpicker (right side of the row)
        function Toggle:Keybind(kdata)
            kdata = kdata or {}
            local key   = kdata.Default or kdata.default or Enum.KeyCode.Unknown
            local mode  = kdata.Mode or kdata.mode or "Toggle"
            local flag  = kdata.Flag or kdata.flag or (Toggle.Flag .. "_key")
            local cb    = kdata.Callback or kdata.callback or function() end

            local keyName = (typeof(key) == "EnumItem") and key.Name or tostring(key)
            local badge   = MakeKeyBadge(row, keyName == "Unknown" and "..." or keyName)

            local K = { Key = keyName, Mode = mode, Flag = flag, Toggled = false }
            Library.Flags[flag] = { Key = keyName, Mode = mode, Toggled = false }

            local listItem
            if Library.KeyList then
                listItem = Library.KeyList:Add(mode, Toggle.Name, keyName)
            end

            function K:Set(v)
                if typeof(v) == "EnumItem" then
                    self.Key   = v.Name
                    badge.Text = self.Key == "Unknown" and "..." or self.Key
                elseif type(v) == "table" then
                    if v.Key  then self.Key  = v.Key;  badge.Text = self.Key end
                    if v.Mode then self.Mode = v.Mode end
                end
                Library.Flags[flag] = { Key = self.Key, Mode = self.Mode, Toggled = self.Toggled }
                if listItem then listItem:Set(self.Mode, Toggle.Name, self.Key) end
            end

            local picking = false
            local btn = new("TextButton", {
                Parent                 = badge,
                Size                   = UDim2New(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Text                   = "",
                AutoButtonColor        = false,
            })
            btn.MouseButton1Click:Connect(function()
                if picking then return end
                picking = true
                badge.TextColor3 = Library.Theme.Accent
                local conn
                conn = UserInputService.InputBegan:Connect(function(inp)
                    if inp.UserInputType == Enum.UserInputType.Keyboard then
                        K:Set(inp.KeyCode)
                    end
                    badge.TextColor3 = Library.Theme.Text
                    picking = false
                    conn:Disconnect()
                end)
            end)

            Library:Connect(UserInputService.InputBegan, function(inp)
                if inp.KeyCode and inp.KeyCode.Name == K.Key then
                    if K.Mode == "Toggle" then Toggle:Set(not Toggle.Value)
                    elseif K.Mode == "Hold" then Toggle:Set(true) end
                end
            end)
            Library:Connect(UserInputService.InputEnded, function(inp)
                if inp.KeyCode and inp.KeyCode.Name == K.Key and K.Mode == "Hold" then
                    Toggle:Set(false)
                end
            end)

            Library.SetFlags[flag] = function(v) K:Set(v) end
            return K
        end

        return Toggle
    end

    --------------------------------------------------- BUTTON
    function Library.Sections:Button(data)
        data = data or {}
        local Btn = {
            Name     = data.Name or data.name or "Button",
            Risky    = data.Risky or data.risky,
            Callback = data.Callback or data.callback or function() end,
        }
        local b = new("TextButton", {
            Parent           = self.Body,
            Size             = UDim2New(1, 0, 0, 18),
            BackgroundColor3 = Library.Theme.Element,
            BorderSizePixel  = 0,
            AutoButtonColor  = false,
            Font             = Library.Font,
            TextSize         = 13,
            Text             = Btn.Name,
            TextColor3       = Btn.Risky and Library.Theme.Risky or Library.Theme.Text,
        })
        local bs = stroke(Library.Theme.AccentDim, 1, 0.4)
        bs.Parent = b

        b.MouseEnter:Connect(function()
            Library:Tween(bs, TweenInfo.new(0.12), {
                Color        = Library.Theme.Accent,
                Transparency = 0,
                Thickness    = 1,
            })
            Library:Tween(b, TweenInfo.new(0.12), {
                BackgroundColor3 = Library.Theme.SliderBg,
            })
        end)
        b.MouseLeave:Connect(function()
            Library:Tween(bs, TweenInfo.new(0.15), {
                Color        = Library.Theme.AccentDim,
                Transparency = 0.4,
                Thickness    = 1,
            })
            Library:Tween(b, TweenInfo.new(0.15), {
                BackgroundColor3 = Library.Theme.Element,
            })
        end)

        b.MouseButton1Click:Connect(function()
            Library:SafeCall(Btn.Callback)
            Library:Tween(b, TweenInfo.new(0.08), { BackgroundColor3 = Library.Theme.Accent })
            task.wait(0.1)
            Library:Tween(b, TweenInfo.new(0.2),  { BackgroundColor3 = Library.Theme.Element })
        end)
        function Btn:Set(name) b.Text = name end
        function Btn:SetVisible(v) b.Visible = v end
        return Btn
    end

    --------------------------------------------------- SLIDER
    function Library.Sections:Slider(data)
        data = data or {}
        local S = {
            Name     = data.Name or data.name or "Slider",
            Min      = data.Min or data.min or 0,
            Max      = data.Max or data.max or 100,
            Default  = data.Default or data.default or 0,
            Decimals = data.Decimals or data.decimals or 1,
            Suffix   = data.Suffix or data.suffix or "",
            Flag     = data.Flag or data.flag or Library:NextFlag(),
            Callback = data.Callback or data.callback or function() end,
            Value    = 0,
        }

        local holder = new("Frame", {
            Parent                 = self.Body,
            Size                   = UDim2New(1, 0, 0, 30),
            BackgroundTransparency = 1,
        })
        local label = new("TextLabel", {
            Parent                 = holder,
            Size                   = UDim2New(1, 0, 0, 14),
            BackgroundTransparency = 1,
            Font                   = Library.Font,
            TextSize               = 13,
            Text                   = S.Name,
            TextColor3             = Library.Theme.Text,
            TextXAlignment         = Enum.TextXAlignment.Left,
        })
        local bar = new("Frame", {
            Parent           = holder,
            Position         = UDim2New(0, 0, 1, -11),
            Size             = UDim2New(1, 0, 0, 11),
            BackgroundColor3 = Library.Theme.SliderBg,
            BorderSizePixel  = 0,
        })
        local fill = new("Frame", {
            Parent           = bar,
            Size             = UDim2New(0, 0, 1, 0),
            BackgroundColor3 = Library.Theme.Accent,
            BorderSizePixel  = 0,
        })
        local valTxt = new("TextLabel", {
            Parent                 = bar,
            Size                   = UDim2New(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Font                   = Library.Font,
            TextSize               = 11,
            Text                   = "",
            TextColor3             = Library.Theme.Text,
        })

        local function round(n)
            local m = 1 / (S.Decimals or 1)
            return MathFloor(n * m + 0.5) / m
        end

        function S:Set(v)
            self.Value = MathClamp(round(v), self.Min, self.Max)
            Library.Flags[self.Flag] = self.Value
            local pct = (self.Value - self.Min) / (self.Max - self.Min)
            fill.Size  = UDim2New(pct, 0, 1, 0)
            valTxt.Text = tostring(self.Value) .. tostring(self.Suffix)
            Library:SafeCall(self.Callback, self.Value)
        end
        function S:Get() return self.Value end
        function S:SetVisible(b) holder.Visible = b end

        local sliding = false
        local function move(input)
            local rel = (input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X
            rel = MathClamp(rel, 0, 1)
            S:Set(S.Min + (S.Max - S.Min) * rel)
        end
        bar.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1
            or i.UserInputType == Enum.UserInputType.Touch then
                sliding = true; move(i)
            end
        end)
        bar.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1
            or i.UserInputType == Enum.UserInputType.Touch then sliding = false end
        end)
        Library:Connect(UserInputService.InputChanged, function(i)
            if sliding and (i.UserInputType == Enum.UserInputType.MouseMovement
                         or i.UserInputType == Enum.UserInputType.Touch) then move(i) end
        end)

        Library.SetFlags[S.Flag] = function(v) S:Set(v) end
        S:Set(S.Default)
        return S
    end

    --------------------------------------------------- DROPDOWN
    function Library.Sections:Dropdown(data)
        data = data or {}
        local D = {
            Name     = data.Name or data.name or "Dropdown",
            Items    = data.Items or data.items or {},
            Default  = data.Default or data.default,
            MaxSize  = data.MaxSize or data.maxsize or 120,
            Flag     = data.Flag or data.flag or Library:NextFlag(),
            Multi    = data.Multi or data.multi or false,
            Callback = data.Callback or data.callback or function() end,
            Value    = nil,
            Options  = {},
            IsOpen   = false,
        }
        if D.Multi and not D.Default then D.Value = {} end

        local wrap = new("Frame", {
            Parent                 = self.Body,
            Size                   = UDim2New(1, 0, 0, 32),
            BackgroundTransparency = 1,
        })
        local lbl = new("TextLabel", {
            Parent                 = wrap,
            Size                   = UDim2New(1, 0, 0, 14),
            BackgroundTransparency = 1,
            Font                   = Library.Font,
            TextSize               = 13,
            Text                   = D.Name,
            TextColor3             = Library.Theme.Text,
            TextXAlignment         = Enum.TextXAlignment.Left,
        })
        local btn = new("TextButton", {
            Parent           = wrap,
            Position         = UDim2New(0, 0, 0, 16),
            Size             = UDim2New(1, 0, 0, 16),
            BackgroundColor3 = Library.Theme.Element,
            BorderSizePixel  = 0,
            AutoButtonColor  = false,
            Font             = Library.Font,
            TextSize         = 12,
            Text             = "  --",
            TextColor3       = Library.Theme.Text,
            TextXAlignment   = Enum.TextXAlignment.Left,
        })
        corner(2).Parent = btn
        stroke(Library.Theme.AccentDim, 1, 0.4).Parent = btn
        new("TextLabel", {
            Parent                 = btn,
            AnchorPoint            = Vector2New(1, 0.5),
            Position               = UDim2New(1, -6, 0.5, 0),
            Size                   = UDim2New(0, 12, 0, 12),
            BackgroundTransparency = 1,
            Font                   = Library.Font,
            TextSize               = 13,
            Text                   = "v",
            TextColor3             = Library.Theme.TextDim,
        })

        local list = new("Frame", {
            Parent                 = Library.Holder,
            Visible                = false,
            BackgroundColor3       = Library.Theme.Inline,
            BorderSizePixel        = 0,
            Size                   = UDim2New(0, 100, 0, 0),
            AutomaticSize          = Enum.AutomaticSize.Y,
            ZIndex                 = 50,
        })
        corner(3).Parent = list
        stroke(Library.Theme.AccentDim, 1, 0.2).Parent = list
        local listLayout = new("UIListLayout", {
            Parent = list, Padding = UDimNew(0, 1),
            SortOrder = Enum.SortOrder.LayoutOrder,
        })
        new("UIPadding", {
            Parent = list,
            PaddingTop = UDimNew(0, 4), PaddingBottom = UDimNew(0, 4),
        })

        local function refreshLabel()
            if D.Multi then
                btn.Text = "  " .. ((#D.Value > 0) and TblConcat(D.Value, ", ") or "--")
            else
                btn.Text = "  " .. (D.Value or "--")
            end
        end

        function D:Open(b)
            self.IsOpen = b
            list.Visible = b
            if b then
                local ap, as = btn.AbsolutePosition, btn.AbsoluteSize
                list.Position = UDim2New(0, ap.X, 0, ap.Y + as.Y + 2)
                list.Size     = UDim2New(0, as.X, 0, 0)
            end
        end

        function D:Set(v)
            if self.Multi then
                if type(v) ~= "table" then return end
                self.Value = v
                Library.Flags[self.Flag] = v
                for _, opt in pairs(self.Options) do
                    opt:Toggle(TblFind(v, opt.Name) ~= nil)
                end
            else
                self.Value = v
                Library.Flags[self.Flag] = v
                for name, opt in pairs(self.Options) do
                    opt:Toggle(name == v)
                end
            end
            refreshLabel()
            Library:SafeCall(self.Callback, self.Value)
        end

        function D:Get() return self.Value end
        function D:SetVisible(b) wrap.Visible = b end

        function D:Add(opt)
            local row = new("TextButton", {
                Parent           = list,
                Size             = UDim2New(1, 0, 0, 16),
                BackgroundTransparency = 1,
                AutoButtonColor  = false,
                Font             = Library.Font,
                TextSize         = 12,
                Text             = "  " .. tostring(opt),
                TextColor3       = Library.Theme.Text,
                TextXAlignment   = Enum.TextXAlignment.Left,
                ZIndex           = 51,
            })
            local o = { Name = opt, Button = row, Selected = false }
            function o:Toggle(b)
                self.Selected = b
                row.TextColor3 = b and Library.Theme.Accent or Library.Theme.Text
            end
            row.MouseButton1Click:Connect(function()
                if D.Multi then
                    local i = TblFind(D.Value, opt)
                    if i then TblRemove(D.Value, i) else TblInsert(D.Value, opt) end
                    o:Toggle(not i and true or false)
                    Library.Flags[D.Flag] = D.Value
                    refreshLabel()
                    Library:SafeCall(D.Callback, D.Value)
                else
                    D:Set(opt)
                    D:Open(false)
                end
            end)
            D.Options[opt] = o
            return o
        end

        function D:Refresh(items)
            for n, o in pairs(D.Options) do o.Button:Destroy() end
            D.Options = {}
            for _, v in ipairs(items) do D:Add(v) end
        end

        for _, v in ipairs(D.Items) do D:Add(v) end

        btn.MouseButton1Click:Connect(function() D:Open(not D.IsOpen) end)
        Library:Connect(UserInputService.InputBegan, function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1
            or i.UserInputType == Enum.UserInputType.Touch then
                if D.IsOpen and not Library:IsMouseOver(list) and not Library:IsMouseOver(btn) then
                    D:Open(false)
                end
            end
        end)

        if D.Default then D:Set(D.Default) end
        Library.SetFlags[D.Flag] = function(v) D:Set(v) end
        return D
    end

    --------------------------------------------------- TEXTBOX
    function Library.Sections:Textbox(data)
        data = data or {}
        local T = {
            Name        = data.Name or data.name or "Textbox",
            Default     = data.Default or data.default or "",
            Placeholder = data.Placeholder or data.placeholder or "...",
            Flag        = data.Flag or data.flag or Library:NextFlag(),
            Callback    = data.Callback or data.callback or function() end,
            Value       = "",
        }
        local wrap = new("Frame", {
            Parent                 = self.Body,
            Size                   = UDim2New(1, 0, 0, 32),
            BackgroundTransparency = 1,
        })
        new("TextLabel", {
            Parent                 = wrap,
            Size                   = UDim2New(1, 0, 0, 14),
            BackgroundTransparency = 1,
            Font                   = Library.Font,
            TextSize               = 13,
            Text                   = T.Name,
            TextColor3             = Library.Theme.Text,
            TextXAlignment         = Enum.TextXAlignment.Left,
        })
        local box = new("TextBox", {
            Parent                 = wrap,
            Position               = UDim2New(0, 0, 0, 16),
            Size                   = UDim2New(1, 0, 0, 16),
            BackgroundColor3       = Library.Theme.Element,
            BorderSizePixel        = 0,
            Font                   = Library.Font,
            TextSize               = 12,
            Text                   = "",
            TextColor3             = Library.Theme.Text,
            PlaceholderText        = T.Placeholder,
            PlaceholderColor3      = Library.Theme.TextDim,
            ClearTextOnFocus       = false,
            TextXAlignment         = Enum.TextXAlignment.Left,
        })
        corner(2).Parent = box
        stroke(Library.Theme.AccentDim, 1, 0.4).Parent = box
        new("UIPadding", { Parent = box, PaddingLeft = UDimNew(0, 5) })

        function T:Set(v)
            self.Value = tostring(v)
            box.Text   = self.Value
            Library.Flags[self.Flag] = self.Value
            Library:SafeCall(self.Callback, self.Value)
        end
        function T:Get() return self.Value end
        function T:SetVisible(b) wrap.Visible = b end

        box.FocusLost:Connect(function() T:Set(box.Text) end)
        Library.SetFlags[T.Flag] = function(v) T:Set(v) end
        T:Set(T.Default)
        return T
    end

    ----------------------------------------------------------------
    -- Expose
    ----------------------------------------------------------------
    if getgenv then getgenv().AuroraLegacy = Library end
end

return Library
