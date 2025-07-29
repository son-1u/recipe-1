local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local config = require(script.Parent.Parent.Config).keybinds
local camera = require(script.Parent.Parent.Camera)
local handle_mouse_activation = require(script.Mouse)

local keyboard = {}

function keyboard:enable(): ()
	if not UserInputService.KeyboardEnabled then
		return
	end
	
	ContextActionService:BindAction("SHIFT_UP", _, false, config.kb_shift_up)
	ContextActionService:BindAction("SHIFT_DOWN", _, false, config.kb_shift_down)
	ContextActionService:BindAction("CAMERA_CHANGE_VIEW", _, false, config.kb_camera_change)
	ContextActionService:BindAction("CAMERA_REARVIEW", _, false, config.kb_camera_rearview)
	ContextActionService:BindAction("ENABLE_MOUSE_DRIVE", handle_mouse_activation, false, config.mouse_toggle)
end

function keyboard:disable(): ()
	ContextActionService:UnbindAllActions()
end

function keyboard:update(): (number, number)
	local function get_axis(positive, positive_alt, negative, negative_alt): number
		local value = 0

		if UserInputService:IsKeyDown(positive) or UserInputService:IsKeyDown(positive_alt) then
			value += 1
		end
		if UserInputService:IsKeyDown(negative) or UserInputService:IsKeyDown(negative_alt) then
			value -= 1
		end

		return value
	end

	local throttle = get_axis(config.kb_throttle, config.kb_throttle_alt, config.kb_brake, config.kb_brake_alt)
	local steer = get_axis(config.kb_steer_right, config.kb_steer_right_alt, config.kb_steer_left, config.kb_steer_left_alt)

	return throttle, steer
end

return keyboard
