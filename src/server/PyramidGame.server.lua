-- Pyramid Building Game
-- Players click button to place blocks, building a pyramid from base to tip

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

-- Random hello messages to verify script is running
local helloMessages = {
	"Hello from the desert!",
	"Greetings, pyramid builder!",
	"Welcome to the sands!",
	"Salutations, adventurer!",
	"Hey there, explorer!",
	"Good day, constructor!",
}

local randomHello = helloMessages[math.random(1, #helloMessages)]
print("=" .. string.rep("=", 50))
print(randomHello)
print("=" .. string.rep("=", 50))

-- Create BindableEvent for server-to-server communication (button is also on server)
local placeBlockEvent = Instance.new("BindableEvent")
placeBlockEvent.Name = "PlacePyramidBlock"
placeBlockEvent.Parent = ReplicatedStorage

-- Pyramid configuration
-- Each pyramid is 20% bigger than the previous
local BASE_PYRAMID_SIZE = 7 -- Starting size for first pyramid
local MEGA_PYRAMID_SIZE = 15 -- Reduced size for mega pyramid (west)
local BLOCK_SIZE = 8 -- Size of each block

-- Track pyramid building
local currentPyramidNumber = 0 -- 0 = not started, 1-2 = normal, 3 = mega
local currentPyramidSize = NORMAL_PYRAMID_SIZE
local PYRAMID_CENTER = Vector3.new(0, 0, 30)
local currentBlockIndex = 0
local totalBlocks = 0
local placedBlocks = {}
local pyramidModel = nil

-- Pyramid positions (north, south, east, west around center)
local pyramidPositions = {
	Vector3.new(0, 0, -200),   -- Pyramid 1: North
	Vector3.new(0, 0, 200),    -- Pyramid 2: South
	Vector3.new(200, 0, 0),    -- Pyramid 3: East
	Vector3.new(-200, 0, 0),   -- Pyramid 4: West (Mega)
}

-- Initialize a pyramid
local function startNewPyramid(pyramidNum)
	-- Set pyramid number
	currentPyramidNumber = pyramidNum
	
	-- Determine pyramid size (each 20% bigger than previous)
	if currentPyramidNumber <= 3 then
		-- Progressive sizing: 7, 8.4 (8), 10.08 (10)
		currentPyramidSize = math.floor(BASE_PYRAMID_SIZE * (1.2 ^ (currentPyramidNumber - 1)) + 0.5)
	else
		currentPyramidSize = MEGA_PYRAMID_SIZE
	end
	
	-- Set position
	PYRAMID_CENTER = pyramidPositions[math.min(currentPyramidNumber, #pyramidPositions)]
	
	-- Calculate total blocks needed (we'll remove one for entrance after completion)
	totalBlocks = 0
	for level = 1, currentPyramidSize do
		totalBlocks = totalBlocks + (level * level)
	end
	
	-- Check if pyramid model already exists
	pyramidModel = workspace:FindFirstChild("Pyramid" .. currentPyramidNumber)
	
	if pyramidModel then
		-- Count existing blocks
		local existingBlocks = 0
		for _, child in ipairs(pyramidModel:GetChildren()) do
			if child:IsA("Part") and child.Name:match("^PyramidBlock") then
				existingBlocks = existingBlocks + 1
			end
		end
		currentBlockIndex = existingBlocks
		placedBlocks = {}
		print("Resuming Pyramid #" .. currentPyramidNumber .. " - " .. currentBlockIndex .. " blocks already placed")
	else
		-- Create new model
		currentBlockIndex = 0
		placedBlocks = {}
		pyramidModel = Instance.new("Model")
		pyramidModel.Name = "Pyramid" .. currentPyramidNumber
		pyramidModel.Parent = workspace
		print("Starting new Pyramid #" .. currentPyramidNumber)
	end
	
	local pyramidType = (currentPyramidNumber <= 2) and "Normal" or "MEGA"
	print("=" .. string.rep("=", 50))
	print(pyramidType .. " Pyramid #" .. currentPyramidNumber)
	print("Size: " .. currentPyramidSize .. "x" .. currentPyramidSize .. " base")
	print("Total blocks: " .. totalBlocks)
	print("Blocks placed: " .. currentBlockIndex)
	print("Position: " .. tostring(PYRAMID_CENTER))
	print("=" .. string.rep("=", 50))
end

-- Don't auto-start - wait for button click
print("Pyramid system ready! Click a button to start building!")

-- Function to get block position in spiral pattern (from base to tip)
-- Level 1 = base (largest), Level currentPyramidSize = top (smallest 1x1)
local function getBlockPosition(index)
	-- Calculate which level (1 = base/largest, currentPyramidSize = top/smallest)
	-- Blocks are placed: level 1 (largest base), level 2, ..., level currentPyramidSize (1x1 at top)
	local level = 1
	local currentIndex = 0
	
	-- Count blocks from base (largest level) upward to top (smallest level)
	-- l=currentPyramidSize means largest (e.g., 25x25) -> level 1 (base)
	-- l=1 means 1x1 (1 block) -> level currentPyramidSize (top)
	for l = currentPyramidSize, 1, -1 do
		local blocksInLevel = l * l
		if index > currentIndex + blocksInLevel then
			currentIndex = currentIndex + blocksInLevel
			level = level + 1
		else
			break
		end
	end
	
	-- Calculate position within the level
	local levelIndex = index - currentIndex - 1
	-- Get the actual side length for this level (level 1 = currentPyramidSize, level N = 1)
	local sideLength = currentPyramidSize - level + 1
	
	-- Simple spiral: start at bottom-left, go around perimeter
	-- Skip entrance block in bottom level
	local x, z
	if sideLength == 1 then
		-- Single block
		x, z = 0, 0
	else
		-- Calculate position in spiral around the level
		-- Start from bottom-left corner, go clockwise
		local perimeter = (sideLength - 1) * 4
		local posOnPerimeter = levelIndex % perimeter
		local side = math.floor(posOnPerimeter / (sideLength - 1))
		local posOnSide = posOnPerimeter % (sideLength - 1)
		
		-- Adjust for center offset
		local offset = -sideLength/2 + 0.5
		
		if side == 0 then
			-- Bottom side: left to right
			x = offset + posOnSide
			z = offset
		elseif side == 1 then
			-- Right side: bottom to top
			x = -offset
			z = offset + posOnSide
		elseif side == 2 then
			-- Top side: right to left
			x = -offset - posOnSide
			z = -offset
		else
			-- Left side: top to bottom
			x = offset
			z = -offset - posOnSide
		end
	end
	
	-- Y position: level 1 (base) is at ground, level currentPyramidSize (top) is highest
	-- Level 1 = base (y = BLOCK_SIZE/2), Level currentPyramidSize = top (y = (currentPyramidSize-1)*BLOCK_SIZE + BLOCK_SIZE/2)
	local y = (level - 1) * BLOCK_SIZE + BLOCK_SIZE / 2
	
	return PYRAMID_CENTER + Vector3.new(
		x * BLOCK_SIZE,
		y,
		z * BLOCK_SIZE
	), level
end

-- Place blocks (10 at a time)
local function placeBlocks()
	if currentBlockIndex >= totalBlocks then
		return false
	end
	
	local blocksToPlace = math.min(10, totalBlocks - currentBlockIndex)
	
	for i = 1, blocksToPlace do
		if currentBlockIndex >= totalBlocks then
			break
		end
		
		currentBlockIndex = currentBlockIndex + 1
		local position, level = getBlockPosition(currentBlockIndex)
		
		local block = Instance.new("Part")
		block.Name = "PyramidBlock" .. currentBlockIndex
		block.Size = Vector3.new(BLOCK_SIZE, BLOCK_SIZE, BLOCK_SIZE)
		block.Position = position
		block.Anchored = true
		block.CanCollide = true
		block.Material = Enum.Material.Sand
		
		-- Color based on level (darker at bottom, lighter at top)
		-- Level 1 is base (darkest), level currentPyramidSize is top (lightest)
		local colorValue = 1 - (level / currentPyramidSize) * 0.3
		block.Color = Color3.new(colorValue * 0.8, colorValue * 0.7, colorValue * 0.5)
		
		block.Parent = pyramidModel
		table.insert(placedBlocks, block)
	end
	
	print("Placed " .. blocksToPlace .. " blocks. Total: " .. currentBlockIndex .. " of " .. totalBlocks)
	
	-- Check if complete
	if currentBlockIndex >= totalBlocks then
		local pyramidType = (currentPyramidNumber <= 3) and "Normal" or "MEGA"
		print(pyramidType .. " PYRAMID #" .. currentPyramidNumber .. " COMPLETE! Fireworks!")
		
		-- Create entrance by removing one block from bottom level
		createEntrance()
		
		triggerFireworks()
		
		-- Don't auto-start next pyramid - let user choose with buttons
		print("Pyramid #" .. currentPyramidNumber .. " complete! Click another button to build a different pyramid!")
	end
	
	return true
end

-- Create entrance by removing one block from bottom level
local function createEntrance()
	if not pyramidModel then return end
	
	-- Spawn point is typically at (0, 5, 0) or (0, 0, 0)
	local spawnPoint = Vector3.new(0, 5, 0)
	
	-- Find all blocks in the bottom level (level 1)
	local bottomBlocks = {}
	for _, child in ipairs(pyramidModel:GetChildren()) do
		if child:IsA("Part") and child.Name:match("^PyramidBlock") then
			-- Check if it's at ground level (bottom level)
			local blockY = child.Position.Y
			local expectedBottomY = PYRAMID_CENTER.Y + BLOCK_SIZE / 2
			if math.abs(blockY - expectedBottomY) < 1 then
				table.insert(bottomBlocks, child)
			end
		end
	end
	
	if #bottomBlocks == 0 then
		warn("No bottom blocks found for entrance!")
		return
	end
	
	-- Find the block on the side facing the spawn point
	local directionToSpawn = (spawnPoint - PYRAMID_CENTER)
	directionToSpawn = Vector3.new(directionToSpawn.X, 0, directionToSpawn.Z).Unit
	
	local closestBlock = nil
	local closestDistance = math.huge
	
	for _, block in ipairs(bottomBlocks) do
		local blockPos = block.Position
		local blockDir = (blockPos - PYRAMID_CENTER)
		blockDir = Vector3.new(blockDir.X, 0, blockDir.Z).Unit
		
		-- Check if this block is on the side facing spawn point
		local dot = blockDir:Dot(directionToSpawn)
		if dot > 0.5 then -- Block is on the side facing spawn
			-- Find the one closest to spawn point
			local distance = (blockPos - spawnPoint).Magnitude
			if distance < closestDistance then
				closestDistance = distance
				closestBlock = block
			end
		end
	end
	
	-- If no block found on facing side, just use the closest to spawn point
	if not closestBlock then
		for _, block in ipairs(bottomBlocks) do
			local distance = (block.Position - spawnPoint).Magnitude
			if distance < closestDistance then
				closestDistance = distance
				closestBlock = block
			end
		end
	end
	
	-- Remove the block to create entrance
	if closestBlock then
		print("Creating entrance by removing block at:", closestBlock.Position, "facing spawn point")
		closestBlock:Destroy()
	else
		warn("Could not find block to remove for entrance!")
	end
end

-- Fireworks when pyramid is complete
local function triggerFireworks()
	local colors = {
		Color3.new(1, 0, 0), -- Red
		Color3.new(0, 1, 0), -- Green
		Color3.new(0, 0, 1), -- Blue
		Color3.new(1, 1, 0), -- Yellow
		Color3.new(1, 0, 1), -- Magenta
		Color3.new(0, 1, 1), -- Cyan
	}
	
	local fireworksCount = 20
	local delay = 0
	
	for i = 1, fireworksCount do
		delay = delay + 0.2
		task.wait(delay)
		
		local firework = Instance.new("Explosion")
		firework.Position = PYRAMID_CENTER + Vector3.new(
			math.random(-50, 50),
			math.random(50, 100),
			math.random(-50, 50)
		)
		firework.BlastRadius = 0
		firework.BlastPressure = 0
		firework.Visible = false
		
		-- Create colorful particles
		for j = 1, 30 do
			local particle = Instance.new("Part")
			particle.Name = "FireworkParticle"
			particle.Size = Vector3.new(0.5, 0.5, 0.5)
			particle.Shape = Enum.PartType.Ball
			particle.Material = Enum.Material.Neon
			particle.Color = colors[math.random(1, #colors)]
			particle.Anchored = false
			particle.CanCollide = false
			particle.Position = firework.Position
			particle.Velocity = Vector3.new(
				math.random(-30, 30),
				math.random(10, 30),
				math.random(-30, 30)
			)
			particle.Parent = workspace
			
			game:GetService("Debris"):AddItem(particle, 3)
		end
		
		firework.Parent = workspace
	end
end

-- Create build button - SIMPLE VERSION
local function createBuildButton()
	print("Creating build button...")
	
	-- Create a MASSIVE simple box
	local button = Instance.new("Part")
	button.Name = "BuildButton"
	button.Size = Vector3.new(40, 40, 40) -- HUGE box
	button.Position = Vector3.new(0, 20, 0) -- High up, center of map
	button.Anchored = true
	button.CanCollide = false
	button.Color = Color3.new(0, 1, 0) -- Bright green
	button.Material = Enum.Material.Neon
	button.Shape = Enum.PartType.Block
	button.Parent = workspace
	
	print("Button part created at:", button.Position)
	print("Button size:", button.Size)
	print("Button in workspace:", button.Parent == workspace)
	
	-- Add bright light
	local light = Instance.new("PointLight")
	light.Color = Color3.new(0, 1, 0)
	light.Brightness = 10
	light.Range = 100
	light.Parent = button
	
	-- Click detector
	local clickDetector = Instance.new("ClickDetector")
	clickDetector.MaxActivationDistance = 200
	clickDetector.Parent = button
	
	-- Billboard with text
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 400, 0, 200)
	billboard.StudsOffset = Vector3.new(0, 25, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = button
	
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundColor3 = Color3.new(0, 0.5, 0)
	label.BackgroundTransparency = 0.3
	label.BorderSizePixel = 5
	label.BorderColor3 = Color3.new(0, 1, 0)
	label.Text = "BUILD BUTTON\n\nCLICK TO ADD 10 BLOCKS"
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextSize = 50
	label.Font = Enum.Font.GothamBold
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.Parent = billboard
	
	-- Click handler
	clickDetector.MouseClick:Connect(function(player)
		print(player.Name .. " clicked the build button!")
		if currentBlockIndex < totalBlocks then
			placeBlocks()
		else
			print("Pyramid complete!")
		end
	end)
	
	-- Simple pulsing
	local startTime = tick()
	RunService.Heartbeat:Connect(function()
		local pulse = math.sin((tick() - startTime) * 3) * 0.3 + 0.7
		button.Transparency = 1 - pulse
		light.Brightness = 10 * pulse
	end)
	
	print("Build button COMPLETE! Look for a HUGE GREEN BOX at (0, 20, 0)")
	print("Button visible:", button.Transparency < 1)
end

-- Handle button clicks (BindableEvent)
placeBlockEvent.Event:Connect(function(player, requestedPyramidNumber)
	print("PlacePyramidBlock event received from:", player and player.Name or "unknown", "for pyramid:", requestedPyramidNumber)
	
	if not requestedPyramidNumber then
		warn("No pyramid number specified!")
		return
	end
	
	-- If requesting a different pyramid, switch to it
	if requestedPyramidNumber ~= currentPyramidNumber then
		-- Switch to the requested pyramid
		startNewPyramid(requestedPyramidNumber)
	end
	
	-- Start pyramid if not started (shouldn't happen, but safety check)
	if currentPyramidNumber == 0 then
		startNewPyramid(requestedPyramidNumber)
	end
	
	-- Place blocks if pyramid is not complete
	if currentBlockIndex < totalBlocks then
		placeBlocks()
	else
		print("Pyramid #" .. currentPyramidNumber .. " is complete!")
	end
end)

-- Create desert environment
local function createDesertEnvironment()
	-- Change terrain to desert
	local terrain = workspace.Terrain
	if terrain then
		-- Set terrain material to sand
		-- Note: This requires Terrain API which may need specific setup
	end
	
	-- Create river
	local river = Instance.new("Part")
	river.Name = "River"
	river.Size = Vector3.new(200, 5, 20)
	river.Position = Vector3.new(0, 2.5, 80)
	river.Anchored = true
	river.CanCollide = false
	river.Transparency = 0.3
	river.Color = Color3.new(0.2, 0.6, 0.9)
	river.Material = Enum.Material.Water
	river.Parent = workspace
	
	-- Create palm trees along river banks
	local function createPalmTree(position)
		local tree = Instance.new("Model")
		tree.Name = "PalmTree"
		
		-- Trunk
		local trunk = Instance.new("Part")
		trunk.Name = "Trunk"
		trunk.Size = Vector3.new(2, 12, 2)
		trunk.Position = position + Vector3.new(0, 6, 0)
		trunk.Anchored = true
		trunk.BrickColor = BrickColor.new("Brown")
		trunk.Material = Enum.Material.Wood
		trunk.Parent = tree
		
		-- Leaves
		for i = 1, 8 do
			local angle = (i / 8) * math.pi * 2
			local leaf = Instance.new("Part")
			leaf.Name = "Leaf" .. i
			leaf.Size = Vector3.new(0.3, 6, 2)
			leaf.Position = position + Vector3.new(
				math.cos(angle) * 3,
				12,
				math.sin(angle) * 3
			)
			leaf.Anchored = true
			leaf.BrickColor = BrickColor.new("Bright green")
			leaf.Material = Enum.Material.Grass
			leaf.Rotation = Vector3.new(0, math.deg(angle), -20)
			leaf.Parent = tree
		end
		
		tree.Parent = workspace
	end
	
	-- Place palm trees
	for i = 1, 10 do
		local side = (i % 2 == 0) and 1 or -1
		local z = 80 + side * 15
		local x = (i - 5) * 20
		createPalmTree(Vector3.new(x, 0, z))
	end
	
	-- Create camels
	local function createCamel(position)
		local camel = Instance.new("Model")
		camel.Name = "Camel"
		
		-- Body
		local body = Instance.new("Part")
		body.Name = "Body"
		body.Size = Vector3.new(4, 3, 6)
		body.Position = position + Vector3.new(0, 1.5, 0)
		body.Anchored = true
		body.BrickColor = BrickColor.new("Tan")
		body.Material = Enum.Material.Fabric
		body.Parent = camel
		
		-- Head
		local head = Instance.new("Part")
		head.Name = "Head"
		head.Size = Vector3.new(2, 2, 3)
		head.Position = position + Vector3.new(0, 2, -3.5)
		head.Anchored = true
		head.BrickColor = BrickColor.new("Tan")
		head.Material = Enum.Material.Fabric
		head.Parent = camel
		
		-- Legs
		for i = 1, 4 do
			local leg = Instance.new("Part")
			leg.Name = "Leg" .. i
			leg.Size = Vector3.new(0.8, 2, 0.8)
			local offsetX = (i <= 2) and -1.5 or 1.5
			local offsetZ = (i % 2 == 1) and -2 or 2
			leg.Position = position + Vector3.new(offsetX, 1, offsetZ)
			leg.Anchored = true
			leg.BrickColor = BrickColor.new("Tan")
			leg.Material = Enum.Material.Fabric
			leg.Parent = camel
		end
		
		camel.Parent = workspace
	end
	
	-- Place camels
	createCamel(Vector3.new(-30, 0, 60))
	createCamel(Vector3.new(40, 0, 70))
	
	-- Create decorative pyramids (smaller, already built)
	local function createDecorativePyramid(position, size)
		local pyramid = Instance.new("Model")
		pyramid.Name = "DecorativePyramid"
		
		for level = 1, size do
			local sideLength = size - level + 1
			for x = 1, sideLength do
				for z = 1, sideLength do
					local block = Instance.new("Part")
					block.Name = "Block"
					block.Size = Vector3.new(4, 4, 4)
					block.Position = position + Vector3.new(
						(x - sideLength/2 - 0.5) * 4,
						(level - 1) * 4 + 2,
						(z - sideLength/2 - 0.5) * 4
					)
					block.Anchored = true
					block.Material = Enum.Material.Sand
					local colorValue = 1 - (level / size) * 0.3
					block.Color = Color3.new(colorValue * 0.8, colorValue * 0.7, colorValue * 0.5)
					block.Parent = pyramid
				end
			end
		end
		
		pyramid.Parent = workspace
	end
	
	-- Place decorative pyramids
	createDecorativePyramid(Vector3.new(-60, 0, 50), 4)
	createDecorativePyramid(Vector3.new(70, 0, 60), 3)
	createDecorativePyramid(Vector3.new(-80, 0, -40), 5)
	
	-- Set up lighting for desert
	Lighting.Brightness = 1.5
	Lighting.Ambient = Color3.new(0.5, 0.4, 0.3)
	Lighting.ColorShift_Top = Color3.new(1, 0.8, 0.6)
	Lighting.TimeOfDay = "14:00:00" -- Bright afternoon sun
	
	-- Sky
	Lighting.Sky.SkyboxBk = "rbxasset://sky/sky512_bk.tex"
	Lighting.Sky.SkyboxDn = "rbxasset://sky/sky512_dn.tex"
	Lighting.Sky.SkyboxFt = "rbxasset://sky/sky512_ft.tex"
	Lighting.Sky.SkyboxLf = "rbxasset://sky/sky512_lf.tex"
	Lighting.Sky.SkyboxRt = "rbxasset://sky/sky512_rt.tex"
	Lighting.Sky.SkyboxUp = "rbxasset://sky/sky512_up.tex"
	
	-- Sun
	local sun = Instance.new("Sun")
	sun.Parent = Lighting
	sun.AngularSize = 21
	
	-- Fog (optional, for atmosphere)
	Lighting.FogStart = 200
	Lighting.FogEnd = 1000
	Lighting.FogColor = Color3.new(0.9, 0.8, 0.7)
	
	print("Desert environment created!")
end

-- Initialize
createDesertEnvironment()
createBuildButton()
print("Pyramid building game ready! Click the green button to build!")

