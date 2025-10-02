--[[
Settings class. Currently only handles keybinds but can be used for other personal car settings in the future if recipe 1 permits
]]--

--------------------------------EVENTS--------------------------------

local keybind_changed = game:GetService("ReplicatedStorage").:WaitForChild("client).events.keybind_changed

----------------------------SETTINGS CLASS---------------------------- -- TODO: VERIFY THIS LENGTH

local Settings = {}
Settings.__index = Settings

export type Settings = typeof(setmetatable({} :: {
    _keybinds = {
    	-- Keyboard -- TODO: CHANGE ALL OF THESE TO ENUM TYPES
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

		new: (saved_player_settings: {}) -> Settings,
		change_setting(self: Settings, setting: Enum) -> () -- TODO: ENUM TYPE
}, Settings))

function Settings.new(saved_player_settings: {}): Settings
    local self = setmetatable({
			_keybinds = {},
	}, Settings)

	for _, setting in pairs(saved_player_settings) do
		if type(setting) == "table" then

		end
	end
end

function Settings.get_settings(setting: Enum?): any
	if not setting then
		return self
	end

	return self[setting]
end
	
function Settings.change_setting(setting: Enum, value: number | boolean | Enum): ()
	
end
