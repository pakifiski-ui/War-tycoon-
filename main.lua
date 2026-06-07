local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local playerGui = player:WaitForChild("PlayerGui")

-- Глобальные настройки
local aimbotEnabled = false
local infAmmoEnabled = false
local fovRadius = 150
local smoothSpeed = 0.15
local maxDistance = 750

-- Создание контейнера под круг FOV и ESP
local mainGui = Instance.new("ScreenGui")
mainGui.Name = "WT_CheatsGui"
mainGui.ResetOnSpawn = false
mainGui.Parent = playerGui

-- Визуальный круг FOV через интерфейс (работает везде)
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

-- Функция обновления положения круга FOV
local function updateFOVCirclePosition()
	fovCircle.Size = UDim2.new(0, fovRadius * 2, 0, fovRadius * 2)
	fovCircle.Position = UDim2.new(0, camera.ViewportSize.X / 2, 0, camera.ViewportSize.Y / 2)
end

-- Очистка старых боксов ESP
local function clearESP()
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			for _, child in ipairs(p.Character:GetChildren()) do
				if child.Name == "WT_ESPBox" then child:Destroy() end
			end
		end
	end
end

-- Создание стабильного 3D ESP
local function createESPForCharacter(char, otherPlayer)
	if not aimbotEnabled or otherPlayer == player then return end
	if player.Team ~= nil and otherPlayer.Team == player.Team then return end

	local root = char:WaitForChild("HumanoidRootPart", 5)
	local humanoid = char:WaitForChild("Humanoid", 5)
	
	if root and humanoid and not char:FindFirstChild("WT_ESPBox") then
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

-- Мониторинг игроков на сервере
local function monitorPlayers()
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player then
			if p.Character then createESPForCharacter(p.Character, p) end
			p.CharacterAdded:Connect(function(char)
				task.wait(0.4)
				createESPForCharacter(char, p)
			end)
		end
	end
end

Players.PlayerAdded:Connect(function(p)
	p.CharacterAdded:Connect(function(char)
		task.wait(0.4)
		createESPForCharacter(char, p)
	end)
end)

-- Поиск цели (приоритет центру экрана)
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

-- Бесконечные патроны для оружия War Tycoon
task.spawn(function()
	while true do
		task.wait(0.1)
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
				
				local module = tool:FindFirstChildOfClass("ModuleScript")
				if module then
					local success, result = pcall(require, module)
					if success and type(result) == "table" then
						for key, value in pairs(result) do
							if string.find(string.lower(key), "ammo") or string.find(string.lower(key), "mag") or key == "MaxAmmo" or key == "ClipSize" then
								rawset(result, key, 999)
							end
						end
					end
				end
			end
		end
	end
end)

-- Хукинг эвентов перезарядки (без ошибок синтаксиса)
if hookmetamethod then
	local oldFireServer
	oldFireServer = hookmetamethod(game, "__namecall", function(self, ...)
		local method = getnamecallmethod()
		if infAmmoEnabled and method == "FireServer" and self:IsA("RemoteEvent") then
			if string.find(string.lower(self.Name), "reload") or string.find(string.lower(self.Name), "ammo") then
				return nil
			end
		end
		return oldFireServer(self, ...)
	end)
end

-- Ежекадровое обновление Аима и Фова
RunService.RenderStepped:Connect(function()
	if aimbotEnabled then
		updateFOVCirclePosition()
		
		if math.random(1, 8) == 1 then
			for _, p in ipairs(Players:GetPlayers()) do
				if p.Character then createESPForCharacter(p.Character, p) end
			end
		end
		
		if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			local target = getClosestPlayerToCenter()
			if target then
				local targetCFrame = CFrame.new(camera.CFrame.Position, target.Position)
				camera.CFrame = camera.CFrame:Lerp(targetCFrame, smoothSpeed)
			end
		end
	end
end)

