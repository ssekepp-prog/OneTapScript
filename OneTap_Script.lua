--[[
    One Tap Aimbot & ESP Script
    Совместимость: Xeno, Krnl, Synapse, Fluxus
    Игра: [FPS] One Tap
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

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

-- Настройки по умолчанию
local Settings = {
    Aimbot = {
        Enabled = false,
        FOV = 150,
        ShowFOV = true,
        Smoothness = 0.2,
        TargetPart = "Head",
        MaxDistance = 300,
        WallCheck = true
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
                    Settings[category][key] = value
                end
            end
        end
    end
end

-- Функция сохранения настроек
local function SaveSettings()
    if writefile then
        local success = pcall(function()
            writefile("OneTapConfig.json", game:GetService("HttpService"):JSONEncode(Settings))
        end)
        if success then
            print("Настройки сохранены!")
        end
    end
end

-- ESP объекты для каждого игрока
local ESPObjects = {}

-- FOV круг
local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 2
FOVCircle.NumSides = 50
FOVCircle.Radius = Settings.Aimbot.FOV
FOVCircle.Color = Color3.fromRGB(255, 255, 255)
FOVCircle.Visible = Settings.Aimbot.ShowFOV
FOVCircle.Filled = false
FOVCircle.Transparency = 1

-- Функция проверки видимости через стены
local function IsVisible(targetPart)
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

-- Функция получения ближайшего врага в FOV
local function GetClosestEnemy()
    local closestPlayer = nil
    local shortestDistance = math.huge
    
    local mousePos = Vector2.new(Mouse.X, Mouse.Y)
    local viewportCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local character = player.Character
            if character then
                local humanoid = character:FindFirstChild("Humanoid")
                local targetPart = character:FindFirstChild(Settings.Aimbot.TargetPart)
                
                if humanoid and humanoid.Health > 0 and targetPart then
                    local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
                    
                    if onScreen then
                        local screenPoint = Vector2.new(screenPos.X, screenPos.Y)
                        local distanceFromMouse = (screenPoint - mousePos).Magnitude
                        local distanceFromCenter = (screenPoint - viewportCenter).Magnitude
                        
                        -- Проверка в пределах FOV
                        if distanceFromCenter <= Settings.Aimbot.FOV then
                            local distance3D = (LocalPlayer.Character.HumanoidRootPart.Position - targetPart.Position).Magnitude
                            
                            -- Проверка максимальной дистанции
                            if distance3D <= Settings.Aimbot.MaxDistance then
                                -- Проверка видимости
                                if IsVisible(targetPart) then
                                    if distanceFromMouse < shortestDistance then
                                        shortestDistance = distanceFromMouse
                                        closestPlayer = player
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    return closestPlayer
end

-- Функция наведения на цель
local function AimAt(targetPart)
    if not targetPart then return end
    
    local targetPos = targetPart.Position
    local cameraPos = Camera.CFrame.Position
    
    -- Вычисление направления
    local direction = (targetPos - cameraPos).Unit
    local targetCFrame = CFrame.new(cameraPos, cameraPos + direction)
    
    -- Плавное наведение
    if Settings.Aimbot.Smoothness > 0 then
        Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, 1 - Settings.Aimbot.Smoothness)
    else
        Camera.CFrame = targetCFrame
    end
end

-- Создание ESP объектов для игрока
local function CreateESP(player)
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
    
    ESPObjects[player] = esp
end

-- Удаление ESP объектов
local function RemoveESP(player)
    if ESPObjects[player] then
        for _, obj in pairs(ESPObjects[player]) do
            obj:Remove()
        end
        ESPObjects[player] = nil
    end
end

-- Обновление ESP для игрока
local function UpdateESP(player)
    if not Settings.ESP.Enabled then return end
    
    local esp = ESPObjects[player]
    if not esp then return end
    
    local character = player.Character
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
        esp.Name.Text = player.Name
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

-- Создание GUI
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "OneTapGUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

if gethui then
    ScreenGui.Parent = gethui()
elseif syn and syn.protect_gui then
    syn.protect_gui(ScreenGui)
    ScreenGui.Parent = game.CoreGui
else
    ScreenGui.Parent = game.CoreGui
end

-- Главное окно
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 500, 0, 400)
MainFrame.Position = UDim2.new(0.5, -250, 0.5, -200)
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Visible = false
MainFrame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 8)
UICorner.Parent = MainFrame

-- Заголовок
local Title = Instance.new("TextLabel")
Title.Name = "Title"
Title.Size = UDim2.new(1, 0, 0, 40)
Title.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
Title.BorderSizePixel = 0
Title.Text = "One Tap - Aimbot & ESP"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 18
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
TabContainer.Size = UDim2.new(1, -20, 0, 35)
TabContainer.Position = UDim2.new(0, 10, 0, 50)
TabContainer.BackgroundTransparency = 1
TabContainer.Parent = MainFrame

-- Контейнер для содержимого
local ContentContainer = Instance.new("Frame")
ContentContainer.Name = "ContentContainer"
ContentContainer.Size = UDim2.new(1, -20, 1, -105)
ContentContainer.Position = UDim2.new(0, 10, 0, 95)
ContentContainer.BackgroundTransparency = 1
ContentContainer.Parent = MainFrame

-- Функция создания вкладки
local currentTab = nil
local function CreateTab(name, position)
    local TabButton = Instance.new("TextButton")
    TabButton.Name = name .. "Tab"
    TabButton.Size = UDim2.new(0, 150, 1, 0)
    TabButton.Position = UDim2.new(0, position, 0, 0)
    TabButton.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    TabButton.BorderSizePixel = 0
    TabButton.Text = name
    TabButton.TextColor3 = Color3.fromRGB(200, 200, 200)
    TabButton.TextSize = 14
    TabButton.Font = Enum.Font.Gotham
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
                child.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
                child.TextColor3 = Color3.fromRGB(200, 200, 200)
            end
        end
        TabContent.Visible = true
        TabButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        TabButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        currentTab = TabContent
    end)
    
    return TabContent
