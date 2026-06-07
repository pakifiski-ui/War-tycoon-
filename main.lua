-- Выводим текст в консоль для проверки запуска
print("[WT Cheat]: Попытка запуска скрипта...")

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local playerGui = player:WaitForChild("PlayerGui", 10)

if not playerGui then
    warn("[WT Cheat]: Не удалось найти PlayerGui!")
    return
end

-- Настройки
local aimbotEnabled = false
local infAmmoEnabled = false
local fovRadius = 130
local smoothSpeed = 0.15
local maxDistance = 750

-- Защита от повторного запуска (удаляем старое меню, если оно было)
if playerGui:FindFirstChild("MobileMenu") then
    playerGui.MobileMenu:Destroy()
end
if playerGui:FindFirstChild("WT_CheatsGui") then
    playerGui.WT_CheatsGui:Destroy()
end

-- Основной контейнер под FOV и элементы
local mainGui = Instance.new("ScreenGui")
mainGui.Name = "WT_CheatsGui"
mainGui.ResetOnSpawn = false
mainGui.Parent = playerGui

-- Визуальный круг FOV
local fovCircle = Instance.new("Frame")
fovCircle.Name = "FOVCircle"
fovCircle.AnchorPoint = Vector2.new(0.5, 0.5)
fovCircle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
fovCircle.BackgroundTransparency = 0.95
fovCircle.BorderColor3 = Color3.fromRGB(255, 255, 255)
fovCircle.BorderSizePixel = 1
fovCircle.Visible = false
fovCircle.Parent = mainGui

local fovCorner = Instance.new("UICorner")
fovCorner.CornerRadius = UDim.new(1, 0)
fovCorner.Parent = fovCircle

local function updateFOVCirclePosition()
	fovCircle.Size = UDim2.new(0, fovRadius * 2, 0, fovRadius * 2)
	fovCircle.Position = UDim2.new(0, camera.ViewportSize.X / 2, 0, camera.ViewportSize.Y / 2)
end

-- Очистка ESP
local function clearESP()
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			for _, child in ipairs(p.Character:GetChildren()) do
				if child.Name == "WT_ESPBox" then child:Destroy() end
			end
		end
	end
end

-- Создание ESP
local function createESPForCharacter(char, otherPlayer)
	if not aimbotEnabled or otherPlayer == player then return end
	if player.Team ~= nil and otherPlayer.Team == player.Team then return end

	local root = char:WaitForChild("HumanoidRootPart", 5)
	if root and not char:FindFirstChild("WT_ESPBox") then
		local box = Instance.new("BoxHandleAdornment")
		box.Name = "WT_ESPBox"
		box.Size = char:GetExtentsSize() + Vector3.new(0.4, 0.4, 0.4)
		box.Color3 = Color3.fromRGB(255, 60, 60)
		box.AlwaysOnTop = true
		box.ZIndex = 5
		box.Transparency = 0.65
		box.Adornee = root
		box.Parent = char
	end
end

-- Сканирование игроков для ESP
local function monitorPlayers()
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player and p.Character then 
            createESPForCharacter(p.Character, p) 
        end
	end
end

-- Поиск ближайшей цели
local function getClosestPlayerToCenter()
	local closestTarget = nil
	local shortestDistance = math.huge
	local screenCenter = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)

	for _, otherPlayer in ipairs(Players:GetPlayers()) do
		if otherPlayer ~= player and (player.Team == nil or otherPlayer.Team ~= player.Team) then
			local char = otherPlayer.Character
			if char and char:FindFirstChild("Humanoid") and char.Humanoid.Health > 0 then
				local head = char:FindFirstChild("Head")
				local root = char:FindFirstChild("HumanoidRootPart")
				local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				
				if head and root and myRoot then
					local distanceInWorld = (myRoot.Position - root.Position).Magnitude
					if distanceInWorld <= maxDistance then
						local screenPos, onScreen = camera:WorldToViewportPoint(head.Position)
						if onScreen then
							local distanceToCenter = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
							if distanceToCenter <= fovRadius and distanceToCenter < shortestDistance then
								shortestDistance = distanceToCenter
								closestTarget = head
							end
						end
					end
				end
			end
		end
	end
	return closestTarget
end

-- Поток бесконечных патронов
task.spawn(function()
	while true do
		task.wait(0.2)
		if infAmmoEnabled and player.Character then
			local tool = player.Character:FindFirstChildOfClass("Tool")
			if tool then
				local config = tool:FindFirstChild("Configuration") or tool:FindFirstChild("GunConfig") or tool
				for _, obj in ipairs(config:GetDescendants()) do
					if obj:IsA("IntValue") or obj:IsA("NumberValue") then
						if string.find(string.lower(obj.Name), "ammo") or string.find(string.lower(obj.Name), "mag") or obj.Name == "Clip" then
							obj.Value = 999
						end
					end
				end
			end
		end
	end
end)

