-- Bee Swarm field helper for executor-side use through roblox-mcp.
-- AlignPosition is only used to enter the selected field. Tokens are collected
-- with normal Humanoid:MoveTo walking.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local FlowerZones = workspace:WaitForChild("FlowerZones")
local Collectibles = workspace:WaitForChild("Collectibles")

local CONFIG = {
	moveSpeed = 85,
	responsiveness = 24,
	reachDistance = 2.75,
	tokenReachDistance = 3.5,
	fieldPadding = 3,
	maxTokenHeight = 18,
	walkRepathInterval = 0.35,
	walkTimeout = 14
}

-- Earlier entries always win. Unlisted token textures are collected afterward.
local TOKEN_PRIORITY = {
	"Token Link",
	"Target Practice",
	"Festive Gift",
	"Bear Morph",
	"Triangulate",
	"Fuzz Bombs",
	"Smile Token",
	"Blue Balloon",
	"Inspire"
}

local function textureId(texture)
	return string.match(tostring(texture or ""), "%d+") or ""
end

local priorityByTexture = {}
local priorityNameByTexture = {}
local tokenDefinitions = ReplicatedStorage:FindFirstChild("Collectibles")
for rank, tokenName in ipairs(TOKEN_PRIORITY) do
	local definition = tokenDefinitions and tokenDefinitions:FindFirstChild(tokenName)
	local icon = definition and definition:FindFirstChild("Icon")
	local id = icon and textureId(icon.Texture) or ""
	if id ~= "" and priorityByTexture[id] == nil then
		priorityByTexture[id] = rank
		priorityNameByTexture[id] = tokenName
	end
end

local Environment = type(getgenv) == "function" and getgenv() or _G
local previous = Environment.__BSS_ALIGN_FIELD_FARM
local previousField = type(previous) == "table" and previous.selectedField or nil
local restartAfterLoad = type(previous) == "table" and previous.running == true
if type(previous) == "table" and type(previous.Destroy) == "function" then
	pcall(previous.Destroy)
end

local State = {
	running = false,
	generation = 0,
	selectedField = nil,
	activeMovement = nil,
	activeHumanoid = nil,
	connections = {}
}
Environment.__BSS_ALIGN_FIELD_FARM = State

local function lower(value)
	return string.lower(tostring(value or ""))
end

local function contains(text, needle)
	return string.find(lower(text), lower(needle), 1, true) ~= nil
end

local function getCharacter()
	local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
	local root = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart", 5)
	return character, humanoid, root
end

local excludedFields = {
	["Ant Field"] = true,
	["Hub Field"] = true
}

local function usableField(zone)
	return zone:IsA("BasePart")
		and not excludedFields[zone.Name]
		and not contains(zone.Name, "Brick Field")
end

local function getFieldNames()
	local names = {}
	for _, zone in ipairs(FlowerZones:GetChildren()) do
		if usableField(zone) then
			table.insert(names, zone.Name)
		end
	end
	table.sort(names)
	return names
end

local fieldNames = getFieldNames()
State.selectedField = table.find(fieldNames, previousField) and previousField
	or (table.find(fieldNames, "Sunflower Field") and "Sunflower Field" or fieldNames[1])

local function getSelectedZone()
	local zone = State.selectedField and FlowerZones:FindFirstChild(State.selectedField)
	return zone and usableField(zone) and zone or nil
end

local function fieldCenter(zone)
	return zone.Position + zone.CFrame.UpVector * (zone.Size.Y * 0.5 + 3)
end

local function pointInField(position, zone, padding)
	if not position or not zone then
		return false
	end

	local localPosition = zone.CFrame:PointToObjectSpace(position)
	local xLimit = zone.Size.X * 0.5 + (padding or 0)
	local zLimit = zone.Size.Z * 0.5 + (padding or 0)
	local yLimit = zone.Size.Y * 0.5 + CONFIG.maxTokenHeight
	return math.abs(localPosition.X) <= xLimit
		and math.abs(localPosition.Z) <= zLimit
		and math.abs(localPosition.Y) <= yLimit
