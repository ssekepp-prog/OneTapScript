--[[
    One Tap Aimbot & ESP Script V2
    Совместимость: Xeno, Krnl, Synapse, Fluxus
    Игра: [FPS] One Tap
    
    Новые функции:
    - NPC/Bot Detection
    - Silent Aim
    - Auto Shoot
    - Wallbang
    - Third Person Mode
    - Spinbot
    - CS:GO Style GUI
]]

-- Защита от повторного запуска
if getgenv().OneTapLoaded then
    warn("Скрипт уже загружен!")
    return
end
getgenv().OneTapLoaded = true

-- Сервисы
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

-- Настройки по умолчанию
local Settings = {
    Aimbot = {
        Enabled = false,
        SilentAim = false,
        SilentAimMode = "Always",
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
        WallPenetration = 100
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

-- Загрузка сохранённых настроек
if isfile and readfile and isfile("OneTapConfig.json") then
    local success, data = pcall(function()
        return game:GetService("HttpService"):JSONDecode(readfile("OneTapConfig.json"))
    end)
    if success and data then
        for category, options in pairs(data) do
            if Settings[category] then
                for key, value in pairs(options) do
                    if type(value) == "table" and type(Settings[category][key]) == "userdata" then
                        Settings[category][key] = Color3.fromRGB(value.R, value.G, value.B)
                    else
                        Settings[category][key] = value
                    end
                end
            end
        end
    end
end

-- Функция сохранения настроек
local function SaveSettings()
    if writefile then
        local success = pcall(function()
            local saveData = {}
            for category, options in pairs(Settings) do
                saveData[category] = {}
                for key, value in pairs(options) do
                    if type(value) == "userdata" then
                        saveData[category][key] = {R = value.R * 255, G = value.G * 255, B = value.B * 255}
                    else
                        saveData[category][key] = value
                    end
                end
            end
            writefile("OneTapConfig.json", game:GetService("HttpService"):JSONEncode(saveData))
        end)
        if success then
            print("Настройки сохранены!")
        end
    end
end

-- ESP объекты для каждого игрока и NPC
local ESPObjects = {}
local NPCList = {}

-- FOV круг
local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = Settings.Aimbot.FOVThickness
FOVCircle.NumSides = 50
FOVCircle.Radius = Settings.Aimbot.FOV
FOVCircle.Color = Settings.Aimbot.FOVColor
FOVCircle.Visible = Settings.Aimbot.ShowFOV
FOVCircle.Filled = Settings.Aimbot.FOVFilled
FOVCircle.Transparency = Settings.Aimbot.FOVTransparency

-- Переменные для Auto Shoot
local lastShootTime = 0
local currentTarget = nil
local autoShootKeyPressed = false

-- Переменные для Third Person
local originalCameraType = nil
local originalCameraSubject = nil

-- Переменные для Spinbot
local spinAngle = 0

-- Переменные для Bunny Hop
local lastJumpTime = 0
local bhopKeyPressed = false

-- Функция получения всех целей (игроки + NPC)
local function GetAllTargets()
    local targets = {}
    
    -- Добавляем игроков
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
    
    -- Добавляем NPC из workspace
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

-- Функция проверки видимости через стены
local function IsVisible(targetPart)
    -- Если Wallbang включен - игнорируем стены
    if Settings.Wallbang.IgnoreWalls then
        return true
    end
    
    -- Если проверка стен выключена
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

-- Функция получения ближайшего врага в FOV (с поддержкой NPC и приоритетов)
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
                    local distanceFromMouse = (screenPoint - mousePos).Magnitude
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

-- Функция наведения на цель (обычный аим)
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

-- Silent Aim через камеру (альтернативный метод)
local silentAimActive = false
local silentAimTarget = nil
local originalCameraCFrame = nil

local function SilentAimCamera()
    if not Settings.Aimbot.SilentAim then return end
    if not currentTarget or not currentTarget.Character then return end
    
    local targetPart = currentTarget.Character:FindFirstChild(Settings.Aimbot.TargetPart)
    if not targetPart then
        targetPart = currentTarget.Character:FindFirstChild("Head") or currentTarget.Character:FindFirstChild("HumanoidRootPart")
    end
    
    if targetPart then
        silentAimTarget = targetPart
        silentAimActive = true
    end
end

-- Silent Aim функция (подмена направления выстрела)
local silentAimSupported = true

if hookmetamethod and getnamecallmethod then
    -- Метод 1: Через hookmetamethod (если поддерживается)
    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        local args = {...}
        
        if Settings.Aimbot.SilentAim and currentTarget and currentTarget.Character then
            if method == "FireServer" or method == "InvokeServer" then
                local targetPart = currentTarget.Character:FindFirstChild(Settings.Aimbot.TargetPart)
                if targetPart then
                    if args[1] and typeof(args[1]) == "Vector3" then
                        args[1] = targetPart.Position
                    end
                end
            end
        end
        
        return oldNamecall(self, unpack(args))
    end)
    print("[One Tap] Silent Aim: Метод hookmetamethod")
else
    -- Метод 2: Через быстрое наведение камеры (работает везде)
    print("[One Tap] Silent Aim: Метод Camera Snap")
    
    -- Отслеживание нажатия мыши для Silent Aim
    Mouse.Button1Down:Connect(function()
        if Settings.Aimbot.SilentAim and currentTarget and currentTarget.Character then
            local targetPart = currentTarget.Character:FindFirstChild(Settings.Aimbot.TargetPart)
            if not targetPart then
                targetPart = currentTarget.Character:FindFirstChild("Head") or currentTarget.Character:FindFirstChild("HumanoidRootPart")
            end
            
            if targetPart then
                -- Сохраняем оригинальную позицию камеры
                originalCameraCFrame = Camera.CFrame
                
                -- Мгновенно наводим на цель
                local targetPos = targetPart.Position
                local cameraPos = Camera.CFrame.Position
                local direction = (targetPos - cameraPos).Unit
                Camera.CFrame = CFrame.new(cameraPos, cameraPos + direction)
                
                -- Возвращаем камеру через минимальную задержку
                task.spawn(function()
                    task.wait(0.03)
                    if originalCameraCFrame then
                        Camera.CFrame = originalCameraCFrame
                        originalCameraCFrame = nil
                    end
                end)
            end
        end
    end)
end

-- Auto Shoot функция
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
                elseif VirtualInputManager then
                    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
                    task.wait(0.01)
                    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
                end
            end)
            lastShootTime = currentTime
        end
    end
