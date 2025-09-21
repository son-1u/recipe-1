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

local hud_ui = ReplicatedStorage:WaitForChild("user_interface").hud

-------------------------------HUD CLASS------------------------------

local HUD = {}
HUD.__index = HUD

export type HUD = typeof(setmetatable({} :: {
	_player: Player,
	_user_interface: ScreenGui,
	_gear_text: TextLabel,
	_speed_text: TextLabel,
	_tachometer_text: TextLabel,
	_tachometer_bar: Frame,
	
	new: (player: Player, gear_shift_event: Signal) -> HUD,
	update: (self: HUD, speed: number, rpm_text: number, tachometer_bar_progress: number, dt: number) -> (),
	destroy: (self: HUD) -> (),
}, HUD))

function HUD.new(player: Player, gear_shift_event: Signal): HUD
	local self = setmetatable({
		_player = player,
		_user_interface = hud_ui:Clone()
	}, HUD)
	
	self._gear_text = self._user_interface:WaitForChild("base").gear.value
	self._speed_text = self._user_interface:WaitForChild("base").speedometer.value
	self._tachometer_text = self._user_interface:WaitForChild("base").tachometer.value
	self._tachometer_bar = self._user_interface:WaitForChild("base").tachometer_bar.fill
	
	self._user_interface.Parent = self._player.PlayerGui
	
	gear_shift_event:Connect(function(gear: number)
		self._gear_text.Text = gear
	end)
	
	return self
end

function HUD.update(self: HUD, speed: number, rpm_text: number, tachometer_bar_progress: number, dt: number,): ()
	self._speed_text.Text = speed
	self._tachometer_text.Text = rpm_text
	
	TweenService:Create(
		self._tachometer_bar,
		TweenInfo.new(dt, Enum.EasingStyle.Linear, Enum.EasingDirection.In),
		{Size = UDim2.fromScale(tachometer_bar_progress, 1)}
	):Play()
end

function HUD.destroy(self: HUD): ()
	self._user_interface:Destroy()
	
	for k, v in pairs(self) do
		if getmetatable(v) == Signal then
			v:Disconnect()
		end
		
		self[k] = nil
	end
end

return HUD