end

local GuiParent = LocalPlayer:WaitForChild("PlayerGui")
if type(gethui) == "function" then
	local ok, result = pcall(gethui)
	if ok and result then
		GuiParent = result
	end
end

local existingGui = GuiParent:FindFirstChild("BSSAlignFieldFarm")
if existingGui then
	existingGui:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "BSSAlignFieldFarm"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = GuiParent

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.AnchorPoint = Vector2.new(0.5, 0.5)
Main.Position = UDim2.fromScale(0.5, 0.46)
Main.Size = UDim2.fromOffset(320, 194)
Main.BackgroundColor3 = Color3.fromRGB(27, 29, 31)
Main.BorderSizePixel = 0
Main.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 6)
MainCorner.Parent = Main

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(73, 78, 82)
MainStroke.Thickness = 1
MainStroke.Parent = Main

local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, 42)
Header.BackgroundColor3 = Color3.fromRGB(36, 39, 41)
Header.BorderSizePixel = 0
Header.Parent = Main

local HeaderCorner = Instance.new("UICorner")
HeaderCorner.CornerRadius = UDim.new(0, 6)
HeaderCorner.Parent = Header

local HeaderFill = Instance.new("Frame")
HeaderFill.AnchorPoint = Vector2.new(0, 1)
HeaderFill.Position = UDim2.new(0, 0, 1, 0)
HeaderFill.Size = UDim2.new(1, 0, 0, 6)
HeaderFill.BackgroundColor3 = Header.BackgroundColor3
HeaderFill.BorderSizePixel = 0
HeaderFill.Parent = Header

local Accent = Instance.new("Frame")
Accent.Size = UDim2.fromOffset(4, 22)
Accent.Position = UDim2.fromOffset(12, 10)
Accent.BackgroundColor3 = Color3.fromRGB(242, 187, 66)
Accent.BorderSizePixel = 0
Accent.Parent = Header

local AccentCorner = Instance.new("UICorner")
AccentCorner.CornerRadius = UDim.new(0, 2)
AccentCorner.Parent = Accent

local Title = Instance.new("TextLabel")
Title.Position = UDim2.fromOffset(25, 0)
Title.Size = UDim2.new(1, -70, 1, 0)
Title.BackgroundTransparency = 1
Title.Font = Enum.Font.GothamSemibold
Title.Text = "Field Farm"
Title.TextColor3 = Color3.fromRGB(242, 244, 245)
Title.TextSize = 16
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

local CloseButton = Instance.new("TextButton")
CloseButton.Name = "Close"
CloseButton.AnchorPoint = Vector2.new(1, 0.5)
CloseButton.Position = UDim2.new(1, -9, 0.5, 0)
CloseButton.Size = UDim2.fromOffset(28, 28)
CloseButton.BackgroundColor3 = Color3.fromRGB(53, 56, 59)
CloseButton.BorderSizePixel = 0
CloseButton.Font = Enum.Font.GothamBold
CloseButton.Text = "X"
CloseButton.TextColor3 = Color3.fromRGB(220, 224, 226)
CloseButton.TextSize = 13
CloseButton.Parent = Header

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 4)
CloseCorner.Parent = CloseButton

local FieldLabel = Instance.new("TextLabel")
FieldLabel.Position = UDim2.fromOffset(16, 53)
FieldLabel.Size = UDim2.fromOffset(288, 18)
FieldLabel.BackgroundTransparency = 1
FieldLabel.Font = Enum.Font.GothamMedium
FieldLabel.Text = "FIELD"
FieldLabel.TextColor3 = Color3.fromRGB(167, 173, 177)
FieldLabel.TextSize = 11
FieldLabel.TextXAlignment = Enum.TextXAlignment.Left
FieldLabel.Parent = Main

