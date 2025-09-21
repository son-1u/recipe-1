--[[
Input class used to allow for multiple input types, interfacing with ROBLOX API, as well as allowing the ability
to enable/disable easily
]]--

-------------------------------SERVICES-------------------------------

local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")

--------------------------------IMPORTS-------------------------------

local config = require(script.Parent.Parent.utils.config).keybinds -- In the future, if we want to allow custom keybinds, move this down to the input class or whatever

------------------------------INPUT CLASS-----------------------------

local Input = {}
Input.__index = Input

export type Input = typeof(setmetatable({} :: {
	enabled: boolean,
	_throttle: number,
	_steer: number,
	_current_input_type: Enum.UserInputType | nil,
	
	new: () -> Input,
	enable: (self: Input) -> (),
	disable: (self: Input) -> (),
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
	[config.gamepad_brake] = 1,
}

local STEER_MAP = {
	[config.kb_steer_right] = 1,
	[config.kb_steer_right_alt] = 1,
	[config.kb_steer_left] = -1,
	[config.kb_steer_left_alt] = -1,
	[config.gamepad_steer] = 1, -- TODO: HEY!!!! I DONT KNOW FIGURE OUT HOW TO READ CONTROLLER INPUT
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
	}, Input)
end

function Input.enable(self: Input): ()
	if self.enabled then
		return
	end
	self.enabled = true
	
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
	end, false,
		config.kb_throttle,
		config.kb_throttle_alt,
		config.kb_brake,
		config.kb_brake_alt,
		config.gamepad_throttle,
		config.gamepad_brake
	)
	
	ContextActionService:BindAction(ACTION_NAMES.STEER, function(_, input_state, input_object: InputObject)
		local value = THROTTLE_MAP[input_object.KeyCode]
		if value then
			return
		end
		
		if input_state == Enum.UserInputState.Begin then
			self._steer = value
		else
			self._steer = 0
		end
	end, false,
		config.kb_steer_left,
		config.kb_steer_left_alt,
		config.kb_steer_right,
		config.kb_steer_right_alt,
		config.gamepad_steer
	)
	
	ContextActionService:BindAction(ACTION_NAMES.SHIFT, function(_, input_state, input_object: InputObject)
		local value = SHIFT_MAP[input_object.KeyCode]
		if not value then
			return
		end
		
		-- TODO: SEND SIGNAL
	end, false,
		config.kb_shift_up,
		config.kb_shift_down,
		config.gamepad_shift_up,
		config.gamepad_shift_down
	)
	
	ContextActionService:BindAction(ACTION_NAMES.CAMERA_CHANGE, function(_, input_state, input_object: InputObject)
		if input_object.KeyCode == config.kb_camera_rearview or input_object.KeyCode == config.gamepad_camera_rearview then
			if input_state == Enum.UserInputState.Begin then
				--ACTION_NAMES
			else
				--ACTION_NAMES
			end
		end
		
		if input_object.KeyCode == config.kb_camera_change or input_object.KeyCode == config.gamepad_camera_change then
			-- TODO: SEND SIGNAL
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
	
	ContextActionService:UnbindAllActions()
	
	GuiService.TouchControlsEnabled = true
end

function Input.get_movement_vector(self: Input): (number, number)
	return self._throttle, self._steer
end

function Input.destroy(self: Input): ()
	if self.enabled then
		self:disable()
	end
	
	for k, v in pairs(self) do
		self[k] = nil
	end
end

return Input
