local CollectionService = game:GetService("CollectionService")

local PART_VELOCITY_THRESHOLD = 80
local DEBOUNCE_TIME = 0.1

local function break_joints(part: BasePart): ()
	for _, joint in pairs(part:GetJoints()) do
		joint:Destroy()
	end
end

local function make_parts_destructible(parts_folder: Folder): ()
	local debounce_table = {}
	
	for _, part in pairs(parts_folder:GetDescendants()) do
		if not part:IsA("BasePart") then
			continue
		end
		
		-- I would've preferred possibly a better way, but I guess this works for now, especially with my time constraint
		-- Look into some sort of raycast hitbox?
		part.Touched:Connect(function(hit: BasePart)
			if debounce_table[part] then
				return
			end
			if (math.abs(part.AssemblyLinearVelocity.Magnitude) - math.abs(hit.AssemblyLinearVelocity.Magnitude)) <= PART_VELOCITY_THRESHOLD then
				return
			end
			
			local humanoid = hit.Parent:FindFirstChildOfClass("Humanoid")
			if humanoid then
				if humanoid.Sit == true then
					return
				end
				
				humanoid:TakeDamage(part.AssemblyLinearVelocity.Magnitude / 5)
			end
			
			break_joints(part)
			CollectionService:AddTag(part, "DEBRIS")
			part.CollisionGroup = "Default"
			part.CanCollide = true
			part:SetNetworkOwnershipAuto()
			
			task.delay(DEBOUNCE_TIME, function()
				table.remove(debounce_table, part)
			end)
		end)
	end
end

local function create_vehicle_model(prefab: Model, spawn_position: CFrame, config): Model
	local vehicle = prefab:Clone()
	local chassis_part = vehicle.chassis.chassis_part

	-- Weight
	local weight_brick_front = vehicle.chassis:FindFirstChild("weight_brick_front")
	weight_brick_front.CustomPhysicalProperties = true
	weight_brick_front.CustomPhysicalProperties.Density = config.vehicle_mass * config.mass_distribution
	local weight_brick_rear = vehicle.chassis:FindFirstChild("weight_brick_rear")
	weight_brick_rear.CustomPhysicalProperties = true
	weight_brick_rear.CustomPhysicalProperties.Density = config.vehicle_mass * (1 - config.mass_distribution)

	-- Wheels
	for _, wheel in pairs(vehicle.chassis.wheels:GetChildren()) do
		if not wheel:IsA("BasePart") then
			return
		end

		-- TODO: is_front and wheel_side currently has no support for CFrames that have the same CFrame as ChassisPart
		local is_front: boolean = -chassis_part.CFrame:PointToObjectSpace(wheel.Position).Z > 0
		local wheel_side: number = chassis_part.CFrame:PointToObjectSpace(wheel.Position).X > 0 and 1 or -1 -- Right = 1, Left = -1
		local wheel_caster = is_front and config.WheelAlignment.FCaster or config.WheelAlignment.RCaster
		local wheel_toe = is_front and config.WheelAlignment.FToe or config.WheelAlignment.RToe
		local wheel_camber = is_front and config.WheelAlignment.FCamber or config.WheelAlignment.RCamber

		wheel.CFrame = wheel.CFrame * CFrame.Angles(
			math.rad(wheel_caster * wheel_side),
			math.rad(wheel_toe * -wheel_side),
			math.rad(wheel_caster)
		)
	end
	vehicle.Parent = workspace
	vehicle.PrimaryPart.CFrame = spawn_position

	-- Unanchor
	for _, descendant in pairs(vehicle:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
		end
	end
	
	make_parts_destructible(vehicle:FindFirstChild("body"))
end

return create_vehicle_model
