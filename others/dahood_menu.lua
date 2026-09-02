local library = loadstring(game:HttpGet("https://raw.githubusercontent.com/GreenDeno/Venyx-UI-Library/main/source.lua"))()
local venyx = library.new("Titan Labs", 5013109572)

local debug_enabled = false

local themes = {
    Background = Color3.fromRGB(24, 24, 24),
    Glow = Color3.fromRGB(0, 0, 0),
    Accent = Color3.fromRGB(10, 10, 10),
    LightContrast = Color3.fromRGB(20, 20, 20),
    DarkContrast = Color3.fromRGB(14, 14, 14),
    TextColor = Color3.fromRGB(255, 255, 255)
}

local settings = {
    aimbot_enabled = false,
    aimbot_logic = "Ping-Based",
    smoothness = 5,
    x_prediction = 0,
    y_prediction = 0,
    show_fov = false,
    fov_radius = 120,
    box_esp = false,
    corner_esp = false,
    health_esp = false,
    target_esp = false,
    player_fov = 70,
    bunny_hop = false,
    spinbot = false,
    fullbright = false
}

local players = game:GetService("Players")
local run_service = game:GetService("RunService")
local camera = workspace.CurrentCamera
local user_input = game:GetService("UserInputService")
local lighting = game:GetService("Lighting")

local local_player = players.LocalPlayer
local character = local_player.Character or local_player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")

local aimbot_target = nil
local locked_target = nil
local fov_circle = nil
local is_aiming = false
local esp_objects = {}

local function debug_log(...)
    if debug_enabled then
        print("[DEBUG]", ...)
    end
end

local function get_ping()
    local stats = game:GetService("Stats")
    local ping = stats.Network:GetValue("Ping")
    return ping or 50
end

local function get_prediction_offset()
    if settings.aimbot_logic == "Ping-Based" then
        local ping = get_ping()
        return math.clamp(ping / 1000 * 12, 0, 0.8)
    else
        return Vector3.new(settings.x_prediction, settings.y_prediction, 0)
    end
end

local function get_closest_player_to_crosshair()
    local closest = nil
    local shortest_distance = math.huge
    local center = camera.ViewportSize / 2
    
    for _, player in ipairs(players:GetPlayers()) do
        if player ~= local_player and player.Character and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.Health > 0 then
            local root_part = player.Character:FindFirstChild("HumanoidRootPart")
            if root_part then
                local screen_pos, on_screen = camera:WorldToScreenPoint(root_part.Position)
                if on_screen then
                    local distance = (Vector2.new(screen_pos.X, screen_pos.Y) - center).Magnitude
                    if distance < settings.fov_radius and distance < shortest_distance then
                        shortest_distance = distance
                        closest = player
                    end
                end
            end
        end
    end
    return closest
end

local function get_predicted_position(player)
    if not player or not player.Character then return nil end
    local root_part = player.Character:FindFirstChild("HumanoidRootPart")
    if not root_part then return nil end
    
    local velocity = root_part.Velocity
    local offset = get_prediction_offset()
    
    if settings.aimbot_logic == "Ping-Based" then
        return root_part.Position + (velocity * offset)
    else
        local pred_x = velocity.X * settings.x_prediction / 100
        local pred_y = velocity.Y * settings.y_prediction / 100 + 1.5
        local pred_z = velocity.Z * settings.x_prediction / 100
        return root_part.Position + Vector3.new(pred_x, pred_y, pred_z)
    end
end

local function create_fov_circle()
    if fov_circle then fov_circle:Remove() end
    fov_circle = Drawing.new("Circle")
    fov_circle.Radius = settings.fov_radius
    fov_circle.Thickness = 2
    fov_circle.Color = Color3.fromRGB(255, 255, 255)
    fov_circle.Transparency = 0.5
    fov_circle.Visible = settings.show_fov
    fov_circle.Filled = false
    fov_circle.Position = camera.ViewportSize / 2
end

local function update_fov_circle()
    if fov_circle then
        fov_circle.Radius = settings.fov_radius
        fov_circle.Position = camera.ViewportSize / 2
        fov_circle.Visible = settings.show_fov
    end
end

local function update_camera_fov()
    camera.FieldOfView = settings.player_fov
end

local function toggle_fullbright(enabled)
    if enabled then
        lighting.Ambient = Color3.fromRGB(255, 255, 255)
        lighting.Brightness = 2
        lighting.GlobalShadows = false
        lighting.ClockTime = 12
    else
        lighting.Ambient = Color3.fromRGB(127, 127, 127)
        lighting.Brightness = 1
        lighting.GlobalShadows = true
    end
end

