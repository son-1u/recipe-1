while script.Parent.PrimaryPart == nil do
	task.wait()
end

-------------------------------SERVICES-------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

--------------------------------IMPORTS-------------------------------

local Vehicle = require(ReplicatedStorage.module_scripts.vehicle.client_vehicle)
local Config = require(script.config)

local Camera = require(ReplicatedStorage.module_scripts.vehicle.camera)

--local VehicleHUD = require(ReplicatedStorage.module_scripts.vehicle.vehicle_hud)

------------------------------SCRIPT NAME-----------------------------

local VEHICLE_PRIMARY_PART: VehicleSeat = script.Parent.PrimaryPart
local DOWNFORCE_OBJECT: VectorForce = script.Parent:WaitForChild("chassis").forces.downforce
local SLIPSTREAM_OBJECT: VectorForce = script.Parent:WaitForChild("chassis").forces.slipstream

local VEHICLE = Vehicle.new(script.Parent.chassis:WaitForChild("driver_seat"), script.Parent.chassis.wheels:GetChildren(), Config)
local CAMERA = Camera.new(script.Parent.chassis.extras.cameras:GetChildren())

local function client_stepped_callback(_, dt: number): ()
	local speed, rpm, wheel_forces, downforce, slipstream = VEHICLE:update(dt)
	print(rpm)
	print(wheel_forces)
	for position: Vector3, force: Vector3 in pairs(wheel_forces) do
		VEHICLE_PRIMARY_PART:ApplyImpulseAtPosition(force, position)
	end

	DOWNFORCE_OBJECT.Force = downforce
	SLIPSTREAM_OBJECT.Force = slipstream
end

local function server_stepped_callback(): ()
	VEHICLE_PRIMARY_PART:ApplyImpulseAtPosition(
		VEHICLE_PRIMARY_PART.Mass * workspace.Gravity * VEHICLE_PRIMARY_PART.CFrame.UpVector,
		VEHICLE_PRIMARY_PART.Position
	)
end

local client_conn: RBXScriptConnection
local server_conn: RBXScriptConnection
local hud

server_conn = RunService.Stepped:Connect(server_stepped_callback)

VEHICLE_PRIMARY_PART:GetPropertyChangedSignal("Occupant"):Connect(function()
	if VEHICLE_PRIMARY_PART.Occupant ~= nil then
		-- TODO: PLAY ANIMATION, SET COLLISION GROUPS
		print("g")
		--hud = VehicleHUD.new()
		
		if server_conn ~= nil then server_conn:Disconnect() end
		client_conn = RunService.Stepped:Connect(client_stepped_callback)
		
		CAMERA:enable()
	else
		--hud:Destroy() --verify this is correct
		
		if client_conn ~= nil then client_conn:Disconnect() end
		server_conn = RunService.Stepped:Connect(server_stepped_callback)
		
		CAMERA:disable()
	end
end)

VEHICLE.camera_change_triggered:Connect(function(rearview: boolean?)
	CAMERA:change_camera(rearview)
end)
