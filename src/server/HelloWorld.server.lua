-- Updated startup message with last-change timestamp for verification in Studio
local LAST_CHANGED = "2025-11-28 00:00:00 UTC" -- update this timestamp when you edit the file
local now = os.date("%Y-%m-%d %H:%M:%S %Z", os.time())
print("Hello from Cursor! (script start: " .. now .. ") - Last change: " .. LAST_CHANGED)

-- Create three BUILD BUTTONS (one for each pyramid)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function createButton(name, position, color, pyramidNumber)
	local button = Instance.new("Part")
	button.Name = name
	button.Size = Vector3.new(8, 2, 8)
	button.Position = position
	button.Anchored = true
	button.CanCollide = true
	button.BrickColor = BrickColor.new(color)
	button.Material = Enum.Material.SmoothPlastic
	button.Parent = workspace
	
	-- Simple click detector
	local clickDetector = Instance.new("ClickDetector")
	clickDetector.MaxActivationDistance = 50
	clickDetector.Parent = button
	
	-- Simple surface text
	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Face = Enum.NormalId.Top
	surfaceGui.Parent = button
	
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = name
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextSize = 20
	label.Font = Enum.Font.GothamBold
	label.Parent = surfaceGui
	
	-- Wait for the pyramid game to create the event
	local placeBlockEvent = ReplicatedStorage:WaitForChild("PlacePyramidBlock", 5)
	
	if placeBlockEvent then
		clickDetector.MouseClick:Connect(function(player)
			print(player.Name .. " clicked " .. name .. " button!")
			-- Fire the event with pyramid number
			placeBlockEvent:Fire(player, pyramidNumber)
		end)
		print(name .. " button connected to pyramid game!")
	else
		warn("PlacePyramidBlock event not found after waiting!")
	end
	
	return button
end

-- Create four buttons (north, south, east, west)
createButton("NorthPyramid", Vector3.new(0, 1, -50), "Bright green", 1)
createButton("SouthPyramid", Vector3.new(0, 1, 50), "Bright blue", 2)
createButton("EastPyramid", Vector3.new(50, 1, 0), "Bright yellow", 3)
createButton("WestPyramid", Vector3.new(-50, 1, 0), "Bright orange", 4)

print("Four BUILD BUTTONS created!")