local function clear_esp_objects()
    for _, obj in ipairs(esp_objects) do
        pcall(function() obj:Remove() end)
    end
    esp_objects = {}
end

local function get_esp_coords(player)
    if not player or not player.Character then
        return nil
    end

    local character = player.Character
    local humanoid = character:FindFirstChildOfClass("Humanoid")

    if not humanoid or humanoid.Health <= 0 then
        return nil
    end

    local bounding_cframe, bounding_size = character:GetBoundingBox()

    local half_size = bounding_size / 2

    local corners = {
        Vector3.new(-half_size.X, -half_size.Y, -half_size.Z),
        Vector3.new(-half_size.X, -half_size.Y,  half_size.Z),
        Vector3.new(-half_size.X,  half_size.Y, -half_size.Z),
        Vector3.new(-half_size.X,  half_size.Y,  half_size.Z),
        Vector3.new( half_size.X, -half_size.Y, -half_size.Z),
        Vector3.new( half_size.X, -half_size.Y,  half_size.Z),
        Vector3.new( half_size.X,  half_size.Y, -half_size.Z),
        Vector3.new( half_size.X,  half_size.Y,  half_size.Z)
    }

    local min_x = math.huge
    local min_y = math.huge
    local max_x = -math.huge
    local max_y = -math.huge

    local visible = false

    for _, corner in ipairs(corners) do
        local world_position = bounding_cframe:PointToWorldSpace(corner)

        local screen_position, on_screen =
            camera:WorldToViewportPoint(world_position)

        if screen_position.Z > 0 then
            visible = true

            min_x = math.min(min_x, screen_position.X)
            min_y = math.min(min_y, screen_position.Y)
            max_x = math.max(max_x, screen_position.X)
            max_y = math.max(max_y, screen_position.Y)
        end
    end

    if not visible then
        return nil
    end

    local width = max_x - min_x
    local height = max_y - min_y

    if width <= 1 or height <= 1 then
        return nil
    end

    return {
        top = min_y,
        bottom = max_y,
        left = min_x,
        right = max_x,
        width = width,
        height = height,
        center_x = (min_x + max_x) / 2,
        center_y = (min_y + max_y) / 2,
        top_left = Vector2.new(min_x, min_y),
        top_right = Vector2.new(max_x, min_y),
        bottom_left = Vector2.new(min_x, max_y),
        bottom_right = Vector2.new(max_x, max_y),
        center = Vector2.new(
            (min_x + max_x) / 2,
            (min_y + max_y) / 2
        )
    }
end

