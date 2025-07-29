local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local config = require(script.Parent.Parent.Config).keybinds

local Controller = {}

local current_gamepad = Enum.UserInputType.Gamepad1

local connection: RBXScriptConnection
function Controller:enable(): ()
	if not UserInputService.GamepadEnabled then
		return
	end
	
	connection = UserInputService.InputChanged:Connect(function(input: InputObject, game_processed: boolean): ()
		if input.UserInputType ~= Enum.UserInputType.Gamepad then -- TODO: FIND A USERINPUTTYPE FOR ALL GAMEPADS
			return
		end
		current_gamepad = input
	end)
	
	ContextActionService:BindAction("SHIFT_UP", _, false, config.controller_shift_up)
	ContextActionService:BindAction("SHIFT_DOWN", _, false, config.controller_shift_down)
	ContextActionService:BindAction("CAMERA_CHANGE_VIEW", _, false, config.controller_camera_change)
	ContextActionService:BindAction("CAMERA_REARVIEW", _, false, config.controller_camera_rearview)
end

function Controller:disable(): ()
	ContextActionService:UnbindAllActions()
	
	if connection then
		connection:Disconnect()
		connection = nil
	end
end 

function Controller:update()
	local throttle = 0
	local steer = 0
	
	for _, input in pairs(UserInputService:GetGamepadState(current_gamepad)) do
		if input.KeyCode == config.controller_throttle then -- TODO: REPLACE ALL ENUM.KEYCODE WITH CONFIG
			throttle += input.Position.Z
		end
		if input.KeyCode == config.controller_brake then
			throttle -= input.Position.Z
		end
		if input.KeyCode == config.controller_steer then
			local position = input.Position.X
			if math.abs(position) < STEERING_DEADZONE then
				continue
			end
			steer = (math.abs(position) - STEERING_DEADZONE) / (1 - STEERING_DEADZONE) * math.sign(position)
		end
	end
end

return Controller
