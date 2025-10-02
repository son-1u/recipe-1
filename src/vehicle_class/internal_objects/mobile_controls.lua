--[[
Trying some new OOP UI pattern, instead, cloning the entire UI upon request. Hope it works
]]--

-------------------------------SERVICES-------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

--------------------------------IMPORTS-------------------------------

local Signal = require(script.Parent.Parent.utils.Signal)

-------------------------------VARIABLES------------------------------

local mobile_control_ui = ReplicatedStorage:WaitForChild("user_interface").mobile_controls

type SteeringType = {
	BUTTON: number,
	STEERING_WHEEL: number,
}

local Enums = {
	SteeringType = {
		BUTTON = 1,
		STEERING_WHEEL = 2,
	},
}

------------------------MOBILE CONTROL UI CLASS-----------------------

local MobileControlUI = {}
MobileControlUI.__index = MobileControlUI

export type MobileControlUI = typeof(setmetatable({} :: {
	_player: Player,
	_user_interface: ScreenGui,
	_steering_type: SteeringType,
	
	throttle_changed: typeof(Signal),
	steering_changed: typeof(Signal),
	gear_shift_triggered: typeof(Signal),
	camera_change_triggered: typeof(Signal),
	
	_inputs: {
		throttle_button: ImageButton,
		brake_button: ImageButton,
		steer_left: ImageButton,
		steer_right: ImageButton,
		steering_wheel: ImageButton,
	},
}, MobileControlUI))

function MobileControlUI.new(player: Player): MobileControlUI
	local self = setmetatable({
		_player = player,
		_user_interface = mobile_control_ui:Clone(),
		_steering_type = Enums.SteeringType.BUTTON,
		
		throttle_changed = Signal.new(),
		steering_changed = Signal.new(),
		gear_shift_triggered = Signal.new(),
		camera_change_triggered = Signal.new(),
	}, MobileControlUI)
	
	self._user_interface.Parent = self._player.PlayerGui
	
	self._inputs = {
		throttle_button = self._user_interface:WaitForChild("throttle"),
		brake_button = self._user_interface:WaitForChild("brake"),
		steer_left = self._user_interface:WaitForChild("steer_left"),
		steer_right = self._user_interface:WaitForChild("steer_right"),
		steering_wheel = self._user_interface:WaitForChild("steering_wheel"),
	}
	
	local BUTTON_TO_SIGNAL_MAP = {
		[self._inputs._throttle_button] = self.throttle_changed,
		[self._inputs._brake_button] = self.throttle_changed,
		[self._inputs._steer_left] = self.steering_changed,
		[self._inputs._steer_right] = self.steering_changed,
		[self._inputs._steering_wheel] = self.steering_changed,
	}
	local INPUT_MAP = {
		[self._inputs._throttle_button] = 1,
		[self._inputs._brake_button] = -1,
		[self._inputs._steer_right] = 1,
		[self._inputs._steer_left] = -1,
	}
	for _, button: ImageButton in pairs(self._inputs) do
		if button == self._inputs._steering_wheel then
			button.InputChanged:Connect(function()
				-- STEERING WHEEL FUNCTIONALITY
			end)
		end
		button.InputBegan:Connect(function()
			local value = INPUT_MAP[button]
			BUTTON_TO_SIGNAL_MAP[button]:Fire(value)
		end)
		button.InputEnded:Connect(function()
			BUTTON_TO_SIGNAL_MAP[button]:Fire(0)
		end)
	end
	
	return self
end

function MobileControlUI.change_steering_type(self: MobileControlUI, steering_type: SteeringType): ()
	if self._steering_type == steering_type then
		return
	end
	
	local function toggle(button: GuiButton, value: boolean): ()
		button.Active = value
		button.Visible = value
	end
	
	if steering_type == Enums.SteeringType.BUTTON then
		toggle(self._inputs.steering_wheel, false)
		toggle(self._inputs.steer_right, true)
		toggle(self._inputs.steer_left, true)
	elseif steering_type == Enums.SteeringType.STEERING_WHEEL then
		toggle(self._inputs.steer_right, false)
		toggle(self._inputs.steer_left, false)
		toggle(self._inputs.steering_wheel, true)
	end
	
	self._steering_type = steering_type
end

local function clear_table(tbl: {}): ()
	for k, v in pairs(tbl) do
		tbl[k] = nil
	end
end

function MobileControlUI.destroy(self: MobileControlUI): ()
	self._user_interface:Destroy()

	for k, v in pairs(self) do
		if typeof(v) == "table" and getmetatable(v) == Signal then
			v:DisconnectAll()
		end
		if typeof(v) == "ScreenGui" then
			v:Destroy()
		end
		self[k] = nil
	end
end

return MobileControlUI