end

-- Third Person функция
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

-- Spinbot функция
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

-- Bunny Hop функция
local function UpdateBunnyHop()
    if not Settings.BunnyHop.Enabled then return end
    if not LocalPlayer.Character then return end
    
    -- Проверка клавиши (если установлена)
    if Settings.BunnyHop.HoldKey ~= "None" and not bhopKeyPressed then
        return
    end
    
    local humanoid = LocalPlayer.Character:FindFirstChild("Humanoid")
    local humanoidRootPart = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not humanoidRootPart then return end
    
    -- Проверка скорости движения
    local currentSpeed = humanoidRootPart.Velocity.Magnitude
    if currentSpeed < Settings.BunnyHop.MinSpeed then return end
    
    -- Проверка, что игрок движется
    if humanoid.MoveDirection.Magnitude <= 0 then return end
    
    -- Проверка, что игрок на земле
    local onGround = humanoid.FloorMaterial ~= Enum.Material.Air
    
    -- Задержка между прыжками (0.1 секунды)
    local currentTime = tick()
    if currentTime - lastJumpTime < 0.1 then return end
    
    if onGround then
        -- Симуляция прыжка
        humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        lastJumpTime = currentTime
        
        -- Auto Strafe: добавление бокового ускорения в воздухе
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

-- Создание ESP объектов для игрока или NPC
local function CreateESP(target)
    local esp = {
        Box = Drawing.new("Square"),
        Name = Drawing.new("Text"),
        HealthBar = Drawing.new("Square"),
        HealthBarOutline = Drawing.new("Square"),
        HealthText = Drawing.new("Text"),
        Distance = Drawing.new("Text"),
        Tracer = Drawing.new("Line")
    }
    
    -- Настройка Box
    esp.Box.Thickness = 2
    esp.Box.Filled = false
    esp.Box.Color = Settings.ESP.BoxColor
    esp.Box.Transparency = 1
    esp.Box.Visible = false
    
    -- Настройка Name
    esp.Name.Size = 14
    esp.Name.Center = true
    esp.Name.Outline = true
    esp.Name.Color = Settings.ESP.NameColor
    esp.Name.Visible = false
    
    -- Настройка Health Bar
    esp.HealthBar.Filled = true
    esp.HealthBar.Color = Settings.ESP.HealthColor
    esp.HealthBar.Transparency = 1
    esp.HealthBar.Visible = false
    
    esp.HealthBarOutline.Thickness = 1
    esp.HealthBarOutline.Filled = false
    esp.HealthBarOutline.Color = Color3.fromRGB(0, 0, 0)
    esp.HealthBarOutline.Transparency = 1
    esp.HealthBarOutline.Visible = false
    
    -- Настройка Health Text
    esp.HealthText.Size = 12
    esp.HealthText.Center = true
    esp.HealthText.Outline = true
    esp.HealthText.Color = Color3.fromRGB(255, 255, 255)
    esp.HealthText.Visible = false
    
    -- Настройка Distance
    esp.Distance.Size = 12
    esp.Distance.Center = true
    esp.Distance.Outline = true
    esp.Distance.Color = Settings.ESP.NameColor
    esp.Distance.Visible = false
    
    -- Настройка Tracer
    esp.Tracer.Thickness = 1
    esp.Tracer.Color = Settings.ESP.TracerColor
    esp.Tracer.Transparency = 1
    esp.Tracer.Visible = false
    
    ESPObjects[target] = esp
end

