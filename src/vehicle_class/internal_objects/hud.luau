--[[
Trying some new OOP UI pattern, instead, cloning the entire UI upon request. Hope it works
]]--

-------------------------------SERVICES-------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

--------------------------------IMPORTS-------------------------------

local Signal = require(script.Parent.utils.signal)

-------------------------------VARIABLES------------------------------

local hud_ui = ReplicatedStorage:WaitForChild("user_interface").hud

-------------------------------HUD CLASS------------------------------

local HUD = {}
HUD.__index = HUD

local function create_element(instance: GuiObject, properties: {[string]: any}): Instance
	for k, v in pairs(properties) do
		if instance[k] ~= nil then
			instance[k] = v
		end
	end
	
	return instance
end

local function clone_element(instance: GuiObject, properties: {[string]: any}): Instance
	local clone = instance:Clone()
	for k, v in pairs(properties) do
		if clone[k] ~= nil then
			clone[k] = v
		end
	end
	
	return clone
end

function HUD.new()
	local frame = create_element(Instance.new("Frame"), {
		Size = UDim2.fromScale(0.256, 0.135),
		Position = UDim2.fromScale(0.5, 0.8),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 0.2,
		BackgroundColor3 = Color3.fromRGB(45, 45, 45),
	})
	local stroke = create_element(Instance.new("UIStroke"), {
		Parent = frame,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Miter,
		Thickness = 2,
		Color = Color3.fromRGB(0, 0, 0),
	})
	local text_template = create_element(Instance.new("TextLabel"), {
		Parent = frame,
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.538),
		Size = UDim2.fromScale(0.16, 0.25),
		FontFace = Enum.Font.Cartoon,
		TextColor3 = Color3.fromRGB(240, 240, 240),
		TextSize = 14,
		TextWrapped = true,
	})
	local gear_value = clone_element(text_template, {
		Parent = frame,
		Text = "1",
		Size = UDim2.fromScale(0.12, 0.375),
		Position = UDim2.fromScale(0.5, 0.222),
	})
	local gear_text = clone_element(text_template, {
		Parent = frame,
		Text = "gear",
		Position = UDim2.fromScale(0.5, 0.538),
	})
	
	local speedometer_value = clone_element(text_template, {
		Parent = frame,
		Text = "0",
		Size = UDim2.fromScale(0.12, 0.375),
		Position = UDim2.fromScale(0.2, 0.222),
	})
	local speedometer_unit = clone_element(text_template, {
		Parent = frame,
		Text = "sps",
		Position = UDim2.fromScale(0.2, 0.538),
	})
	
	local tachometer_value = clone_element(text_template, {
		Parent = frame,
		Text = "0",
		Size = UDim2.fromScale(0.12, 0.375),
		Position = UDim2.fromScale(0.8, 0.222),
	})
	local tachometer_unit = clone_element(text_template, {
		Parent = frame,
		Text = "rpm",
		Position = UDim2.fromScale(0.8, 0.538),
	})
	
	local tachometer_holder = create_element(Instance.new("Frame"), {
		Parent = frame,
		BackgroundColor3 = Color3.fromRGB(30, 30, 30),
		Size = UDim2.fromScale(1, 0.125)
	})
	local tachometer_fill = create_element(Instance.new("Frame"), {
		Parent = tachometer_holder,
		Size = UDim2.fromScale(0, 1),
		ZIndex = 2,
	})
	clone_element(stroke, {Parent = tachometer_holder})
	
	return frame
end

function HUD.update(speed: number, rpm: number)
	
end

return HUD
