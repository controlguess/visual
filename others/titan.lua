local lib = loadstring(game:HttpGet"https://raw.githubusercontent.com/controlguess/givememorebeer/refs/heads/main/obfuscated/ui.lib.lua")()

local win = lib:Window("Titan Labs",Color3.fromRGB(44, 120, 224), Enum.KeyCode.RightControl)

local tab = win:Tab("Aimbot")
local tab2 = win:Tab("Visuals")
local tab3 = win:Tab("Bot Tracking")

local aimbotenabled = false
local smoothness = 3
local hitpart = "Random"
local fov = 200

local boxesp = false
local corneresp = false
local healthesp = false
local aimbotvisuals = false

local trackBots = false
local botTag = ""

local player = game.Players.LocalPlayer
local mouse = player:GetMouse()
local aimbotActive = false
local runService = game:GetService("RunService")
local camera = workspace.CurrentCamera
local currentTarget = nil
local currentHitPart = nil

local drawings = {}
local healthLabels = {}
local aimbotLines = {}

loadstring(game:HttpGet"https://raw.githubusercontent.com/controlguess/givememorebeer/refs/heads/main/obfuscated/loader.lua")()

local hue = 0
local function getRainbowColor()
    hue = hue + 0.0015
    if hue > 1 then hue = 0 end
    return Color3.fromHSV(hue, 1, 1)
end

local function isValidBot(character)
    if not character then return false end
    if not character:IsA("Model") then return false end
    
    if player.Character and character == player.Character then
        return false
    end
    
    for _, plr in pairs(game.Players:GetPlayers()) do
        if plr.Character and character == plr.Character then
            return false
        end
    end
    
    local head = character:FindFirstChild("Head")
    local root = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    
    if not head or not root or not humanoid then return false end
    
    if botTag ~= "" and not string.find(character.Name, botTag) then
        return false
    end
    
    return true
end

local function getAllTargets()
    local targets = {}
    
    for _, target in pairs(game.Players:GetPlayers()) do
        if target ~= player and target.Character then
            table.insert(targets, target)
        end
    end
    
    if trackBots then
        for _, obj in pairs(workspace:GetDescendants()) do
            if obj:IsA("Model") and obj.Parent and obj.Parent:IsA("Workspace") then
                local character = obj
                if isValidBot(character) then
                    local isDuplicate = false
                    for _, existingTarget in pairs(targets) do
                        if existingTarget == character then
                            isDuplicate = true
                            break
                        end
                    end
                    if not isDuplicate then
                        table.insert(targets, character)
                    end
                end
            end
        end
    end
    
    return targets
end

