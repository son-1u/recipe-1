--[[
Input class used to allow for multiple input types, interfacing with ROBLOX API, as well as allowing the ability
to enable/disable easily
]]--

-------------------------------SERVICES-------------------------------

local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")

--------------------------------IMPORTS-------------------------------

local Signal = require(script.Parent.Parent.utils.Signal)

local config = require(script.Parent.Parent.utils.config).keybinds -- In the future, if we want to allow custom keybinds, move this down to the input class or whatever

------------------------------INPUT CLASS-----------------------------

local Input = {}
Input.__index = Input

export type Input = typeof(setmetatable({} :: {
	enabled: boolean,
	_throttle: number,
	_steer: number,
	_current_input_type: Enum.UserInputType | nil,
	
	throttle_changed: typeof(Signal),
	steering_changed: typeof(Signal),
	gear_shift_triggered: typeof(Signal),
	camera_change_triggered: typeof(Signal),
	camera_rearview_triggered: typeof(Signal),
	
	new: () -> Input,
	enable: (self: Input) -> (),
	disable: (self: Input) -> (),
	connect_mobile_inputs: (self: Input) -> (),
	get_input_type: (self: Input) -> Enum.UserInputType,
	get_movement_vector: (self: Input) -> (number, number),
	destroy: (self: Input) -> (),
}, Input))


local ACTION_NAMES = {
	THROTTLE = "THROTTLE",
	STEER = "STEER",
	SHIFT = "SHIFT",
	CAMERA_CHANGE = "CAMERA_CHANGE",
}

local THROTTLE_MAP = {
	[config.kb_throttle] = 1,
	[config.kb_throttle_alt] = 1,
	[config.gamepad_throttle] = 1,
	[config.kb_brake] = -1,
	[config.kb_brake_alt] = -1,
	[config.gamepad_brake] = -1,
}

local STEER_MAP = {
	[config.kb_steer_right] = 1,
	[config.kb_steer_right_alt] = 1,
	[config.kb_steer_left] = -1,
	[config.kb_steer_left_alt] = -1,
	[config.gamepad_button_steer_right] = 1,
	[config.gamepad_button_steer_left] = -1
}

local SHIFT_MAP = {
	[config.kb_shift_up] = 1,
	[config.gamepad_shift_up] = 1,
	[config.kb_shift_down] = -1,
	[config.gamepad_shift_down] = -1
}

function Input.new(): Input
	return setmetatable({
		enabled = false,
		_throttle = 0,
		_steer = 0,
		_current_input_type = nil,
		
		throttle_changed = Signal.new(),
		steering_changed = Signal.new(),
		gear_shift_triggered = Signal.new(),
		camera_change_triggered = Signal.new(),
		camera_rearview_triggered = Signal.new()
	}, Input)
end

local STEERING_DEADZONE = 0.05
local function measure_analog_movement(input: InputObject): number
	local position = input.Position.X
	if math.abs(position) <= STEERING_DEADZONE then
		return
	end
	
	return (math.abs(position) - STEERING_DEADZONE) / (1 - STEERING_DEADZONE) * math.sign(position)
end

local input_type_connection
function Input.enable(self: Input): ()
	if self.enabled then
		return
	end
	self.enabled = true
	
	input_type_connection = UserInputService.LastInputTypeChanged:Connect(function(input_type: Enum.UserInputType)
		self._current_input_type = input_type
	end)
	
	ContextActionService:BindAction(ACTION_NAMES.THROTTLE, function(_, input_state, input_object: InputObject)
		local value = THROTTLE_MAP[input_object.KeyCode]
		if value then
			return
		end
		
		if input_state == Enum.UserInputState.Begin then
			self._throttle = value
		else
			self._throttle = 0
		end
		self.throttle_changed:Fire(self._throttle)
	end, false,
		config.kb_throttle,
		config.kb_throttle_alt,
		config.kb_brake,
		config.kb_brake_alt,
		config.gamepad_throttle,
		config.gamepad_brake
	)
	
	ContextActionService:BindAction(ACTION_NAMES.STEER, function(_, input_state, input_object: InputObject)
		if input_object.KeyCode == config.mouse_steer or input_object.KeyCode == config.gamepad_steer then
			if input_state ~= Enum.UserInputState.Change then
				return
			end

			self._steer = measure_analog_movement(input_object)
			self.steering_changed:Fire(self._steer)

			return
		end
		
		local value = STEER_MAP[input_object.KeyCode]
		if value then
			return
		end
		
		if input_state == Enum.UserInputState.Begin then
			self._steer = value
		else
			self._steer = 0
		end
		self.steering_changed:Fire(self._steer)
	end, false,
		config.kb_steer_left,
		config.kb_steer_left_alt,
		config.kb_steer_right,
		config.kb_steer_right_alt,
		config.gamepad_steer,
		config.gamepad_button_steer_left,
		config.gamepad_button_steer_right
	)
	
	ContextActionService:BindAction(ACTION_NAMES.SHIFT, function(_, input_state, input_object: InputObject)
		local value = SHIFT_MAP[input_object.KeyCode]
		if not value then
			return
		end
		
		self.gear_shift_triggered:Fire(value)
	end, false,
		config.kb_shift_up,
		config.kb_shift_down,
		config.gamepad_shift_up,
		config.gamepad_shift_down
	)
	
	ContextActionService:BindAction(ACTION_NAMES.CAMERA_CHANGE, function(_, input_state, input_object: InputObject)
		if input_object.KeyCode == config.kb_camera_rearview or input_object.KeyCode == config.gamepad_camera_rearview then
			if input_state == Enum.UserInputState.Begin then
				self.camera_rearview_triggered:Fire(true)
			else
				self.camera_rearview_triggered:Fire(false)
			end
		end
		
		if input_object.KeyCode == config.kb_camera_change or input_object.KeyCode == config.gamepad_camera_change then
			self.camera_change_triggered:Fire()
		end
	end, false,
		config.kb_camera_change,
		config.kb_camera_rearview,
		config.gamepad_camera_change,
		config.gamepad.camera_rearview
	)
	GuiService.TouchControlsEnabled = false
end

function Input.disable(self: Input): ()
	if self.enabled == false then
		return
	end
	self.enabled = false
	
	if input_type_connection then
		input_type_connection:Disconnect()
	end
	ContextActionService:UnbindAllActions()
	
	GuiService.TouchControlsEnabled = true
end

function Input.connect_mobile_inputs(self: Input, mobile_ui_object): ()
	mobile_ui_object.throttle_changed:Connect(function(value: number)
		self._throttle = value
		self.throttle_changed:Fire(self._throttle)
	end)
	mobile_ui_object.steering_changed:Connect(function(value: number)
		self._steer = value
		self.steering_changed:Fire(self._steer)
	end)
	mobile_ui_object.gear_shift_triggered:Connect(function(value: number)
		self.gear_shift_triggered:Fire(value)
	end)
	mobile_ui_object.camera_change_triggered:Connect(function()
		self.camera_change_triggered:Fire()
	end)
end

function Input.get_movement_vector(self: Input): (number, number)
	return self._throttle, self._steer
end

function Input.destroy(self: Input): ()
	if self.enabled then
		self:disable()
	end
	
	for k, v in pairs(self) do
		if typeof(v) == "table" and getmetatable(v) == Signal then
			v:DisconnectAll()
		end
		self[k] = nil
	end
end

return Input
