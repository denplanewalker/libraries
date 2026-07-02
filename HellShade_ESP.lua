local EspModule = {}

function EspModule.init(context)
    local cheat = context.cheat
    local workspace = context.workspace
    local LocalPlayer = context.LocalPlayer
    local Camera = context.Camera
    local UserInputService = context.UserInputService
    local _FindFirstChild = context._FindFirstChild
    local _IsA = context._IsA
    local _WorldToViewportPoint = context._WorldToViewportPoint
    local esp_section = context.esp_section
    local playerCache = context.playerCache
    local isSleeper = context.isSleeper
    local isBot = context.isBot

    local espEnabled = false
    local infoEsp = false
    local boxEsp = false
    local checkSleeper = false
    local checkBot = false
    local corpseEsp = false
    local maxDistance = 1000
    local espColor = Color3.new(1, 1, 1)
    local boxColor = Color3.new(1, 0, 0)

    local espObjects = {}
    local corpseObjects = {}
    local corpseCache = setmetatable({}, {__mode = "k"})

    local function cleanupCharacter(character)
        if espObjects[character] then
            for _, drawing in pairs(espObjects[character]) do
                drawing.Visible = false
                drawing:Remove()
            end
            espObjects[character] = nil
        end
    end

    local function cleanupCorpse(corpse)
        if corpseObjects[corpse] then
            for _, drawing in pairs(corpseObjects[corpse]) do
                drawing.Visible = false
                drawing:Remove()
            end
            corpseObjects[corpse] = nil
            corpseCache[corpse] = nil
        end
    end

    local function isCorpse(model)
        local cached = corpseCache[model]
        if cached ~= nil then return cached end

        local count, mat1, mat2 = 0, nil, nil
        for _, child in ipairs(model:GetChildren()) do
            if child:IsA("BasePart") then
                count = count + 1
                if count == 1 then
                    mat1 = child.Material
                elseif count == 2 then
                    mat2 = child.Material
                else
                    corpseCache[model] = false
                    return false
                end
            end
        end

        if count ~= 2 then
            corpseCache[model] = false
            return false
        end

        local valid = (mat1 == Enum.Material.Fabric and mat2 == Enum.Material.Metal) or
                      (mat1 == Enum.Material.Metal and mat2 == Enum.Material.Fabric)
        corpseCache[model] = valid
        return valid
    end

    local function getHeldTool(player)
        local character = player.Character
        if not character then return "No Tool" end

        local tool = character:FindFirstChildWhichIsA("Tool")
        if tool and tool.Name ~= "" then
            return tool.Name
        end

        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid and humanoid:IsA("Humanoid") then
            local equipped = humanoid:FindFirstChildWhichIsA("Tool")
            if equipped and equipped.Name ~= "" then
                return equipped.Name
            end
        end

        return "Fists"
    end

    local function createPlayerEsp(player)
        if espObjects[player] then return end

        local box = cheat.utility.new_drawing("Square", {})
        box.Visible = false
        box.Filled = false
        box.Thickness = 2
        box.Color = boxColor
        box.Transparency = 1
        box.ZIndex = 2
        box.Center = true

        local nameText = cheat.utility.new_drawing("Text", {})
        nameText.Size = 13
        nameText.Center = true
        nameText.Font = 2
        nameText.Outline = true
        nameText.OutlineColor = Color3.new(0, 0, 0)
        nameText.Color = espColor
        nameText.ZIndex = 3

        local distText = cheat.utility.new_drawing("Text", {})
        distText.Size = 13
        distText.Center = true
        distText.Font = 2
        distText.Outline = true
        distText.OutlineColor = Color3.new(0, 0, 0)
        distText.Color = espColor
        distText.ZIndex = 3

        local toolText = cheat.utility.new_drawing("Text", {})
        toolText.Size = 13
        toolText.Center = true
        toolText.Font = 2
        toolText.Outline = true
        toolText.OutlineColor = Color3.new(0, 0, 0)
        toolText.Color = espColor
        toolText.ZIndex = 3

        espObjects[player] = {box = box, name = nameText, tool = toolText, dist = distText}
    end

    local function addCorpseModel(model)
        if corpseObjects[model] then return end
        if not isCorpse(model) then return end

        local part = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
        if not part then return end

        local box = cheat.utility.new_drawing("Square", {})
        box.Visible = false
        box.Filled = false
        box.Thickness = 2
        box.Color = boxColor
        box.Transparency = 1
        box.ZIndex = 2
        box.Center = true

        local nameText = cheat.utility.new_drawing("Text", {})
        nameText.Size = 13
        nameText.Center = true
        nameText.Font = 2
        nameText.Outline = true
        nameText.OutlineColor = Color3.new(0, 0, 0)
        nameText.Color = espColor
        nameText.ZIndex = 3

        local distText = cheat.utility.new_drawing("Text", {})
        distText.Size = 13
        distText.Center = true
        distText.Font = 2
        distText.Outline = true
        distText.OutlineColor = Color3.new(0, 0, 0)
        distText.Color = espColor
        distText.ZIndex = 3

        corpseObjects[model] = {box = box, name = nameText, dist = distText, part = part}
    end

    local function findCorpses()
        for _, child in ipairs(workspace:GetChildren()) do
            if child:IsA("Model") and not corpseObjects[child] then
                addCorpseModel(child)
            end
        end
    end

    workspace.ChildAdded:Connect(function(child)
        if child:IsA("Model") then
            task.wait()
            addCorpseModel(child)
        end
    end)

    workspace.ChildRemoved:Connect(cleanupCorpse)

    function EspModule.cleanupPlayer(player)
        if player then
            cleanupCharacter(player)
            cleanupCorpse(player)
        end
    end

    esp_section:toggle({
        name = "player esp",
        def = false,
        callback = LPH_NO_VIRTUALIZE(function(value)
            espEnabled = value
            if not value then
                for _, esp in pairs(espObjects) do
                    if esp.box then esp.box.Visible = false end
                    if esp.name then esp.name.Visible = false end
                    if esp.dist then esp.dist.Visible = false end
                end
            end
        end)
    })

    esp_section:toggle({
        name = "info esp",
        def = false,
        callback = LPH_NO_VIRTUALIZE(function(value)
            infoEsp = value
        end)
    })

    esp_section:toggle({
        name = "box esp",
        def = false,
        callback = LPH_NO_VIRTUALIZE(function(value)
            boxEsp = value
            if not value then
                for _, esp in pairs(espObjects) do
                    if esp.box then esp.box.Visible = false end
                end
                for _, esp in pairs(corpseObjects) do
                    if esp.box then esp.box.Visible = false end
                end
            end
        end)
    })

    esp_section:toggle({
        name = "corpse esp",
        def = false,
        callback = LPH_NO_VIRTUALIZE(function(value)
            corpseEsp = value
            if not value then
                for _, esp in pairs(corpseObjects) do
                    if esp.box then esp.box.Visible = false end
                    if esp.name then esp.name.Visible = false end
                    if esp.dist then esp.dist.Visible = false end
                end
            end
        end)
    })

    esp_section:toggle({
        name = "check sleeper",
        def = false,
        callback = LPH_NO_VIRTUALIZE(function(value)
            checkSleeper = value
        end)
    })

    esp_section:toggle({
        name = "check bot",
        def = false,
        callback = LPH_NO_VIRTUALIZE(function(value)
            checkBot = value
        end)
    })

    esp_section:colorpicker({
        name = "esp color",
        cpname = nil,
        def = Color3.fromRGB(255, 255, 255),
        callback = LPH_NO_VIRTUALIZE(function(value)
            espColor = value
            for _, esp in pairs(espObjects) do
                if esp.name then esp.name.Color = value end
                if esp.tool then esp.tool.Color = value end
                if esp.dist then esp.dist.Color = value end
            end
            for _, esp in pairs(corpseObjects) do
                if esp.name then esp.name.Color = value end
                if esp.dist then esp.dist.Color = value end
            end
        end)
    })

    esp_section:colorpicker({
        name = "box color",
        cpname = nil,
        def = Color3.fromRGB(255, 0, 0),
        callback = LPH_NO_VIRTUALIZE(function(value)
            boxColor = value
            for _, esp in pairs(espObjects) do
                if esp.box then esp.box.Color = value end
            end
            for _, esp in pairs(corpseObjects) do
                if esp.box then esp.box.Color = value end
            end
        end)
    })

    esp_section:slider({
        name = "max distance",
        def = 1000,
        max = 1000,
        min = 100,
        rounding = true,
        ticking = false,
        measuring = "studs",
        callback = LPH_NO_VIRTUALIZE(function(value)
            maxDistance = value
        end)
    })

    function EspModule.update(cameraPos)
        cheat.utility.anti_trace()

        if corpseEsp then
            findCorpses()
        end

        if espEnabled then
            for _, player in ipairs(playerCache) do
                local root = _FindFirstChild(player, "LowerTorso") or _FindFirstChild(player, "HumanoidRootPart")
                if root then
                    local distance = (cameraPos - root.Position).Magnitude

                    if distance <= maxDistance then
                        local sleeper = isSleeper(player)
                        local bot = isBot(player)

                        if not (checkSleeper and sleeper) and not (checkBot and bot) then
                            local screenPos, onScreen = _WorldToViewportPoint(Camera, root.Position)

                            if onScreen then
                                createPlayerEsp(player)
                                local esp = espObjects[player]
                                local boxSize = math.clamp(5000 / screenPos.Z, 25, 250)

                                esp.box.Visible = boxEsp
                                esp.box.Size = Vector2.new(boxSize, boxSize * 1.7)
                                esp.box.Position = Vector2.new(screenPos.X, screenPos.Y)
                                esp.box.Color = boxColor

                                esp.name.Visible = infoEsp
                                esp.name.Text = sleeper and "SLEEPER" or (bot and "BOT" or "PLAYER")
                                esp.name.Color = espColor
                                esp.name.Position = Vector2.new(screenPos.X, screenPos.Y - boxSize / 2 - 18)

                                esp.tool.Visible = infoEsp
                                esp.tool.Text = getHeldTool(player)
                                esp.tool.Color = espColor
                                esp.tool.Position = Vector2.new(screenPos.X, screenPos.Y - boxSize / 2 + 4)

                                esp.dist.Visible = infoEsp
                                esp.dist.Text = string.format("[%dm]", math.floor(distance))
                                esp.dist.Color = espColor
                                esp.dist.Position = Vector2.new(screenPos.X, screenPos.Y + boxSize / 2 + 5)
                            else
                                if espObjects[player] then
                                    espObjects[player].box.Visible = false
                                    espObjects[player].name.Visible = false
                                    espObjects[player].tool.Visible = false
                                    espObjects[player].dist.Visible = false
                                end
                            end
                        else
                            if espObjects[player] then
                                espObjects[player].box.Visible = false
                                espObjects[player].name.Visible = false
                                espObjects[player].tool.Visible = false
                                espObjects[player].dist.Visible = false
                            end
                        end
                    else
                        if espObjects[player] then
                            espObjects[player].box.Visible = false
                            espObjects[player].name.Visible = false
                            espObjects[player].tool.Visible = false
                            espObjects[player].dist.Visible = false
                        end
                    end
                end
            end
        else
            for _, esp in pairs(espObjects) do
                if esp.box then esp.box.Visible = false end
                if esp.name then esp.name.Visible = false end
                if esp.tool then esp.tool.Visible = false end
                if esp.dist then esp.dist.Visible = false end
            end
        end

        if corpseEsp then
            for model, esp in pairs(corpseObjects) do
                local part = esp.part
                if part and part.Parent then
                    local distance = (cameraPos - part.Position).Magnitude
                    if distance <= maxDistance then
                        local screenPos, onScreen = _WorldToViewportPoint(Camera, part.Position)
                        if onScreen then
                            esp.box.Visible = boxEsp
                            local boxSize = math.clamp(4000 / screenPos.Z, 20, 200)
                            esp.box.Size = Vector2.new(boxSize, boxSize * 0.45)
                            esp.box.Position = Vector2.new(screenPos.X, screenPos.Y)
                            esp.box.Color = boxColor

                            esp.name.Visible = true
                            esp.name.Text = "CORPSE"
                            esp.name.Color = espColor
                            esp.name.Position = Vector2.new(screenPos.X, screenPos.Y - boxSize / 2 - 15)

                            esp.dist.Visible = true
                            esp.dist.Text = string.format("[%dm]", math.floor(distance))
                            esp.dist.Color = espColor
                            esp.dist.Position = Vector2.new(screenPos.X, screenPos.Y + boxSize / 2 + 5)
                        else
                            esp.box.Visible = false
                            esp.name.Visible = false
                            esp.dist.Visible = false
                        end
                    else
                        esp.box.Visible = false
                        esp.name.Visible = false
                        esp.dist.Visible = false
                    end
                else
                    cleanupCorpse(model)
                end
            end
        else
            for _, esp in pairs(corpseObjects) do
                if esp.box then esp.box.Visible = false end
                if esp.name then esp.name.Visible = false end
                if esp.dist then esp.dist.Visible = false end
            end
        end
    end
end

return EspModule
