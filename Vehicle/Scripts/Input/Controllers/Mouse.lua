-- Should only be used through the Keyboard module script

-------------------------------SERVICES-------------------------------

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

--------------------------------IMPORTS-------------------------------

-------------------------------FUNCTIONS------------------------------

local enabled
local function handle_mouse_activation(): ()
	UserInputService.InputChanged:Connect(function(input: InputObject, game_processed: boolean): ()
		if input.UserInputType  ~= Enum.UserInputType.MouseMovement then
			return
		end
		
		local position = input.Position.X
		local steer = 0
		if math.abs(position) > STEERING_DEADZONE then
			steer = (math.abs(position) - STEERING_DEADZONE) / (1 - STEERING_DEADZONE) * math.sign(position)
		end
	end)
end

return handle_mouse_activation
