
-- Luau | FPSOptimizer.client.lua | Roblox Studio | StarterPlayerScripts

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Configuration
local TOGGLE_KEY = Enum.KeyCode.P
local SAMPLE_WINDOW = 10
local LOW_SAMPLE_COUNT = 1000

local is_open = false
local is_optimized = false
local frame_times = {}
local frame_time_sum = 0
local last_frame = os.clock()

-- GUI
local gui = Instance.new("ScreenGui")
gui.Name = "FPSOptimizer"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = playerGui

local main = Instance.new("Frame")
main.Size = UDim2.fromOffset(310, 255)
main.Position = UDim2.new(0, 20, 0.5, -127)
main.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
main.BorderSizePixel = 0
main.Visible = false
main.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = main

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(65, 105, 255)
stroke.Thickness = 1.5
stroke.Parent = main

local function create_label(name, text, position, size, font_size)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = Color3.fromRGB(235, 240, 255)
	label.TextSize = font_size
	label.Font = Enum.Font.GothamMedium
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = main
	return label
end

create_label(
	"Title",
	"FPS OPTIMIZER",
	UDim2.fromOffset(18, 12),
	UDim2.fromOffset(250, 30),
	20
).Font = Enum.Font.GothamBold

local fps_label = create_label(
	"FPS",
	"FPS: --",
	UDim2.fromOffset(20, 55),
	UDim2.fromOffset(270, 30),
	18
)

local avg_label = create_label(
	"Average",
	"Average FPS: --",
	UDim2.fromOffset(20, 90),
	UDim2.fromOffset(270, 25),
	15
)

local low_label = create_label(
	"Low",
	"0.1% Low: collecting...",
	UDim2.fromOffset(20, 120),
	UDim2.fromOffset(270, 25),
	15
)

local status_label = create_label(
	"Status",
	"Status: Normal",
	UDim2.fromOffset(20, 153),
	UDim2.fromOffset(270, 25),
	14
)

local optimize_button = Instance.new("TextButton")
optimize_button.Name = "Optimize"
optimize_button.Size = UDim2.fromOffset(270, 42)
optimize_button.Position = UDim2.fromOffset(20, 195)
optimize_button.BackgroundColor3 = Color3.fromRGB(55, 105, 255)
optimize_button.Text = "OPTIMIZE"
optimize_button.TextColor3 = Color3.new(1, 1, 1)
optimize_button.TextSize = 17
optimize_button.Font = Enum.Font.GothamBold
optimize_button.Parent = main

local button_corner = Instance.new("UICorner")
button_corner.CornerRadius = UDim.new(0, 8)
button_corner.Parent = optimize_button

-- Toggle UI
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end

	if input.KeyCode == TOGGLE_KEY then
		is_open = not is_open
		main.Visible = is_open
	end
end)

-- FPS measurement
RunService.RenderStepped:Connect(function()
	local now = os.clock()
	local delta = now - last_frame
	last_frame = now

	if delta <= 0 then
		return
	end

	local fps = 1 / delta

	table.insert(frame_times, delta)
	frame_time_sum += delta

	while #frame_times > LOW_SAMPLE_COUNT do
		frame_time_sum -= table.remove(frame_times, 1)
	end

	fps_label.Text = string.format("FPS: %d", math.floor(fps + 0.5))

	if #frame_times >= 2 then
		-- Harmonic average of FPS = samples / total frame time
		local average_fps = #frame_times / frame_time_sum
		avg_label.Text = string.format("Average FPS: %.1f", average_fps)
	end

	if #frame_times >= LOW_SAMPLE_COUNT then
		-- Approximate 0.1% low using the slowest frame in the window.
		local slowest_frame = 0

		for _, frame_time in ipairs(frame_times) do
			if frame_time > slowest_frame then
				slowest_frame = frame_time
			end
		end

		local low_fps = 1 / slowest_frame
		low_label.Text = string.format("0.1%% Low: %.1f FPS", low_fps)
	else
		low_label.Text = string.format(
			"0.1%% Low: collecting %d/%d",
			#frame_times,
			LOW_SAMPLE_COUNT
		)
	end
end)

-- Save original settings before optimization
local saved_settings = {}
local saved_quality = nil

local function save_property(instance, property)
	local success, value = pcall(function()
		return instance[property]
	end)

	if success then
		saved_settings[instance] = saved_settings[instance] or {}
		saved_settings[instance][property] = value
	end
end

local function change_property(instance, property, value)
	pcall(function()
		instance[property] = value
	end)
end

local function optimize_instance(instance)
	if instance:IsA("ParticleEmitter") then
		save_property(instance, "Enabled")
		save_property(instance, "Rate")
		change_property(instance, "Rate", 0)

	elseif instance:IsA("Trail") or instance:IsA("Beam") then
		save_property(instance, "Enabled")
		change_property(instance, "Enabled", false)

	elseif instance:IsA("Fire")
		or instance:IsA("Smoke")
		or instance:IsA("Sparkles") then

		save_property(instance, "Enabled")
		change_property(instance, "Enabled", false)

	elseif instance:IsA("PointLight")
		or instance:IsA("SpotLight")
		or instance:IsA("SurfaceLight") then

		save_property(instance, "Shadows")
		change_property(instance, "Shadows", false)

	elseif instance:IsA("PostEffect") then
		save_property(instance, "Enabled")
		change_property(instance, "Enabled", false)
	end
end

local function optimize_game()
	if is_optimized then
		return
	end

	is_optimized = true

	status_label.Text = "Status: Optimizing..."
	optimize_button.Text = "OPTIMIZED"
	optimize_button.BackgroundColor3 = Color3.fromRGB(35, 160, 95)

	-- Attempt to lower Roblox graphics quality.
	local success, settings = pcall(function()
		return UserSettings():GetService("UserGameSettings")
	end)

	if success and settings then
		pcall(function()
			saved_quality = settings.SavedQualityLevel
			settings.SavedQualityLevel =
				Enum.SavedQualitySetting.QualityLevel1
		end)
	end

	-- Reduce expensive visual effects.
	for _, instance in ipairs(game:GetDescendants()) do
		optimize_instance(instance)
	end

	-- Optimize newly created effects too.
	game.DescendantAdded:Connect(function(instance)
		if is_optimized then
			optimize_instance(instance)
		end
	end)

	status_label.Text = "Status: Optimized"
end

optimize_button.MouseButton1Click:Connect(optimize_game)