local FieldButton = Instance.new("TextButton")
FieldButton.Name = "FieldSelector"
FieldButton.Position = UDim2.fromOffset(16, 75)
FieldButton.Size = UDim2.fromOffset(288, 36)
FieldButton.BackgroundColor3 = Color3.fromRGB(43, 46, 48)
FieldButton.BorderSizePixel = 0
FieldButton.Font = Enum.Font.Gotham
FieldButton.Text = (State.selectedField or "No fields found") .. "   v"
FieldButton.TextColor3 = Color3.fromRGB(236, 239, 240)
FieldButton.TextSize = 14
FieldButton.TextTruncate = Enum.TextTruncate.AtEnd
FieldButton.Parent = Main

local FieldCorner = Instance.new("UICorner")
FieldCorner.CornerRadius = UDim.new(0, 4)
FieldCorner.Parent = FieldButton

local ToggleButton = Instance.new("TextButton")
ToggleButton.Name = "FarmToggle"
ToggleButton.Position = UDim2.fromOffset(16, 122)
ToggleButton.Size = UDim2.fromOffset(288, 38)
ToggleButton.BackgroundColor3 = Color3.fromRGB(42, 150, 91)
ToggleButton.BorderSizePixel = 0
ToggleButton.Font = Enum.Font.GothamSemibold
ToggleButton.Text = "Start"
ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleButton.TextSize = 14
ToggleButton.Parent = Main

local ToggleCorner = Instance.new("UICorner")
ToggleCorner.CornerRadius = UDim.new(0, 4)
ToggleCorner.Parent = ToggleButton

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Name = "Status"
StatusLabel.Position = UDim2.fromOffset(16, 166)
StatusLabel.Size = UDim2.fromOffset(288, 18)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.Text = "Status: Idle"
StatusLabel.TextColor3 = Color3.fromRGB(174, 180, 184)
StatusLabel.TextSize = 12
StatusLabel.TextTruncate = Enum.TextTruncate.AtEnd
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.Parent = Main