local function draw_esp()
    clear_esp_objects()
    
    for _, player in ipairs(players:GetPlayers()) do
        if player ~= local_player then
            local coords = get_esp_coords(player)
            if coords then
                local is_target = (player == aimbot_target and settings.target_esp)
                local esp_color = is_target and Color3.fromRGB(255, 50, 50) or Color3.fromRGB(50, 255, 50)
                
                if settings.box_esp then
                    local box = Drawing.new("Square")
                    box.Size = Vector2.new(coords.width, coords.height)
                    box.Position = coords.top_left
                    box.Color = esp_color
                    box.Thickness = 2
                    box.Transparency = 0.2
                    box.Visible = true
                    table.insert(esp_objects, box)
                end
                
                if settings.corner_esp then
                    local corner_length = math.min(coords.width, coords.height) / 5
                    local corners = {
                        {coords.top_left, Vector2.new(coords.top_left.X + corner_length, coords.top_left.Y), Vector2.new(coords.top_left.X, coords.top_left.Y + corner_length)},
                        {coords.top_right, Vector2.new(coords.top_right.X - corner_length, coords.top_right.Y), Vector2.new(coords.top_right.X, coords.top_right.Y + corner_length)},
                        {coords.bottom_left, Vector2.new(coords.bottom_left.X + corner_length, coords.bottom_left.Y), Vector2.new(coords.bottom_left.X, coords.bottom_left.Y - corner_length)},
                        {coords.bottom_right, Vector2.new(coords.bottom_right.X - corner_length, coords.bottom_right.Y), Vector2.new(coords.bottom_right.X, coords.bottom_right.Y - corner_length)}
                    }
                    for _, corner in ipairs(corners) do
                        local line1 = Drawing.new("Line")
                        line1.From = corner[1]
                        line1.To = corner[2]
                        line1.Color = esp_color
                        line1.Thickness = 2
                        line1.Transparency = 0.2
                        line1.Visible = true
                        table.insert(esp_objects, line1)
                        
                        local line2 = Drawing.new("Line")
                        line2.From = corner[1]
                        line2.To = corner[3]
                        line2.Color = esp_color
                        line2.Thickness = 2
                        line2.Transparency = 0.2
                        line2.Visible = true
                        table.insert(esp_objects, line2)
                    end
                end
                
                if settings.health_esp then
                    local health = player.Character.Humanoid.Health
                    local max_health = player.Character.Humanoid.MaxHealth
                    local health_percent = health / max_health * 100
                    local health_color = Color3.fromRGB(255 - (health_percent * 2.55), health_percent * 2.55, 0)
                    
                    local health_text = Drawing.new("Text")
                    health_text.Text = string.format("%.0f HP", health)
                    health_text.Position = Vector2.new(coords.center.X, coords.top_left.Y - 25)
                    health_text.Color = health_color
                    health_text.Size = 16
                    health_text.Center = true
                    health_text.Visible = true
                    table.insert(esp_objects, health_text)
                    
                    local health_bar_bg = Drawing.new("Square")
                    health_bar_bg.Size = Vector2.new(coords.width, 4)
                    health_bar_bg.Position = Vector2.new(coords.top_left.X, coords.top_left.Y - 20)
                    health_bar_bg.Color = Color3.fromRGB(50, 50, 50)
                    health_bar_bg.Thickness = 0
                    health_bar_bg.Filled = true
                    health_bar_bg.Transparency = 0.5
                    health_bar_bg.Visible = true
                    table.insert(esp_objects, health_bar_bg)
                    
                    local health_bar = Drawing.new("Square")
                    health_bar.Size = Vector2.new(coords.width * (health_percent / 100), 4)
                    health_bar.Position = Vector2.new(coords.top_left.X, coords.top_left.Y - 20)
                    health_bar.Color = health_color
                    health_bar.Thickness = 0
                    health_bar.Filled = true
                    health_bar.Transparency = 0.2
                    health_bar.Visible = true
                    table.insert(esp_objects, health_bar)
                end
                
                if settings.target_esp and is_target then
                    local target_indicator = Drawing.new("Text")
                    target_indicator.Text = "◄ TARGET ►"
                    target_indicator.Position = Vector2.new(coords.center.X, coords.top_left.Y - 45)
                    target_indicator.Color = Color3.fromRGB(255, 0, 0)
                    target_indicator.Size = 18
                    target_indicator.Center = true
                    target_indicator.Visible = true
                    table.insert(esp_objects, target_indicator)
                    
                    local glow_box = Drawing.new("Square")
                    glow_box.Size = Vector2.new(coords.width + 10, coords.height + 10)
                    glow_box.Position = Vector2.new(coords.top_left.X - 5, coords.top_left.Y - 5)
                    glow_box.Color = Color3.fromRGB(255, 0, 0)
                    glow_box.Thickness = 3
                    glow_box.Transparency = 0.4
                    glow_box.Visible = true
                    table.insert(esp_objects, glow_box)
                end
            end
        end
    end
end

local function is_player_valid(player)
    if not player or not player.Character then return false end
    local humanoid = player.Character:FindFirstChild("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return false end
    return true
end

local function camlock()
    if not settings.aimbot_enabled or not is_aiming then return end
    
    if locked_target and is_player_valid(locked_target) then
        local predicted_pos = get_predicted_position(locked_target)
        if predicted_pos then
            local current_cframe = camera.CFrame
            local target_cframe = CFrame.new(current_cframe.Position, predicted_pos)
            
            if settings.smoothness > 0 then
                local smooth_factor = math.clamp(1 / (settings.smoothness * 1.2), 0.01, 0.6)
                camera.CFrame = current_cframe:Lerp(target_cframe, smooth_factor)
            else
                camera.CFrame = target_cframe
            end
            aimbot_target = locked_target
            return
        end
    end
    
    local target = get_closest_player_to_crosshair()
    if target then
        locked_target = target
        aimbot_target = target
        local predicted_pos = get_predicted_position(target)
        if predicted_pos then
            local current_cframe = camera.CFrame
            local target_cframe = CFrame.new(current_cframe.Position, predicted_pos)
            
            if settings.smoothness > 0 then
                local smooth_factor = math.clamp(1 / (settings.smoothness * 1.2), 0.01, 0.6)
                camera.CFrame = current_cframe:Lerp(target_cframe, smooth_factor)
            else
                camera.CFrame = target_cframe
            end
        end
    else
        aimbot_target = nil
        locked_target = nil
    end
end

local function bunny_hop_logic()
    if settings.bunny_hop and humanoid and humanoid.MoveDirection.Magnitude > 0 then
        if humanoid.FloorMaterial ~= Enum.Material.Air then
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end

local function spinbot_logic()
    if settings.spinbot and character and character:FindFirstChild("HumanoidRootPart") then
        local root = character.HumanoidRootPart
        root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(720 * run_service.RenderStepped:Wait()), 0)
    end