end

-- Создание вкладок
local AimbotTab = CreateTab("Aimbot", 0)
local ESPTab = CreateTab("ESP", 160)
local SettingsTab = CreateTab("Settings", 320)

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

CreateCheckbox(AimbotTab, "Показать FOV круг", Settings.Aimbot.ShowFOV, function(value)
    Settings.Aimbot.ShowFOV = value
    FOVCircle.Visible = value and Settings.Aimbot.Enabled
end)

CreateSlider(AimbotTab, "FOV радиус", 50, 300, Settings.Aimbot.FOV, function(value)
    Settings.Aimbot.FOV = value
    FOVCircle.Radius = value
end)

CreateSlider(AimbotTab, "Плавность (0 = мгновенно)", 0, 100, Settings.Aimbot.Smoothness * 100, function(value)
    Settings.Aimbot.Smoothness = value / 100
end)

CreateDropdown(AimbotTab, "Целиться в", {"Head", "HumanoidRootPart", "UpperTorso"}, Settings.Aimbot.TargetPart, function(value)
    Settings.Aimbot.TargetPart = value
end)

CreateSlider(AimbotTab, "Макс. дистанция", 50, 500, Settings.Aimbot.MaxDistance, function(value)
    Settings.Aimbot.MaxDistance = value
end)

CreateCheckbox(AimbotTab, "Проверка стен", Settings.Aimbot.WallCheck, function(value)
    Settings.Aimbot.WallCheck = value
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

-- Настройки Settings
CreateButton(SettingsTab, "Сохранить конфигурацию", function()
    SaveSettings()
end)

CreateButton(SettingsTab, "Выгрузить скрипт", function()
    getgenv().OneTapLoaded = false
    
    -- Удаление всех ESP объектов
    for player, esp in pairs(ESPObjects) do
        for _, obj in pairs(esp) do
            obj:Remove()
        end
    end
    ESPObjects = {}
    
    -- Удаление FOV круга
    FOVCircle:Remove()
    
    -- Удаление GUI
    ScreenGui:Destroy()
    
    -- Отключение всех соединений
    for _, connection in pairs(getconnections(RunService.RenderStepped)) do
        connection:Disconnect()
    end
    
    print("Скрипт выгружен!")
end)

-- Показать первую вкладку
AimbotTab.Visible = true
for _, child in pairs(TabContainer:GetChildren()) do
    if child.Name == "AimbotTab" then
        child.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        child.TextColor3 = Color3.fromRGB(255, 255, 255)
        break
    end
end

-- Переключение видимости GUI
local guiVisible = false
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.RightShift then
        guiVisible = not guiVisible
        MainFrame.Visible = guiVisible
    end
end)

-- Основной цикл обновления
RunService.RenderStepped:Connect(function()
    -- Обновление позиции FOV круга
    FOVCircle.Position = Vector2.new(Mouse.X, Mouse.Y + 36)
    FOVCircle.Visible = Settings.Aimbot.ShowFOV and Settings.Aimbot.Enabled
    
    -- Aimbot
    if Settings.Aimbot.Enabled then
        local target = GetClosestEnemy()
        if target and target.Character then
            local targetPart = target.Character:FindFirstChild(Settings.Aimbot.TargetPart)
            if targetPart then
                AimAt(targetPart)
            end
        end
    end
    
    -- ESP
    if Settings.ESP.Enabled then
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                if not ESPObjects[player] then
                    CreateESP(player)
                end
                UpdateESP(player)
            end
        end
    end
end)

print("One Tap Script загружен! Нажмите RightShift для открытия меню.")