local Dropdown = Instance.new("ScrollingFrame")
Dropdown.Name = "FieldList"
Dropdown.Position = UDim2.fromOffset(16, 115)
Dropdown.Size = UDim2.fromOffset(288, 184)
Dropdown.BackgroundColor3 = Color3.fromRGB(35, 38, 40)
Dropdown.BorderSizePixel = 0
Dropdown.CanvasSize = UDim2.fromOffset(0, #fieldNames * 30 + 8)
Dropdown.ScrollBarImageColor3 = Color3.fromRGB(116, 122, 126)
Dropdown.ScrollBarThickness = 4
Dropdown.Visible = false
Dropdown.ZIndex = 20
Dropdown.Parent = Main

local DropdownCorner = Instance.new("UICorner")
DropdownCorner.CornerRadius = UDim.new(0, 4)
DropdownCorner.Parent = Dropdown

local DropdownStroke = Instance.new("UIStroke")
DropdownStroke.Color = Color3.fromRGB(79, 84, 88)
DropdownStroke.Thickness = 1
DropdownStroke.Parent = Dropdown

local DropdownLayout = Instance.new("UIListLayout")
DropdownLayout.Padding = UDim.new(0, 2)
DropdownLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
DropdownLayout.SortOrder = Enum.SortOrder.LayoutOrder
DropdownLayout.Parent = Dropdown

local DropdownPadding = Instance.new("UIPadding")
DropdownPadding.PaddingTop = UDim.new(0, 4)
DropdownPadding.PaddingBottom = UDim.new(0, 4)
DropdownPadding.Parent = Dropdown

local function setStatus(text)
	if StatusLabel.Parent then
		StatusLabel.Text = "Status: " .. text
	end
end

local function updateToggle()
	if not ToggleButton.Parent then
		return
	end
	ToggleButton.Text = State.running and "Stop" or "Start"
	ToggleButton.BackgroundColor3 = State.running
		and Color3.fromRGB(190, 68, 68)
		or Color3.fromRGB(42, 150, 91)
end

local function finishMovement(movement)
	if not movement then
		return
	end

	if movement.noclipConnection then
		movement.noclipConnection:Disconnect()
		movement.noclipConnection = nil
	end
	if movement.align and movement.align.Parent then
		movement.align:Destroy()
	end
	if movement.attachment and movement.attachment.Parent then
		movement.attachment:Destroy()
	end

	for part, canCollide in pairs(movement.collisions or {}) do
		if part.Parent then
			part.CanCollide = canCollide
		end
	end

	if movement.humanoid and movement.humanoid.Parent then
		movement.humanoid.PlatformStand = movement.platformStand
		movement.humanoid.AutoRotate = movement.autoRotate
	end

	if State.activeMovement == movement then
		State.activeMovement = nil
	end
end

local function cancelMovement()
	finishMovement(State.activeMovement)
end

local function alignTravelToField(destination, generation, fieldName)
	local character, humanoid, root = getCharacter()
	if not character or not humanoid or not root or humanoid.Health <= 0 then
		return false
	end

	cancelMovement()

	local collisions = {}
	local function applyNoclip()
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") then
				if collisions[part] == nil then
					collisions[part] = part.CanCollide
				end
				part.CanCollide = false
			end
		end
	end
	applyNoclip()
	local noclipConnection = RunService.Stepped:Connect(applyNoclip)

	local attachment = Instance.new("Attachment")
	attachment.Name = "BSSAlignFarmAttachment"
	attachment.Parent = root

	local align = Instance.new("AlignPosition")
	align.Name = "BSSAlignFarmMover"
	align.Mode = Enum.PositionAlignmentMode.OneAttachment
	align.Attachment0 = attachment
	align.ApplyAtCenterOfMass = true
	align.MaxForce = 1000000000
	align.MaxVelocity = CONFIG.moveSpeed
	align.Responsiveness = CONFIG.responsiveness
	align.RigidityEnabled = false
	align.Position = destination
	align.Parent = root

	local movement = {
		align = align,
		attachment = attachment,
		noclipConnection = noclipConnection,
		collisions = collisions,
		humanoid = humanoid,
		platformStand = humanoid.PlatformStand,
		autoRotate = humanoid.AutoRotate
	}
	State.activeMovement = movement

	humanoid.PlatformStand = true
	humanoid.AutoRotate = false
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero

	local initialDistance = (root.Position - destination).Magnitude
	local timeout = math.clamp(initialDistance / CONFIG.moveSpeed * 3 + 10, 12, 45)
	local startedAt = os.clock()
	local reached = false

	while State.running
		and State.generation == generation
		and State.selectedField == fieldName
		and os.clock() - startedAt < timeout do
		if not root.Parent or humanoid.Health <= 0 then
			break
		end
		if (root.Position - destination).Magnitude <= CONFIG.reachDistance then
			reached = true
			break
		end
		RunService.Heartbeat:Wait()
	end

	finishMovement(movement)
	if root.Parent then
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end
	return reached
end

local function validToken(token)
	if not token
		or token.Parent ~= Collectibles
		or not token:IsA("BasePart")
		or token.Name ~= "C"
		or token.Transparency >= 0.98 then
		return false, ""
	end

	local front = token:FindFirstChild("FrontDecal")
	local back = token:FindFirstChild("BackDecal")
	if not front or not back or not front:IsA("Decal") or not back:IsA("Decal") then
		return false, ""
	end

	local id = textureId(front.Texture)
	return id ~= "" and id == textureId(back.Texture), id
end

local function findToken(zone)
	local _, _, root = getCharacter()
	if not root then
		return nil, nil
	end

	local best = nil
	local bestPriority = nil
	local bestDistance = nil
	local bestName = nil
	for _, token in ipairs(Collectibles:GetChildren()) do
		local isToken, id = validToken(token)
		if isToken and pointInField(token.Position, zone, CONFIG.fieldPadding) then
			local priority = priorityByTexture[id] or (#TOKEN_PRIORITY + 1)
			local distance = (root.Position - token.Position).Magnitude
			if not bestPriority
				or priority < bestPriority
				or (priority == bestPriority and distance < bestDistance) then
				best = token
				bestPriority = priority
				bestDistance = distance
				bestName = priorityNameByTexture[id] or "token"
			end
		end
	end
	return best, bestName
end

local function stopNormalWalk()
	local humanoid = State.activeHumanoid
	State.activeHumanoid = nil
	if humanoid and humanoid.Parent then
		local root = humanoid.Parent:FindFirstChild("HumanoidRootPart")
		if root then
			humanoid:MoveTo(root.Position)
		end
	end
end

local function walkToPosition(destination, generation, fieldName, reachDistance)
	local _, humanoid, root = getCharacter()
	if not humanoid or not root or humanoid.Health <= 0 then
		return false
	end

	stopNormalWalk()
	humanoid.PlatformStand = false
	humanoid.AutoRotate = true
	State.activeHumanoid = humanoid

	local startedAt = os.clock()
	local lastMoveAt = -math.huge
	local reached = false
	while State.running
		and State.generation == generation
		and State.selectedField == fieldName
		and os.clock() - startedAt < CONFIG.walkTimeout do
		if not root.Parent or humanoid.Health <= 0 then
			break
		end
		if (root.Position - destination).Magnitude <= reachDistance then
			reached = true
			break
		end
		if os.clock() - lastMoveAt >= CONFIG.walkRepathInterval then
			humanoid:MoveTo(destination)
			lastMoveAt = os.clock()
		end
		RunService.Heartbeat:Wait()
	end

	if State.activeHumanoid == humanoid then
		State.activeHumanoid = nil
	end
	if root.Parent then
		humanoid:MoveTo(root.Position)
	end
	return reached
end

local function walkToToken(token, generation, fieldName)
	local _, humanoid, root = getCharacter()
	if not humanoid or not root or humanoid.Health <= 0 then
		return false
	end

	stopNormalWalk()
	humanoid.PlatformStand = false
	humanoid.AutoRotate = true
	State.activeHumanoid = humanoid

	local startedAt = os.clock()
	local lastMoveAt = -math.huge
	local reached = false
	while State.running
		and State.generation == generation
		and State.selectedField == fieldName
		and os.clock() - startedAt < CONFIG.walkTimeout do
		local isToken = validToken(token)
		if not isToken then
			reached = true
			break
		end
		if not root.Parent or humanoid.Health <= 0 then
			break
		end
		if (root.Position - token.Position).Magnitude <= CONFIG.tokenReachDistance then
			reached = true
			break
		end
		if os.clock() - lastMoveAt >= CONFIG.walkRepathInterval then
			humanoid:MoveTo(token.Position)
			lastMoveAt = os.clock()
		end
		RunService.Heartbeat:Wait()
	end

	if State.activeHumanoid == humanoid then
		State.activeHumanoid = nil
	end
	if root.Parent then
		humanoid:MoveTo(root.Position)
	end
	return reached
end

local function touchToken(token)
	local _, _, root = getCharacter()
	local isToken = validToken(token)
	if not root or not isToken or type(firetouchinterest) ~= "function" then
		return
	end
	pcall(function()
		firetouchinterest(root, token, 0)
		firetouchinterest(root, token, 1)
	end)
end

local function placeSprinkler(zone)
	setStatus("Placing sprinkler in " .. zone.Name)
	local ok, err = pcall(function()
		local actives = require(ReplicatedStorage:WaitForChild("PlayerActives"))
		local sprinkler = actives.Get("Sprinkler Builder")
		if not sprinkler then
			error("Sprinkler Builder active is unavailable")
		end
		sprinkler:ClientActivate()
	end)
	if not ok then
		warn("[Field Farm] Sprinkler placement failed:", err)
		setStatus("Sprinkler placement was rejected")
	end
	task.wait(0.75)
	return ok
end

local function stopFarm(message)
	State.running = false
	State.generation = State.generation + 1
	cancelMovement()
	stopNormalWalk()
	updateToggle()
	setStatus(message or "Idle")
end

local function farmLoop(generation)
	local activeFieldName = nil
	while State.running and State.generation == generation do
		local zone = getSelectedZone()
		if not zone then
			stopFarm("Selected field is unavailable")
			return
		end

		if activeFieldName ~= zone.Name then
			local _, _, root = getCharacter()
			local ready = root and pointInField(root.Position, zone, 0)
			if not ready then
				setStatus("Noclip travel to " .. zone.Name)
				ready = alignTravelToField(fieldCenter(zone), generation, zone.Name)
			elseif (root.Position - fieldCenter(zone)).Magnitude > 5 then
				setStatus("Walking to field center")
				ready = walkToPosition(fieldCenter(zone), generation, zone.Name, 5)
			end

			if not ready then
				if State.running and State.generation == generation then
					setStatus("Could not reach " .. zone.Name)
					task.wait(0.5)
				end
				continue
			end
			if State.running and State.generation == generation and State.selectedField == zone.Name then
				placeSprinkler(zone)
				activeFieldName = zone.Name
			end
		end

		local token, tokenName = findToken(zone)
		if token then
			setStatus("Walking to " .. tokenName)
			if walkToToken(token, generation, zone.Name) then
				touchToken(token)
			end
			task.wait(0.08)
		else
			setStatus("Waiting for tokens in " .. zone.Name)
			task.wait(0.2)
		end
	end
end

local function startFarm()
	if State.running then
		return
	end
	if not getSelectedZone() then
		setStatus("Choose an available field")
		return
	end
	State.running = true
	State.generation = State.generation + 1
	updateToggle()
	task.spawn(farmLoop, State.generation)
end

for index, fieldName in ipairs(fieldNames) do
	local optionFieldName = fieldName
	local option = Instance.new("TextButton")
	option.Name = optionFieldName
	option.LayoutOrder = index
	option.Size = UDim2.fromOffset(276, 28)
	option.BackgroundColor3 = Color3.fromRGB(45, 48, 50)
	option.BorderSizePixel = 0
	option.Font = Enum.Font.Gotham
	option.Text = "  " .. optionFieldName
	option.TextColor3 = Color3.fromRGB(230, 233, 235)
	option.TextSize = 13
	option.TextXAlignment = Enum.TextXAlignment.Left
	option.ZIndex = 21
	option.Parent = Dropdown

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 3)
	corner.Parent = option

	option.MouseButton1Click:Connect(function()
		State.selectedField = optionFieldName
		FieldButton.Text = optionFieldName .. "   v"
		Dropdown.Visible = false
		setStatus(State.running and "Switching to " .. optionFieldName or "Idle")
	end)
end

FieldButton.MouseButton1Click:Connect(function()
	Dropdown.Visible = not Dropdown.Visible
end)

ToggleButton.MouseButton1Click:Connect(function()
	if State.running then
		stopFarm("Idle")
	else
		startFarm()
	end
end)

local dragging = false
local dragInput = nil
local dragStart = nil
local startPosition = nil

Header.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPosition = Main.Position
		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				dragging = false
			end
		end)
	end
end)

Header.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch then
		dragInput = input
	end
end)

table.insert(State.connections, UserInputService.InputChanged:Connect(function(input)
	if dragging and input == dragInput and dragStart and startPosition then
		local delta = input.Position - dragStart
		Main.Position = UDim2.new(
			startPosition.X.Scale,
			startPosition.X.Offset + delta.X,
			startPosition.Y.Scale,
			startPosition.Y.Offset + delta.Y
		)
	end
end))

local function destroy()
	if Environment.__BSS_ALIGN_FIELD_FARM ~= State then
		return
	end
	stopFarm("Closed")
	for _, connection in ipairs(State.connections) do
		pcall(function()
			connection:Disconnect()
		end)
	end
	if ScreenGui.Parent then
		ScreenGui:Destroy()
	end
	Environment.__BSS_ALIGN_FIELD_FARM = nil
end

State.Start = startFarm
State.Stop = stopFarm
State.Destroy = destroy
State.Gui = ScreenGui

CloseButton.MouseButton1Click:Connect(destroy)
setStatus("Idle")
updateToggle()
if restartAfterLoad then
	startFarm()
end
