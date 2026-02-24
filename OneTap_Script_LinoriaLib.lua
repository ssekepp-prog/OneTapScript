--[[
    One Tap V3 - Premium Edition with LinoriaLib
    Совместимость: Xeno, Krnl, Synapse, Fluxus
    Игра: [FPS] One Tap
]]

-- Защита от повторного запуска
if getgenv().OneTapLoaded then
    warn("Скрипт уже загружен!")
    return
end
getgenv().OneTapLoaded = true

-- Загрузка LinoriaLib
local repo = 'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/'
local Library = loadstring(game:HttpGet(repo .. 'Library.lua'))()
local ThemeManager = loadstring(game:HttpGet(repo .. 'addons/ThemeManager.lua'))()
local SaveManager = loadstring(game:HttpGet(repo .. 'addons/SaveManager.lua'))()

-- Сервисы
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

-- Настройки по умолчанию
local Settings = {
    Aimbot = {
        Enabled = false,
        SilentAim = false,
        FOV = 150,
        ShowFOV = true,
        Smoothness = 0.2,
        TargetPart = "Head",
        MaxDistance = 300,
        WallCheck = true,
        TargetPriority = "Closest to Crosshair",
        FOVColor = Color3.fromRGB(255, 255, 255),
        FOVThickness = 2,
        FOVFilled = false,
        FOVTransparency = 0.5
    },
    AutoShoot = {
        Enabled = false,
        CPS = 10,
        TriggerDelay = 0,
        AutoShootKey = "None"
    },
    Wallbang = {
        IgnoreWalls = false,
        WallbangMode = "Always",
        WallPenetration = 100
    },
    Visual = {
        CameraFOV = 70,
        HighlightTarget = true,
        HighlightColor = Color3.fromRGB(255, 215, 0),
        HighlightThickness = 3
    },
    ESP = {
        Enabled = false,
        Boxes = true,
        Names = true,
        Health = true,
        Distance = true,
        Tracers = false,
        BoxColor = Color3.fromRGB(255, 0, 0),
        NameColor = Color3.fromRGB(255, 255, 255),
        HealthColor = Color3.fromRGB(0, 255, 0),
        TracerColor = Color3.fromRGB(255, 255, 255)
    },
    ThirdPerson = {
        Enabled = false,
        Distance = 5
    },
    Spinbot = {
        Enabled = false,
        Speed = 20,
        Axis = "Yaw",
        Jitter = false,
        JitterAmount = 3
    },
    BunnyHop = {
        Enabled = false,
        HoldKey = "Space",
        AutoStrafe = false,
        MinSpeed = 10
    }
}

-- Переменные
local ESPObjects = {}
local NPCList = {}
local FOVCircle = Drawing.new("Circle")
local lastShootTime = 0
local currentTarget = nil
local autoShootKeyPressed = false
local originalCameraType = nil
local originalCameraSubject = nil
local spinAngle = 0
local lastJumpTime = 0
local bhopKeyPressed = false
local originalCameraFOV = Camera.FieldOfView or 70
local targetHighlight = nil
local isSilentAiming = false
local savedCameraCFrame = nil

-- Инициализация FOV круга
FOVCircle.Thickness = Settings.Aimbot.FOVThickness
FOVCircle.NumSides = 50
FOVCircle.Radius = Settings.Aimbot.FOV
FOVCircle.Color = Settings.Aimbot.FOVColor
FOVCircle.Visible = Settings.Aimbot.ShowFOV
FOVCircle.Filled = Settings.Aimbot.FOVFilled
FOVCircle.Transparency = Settings.Aimbot.FOVTransparency

-- Функция получения всех целей (игроки + NPC)
local function GetAllTargets()
    local targets = {}
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local humanoid = player.Character:FindFirstChild("Humanoid")
            local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
            if humanoid and humanoid.Health > 0 and rootPart then
                table.insert(targets, {
                    Type = "Player",
                    Instance = player,
                    Character = player.Character,
                    Name = player.Name
                })
            end
        end
    end
    
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and obj ~= LocalPlayer.Character then
            local humanoid = obj:FindFirstChild("Humanoid")
            local rootPart = obj:FindFirstChild("HumanoidRootPart")
            if humanoid and humanoid.Health > 0 and rootPart then
                local isPlayer = false
                for _, player in pairs(Players:GetPlayers()) do
                    if player.Character == obj then
                        isPlayer = true
                        break
                    end
                end
                if not isPlayer then
                    table.insert(targets, {
                        Type = "NPC",
                        Instance = obj,
                        Character = obj,
                        Name = obj.Name or "Bot"
                    })
                    NPCList[obj] = true
                end
            end
        end
    end
    
    return targets