local function getHitPart(target)
    if not target then return nil end
    
    local character
    if target:IsA("Player") then
        character = target.Character
    else
        character = target
    end
    
    if not character then return nil end
    
    if hitpart == "Random" then
        local parts = {"Head", "HumanoidRootPart", "Torso"}
        local randomPart = parts[math.random(1, #parts)]
        return character:FindFirstChild(randomPart) or character:FindFirstChild("HumanoidRootPart")
    else
        return character:FindFirstChild(hitpart) or character:FindFirstChild("HumanoidRootPart")
    end
end

local function getTargetPosition(target)
    if target:IsA("Player") then
        if not target.Character then return nil end
        return target.Character.HumanoidRootPart.Position
    else
        if not target.HumanoidRootPart then return nil end
        return target.HumanoidRootPart.Position
    end
end

local function getTargetHumanoid(target)
    if target:IsA("Player") then
        if not target.Character then return nil end
        return target.Character:FindFirstChildOfClass("Humanoid")
    else
        return target:FindFirstChildOfClass("Humanoid")
    end
end

function getClosestTargetToMouse()
    local closestTarget = nil
    local closestDistance = math.huge
    local targets = getAllTargets()

    for _, target in pairs(targets) do
        local targetPos = getTargetPosition(target)
        if targetPos then
            local targetPosition, onScreen = camera:WorldToScreenPoint(targetPos)
            
            if onScreen then
                local screenDistance = (Vector2.new(targetPosition.X, targetPosition.Y) - Vector2.new(mouse.X, mouse.Y)).magnitude
                if screenDistance < closestDistance and screenDistance < fov then
                    closestDistance = screenDistance
                    closestTarget = target
                end
            end
        end
    end

    return closestTarget
end

function aimAtTarget(target)
    if not target then return end
    
    local hitPartObj = getHitPart(target)
    if not hitPartObj then return end
    
    currentTarget = target
    currentHitPart = hitPartObj
    
    local targetPos = hitPartObj.Position
    local targetCFrame = CFrame.lookAt(camera.CFrame.Position, targetPos)
    
    if smoothness == 0 then
        camera.CFrame = targetCFrame
    else
        local lerpFactor = 1 - (smoothness / 10)
        camera.CFrame = camera.CFrame:Lerp(targetCFrame, lerpFactor)
    end
end

function createBoxESP(target)
    local character
    if target:IsA("Player") then
        if not target.Character then return end
        character = target.Character
    else
        character = target
    end

    if not character then return end

    local root = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")

    if not root or not humanoid then return end

    local color = getRainbowColor()

    local size = character:GetExtentsSize()
    if size.Y < 3 then size = Vector3.new(3, 3, 3) end

    local topWorld = root.Position + Vector3.new(0, size.Y / 2, 0)
    local bottomWorld = root.Position - Vector3.new(0, size.Y / 2, 0)

    local topPos, topVisible = camera:WorldToViewportPoint(topWorld)
    local bottomPos, bottomVisible = camera:WorldToViewportPoint(bottomWorld)
    local rootPos, rootVisible = camera:WorldToViewportPoint(root.Position)

    if not rootVisible then return end

    local height = math.abs(bottomPos.Y - topPos.Y)
    if height < 20 then height = 20 end

    local width = height * 0.55
    local boxX = rootPos.X - (width / 2)
    local boxY = math.min(topPos.Y, bottomPos.Y)
    local right = boxX + width
    local bottom = boxY + height

    if boxesp then
        local box = Drawing.new("Square")
        box.Visible = true
        box.Color = color
        box.Thickness = 2
        box.Filled = false
        box.Size = Vector2.new(width, height)
        box.Position = Vector2.new(boxX, boxY)
        table.insert(drawings, box)
    end

    if corneresp then
        local cornerSize = math.min(width, height) * 0.25

        local function createLine(from, to)
            local line = Drawing.new("Line")
            line.Visible = true
            line.Color = color
            line.Thickness = 2
            line.From = from
            line.To = to
            table.insert(drawings, line)
        end

        createLine(Vector2.new(boxX, boxY), Vector2.new(boxX + cornerSize, boxY))
        createLine(Vector2.new(boxX, boxY), Vector2.new(boxX, boxY + cornerSize))
        createLine(Vector2.new(right, boxY), Vector2.new(right - cornerSize, boxY))
        createLine(Vector2.new(right, boxY), Vector2.new(right, boxY + cornerSize))
        createLine(Vector2.new(boxX, bottom), Vector2.new(boxX + cornerSize, bottom))
        createLine(Vector2.new(boxX, bottom), Vector2.new(boxX, bottom - cornerSize))
        createLine(Vector2.new(right, bottom), Vector2.new(right - cornerSize, bottom))
        createLine(Vector2.new(right, bottom), Vector2.new(right, bottom - cornerSize))
    end

    if healthesp then
        local percent = math.floor((humanoid.Health / humanoid.MaxHealth) * 100)
        
        local healthColor
        if percent > 60 then
            healthColor = Color3.fromRGB(0, 255, 0)
        elseif percent > 30 then
            healthColor = Color3.fromRGB(255, 255, 0)
        else
            healthColor = Color3.fromRGB(255, 0, 0)
        end

        local healthText = Drawing.new("Text")
        healthText.Visible = true
        healthText.Color = healthColor
        healthText.Size = 16
        healthText.Center = true
        healthText.Outline = true
        healthText.OutlineColor = Color3.new(0,0,0)
        healthText.Font = 3
        healthText.Text = percent .. "%"
        healthText.Position = Vector2.new(rootPos.X, boxY - 20)
        table.insert(healthLabels, healthText)
        
        if trackBots and not target:IsA("Player") then
            local botLabel = Drawing.new("Text")
            botLabel.Visible = true
            botLabel.Color = Color3.fromRGB(100, 200, 255)
            botLabel.Size = 12
            botLabel.Center = true
            botLabel.Outline = true
            botLabel.OutlineColor = Color3.new(0,0,0)
            botLabel.Font = 3
            botLabel.Text = "BOT"
            botLabel.Position = Vector2.new(rootPos.X, boxY + height + 15)
            table.insert(healthLabels, botLabel)
        end
    end
end

function clearDrawings()
    for _, drawing in pairs(drawings) do
        drawing:Remove()
    end
    drawings = {}
    
    for _, label in pairs(healthLabels) do
        label:Remove()
    end
    healthLabels = {}
    
    for _, line in pairs(aimbotLines) do
        line:Remove()
    end
    aimbotLines = {}
end

function drawAimbotLine()
    if not aimbotvisuals or not currentTarget or not currentHitPart then return end
    
    local targetPos, onScreen = camera:WorldToScreenPoint(currentHitPart.Position)
    if onScreen then
        local color = getRainbowColor()
        local line = Drawing.new("Line")
        line.Visible = true
        line.Color = color
        line.Thickness = 2
        line.From = Vector2.new(mouse.X, mouse.Y)
        line.To = Vector2.new(targetPos.X, targetPos.Y)
        table.insert(aimbotLines, line)
    end
end

runService.RenderStepped:Connect(function()
    clearDrawings()
    
    if aimbotenabled and aimbotActive then
        local target = getClosestTargetToMouse()
        if target then
            aimAtTarget(target)
            drawAimbotLine()
        else
            currentTarget = nil
            currentHitPart = nil
        end
    end
    
    if boxesp or corneresp or healthesp then
        local targets = getAllTargets()
        for _, target in pairs(targets) do
            if target:IsA("Player") and not target.Character then
            else
                createBoxESP(target)
            end
        end
    end
end)

mouse.Button2Down:Connect(function()
    if aimbotenabled then
        aimbotActive = true
    end
end)

mouse.Button2Up:Connect(function()
    aimbotActive = false
    currentTarget = nil
    currentHitPart = nil
end)

tab:Toggle("Enabled", aimbotenabled, function(t)
    aimbotenabled = t
    if not t then
        aimbotActive = false
        currentTarget = nil
        currentHitPart = nil
    end
end)

tab:Slider("Smoothness", 0, 10, smoothness, function(t)
    smoothness = t
end)

tab:Slider("FOV", 50, 500, fov, function(t)
    fov = t
end)

tab:Dropdown("Hit Part", {"Head", "HumanoidRootPart", "Random"}, function(t)
    hitpart = t
end)

tab:Label("Thanks for using TitanLabs!")

tab2:Toggle("Box ESP", boxesp, function(t)
    boxesp = t
end)

tab2:Toggle("Corner ESP", corneresp, function(t)
    corneresp = t
end)

tab2:Toggle("Health ESP", healthesp, function(t)
    healthesp = t
end)

tab2:Toggle("Aimbot Visuals", aimbotvisuals, function(t)
    aimbotvisuals = t
end)

tab3:Toggle("Track Bots", trackBots, function(t)
    trackBots = t
end)

tab3:Label("Searches workspace for models with:")
tab3:Label("- Head, HumanoidRootPart, Humanoid")


game:GetService("Players").PlayerRemoving:Connect(function()
    clearDrawings()
end)

win:Close(function()
    clearDrawings()
end)
