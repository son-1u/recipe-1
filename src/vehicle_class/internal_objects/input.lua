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

------------------------------INPUT CLASS-----------------------------

local Input = {}
Input.__index = Input

export type Input = typeof(setmetatable({} :: {
	enabled: boolean,
	_throttle: number,
	_steer: number,
	_current_input_type: Enum.UserInputType | nil,
	_connections: {},
	_keybinds: {[string]: Enum.KeyCode},
	
	throttle_changed: typeof(Signal),
	steering_changed: typeof(Signal),
	gear_shift_triggered: typeof(Signal),
	camera_change_triggered: typeof(Signal),
	
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

local THROTTLE_MAP = {}
local STEER_MAP = {}
local SHIFT_MAP = {}

function Input.new(input_settings: {[string]: Enum.KeyCode}): Input
	local self = setmetatable({
		enabled = false,
		_throttle = 0,
		_steer = 0,
		_current_input_type = nil,
		_connections = table.create(4), -- When you add more mobile connections, add onto this
		_keybinds = input_settings,
		
		throttle_changed = Signal.new(),
		steering_changed = Signal.new(),
		gear_shift_triggered = Signal.new(),
		camera_change_triggered = Signal.new(),
	}, Input)
	
	THROTTLE_MAP = {
		[self._keybinds.kb_throttle] = 1,
		[self._keybinds.kb_throttle_alt] = 1,
		[self._keybinds.gamepad_throttle] = 1,
		[self._keybinds.kb_brake] = -1,
		[self._keybinds.kb_brake_alt] = -1,
		[self._keybinds.gamepad_brake] = -1,
	}
	
	STEER_MAP = {
		[self._keybinds.kb_steer_right] = 1,
		[self._keybinds.kb_steer_right_alt] = 1,
		[self._keybinds.kb_steer_left] = -1,
		[self._keybinds.kb_steer_left_alt] = -1,
		[self._keybinds.gamepad_button_steer_right] = 1,
		[self._keybinds.gamepad_button_steer_left] = -1,
	}
	
	SHIFT_MAP = {
		[self._keybinds.kb_shift_up] = 1,
		[self._keybinds.gamepad_shift_up] = 1,
		[self._keybinds.kb_shift_down] = -1,
		[self._keybinds.gamepad_shift_down] = -1,
	}
	
	return self
end

local STEERING_DEADZONE = 0.05
local function measure_analog_movement(input_object: InputObject): number
	local position = input_object.Position.X
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
		self._keybinds.kb_throttle,
		self._keybinds.kb_throttle_alt,
		self._keybinds.kb_brake,
		self._keybinds.kb_brake_alt,
		self._keybinds.gamepad_throttle,
		self._keybinds.gamepad_brake
	)
	
	ContextActionService:BindAction(ACTION_NAMES.STEER, function(_, input_state, input_object: InputObject)
		if input_object.KeyCode == self._keybinds.mouse_steer or input_object.KeyCode == self._keybinds.gamepad_steer then
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
		self._keybinds.kb_steer_left,
		self._keybinds.kb_steer_left_alt,
		self._keybinds.kb_steer_right,
		self._keybinds.kb_steer_right_alt,
		self._keybinds.gamepad_steer,
		self._keybinds.gamepad_button_steer_left,
		self._keybinds.gamepad_button_steer_right
	)
	
	ContextActionService:BindAction(ACTION_NAMES.SHIFT, function(_, input_state, input_object: InputObject)
		local value = SHIFT_MAP[input_object.KeyCode]
		if not value then
			return
		end
		
		self.gear_shift_triggered:Fire(value)
	end, false,
		self._keybinds.kb_shift_up,
		self._keybinds.kb_shift_down,
		self._keybinds.gamepad_shift_up,
		self._keybinds.gamepad_shift_down
	)
	
	ContextActionService:BindAction(ACTION_NAMES.CAMERA_CHANGE, function(_, input_state, input_object: InputObject)
		if input_object.KeyCode == self._keybinds.kb_camera_rearview or input_object.KeyCode == self._keybinds.gamepad_camera_rearview then
			if input_state == Enum.UserInputState.Begin then
				self.camera_change_triggered:Fire(true)
			elseif input_state == Enum.UserInputState.End then
				self.camera_change_triggered:Fire(false)
			end
			
			return
		end
		
		if input_object.KeyCode == self._keybinds.kb_camera_change or input_object.KeyCode == self._keybinds.gamepad_camera_change then
			self.camera_change_triggered:Fire()
		end
	end, false,
		self._keybinds.kb_camera_change,
		self._keybinds.kb_camera_rearview,
		self._keybinds.gamepad_camera_change,
		self._keybinds.gamepad.camera_rearview
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
	table.insert(self._connections, mobile_ui_object.throttle_changed:Connect(function(value: number)
		self._throttle = value
		self.throttle_changed:Fire(self._throttle)
	end))
	table.insert(self._connections, mobile_ui_object.steering_changed:Connect(function(value: number)
		self._steer = value
		self.steering_changed:Fire(self._steer)
	end))
	table.insert(self._connections, mobile_ui_object.gear_shift_triggered:Connect(function(value: number)
		self.gear_shift_triggered:Fire(value)
	end))
	table.insert(self._connections, mobile_ui_object.camera_change_triggered:Connect(function(rearview: boolean?)
		self.camera_change_triggered:Fire(rearview)
	end))
end

function Input.get_movement_vector(self: Input): (number, number)
	return self._throttle, self._steer
end

function Input.keybind_changed(self: Input, keybind: string, key_code: Enum.KeyCode): ()
	self._keybinds[keybind] = key_code
end

function Input.destroy(self: Input): ()
	if self.enabled then
		self:disable()
	end
	
	for _, connection in pairs(self._connections) do
		connection:Disconnect()
	end
	
	for k, v in pairs(self) do
		if typeof(v) == "table" and getmetatable(v) == Signal then
			v:DisconnectAll()
		end
		
		self[k] = nil
	end
end

setmetatable(Input, {
	__index = function(tbl, key)
		error(`Attempt to get {tbl}.{key} (not a valid member)`, 2)
	end,
	__newindex = function(tbl, key, value)
		error(`Attempt to set {tbl}.{key} (not a valid operation)`, 2)
	end,
})

return Input