end

-- Функция проверки видимости
local function IsVisible(targetPart)
    if Settings.Wallbang.IgnoreWalls then
        if Settings.Wallbang.WallbangMode == "Always" then
            return true
        elseif Settings.Wallbang.WallbangMode == "Penetration" then
            return math.random(1, 100) <= Settings.Wallbang.WallPenetration
        end
    end
    
    if not Settings.Aimbot.WallCheck then
        return true
    end
    
    local character = LocalPlayer.Character
    if not character then return false end
    
    local origin = Camera.CFrame.Position
    local direction = (targetPart.Position - origin).Unit * (targetPart.Position - origin).Magnitude
    
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {character, targetPart.Parent}
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.IgnoreWater = true
    
    local rayResult = workspace:Raycast(origin, direction, raycastParams)
    
    return rayResult == nil or rayResult.Instance:IsDescendantOf(targetPart.Parent)
end

-- Функция получения ближайшего врага
local function GetClosestEnemy()
    local closestTarget = nil
    local bestValue = math.huge
    
    local mousePos = Vector2.new(Mouse.X, Mouse.Y)
    local viewportCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    
    local targets = GetAllTargets()
    
    for _, target in pairs(targets) do
        local character = target.Character
        if character then
            local humanoid = character:FindFirstChild("Humanoid")
            local targetPart = character:FindFirstChild(Settings.Aimbot.TargetPart)
            
            if not targetPart then
                targetPart = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
            end
            
            if humanoid and humanoid.Health > 0 and targetPart then
                local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
                
                if onScreen then
                    local screenPoint = Vector2.new(screenPos.X, screenPos.Y)
                    local distanceFromCenter = (screenPoint - viewportCenter).Magnitude
                    
                    if distanceFromCenter <= Settings.Aimbot.FOV then
                        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                            local distance3D = (LocalPlayer.Character.HumanoidRootPart.Position - targetPart.Position).Magnitude
                            
                            if distance3D <= Settings.Aimbot.MaxDistance then
                                if IsVisible(targetPart) then
                                    local currentValue = 0
                                    
                                    if Settings.Aimbot.TargetPriority == "Closest to Crosshair" then
                                        currentValue = distanceFromCenter
                                    elseif Settings.Aimbot.TargetPriority == "Lowest Health" then
                                        currentValue = humanoid.Health
                                    elseif Settings.Aimbot.TargetPriority == "Closest Distance" then
                                        currentValue = distance3D
                                    end
                                    
                                    if currentValue < bestValue then
                                        bestValue = currentValue
                                        closestTarget = target
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    return closestTarget
end

-- Функция наведения
local function AimAt(targetPart)
    if not targetPart then return end
    
    local targetPos = targetPart.Position
    local cameraPos = Camera.CFrame.Position
    
    local direction = (targetPos - cameraPos).Unit
    local targetCFrame = CFrame.new(cameraPos, cameraPos + direction)
    
    if Settings.Aimbot.Smoothness > 0 then
        Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, 1 - Settings.Aimbot.Smoothness)
    else
        Camera.CFrame = targetCFrame
    end
end

-- Создание подсветки цели
local function CreateTargetHighlight()
    if targetHighlight then
        targetHighlight:Remove()
    end
    
    targetHighlight = Drawing.new("Square")
    targetHighlight.Thickness = Settings.Visual.HighlightThickness
    targetHighlight.Color = Settings.Visual.HighlightColor
    targetHighlight.Filled = false
    targetHighlight.Transparency = 1
    targetHighlight.Visible = false
end

-- Обновление подсветки цели
local function UpdateTargetHighlight()
    if not Settings.Visual.HighlightTarget or not currentTarget then
        if targetHighlight then
            targetHighlight.Visible = false
        end
        return
    end
    
    if not targetHighlight then
        CreateTargetHighlight()
    end
    
    if currentTarget and currentTarget.Character then
        local targetPart = currentTarget.Character:FindFirstChild(Settings.Aimbot.TargetPart)
        if not targetPart then
            targetPart = currentTarget.Character:FindFirstChild("Head") or currentTarget.Character:FindFirstChild("HumanoidRootPart")
        end
        
        if targetPart then
            local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
            if onScreen then
                local size = Vector2.new(50, 50)
                targetHighlight.Size = size
                targetHighlight.Position = Vector2.new(screenPos.X - size.X / 2, screenPos.Y - size.Y / 2)
                targetHighlight.Color = Settings.Visual.HighlightColor
                targetHighlight.Thickness = Settings.Visual.HighlightThickness
                targetHighlight.Visible = true
            else
                targetHighlight.Visible = false
            end
        else
            targetHighlight.Visible = false
        end
    else
        targetHighlight.Visible = false
    end