-- Удаление ESP объектов
local function RemoveESP(target)
    if ESPObjects[target] then
        for _, obj in pairs(ESPObjects[target]) do
            obj:Remove()
        end
        ESPObjects[target] = nil
    end
end

-- Обновление ESP для игрока или NPC
local function UpdateESP(target, targetData)
    if not Settings.ESP.Enabled then return end
    
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
    
    if not humanoid or not rootPart or humanoid.Health <= 0 then
        for _, obj in pairs(esp) do
            obj.Visible = false
        end
        return
    end
    
    local screenPos, onScreen = Camera:WorldToViewportPoint(rootPart.Position)
    
    if not onScreen then
        for _, obj in pairs(esp) do
            obj.Visible = false
        end
        return
    end
    
    -- Вычисление размера бокса
    local headPos = character:FindFirstChild("Head") and character.Head.Position or rootPart.Position + Vector3.new(0, 2, 0)
    local legPos = rootPart.Position - Vector3.new(0, 3, 0)
    
    local topScreen = Camera:WorldToViewportPoint(headPos)
    local bottomScreen = Camera:WorldToViewportPoint(legPos)
    
    local height = math.abs(topScreen.Y - bottomScreen.Y)
    local width = height / 2
    
    -- Обновление Box
    if Settings.ESP.Boxes then
        esp.Box.Size = Vector2.new(width, height)
        esp.Box.Position = Vector2.new(screenPos.X - width / 2, screenPos.Y - height / 2)
        esp.Box.Color = Settings.ESP.BoxColor
        esp.Box.Visible = true
    else
        esp.Box.Visible = false
    end
    
    -- Обновление Name
    if Settings.ESP.Names then
        local displayName = targetData and targetData.Name or (target.Name or "Bot")
        if targetData and targetData.Type == "NPC" then
            displayName = "[NPC] " .. displayName
        end
        esp.Name.Text = displayName
        esp.Name.Position = Vector2.new(screenPos.X, topScreen.Y - 20)
        esp.Name.Color = Settings.ESP.NameColor
        esp.Name.Visible = true
    else
        esp.Name.Visible = false
    end
    
    -- Обновление Health Bar
    if Settings.ESP.Health then
        local healthPercent = humanoid.Health / humanoid.MaxHealth
        local barHeight = height
        local barWidth = 4
        
        esp.HealthBarOutline.Size = Vector2.new(barWidth + 2, barHeight + 2)
        esp.HealthBarOutline.Position = Vector2.new(screenPos.X - width / 2 - barWidth - 4, screenPos.Y - height / 2 - 1)
        esp.HealthBarOutline.Visible = true
        
        esp.HealthBar.Size = Vector2.new(barWidth, barHeight * healthPercent)
        esp.HealthBar.Position = Vector2.new(screenPos.X - width / 2 - barWidth - 3, screenPos.Y + height / 2 - barHeight * healthPercent + 1)
        
        -- Цвет в зависимости от здоровья
        if healthPercent > 0.6 then
            esp.HealthBar.Color = Color3.fromRGB(0, 255, 0)
        elseif healthPercent > 0.3 then
            esp.HealthBar.Color = Color3.fromRGB(255, 255, 0)
        else
            esp.HealthBar.Color = Color3.fromRGB(255, 0, 0)
        end
        
        esp.HealthBar.Visible = true
        
        esp.HealthText.Text = string.format("%d/%d", math.floor(humanoid.Health), math.floor(humanoid.MaxHealth))
        esp.HealthText.Position = Vector2.new(screenPos.X - width / 2 - barWidth - 3, screenPos.Y - height / 2 - 15)
        esp.HealthText.Visible = true
    else
        esp.HealthBar.Visible = false
        esp.HealthBarOutline.Visible = false
        esp.HealthText.Visible = false
    end
    
    -- Обновление Distance
    if Settings.ESP.Distance then
        local distance = (LocalPlayer.Character.HumanoidRootPart.Position - rootPart.Position).Magnitude
        esp.Distance.Text = string.format("[%d studs]", math.floor(distance))
        esp.Distance.Position = Vector2.new(screenPos.X, bottomScreen.Y + 5)
        esp.Distance.Color = Settings.ESP.NameColor
        esp.Distance.Visible = true
    else
        esp.Distance.Visible = false
    end
    
    -- Обновление Tracer
    if Settings.ESP.Tracers then
        esp.Tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
        esp.Tracer.To = Vector2.new(screenPos.X, screenPos.Y)
        esp.Tracer.Color = Settings.ESP.TracerColor
        esp.Tracer.Visible = true
    else
        esp.Tracer.Visible = false
    end
end

-- Инициализация ESP для всех игроков
for _, player in pairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        CreateESP(player)
    end
end

-- События добавления/удаления игроков
Players.PlayerAdded:Connect(function(player)
    CreateESP(player)
end)

Players.PlayerRemoving:Connect(function(player)
    RemoveESP(player)
end)