end

user_input.InputBegan:Connect(function(input, game_processed)
    if game_processed then return end
    
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        is_aiming = true
        locked_target = nil
        debug_log("Aiming started")
    end
end)

user_input.InputEnded:Connect(function(input, game_processed)
    if game_processed then return end
    
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        is_aiming = false
        aimbot_target = nil
        locked_target = nil
        debug_log("Aiming stopped")
    end
end)

run_service.RenderStepped:Connect(function()
    if settings.aimbot_enabled and is_aiming then
        camlock()
    end
    
    if settings.box_esp or settings.corner_esp or settings.health_esp or settings.target_esp then
        draw_esp()
    else
        clear_esp_objects()
    end
    
    if settings.bunny_hop then
        bunny_hop_logic()
    end
    
    if settings.spinbot then
        spinbot_logic()
    end
    
    if settings.show_fov and fov_circle then
        update_fov_circle()
    end
end)

local page1 = venyx:addPage("Aimbot", 5012544693)
local aimbot_section = page1:addSection("Aimbot Settings")

aimbot_section:addToggle("Aimbot Enabled", nil, function(value)
    settings.aimbot_enabled = value
    if not value then
        is_aiming = false
        aimbot_target = nil
        locked_target = nil
    end
    debug_log("Aimbot toggled:", value)
end)

aimbot_section:addDropdown("Aimbot Logic", {"Prediction-Based", "Ping-Based"}, function(text)
    settings.aimbot_logic = text
    debug_log("Aimbot logic set to:", text)
end)

aimbot_section:addSlider("Smoothness", settings.smoothness, 1, 20, function(value)
    settings.smoothness = math.floor(value)
    debug_log("Smoothness set to:", settings.smoothness)
end)

aimbot_section:addSlider("X Prediction", settings.x_prediction, 0, 20, function(value)
    settings.x_prediction = value
    debug_log("X Prediction set to:", settings.x_prediction)
end)

aimbot_section:addSlider("Y Prediction", settings.y_prediction, 0, 20, function(value)
    settings.y_prediction = value
    debug_log("Y Prediction set to:", settings.y_prediction)
end)

aimbot_section:addToggle("Show FOV Radius", nil, function(value)
    settings.show_fov = value
    if value then
        create_fov_circle()
    elseif fov_circle then
        fov_circle.Visible = false
    end
    debug_log("FOV visibility:", value)
end)

aimbot_section:addSlider("FOV Radius", settings.fov_radius, 80, 500, function(value)
    settings.fov_radius = math.floor(value)
    update_fov_circle()
    debug_log("FOV radius set to:", settings.fov_radius)
end)

local page2 = venyx:addPage("Visuals", 5012544693)
local visuals_section = page2:addSection("ESP Settings")

visuals_section:addToggle("Box ESP", nil, function(value)
    settings.box_esp = value
    if not value then clear_esp_objects() end
    debug_log("Box ESP:", value)
end)

visuals_section:addToggle("Corner ESP", nil, function(value)
    settings.corner_esp = value
    if not value then clear_esp_objects() end
    debug_log("Corner ESP:", value)
end)

visuals_section:addToggle("Health ESP", nil, function(value)
    settings.health_esp = value
    if not value then clear_esp_objects() end
    debug_log("Health ESP:", value)
end)

visuals_section:addToggle("Target ESP", nil, function(value)
    settings.target_esp = value
    if not value then clear_esp_objects() end
    debug_log("Target ESP:", value)
end)

local page3 = venyx:addPage("Player", 5012544693)
local player_section = page3:addSection("Player Settings")

player_section:addSlider("Player FOV", settings.player_fov, 1, 120, function(value)
    settings.player_fov = math.floor(value)
    update_camera_fov()
    debug_log("Player FOV set to:", settings.player_fov)
end)

player_section:addToggle("Bunny Hop", nil, function(value)
    settings.bunny_hop = value
    debug_log("Bunny Hop:", value)
end)

player_section:addToggle("Spinbot", nil, function(value)
    settings.spinbot = value
    debug_log("Spinbot:", value)
end)

player_section:addToggle("Fullbright", nil, function(value)
    settings.fullbright = value
    toggle_fullbright(value)
    debug_log("Fullbright:", value)
end)

local theme_page = venyx:addPage("Theme", 5012544693)
local colors_section = theme_page:addSection("Colors")

for theme, color in pairs(themes) do
    colors_section:addColorPicker(theme, color, function(color3)
        venyx:setTheme(theme, color3)
        debug_log("Theme updated:", theme)
    end)
end

venyx:SelectPage(venyx.pages[1], true)
create_fov_circle()
update_camera_fov()

debug_log("Script loaded successfully")