end

-- Silent Aim с улучшенной точностью и предсказанием
Mouse.Button1Down:Connect(function()
    if not Settings.Aimbot.SilentAim then return end
    if not Settings.Aimbot.Enabled then return end
    if not currentTarget or not currentTarget.Character then return end
    if isSilentAiming then return end
    
    local targetPart = currentTarget.Character:FindFirstChild(Settings.Aimbot.TargetPart)
    if not targetPart then
        targetPart = currentTarget.Character:FindFirstChild("Head") or currentTarget.Character:FindFirstChild("HumanoidRootPart")
    end
    
    if targetPart then
        isSilentAiming = true
        savedCameraCFrame = Camera.CFrame
        
        -- Предсказание позиции цели (velocity prediction)
        local targetPos = targetPart.Position
        local targetVelocity = targetPart.AssemblyLinearVelocity or Vector3.new(0, 0, 0)
        local distance = (targetPos - Camera.CFrame.Position).Magnitude
        local bulletSpeed = 1000 -- Примерная скорость пули
        local timeToHit = distance / bulletSpeed
        
        -- Предсказываем позицию с учётом движения
        local predictedPos = targetPos + (targetVelocity * timeToHit)
        
        -- Расширение хитбокса - целимся чуть выше центра для лучшего попадания
        if Settings.Aimbot.TargetPart == "Head" then
            predictedPos = predictedPos + Vector3.new(0, 0.2, 0)
        end
        
        local cameraPos = Camera.CFrame.Position
        local direction = (predictedPos - cameraPos).Unit
        Camera.CFrame = CFrame.new(cameraPos, cameraPos + direction)
        
        -- Удерживаем прицел на цели чуть дольше для гарантии попадания
        task.spawn(function()
            task.wait(0.05) -- Увеличено с task.wait() до 0.05 сек
            if savedCameraCFrame then
                Camera.CFrame = savedCameraCFrame
                savedCameraCFrame = nil
            end
            isSilentAiming = false
        end)
    end
end)

-- Auto Shoot
local function AutoShoot()
    if not Settings.AutoShoot.Enabled then return end
    if Settings.AutoShoot.AutoShootKey ~= "None" and not autoShootKeyPressed then return end
    
    if currentTarget then
        local currentTime = tick()
        local shootInterval = 1 / Settings.AutoShoot.CPS
        
        if currentTime - lastShootTime >= shootInterval + (Settings.AutoShoot.TriggerDelay / 1000) then
            pcall(function()
                if mouse1click then
                    mouse1click()
                elseif mouse1press and mouse1release then
                    mouse1press()
                    task.wait(0.01)
                    mouse1release()
                end
            end)
            lastShootTime = currentTime
        end
    end
end

-- Third Person
local function UpdateThirdPerson()
    if not LocalPlayer.Character then return end
    
    if Settings.ThirdPerson.Enabled then
        if not originalCameraType then
            originalCameraType = Camera.CameraType
            originalCameraSubject = Camera.CameraSubject
        end
        
        local humanoidRootPart = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if humanoidRootPart then
            local offset = Camera.CFrame.LookVector * -Settings.ThirdPerson.Distance
            Camera.CFrame = CFrame.new(humanoidRootPart.Position + offset + Vector3.new(0, 2, 0), humanoidRootPart.Position)
        end
    else
        if originalCameraType then
            Camera.CameraType = originalCameraType
            Camera.CameraSubject = originalCameraSubject
            originalCameraType = nil
            originalCameraSubject = nil
        end
    end
end

