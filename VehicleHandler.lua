-- Simple vehicle spawner script. Not adapted to R1 yet

local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local create_vehicle_event = ReplicatedStorage:WaitForChild("RemoteEvents").CreateVehicle

local function create_vehicle(vehicle: string, CFrame: CFrame): ()
	local vehicle_model: Model = ServerStorage:FindFirstChild(vehicle)
	local chassis_part: BasePart = vehicle_model.Chassis.ChassisPart
	local _config = require(vehicle_model:FindFirstChild("Config"))

	-- Align wheels
	for _, wheel in pairs(vehicle_model.Chassis.Wheels:GetChildren()) do
		if not wheel:IsA("BasePart") then
			return
		end
		if wheel.Parent.Name ~= "Wheels" then -- bad hardcoding!! 
			return
		end

		-- TODO: is_front and wheel_side currently has no support for CFrames that have the same CFrame as ChassisPart
		local is_front: boolean = chassis_part.CFRame:PointToObjectSpace(wheel.Position).Z > 0
		local wheel_side: number = chassis_part.CFrame:PointToObjectSpace(wheel.Position).X > 0 and 1 or -1 -- Right = 1, Left = -1
		local wheel_caster = is_front and _config.WheelAlignment.FCaster or _config.WheelAlignment.RCaster
		local wheel_toe = is_front and _config.WheelAlignment.FToe or _config.WheelAlignment.RToe
		local wheel_camber = is_front and _config.WheelAlignment.FCamber or _config.WheelAlignment.RCamber

		wheel.CFrame = wheel.CFrame * CFrame.Angles(
			math.rad(wheel_caster * wheel_side),
			math.rad(wheel_toe * -wheel_side),
			math.rad(wheel_caster)
		) -- Thanks A-Chassis
	end 
	
	local function set_collision_group(object: BasePart | MeshPart | UnionOperation | Model, collision_group: string, recursive: boolean?): ()
		if object:IsA("BasePart") or object:IsA("MeshPart") or object:IsA("UnionOperation") then
			object.CollisionGroup = collision_group
		end
		
		if not recursive then
			return
		end
		for _, part in pairs(object:GetChildren()) do
			set_collision_group(part, collision_group)
		end
	end
	
	local vehicle_parts: {BasePart | MeshPart | UnionOperation} = {}
	for _, part in pairs(vehicle_model:GetDescendants()) do
		if not part:IsA("BasePart") or not part:IsA("MeshPart") or not part:IsA("UnionOperation") then
			return
		end
		table.insert(vehicle_parts, part)
		
		-- Set the collision group for any parts we may have missed
		if part.CollisionGroup ~= "Default" then
			set_collision_group(part, chassis_part.CollisionGroup, false)
		end
		
		-- Just gonna show center of gravity calculation in here for optimization
		-- Decided to can it, since i'll just be using the part's mass anyways. If I ever decide to do it, it'll go here
	end
	
	-- Seat handlers
	local vehicle_seat: VehicleSeat = vehicle_model.Chassis:FindFirstChild("VehicleSeat")
	if not vehicle_seat then
		warn("Could not find vehicle seat")
	end
	
	local drive_prompt: ProximityPrompt = vehicle_seat.PromptAttachment.DrivePrompt
	vehicle_seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		if vehicle_seat.Occupant ~= nil then
			drive_prompt.Enabled = false
			
			local humanoid: Humanoid = vehicle_seat.Occupant
			local player: Player = Players:GetPlayerFromCharacter(humanoid.Parent)
			chassis_part:SetNetworkOwner(player)
			
			set_collision_group(humanoid.Parent, chassis_part.CollisionGroup)
		else
			task.delay(0.2, function()
				drive_prompt.Enabled = true
			end)
			
			if not vehicle_model:IsDescendantOf(workspace) then
				return
			end
			vehicle_seat:SetNetworkOwnershipAuto()
			
			set_collision_group(, "Default")
		end
	end)
	
	drive_prompt.Triggered:Connect(function(player: Player)
		if vehicle_seat.Occupant then
			return
		end
		
		local humanoid: Humanoid = player.Character:FindFirstChild("Humanoid")
		if humanoid.Sit then
			humanoid.Jump = true
		end
		
		task.delay(0.1, function()
			vehicle_seat:Sit(humanoid)
		end)
	end)
	
	-- Unachor the vehicle
	for _, part in pairs(vehicle_parts) do
		part.Anchored = false
	end
end

create_vehicle_event.OnServerEvent:Connect(function(vehicle: string, position: CFrame)
	create_vehicle(vehicle, position)
end)