-- Отслеживание NPC
workspace.DescendantAdded:Connect(function(obj)
    task.wait(0.1)
    if obj:IsA("Model") and obj:FindFirstChild("Humanoid") and obj:FindFirstChild("HumanoidRootPart") then
        local isPlayer = false
        for _, player in pairs(Players:GetPlayers()) do
            if player.Character == obj then
                isPlayer = true
                break
            end
        end
        if not isPlayer and not ESPObjects[obj] then
            CreateESP(obj)
            NPCList[obj] = true
        end
    end
end)

workspace.DescendantRemoving:Connect(function(obj)
    if NPCList[obj] then
        RemoveESP(obj)
        NPCList[obj] = nil
    end
end)

-- Обработка клавиш для Auto Shoot
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if Settings.AutoShoot.AutoShootKey ~= "None" then
        if input.KeyCode.Name == Settings.AutoShoot.AutoShootKey then
            autoShootKeyPressed = true
        end
    end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if Settings.AutoShoot.AutoShootKey ~= "None" then
        if input.KeyCode.Name == Settings.AutoShoot.AutoShootKey then
            autoShootKeyPressed = false
        end
    end
    
    -- Bunny Hop key release
    if Settings.BunnyHop.HoldKey ~= "None" then
        if input.KeyCode.Name == Settings.BunnyHop.HoldKey then
            bhopKeyPressed = false
        end
    end
end)

-- Обработка нажатия клавиши для Bunny Hop
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and Settings.BunnyHop.HoldKey ~= "None" then
        if input.KeyCode.Name == Settings.BunnyHop.HoldKey then
            bhopKeyPressed = true
        end
    end
end)

-- Создание GUI
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "OneTapGUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- Защита GUI от обнаружения
pcall(function()
    if gethui then
        ScreenGui.Parent = gethui()
    elseif syn and syn.protect_gui then
        syn.protect_gui(ScreenGui)
        ScreenGui.Parent = game.CoreGui
    else
        ScreenGui.Parent = game.CoreGui
    end
end)

if not ScreenGui.Parent then
    ScreenGui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
end

-- Главное окно (CS:GO Style)
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 550, 0, 450)
MainFrame.Position = UDim2.new(0.5, -275, 0.5, -225)
MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Visible = false
MainFrame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 8)
UICorner.Parent = MainFrame

-- Заголовок (CS:GO Style)
local Title = Instance.new("TextLabel")
Title.Name = "Title"
Title.Size = UDim2.new(1, 0, 0, 45)
Title.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
Title.BorderSizePixel = 0
Title.Text = "ONE TAP V2 | CS:GO STYLE"
Title.TextColor3 = Color3.fromRGB(255, 215, 0)
Title.TextSize = 20
Title.Font = Enum.Font.GothamBold
Title.Parent = MainFrame

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 8)
TitleCorner.Parent = Title

-- Кнопка закрытия
local CloseButton = Instance.new("TextButton")
CloseButton.Name = "CloseButton"
CloseButton.Size = UDim2.new(0, 30, 0, 30)
CloseButton.Position = UDim2.new(1, -35, 0, 5)
CloseButton.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
CloseButton.BorderSizePixel = 0
CloseButton.Text = "X"
CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseButton.TextSize = 16
CloseButton.Font = Enum.Font.GothamBold
CloseButton.Parent = Title

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 6)
CloseCorner.Parent = CloseButton

CloseButton.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
end)

-- Контейнер для вкладок
local TabContainer = Instance.new("Frame")
TabContainer.Name = "TabContainer"
TabContainer.Size = UDim2.new(1, -20, 0, 38)
TabContainer.Position = UDim2.new(0, 10, 0, 55)
TabContainer.BackgroundTransparency = 1
TabContainer.Parent = MainFrame

-- Контейнер для содержимого
local ContentContainer = Instance.new("Frame")
ContentContainer.Name = "ContentContainer"
ContentContainer.Size = UDim2.new(1, -20, 1, -113)
ContentContainer.Position = UDim2.new(0, 10, 0, 103)
ContentContainer.BackgroundTransparency = 1
ContentContainer.Parent = MainFrame