-- Spinbot
local function UpdateSpinbot()
    if not Settings.Spinbot.Enabled then return end
    if not LocalPlayer.Character then return end
    
    local humanoidRootPart = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return end
    
    local speed = Settings.Spinbot.Speed
    if Settings.Spinbot.Jitter then
        speed = speed + math.random(-Settings.Spinbot.JitterAmount, Settings.Spinbot.JitterAmount)
    end
    
    spinAngle = spinAngle + math.rad(speed)
    if spinAngle >= math.pi * 2 then
        spinAngle = 0
    end
    
    local currentCFrame = humanoidRootPart.CFrame
    
    if Settings.Spinbot.Axis == "Yaw" then
        humanoidRootPart.CFrame = CFrame.new(currentCFrame.Position) * CFrame.Angles(0, spinAngle, 0)
    elseif Settings.Spinbot.Axis == "Pitch" then
        humanoidRootPart.CFrame = CFrame.new(currentCFrame.Position) * CFrame.Angles(spinAngle, 0, 0)
    elseif Settings.Spinbot.Axis == "Both" then
        humanoidRootPart.CFrame = CFrame.new(currentCFrame.Position) * CFrame.Angles(spinAngle, spinAngle, 0)
    end
end

-- Bunny Hop
local function UpdateBunnyHop()
    if not Settings.BunnyHop.Enabled then return end
    if not LocalPlayer.Character then return end
    
    if Settings.BunnyHop.HoldKey ~= "None" and not bhopKeyPressed then
        return
    end
    
    local humanoid = LocalPlayer.Character:FindFirstChild("Humanoid")
    local humanoidRootPart = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not humanoidRootPart then return end
    
    local currentSpeed = humanoidRootPart.Velocity.Magnitude
    if currentSpeed < Settings.BunnyHop.MinSpeed then return end
    
    if humanoid.MoveDirection.Magnitude <= 0 then return end
    
    local onGround = humanoid.FloorMaterial ~= Enum.Material.Air
    
    local currentTime = tick()
    if currentTime - lastJumpTime < 0.1 then return end
    
    if onGround then
        humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        lastJumpTime = currentTime
        
        if Settings.BunnyHop.AutoStrafe then
            task.spawn(function()
                task.wait(0.05)
                if humanoidRootPart and humanoid.FloorMaterial == Enum.Material.Air then
                    local moveDir = humanoid.MoveDirection
                    if moveDir.Magnitude > 0 then
                        local strafeVelocity = Vector3.new(moveDir.X * 2, 0, moveDir.Z * 2)
                        humanoidRootPart.Velocity = humanoidRootPart.Velocity + strafeVelocity
                    end
                end
            end)
        end
    end
end

-- Camera FOV
local function UpdateCameraFOV()
    if Camera then
        Camera.FieldOfView = Settings.Visual.CameraFOV
    end
end

-- Профессиональный ESP с хелсбарами, дистанцией и трейсерами
local function CreateESP(target)
    local esp = {
        Box = Drawing.new("Square"),
        BoxOutline = Drawing.new("Square"),
        Name = Drawing.new("Text"),
        Distance = Drawing.new("Text"),
        HealthBar = Drawing.new("Square"),
        HealthBarOutline = Drawing.new("Square"),
        HealthText = Drawing.new("Text"),
        Tracer = Drawing.new("Line")
    }
    
    -- Box
    esp.Box.Thickness = 2
    esp.Box.Color = Settings.ESP.BoxColor
    esp.Box.Filled = false
    esp.Box.Transparency = 1
    esp.Box.Visible = false
    
    -- Box Outline
    esp.BoxOutline.Thickness = 3
    esp.BoxOutline.Color = Color3.fromRGB(0, 0, 0)
    esp.BoxOutline.Filled = false
    esp.BoxOutline.Transparency = 1
    esp.BoxOutline.Visible = false
    
    -- Name
    esp.Name.Size = 13
    esp.Name.Center = true
    esp.Name.Outline = true
    esp.Name.Color = Settings.ESP.NameColor
    esp.Name.Visible = false
    esp.Name.Font = 2
    
    -- Distance
    esp.Distance.Size = 12
    esp.Distance.Center = true
    esp.Distance.Outline = true
    esp.Distance.Color = Color3.fromRGB(255, 255, 255)
    esp.Distance.Visible = false
    esp.Distance.Font = 2
    
    -- Health Bar Background
    esp.HealthBarOutline.Thickness = 1
    esp.HealthBarOutline.Color = Color3.fromRGB(0, 0, 0)
    esp.HealthBarOutline.Filled = true
    esp.HealthBarOutline.Transparency = 0.5
    esp.HealthBarOutline.Visible = false
    
    -- Health Bar
    esp.HealthBar.Thickness = 1
    esp.HealthBar.Color = Settings.ESP.HealthColor
    esp.HealthBar.Filled = true
    esp.HealthBar.Transparency = 1
    esp.HealthBar.Visible = false
    
    -- Health Text
    esp.HealthText.Size = 12
    esp.HealthText.Center = true
    esp.HealthText.Outline = true
    esp.HealthText.Color = Color3.fromRGB(255, 255, 255)
    esp.HealthText.Visible = false
    esp.HealthText.Font = 2
    
    -- Tracer
    esp.Tracer.Thickness = 1
    esp.Tracer.Color = Settings.ESP.TracerColor
    esp.Tracer.Transparency = 1
    esp.Tracer.Visible = false
    
    ESPObjects[target] = esp