-- Создание интерфейса
local function createMenu()
	if playerGui:FindFirstChild("MobileMenu") then return end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "MobileMenu"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui

	local openButton = Instance.new("TextButton")
	openButton.Size = UDim2.new(0.12, 0, 0.06, 0)
	openButton.Position = UDim2.new(0.02, 0, 0.45, 0)
	openButton.Text = "Меню"
	openButton.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
	openButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	openButton.Font = Enum.Font.SourceSansBold
	openButton.TextSize = 16
	openButton.Parent = screenGui
	Instance.new("UICorner", openButton)

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0.42, 0, 0.78, 0)
	frame.Position = UDim2.new(0.5, 0, 0.5, 0)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
	frame.Visible = false
	frame.Parent = screenGui
	Instance.new("UICorner", frame)

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0.12, 0)
	title.BackgroundTransparency = 1
	title.Text = "War Tycoon Premium Menu"
	title.TextColor3 = Color3.fromRGB(255, 215, 0)
	title.Font = Enum.Font.SourceSansBold
	title.TextSize = 20
	title.Parent = frame

	local closeButton = Instance.new("TextButton")
	closeButton.Size = UDim2.new(0, 35, 0, 35)
	closeButton.Position = UDim2.new(1, -40, 0, 5)
	closeButton.Text = "X"
	closeButton.TextColor3 = Color3.fromRGB(255, 80, 80)
	closeButton.BackgroundTransparency = 1
	closeButton.Font = Enum.Font.SourceSansBold
	closeButton.TextSize = 22
	closeButton.Parent = frame

	local toggleButton = Instance.new("TextButton")
	toggleButton.Size = UDim2.new(0.85, 0, 0.12, 0)
	toggleButton.Position = UDim2.new(0.075, 0, 0.15, 0)
	toggleButton.Text = "АИМ И ESP: ВЫКЛ"
	toggleButton.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
	toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	toggleButton.Font = Enum.Font.SourceSansBold
	toggleButton.TextSize = 15
	toggleButton.Parent = frame
	Instance.new("UICorner", toggleButton)

	local ammoButton = Instance.new("TextButton")
	ammoButton.Size = UDim2.new(0.85, 0, 0.12, 0)
	ammoButton.Position = UDim2.new(0.075, 0, 0.29, 0)
	ammoButton.Text = "БЕСК. ПАТРОНЫ (WAR TYCOON): ВЫКЛ"
	ammoButton.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
	ammoButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	ammoButton.Font = Enum.Font.SourceSansBold
	ammoButton.TextSize = 13
	ammoButton.Parent = frame
	Instance.new("UICorner", ammoButton)

	local fovLabel = Instance.new("TextLabel")
	fovLabel.Size = UDim2.new(0.85, 0, 0.08, 0)
	fovLabel.Position = UDim2.new(0.075, 0, 0.46, 0)
	fovLabel.Text = "Угол обзора (FOV): " .. fovRadius
	fovLabel.TextColor3 = Color3.fromRGB(210, 210, 210)
	fovLabel.BackgroundTransparency = 1
	fovLabel.Font = Enum.Font.SourceSans
	fovLabel.TextSize = 14
	fovLabel.Parent = frame

	local fovSlider = Instance.new("TextButton")
	fovSlider.Size = UDim2.new(0.85, 0, 0.05, 0)
	fovSlider.Position = UDim2.new(0.075, 0, 0.55, 0)
	fovSlider.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
	fovSlider.Text = ""
	fovSlider.Parent = frame
	Instance.new("UICorner", fovSlider)

	local fovFill = Instance.new("Frame")
	fovFill.Size = UDim2.new(0.3, 0, 1, 0)
	fovFill.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
	fovFill.BorderSizePixel = 0
	fovFill.Parent = fovSlider
	Instance.new("UICorner", fovFill)

	local smoothLabel = Instance.new("TextLabel")
	smoothLabel.Size = UDim2.new(0.85, 0, 0.08, 0)
	smoothLabel.Position = UDim2.new(0.075, 0, 0.67, 0)
	smoothLabel.Text = "Скорость наводки: Плавная"
	smoothLabel.TextColor3 = Color3.fromRGB(210, 210, 210)
	smoothLabel.BackgroundTransparency = 1
	smoothLabel.Font = Enum.Font.SourceSans
	smoothLabel.TextSize = 14
	smoothLabel.Parent = frame

	local smoothSlider = Instance.new("TextButton")
	smoothSlider.Size = UDim2.new(0.85, 0, 0.05, 0)
	smoothSlider.Position = UDim2.new(0.075, 0, 0.76, 0)
	smoothSlider.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
	smoothSlider.Text = ""
	smoothSlider.Parent = frame
	Instance.new("UICorner", smoothSlider)

	local smoothFill = Instance.new("Frame")
	smoothFill.Size = UDim2.new(0.5, 0, 1, 0)
	smoothFill.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
	smoothFill.BorderSizePixel = 0
	smoothFill.Parent = smoothSlider
	Instance.new("UICorner", smoothFill)

	local function updateFovSlider(input)
		local percentage = math.clamp((input.Position.X - fovSlider.AbsolutePosition.X) / fovSlider.AbsoluteSize.X, 0, 1)
		fovFill.Size = UDim2.new(percentage, 0, 1, 0)
		fovRadius = math.floor(percentage * 350) + 50
		fovLabel.Text = "Угол обзора (FOV): " .. fovRadius
	end

	fovSlider.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			updateFovSlider(input)
			local connection
			connection = UserInputService.InputChanged:Connect(function(changedInput)
				if changedInput.UserInputType == Enum.UserInputType.MouseMovement or changedInput.UserInputType == Enum.UserInputType.Touch then
					updateFovSlider(changedInput)
				end
			end)
			UserInputService.InputEnded:Connect(function(endedInput)
				if endedInput.UserInputType == Enum.UserInputType.MouseButton1 or endedInput.UserInputType == Enum.UserInputType.Touch then
					if connection then connection:Disconnect() end
				end
			end)
		end
	end)

	local function updateSmoothSlider(input)
		local percentage = math.clamp((input.Position.X - smoothSlider.AbsolutePosition.X) / smoothSlider.AbsoluteSize.X, 0, 1)
		smoothFill.Size = UDim2.new(percentage, 0, 1, 0)
		smoothSpeed = percentage * 0.46 + 0.04
		if smoothSpeed > 0.35 then
			smoothLabel.Text = "Скорость наводки: Моментальная"
		elseif smoothSpeed > 0.15 then
			smoothLabel.Text = "Скорость наводки: Средняя"
		else
			smoothLabel.Text = "Скорость наводки: Плавная"
		end
	end

	smoothSlider.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			updateSmoothSlider(input)
			local connection
			connection = UserInputService.InputChanged:Connect(function(changedInput)
				if changedInput.UserInputType == Enum.UserInputType.MouseMovement or changedInput.UserInputType == Enum.UserInputType.Touch then
					updateSmoothSlider(changedInput)
				end
			end)
			UserInputService.InputEnded:Connect(function(endedInput)
				if endedInput.UserInputType == Enum.UserInputType.MouseButton1 or endedInput.UserInputType == Enum.UserInputType.Touch then
					if connection then connection:Disconnect() end
				end
			end)
		end
	end)

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
			ammoButton.Text = "БЕСК. ПАТРОНЫ (WAR TYCOON): ВКЛ"
			ammoButton.BackgroundColor3 = Color3.fromRGB(40, 160, 40)
		else
			ammoButton.Text = "БЕСК. ПАТРОНЫ (WAR TYCOON): ВЫКЛ"
			ammoButton.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
		end
	end)

	openButton.Activated:Connect(function() frame.Visible = true; openButton.Visible = false end)
	closeButton.Activated:Connect(function() frame.Visible = false; openButton.Visible = true end)
end

createMenu()