-- Функция создания вкладки (CS:GO Style)
local currentTab = nil
local function CreateTab(name, position)
    local TabButton = Instance.new("TextButton")
    TabButton.Name = name .. "Tab"
    TabButton.Size = UDim2.new(0, 125, 1, 0)
    TabButton.Position = UDim2.new(0, position, 0, 0)
    TabButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    TabButton.BorderSizePixel = 0
    TabButton.Text = name:upper()
    TabButton.TextColor3 = Color3.fromRGB(180, 180, 180)
    TabButton.TextSize = 13
    TabButton.Font = Enum.Font.GothamBold
    TabButton.Parent = TabContainer
    
    local TabCorner = Instance.new("UICorner")
    TabCorner.CornerRadius = UDim.new(0, 6)
    TabCorner.Parent = TabButton
    
    local TabContent = Instance.new("ScrollingFrame")
    TabContent.Name = name .. "Content"
    TabContent.Size = UDim2.new(1, 0, 1, 0)
    TabContent.BackgroundTransparency = 1
    TabContent.BorderSizePixel = 0
    TabContent.ScrollBarThickness = 4
    TabContent.Visible = false
    TabContent.CanvasSize = UDim2.new(0, 0, 0, 0)
    TabContent.AutomaticCanvasSize = Enum.AutomaticSize.Y
    TabContent.Parent = ContentContainer
    
    TabButton.MouseButton1Click:Connect(function()
        for _, child in pairs(ContentContainer:GetChildren()) do
            if child:IsA("ScrollingFrame") then
                child.Visible = false
            end
        end
        for _, child in pairs(TabContainer:GetChildren()) do
            if child:IsA("TextButton") then
                child.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
                child.TextColor3 = Color3.fromRGB(180, 180, 180)
            end
        end
        TabContent.Visible = true
        TabButton.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
        TabButton.TextColor3 = Color3.fromRGB(255, 215, 0)
        currentTab = TabContent
    end)
    
    return TabContent
end

-- Создание вкладок
local AimbotTab = CreateTab("Aimbot", 0)
local ESPTab = CreateTab("ESP", 120)
local MiscTab = CreateTab("Misc", 240)
local SettingsTab = CreateTab("Settings", 360)

-- Функция создания чекбокса
local function CreateCheckbox(parent, text, defaultValue, callback)
    local yPos = #parent:GetChildren() * 35
    
    local Container = Instance.new("Frame")
    Container.Name = text
    Container.Size = UDim2.new(1, -10, 0, 30)
    Container.Position = UDim2.new(0, 5, 0, yPos)
    Container.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    Container.BorderSizePixel = 0
    Container.Parent = parent
    
    local ContainerCorner = Instance.new("UICorner")
    ContainerCorner.CornerRadius = UDim.new(0, 6)
    ContainerCorner.Parent = Container
    
    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(1, -40, 1, 0)
    Label.Position = UDim2.new(0, 10, 0, 0)
    Label.BackgroundTransparency = 1
    Label.Text = text
    Label.TextColor3 = Color3.fromRGB(255, 255, 255)
    Label.TextSize = 13
    Label.Font = Enum.Font.Gotham
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = Container
    
    local Checkbox = Instance.new("TextButton")
    Checkbox.Size = UDim2.new(0, 20, 0, 20)
    Checkbox.Position = UDim2.new(1, -25, 0.5, -10)
    Checkbox.BackgroundColor3 = defaultValue and Color3.fromRGB(0, 200, 0) or Color3.fromRGB(60, 60, 60)
    Checkbox.BorderSizePixel = 0
    Checkbox.Text = defaultValue and "✓" or ""
    Checkbox.TextColor3 = Color3.fromRGB(255, 255, 255)
    Checkbox.TextSize = 14
    Checkbox.Font = Enum.Font.GothamBold
    Checkbox.Parent = Container
    
    local CheckboxCorner = Instance.new("UICorner")
    CheckboxCorner.CornerRadius = UDim.new(0, 4)
    CheckboxCorner.Parent = Checkbox
    
    local value = defaultValue
    
    Checkbox.MouseButton1Click:Connect(function()
        value = not value
        Checkbox.BackgroundColor3 = value and Color3.fromRGB(0, 200, 0) or Color3.fromRGB(60, 60, 60)
        Checkbox.Text = value and "✓" or ""
        callback(value)
    end)
    
    return Container
end

-- Функция создания слайдера
local function CreateSlider(parent, text, min, max, defaultValue, callback)
    local yPos = #parent:GetChildren() * 35
    
    local Container = Instance.new("Frame")
    Container.Name = text
    Container.Size = UDim2.new(1, -10, 0, 50)
    Container.Position = UDim2.new(0, 5, 0, yPos)
    Container.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    Container.BorderSizePixel = 0
    Container.Parent = parent
    
    local ContainerCorner = Instance.new("UICorner")
    ContainerCorner.CornerRadius = UDim.new(0, 6)
    ContainerCorner.Parent = Container
    
    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(1, -20, 0, 20)
    Label.Position = UDim2.new(0, 10, 0, 5)
    Label.BackgroundTransparency = 1
    Label.Text = text .. ": " .. tostring(defaultValue)
    Label.TextColor3 = Color3.fromRGB(255, 255, 255)
    Label.TextSize = 13
    Label.Font = Enum.Font.Gotham
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = Container
    
    local SliderBack = Instance.new("Frame")
    SliderBack.Size = UDim2.new(1, -20, 0, 6)
    SliderBack.Position = UDim2.new(0, 10, 1, -15)
    SliderBack.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    SliderBack.BorderSizePixel = 0
    SliderBack.Parent = Container
    
    local SliderBackCorner = Instance.new("UICorner")
    SliderBackCorner.CornerRadius = UDim.new(0, 3)
    SliderBackCorner.Parent = SliderBack
    
    local SliderFill = Instance.new("Frame")
    SliderFill.Size = UDim2.new((defaultValue - min) / (max - min), 0, 1, 0)
    SliderFill.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
    SliderFill.BorderSizePixel = 0
    SliderFill.Parent = SliderBack
    
    local SliderFillCorner = Instance.new("UICorner")
    SliderFillCorner.CornerRadius = UDim.new(0, 3)
    SliderFillCorner.Parent = SliderFill
    
    local dragging = false
    local value = defaultValue
    
    local function UpdateSlider(input)
        local pos = math.clamp((input.Position.X - SliderBack.AbsolutePosition.X) / SliderBack.AbsoluteSize.X, 0, 1)
        value = math.floor(min + (max - min) * pos)
        SliderFill.Size = UDim2.new(pos, 0, 1, 0)
        Label.Text = text .. ": " .. tostring(value)
        callback(value)
    end
    
    SliderBack.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            UpdateSlider(input)
        end
    end)
    
    SliderBack.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            UpdateSlider(input)
        end
    end)
    
    return Container