end

local function RemoveESP(target)
    if ESPObjects[target] then
        for _, obj in pairs(ESPObjects[target]) do
            pcall(function() obj:Remove() end)
        end
        ESPObjects[target] = nil
    end
end

local function UpdateESP(target, targetData)
    if not Settings.ESP.Enabled then
        if ESPObjects[target] then
            for _, obj in pairs(ESPObjects[target]) do
                obj.Visible = false
            end
        end
        return
    end
    
    local esp = ESPObjects[target]
    if not esp then return end
    
    local character = targetData and targetData.Character or (target.Character or target)
    if not character then
        for _, obj in pairs(esp) do
            obj.Visible = false
        end
        return
    end
    
    local humanoid = character:FindFirstChild("Humanoid")
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    local head = character:FindFirstChild("Head")
    
    if not rootPart or not humanoid or humanoid.Health <= 0 then
        for _, obj in pairs(esp) do
            obj.Visible = false
        end
        return
    end
    
    local screenPos, onScreen = Camera:WorldToViewportPoint(rootPart.Position)
    local headPos = head and Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0)) or screenPos
    local legPos = Camera:WorldToViewportPoint(rootPart.Position - Vector3.new(0, 3, 0))
    
    if onScreen then
        -- Размер бокса
        local height = (headPos.Y - legPos.Y)
        local width = height / 2
        local boxSize = Vector2.new(width, height)
        local boxPos = Vector2.new(screenPos.X - width / 2, headPos.Y)
        
        -- Box Outline
        if Settings.ESP.Boxes then
            esp.BoxOutline.Size = boxSize
            esp.BoxOutline.Position = boxPos
            esp.BoxOutline.Visible = true
            
            -- Box
            esp.Box.Size = boxSize
            esp.Box.Position = boxPos
            esp.Box.Visible = true
        else
            esp.Box.Visible = false
            esp.BoxOutline.Visible = false
        end
        
        -- Name
        if Settings.ESP.Names then
            local displayName = targetData and targetData.Name or (target.Name or "Bot")
            if targetData and targetData.Type == "NPC" then
                displayName = "[NPC] " .. displayName
            end
            esp.Name.Text = displayName
            esp.Name.Position = Vector2.new(screenPos.X, headPos.Y - 15)
            esp.Name.Visible = true
        else
            esp.Name.Visible = false
        end
        
        -- Distance
        if Settings.ESP.Distance and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local distance = (LocalPlayer.Character.HumanoidRootPart.Position - rootPart.Position).Magnitude
            esp.Distance.Text = string.format("[%d studs]", math.floor(distance))
            esp.Distance.Position = Vector2.new(screenPos.X, legPos.Y + 5)
            esp.Distance.Visible = true
        else
            esp.Distance.Visible = false
        end
        
        -- Health Bar
        if Settings.ESP.Health then
            local healthPercent = humanoid.Health / humanoid.MaxHealth
            local barHeight = height
            local barWidth = 4
            
            -- Health Bar Outline
            esp.HealthBarOutline.Size = Vector2.new(barWidth + 2, barHeight + 2)
            esp.HealthBarOutline.Position = Vector2.new(boxPos.X - barWidth - 4, boxPos.Y - 1)
            esp.HealthBarOutline.Visible = true
            
            -- Health Bar Fill
            local healthBarHeight = barHeight * healthPercent
            esp.HealthBar.Size = Vector2.new(barWidth, healthBarHeight)
            esp.HealthBar.Position = Vector2.new(boxPos.X - barWidth - 3, boxPos.Y + (barHeight - healthBarHeight))
            
            -- Цвет в зависимости от хелса
            if healthPercent > 0.75 then
                esp.HealthBar.Color = Color3.fromRGB(0, 255, 0)
            elseif healthPercent > 0.5 then
                esp.HealthBar.Color = Color3.fromRGB(255, 255, 0)
            elseif healthPercent > 0.25 then
                esp.HealthBar.Color = Color3.fromRGB(255, 165, 0)
            else
                esp.HealthBar.Color = Color3.fromRGB(255, 0, 0)
            end
            
            esp.HealthBar.Visible = true
            
            -- Health Text
            esp.HealthText.Text = string.format("%d", math.floor(humanoid.Health))
            esp.HealthText.Position = Vector2.new(boxPos.X - barWidth - 3, boxPos.Y - 15)
            esp.HealthText.Visible = true
        else
            esp.HealthBar.Visible = false
            esp.HealthBarOutline.Visible = false
            esp.HealthText.Visible = false
        end
        
        -- Tracer
        if Settings.ESP.Tracers then
            local tracerStart = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
            esp.Tracer.From = tracerStart
            esp.Tracer.To = Vector2.new(screenPos.X, legPos.Y)
            esp.Tracer.Visible = true
        else
            esp.Tracer.Visible = false
        end
    else
        for _, obj in pairs(esp) do
            obj.Visible = false
        end
    end