-- Кадровое обновление Аима
RunService.RenderStepped:Connect(function()
	if aimbotEnabled then
		updateFOVCirclePosition()
		if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			local target = getClosestPlayerToCenter()
			if target then
				local targetCFrame = CFrame.new(camera.CFrame.Position, target.Position)
				camera.CFrame = camera.CFrame:Lerp(targetCFrame, smoothSpeed)
			end
		end
	end
end)

-- Создание UI Меню (Упрощенный и надежный вариант)
local function createMenu()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "MobileMenu"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui

	-- Кнопка открытия
	local openButton = Instance.new("TextButton")
	openButton.Size = UDim2.new(0, 100, 0, 45)
	openButton.Position = UDim2.new(0.02, 0, 0.4, 0)
	openButton.Text = "ОТКРЫТЬ"
	openButton.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
	openButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	openButton.Font = Enum.Font.SourceSansBold
	openButton.TextSize = 16
	openButton.Parent = screenGui
	Instance.new("UICorner", openButton)

	-- Главное окно
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, 280, 0, 300)
	frame.Position = UDim2.new(0.5, 0, 0.5, 0)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	frame.Visible = false
	frame.Parent = screenGui
	Instance.new("UICorner", frame)

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 40)
	title.BackgroundTransparency = 1
	title.Text = "WT Premium Menu"
	title.TextColor3 = Color3.fromRGB(255, 215, 0)
	title.Font = Enum.Font.SourceSansBold
	title.TextSize = 18
	title.Parent = frame

	local closeButton = Instance.new("TextButton")
	closeButton.Size = UDim2.new(0, 40, 0, 40)
	closeButton.Position = UDim2.new(1, -40, 0, 0)
	closeButton.Text = "X"
	closeButton.TextColor3 = Color3.fromRGB(255, 80, 80)
	closeButton.BackgroundTransparency = 1
	closeButton.Font = Enum.Font.SourceSansBold
	closeButton.TextSize = 18
	closeButton.Parent = frame

	-- Кнопка Аимбота
	local toggleButton = Instance.new("TextButton")
	toggleButton.Size = UDim2.new(0.9, 0, 0, 45)
	toggleButton.Position = UDim2.new(0.05, 0, 0, 60)
	toggleButton.Text = "АИМ И ESP: ВЫКЛ"
	toggleButton.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
	toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	toggleButton.Font = Enum.Font.SourceSansBold
	toggleButton.TextSize = 14
	toggleButton.Parent = frame
	Instance.new("UICorner", toggleButton)

	-- Кнопка Патронов
	local ammoButton = Instance.new("TextButton")
	ammoButton.Size = UDim2.new(0.9, 0, 0, 45)
	ammoButton.Position = UDim2.new(0.05, 0, 0, 120)
	ammoButton.Text = "БЕСК. ПАТРОНЫ: ВЫКЛ"
	ammoButton.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
	ammoButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	ammoButton.Font = Enum.Font.SourceSansBold
	ammoButton.TextSize = 14
	ammoButton.Parent = frame
	Instance.new("UICorner", ammoButton)

	-- Обработка событий кликов
	toggleButton.Activated:Connect(function()
		aimbotEnabled = not aimbotEnabled
		if aimbotEnabled then
			toggleButton.Text = "АИМ И ESP: ВКЛ"
			toggleButton.BackgroundColor3 = Color3.fromRGB(40, 160, 40)
			fovCircle.Visible = true
			monitorPlayers()
		else
			toggleButton.Text = "АИМ И ESP: ВЫКЛ"
			toggleButton.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
			fovCircle.Visible = false
			clearESP()
		end
	end)

	ammoButton.Activated:Connect(function()
		infAmmoEnabled = not infAmmoEnabled
		if infAmmoEnabled then
			ammoButton.Text = "БЕСК. ПАТРОНЫ: ВКЛ"
			ammoButton.BackgroundColor3 = Color3.fromRGB(40, 160, 40)
		else
			ammoButton.Text = "БЕСК. ПАТРОНЫ: ВЫКЛ"
			ammoButton.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
		end
	end)

	openButton.Activated:Connect(function() frame.Visible = true; openButton.Visible = false end)
	closeButton.Activated:Connect(function() frame.Visible = false; openButton.Visible = true end)
end

-- Запуск создания интерфейса с проверкой на ошибки
local success, err = pcall(createMenu)
if success then
    print("[WT Cheat]: Меню успешно создано на экране!")
else
    warn("[WT Cheat]: Ошибка при создании меню: " .. tostring(err))
end