end

-- Функция создания выпадающего списка
local function CreateDropdown(parent, text, options, defaultValue, callback)
    local yPos = #parent:GetChildren() * 35
    
    local Container = Instance.new("Frame")
    Container.Name = text
    Container.Size = UDim2.new(1, -10, 0, 30)
    Container.Position = UDim2.new(0, 5, 0, yPos)
    Container.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    Container.BorderSizePixel = 0
    Container.Parent = parent
    
    local ContainerCorner = Instance.new("UICorner")
    ContainerCorner.CornerRadius = UDim.new(0, 6)
    ContainerCorner.Parent = Container
    
    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(0.5, -10, 1, 0)
    Label.Position = UDim2.new(0, 10, 0, 0)
    Label.BackgroundTransparency = 1
    Label.Text = text
    Label.TextColor3 = Color3.fromRGB(255, 255, 255)
    Label.TextSize = 13
    Label.Font = Enum.Font.Gotham
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = Container
    
    local Dropdown = Instance.new("TextButton")
    Dropdown.Size = UDim2.new(0.5, -10, 0, 25)
    Dropdown.Position = UDim2.new(0.5, 5, 0.5, -12.5)
    Dropdown.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    Dropdown.BorderSizePixel = 0
    Dropdown.Text = defaultValue
    Dropdown.TextColor3 = Color3.fromRGB(255, 255, 255)
    Dropdown.TextSize = 12
    Dropdown.Font = Enum.Font.Gotham
    Dropdown.Parent = Container
    
    local DropdownCorner = Instance.new("UICorner")
    DropdownCorner.CornerRadius = UDim.new(0, 4)
    DropdownCorner.Parent = Dropdown
    
    local DropdownList = Instance.new("Frame")
    DropdownList.Size = UDim2.new(0.5, -10, 0, #options * 25)
    DropdownList.Position = UDim2.new(0.5, 5, 1, 5)
    DropdownList.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    DropdownList.BorderSizePixel = 0
    DropdownList.Visible = false
    DropdownList.ZIndex = 10
    DropdownList.Parent = Container
    
    local DropdownListCorner = Instance.new("UICorner")
    DropdownListCorner.CornerRadius = UDim.new(0, 4)
    DropdownListCorner.Parent = DropdownList
    
    for i, option in ipairs(options) do
        local OptionButton = Instance.new("TextButton")
        OptionButton.Size = UDim2.new(1, 0, 0, 25)
        OptionButton.Position = UDim2.new(0, 0, 0, (i - 1) * 25)
        OptionButton.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
        OptionButton.BorderSizePixel = 0
        OptionButton.Text = option
        OptionButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        OptionButton.TextSize = 12
        OptionButton.Font = Enum.Font.Gotham
        OptionButton.ZIndex = 11
        OptionButton.Parent = DropdownList
        
        OptionButton.MouseButton1Click:Connect(function()
            Dropdown.Text = option
            DropdownList.Visible = false
            callback(option)
        end)
    end
    
    Dropdown.MouseButton1Click:Connect(function()
        DropdownList.Visible = not DropdownList.Visible
    end)
    
    return Container
end

-- Функция создания кнопки
local function CreateButton(parent, text, callback)
    local yPos = #parent:GetChildren() * 35
    
    local Button = Instance.new("TextButton")
    Button.Name = text
    Button.Size = UDim2.new(1, -10, 0, 35)
    Button.Position = UDim2.new(0, 5, 0, yPos)
    Button.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
    Button.BorderSizePixel = 0
    Button.Text = text
    Button.TextColor3 = Color3.fromRGB(255, 255, 255)
    Button.TextSize = 14
    Button.Font = Enum.Font.GothamBold
    Button.Parent = parent
    
    local ButtonCorner = Instance.new("UICorner")
    ButtonCorner.CornerRadius = UDim.new(0, 6)
    ButtonCorner.Parent = Button
    
    Button.MouseButton1Click:Connect(callback)
    
    return Button
end

-- Настройки Aimbot
CreateCheckbox(AimbotTab, "Включить Aimbot", Settings.Aimbot.Enabled, function(value)
    Settings.Aimbot.Enabled = value
end)

CreateCheckbox(AimbotTab, "Silent Aim", Settings.Aimbot.SilentAim, function(value)
    Settings.Aimbot.SilentAim = value
end)

CreateCheckbox(AimbotTab, "Показать FOV круг", Settings.Aimbot.ShowFOV, function(value)
    Settings.Aimbot.ShowFOV = value
    FOVCircle.Visible = value and Settings.Aimbot.Enabled
end)

CreateSlider(AimbotTab, "FOV радиус", 50, 300, Settings.Aimbot.FOV, function(value)
    Settings.Aimbot.FOV = value
    FOVCircle.Radius = value
end)

CreateSlider(AimbotTab, "FOV толщина", 1, 5, Settings.Aimbot.FOVThickness, function(value)
    Settings.Aimbot.FOVThickness = value
    FOVCircle.Thickness = value
end)

CreateCheckbox(AimbotTab, "FOV заливка", Settings.Aimbot.FOVFilled, function(value)
    Settings.Aimbot.FOVFilled = value
    FOVCircle.Filled = value
end)

CreateSlider(AimbotTab, "Плавность (0 = мгновенно)", 0, 100, Settings.Aimbot.Smoothness * 100, function(value)
    Settings.Aimbot.Smoothness = value / 100
end)

CreateDropdown(AimbotTab, "Целиться в", {"Head", "HumanoidRootPart", "UpperTorso"}, Settings.Aimbot.TargetPart, function(value)
    Settings.Aimbot.TargetPart = value
end)

CreateDropdown(AimbotTab, "Приоритет цели", {"Closest to Crosshair", "Lowest Health", "Closest Distance"}, Settings.Aimbot.TargetPriority, function(value)
    Settings.Aimbot.TargetPriority = value
end)

CreateSlider(AimbotTab, "Макс. дистанция", 50, 500, Settings.Aimbot.MaxDistance, function(value)
    Settings.Aimbot.MaxDistance = value
end)

CreateCheckbox(AimbotTab, "Проверка стен", Settings.Aimbot.WallCheck, function(value)
    Settings.Aimbot.WallCheck = value
end)

CreateCheckbox(AimbotTab, "Ignore Walls (Wallbang)", Settings.Wallbang.IgnoreWalls, function(value)
    Settings.Wallbang.IgnoreWalls = value
    if value then
        print("[One Tap] Wallbang включен - стены игнорируются")
    end
end)

-- Auto Shoot настройки
CreateCheckbox(AimbotTab, "Auto Shoot", Settings.AutoShoot.Enabled, function(value)
    Settings.AutoShoot.Enabled = value
end)

CreateSlider(AimbotTab, "Auto Shoot CPS", 1, 20, Settings.AutoShoot.CPS, function(value)
    Settings.AutoShoot.CPS = value
end)

CreateSlider(AimbotTab, "Trigger Delay (ms)", 0, 500, Settings.AutoShoot.TriggerDelay, function(value)
    Settings.AutoShoot.TriggerDelay = value
end)

-- Настройки ESP
CreateCheckbox(ESPTab, "Включить ESP", Settings.ESP.Enabled, function(value)
    Settings.ESP.Enabled = value
    if not value then
        for _, esp in pairs(ESPObjects) do
            for _, obj in pairs(esp) do
                obj.Visible = false
            end
        end
    end
end)

CreateCheckbox(ESPTab, "Показать боксы", Settings.ESP.Boxes, function(value)
    Settings.ESP.Boxes = value
end)

CreateCheckbox(ESPTab, "Показать имена", Settings.ESP.Names, function(value)
    Settings.ESP.Names = value
end)

CreateCheckbox(ESPTab, "Показать здоровье", Settings.ESP.Health, function(value)
    Settings.ESP.Health = value
end)

CreateCheckbox(ESPTab, "Показать дистанцию", Settings.ESP.Distance, function(value)
    Settings.ESP.Distance = value
end)

CreateCheckbox(ESPTab, "Показать трассеры", Settings.ESP.Tracers, function(value)
    Settings.ESP.Tracers = value
end)

-- Настройки Misc (Third Person & Spinbot)
CreateCheckbox(MiscTab, "Third Person Mode", Settings.ThirdPerson.Enabled, function(value)
    Settings.ThirdPerson.Enabled = value
end)

CreateSlider(MiscTab, "Camera Distance", 2, 20, Settings.ThirdPerson.Distance, function(value)
    Settings.ThirdPerson.Distance = value
end)

CreateCheckbox(MiscTab, "Spinbot", Settings.Spinbot.Enabled, function(value)
    Settings.Spinbot.Enabled = value
end)

CreateSlider(MiscTab, "Spin Speed", 1, 100, Settings.Spinbot.Speed, function(value)
    Settings.Spinbot.Speed = value
end)

CreateDropdown(MiscTab, "Spin Axis", {"Yaw", "Pitch", "Both"}, Settings.Spinbot.Axis, function(value)
    Settings.Spinbot.Axis = value
end)

CreateCheckbox(MiscTab, "Jitter", Settings.Spinbot.Jitter, function(value)
    Settings.Spinbot.Jitter = value
end)

CreateSlider(MiscTab, "Jitter Amount", 0, 10, Settings.Spinbot.JitterAmount, function(value)
    Settings.Spinbot.JitterAmount = value
end)

-- Bunny Hop настройки
CreateCheckbox(MiscTab, "Bunny Hop", Settings.BunnyHop.Enabled, function(value)
    Settings.BunnyHop.Enabled = value
end)

CreateDropdown(MiscTab, "Hold Key", {"None", "Space", "LeftControl", "LeftShift"}, Settings.BunnyHop.HoldKey, function(value)
    Settings.BunnyHop.HoldKey = value
end)

CreateCheckbox(MiscTab, "Auto Strafe", Settings.BunnyHop.AutoStrafe, function(value)
    Settings.BunnyHop.AutoStrafe = value
end)

CreateSlider(MiscTab, "Min Speed", 0, 50, Settings.BunnyHop.MinSpeed, function(value)
    Settings.BunnyHop.MinSpeed = value
end)

-- Настройки Settings
CreateButton(SettingsTab, "Сохранить конфигурацию", function()
    SaveSettings()
end)

CreateButton(SettingsTab, "Выгрузить скрипт", function()
    getgenv().OneTapLoaded = false
    
    -- Удаление всех ESP объектов
    for target, esp in pairs(ESPObjects) do
        for _, obj in pairs(esp) do
            obj:Remove()
        end
    end
    ESPObjects = {}
    NPCList = {}
    
    -- Удаление FOV круга
    FOVCircle:Remove()
    
    -- Удаление GUI
    ScreenGui:Destroy()
    
    print("Скрипт выгружен!")
end)

-- Показать первую вкладку
AimbotTab.Visible = true
for _, child in pairs(TabContainer:GetChildren()) do
    if child.Name == "AimbotTab" then
        child.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
        child.TextColor3 = Color3.fromRGB(255, 215, 0)
        break
    end
end

-- Переключение видимости GUI (RightShift или Insert)
local guiVisible = false
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if input.KeyCode == Enum.KeyCode.RightShift or input.KeyCode == Enum.KeyCode.Insert then
        guiVisible = not guiVisible
        MainFrame.Visible = guiVisible
        print("[One Tap] Меню " .. (guiVisible and "открыто" or "закрыто"))
    end
end)