end

-- Создание GUI с LinoriaLib
local Window = Library:CreateWindow({
    Title = 'ONE TAP V3 | Premium Edition',
    Center = true,
    AutoShow = true,
    TabPadding = 8,
    MenuFadeTime = 0.2
})

local Tabs = {
    Aimbot = Window:AddTab('Aimbot'),
    ESP = Window:AddTab('ESP'),
    Misc = Window:AddTab('Misc'),
    Settings = Window:AddTab('Settings')
}

-- Aimbot Tab
local AimbotBox = Tabs.Aimbot:AddLeftGroupbox('Aimbot Settings')

AimbotBox:AddToggle('AimbotEnabled', {
    Text = 'Enable Aimbot',
    Default = false,
    Tooltip = 'Включить аимбот',
    Callback = function(Value)
        Settings.Aimbot.Enabled = Value
    end
})

AimbotBox:AddToggle('SilentAim', {
    Text = 'Silent Aim',
    Default = false,
    Tooltip = 'Мгновенное наведение при выстреле',
    Callback = function(Value)
        Settings.Aimbot.SilentAim = Value
    end
})

AimbotBox:AddSlider('FOVRadius', {
    Text = 'FOV Radius',
    Default = 150,
    Min = 50,
    Max = 300,
    Rounding = 0,
    Compact = false,
    Callback = function(Value)
        Settings.Aimbot.FOV = Value
        FOVCircle.Radius = Value
    end
})

AimbotBox:AddSlider('Smoothness', {
    Text = 'Smoothness',
    Default = 20,
    Min = 0,
    Max = 100,
    Rounding = 0,
    Compact = false,
    Callback = function(Value)
        Settings.Aimbot.Smoothness = Value / 100
    end
})

AimbotBox:AddSlider('MaxDistance', {
    Text = 'Max Distance',
    Default = 300,
    Min = 50,
    Max = 500,
    Rounding = 0,
    Compact = false,
    Callback = function(Value)
        Settings.Aimbot.MaxDistance = Value
    end
})

AimbotBox:AddDropdown('TargetPart', {
    Values = {'Head', 'HumanoidRootPart', 'UpperTorso'},
    Default = 1,
    Multi = false,
    Text = 'Target Part',
    Tooltip = 'Часть тела для прицеливания',
    Callback = function(Value)
        Settings.Aimbot.TargetPart = Value
    end
})

AimbotBox:AddDropdown('TargetPriority', {
    Values = {'Closest to Crosshair', 'Lowest Health', 'Closest Distance'},
    Default = 1,
    Multi = false,
    Text = 'Target Priority',
    Callback = function(Value)
        Settings.Aimbot.TargetPriority = Value
    end
})

-- FOV Settings
local FOVBox = Tabs.Aimbot:AddRightGroupbox('FOV Settings')

FOVBox:AddToggle('ShowFOV', {
    Text = 'Show FOV Circle',
    Default = true,
    Callback = function(Value)
        Settings.Aimbot.ShowFOV = Value
    end
})

FOVBox:AddSlider('FOVThickness', {
    Text = 'FOV Thickness',
    Default = 2,
    Min = 1,
    Max = 5,
    Rounding = 0,
    Compact = false,
    Callback = function(Value)
        Settings.Aimbot.FOVThickness = Value
        FOVCircle.Thickness = Value
    end
})

FOVBox:AddToggle('FOVFilled', {
    Text = 'FOV Filled',
    Default = false,
    Callback = function(Value)
        Settings.Aimbot.FOVFilled = Value
        FOVCircle.Filled = Value
    end
})

