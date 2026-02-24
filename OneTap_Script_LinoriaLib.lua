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
        FOVTransparency = 0.5,
        IgnoreFOV = false
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
        HighlightTarget = false,
        HighlightColor = Color3.fromRGB(255, 215, 0),
        HighlightThickness = 3
    },
    HitboxExpander = {
        Enabled = true,
        HeadSize = 10,
        TorsoSize = 5
    },
    QuickSwap = {
        Enabled = false,
        Key = "Q"
    },
    ESP = {
        Enabled = false,
        Boxes = true,
        Names = true,
        Health = true,
        Distance = true,
        Tracers = false,
        Skeleton = false,
        HeadDot = false,
        BoxColor = Color3.fromRGB(255, 215, 0),
        BoxOutlineColor = Color3.fromRGB(0, 0, 0),
        NameColor = Color3.fromRGB(255, 255, 255),
        HealthColorHigh = Color3.fromRGB(0, 255, 0),
        HealthColorLow = Color3.fromRGB(255, 0, 0),
        TracerColor = Color3.fromRGB(255, 215, 0),
        SkeletonColor = Color3.fromRGB(255, 255, 255),
        HeadDotColor = Color3.fromRGB(255, 215, 0),
        BoxThickness = 2,
        BoxRounding = 6,
        TextSize = 13,
        TextOutlineThickness = 2,
        HealthBarWidth = 4,
        TracerThickness = 1,
        SkeletonThickness = 2,
        HeadDotSize = 8,
        FadeSpeed = 0.1
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
local originalHeadSizes = {}
local quickSwapPressed = false

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
                    
                    -- Ignore FOV если включено
                    local withinFOV = Settings.Aimbot.IgnoreFOV or (distanceFromCenter <= Settings.Aimbot.FOV)
                    
                    if withinFOV then
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

-- Silent Aim (невидимый для игрока - камера не двигается визуально)
local silentAimConnection = nil

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
        
        -- Предсказание позиции цели
        local targetPos = targetPart.Position
        local targetVelocity = targetPart.AssemblyLinearVelocity or Vector3.new(0, 0, 0)
        local distance = (targetPos - Camera.CFrame.Position).Magnitude
        local bulletSpeed = 1000
        local timeToHit = distance / bulletSpeed
        local predictedPos = targetPos + (targetVelocity * timeToHit)
        
        -- Сохраняем оригинальную камеру
        savedCameraCFrame = Camera.CFrame
        
        -- Поворачиваем камеру на цель (игра видит, игрок нет)
        local cameraPos = Camera.CFrame.Position
        local direction = (predictedPos - cameraPos).Unit
        local targetCFrame = CFrame.new(cameraPos, cameraPos + direction)
        
        -- Мгновенно поворачиваем
        Camera.CFrame = targetCFrame
        
        -- Возвращаем камеру МГНОВЕННО в следующем кадре
        silentAimConnection = RunService.RenderStepped:Connect(function()
            if savedCameraCFrame then
                Camera.CFrame = savedCameraCFrame
                if silentAimConnection then
                    silentAimConnection:Disconnect()
                    silentAimConnection = nil
                end
                savedCameraCFrame = nil
                isSilentAiming = false
            end
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

-- Camera FOV с поддержкой viewmodel
local function UpdateCameraFOV()
    if Camera then
        Camera.FieldOfView = Settings.Visual.CameraFOV
    end
    
    -- Применяем FOV к оружию (viewmodel)
    if LocalPlayer.Character then
        for _, obj in pairs(Camera:GetChildren()) do
            if obj:IsA("Model") then
                -- Это viewmodel оружия
                local fovMultiplier = Settings.Visual.CameraFOV / 70
                obj:ScaleTo(fovMultiplier)
            end
        end
    end
end

-- Hitbox Expander
local function UpdateHitboxes()
    if not Settings.HitboxExpander.Enabled then
        -- Восстанавливаем оригинальные размеры
        for part, originalSize in pairs(originalHeadSizes) do
            if part and part.Parent then
                part.Size = originalSize
                part.Transparency = 1
                part.CanCollide = false
            end
        end
        originalHeadSizes = {}
        return
    end
    
    local targets = GetAllTargets()
    for _, target in pairs(targets) do
        if target.Character then
            local head = target.Character:FindFirstChild("Head")
            local torso = target.Character:FindFirstChild("HumanoidRootPart") or target.Character:FindFirstChild("UpperTorso")
            
            if head and not originalHeadSizes[head] then
                originalHeadSizes[head] = head.Size
                head.Size = Vector3.new(Settings.HitboxExpander.HeadSize, Settings.HitboxExpander.HeadSize, Settings.HitboxExpander.HeadSize)
                head.Transparency = 0.5
                head.CanCollide = false
            end
            
            if torso and not originalHeadSizes[torso] then
                originalHeadSizes[torso] = torso.Size
                torso.Size = Vector3.new(Settings.HitboxExpander.TorsoSize, Settings.HitboxExpander.TorsoSize, Settings.HitboxExpander.TorsoSize)
                torso.Transparency = 0.5
                torso.CanCollide = false
            end
        end
    end
end

-- Quick Swap (быстрая смена оружия)
local lastSwapTime = 0
local function QuickSwap()
    if not Settings.QuickSwap.Enabled then return end
    
    local currentTime = tick()
    if currentTime - lastSwapTime < 0.1 then return end
    
    if LocalPlayer.Character then
        local humanoid = LocalPlayer.Character:FindFirstChild("Humanoid")
        if humanoid then
            -- Быстрая смена на нож и обратно
            task.spawn(function()
                -- Переключаемся на слот 3 (нож)
                game:GetService("VirtualInputManager"):SendKeyEvent(true, Enum.KeyCode.Three, false, game)
                task.wait(0.05)
                game:GetService("VirtualInputManager"):SendKeyEvent(false, Enum.KeyCode.Three, false, game)
                
                -- Возвращаемся на предыдущее оружие
                task.wait(0.05)
                game:GetService("VirtualInputManager"):SendKeyEvent(true, Enum.KeyCode.One, false, game)
                task.wait(0.05)
                game:GetService("VirtualInputManager"):SendKeyEvent(false, Enum.KeyCode.One, false, game)
            end)
            
            lastSwapTime = currentTime
        end
    end
end

-- Современный ESP с градиентами, скруглениями и анимациями
local function CreateESP(target)
    local esp = {
        -- Rounded Box (8 линий для скруглённых углов)
        BoxTop = Drawing.new("Line"),
        BoxBottom = Drawing.new("Line"),
        BoxLeft = Drawing.new("Line"),
        BoxRight = Drawing.new("Line"),
        BoxTopOutline = Drawing.new("Line"),
        BoxBottomOutline = Drawing.new("Line"),
        BoxLeftOutline = Drawing.new("Line"),
        BoxRightOutline = Drawing.new("Line"),
        
        -- Скруглённые углы (4 угла по 2 линии)
        CornerTL1 = Drawing.new("Line"),
        CornerTL2 = Drawing.new("Line"),
        CornerTR1 = Drawing.new("Line"),
        CornerTR2 = Drawing.new("Line"),
        CornerBL1 = Drawing.new("Line"),
        CornerBL2 = Drawing.new("Line"),
        CornerBR1 = Drawing.new("Line"),
        CornerBR2 = Drawing.new("Line"),
        
        -- Text с обводкой
        Name = Drawing.new("Text"),
        NameOutline = Drawing.new("Text"),
        Distance = Drawing.new("Text"),
        DistanceOutline = Drawing.new("Text"),
        
        -- Gradient Health Bar
        HealthBar = Drawing.new("Square"),
        HealthBarOutline = Drawing.new("Square"),
        HealthBarBg = Drawing.new("Square"),
        HealthText = Drawing.new("Text"),
        HealthTextOutline = Drawing.new("Text"),
        
        -- Tracer
        Tracer = Drawing.new("Line"),
        
        -- Head Dot с свечением
        HeadDot = Drawing.new("Circle"),
        HeadDotGlow = Drawing.new("Circle"),
        
        -- Skeleton (линии костей)
        SkeletonLines = {},
        
        -- Анимация
        Transparency = 0,
        TargetTransparency = 1
    }
    
    -- Box lines (основные линии)
    local boxLines = {esp.BoxTop, esp.BoxBottom, esp.BoxLeft, esp.BoxRight}
    local boxOutlines = {esp.BoxTopOutline, esp.BoxBottomOutline, esp.BoxLeftOutline, esp.BoxRightOutline}
    
    for _, line in pairs(boxLines) do
        line.Thickness = Settings.ESP.BoxThickness
        line.Color = Settings.ESP.BoxColor
        line.Transparency = 0
        line.Visible = false
    end
    
    for _, line in pairs(boxOutlines) do
        line.Thickness = Settings.ESP.BoxThickness + 2
        line.Color = Settings.ESP.BoxOutlineColor
        line.Transparency = 0.5
        line.Visible = false
    end
    
    -- Corner lines (скруглённые углы)
    local cornerLines = {
        esp.CornerTL1, esp.CornerTL2, esp.CornerTR1, esp.CornerTR2,
        esp.CornerBL1, esp.CornerBL2, esp.CornerBR1, esp.CornerBR2
    }
    
    for _, line in pairs(cornerLines) do
        line.Thickness = Settings.ESP.BoxThickness
        line.Color = Settings.ESP.BoxColor
        line.Transparency = 0
        line.Visible = false
    end
    
    -- Name с кастомной обводкой
    esp.Name.Size = Settings.ESP.TextSize
    esp.Name.Center = true
    esp.Name.Outline = false
    esp.Name.Color = Settings.ESP.NameColor
    esp.Name.Visible = false
    esp.Name.Font = 3
    
    esp.NameOutline.Size = Settings.ESP.TextSize
    esp.NameOutline.Center = true
    esp.NameOutline.Outline = false
    esp.NameOutline.Color = Color3.fromRGB(0, 0, 0)
    esp.NameOutline.Visible = false
    esp.NameOutline.Font = 3
    
    -- Distance с обводкой
    esp.Distance.Size = Settings.ESP.TextSize - 1
    esp.Distance.Center = true
    esp.Distance.Outline = false
    esp.Distance.Color = Color3.fromRGB(200, 200, 200)
    esp.Distance.Visible = false
    esp.Distance.Font = 3
    
    esp.DistanceOutline.Size = Settings.ESP.TextSize - 1
    esp.DistanceOutline.Center = true
    esp.DistanceOutline.Outline = false
    esp.DistanceOutline.Color = Color3.fromRGB(0, 0, 0)
    esp.DistanceOutline.Visible = false
    esp.DistanceOutline.Font = 3
    
    -- Health Bar с градиентом
    esp.HealthBarBg.Thickness = 1
    esp.HealthBarBg.Color = Color3.fromRGB(20, 20, 20)
    esp.HealthBarBg.Filled = true
    esp.HealthBarBg.Transparency = 0.8
    esp.HealthBarBg.Visible = false
    
    esp.HealthBarOutline.Thickness = 1
    esp.HealthBarOutline.Color = Color3.fromRGB(0, 0, 0)
    esp.HealthBarOutline.Filled = false
    esp.HealthBarOutline.Transparency = 1
    esp.HealthBarOutline.Visible = false
    
    esp.HealthBar.Thickness = 1
    esp.HealthBar.Color = Settings.ESP.HealthColorHigh
    esp.HealthBar.Filled = true
    esp.HealthBar.Transparency = 1
    esp.HealthBar.Visible = false
    
    -- Health Text с обводкой
    esp.HealthText.Size = 11
    esp.HealthText.Center = true
    esp.HealthText.Outline = false
    esp.HealthText.Color = Color3.fromRGB(255, 255, 255)
    esp.HealthText.Visible = false
    esp.HealthText.Font = 3
    
    esp.HealthTextOutline.Size = 11
    esp.HealthTextOutline.Center = true
    esp.HealthTextOutline.Outline = false
    esp.HealthTextOutline.Color = Color3.fromRGB(0, 0, 0)
    esp.HealthTextOutline.Visible = false
    esp.HealthTextOutline.Font = 3
    
    -- Tracer
    esp.Tracer.Thickness = Settings.ESP.TracerThickness
    esp.Tracer.Color = Settings.ESP.TracerColor
    esp.Tracer.Transparency = 0.7
    esp.Tracer.Visible = false
    
    -- Head Dot с свечением
    esp.HeadDot.Thickness = 1
    esp.HeadDot.NumSides = 30
    esp.HeadDot.Radius = Settings.ESP.HeadDotSize
    esp.HeadDot.Color = Settings.ESP.HeadDotColor
    esp.HeadDot.Filled = true
    esp.HeadDot.Transparency = 1
    esp.HeadDot.Visible = false
    
    esp.HeadDotGlow.Thickness = 2
    esp.HeadDotGlow.NumSides = 30
    esp.HeadDotGlow.Radius = Settings.ESP.HeadDotSize + 3
    esp.HeadDotGlow.Color = Settings.ESP.HeadDotColor
    esp.HeadDotGlow.Filled = false
    esp.HeadDotGlow.Transparency = 0.3
    esp.HeadDotGlow.Visible = false
    
    -- Skeleton lines (создаём 15 линий для скелета)
    for i = 1, 15 do
        local line = Drawing.new("Line")
        line.Thickness = Settings.ESP.SkeletonThickness
        line.Color = Settings.ESP.SkeletonColor
        line.Transparency = 1
        line.Visible = false
        table.insert(esp.SkeletonLines, line)
    end
    
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
    local headPos = head and Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 1, 0)) or screenPos
    local legPos = Camera:WorldToViewportPoint(rootPart.Position - Vector3.new(0, 2.5, 0))
    
    if onScreen then
        -- Размер бокса
        local height = (headPos.Y - legPos.Y)
        local width = height / 2
        local boxSize = Vector2.new(width, height)
        local boxPos = Vector2.new(screenPos.X - width / 2, headPos.Y)
        
        -- Анимация прозрачности (fade in/out)
        if esp.TargetTransparency > esp.Transparency then
            esp.Transparency = math.min(esp.Transparency + Settings.ESP.FadeSpeed, esp.TargetTransparency)
        elseif esp.TargetTransparency < esp.Transparency then
            esp.Transparency = math.max(esp.Transparency - Settings.ESP.FadeSpeed, esp.TargetTransparency)
        end
        
        -- Rounded 2D Boxes со скруглёнными углами
        if Settings.ESP.Boxes then
            local rounding = Settings.ESP.BoxRounding
            
            -- Outline (чёрная обводка)
            esp.BoxTopOutline.From = Vector2.new(boxPos.X + rounding, boxPos.Y - 1)
            esp.BoxTopOutline.To = Vector2.new(boxPos.X + width - rounding, boxPos.Y - 1)
            esp.BoxTopOutline.Transparency = esp.Transparency * 0.5
            esp.BoxTopOutline.Visible = true
            
            esp.BoxBottomOutline.From = Vector2.new(boxPos.X + rounding, boxPos.Y + height + 1)
            esp.BoxBottomOutline.To = Vector2.new(boxPos.X + width - rounding, boxPos.Y + height + 1)
            esp.BoxBottomOutline.Transparency = esp.Transparency * 0.5
            esp.BoxBottomOutline.Visible = true
            
            esp.BoxLeftOutline.From = Vector2.new(boxPos.X - 1, boxPos.Y + rounding)
            esp.BoxLeftOutline.To = Vector2.new(boxPos.X - 1, boxPos.Y + height - rounding)
            esp.BoxLeftOutline.Transparency = esp.Transparency * 0.5
            esp.BoxLeftOutline.Visible = true
            
            esp.BoxRightOutline.From = Vector2.new(boxPos.X + width + 1, boxPos.Y + rounding)
            esp.BoxRightOutline.To = Vector2.new(boxPos.X + width + 1, boxPos.Y + height - rounding)
            esp.BoxRightOutline.Transparency = esp.Transparency * 0.5
            esp.BoxRightOutline.Visible = true
            
            -- Main box lines
            esp.BoxTop.From = Vector2.new(boxPos.X + rounding, boxPos.Y)
            esp.BoxTop.To = Vector2.new(boxPos.X + width - rounding, boxPos.Y)
            esp.BoxTop.Transparency = esp.Transparency
            esp.BoxTop.Visible = true
            
            esp.BoxBottom.From = Vector2.new(boxPos.X + rounding, boxPos.Y + height)
            esp.BoxBottom.To = Vector2.new(boxPos.X + width - rounding, boxPos.Y + height)
            esp.BoxBottom.Transparency = esp.Transparency
            esp.BoxBottom.Visible = true
            
            esp.BoxLeft.From = Vector2.new(boxPos.X, boxPos.Y + rounding)
            esp.BoxLeft.To = Vector2.new(boxPos.X, boxPos.Y + height - rounding)
            esp.BoxLeft.Transparency = esp.Transparency
            esp.BoxLeft.Visible = true
            
            esp.BoxRight.From = Vector2.new(boxPos.X + width, boxPos.Y + rounding)
            esp.BoxRight.To = Vector2.new(boxPos.X + width, boxPos.Y + height - rounding)
            esp.BoxRight.Transparency = esp.Transparency
            esp.BoxRight.Visible = true
            
            -- Скруглённые углы (диагональные линии)
            local cornerSize = rounding * 0.7
            
            -- Top Left
            esp.CornerTL1.From = Vector2.new(boxPos.X, boxPos.Y + rounding)
            esp.CornerTL1.To = Vector2.new(boxPos.X + cornerSize, boxPos.Y + rounding - cornerSize)
            esp.CornerTL1.Transparency = esp.Transparency
            esp.CornerTL1.Visible = true
            
            esp.CornerTL2.From = Vector2.new(boxPos.X + rounding, boxPos.Y)
            esp.CornerTL2.To = Vector2.new(boxPos.X + rounding - cornerSize, boxPos.Y + cornerSize)
            esp.CornerTL2.Transparency = esp.Transparency
            esp.CornerTL2.Visible = true
            
            -- Top Right
            esp.CornerTR1.From = Vector2.new(boxPos.X + width, boxPos.Y + rounding)
            esp.CornerTR1.To = Vector2.new(boxPos.X + width - cornerSize, boxPos.Y + rounding - cornerSize)
            esp.CornerTR1.Transparency = esp.Transparency
            esp.CornerTR1.Visible = true
            
            esp.CornerTR2.From = Vector2.new(boxPos.X + width - rounding, boxPos.Y)
            esp.CornerTR2.To = Vector2.new(boxPos.X + width - rounding + cornerSize, boxPos.Y + cornerSize)
            esp.CornerTR2.Transparency = esp.Transparency
            esp.CornerTR2.Visible = true
            
            -- Bottom Left
            esp.CornerBL1.From = Vector2.new(boxPos.X, boxPos.Y + height - rounding)
            esp.CornerBL1.To = Vector2.new(boxPos.X + cornerSize, boxPos.Y + height - rounding + cornerSize)
            esp.CornerBL1.Transparency = esp.Transparency
            esp.CornerBL1.Visible = true
            
            esp.CornerBL2.From = Vector2.new(boxPos.X + rounding, boxPos.Y + height)
            esp.CornerBL2.To = Vector2.new(boxPos.X + rounding - cornerSize, boxPos.Y + height - cornerSize)
            esp.CornerBL2.Transparency = esp.Transparency
            esp.CornerBL2.Visible = true
            
            -- Bottom Right
            esp.CornerBR1.From = Vector2.new(boxPos.X + width, boxPos.Y + height - rounding)
            esp.CornerBR1.To = Vector2.new(boxPos.X + width - cornerSize, boxPos.Y + height - rounding + cornerSize)
            esp.CornerBR1.Transparency = esp.Transparency
            esp.CornerBR1.Visible = true
            
            esp.CornerBR2.From = Vector2.new(boxPos.X + width - rounding, boxPos.Y + height)
            esp.CornerBR2.To = Vector2.new(boxPos.X + width - rounding + cornerSize, boxPos.Y + height - cornerSize)
            esp.CornerBR2.Transparency = esp.Transparency
            esp.CornerBR2.Visible = true
        else
            esp.BoxTop.Visible = false
            esp.BoxBottom.Visible = false
            esp.BoxLeft.Visible = false
            esp.BoxRight.Visible = false
            esp.BoxTopOutline.Visible = false
            esp.BoxBottomOutline.Visible = false
            esp.BoxLeftOutline.Visible = false
            esp.BoxRightOutline.Visible = false
            for _, corner in pairs({esp.CornerTL1, esp.CornerTL2, esp.CornerTR1, esp.CornerTR2, esp.CornerBL1, esp.CornerBL2, esp.CornerBR1, esp.CornerBR2}) do
                corner.Visible = false
            end
        end
        
        -- Name с кастомной обводкой
        if Settings.ESP.Names then
            local displayName = targetData and targetData.Name or (target.Name or "Bot")
            if targetData and targetData.Type == "NPC" then
                displayName = "[BOT] " .. displayName
            end
            
            -- Обводка (рисуем в 4 направлениях для толстой обводки)
            for offsetX = -Settings.ESP.TextOutlineThickness, Settings.ESP.TextOutlineThickness do
                for offsetY = -Settings.ESP.TextOutlineThickness, Settings.ESP.TextOutlineThickness do
                    if offsetX ~= 0 or offsetY ~= 0 then
                        esp.NameOutline.Text = displayName
                        esp.NameOutline.Position = Vector2.new(screenPos.X + offsetX, headPos.Y - 18 + offsetY)
                        esp.NameOutline.Transparency = esp.Transparency
                        esp.NameOutline.Visible = true
                    end
                end
            end
            
            -- Основной текст
            esp.Name.Text = displayName
            esp.Name.Position = Vector2.new(screenPos.X, headPos.Y - 18)
            esp.Name.Transparency = esp.Transparency
            esp.Name.Visible = true
        else
            esp.Name.Visible = false
            esp.NameOutline.Visible = false
        end
        
        -- Distance с обводкой
        if Settings.ESP.Distance and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local distance = (LocalPlayer.Character.HumanoidRootPart.Position - rootPart.Position).Magnitude
            local distText = string.format("%dm", math.floor(distance))
            
            -- Обводка
            esp.DistanceOutline.Text = distText
            esp.DistanceOutline.Position = Vector2.new(screenPos.X + 1, headPos.Y - 5 + 1)
            esp.DistanceOutline.Transparency = esp.Transparency
            esp.DistanceOutline.Visible = true
            
            -- Основной текст
            esp.Distance.Text = distText
            esp.Distance.Position = Vector2.new(screenPos.X, headPos.Y - 5)
            esp.Distance.Transparency = esp.Transparency
            esp.Distance.Visible = true
        else
            esp.Distance.Visible = false
            esp.DistanceOutline.Visible = false
        end
        
        -- Gradient Health Bar с плавной анимацией
        if Settings.ESP.Health then
            local healthPercent = humanoid.Health / humanoid.MaxHealth
            local barHeight = height
            local barWidth = Settings.ESP.HealthBarWidth
            
            -- Background
            esp.HealthBarBg.Size = Vector2.new(barWidth, barHeight)
            esp.HealthBarBg.Position = Vector2.new(boxPos.X - barWidth - 5, boxPos.Y)
            esp.HealthBarBg.Transparency = esp.Transparency * 0.8
            esp.HealthBarBg.Visible = true
            
            -- Outline
            esp.HealthBarOutline.Size = Vector2.new(barWidth + 2, barHeight + 2)
            esp.HealthBarOutline.Position = Vector2.new(boxPos.X - barWidth - 6, boxPos.Y - 1)
            esp.HealthBarOutline.Transparency = esp.Transparency
            esp.HealthBarOutline.Visible = true
            
            -- Health Bar Fill (градиент от зелёного к красному)
            local healthBarHeight = barHeight * healthPercent
            esp.HealthBar.Size = Vector2.new(barWidth, healthBarHeight)
            esp.HealthBar.Position = Vector2.new(boxPos.X - barWidth - 5, boxPos.Y + (barHeight - healthBarHeight))
            
            -- Плавный градиент цвета
            local r = math.floor(255 * (1 - healthPercent))
            local g = math.floor(255 * healthPercent)
            esp.HealthBar.Color = Color3.fromRGB(r, g, 0)
            esp.HealthBar.Transparency = esp.Transparency
            esp.HealthBar.Visible = true
            
            -- Health Text с обводкой
            local healthText = string.format("%d", math.floor(humanoid.Health))
            
            esp.HealthTextOutline.Text = healthText
            esp.HealthTextOutline.Position = Vector2.new(boxPos.X - barWidth - 5 + 1, boxPos.Y - 13 + 1)
            esp.HealthTextOutline.Transparency = esp.Transparency
            esp.HealthTextOutline.Visible = true
            
            esp.HealthText.Text = healthText
            esp.HealthText.Position = Vector2.new(boxPos.X - barWidth - 5, boxPos.Y - 13)
            esp.HealthText.Transparency = esp.Transparency
            esp.HealthText.Visible = true
        else
            esp.HealthBar.Visible = false
            esp.HealthBarBg.Visible = false
            esp.HealthBarOutline.Visible = false
            esp.HealthText.Visible = false
            esp.HealthTextOutline.Visible = false
        end
        
        -- Tracer
        if Settings.ESP.Tracers then
            local tracerStart = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
            esp.Tracer.From = tracerStart
            esp.Tracer.To = Vector2.new(screenPos.X, legPos.Y)
            esp.Tracer.Transparency = esp.Transparency * 0.7
            esp.Tracer.Visible = true
        else
            esp.Tracer.Visible = false
        end
        
        -- Head Dot с свечением
        if Settings.ESP.HeadDot and head then
            local headScreenPos = Camera:WorldToViewportPoint(head.Position)
            
            -- Glow (свечение)
            esp.HeadDotGlow.Position = Vector2.new(headScreenPos.X, headScreenPos.Y)
            esp.HeadDotGlow.Transparency = esp.Transparency * 0.3
            esp.HeadDotGlow.Visible = true
            
            -- Main dot
            esp.HeadDot.Position = Vector2.new(headScreenPos.X, headScreenPos.Y)
            esp.HeadDot.Transparency = esp.Transparency
            esp.HeadDot.Visible = true
        else
            esp.HeadDot.Visible = false
            esp.HeadDotGlow.Visible = false
        end
        
        -- Skeleton ESP (линии костей)
        if Settings.ESP.Skeleton then
            local function getBonePosition(boneName)
                local bone = character:FindFirstChild(boneName, true)
                if bone then
                    local pos, onScreen = Camera:WorldToViewportPoint(bone.Position)
                    if onScreen then
                        return Vector2.new(pos.X, pos.Y)
                    end
                end
                return nil
            end
            
            -- Определяем кости
            local bones = {
                {"Head", "UpperTorso"},
                {"UpperTorso", "LowerTorso"},
                {"UpperTorso", "LeftUpperArm"},
                {"LeftUpperArm", "LeftLowerArm"},
                {"LeftLowerArm", "LeftHand"},
                {"UpperTorso", "RightUpperArm"},
                {"RightUpperArm", "RightLowerArm"},
                {"RightLowerArm", "RightHand"},
                {"LowerTorso", "LeftUpperLeg"},
                {"LeftUpperLeg", "LeftLowerLeg"},
                {"LeftLowerLeg", "LeftFoot"},
                {"LowerTorso", "RightUpperLeg"},
                {"RightUpperLeg", "RightLowerLeg"},
                {"RightLowerLeg", "RightFoot"}
            }
            
            for i, bonePair in ipairs(bones) do
                if esp.SkeletonLines[i] then
                    local pos1 = getBonePosition(bonePair[1])
                    local pos2 = getBonePosition(bonePair[2])
                    
                    if pos1 and pos2 then
                        esp.SkeletonLines[i].From = pos1
                        esp.SkeletonLines[i].To = pos2
                        esp.SkeletonLines[i].Transparency = esp.Transparency
                        esp.SkeletonLines[i].Visible = true
                    else
                        esp.SkeletonLines[i].Visible = false
                    end
                end
            end
        else
            for _, line in ipairs(esp.SkeletonLines) do
                line.Visible = false
            end
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
    Tooltip = 'Невидимое наведение (камера не двигается)',
    Callback = function(Value)
        Settings.Aimbot.SilentAim = Value
    end
})

