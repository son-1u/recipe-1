--[[
Settings class. Currently only handles keybinds but can be used for other personal car settings in the future if recipe 1 permits
]]--

--------------------------------EVENTS--------------------------------

local keybind_changed = game:GetService("ReplicatedStorage").:WaitForChild("client").events.keybind_changed

----------------------------SETTINGS CLASS----------------------------

local Settings = {}
Settings.__index = Settings

export type Settings = typeof(setmetatable({} :: {
	_keybinds: {
		-- Keyboard
		kb_throttle: Enum.KeyCode,
		kb_brake: Enum.KeyCode,
		kb_steer_left: Enum.KeyCode,
		kb_steer_right: Enum.KeyCode,

		kb_throttle_alt: Enum.KeyCode,
		kb_brake_alt: Enum.KeyCode,
		kb_steer_left_alt: Enum.KeyCode,
		kb_steer_right_alt: Enum.KeyCode,
		kb_mouse_steer: Enum.KeyCode,

		kb_shift_up: Enum.KeyCode,
		kb_shift_down: Enum.KeyCode,

		kb_camera_change: Enum.KeyCode,
		kb_camera_rearview: Enum.KeyCode,

		-- Controller
		gamepad_throttle: Enum.KeyCode,
		gamepad_brake: Enum.KeyCode,
		gamepad_steer: Enum.KeyCode,
		gamepad_button_steer_left: Enum.KeyCode,
		gamepad_button_steer_right: Enum.KeyCode,

		gamepad_shift_up: Enum.KeyCode,
		gamepad_shift_down: Enum.KeyCode,

		gamepad_camera_change: Enum.KeyCode,
		gamepad_camera_rearview: Enum.KeyCode,

		-- Mouse
		mouse_toggle: Enum.KeyCode,
		mouse_throttle: Enum.UserInputType,
		mouse_brake: Enum.UserInputType,
		mouse_steer: Enum.UserInputType,		
	},
	_camera: {
		shake_x_multiplier: number,
		shake_y_multiplier: number,
		shake_z_multiplier: number,
	},
	_audio: {
		-- Sound settings
	},

	new: (saved_player_settings: {}) -> Settings,
	get_settings: (self: Settings) -> {[string]: any},
	get_setting: (self: Settings, setting: Enum) -> any,
	change_setting: (self: Settings, setting: Enum) -> (),
}, Settings))

function Settings.new(saved_player_settings: {}): Settings
	local self = setmetatable(saved_player_settings or {
		_keybinds = {
			-- Keyboard
			kb_throttle = Enum.KeyCode.W,
			kb_brake = Enum.KeyCode.S,
			kb_steer_left = Enum.KeyCode.A,
			kb_steer_right = Enum.KeyCode.D,

			kb_throttle_alt = Enum.KeyCode.Up,
			kb_brake_alt = Enum.KeyCode.Down,
			kb_steer_left_alt = Enum.KeyCode.Left,
			kb_steer_right_alt = Enum.KeyCode.Right,
			kb_mouse_steer = Enum.KeyCode.MousePosition,

			kb_shift_up = Enum.KeyCode.E,
			kb_shift_down = Enum.KeyCode.Q,

			kb_camera_change = Enum.KeyCode.V,
			kb_camera_rearview = Enum.KeyCode.LeftShift,

			-- Controller
			gamepad_throttle = Enum.KeyCode.ButtonR2,
			gamepad_brake = Enum.KeyCode.ButtonL2,
			gamepad_steer = Enum.KeyCode.Thumbstick1,
			gamepad_button_steer_left = Enum.KeyCode.DPadLeft,
			gamepad_button_steer_right = Enum.KeyCode.DPadRight,

			gamepad_shift_up = Enum.KeyCode.ButtonY,
			gamepad_shift_down = Enum.KeyCode.ButtonX,

			gamepad_camera_change = Enum.KeyCode.ButtonL1,
			gamepad_camera_rearview = Enum.KeyCode.ButtonR1,

			-- Mouse
			mouse_toggle = Enum.KeyCode.P,
			mouse_throttle = Enum.UserInputType.MouseButton1,
			mouse_brake = Enum.UserInputType.MouseButton2,
			mouse_steer = Enum.UserInputType.MouseMovement,
		},
		_camera = {
			shake_x_multiplier = 0.05,
			shake_y_multiplier = 0.05,
			shake_z_multiplier = 0.01,
		},
		_audio = {
			engine_volume = 100,
		},
	}, Settings)
end
	
function Settings.get_settings(self: Settings): {[string]: any}
	return {
		keybinds = self._keybinds,
		camera = self._camera,
		audio = self._audio,
	}
end

function Settings.get_setting(self: Settings, setting: Enum): any
	return self.path.to.setting
end

function Settings.change_setting(self: Settings, setting: Enum, value: number | boolean | Enum): ()
	self.path.to.setting = value
end

function Settings.destroy(self: Settings): ()
	
end

setmetatable(Settings, {
	__index = function(tbl, key)
		error(`Attempt to get {tbl}.{key} (not a valid member)`, 2)
	end,
	__newindex = function(tbl, key, value)
		error(`Attempt to set {tbl}.{key} (not a valid operation)`, 2)
	end,
})