-- Wallbang Settings
local WallbangBox = Tabs.Aimbot:AddRightGroupbox('Wallbang')

WallbangBox:AddToggle('IgnoreWalls', {
    Text = 'Ignore Walls',
    Default = false,
    Callback = function(Value)
        Settings.Wallbang.IgnoreWalls = Value
    end
})

WallbangBox:AddDropdown('WallbangMode', {
    Values = {'Always', 'Raycast', 'Penetration'},
    Default = 1,
    Multi = false,
    Text = 'Wallbang Mode',
    Callback = function(Value)
        Settings.Wallbang.WallbangMode = Value
    end
})

WallbangBox:AddSlider('WallPenetration', {
    Text = 'Penetration %',
    Default = 100,
    Min = 0,
    Max = 100,
    Rounding = 0,
    Compact = false,
    Callback = function(Value)
        Settings.Wallbang.WallPenetration = Value
    end
})

-- Auto Shoot
local AutoShootBox = Tabs.Aimbot:AddLeftGroupbox('Auto Shoot')

AutoShootBox:AddToggle('AutoShoot', {
    Text = 'Enable Auto Shoot',
    Default = false,
    Callback = function(Value)
        Settings.AutoShoot.Enabled = Value
    end
})

AutoShootBox:AddSlider('AutoShootCPS', {
    Text = 'CPS',
    Default = 10,
    Min = 1,
    Max = 20,
    Rounding = 0,
    Compact = false,
    Callback = function(Value)
        Settings.AutoShoot.CPS = Value
    end
})

AutoShootBox:AddSlider('TriggerDelay', {
    Text = 'Trigger Delay (ms)',
    Default = 0,
    Min = 0,
    Max = 500,
    Rounding = 0,
    Compact = false,
    Callback = function(Value)
        Settings.AutoShoot.TriggerDelay = Value
    end
})

-- ESP Tab
local ESPBox = Tabs.ESP:AddLeftGroupbox('ESP Settings')

ESPBox:AddToggle('ESPEnabled', {
    Text = 'Enable ESP',
    Default = false,
    Callback = function(Value)
        Settings.ESP.Enabled = Value
    end
})

ESPBox:AddToggle('ESPBoxes', {
    Text = 'Boxes',
    Default = true,
    Callback = function(Value)
        Settings.ESP.Boxes = Value
    end
})

ESPBox:AddToggle('ESPNames', {
    Text = 'Names',
    Default = true,
    Callback = function(Value)
        Settings.ESP.Names = Value
    end
})

ESPBox:AddToggle('ESPHealth', {
    Text = 'Health Bars',
    Default = true,
    Callback = function(Value)
        Settings.ESP.Health = Value
    end
})

ESPBox:AddToggle('ESPDistance', {
    Text = 'Distance',
    Default = true,
    Callback = function(Value)
        Settings.ESP.Distance = Value
    end
})

ESPBox:AddToggle('ESPTracers', {
    Text = 'Tracers',
    Default = false,
    Callback = function(Value)
        Settings.ESP.Tracers = Value
    end
})

-- Misc Tab
local MiscBox = Tabs.Misc:AddLeftGroupbox('Movement')

MiscBox:AddToggle('ThirdPerson', {
    Text = 'Third Person',
    Default = false,
    Callback = function(Value)
        Settings.ThirdPerson.Enabled = Value
    end
})

MiscBox:AddSlider('ThirdPersonDistance', {
    Text = 'Camera Distance',
    Default = 5,
    Min = 2,
    Max = 20,
    Rounding = 0,
    Compact = false,
    Callback = function(Value)
        Settings.ThirdPerson.Distance = Value
    end
})

MiscBox:AddToggle('Spinbot', {
    Text = 'Spinbot',
    Default = false,
    Callback = function(Value)
        Settings.Spinbot.Enabled = Value
    end
})

MiscBox:AddSlider('SpinSpeed', {
    Text = 'Spin Speed',
    Default = 20,
    Min = 1,
    Max = 100,
    Rounding = 0,
    Compact = false,
    Callback = function(Value)
        Settings.Spinbot.Speed = Value
    end
})

MiscBox:AddDropdown('SpinAxis', {
    Values = {'Yaw', 'Pitch', 'Both'},
    Default = 1,
    Multi = false,
    Text = 'Spin Axis',
    Callback = function(Value)
        Settings.Spinbot.Axis = Value
    end
})

MiscBox:AddToggle('BunnyHop', {
    Text = 'Bunny Hop',
    Default = false,
    Callback = function(Value)
        Settings.BunnyHop.Enabled = Value
    end
})