-- Основной цикл обновления
RunService.RenderStepped:Connect(function()
    -- Обновление позиции FOV круга (центр экрана)
    local viewportSize = Camera.ViewportSize
    FOVCircle.Position = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
    FOVCircle.Visible = Settings.Aimbot.ShowFOV and Settings.Aimbot.Enabled
    
    -- Получение текущей цели
    currentTarget = nil
    if Settings.Aimbot.Enabled or Settings.AutoShoot.Enabled then
        currentTarget = GetClosestEnemy()
    end
    
    -- Aimbot (обычный, если Silent Aim выключен или используется Camera Snap метод)
    if Settings.Aimbot.Enabled then
        if currentTarget and currentTarget.Character then
            local targetPart = currentTarget.Character:FindFirstChild(Settings.Aimbot.TargetPart)
            if not targetPart then
                targetPart = currentTarget.Character:FindFirstChild("Head") or currentTarget.Character:FindFirstChild("HumanoidRootPart")
            end
            if targetPart then
                -- Если Silent Aim выключен - используем обычный аим
                if not Settings.Aimbot.SilentAim then
                    AimAt(targetPart)
                end
            end
        end
    end
    
    -- Auto Shoot
    AutoShoot()
    
    -- Third Person
    UpdateThirdPerson()
    
    -- Spinbot
    UpdateSpinbot()
    
    -- Bunny Hop
    UpdateBunnyHop()
    
    -- ESP для игроков
    if Settings.ESP.Enabled then
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                if not ESPObjects[player] then
                    CreateESP(player)
                end
                UpdateESP(player, {Type = "Player", Character = player.Character, Name = player.Name})
            end
        end
        
        -- ESP для NPC
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
    end
end)

print("========================================")
print("ONE TAP V2 - CS:GO STYLE LOADED")
print("========================================")
print("Новые функции:")
print("✓ NPC/Bot Detection")
print("✓ Silent Aim (Camera Snap)")
print("✓ Auto Shoot")
print("✓ Wallbang")
print("✓ Third Person Mode")
print("✓ Spinbot")
print("✓ Bunny Hop")
print("✓ Extended FOV Settings")
print("✓ Target Priority System")
print("========================================")
print("Нажмите RightShift или Insert для меню")
print("GUI Parent:", ScreenGui.Parent and ScreenGui.Parent:GetFullName() or "None")
print("MainFrame создан:", MainFrame ~= nil)
print("=========================================")