AimbotBox:AddToggle('IgnoreFOV', {
    Text = 'Ignore FOV',
    Default = false,
    Tooltip = 'Стреляет в любого видимого игрока',
    Callback = function(Value)
        Settings.Aimbot.IgnoreFOV = Value
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

ESPBox:AddToggle('ESPSkeleton', {
    Text = 'Skeleton',
    Default = false,
    Callback = function(Value)
        Settings.ESP.Skeleton = Value
    end
})

ESPBox:AddToggle('ESPHeadDot', {
    Text = 'Head Dot',
    Default = false,
    Callback = function(Value)
        Settings.ESP.HeadDot = Value
    end
})

-- ESP Customization
local ESPCustomBox = Tabs.ESP:AddRightGroupbox('ESP Customization')

ESPCustomBox:AddLabel('Box Settings')

ESPCustomBox:AddSlider('BoxThickness', {
    Text = 'Box Thickness',
    Default = 2,
    Min = 1,
    Max = 5,
    Rounding = 0,
    Compact = false,
    Callback = function(Value)
        Settings.ESP.BoxThickness = Value
    end
})

ESPCustomBox:AddSlider('BoxRounding', {
    Text = 'Corner Rounding',
    Default = 6,
    Min = 0,
    Max = 15,
    Rounding = 0,
    Compact = false,
    Callback = function(Value)
        Settings.ESP.BoxRounding = Value
    end
})

ESPCustomBox:AddLabel('Box Color'):AddColorPicker('BoxColor', {
    Default = Color3.fromRGB(255, 215, 0),
    Title = 'Box Color',
    Transparency = 0,
    Callback = function(Value)
        Settings.ESP.BoxColor = Value
        for target, esp in pairs(ESPObjects) do
            if esp.BoxTop then esp.BoxTop.Color = Value end
            if esp.BoxBottom then esp.BoxBottom.Color = Value end
            if esp.BoxLeft then esp.BoxLeft.Color = Value end
            if esp.BoxRight then esp.BoxRight.Color = Value end
        end
    end
})

ESPCustomBox:AddLabel('Text Settings')

ESPCustomBox:AddSlider('TextSize', {
    Text = 'Text Size',
    Default = 13,
    Min = 10,
    Max = 20,
    Rounding = 0,
    Compact = false,
    Callback = function(Value)
        Settings.ESP.TextSize = Value
    end
})

ESPCustomBox:AddSlider('TextOutlineThickness', {
    Text = 'Text Outline',
    Default = 2,
    Min = 1,
    Max = 4,
    Rounding = 0,
    Compact = false,
    Callback = function(Value)
        Settings.ESP.TextOutlineThickness = Value
    end
})

ESPCustomBox:AddLabel('Name Color'):AddColorPicker('NameColor', {
    Default = Color3.fromRGB(255, 255, 255),
    Title = 'Name Color',
    Transparency = 0,
    Callback = function(Value)
        Settings.ESP.NameColor = Value
    end
})

ESPCustomBox:AddLabel('Health Bar Settings')

ESPCustomBox:AddSlider('HealthBarWidth', {
    Text = 'Health Bar Width',
    Default = 4,
    Min = 2,
    Max = 8,
    Rounding = 0,
    Compact = false,
    Callback = function(Value)
        Settings.ESP.HealthBarWidth = Value
    end
})

ESPCustomBox:AddLabel('Tracer Settings')

ESPCustomBox:AddSlider('TracerThickness', {
    Text = 'Tracer Thickness',
    Default = 1,
    Min = 1,
    Max = 5,
    Rounding = 0,
    Compact = false,
    Callback = function(Value)
        Settings.ESP.TracerThickness = Value
    end
})

ESPCustomBox:AddLabel('Tracer Color'):AddColorPicker('TracerColor', {
    Default = Color3.fromRGB(255, 215, 0),
    Title = 'Tracer Color',
    Transparency = 0,
    Callback = function(Value)
        Settings.ESP.TracerColor = Value
    end
})

ESPCustomBox:AddLabel('Skeleton Settings')

ESPCustomBox:AddSlider('SkeletonThickness', {
    Text = 'Skeleton Thickness',
    Default = 2,
    Min = 1,
    Max = 5,
    Rounding = 0,
    Compact = false,
    Callback = function(Value)
        Settings.ESP.SkeletonThickness = Value
    end
})

ESPCustomBox:AddLabel('Skeleton Color'):AddColorPicker('SkeletonColor', {
    Default = Color3.fromRGB(255, 255, 255),
    Title = 'Skeleton Color',
    Transparency = 0,
    Callback = function(Value)
        Settings.ESP.SkeletonColor = Value
    end
})

ESPCustomBox:AddLabel('Head Dot Settings')

ESPCustomBox:AddSlider('HeadDotSize', {
    Text = 'Head Dot Size',
    Default = 8,
    Min = 4,
    Max = 15,
    Rounding = 0,
    Compact = false,
    Callback = function(Value)
        Settings.ESP.HeadDotSize = Value
    end
})

ESPCustomBox:AddLabel('Head Dot Color'):AddColorPicker('HeadDotColor', {
    Default = Color3.fromRGB(255, 215, 0),
    Title = 'Head Dot Color',
    Transparency = 0,
    Callback = function(Value)
        Settings.ESP.HeadDotColor = Value
    end
})

ESPCustomBox:AddLabel('Animation Settings')

ESPCustomBox:AddSlider('FadeSpeed', {
    Text = 'Fade Speed',
    Default = 0.1,
    Min = 0.05,
    Max = 0.5,
    Rounding = 2,
    Compact = false,
    Callback = function(Value)
        Settings.ESP.FadeSpeed = Value
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

-- Hitbox Expander
local HitboxBox = Tabs.Misc:AddRightGroupbox('Hitbox Expander')

HitboxBox:AddToggle('HitboxEnabled', {
    Text = 'Enable Hitbox Expander',
    Default = true,
    Callback = function(Value)
        Settings.HitboxExpander.Enabled = Value
    end
})

HitboxBox:AddSlider('HeadSize', {
    Text = 'Head Size',
    Default = 10,
    Min = 2,
    Max = 20,
    Rounding = 0,
    Compact = false,
    Callback = function(Value)
        Settings.HitboxExpander.HeadSize = Value
    end
})

HitboxBox:AddSlider('TorsoSize', {
    Text = 'Torso Size',
    Default = 5,
    Min = 2,
    Max = 15,
    Rounding = 0,
    Compact = false,
    Callback = function(Value)
        Settings.HitboxExpander.TorsoSize = Value
    end
})

-- Quick Swap
local QuickSwapBox = Tabs.Misc:AddLeftGroupbox('Quick Swap')

QuickSwapBox:AddToggle('QuickSwapEnabled', {
    Text = 'Enable Quick Swap',
    Default = false,
    Tooltip = 'Быстрая смена оружия (как в CS)',
    Callback = function(Value)
        Settings.QuickSwap.Enabled = Value
    end
})

QuickSwapBox:AddLabel('Press Q for Quick Swap'):AddKeyPicker('QuickSwapKey', {
    Default = 'Q',
    SyncToggleState = false,
    Mode = 'Hold',
    Text = 'Quick Swap',
    NoUI = false,
    Callback = function(Value)
        if Value then
            QuickSwap()
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

-- Очистка ESP при выходе игрока
Players.PlayerRemoving:Connect(function(player)
    if ESPObjects[player] then
        RemoveESP(player)
    end
end)

-- Основной цикл
RunService.RenderStepped:Connect(function()
    local viewportSize = Camera.ViewportSize
    FOVCircle.Position = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
    FOVCircle.Visible = Settings.Aimbot.ShowFOV and Settings.Aimbot.Enabled
    
    -- Применяем Camera FOV каждый кадр
    UpdateCameraFOV()
    
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
    UpdateHitboxes()
    
    -- Убираем подсветку цели
    if targetHighlight then
        targetHighlight.Visible = false
    end
    
    if Settings.ESP.Enabled then
        -- Очистка ESP для игроков которые вышли
        for target, _ in pairs(ESPObjects) do
            if target:IsA("Player") then
                local stillInGame = false
                for _, player in pairs(Players:GetPlayers()) do
                    if player == target then
                        stillInGame = true
                        break
                    end
                end
                if not stillInGame then
                    RemoveESP(target)
                end
            end
        end
        
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
                RemoveESP(npc)
                NPCList[npc] = nil
            end
        end
    else
        -- Скрываем все ESP если выключено
        for target, esp in pairs(ESPObjects) do
            for _, obj in pairs(esp) do
                obj.Visible = false
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