MiscBox:AddSlider('BhopMinSpeed', {
    Text = 'Min Speed',
    Default = 10,
    Min = 0,
    Max = 50,
    Rounding = 0,
    Compact = false,
    Callback = function(Value)
        Settings.BunnyHop.MinSpeed = Value
    end
})

-- Visual Settings
local VisualBox = Tabs.Misc:AddRightGroupbox('Visual')

VisualBox:AddSlider('CameraFOV', {
    Text = 'Camera FOV',
    Default = 70,
    Min = 40,
    Max = 120,
    Rounding = 0,
    Compact = false,
    Callback = function(Value)
        Settings.Visual.CameraFOV = Value
    end
})

VisualBox:AddToggle('HighlightTarget', {
    Text = 'Highlight Target',
    Default = true,
    Callback = function(Value)
        Settings.Visual.HighlightTarget = Value
    end
})

VisualBox:AddSlider('HighlightThickness', {
    Text = 'Highlight Thickness',
    Default = 3,
    Min = 1,
    Max = 5,
    Rounding = 0,
    Compact = false,
    Callback = function(Value)
        Settings.Visual.HighlightThickness = Value
        if targetHighlight then
            targetHighlight.Thickness = Value
        end
    end
})

-- Settings Tab
Library:SetWatermarkVisibility(true)
Library:SetWatermark('ONE TAP V3 | Premium Edition')

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)

SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({'MenuKeybind'})

ThemeManager:SetFolder('OneTapV3')
SaveManager:SetFolder('OneTapV3/configs')

SaveManager:BuildConfigSection(Tabs.Settings)
ThemeManager:ApplyToTab(Tabs.Settings)

-- Основной цикл
RunService.RenderStepped:Connect(function()
    local viewportSize = Camera.ViewportSize
    FOVCircle.Position = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
    FOVCircle.Visible = Settings.Aimbot.ShowFOV and Settings.Aimbot.Enabled
    
    currentTarget = nil
    if Settings.Aimbot.Enabled or Settings.AutoShoot.Enabled then
        currentTarget = GetClosestEnemy()
    end
    
    if Settings.Aimbot.Enabled then
        if currentTarget and currentTarget.Character then
            local targetPart = currentTarget.Character:FindFirstChild(Settings.Aimbot.TargetPart)
            if not targetPart then
                targetPart = currentTarget.Character:FindFirstChild("Head") or currentTarget.Character:FindFirstChild("HumanoidRootPart")
            end
            if targetPart then
                if not Settings.Aimbot.SilentAim then
                    AimAt(targetPart)
                end
            end
        end
    end
    
    AutoShoot()
    UpdateThirdPerson()
    UpdateSpinbot()
    UpdateBunnyHop()
    UpdateCameraFOV()
    UpdateTargetHighlight()
    
    if Settings.ESP.Enabled then
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                if not ESPObjects[player] then
                    CreateESP(player)
                end
                UpdateESP(player, {Type = "Player", Character = player.Character, Name = player.Name})
            end
        end
        
        for npc, _ in pairs(NPCList) do
            if npc and npc.Parent then
                if not ESPObjects[npc] then
                    CreateESP(npc)
                end
                UpdateESP(npc, {Type = "NPC", Character = npc, Name = npc.Name or "Bot"})
            else
                if ESPObjects[npc] then
                    for _, obj in pairs(ESPObjects[npc]) do
                        pcall(function() obj:Remove() end)
                    end
                    ESPObjects[npc] = nil
                end
                NPCList[npc] = nil
            end
        end
    end
end)

Library:OnUnload(function()
    getgenv().OneTapLoaded = false
    
    for target, esp in pairs(ESPObjects) do
        for _, obj in pairs(esp) do
            pcall(function() obj:Remove() end)
        end
    end
    
    pcall(function() FOVCircle:Remove() end)
    
    if targetHighlight then
        pcall(function() targetHighlight:Remove() end)
    end
    
    if Camera then
        Camera.FieldOfView = originalCameraFOV
    end
    
    if originalCameraType then
        Camera.CameraType = originalCameraType
        Camera.CameraSubject = originalCameraSubject
    end
    
    print('ONE TAP V3 Unloaded!')
end)

print("========================================")
print("ONE TAP V3 - PREMIUM EDITION")
print("LinoriaLib GUI Loaded")
print("========================================")
print("✓ All Features Active")
print("✓ Professional GUI")
print("✓ Config System")
print("========================================")
