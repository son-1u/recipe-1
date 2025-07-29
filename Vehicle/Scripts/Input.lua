local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local controllers = {
	[Enum.UserInputType.Keyboard] = require(script.Keyboard),
	[Enum.UserInputType.MouseMovement] = require(script.Mouse), --TODO: maybe revamp mousemovement to be a part of keyboard to avoid Enum.LastInputType.MouseMovement
	[Enum.UserInputType.Touch] = require(script.Mobile),
	[Enum.UserInputType.Gamepad1] = require(script.Gamepad),
}

local Input = {}
Input.__index = Input

export type Input = typeof(setmetatable({} :: {
	enabled: boolean,
	_movement_vector: Vector2,
	_current_controller: Enum.UserInputType | nil,
	
	new: () -> Input,
	enable: (self: Input) -> (),
	disable: (self: Input) -> (),
	get_movement_vector: (self: Input) -> Vector2,
}, Input))

local function on_last_input_type_changed(input: Enum.UserInputType): ()
	for _, controller in pairs(controllers) do
		if controller ~= Input._current_controller then
			continue
		end
		controller:disable()
	end
	controllers[input]:enable()
end

function Input.new(): Input
	local self = setmetatable({}, Input)
	self.enabled = false
	self._movement_vector = Vector2.zero()
	self._current_controller = nil
	
	return self
end

local connection: RBXScriptConnection
function Input.enable(self: Input): ()
	if self.enabled == true then
		return
	end
	self.enabled = true
	
	connection = UserInputService.LastInputTypeChanged:Connect(on_last_input_type_changed)
	GuiService.TouchControlsEnabled = false
end

function Input.disable(self: Input): ()
	if self.enabled == false then
		return
	end
	self.enabled = false
	
	for _, controller in pairs(controllers) do
		controller:disable()
	end
	
	if connection then
		connection:Disconnect()
		connection = nil
	end
	
	GuiService.TouchControlsEnabled = true
end

function Input.get_movement_vector(self: Input): Vector2
	return self._movement_vector
end

return Input
